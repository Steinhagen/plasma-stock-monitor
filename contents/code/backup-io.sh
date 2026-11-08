#!/bin/sh
#
# File access helper for the widget's Import / Export page.
#
# QML has no portable file-writing API, so the page runs this script through the
# Plasma5Support "executable" data engine. Arguments arrive as separate argv
# entries (the QML side quotes them), which keeps paths with spaces and quotes safe.
#
#   backup-io.sh read  <path>
#   backup-io.sh write <path> <base64-encoded-data>
#
# "read" writes the file to stdout. "write" decodes the base64 argument and
# replaces the file. Both exit non-zero on failure so the QML side can show an
# error instead of silently claiming success.

set -eu

operation=$1
path=$2

case "$operation" in
    read)
        cat -- "$path"
        ;;
    write)
        # Write next to the target and rename it into place, so a failed export does
        # not truncate an existing backup. mktemp also gives the new file mode 0600.
        tmp=$(mktemp "${path}.XXXXXX")
        if printf '%s' "$3" | base64 -d > "$tmp"; then
            mv -- "$tmp" "$path" || { rm -f -- "$tmp"; exit 1; }
        else
            rm -f -- "$tmp"
            exit 1
        fi
        ;;
    *)
        echo "Unknown operation: $operation" >&2
        exit 2
        ;;
esac
