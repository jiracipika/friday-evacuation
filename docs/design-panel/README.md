# Friday design panel

Open `index.html` directly in a browser; no server or external dependencies are needed. Keep this directory together when copying it.

Three concept directions: After-hours dusk (recommended), Toybox office, Corporate emergency. Each has HUD/signage specimens, material shape samples, a palette, and Godot translation guidance. Preview boost toggles READY/ACTIVE; Copy recipe uses clipboard or text-selection fallback; Export Godot palette downloads a valid .gd helper. The generated palette files are also included for convenience; none is wired into the game.

The image labeled CURRENT GODOT BUILD is a real unmodified engine capture, with the opening controls overlay visible. Other specimens are HTML concepts, not game renders. No gameplay/runtime code changed. Direction approval remains pending; no choice has been silently applied.

## Verification

`verification.json`: three directions at 1440 and 390 pixels; no horizontal overflow, baseline image loads, three navigation links, boost/reset behavior, clipboard fallback, exported Blob contents; zero Runtime exceptions. Six screenshots under captures/. Parent visually reviewed desktop dusk/emergency and narrow toybox.

Regenerate pages: `python3 docs/design-panel/build_panel.py` from the repo root. Baseline is preserved.

Browser verification: run Chrome headless with remote-debugging-port=9337, remote-allow-origins=http://localhost:9337, and an isolated user-data-dir. Run `verify_panel.py` using a Python environment with websocket-client installed. It writes screenshots, verifies the download Blob, and closes that dedicated browser. Do not point it at a personal browser session.

Palette verification: `godot --headless --path . --script docs/design-panel/dusk_palette.gd --check-only` (repeat for toybox/emergency).

## Next, after user chooses

Apply selected direction as a bounded Godot slice: quieter wall/floor materials, existing-light warm/cool tuning, unified route signage and compact HUD. Retain collision, camera and elevator geometry. Run the full game ladder plus real before/after engine frames. This panel is a template, not completion of the game-wide art pass.
