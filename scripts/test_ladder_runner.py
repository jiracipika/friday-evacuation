#!/usr/bin/env python3
"""test_ladder_runner.py — unittest harness for the trustworthy serial ladder
runner (P0A).

IMPORTANT SCOPE DISTINCTION
---------------------------
Every test below drives a TEMPORARY FAKE "godot" executable (a tiny shell
script) against synthetic fixture suites. These are SYNTHETIC FIXTURES that
verify runner supervision behaviour only (timeout, log isolation, success
evidence scanning, missing-suite failure, boot-error detection). They are NOT
real game validation and MUST NOT be read as such. No claim is made here that
real game tests have been run; real Godot validation status is tracked in
docs/ui-continuation/STATUS.md (REAL_GAME_VALIDATION_PENDING until the parent
independently serializes a real menu/loading/boot run and records it in
docs/ui-continuation/results/P0A.md under real log paths).

Run:  python3 scripts/test_ladder_runner.py -v
"""

import os
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(HERE)
RUNNER = os.path.join(HERE, "ladder_runner.py")
OLD_RUNNER = os.path.join(HERE, "run_ladder.sh")

FAKE_GODOT = r"""#!/bin/bash
# Fake godot for runner supervision tests (SYNTHETIC FIXTURE, not the game).
# Behaviour driven by the requested --script argument and $FAKE_MODE.
script=""
prev=""
for a in "$@"; do
  if [ "$prev" = "--script" ]; then script="$a"; fi
  prev="$a"
done
if [ "$script" = "__BOOT__" ] || [ -z "$script" ]; then
  # boot phase invocation
  echo "Godot Engine v4.2.1.official.4c9f2dc - https://godotengine.org"
  echo "boot banner ok"
  if [ "$FAKE_MODE" = "boot-script-error" ]; then
    echo "SCRIPT ERROR: boot failed to load scene"   # zero-exit boot error
    exit 0
  fi
  exit 0
fi
case "$FAKE_MODE" in
  "")            echo "=== ALL CHECKS PASSED ($script) ==="; exit 0 ;;
  script-error)  echo "SCRIPT ERROR: Parse Error: bad index in $script.gd:12"; exit 0 ;;
  hang)          sleep 600; exit 0 ;;
  nonzero)       echo "=== ALL CHECKS PASSED ($script) ==="; exit 3 ;;
  fail-banner)   echo "=== SOME CHECKS FAILED ==="; exit 1 ;;
  pass-then-error)
                 echo "=== ALL CHECKS PASSED ($script) ==="
                 echo "SCRIPT ERROR: leaked error after success banner"
                 exit 0 ;;
  rc0-silent)    echo "noise output only, no banner, no errors"; exit 0 ;;
  hero-fail-marker)
                 # Real HeroAssemblySmokeTest shape: per-check [FAIL] lines plus
                 # a summary; failure via exit code only. Our fake exits 0 to
                 # prove the runner must detect the [FAIL] marker itself.
                 echo "[PASS] hero_assembly.glb loads"
                 echo "[FAIL] final check"
                 echo "HeroAssemblySmokeTest: 5 checks, 1 failures"
                 exit 0 ;;
  numeric-fail)  echo "LoadingFlowSmokeTest: 1/10 checks passed"; exit 0 ;;
  *)             echo "unknown FAKE_MODE $FAKE_MODE" >&2; exit 9 ;;
esac
"""


def _write(path, content, executable=True):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(content)
    if executable:
        st = os.stat(path)
        os.chmod(path, st.st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


class LadderRunnerHarness(unittest.TestCase):
    """Synthetic-fixture supervision tests for scripts/ladder_runner.py."""

    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="ladder-harness-")
        self.godot = os.path.join(self.tmp, "bin", "fake-godot")
        _write(self.godot, FAKE_GODOT)
        self.repo = os.path.join(self.tmp, "repo")
        self.log_dir = os.path.join(self.tmp, "logs")
        os.makedirs(os.path.join(self.repo, "scripts"))
        # Fixture suite that "passes" by default.
        self.suite = "FakeSuiteA"
        _write(os.path.join(self.repo, "scripts", self.suite + ".gd"),
               "# synthetic fixture suite\n", executable=False)
        # Mirror the shell wrapper INTO the fixture repo: run_ladder.sh
        # self-locates its repo root from its own path, so a copy inside the
        # fixture gates the fixture (not the production checkout).
        self.old_runner = os.path.join(self.repo, "scripts", "run_ladder.sh")
        shutil.copyfile(OLD_RUNNER, self.old_runner)
        shutil.copyfile(RUNNER, os.path.join(self.repo, "scripts", "ladder_runner.py"))
        os.chmod(self.old_runner, os.stat(self.old_runner).st_mode
                 | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def _add_fixture(self, suite, mode_unused=None):
        """Add a synthetic fixture suite script to the fake repo."""
        _write(os.path.join(self.repo, "scripts", suite + ".gd"),
               "# synthetic fixture suite %s\n" % suite, executable=False)

    def _manifest_len(self):
        sys.path.insert(0, HERE)
        import ladder_runner
        return len(ladder_runner.PRODUCTION_SUITES)

    def _add_git_repo(self):
        """Turn the synthetic fixture repo into a minimal real git repo so the
        restored git diff --check gate can be exercised end-to-end without
        touching the production checkout."""
        subprocess.run(["git", "init", "-q"], cwd=self.repo, check=True,
                       capture_output=True)
        subprocess.run(["git", "config", "user.email", "harness@example.com"],
                       cwd=self.repo, check=True, capture_output=True)
        subprocess.run(["git", "config", "user.name", "harness"],
                       cwd=self.repo, check=True, capture_output=True)
        subprocess.run(["git", "add", "-A"], cwd=self.repo, check=True,
                       capture_output=True)
        subprocess.run(["git", "commit", "-qm", "fixture base"], cwd=self.repo,
                       check=True, capture_output=True)

    def _run(self, extra_env=None, suites=None, boot=True, runner=RUNNER):
        # --repo-root is a DOCUMENTED TEST SEAM (production CLI defaults it to
        # the real repo; production defaults never omit suites).
        env = dict(os.environ)
        env["GODOT_BIN"] = self.godot
        env["FE_LADDER_LOG_DIR"] = self.log_dir
        env["FE_LADDER_TIMEOUT_SECONDS"] = "5"
        env.pop("FE_LADDER_SUITES", None)
        if extra_env:
            env.update(extra_env)
        # Shell wrappers must run under bash, not sys.executable (that fed the
        # .sh script to Python and died with a SyntaxError).
        cmd = ([ "bash", runner] if runner.endswith(".sh") else [sys.executable, runner]) + [
               "--repo-root", self.repo,
               "--godot", self.godot,
               "--log-dir", self.log_dir,
               "--timeout", "5"]
        cmd += ["--suites"] + (suites if suites is not None else [self.suite])
        if not boot:
            cmd.append("--no-boot")
        # The shell wrapper is a THIN gate (git diff --check) that forwards all
        # arguments to ladder_runner.py, so the same CLI flags work through it.
        return subprocess.run(cmd, env=env, capture_output=True,
                              text=True, timeout=120)

    # --- 1. success --------------------------------------------------------
    def test_success_passes(self):
        r = self._run()
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("=== FakeSuiteA PASS ===", r.stdout)
        self.assertIn("=== BOOT PASS ===", r.stdout)

    # --- 2. zero-exit SCRIPT ERROR ----------------------------------------
    def test_zero_exit_script_error_fails(self):
        r = self._run(extra_env={"FAKE_MODE": "script-error"})
        self.assertEqual(r.returncode, 1, r.stdout)
        self.assertIn("FakeSuiteA HARD_ERROR", r.stdout)

    def test_pass_banner_with_late_script_error_fails(self):
        r = self._run(extra_env={"FAKE_MODE": "pass-then-error"})
        self.assertEqual(r.returncode, 1, r.stdout)
        self.assertIn("FakeSuiteA HARD_ERROR", r.stdout)

    # --- 3. missing required suite ----------------------------------------
    def test_missing_required_suite_fails_not_skips(self):
        r = self._run(suites=["NoSuchSuite"])
        self.assertEqual(r.returncode, 1, r.stdout)
        self.assertIn("NoSuchSuite MISSING", r.stdout)
        self.assertNotIn("skipped", r.stdout.lower())

    # --- 4. boot error (zero exit + SCRIPT ERROR) --------------------------
    def test_boot_script_error_fails_despite_zero_exit(self):
        r = self._run(extra_env={"FAKE_MODE": "boot-script-error"})
        self.assertEqual(r.returncode, 1, r.stdout)
        self.assertIn("BOOT HARD_ERROR", r.stdout)

    # --- 5. timeout ---------------------------------------------------------
    def test_timeout_fails(self):
        r = self._run(extra_env={"FAKE_MODE": "hang"})
        self.assertEqual(r.returncode, 1, r.stdout)
        self.assertIn("FakeSuiteA TIMEOUT", r.stdout)

    # --- 6. stale prior PASS cannot pass a new run --------------------------
    def test_stale_pass_log_never_satisfies_new_run(self):
        # A fresh run must create its own unique run directory and must not
        # reuse (or even look at) any prior run's PASS logs.
        r1 = self._run()
        self.assertEqual(r1.returncode, 0, r1.stdout)
        runs = sorted(d for d in os.listdir(self.log_dir))
        self.assertEqual(len(runs), 1)
        # Poison: remove the suite log entirely and plant a fake PASS marker
        # from an "old" run; then run a suite that now hangs.
        old_run = os.path.join(self.log_dir, runs[0])
        with open(os.path.join(old_run, "suite-FakeSuiteA.log"), "a") as f:
            f.write("[runner] rc=0 timed_out=False (STALE PRIOR PASS)\n")
        r2 = self._run(extra_env={"FAKE_MODE": "hang"})
        self.assertEqual(r2.returncode, 1, r2.stdout)
        self.assertIn("TIMEOUT", r2.stdout)
        runs2 = sorted(d for d in os.listdir(self.log_dir))
        self.assertEqual(len(runs2), 2, "new run must get its own log dir")
        self.assertNotEqual(runs[0], runs2[-1])

    # --- 7. nonzero exit ----------------------------------------------------
    def test_nonzero_exit_fails_even_with_pass_banner(self):
        r = self._run(extra_env={"FAKE_MODE": "nonzero"})
        self.assertEqual(r.returncode, 1, r.stdout)
        self.assertIn("FakeSuiteA NONZERO_EXIT", r.stdout)

    def test_failure_banner_fails(self):
        r = self._run(extra_env={"FAKE_MODE": "fail-banner"})
        # Correct failure is SUITE_FAILURE_MARKER at rc=1; any explicit failure
        # status is acceptable — what is FORBIDDEN is a PASS or rc=0. Never
        # weaken failure detection by insisting on a specific status label.
        self.assertEqual(r.returncode, 1, r.stdout)
        self.assertIn("FakeSuiteA", r.stdout)
        self.assertNotIn("FakeSuiteA PASS", r.stdout)
        self.assertIn("SUITE_FAILURE_MARKER", r.stdout)

    # --- 8. missing success evidence despite rc=0 ---------------------------
    def test_rc0_without_success_evidence_fails(self):
        # FAKE_MODE=script-error also suppresses the success banner and exits 0
        # with a SCRIPT ERROR -> HARD_ERROR; here we need rc=0, no banner,
        # no error lines: use a dedicated mode via env not covered above, so
        # reuse "unknown" mode (rc 9) instead for nonzero, and craft rc0-silent
        # by pointing at a fixture that only prints noise.
        r = self._run(extra_env={"FAKE_MODE": "rc0-silent"})
        self.assertEqual(r.returncode, 1, r.stdout)
        self.assertIn("FakeSuiteA", r.stdout)
        self.assertNotIn("FakeSuiteA PASS ===", r.stdout)

    # --- 9. combined stdout+stderr log with command/rc/timeout --------------
    def test_log_contains_command_rc_and_timeout(self):
        # bogus mode writes to stderr and exits 9: verifies the combined log
        # captures stderr, explicit rc and timeout.
        r = self._run(extra_env={"FAKE_MODE": "bogus"})
        self.assertEqual(r.returncode, 1)
        runs = sorted(os.listdir(self.log_dir))
        log = os.path.join(self.log_dir, runs[-1], "suite-FakeSuiteA.log")
        with open(log) as f:
            content = f.read()
        self.assertIn("$ ", content)            # explicit command line
        self.assertIn("fake-godot", content)
        self.assertIn("rc=9", content)           # explicit rc
        self.assertIn("timeout=5s", content)     # explicit timeout
        # stderr-only output must also land in the combined log:
        self.assertIn("unknown FAKE_MODE", content)

    # --- 10. runner wrapper + benign teardown preserved ---------------------
    def test_run_ladder_sh_wrapper_delegates_to_python(self):
        # The production entrypoint must be the repaired runner (checks the
        # shell wrapper execs the Python supervisor and honours GODOT_BIN).
        r = self._run(runner=OLD_RUNNER, extra_env={"FAKE_MODE": "nonzero"})
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn("FakeSuiteA NONZERO_EXIT", r.stdout)

    def test_benign_teardown_warning_not_fatal(self):
        # The default fake boot emits only normal banner output; BOOT must
        # PASS. (Benign-warning whitelist itself is covered by the
        # scan_for_hard_errors unit checks below.)
        r = self._run(extra_env={"FAKE_MODE": ""})
        self.assertEqual(r.returncode, 0, r.stdout)

    # --- 11. production defaults never silently omit suites ------------------
    def test_production_manifest_includes_new_suites(self):
        sys.path.insert(0, HERE)
        import ladder_runner
        self.assertIn("MenuDepartureSmokeTest", ladder_runner.PRODUCTION_SUITES)
        self.assertIn("LoadingFlowSmokeTest", ladder_runner.PRODUCTION_SUITES)
        self.assertIn("BootTest", ladder_runner.PRODUCTION_SUITES)
        self.assertEqual(
            len(ladder_runner.PRODUCTION_SUITES),
            len(set(ladder_runner.PRODUCTION_SUITES)),
            "duplicate suites in manifest")

    # --- 12. review-fix regressions -----------------------------------------
    def test_numeric_success_requires_equal_positive_passed_total(self):
        # LoadingFlowSmokeTest-style summary: a FAILING summary (1/10) must not
        # satisfy the success requirement merely by regex shape. The SEMANTIC
        # gate is success_evidence_matches (equal positive counts required) —
        # test THAT function, plus the end-to-end runner behaviour.
        sys.path.insert(0, HERE)
        import ladder_runner
        self.assertFalse(
            ladder_runner.success_evidence_matches(
                "LoadingFlowSmokeTest", "LoadingFlowSmokeTest: 1/10 checks passed"),
            "1/10 must not match success evidence")
        self.assertFalse(
            ladder_runner.success_evidence_matches(
                "LoadingFlowSmokeTest", "LoadingFlowSmokeTest: 0/0 checks passed"),
            "0/0 must not match success evidence")
        self.assertTrue(
            ladder_runner.success_evidence_matches(
                "LoadingFlowSmokeTest", "LoadingFlowSmokeTest: 10/10 checks passed"))
        # Numeric N/M patterns that ARE regex-matched by shape must still be
        # rejected semantically — across the whole table.
        for name, pats in ladder_runner.SUCCESS_PATTERNS.items():
            for p in pats:
                if p.groups == 2:  # numeric N/M pattern
                    failing = "%s: 3/7 checks passed" % name
                    self.assertTrue(
                        p.search(failing) is not None or True)  # shape may match
                    self.assertFalse(
                        ladder_runner.success_evidence_matches(name, failing),
                        "%s N/M pattern semantically accepts failing counts" % name)
                    self.assertFalse(
                        ladder_runner.success_evidence_matches(
                            name, "%s: 0/0 checks passed" % name),
                        "%s semantically accepts zero checks" % name)
        # End-to-end: a numeric-failing summary with rc=0 must FAIL the run.
        self._add_fixture("LoadingFlowSmokeTest", "numeric-fail")
        r = self._run(suites=["LoadingFlowSmokeTest"],
                      extra_env={"FAKE_MODE": "numeric-fail"})
        self.assertEqual(r.returncode, 1, r.stdout)
        self.assertIn("LoadingFlowSmokeTest", r.stdout)
        self.assertNotIn("LoadingFlowSmokeTest PASS", r.stdout)

    def test_hero_assembly_fail_marker_fails_despite_rc0(self):
        # Real HeroAssemblySmokeTest prints per-check "[FAIL] <label>" lines and
        # reports failure via exit code only. A zero exit with a [FAIL] line and
        # a success-shaped line must NOT count as a suite PASS.
        sys.path.insert(0, HERE)
        import ladder_runner
        out = ("[PASS] hero_assembly.glb loads\n"
               "[FAIL] final check\n"
               "HeroAssemblySmokeTest: 5 checks, 1 failures\n")
        self.assertEqual(ladder_runner.scan_for_suite_failures(
            "HeroAssemblySmokeTest", out),
            ["[FAIL] final check"])
        # ...and end-to-end through a real runner subprocess: rc=0 but the
        # suite must FAIL.
        self._add_fixture("HeroAssemblySmokeTest", "hero-fail-marker")
        r = self._run(suites=["HeroAssemblySmokeTest"],
                      extra_env={"FAKE_MODE": "hero-fail-marker"})
        self.assertEqual(r.returncode, 1, r.stdout)
        self.assertIn("HeroAssemblySmokeTest", r.stdout)
        self.assertNotIn("HeroAssemblySmokeTest PASS", r.stdout)

    def test_warning_containing_script_error_is_hard_error(self):
        sys.path.insert(0, HERE)
        import ladder_runner
        hits = ladder_runner.scan_for_hard_errors(
            "WARNING: leaked SCRIPT ERROR: real failure")
        self.assertEqual(len(hits), 1, "SCRIPT ERROR must never be whitelisted")
        self.assertIn("SCRIPT ERROR", hits[0])
        # Parse Error likewise:
        hits = ladder_runner.scan_for_hard_errors(
            "WARNING: something Parse Error: bad line")
        self.assertEqual(len(hits), 1)
        # Whitelist still honours genuinely benign teardown lines.
        self.assertEqual(ladder_runner.scan_for_hard_errors(
            "WARNING: ResourceStillAllocated: 2"), [])
        self.assertEqual(ladder_runner.scan_for_hard_errors(
            "ERROR: ResourceStillAllocated: 2"), [])
        # Arbitrary Condition / index-error lines are NOT blanket-whitelisted.
        self.assertEqual(
            len(ladder_runner.scan_for_hard_errors(
                "WARNING: Condition \"!err\" is true with SCRIPT ERROR inside")),
            1)

    def test_diff_check_gate_restored_in_wrapper(self):
        with open(OLD_RUNNER) as f:
            body = f.read()
        self.assertIn("git diff --check", body,
                      "run_ladder.sh must restore the git diff --check gate")
        self.assertIn("git rev-parse", body,
                      "gate must detect a real git checkout (skip in synthetic "
                      "non-repo temp fixtures)")
        # End-to-end: the wrapper must still work from a synthetic fixture dir
        # (not a git repo) without claiming a real gate ran there.
        r = self._run(runner=self.old_runner)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("git diff --check: SKIPPED (not a git work tree)",
                      r.stdout)

    def test_diff_check_gate_runs_in_real_checkout(self):
        # A synthetic mini git repo proves the gate is active and fails the run
        # on whitespace errors, without touching the production checkout.
        self._add_git_repo()
        r = self._run(runner=self.old_runner)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("git diff --check: clean", r.stdout)
        # Now plant a whitespace error and prove the gate fails the run.
        # It must be an UNSTAGED change to a TRACKED file: `git diff --check`
        # compares work tree vs index, so a staged file (or `git add -A`)
        # would keep the gate clean.
        with open(os.path.join(self.repo, "scripts", self.suite + ".gd"),
                  "a") as f:
            f.write("trailing space \n")
        r2 = self._run(runner=self.old_runner)
        self.assertEqual(r2.returncode, 1, r2.stdout + r2.stderr)
        self.assertIn("git diff --check FAILED", r2.stdout + r2.stderr)

    def test_empty_suite_selection_rejected(self):
        r = self._run(suites=[], boot=False)
        self.assertEqual(r.returncode, 2, r.stdout + r.stderr)
        self.assertIn("no suites selected", r.stdout + r.stderr)

    def test_invalid_suite_identifier_rejected(self):
        r = self._run(suites=["../evil;rm"])
        self.assertEqual(r.returncode, 2, r.stdout + r.stderr)
        self.assertIn("invalid suite identifier", r.stdout + r.stderr)

    def test_nonpositive_timeout_rejected(self):
        r = self._run()
        env_cmd = [sys.executable, RUNNER, "--repo-root", self.repo,
                   "--godot", self.godot, "--log-dir", self.log_dir,
                   "--timeout", "0", "--suites", self.suite]
        env = dict(os.environ)
        env["GODOT_BIN"] = self.godot
        r = subprocess.run(env_cmd, env=env, capture_output=True, text=True,
                           timeout=60)
        self.assertEqual(r.returncode, 2, r.stdout + r.stderr)
        self.assertIn("timeout", r.stdout + r.stderr)

    def test_zero_executed_phases_rejected(self):
        # --suites with only zero-weight values plus --no-boot must not be a
        # vacuous full-ladder PASS.
        r = self._run(suites=[], boot=False)
        self.assertEqual(r.returncode, 2, r.stdout + r.stderr)
        self.assertIn("no phases", (r.stdout + r.stderr).lower())

    def test_subset_run_labelled_not_full_pass(self):
        r = self._run(suites=[self.suite], boot=False)
        self.assertEqual(r.returncode, 0, r.stdout)
        self.assertIn("SUBSET", r.stdout)
        self.assertIn("1 of %d" % self._manifest_len(), r.stdout)
        self.assertNotIn("LADDER RESULT: PASS", r.stdout)

    # --- 13. env-subset regression ------------------------------------------
    def test_env_subset_labelled_subset_not_full(self):
        # FE_LADDER_SUITES in the environment (no --suites flag) must also be
        # labelled SUBSET with the production manifest as denominator, and
        # must never be promoted to a full LADDER RESULT.
        env = dict(os.environ)
        env["GODOT_BIN"] = self.godot
        env["FE_LADDER_LOG_DIR"] = self.log_dir
        env["FE_LADDER_TIMEOUT_SECONDS"] = "5"
        env["FE_LADDER_SUITES"] = self.suite
        cmd = [sys.executable, RUNNER,
               "--repo-root", self.repo,
               "--godot", self.godot,
               "--log-dir", self.log_dir,
               "--timeout", "5"]  # NO --suites: env selection drives the run
        r = subprocess.run(cmd, env=env, capture_output=True, text=True,
                           timeout=120)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("=== %s PASS ===" % self.suite, r.stdout)
        self.assertIn("=== BOOT PASS ===", r.stdout)
        self.assertIn("SUBSET", r.stdout)
        self.assertIn("1 of %d" % self._manifest_len(), r.stdout)
        self.assertNotIn("LADDER RESULT", r.stdout)

    # --- 14. banner N/M patterns require equal positive counts ---------------
    def test_banner_numeric_patterns_semantically_validated(self):
        # MenuDepartureSmokeTest / GraphicsPassSmokeTest / MenuLayoutSmokeTest
        # use "=== ... PASS (N/M) ===" banners. Their numeric ratio patterns
        # MUST carry two capture groups so success_evidence_matches can reject
        # failing (1/10) and vacuous (0/0) counts — regex shape alone is not
        # success evidence.
        sys.path.insert(0, HERE)
        import ladder_runner
        # Real banner shapes per SUCCESS_PATTERNS comments (counts substituted).
        banners = {
            "MenuDepartureSmokeTest":
                "=== MENU DEPARTURE SMOKE TEST PASS (%s) ===",
            "GraphicsPassSmokeTest":
                "=== GRAPHICS PASS SMOKE TEST PASS (%s) ===",
            "MenuLayoutSmokeTest":
                "=== MENU LAYOUT SMOKE TEST PASS (%s) ===",
        }
        for name, banner in banners.items():
            pats = ladder_runner.SUCCESS_PATTERNS[name]
            self.assertTrue(
                all(p.groups == 2 for p in pats),
                "%s N/M banner pattern must have two capture groups" % name)
            self.assertFalse(
                ladder_runner.success_evidence_matches(name, banner % "1/10"),
                "%s: 1/10 must not be success evidence" % name)
            self.assertFalse(
                ladder_runner.success_evidence_matches(name, banner % "0/0"),
                "%s: 0/0 must not be success evidence" % name)
            self.assertTrue(
                ladder_runner.success_evidence_matches(name, banner % "10/10"),
                "%s: 10/10 must be success evidence" % name)
        # Table-wide: every pattern containing a numeric N/M shape must carry
        # exactly two capture groups (no uncounted ratios may be added later).
        import re as _re
        for name, pats in ladder_runner.SUCCESS_PATTERNS.items():
            for p in pats:
                if _re.search(r"\\d\+/\\d", p.pattern):
                    self.assertEqual(
                        p.groups, 2,
                        "%s pattern has numeric N/M but %d groups"
                        % (name, p.groups))


if __name__ == "__main__":
    unittest.main(verbosity=2)
