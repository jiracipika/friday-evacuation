"""Offline Godot lightmaps. Requires a working Vulkan editor and display.

The runtime/export renderer stays GL Compatibility. Enable the automation
plugin only for the bake process and always restore the project's settings.
"""
import os, pathlib, subprocess
ROOT = pathlib.Path(__file__).resolve().parents[2]
PROJECT = ROOT/'project.godot'
GODOT = os.environ.get('GODOT_BIN', 'godot')
original = PROJECT.read_bytes()
try:
    if b'[editor_plugins]' in original:
        raise SystemExit('Temporarily disable existing editor plugins before running the offline baker.')
    PROJECT.write_bytes(original + b'\n[editor_plugins]\n\nenabled=PackedStringArray("res://addons/office_baker/plugin.cfg")\n')
    for layout in ['open_plan', 'cubicle_maze', 'executive']:
        subprocess.run([GODOT, '--headless', '--path', str(ROOT), '--script', 'tools/overhaul/BakeCourses.gd', '--', layout], check=True, timeout=120)
        subprocess.run([GODOT, '--path', str(ROOT), '--editor', '--rendering-method', 'mobile', '--', '--bake-office', layout], check=True, timeout=900)
finally:
    PROJECT.write_bytes(original)
