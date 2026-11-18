"""Reproducible overhaul gates. Fail on Godot errors even when it exits zero."""
import subprocess, pathlib, sys, os
ROOT = pathlib.Path(__file__).resolve().parents[2]
GODOT = os.environ.get('GODOT_BIN', 'godot')
def run(script, *arguments):
    command = [GODOT, '--headless', '--path', str(ROOT), '--fixed-fps', '60', '--script', script, '--', '--test-mode', *arguments]
    result = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
    print(result.stdout, flush=True)
    if result.returncode or 'SCRIPT ERROR' in result.stdout or '\nERROR:' in result.stdout:
        raise SystemExit('Overhaul check failed: ' + script + ' ' + ' '.join(arguments))
run('tools/overhaul/VisualRedesignCheck.gd')
run('tools/overhaul/AssetCheck.gd')
run('tools/overhaul/MotorCheck.gd')
for mode in ['hauled', 'seek', 'pizza']:
    run('tools/overhaul/ModeCheck.gd', mode)
for layout in ['open_plan', 'cubicle_maze', 'executive']:
    # Layout is positional in the simulation probe.
    result = subprocess.run([GODOT, '--headless', '--path', str(ROOT), '--fixed-fps', '60', '--script', 'tools/overhaul/SimulationCheck.gd', '--', layout, '--test-mode'], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
    print(result.stdout, flush=True)
    if result.returncode or 'SCRIPT ERROR' in result.stdout or '\nERROR:' in result.stdout: raise SystemExit('Course simulation failed: ' + layout)
subprocess.run([sys.executable, str(ROOT/'tools/overhaul/check_network.py')], check=True, timeout=45)
print('FRIDAY_OVERHAUL_VERIFIED')
