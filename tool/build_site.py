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

    subprocess.run(
        'flutter build web --release --base-href /app/',
        shell=True, cwd=ROOT, env=environment, check=True,
    )

    if os.path.isdir(OUTPUT):
        shutil.rmtree(OUTPUT)

    shutil.copytree(os.path.join(ROOT, 'website'), OUTPUT)
    shutil.copytree(WEB_BUILD, os.path.join(OUTPUT, 'app'))

    print('Site assembled in', os.path.relpath(OUTPUT, ROOT))


if __name__ == '__main__':
    sys.exit(main())
