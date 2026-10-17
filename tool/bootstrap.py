"""Generate missing native runners using an installed Flutter SDK."""
import argparse
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--org', required=True, help='Reverse domain namespace, e.g. com.example')
    args = parser.parse_args()
    if not re.fullmatch(r'[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+', args.org):
        parser.error('Use a lowercase reverse domain namespace')
    flutter = shutil.which('flutter')
    if not flutter:
        raise SystemExit('Install Flutter SDK and add flutter to PATH first.')
    root = Path(__file__).resolve().parents[1]
    platforms = ('android','windows','linux')
    with tempfile.TemporaryDirectory(prefix='xy_runners_') as temp:
        staged = Path(temp)/'xy_encrypt_app'
        subprocess.run([flutter,'create','--project-name=xy_encrypt_app',
            '--org='+args.org,'--platforms='+','.join(platforms),
            '--empty','--no-pub',str(staged)],check=True)
        for platform in platforms:
            dest = root/platform
            if dest.exists():
                print('Kept existing:',platform)
            elif (staged/platform).is_dir():
                shutil.copytree(staged/platform,dest)
                print('Added:',platform)
            else:
                raise SystemExit('Template did not generate '+platform)
        metadata = root/'.metadata'
        if not metadata.exists() and (staged/'.metadata').is_file():
            shutil.copy2(staged/'.metadata',metadata)
    print('Next: apply native configuration in docs/BUILD.md, then flutter pub get.')

if __name__ == '__main__':
    main()
