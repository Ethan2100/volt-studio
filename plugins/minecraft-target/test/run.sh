#!/bin/bash
# =====================================================================
#  Differential test for the #minecraft target.
#
#  The same Volt source is compiled twice: once to Minecraft commands by
#  this plugin, and once to JavaScript by Volt's built-in #js backend.
#  sim.js then interprets the generated commands and the two outputs
#  must match line for line.
#
#  sim.js reads the emitted command text, so this checks the commands
#  that would actually go into the game - but only Minecraft itself can
#  confirm it accepts the syntax.
#
#  Needs: node.   Usage: ./run.sh [file.volt ...]
# =====================================================================
set -u
cd "$(dirname "$0")"
PLUGIN_DIR="$(cd .. && pwd)"
VOLT="$(cd ../../.. && pwd)/compiler/volt.js"

work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
files=("$@"); [ $# -eq 0 ] && files=(*.volt)
pass=0; fail=0

for f in "${files[@]}"; do
  name=$(basename "$f" .volt)

  node -e "
    const volt=require('$VOLT'), fs=require('fs');
    volt.registerTarget('minecraft', { label:'Minecraft', file:(n)=>n+'.mcfunction',
      generate: require('$PLUGIN_DIR/generate.js').generate });
    const r=volt.compile(fs.readFileSync('$f','utf8'));
    if (r.target!=='minecraft') throw new Error('expected #minecraft, got '+r.target);
    fs.writeFileSync('$work/$name.mcfunction', r.code);
  " || { echo "FAIL $name  (did not compile)"; fail=$((fail+1)); continue; }

  node sim.js "$work/$name.mcfunction" > "$work/$name.got" 2>"$work/$name.err" \
    || { echo "FAIL $name  (simulator: $(head -1 "$work/$name.err"))"; fail=$((fail+1)); continue; }

  # --- reference: the identical program as JavaScript -------------------
  sed 's/^#minecraft$/#js/' "$f" > "$work/$name.ref.volt"
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
