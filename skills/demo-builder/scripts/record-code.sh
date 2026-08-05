#!/usr/bin/env bash
# record-code.sh — record ANY source file, syntax-highlighted, scrolling like a human reading it.
# Works for any language (auto-detected by the highlighter). Produces a mac-chrome terminal-style clip.
# usage: record-code.sh <file> <out.mp4> [fontsize=16] [pace=0.10]
#   pace = seconds between lines (smaller = faster scroll).
set -e
FILE="$1"; OUT="$2"; FS="${3:-16}"; PACE="${4:-0.10}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$FILE" ] || { echo "no such file: $FILE" >&2; exit 1; }

# pick the best highlighter available (bat > pygmentize > numbered cat)
if command -v bat >/dev/null 2>&1; then HL="bat --color=always --style=numbers,grid --paging=never --theme=OneHalfDark"
elif command -v pygmentize >/dev/null 2>&1; then HL="pygmentize -g -O style=monokai"
else HL="cat -n"; fi

SEG=$(mktemp /tmp/demo_code_XXXX.sh)
cat > "$SEG" <<EOS
#!/usr/bin/env bash
clear
$HL "$FILE" | while IFS= read -r line; do printf '%s\n' "\$line"; sleep $PACE; done
sleep 2
EOS
chmod +x "$SEG"
bash "$HERE/record-term.sh" "$SEG" "$OUT" "$FS" 6
rm -f "$SEG"
echo "code clip -> $OUT ($FILE)"
