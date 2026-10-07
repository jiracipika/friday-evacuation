#!/usr/bin/env python3
"""ladder_runner.py — trustworthy serial supervision for the friday-evacuation
verification ladder (Python 3.9, stdlib only).

Trust rules (P0A):
  * A missing required suite is a FAILURE, never a silent skip.
  * Exit code 0 alone is not success: every suite must print its own
    suite-specific success evidence (see SUCCESS_PATTERNS).
  * Any "SCRIPT ERROR"/"Parse Error" in the combined output fails the suite
    even if the process exited 0 (Godot script/parse errors can exit 0).
  * Boot phase: any "SCRIPT ERROR" fails, regardless of exit code.
  * Known benign Godot teardown warnings are preserved in logs but ignored:
    only specific full lines are whitelisted, never broad patterns like
    "ERROR" or "SCRIPT ERROR" as a whole.
  * Every suite gets a unique run directory, a hard timeout with process-group
    cleanup, and a combined stdout+stderr log.
"""

import os
import re
import shutil
import signal
import subprocess
import sys
import time
from datetime import datetime

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Production manifest: the pre-existing suite list plus the two recently added
# menu/loading suites. Order matters (cheapest/earliest gates first).
PRODUCTION_SUITES = """\
BootTest HeroAssemblySmokeTest SplashGateTest PlayerChairMechanicsSmokeTest \
JumpForgivenessTest GraphicsPassSmokeTest MenuLayoutSmokeTest \
ChairSkinSmokeTest CharacterRosterSmokeTest HauledSmokeTest HauledBehaviorsTest \
ShopSeekSmokeTest \
PizzaColonySmokeTest TouchControlsSmokeTest ModeHUDResponsiveSmokeTest ModeResultsSmokeTest ModeSmokeTest NetworkSmokeTest \
NetworkTwoPeerTest LanAvatarSyncTest AnnouncerSmokeTest PanicCamSmokeTest \
LevelClearTest CheckpointBotTest LayoutPacingTest SkinBotSanityTest HazardsSmokeTest \
ThemedFloorsSmokeTest OfficeDressingParityTest PowerUpSmokeTest PauseMenuSmokeTest \
AccessibilitySmokeTest Phase8BAccessTest TrapAccessibilitySmokeTest RaceModifiersSmokeTest \
ModifierMenuSmokeTest GhostRacerSmokeTest StatsRoundTripTest \
VisualDesignSmokeTest WallMaterialsSmokeTest FaceSmokeTest BindingsSmokeTest \
InputPrefsSmokeTest ControlsOverlaySmokeTest SettingsRoundTripTest \
NormalMapSmokeTest PropMaterialsSmokeTest LevelLayoutSmokeTest \
PreMatchModalSmokeTest GamepadSupportTest FloorCullingTest ArtLightingTest \
ArtMaterialsTest ArtSurfaceReadabilityTest ArtPropsTest ArtHUDTest \
MenuDepartureSmokeTest MenuInputPathTest LoadingFlowSmokeTest ResultsCelebrationTest \
HUDThemeSmokeTest UICopyContractTest MenuMapBestTest ResultsPanelFitTest \
MovementFeelTest ModeSelectRedesignTest MenuHomeRedesignTest \
MenuBackdropPropsTest PadNavSmokeTest ArtBlenderPropsTest \
SettingsRedesignTest OfficeArchitectureSmokeTest AmbientAudioTest CoreAudioSmokeTest \
StatsBestTimeTest PortraitSweepSmokeTest""".split()

# Default log root lives in the repo (durable), not /tmp.
DEFAULT_LOG_DIR = os.path.join(
    REPO_ROOT, "docs", "ui-continuation", "evidence", "ladder-runs")
DEFAULT_TIMEOUT_SECONDS = 300
DEFAULT_GODOT = "/usr/local/bin/godot"

# Hard failure patterns: a line containing any of these fails the suite even
# on exit code 0 (Godot can exit 0 after a script/parse error).
HARD_ERROR_PATTERNS = [
    re.compile(r"SCRIPT ERROR"),
    re.compile(r"Parse Error"),
]

# Known benign Godot teardown/leak warnings. Matched as FULL LINES only. A line
# matching one of these is merely silenced as a warning — it can never mask a
# hard error, because hard-error detection (SCRIPT ERROR / Parse Error) runs
# FIRST and is unconditional, whitelist or not. The whitelist is intentionally
# narrow: specific Godot engine teardown notices observed in real runs. It does
# NOT cover arbitrary "Condition ..." or index-error lines.
BENIGN_TEARDOWN_LINES = [
    re.compile(r"^Godot Engine v\S+\.official\.[0-9a-f]+ - "),
    re.compile(r"^ERROR: (Atomic ops|Leaked instance|ObjectDB Instances leaked at exit|Nodes still in use|Resources still in use|OS\.|ResourceStillAllocated|.*\) - leaked)\b.*$"),
    re.compile(r"^WARNING: (ResourceStillAllocated|.*leaked|.* still exist|.* still in use).*: [0-9]+$"),
    re.compile(r"^     at: .* \(\S+\)$"),
    re.compile(r"^ *At: \S+:\d+"),
    re.compile(r"^   data->instances\.size\(\)=[0-9]+$"),
]


def _line_is_benign(line):
    stripped = line.strip()
    if not stripped:
        return True
    return any(p.match(line) or p.match(stripped) for p in BENIGN_TEARDOWN_LINES)


def scan_for_hard_errors(text):
    """Return a list of hard-error lines. HARD ERRORS ARE NEVER MASKED: the
    benign teardown whitelist only suppresses the whitelisted line itself and
    can never suppress a line containing SCRIPT ERROR / Parse Error."""
    hits = []
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        has_hard = any(p.search(line) or p.search(stripped)
                       for p in HARD_ERROR_PATTERNS)
        if has_hard:
            hits.append(line.rstrip())
            continue  # never allow the whitelist to swallow a hard error
        # Benign whitelist only silences the exact benign line itself.
    return hits


# Suite-specific success evidence. A suite counts as passed only when at least
# one pattern matches its combined output (and no hard errors were found).
# Sources inspected in the actual scripts/*.gd test files 2026-09-15.
SUCCESS_PATTERNS = {
    # === ALL CHECKS PASSED ===  (BootTest.gd:95)
    "BootTest": [re.compile(r"^=== ALL CHECKS PASSED ===$", re.M)],
    # quit(0 if failures == 0 else 1); HeroAssemblySmokeTest.gd:35
    "HeroAssemblySmokeTest": [re.compile(r"^\[PASS\] ", re.M)],
    # SplashGateTest: PASS (N checks)  (SplashGateTest.gd:119)
    "SplashGateTest": [re.compile(r"^SplashGateTest: PASS \(\d+ checks\)", re.M)],
    # === PLAYER CHAIR MECHANICS SMOKE TEST PASSED ===  (:91)
    "PlayerChairMechanicsSmokeTest": [
        re.compile(r"^=== PLAYER CHAIR MECHANICS SMOKE TEST PASSED ===$", re.M)],
    # JumpForgivenessTest: N/M  (JumpForgivenessTest.gd:172)
    "JumpForgivenessTest": [
        re.compile(r"^JumpForgivenessTest: (\d+)/(\d+)$", re.M)],
    # === GRAPHICS PASS SMOKE TEST PASS (n/m) ===  (:153)
    "GraphicsPassSmokeTest": [
        re.compile(r"^=== GRAPHICS PASS SMOKE TEST PASS \((\d+)/(\d+)\) ===$", re.M)],
    "MenuLayoutSmokeTest": [
        re.compile(r"^=== MENU LAYOUT SMOKE TEST PASS \((\d+)/(\d+)\) ===$", re.M)],
    # [PASS] ChairSkinSmokeTest: N checks — ...  (:133)
    "ChairSkinSmokeTest": [
        re.compile(r"^\[PASS\] ChairSkinSmokeTest: \d+ checks", re.M)],
    # quit(0) at :42 with "[PASS] 8 selectable characters..." at :41
    "CharacterRosterSmokeTest": [
        re.compile(r"^\[PASS\] 8 selectable characters build unique riders", re.M)],
    "HauledSmokeTest": [
        re.compile(r"^=== HAULED SMOKE TEST PASSED \(\d+ checks\) ===$", re.M)],
    "HauledBehaviorsTest": [
        re.compile(r"^=== HAULED BEHAVIORS TEST PASSED \(\d+ checks\) ===$", re.M)],
    "ShopSeekSmokeTest": [
        re.compile(r"^=== SHOPSEEK SMOKE TEST PASSED \(\d+ checks\) ===$", re.M)],
    "PizzaColonySmokeTest": [
        re.compile(r"^=== PIZZA COLONY SMOKE TEST PASSED \(\d+ checks\) ===$", re.M)],
    # TOUCH_SMOKE_PASS  (TouchControlsSmokeTest.gd:35)
    "TouchControlsSmokeTest": [re.compile(r"^TOUCH_SMOKE_PASS$", re.M)],
    # === MODE SMOKE TEST PASSED ===  (ModeSmokeTest.gd:23)
    "ModeSmokeTest": [re.compile(r"^=== MODE SMOKE TEST PASSED ===$", re.M)],
    "ModeHUDResponsiveSmokeTest": [re.compile(r"^ModeHUDResponsiveSmokeTest: \d+/\d+ checks passed$", re.M)],
    "ModeResultsSmokeTest": [re.compile(r"^ModeResultsSmokeTest: \d+/\d+ checks passed$", re.M)],
    "NetworkSmokeTest": [
        re.compile(r"^=== NETWORK SMOKE TEST PASSED ===$", re.M)],
    "NetworkTwoPeerTest": [
        re.compile(r"^=== NETWORK TWO-PEER TEST PASSED ===$", re.M)],
    "LanAvatarSyncTest": [
        re.compile(r"^=== LAN AVATAR SYNC TEST PASSED \(\d+ checks\) ===$", re.M)],
    "AnnouncerSmokeTest": [
        re.compile(r"^=== ANNOUNCER SMOKE TEST PASSED ===$", re.M)],
    "PanicCamSmokeTest": [
        re.compile(r"^=== PANICCAM SMOKE TEST PASSED ===$", re.M)],
    "LevelClearTest": [
        re.compile(r"^=== LEVEL CLEAR TEST: PASS", re.M)],
    "CheckpointBotTest": [
        re.compile(r"^=== CHECKPOINT BOT: ALL PASS \(\d+ checks\) ===$", re.M)],
    "SkinBotSanityTest": [
        re.compile(r"^=== SKIN BOT SANITY PASSED \(\d+ checks\) ===$", re.M)],
    "HazardsSmokeTest": [
        re.compile(r"^=== HAZARDS SMOKE TEST PASSED \(\d+ checks\) ===$", re.M)],
    "ThemedFloorsSmokeTest": [
        re.compile(r"^=== THEMED FLOORS SMOKE TEST PASSED \(\d+ checks\) ===$", re.M)],
    "OfficeDressingParityTest": [
        re.compile(r"^=== OFFICE DRESSING PARITY TEST PASSED \(\d+ checks\) ===$", re.M)],
    "PowerUpSmokeTest": [
        re.compile(r"^=== POWER-UP SMOKE TEST PASSED \(\d+ checks\) ===$", re.M)],
    "PauseMenuSmokeTest": [
        re.compile(r"^=== PAUSE MENU SMOKE TEST: ALL PASS ===$", re.M)],
    "AccessibilitySmokeTest": [
        re.compile(r"^=== ACCESSIBILITY SMOKE TEST PASSED \(\d+ checks\) ===$", re.M)],
    "Phase8BAccessTest": [
        re.compile(r"^=== PHASE 8B ACCESS TEST PASSED \(\d+ checks\) ===$", re.M)],
    "TrapAccessibilitySmokeTest": [
        re.compile(r"^=== TRAP ACCESSIBILITY SMOKE TEST PASSED \(\d+ checks\) ===$", re.M)],
    "RaceModifiersSmokeTest": [
        re.compile(r"^=== RACE MODIFIERS SMOKE TEST PASSED \(\d+ checks\) ===$", re.M)],
    "ModifierMenuSmokeTest": [
        re.compile(r"^=== MODIFIER MENU SMOKE TEST PASSED \(\d+ checks\) ===$", re.M)],
    "GhostRacerSmokeTest": [
        re.compile(r"^=== GHOST RACER SMOKE TEST PASSED \(\d+ checks\) ===$", re.M)],
    # STATS_ROUND_TRIP_PASS  (StatsRoundTripTest.gd:44)
    "StatsRoundTripTest": [re.compile(r"^STATS_ROUND_TRIP_PASS$", re.M)],
    # quit(0) at :31 with PASS banner at :30 ("Friday visual system...")
    "VisualDesignSmokeTest": [
        re.compile(r"^\[PASS\] Friday visual system:", re.M)],
    "WallMaterialsSmokeTest": [
        re.compile(r"^\[PASS\] WallMaterials: per-floor textures", re.M)],
    "FaceSmokeTest": [
        re.compile(r"^=== FACE SMOKE TEST PASSED ===$", re.M)],
    # bare print("PASS") + quit(0); BindingsSmokeTest.gd:177-180
    "BindingsSmokeTest": [re.compile(r"^PASS$", re.M)],
    # "<Name>: N/M checks passed" family (failures only via exit code)
    # Numeric N/M success patterns now go through success_evidence_matches()
    # (equal positive counts required); the (\\d+)/(\\d+) groups are part of
    # the contract, not just shape.
    "InputPrefsSmokeTest": [
        re.compile(r"^InputPrefsSmokeTest: (\d+)/(\d+) checks passed$", re.M)],
    "ControlsOverlaySmokeTest": [
        re.compile(r"^ControlsOverlaySmokeTest: (\d+)/(\d+) checks passed$", re.M)],
    "SettingsRoundTripTest": [
        re.compile(r"^SettingsRoundTripTest: (\d+)/(\d+) checks passed$", re.M)],
    "NormalMapSmokeTest": [
        re.compile(r"^NormalMapSmokeTest: (\d+)/(\d+) checks passed$", re.M)],
    "PropMaterialsSmokeTest": [
        re.compile(r"^PropMaterialsSmokeTest: (\d+)/(\d+) checks passed$", re.M)],
    "LevelLayoutSmokeTest": [
        re.compile(r"^LevelLayoutSmokeTest: (\d+)/(\d+) checks passed$", re.M)],
    "PreMatchModalSmokeTest": [
        re.compile(r"^PreMatchModalSmokeTest: (\d+)/(\d+) checks passed$", re.M)],
    "MenuDepartureSmokeTest": [
        re.compile(r"^=== MENU DEPARTURE SMOKE TEST PASS \((\d+)/(\d+)\) ===$", re.M)],
    "MenuInputPathTest": [
        re.compile(r"^=== MENU INPUT PATH TEST PASS \((\d+)/(\d+)\) ===$", re.M)],
    "ResultsCelebrationTest": [
        re.compile(r"^=== RESULTS CELEBRATION TEST PASS \((\d+)/(\d+)\) ===$", re.M)],
    "ResultsPanelFitTest": [
        re.compile(r"^=== RESULTS PANEL FIT TEST PASS \((\d+)/(\d+)\) ===$", re.M)],
    "HUDThemeSmokeTest": [
        re.compile(r"^=== HUD THEME SMOKE TEST PASS \((\d+)/(\d+)\) ===$", re.M)],
    "UICopyContractTest": [
        re.compile(r"^=== UI COPY CONTRACT TEST PASS \((\d+)/(\d+)\) ===$", re.M)],
    "MenuMapBestTest": [
        re.compile(r"^=== MENU MAP BEST TEST PASS \((\d+)/(\d+)\) ===$", re.M)],
    "LayoutPacingTest": [
        re.compile(r"^=== LAYOUT PACING TEST PASS \((\d+)/(\d+)\) ===$", re.M)],
    "LoadingFlowSmokeTest": [
        re.compile(r"^LoadingFlowSmokeTest: (\d+)/(\d+) checks passed$", re.M)],
    # 2026-09 redesign-era tests newly registered in PRODUCTION_SUITES.
    "MovementFeelTest": [
        re.compile(r"^MovementFeelTest: (\d+)/(\d+) checks passed$", re.M)],
    "ModeSelectRedesignTest": [
        re.compile(r"^=== MODE SELECT REDESIGN TEST PASS \((\d+)/(\d+)\) ===$", re.M)],
    "MenuHomeRedesignTest": [
        re.compile(r"^=== MENU HOME REDESIGN TEST PASS \((\d+)/(\d+)\) ===$", re.M)],
    "MenuBackdropPropsTest": [re.compile(r"^\[PASS\] MenuBackdropPropsTest: ", re.M)],
    "PadNavSmokeTest": [re.compile(r"^PADNAV: ALL PASS$", re.M)],
    "ArtBlenderPropsTest": [
        re.compile(r"^ArtBlenderPropsTest: \d+ checks, 0 failures$", re.M)],
    "SettingsRedesignTest": [
        re.compile(r"^SettingsRedesignTest: (\d+)/(\d+) checks PASS$", re.M)],
    "OfficeArchitectureSmokeTest": [
        re.compile(r"^OfficeArchitectureSmokeTest: (\d+)/(\d+) checks PASS$", re.M)],
    "AmbientAudioTest": [
        re.compile(r"^AmbientAudioTest: (\d+)/(\d+) checks PASS$", re.M)],
    "CoreAudioSmokeTest": [
        re.compile(r"^CoreAudioSmokeTest: (\d+)/(\d+) checks PASS$", re.M)],
    "StatsBestTimeTest": [
        re.compile(r"^=== STATS BEST TIME TEST PASS \((\d+)/(\d+)\) ===$", re.M)],
    "PortraitSweepSmokeTest": [
        re.compile(r"^=== PORTRAIT SWEEP SMOKE TEST PASS \((\d+)/(\d+)\) ===$", re.M)],
    "GamepadSupportTest": [
        re.compile(r"^=== GAMEPAD SUPPORT TEST PASSED \(\d+ checks\) ===$", re.M)],
    "FloorCullingTest": [
        re.compile(r"^=== FLOOR CULLING TEST PASSED \(\d+ checks\) ===$", re.M)],
    # [%s] %s with "PASS" literal + quit(0 if failures==0 else 1)
    "ArtLightingTest": [re.compile(r"^\[PASS\] ", re.M)],
    "ArtMaterialsTest": [
        re.compile(r"^ArtMaterialsTest: (\d+)/(\d+) checks passed$", re.M)],
    "ArtSurfaceReadabilityTest": [re.compile(r"^\[PASS\] ", re.M)],
    "ArtPropsTest": [re.compile(r"^\[PASS\] ", re.M)],
    "ArtHUDTest": [re.compile(r"^\[PASS\] ", re.M)],
    # === harness synthetic fixture (test_ladder_runner.py) ===
    "FakeSuiteA": [re.compile(r"^=== ALL CHECKS PASSED \(", re.M)],
}


def resolve_suite_list(env=None):
    """Production manifest by default. FE_LADDER_SUITES (space separated) may
    narrow/replace it — a documented test seam only; the default NEVER omits
    suites."""
    env = env if env is not None else os.environ
    override = env.get("FE_LADDER_SUITES", "").strip()
    if override:
        return override.split()
    return list(PRODUCTION_SUITES)


class LadderConfigError(ValueError):
    """Invalid runner configuration (suite selection, timeout, ...)."""


VALID_SUITE_ID = re.compile(r"^[A-Za-z0-9_]+$")


def validate_config(suites, timeout_seconds):
    """Reject vacuous or dangerous configurations before any phase runs."""
    try:
        timeout_seconds = int(timeout_seconds)
    except (TypeError, ValueError):
        raise LadderConfigError(
            "timeout must be a positive integer, got %r" % (timeout_seconds,))
    if timeout_seconds <= 0:
        raise LadderConfigError(
            "timeout must be a positive integer, got %d" % timeout_seconds)
    if not suites:
        raise LadderConfigError(
            "no suites selected: no phases would execute (an empty selection "
            "is refused; a run must execute at least one phase)")
    for suite in suites:
        if not VALID_SUITE_ID.match(suite):
            raise LadderConfigError(
                "invalid suite identifier: %r (allowed: [A-Za-z0-9_]+)"
                % suite)
    return timeout_seconds


def scan_for_suite_failures(suite, text):
    """Detect explicit suite FAILURE markers in combined output, even when a
    success marker is also present (exit code alone is not trust; some suites
    report failure only via markers/printerr while still exiting 0).
    Markers are line-anchored and were verified against the actual print
    formats in scripts/*.gd; prose that merely MENTIONS failure (e.g. a
    passing check labelled 'status shows LOAD FAILED') does not match because
    those lines do not start with a failure marker."""
    marker_patterns = [
        re.compile(r"^\[FAIL\] ", re.M),        # per-check failure lines
        re.compile(r"^\s*FAIL: ", re.M),        # PauseMenuSmokeTest-style
        re.compile(r"^=== .*\bFAILED\b", re.M),  # === ... FAILED ... banners
        re.compile(r"^=== LEVEL CLEAR TEST: FAIL ===$", re.M),
        re.compile(r"^TOUCH_SMOKE_FAIL", re.M),
        re.compile(r"^STATS_ROUND_TRIP_FAIL", re.M),
        re.compile(r"^\[BOT FAILED\] ", re.M),
        re.compile(r"^\[FAILED\] ", re.M),
    ]
    hits = []
    for line in text.splitlines():
        for pat in marker_patterns:
            if pat.match(line):
                hits.append(line.rstrip())
                break
    return hits


def success_evidence_matches(suite, output):
    """True only when a suite-specific success pattern matches AND any numeric
    passed/total counts it carries are EQUAL and POSITIVE (so '1/10 checks
    passed' can never satisfy a success requirement by regex shape alone)."""
    for pat in SUCCESS_PATTERNS.get(suite, []):
        for m in pat.finditer(output):
            if pat.groups == 2:
                try:
                    passed = int(m.group(1))
                    total = int(m.group(2))
                except (TypeError, ValueError):
                    continue
                if passed == total and passed > 0:
                    return True
            else:
                return True
    return False


def verify_godot_binary(godot_bin):
    if not os.path.isfile(godot_bin) or not os.access(godot_bin, os.X_OK):
        raise RuntimeError("GODOT_BIN not found or not executable: %s" % godot_bin)


def _fresh_run_dir(log_root):
    os.makedirs(log_root, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    run_dir = os.path.join(log_root, "run-" + stamp)
    n = 1
    while os.path.exists(run_dir):
        n += 1
        run_dir = os.path.join(log_root, "run-%s-%d" % (stamp, n))
    os.makedirs(run_dir)
    return run_dir


def _kill_process_group(proc):
    try:
        os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
    except (ProcessLookupError, PermissionError):
        pass
    try:
        proc.wait(timeout=10)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
        except (ProcessLookupError, PermissionError):
            pass
        proc.wait(timeout=10)


def run_suite(godot_bin, repo_root, suite, log_path, timeout_seconds):
    """Run one suite script headless with a hard timeout. Returns a result dict."""
    script_path = os.path.join(repo_root, "scripts", suite + ".gd")
    if not os.path.isfile(script_path):
        return {"suite": suite, "status": "MISSING", "rc": None,
                "timeout": timeout_seconds,
                "log_path": log_path,
                "reason": "required suite script not found: %s" % script_path}
    cmd = [godot_bin, "--headless", "--path", repo_root,
           "--script", "scripts/%s.gd" % suite, "--", "--test-mode"]
    with open(log_path, "wb") as logf:
        logf.write(("$ %s\n" % " ".join(cmd)).encode("utf-8"))
        logf.flush()
        started = time.monotonic()
        proc = subprocess.Popen(
            cmd, stdout=logf, stderr=subprocess.STDOUT,
            cwd=repo_root, start_new_session=True)
        try:
            rc = proc.wait(timeout=timeout_seconds)
            timed_out = False
        except subprocess.TimeoutExpired:
            _kill_process_group(proc)
            rc = None
            timed_out = True
        duration = time.monotonic() - started
    with open(log_path, "ab") as logf:
        logf.write(("\n[runner] rc=%s timed_out=%s duration=%.1fs timeout=%ss\n"
                    % (rc, timed_out, duration, timeout_seconds)).encode("utf-8"))
    with open(log_path, "r", errors="replace") as f:
        output = f.read()

    if timed_out:
        return {"suite": suite, "status": "TIMEOUT", "rc": None,
                "timeout": timeout_seconds, "log_path": log_path,
                "reason": "timed out after %ss" % timeout_seconds}
    hard = scan_for_hard_errors(output)
    if hard:
        return {"suite": suite, "status": "HARD_ERROR", "rc": rc,
                "timeout": timeout_seconds, "log_path": log_path,
                "reason": "script/parse errors present despite rc=%s" % rc,
                "error_lines": hard[:5]}
    fails = scan_for_suite_failures(suite, output)
    if fails:
        return {"suite": suite, "status": "SUITE_FAILURE_MARKER", "rc": rc,
                "timeout": timeout_seconds, "log_path": log_path,
                "reason": ("explicit suite failure markers present despite "
                           "rc=%s" % rc),
                "error_lines": fails[:5]}
    if rc != 0:
        return {"suite": suite, "status": "NONZERO_EXIT", "rc": rc,
                "timeout": timeout_seconds, "log_path": log_path,
                "reason": "nonzero exit code %s" % rc}
    if not success_evidence_matches(suite, output):
        return {"suite": suite, "status": "NO_SUCCESS_EVIDENCE", "rc": rc,
                "timeout": timeout_seconds, "log_path": log_path,
                "reason": ("rc=0 but no suite-specific success evidence with "
                           "equal positive counts matched (success evidence "
                           "required, exit code alone is not trust)")}
    return {"suite": suite, "status": "PASS", "rc": rc,
            "timeout": timeout_seconds, "log_path": log_path}


def run_boot(godot_bin, repo_root, log_path, timeout_seconds):
    """Boot phase: quit-after 3 frames; any SCRIPT ERROR fails even on rc=0."""
    cmd = [godot_bin, "--headless", "--path", repo_root,
           "--quit-after", "3", "--", "--test-mode"]
    with open(log_path, "wb") as logf:
        logf.write(("$ %s\n" % " ".join(cmd)).encode("utf-8"))
        logf.flush()
        started = time.monotonic()
        proc = subprocess.Popen(
            cmd, stdout=logf, stderr=subprocess.STDOUT,
            cwd=repo_root, start_new_session=True)
        try:
            rc = proc.wait(timeout=timeout_seconds)
            timed_out = False
        except subprocess.TimeoutExpired:
            _kill_process_group(proc)
            rc = None
            timed_out = True
        duration = time.monotonic() - started
    with open(log_path, "ab") as logf:
        logf.write(("\n[runner] rc=%s timed_out=%s duration=%.1fs timeout=%ss\n"
                    % (rc, timed_out, duration, timeout_seconds)).encode("utf-8"))
    with open(log_path, "r", errors="replace") as f:
        output = f.read()
    result = {"suite": "BOOT", "rc": rc, "timeout": timeout_seconds,
              "log_path": log_path}
    if timed_out:
        result["status"] = "TIMEOUT"
        result["reason"] = "boot timed out after %ss" % timeout_seconds
        return result
    hard = scan_for_hard_errors(output)
    if hard:
        result["status"] = "HARD_ERROR"
        result["reason"] = "boot script errors present despite rc=%s" % rc
        result["error_lines"] = hard[:5]
        return result
    if rc != 0:
        result["status"] = "NONZERO_EXIT"
        result["reason"] = "boot exited with rc=%s" % rc
        return result
    result["status"] = "PASS"
    return result


def run_import(godot_bin, repo_root, log_path, timeout_seconds):
    """Fresh-asset import phase: godot --import generates .import metadata
    (models/*.import are gitignored by policy) and the .godot cache. Without
    this a fresh clone fails every GLB-loading suite (e.g. box_stack.glb).
    Failure here is a FAILURE, never a silent skip."""
    cmd = [godot_bin, "--headless", "--path", repo_root, "--import"]
    with open(log_path, "wb") as logf:
        logf.write(("$ %s\n" % " ".join(cmd)).encode("utf-8"))
        logf.flush()
        started = time.monotonic()
        proc = subprocess.Popen(
            cmd, stdout=logf, stderr=subprocess.STDOUT,
            cwd=repo_root, start_new_session=True)
        try:
            rc = proc.wait(timeout=timeout_seconds)
            timed_out = False
        except subprocess.TimeoutExpired:
            _kill_process_group(proc)
            rc = None
            timed_out = True
        duration = time.monotonic() - started
    with open(log_path, "ab") as logf:
        logf.write(("\n[runner] rc=%s timed_out=%s duration=%.1fs timeout=%ss\n"
                    % (rc, timed_out, duration, timeout_seconds)).encode("utf-8"))
    result = {"suite": "IMPORT", "rc": rc, "timeout": timeout_seconds,
              "log_path": log_path}
    if timed_out:
        result["status"] = "TIMEOUT"
        result["reason"] = "import timed out after %ss" % timeout_seconds
        return result
    result["status"] = "PASS" if rc == 0 else "FAIL"
    if rc != 0:
        result["reason"] = "import exited rc=%s" % rc
    return result


def run_ladder(godot_bin=None, log_dir=None, timeout_seconds=None,
               suites=None, include_boot=True, repo_root=None):
    """Run the full serial ladder. Returns (exit_code, run_dir, results)."""
    env = os.environ
    godot_bin = godot_bin or env.get("GODOT_BIN", DEFAULT_GODOT)
    log_dir = log_dir or env.get("FE_LADDER_LOG_DIR", DEFAULT_LOG_DIR)
    # NOTE: no `timeout_seconds or env` fallback here — timeout_seconds=0 must
    # be REJECTED by validate_config, never silently replaced by the default.
    if timeout_seconds is None:
        timeout_seconds = env.get(
            "FE_LADDER_TIMEOUT_SECONDS", DEFAULT_TIMEOUT_SECONDS)
    repo_root = repo_root or REPO_ROOT
    suites = suites if suites is not None else resolve_suite_list(env)
    # CONFIG VALIDATION FIRST, before any state is created (no log directory
    # side effects from an invalid configuration).
    timeout_seconds = validate_config(suites, timeout_seconds)
    # Fresh run dir every time: a stale prior PASS can never satisfy a new run.
    run_dir = _fresh_run_dir(log_dir)

    verify_godot_binary(godot_bin)

    results = []
    overall = 0
    # Import phase FIRST (2026-09-27: fresh clones failed GLB suites because
    # models/*.import are gitignored — the cache must be generated locally).
    import_log = os.path.join(run_dir, "import.log")
    res = run_import(godot_bin, repo_root, import_log, timeout_seconds)
    results.append(res)
    print("=== IMPORT %s ===" % res["status"])
    if res["status"] != "PASS":
        print("    reason: %s" % res.get("reason", ""))
        print("    log: %s" % res["log_path"])
        overall = 1
    for suite in suites:
        log_path = os.path.join(run_dir, "suite-%s.log" % suite)
        res = run_suite(godot_bin, repo_root, suite, log_path, timeout_seconds)
        results.append(res)
        print("=== %s %s ===" % (suite, res["status"]))
        if res["status"] != "PASS":
            print("    reason: %s" % res.get("reason", ""))
            for line in res.get("error_lines", []):
                print("    %s" % line)
            print("    log: %s" % res["log_path"])
            overall = 1
    if include_boot:
        boot_log = os.path.join(run_dir, "boot.log")
        res = run_boot(godot_bin, repo_root, boot_log, timeout_seconds)
        results.append(res)
        print("=== BOOT %s ===" % res["status"])
        if res["status"] != "PASS":
            print("    reason: %s" % res.get("reason", ""))
            for line in res.get("error_lines", []):
                print("    %s" % line)
            print("    log: %s" % res["log_path"])
            overall = 1
    return overall, run_dir, results


def main(argv):
    import argparse
    ap = argparse.ArgumentParser(description="Trustworthy serial test ladder.")
    ap.add_argument("--log-dir", default=None,
                    help="override FE_LADDER_LOG_DIR")
    ap.add_argument("--timeout", type=int, default=None,
                    help="override FE_LADDER_TIMEOUT_SECONDS")
    ap.add_argument("--suites", nargs="*", default=None,
                    help="explicit suite subset (test seam; default = full "
                         "production manifest, never silently omits suites)")
    ap.add_argument("--no-boot", action="store_true",
                    help="skip the boot phase")
    ap.add_argument("--godot", default=None, help="override GODOT_BIN")
    ap.add_argument("--repo-root", default=None,
                    help="TEST SEAM ONLY: repo root to run suites in "
                         "(default: the repo containing this runner)")
    args = ap.parse_args(argv)
    try:
        rc, run_dir, results = run_ladder(
            godot_bin=args.godot, log_dir=args.log_dir,
            timeout_seconds=args.timeout, suites=args.suites,
            include_boot=not args.no_boot, repo_root=args.repo_root)
    except LadderConfigError as exc:
        print("CONFIG ERROR: %s" % exc, file=sys.stderr)
        return 2
    passed = sum(1 for r in results if r["status"] == "PASS")
    verdict = "PASS" if rc == 0 else "FAIL"
    # Denominator is ALWAYS the production manifest, never the env-resolved
    # selection: a FE_LADDER_SUITES subset in the environment must be labelled
    # SUBSET, not silently promoted to a full-manifest result.
    production = list(PRODUCTION_SUITES)
    selected = (args.suites if args.suites is not None
                else resolve_suite_list(os.environ))
    is_full = (tuple(selected) == tuple(production)
               and not args.no_boot)
    if is_full:
        # FULL result is only ever claimed when the complete production
        # manifest executes, including the boot phase.
        print("\nLADDER RESULT: %s (%d/%d phases passed; %d/%d suites; "
              "boot=yes; logs in %s)"
              % (verdict, passed, len(results), len(selected),
                 len(production), run_dir))
    else:
        # Anything narrower is explicitly labelled SUBSET with ACTUAL totals
        # (suites actually selected vs the real production manifest length).
        print("\nSUBSET RESULT: %s (%d of %d suites executed; %d/%d phases "
              "passed; boot=%s; logs in %s)"
              % (verdict, len(selected), len(production), passed,
                 len(results), "no" if args.no_boot else "yes", run_dir))
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
