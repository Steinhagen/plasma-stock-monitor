#!/bin/sh
#
# Extract every translatable string from the widget and update the .po catalogs.
#
#   ./translate/merge.sh
#
# Run this after adding, changing or removing an i18n() call in the QML sources.
# It regenerates template.pot and merges the result into each <language>.po file,
# so translating a new language is only a matter of copying template.pot to
# <language>.po and filling in the msgstr entries. See translate/README.md.
#
# Requires the gettext tools (xgettext, msgmerge) in PATH.

set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PACKAGE=$(CDPATH= cd -- "$DIR/.." && pwd)

# The translation domain Plasma uses for an applet is "plasma_applet_" plus the
# applet id from metadata.json (see Plasma::Applet::translationDomain()).
APP_ID=$(sed -n 's/.*"Id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PACKAGE/metadata.json" | head -n 1)
DOMAIN="plasma_applet_${APP_ID}"
WEBSITE=$(sed -n 's/.*"Website"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PACKAGE/metadata.json" | head -n 1)

if [ -z "$APP_ID" ]; then
    echo "[merge] Error: could not read the applet Id from metadata.json." >&2
    exit 1
fi

for tool in xgettext msgmerge; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "[merge] Error: $tool not found. Install gettext (e.g. 'nix shell nixpkgs#gettext')." >&2
        exit 1
    fi
done

echo "[merge] Extracting messages from the widget sources"

# Only the sources of the widget are scanned: the translate/ folder and metadata.json
# are not part of the message catalog. The list holds paths relative to the package
# root (-D below), so the catalog does not depend on where the checkout lives.
(cd "$PACKAGE" && find contents -type f \( -name '*.qml' -o -name '*.js' \) | sort) > "$DIR/infiles.list"

xgettext \
    --files-from="$DIR/infiles.list" \
    --from-code=UTF-8 \
    --width=400 \
    --add-location=file \
    -C -ci18n \
    -ki18n:1 -ki18nc:1c,2 -ki18np:1,2 -ki18ncp:1c,2,3 \
    -kI18N_NOOP:1 -kI18N_NOOP2:1c,2 -kN_:1 \
    --package-name="${DOMAIN}" \
    --msgid-bugs-address="${WEBSITE:-nobody@example.com}" \
    -D "$PACKAGE" \
    -o "$DIR/template.pot.new" \
    || { echo "[merge] Error: xgettext failed." >&2; rm -f "$DIR/infiles.list"; exit 1; }

rm -f "$DIR/infiles.list"

# xgettext writes a placeholder charset; the sources are UTF-8.
sed -i 's/"Content-Type: text\/plain; charset=CHARSET\\n"/"Content-Type: text\/plain; charset=UTF-8\\n"/' "$DIR/template.pot.new"
# Replace xgettext's placeholder header lines with something meaningful.
sed -i 's/^# SOME DESCRIPTIVE TITLE\.$/# Translation template for Plasma Stock Monitor./' "$DIR/template.pot.new"
sed -i "s/^# Copyright (C) YEAR THE PACKAGE'S COPYRIGHT HOLDER$/# Copyright (C) $(date +%Y) The Plasma Stock Monitor authors/" "$DIR/template.pot.new"
sed -i 's/^# FIRST AUTHOR <EMAIL@ADDRESS>, YEAR\.$/# Distributed under the GPL-3.0-or-later, like the widget./' "$DIR/template.pot.new"
# Keep the creation date stable when nothing else changed, so the diff stays readable.
if [ -f "$DIR/template.pot" ]; then
    NEW_DATE=$(sed -n 's/^"POT-Creation-Date: \(.*\)\\n"$/\1/p' "$DIR/template.pot.new")
    OLD_DATE=$(sed -n 's/^"POT-Creation-Date: \(.*\)\\n"$/\1/p' "$DIR/template.pot")
    if [ -n "$NEW_DATE" ] && [ -n "$OLD_DATE" ]; then
        sed -i "s|^\"POT-Creation-Date: ${NEW_DATE}\\\\n\"$|\"POT-Creation-Date: ${OLD_DATE}\\\\n\"|" "$DIR/template.pot.new"
    fi
fi

if [ -f "$DIR/template.pot" ] && cmp -s "$DIR/template.pot" "$DIR/template.pot.new"; then
    rm -f "$DIR/template.pot.new"
    echo "[merge] template.pot is up to date"
else
    mv "$DIR/template.pot.new" "$DIR/template.pot"
    echo "[merge] template.pot updated"
fi

echo "[merge] Merging template.pot into the catalogs"
for po in "$DIR"/*.po; do
    [ -e "$po" ] || continue
    lang=$(basename "$po" .po)
    echo "[merge]   $lang.po"
    msgmerge \
        --quiet \
        --width=400 \
        --add-location=file \
        --no-fuzzy-matching \
        --update \
        "$po" "$DIR/template.pot"
done

echo "[merge] Done. Run translate/build.sh to rebuild the .mo files."
