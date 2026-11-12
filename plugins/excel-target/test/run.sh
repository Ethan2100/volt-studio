#!/bin/bash
# =====================================================================
#  Differential test for the #excel target.
#
#  The same Volt source is compiled twice: once to a spreadsheet by this
#  plugin, and once to JavaScript by Volt's own built-in #js backend. The
#  spreadsheet is then recalculated by LibreOffice and the JavaScript run
#  by Node, and the two Output columns must match line for line.
#
#  Needs: node, soffice (LibreOffice), python3.
#  Usage:  ./run.sh            - every .volt file here
#          ./run.sh fib.volt   - just one
# =====================================================================
set -u
cd "$(dirname "$0")"
PLUGIN_DIR="$(cd .. && pwd)"
VOLT="$(cd ../../.. && pwd)/compiler/volt.js"

if ! command -v soffice >/dev/null; then
  echo "LibreOffice ('soffice') is not installed - it is what actually runs the sheets."
  exit 1
fi

work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
files=("$@"); [ $# -eq 0 ] && files=(*.volt)
pass=0; fail=0

for f in "${files[@]}"; do
  name=$(basename "$f" .volt)

  # --- under test: compile to a spreadsheet, then let LibreOffice run it
  node -e "
    const volt=require('$VOLT'), fs=require('fs');
    volt.registerTarget('excel', { label:'Spreadsheet', file:(n)=>n+'.xls',
      generate: require('$PLUGIN_DIR/generate.js').generate });
    const r=volt.compile(fs.readFileSync('$f','utf8'));
    if (r.target!=='excel') throw new Error('expected #excel, got '+r.target);
    fs.writeFileSync('$work/$name.xls', r.code);
  " || { echo "FAIL $name  (did not compile to a spreadsheet)"; fail=$((fail+1)); continue; }

  soffice --headless --convert-to csv --outdir "$work" "$work/$name.xls" >/dev/null 2>&1
  python3 -I - "$work/$name.csv" > "$work/$name.got" <<'PY'
import csv, sys
rows = list(csv.reader(open(sys.argv[1], newline='')))
col = rows[0].index('Output')
for r in rows[1:]:
    if len(r) > col and r[col] != '':
        print(r[col])
PY

  # --- reference: the identical program as JavaScript -------------------
  sed 's/^#excel$/#js/' "$f" > "$work/$name.ref.volt"
  node -e "
    const volt=require('$VOLT'), fs=require('fs');
    const r=volt.compile(fs.readFileSync('$work/$name.ref.volt','utf8'));
    fs.writeFileSync('$work/$name.ref.js', r.code);
  " && node "$work/$name.ref.js" > "$work/$name.want" 2>&1

  if diff -q <(sed 's/[[:space:]]*$//' "$work/$name.want") \
             <(sed 's/[[:space:]]*$//' "$work/$name.got") >/dev/null; then
    echo "PASS $name  ($(wc -l < "$work/$name.got" | tr -d ' ') lines match the #js build)"
    pass=$((pass+1))
  else
    echo "FAIL $name"
    diff <(sed 's/[[:space:]]*$//' "$work/$name.want") \
         <(sed 's/[[:space:]]*$//' "$work/$name.got") | head -20
    fail=$((fail+1))
  fi
done

echo "-----"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
