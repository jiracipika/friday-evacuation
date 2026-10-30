"""Fetch only the referenced USD layers for NVIDIA's CC-BY office chair.
No full dataset, simulator binaries, or large source textures are needed.
The revision and per-package licensing are recorded for reproducibility.
"""
import argparse, hashlib, json, urllib.request
from pathlib import Path

def fetch(url):
    with urllib.request.urlopen(url, timeout=90) as response:
        return response.read()

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--output', default='/tmp/friday-nvidia-chair')
    parser.add_argument('--revision', default='4763fbfaa4f8e97658e68b57d01b4c86659e08b5')
    args=parser.parse_args()
    dataset='nvidia/simready-assets'
    asset='chair_office_fabric_manager_a01'
    info=json.loads(fetch(f'https://huggingface.co/api/datasets/{dataset}/revision/{args.revision}'))
    revision=info['sha']
    entries=json.loads(fetch(f'https://huggingface.co/api/datasets/{dataset}/tree/{revision}/{asset}?recursive=true&limit=100'))
    root=Path(args.output); root.mkdir(parents=True,exist_ok=True)
    records=[]
    for entry in entries:
        path=entry['path']
        if entry['type']!='file': continue
        if not (path.endswith(('.usd','.usda','.json','LICENSE.txt'))): continue
        if '/MuJoCo/' in path or '/Newton/' in path: continue
        content=fetch(f'https://huggingface.co/datasets/{dataset}/resolve/{revision}/{path}')
        target=root/Path(path).relative_to(asset)
        target.parent.mkdir(parents=True,exist_ok=True); target.write_bytes(content)
        records.append({'path':path,'sha256':hashlib.sha256(content).hexdigest(),'bytes':len(content)})
    package=json.loads((root/'com.nvidia.simready.packaging.json').read_text())
    if package['license']!='CC-BY-4.0': raise SystemExit('Unexpected license; review before conversion')
    attribution=Path(__file__).resolve().parents[2]/'third_party/nvidia'
    attribution.mkdir(parents=True,exist_ok=True)
    (attribution/'chair-manifest.json').write_text(json.dumps({'dataset':dataset,'asset':asset,'revision':revision,'license':package['license'],'files':records},indent=2)+'\n')
    (attribution/'LICENSE.txt').write_bytes((root/'.metadata/LICENSE.txt').read_bytes())
    print(f'Fetched {len(records)} USD/license files at {revision} into {root}')
if __name__=='__main__': main()
