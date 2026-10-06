#!/bin/sh
# Packs an app into the installer DMG: Peek Pro beside Applications, over the
# background in scripts/dmg. Usage: make-dmg.sh <Peek Pro.app> <out.dmg>
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
app=$1
dmg=$2
venv=$root/build/venv

# dmgbuild writes the Finder layout itself, without scripting Finder. Before
# 1.6.7 it also wrote a background bookmark that blanks the window on macOS 26.2+.
if ! python3 -c 'import sys; sys.exit(sys.version_info < (3, 10))'; then
    echo "error: dmgbuild needs Python 3.10 or later; python3 is $(python3 --version 2>&1)" >&2
    exit 1
fi
[ -x "$venv/bin/python" ] || python3 -m venv "$venv"
"$venv/bin/pip" install --quiet --disable-pip-version-check \
    dmgbuild==1.6.7 ds_store==1.3.3 mac_alias==2.2.3

rm -f "$dmg"
"$venv/bin/dmgbuild" -s "$root/scripts/dmg/settings.py" \
    -D app="$app" -D background="$root/scripts/dmg/background.png" \
    "Peek Pro" "$dmg"
