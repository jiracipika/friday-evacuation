# Menu & UI Redesign — Sep 22 2026

Owner: Astra (design) + GLM 5.3 (implementation). Scope: Main menu and all
menu subviews (modes, settings, ride, office, friends, credits), in-game
overlays (pause, controls/how-to-play, results, HUD accents), one visual
system.

## Survey evidence (10 captures, /tmp/fe-ui/redesign0/)

Screens captured: menu-main, modes, settings, customize, office, friends,
credits, gameplay, paused, controls (how-to-play), results (captured the
controls modal; results panel itself still unstyled S5).

### What works (keep)
- Dark navy + single orange accent identity; orange = selected/primary/GO.
- Sunset skyline through office-window mullions (environmental storytelling).
- List -> detail -> confirm IA on modes; persistent YOUR RIDE preview.
- Dimmed modal backdrop pattern; pinned BACK.
- Flavor copy personality.

### What fails (fix)
F1 Slider tracks invisible (dots floating, no rail/fill) — reads as a bug.
F2 Dead space / bottom-heavy panels; uneven vertical rhythm (17-38px gaps).
F3 Inconsistent corner radii (pill CTA vs card radius vs square BACK).
F4 No elevation: flat panels, no shadows, border does all separation.
F5 CTA contrast weak (cream on orange ~2:1) or CTA under-accented
   (How-to-Play START button is the least orange thing on screen).
F6 Cryptic tags ("DELIVERY PLAYABLE"); redundant heading repeats badge.
F7 Micro-text too small/low-contrast (9px captions, gray on near-black).
F8 Run-on stat line "JUMP x1.00 GRIP x1.00 BOOST x1.00" — needs chips.
F9 Em-dash + all-caps saturation flattens hierarchy.
F10 Backdrop seams: mullions read as artifacts; sun clipped by panel edge;
    unfinished top strip; YOUR RIDE card aligns to nothing.
F11 Settings label/control patterns inconsistent (above vs left vs 33px gap);
    right edges unsnapped; scrollbar hugging border.

## Design directions (boards in this dir)

- variant-a.html "DEPARTURE BOARD" — evolution: keeps current architecture,
  fixes F1-F11 within it. Token refresh, elevation system, rhythm scale,
  stat chips, real signage tags, finished window frame.
- variant-b.html "SAFETY CARD" — bolder: emergency-signage-first. Big
  high-contrast panels, stencil display type, floor-plan iconography,
  orange used ONLY for actions. More work, bigger payoff.

Iteration protocol: render both at 1440x810 + 390x844, critique, merge
winner traits into final-spec.md, implement against it.
