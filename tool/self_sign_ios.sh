#!/usr/bin/env bash
set -euo pipefail
app=${1:?Usage: self_sign_ios.sh path/to/Runner.app}
[ -d "$app" ] || { echo 'Application bundle missing' >&2; exit 1; }
# Local ad-hoc code signature (no certificate); not Apple device provisioning.
python3 - "$app" <<'PY'
import pathlib, subprocess, sys
app = pathlib.Path(sys.argv[1])
magic = {bytes.fromhex(x) for x in ('feedface','cefaedfe','feedfacf','cffaedfe','cafebabe','bebafeca','cafebabf','bfbafeca')}
files = []
for p in app.rglob('*'):
    if p.is_file() and not p.is_symlink():
        with p.open('rb') as f:
            if f.read(4) in magic:
                files.append(p)
for p in sorted(files, key=lambda p: len(p.parts), reverse=True):
    subprocess.run(['codesign','--force','--sign','-','--timestamp=none',str(p)], check=True)
bundles = [p for p in app.rglob('*') if p.is_dir() and p.suffix in ('.framework','.appex','.app')]
for p in sorted(bundles, key=lambda p: len(p.parts), reverse=True) + [app]:
    subprocess.run(['codesign','--force','--sign','-','--timestamp=none',str(p)], check=True)
subprocess.run(['codesign','--verify','--deep','--strict',str(app)], check=True)
print('Local ad-hoc signature verified; Apple provisioning is not included.')
PY
