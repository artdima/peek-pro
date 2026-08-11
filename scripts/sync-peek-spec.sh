#!/bin/sh
# Copies Peek's specs — the session format and the remote protocol — and their
# reference files into the tests, and records the Peek commit they came from. Peek is looked for next to this repository's folder
# (../../peek); set PEEK_DIR to point elsewhere.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
peek=${PEEK_DIR:-$root/../../peek}
spec=$peek/doc/spec
dest=$root/Peek\ ProTests/Spec

if [ ! -f "$spec/session-format.md" ]; then
    echo "error: no Peek spec in $spec; set PEEK_DIR to the Peek repository" >&2
    exit 1
fi
# A commit that the files do not match would make the record a lie.
if [ -n "$(git -C "$peek" status --porcelain -- doc/spec)" ]; then
    echo "error: $spec has uncommitted changes; commit them in Peek first" >&2
    exit 1
fi

commit=$(git -C "$peek" rev-parse HEAD)

rm -rf "$dest"
mkdir -p "$dest/sessions" "$dest/remote"
cp "$spec/session-format.md" "$spec/remote-protocol.md" "$dest/"
cp "$spec/fixtures/sessions/"* "$dest/sessions/"
# Xcode puts the test resources in one flat folder, where the frames' own
# manifest.json would clash with the sessions' one: prefix them all.
for frame in "$spec/fixtures/remote/"*; do
    cp "$frame" "$dest/remote/remote-$(basename "$frame")"
done
printf '%s\n' "$commit" > "$dest/PEEK_SPEC_COMMIT"

echo "Synced the Peek spec at $(git -C "$peek" rev-parse --short HEAD)."
