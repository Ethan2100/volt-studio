# Polyglot

A multi-language learning platform written in Volt.

```
node compiler/volt.js projects/polyglot/polyglot.volt      # builds projects/polyglot/polyglot/index.html
```
Open the generated `index.html` in a browser. Everything works offline except the optional AI tutor.

- `ARCHITECTURE.md`: what Volt can and can't do for this, module map, status, honest limitations
- `core/ engine/ ui/ content/`: the app (Volt)
- `server/tutor-server.volt`: optional AI tutor backend (needs `ANTHROPIC_API_KEY`)
- `tests/`: automated checks (see its README)

Add a language: create `content/xx.volt` (copy `content/es.volt`), import it in `polyglot.volt`.
