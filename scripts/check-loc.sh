#!/usr/bin/env bash
set -euo pipefail

# Enforce portfolio rule: max 200 non-blank, non-comment lines per Swift file.
# Run from repo root: scripts/check-loc.sh

MAX_LOC=200
EXIT=0
TOTAL=0
OVER=0

while IFS= read -r -d '' file; do
    # Strip block comments, line comments, blank lines, then count.
    loc=$(
        awk '
            /\/\*/ { in_block = 1 }
            in_block { if (/\*\//) { in_block = 0 }; next }
            /^[[:space:]]*\/\// { next }
            /^[[:space:]]*$/ { next }
            { count++ }
            END { print count + 0 }
        ' "$file"
    )
    TOTAL=$((TOTAL + 1))
    if [ "$loc" -gt "$MAX_LOC" ]; then
        echo "FAIL  $file  (LOC=$loc, max=$MAX_LOC)"
        OVER=$((OVER + 1))
        EXIT=1
    fi
done < <(find apps packages cli -name "*.swift" -not -path "*/.build/*" -print0)

echo ""
echo "checked $TOTAL Swift files; $OVER over limit"
exit $EXIT
