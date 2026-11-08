#!/bin/sh
#
# Compile the .po catalogs into the binary .mo files the widget ships with.
#
#   ./translate/build.sh
#
# Plasma looks for an applet's catalogs inside the installed package, at
#   contents/locale/<language>/LC_MESSAGES/plasma_applet_<applet-id>.mo
# so the files are written there. They are part of the package (and of the
# .plasmoid archive), which is why they are committed as well.
#
# Requires msgfmt from gettext in PATH.

set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PACKAGE=$(CDPATH= cd -- "$DIR/.." && pwd)

APP_ID=$(sed -n 's/.*"Id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PACKAGE/metadata.json" | head -n 1)
DOMAIN="plasma_applet_${APP_ID}"

if [ -z "$APP_ID" ]; then
    echo "[build] Error: could not read the applet Id from metadata.json." >&2
    exit 1
fi

if ! command -v msgfmt >/dev/null 2>&1; then
    echo "[build] Error: msgfmt not found. Install gettext (e.g. 'nix shell nixpkgs#gettext')." >&2
    exit 1
fi

found=0
for po in "$DIR"/*.po; do
    [ -e "$po" ] || continue
    found=1
    lang=$(basename "$po" .po)
    outdir="$PACKAGE/contents/locale/$lang/LC_MESSAGES"
    mkdir -p "$outdir"
    echo "[build] $lang: $(basename "$po") -> ${outdir#"$PACKAGE"/}/$DOMAIN.mo"
    # --check fails on a malformed catalog and -v lists untranslated/fuzzy entries.
    msgfmt --check --statistics -o "$outdir/$DOMAIN.mo" "$po"
done

if [ "$found" -eq 0 ]; then
    echo "[build] No .po files in $DIR" >&2
    exit 1
fi

echo "[build] Done."
