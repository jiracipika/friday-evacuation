"""Real separate-process ENet late-join, prediction and version-refusal check."""
import subprocess, time, pathlib, os, sys
ROOT = pathlib.Path(__file__).resolve().parents[2]
BASE = ['godot', '--headless', '--path', str(ROOT), '--script', 'tools/overhaul/NetworkCheck.gd', '--']
mode = sys.argv[1] if len(sys.argv) > 1 else 'evacuation'
processes = []
try:
    with open('/tmp/friday-network-host.log', 'w') as host_log:
        host = subprocess.Popen(BASE + ['host', mode], stdout=host_log, stderr=subprocess.STDOUT)
        processes.append(host)
        deadline = time.monotonic() + 8
        while 'HOST_READY' not in pathlib.Path(host_log.name).read_text():
            if host.poll() is not None or time.monotonic() > deadline:
                raise RuntimeError('Host did not become ready')
            time.sleep(.1)
        # Join a round already in progress, rather than only testing the lobby.
        time.sleep(4)
        with open('/tmp/friday-network-client.log', 'w') as log:
            client = subprocess.Popen(BASE + ['client', mode], stdout=log, stderr=subprocess.STDOUT)
            processes.append(client)
            if client.wait(timeout=15): raise RuntimeError('Prediction/late join failed')
        with open('/tmp/friday-network-version.log', 'w') as log:
            bad = subprocess.Popen(BASE + ['incompatible', mode], stdout=log, stderr=subprocess.STDOUT)
            processes.append(bad)
            if bad.wait(timeout=10): raise RuntimeError('Version refusal failed')
        if host.wait(timeout=10): raise RuntimeError('Host authority failed')
    for name in ['host', 'client', 'version']:
        text = pathlib.Path('/tmp/friday-network-' + name + '.log').read_text()
        print(text)
        if 'SCRIPT ERROR' in text or '\nERROR:' in text: raise RuntimeError('Godot runtime error')
    print('OFFICE_NETWORK_PASS')
finally:
    for process in processes:
        if process.poll() is None: process.kill()
