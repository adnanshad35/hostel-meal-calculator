"""Builds everything served at hostelmate.web.app into build/hosting.

    /        the landing page, from website/
    /app/    the web version of the app, built by Flutter

Usage:
    python tool/build_site.py
    firebase deploy --only hosting
"""
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WEB_BUILD = os.path.join(ROOT, 'build', 'web')
OUTPUT = os.path.join(ROOT, 'build', 'hosting')


def main():
    # Git Bash on Windows rewrites arguments that look like paths, which
    # would turn /app/ into a Windows folder.
    environment = dict(os.environ, MSYS_NO_PATHCONV='1')

    # A leftover build can make Flutter skip copying the fonts and other
    # assets, which leaves every icon as an empty box. Start clean.
    if os.path.isdir(WEB_BUILD):
        shutil.rmtree(WEB_BUILD)

    subprocess.run(
        'flutter build web --release --base-href /app/',
        shell=True, cwd=ROOT, env=environment, check=True,
    )

    required = [
        os.path.join('assets', 'FontManifest.json'),
        os.path.join('assets', 'fonts', 'MaterialIcons-Regular.otf'),
        'flutter_service_worker.js',
    ]
    missing = [
        name for name in required
        if not os.path.isfile(os.path.join(WEB_BUILD, name))
    ]
    if missing:
        sys.exit('The web build is incomplete, missing: ' + ', '.join(missing))

    if os.path.isdir(OUTPUT):
        shutil.rmtree(OUTPUT)

    shutil.copytree(os.path.join(ROOT, 'website'), OUTPUT)
    shutil.copytree(WEB_BUILD, os.path.join(OUTPUT, 'app'))

    print('Site assembled in', os.path.relpath(OUTPUT, ROOT))


if __name__ == '__main__':
    sys.exit(main())
