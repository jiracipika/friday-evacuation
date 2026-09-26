# S-H RESULTS — Lobby + Credits (spec section 7 remainder)

Implementer: GLM 5.3 Flash, 2026-09-26, canonical repo
(/Volumes/SERVER/sol-workspace/repos/friday-evacuation). Base: 3c11ff4.

## Scope

The last two spec-section-7 screens move onto the After-Hours system:

- **Lobby.gd**: tape header, white title, muted autowrap status, ORANGE
  section micro-headers (IDENTITY / JOIN BY ADDRESS via
  UITheme.make_section_header), styled dark LineEdits with ORANGE focus
  (_style_edit helper), HOST on apply_primary (orange), JOIN secondary
  (cyan), SCAN + BACK utility, READY secondary (LIME), START primary.
  Behavior, node contract, and Network wiring untouched.
- **CreditsScreen.gd**: panel + tape header replaces the bare centered
  column; PAPER brand line, TEXT body, violet utility BACK; explicit
  grow BOTH on the centered panel (CanvasLayer-adjacent centering trap).

## Real bug found and fixed (measured, not guessed)

The lobby content minimum is ~858px tall but the panel sat at y=140 in
a 720px viewport — READY UP / START MATCH (HOST) / BACK were BELOW THE
FOLD and unreachable at 720p, pre-dating this restyle (measured with a
geometry probe: panel rect 540x858 at y=140). Fix: the panel now pins
to the viewport height minus 20px margins and everything below the
header scrolls (LobbyScroll, the same pattern Settings uses). Probe
after: panel 540x680 at y=20, fully inside the viewport.

## Verification

- MenuDepartureSmokeTest 112/112 (+5 S-H checks: lobby tape, LobbyScroll
  presence, panel fits viewport, HOST reads as the primary orange,
  credits tape).
- LanAvatarSyncTest 21/21, NetworkTwoPeerTest PASSED (lobby flows),
  MenuLayoutSmokeTest 23/23, MenuHomeRedesignTest 8/8.
- Vision QA: probe movie frames — lobby renders the full system with a
  visible scrollbar and all controls reachable; credits renders the
  centered taped panel.
- Full ladder: PASS 61/61 (60 suites + boot), run-20260926-134418.

## Notes

- Credits role headers share one label with their names (both TEXT) —
  splitting into per-line orange micro-caps was skipped as visually
  unnecessary in the frame review.
- With this slice, every FINAL-SPEC section-7 screen has the system;
  the remaining known work is hardware/device QA (touch, LAN, pads).
