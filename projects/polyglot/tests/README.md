# Polyglot tests

Plain Node scripts that load the compiled app in jsdom and drive it like a person would (they are test tooling, not part of the app, which is all Volt).

```
npm install jsdom            # once, anywhere on the module path
node compiler/volt.js projects/polyglot/polyglot.volt
node compiler/volt.js projects/polyglot/server/tutor-server.volt
cd projects/polyglot/tests
for f in validate stage3 stage4 srs stage5 stage6 stage7 stage8 stage9 alllessons; do node $f.js | tail -2; done
```

`validate.js` checks the structure of all lesson content. `alllessons.js` plays all 25 lessons through the UI and expects 100%.
