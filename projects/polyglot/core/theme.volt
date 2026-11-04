// =====================================================================
// POLYGLOT - theme.volt
// Design tokens, light + dark themes and every shared component style.
// The look: warm paper and ink, a serif for headlines, and one accent
// colour per language (set with --h, a hue number, on any .lc element).
// Themes are just CSS variables: the app sets data-theme on <html>.
// =====================================================================

## :root { --h: 12; --bg: #f3efe6; --surface: #fbf9f4; --surface2: #ece6d9; --ink: #1d1a16; --muted: #6f675a; --line: #ddd5c4; --brand: #c8452c; --good: #2f7d4f; --good-soft: #dff0e5; --bad: #b3372c; --bad-soft: #f8e0dc; --accL: 40%; --shadow: 0 1px 2px rgba(40,30,10,.06), 0 10px 28px rgba(40,30,10,.06); --serif: Georgia, "Iowan Old Style", "Palatino Linotype", serif; --sans: "Segoe UI", system-ui, -apple-system, "Yu Gothic UI", "Malgun Gothic", "Microsoft YaHei", sans-serif; color-scheme: light; }
## :root[data-theme='dark'] { --bg: #14120f; --surface: #1c1a16; --surface2: #26231d; --ink: #f1ebdf; --muted: #9b9382; --line: #36322b; --brand: #ef6b4a; --good: #5fc08a; --good-soft: #17301f; --bad: #f08a7e; --bad-soft: #3a1d19; --accL: 64%; --shadow: 0 1px 2px rgba(0,0,0,.4), 0 10px 28px rgba(0,0,0,.35); color-scheme: dark; }
## html, body { background: var(--bg); }
## body { color: var(--ink); font-family: var(--sans); font-size: 16px; line-height: 1.5; -webkit-font-smoothing: antialiased; }
## #volt { max-width: none; margin: 0; padding: 0; }
## #volt button { background: none; border: 0; color: inherit; padding: 0; margin: 0; font: inherit; font-weight: 600; border-radius: 0; cursor: pointer; text-align: inherit; }
## #volt button:hover { filter: none; }
## #volt button:active { transform: none; }
## #volt button:focus-visible, #volt input:focus-visible { outline: 2px solid var(--brand); outline-offset: 2px; }
## #volt h1, #volt h2, #volt h3 { margin: 0; }
## .volt-error { font-family: monospace; }

// ---- layout -----------------------------------------------------------
## .app { display: grid; grid-template-columns: 252px minmax(0, 1fr); min-height: 100vh; }
## .side { position: sticky; top: 0; height: 100vh; box-sizing: border-box; padding: 22px 16px; border-right: 1px solid var(--line); display: flex; flex-direction: column; gap: 20px; background: var(--surface); }
## .brand { display: flex; align-items: center; gap: 10px; font-family: var(--serif); font-size: 1.45rem; font-weight: 700; letter-spacing: -.01em; padding: 0 8px; }
## .brand .mark { width: 30px; height: 30px; border-radius: 9px; background: var(--brand); color: #fff; display: grid; place-items: center; font-size: 1rem; transform: rotate(-6deg); }
## .nav { display: flex; flex-direction: column; gap: 2px; }
## #volt .navbtn { display: flex; align-items: center; gap: 12px; padding: 10px 12px; border-radius: 10px; color: var(--muted); width: 100%; box-sizing: border-box; transition: background .15s, color .15s; }
## #volt .navbtn:hover { background: var(--surface2); color: var(--ink); }
## #volt .navbtn.on { background: var(--ink); color: var(--bg); }
## .navbtn .g { width: 20px; text-align: center; font-size: 1.05rem; }
## .navbtn .sh { display: none; }
## .sidefoot { margin-top: auto; display: flex; flex-direction: column; gap: 12px; }
## .studying { display: flex; flex-wrap: wrap; gap: 6px; }
## .main { padding: 34px 44px 70px; max-width: 1120px; width: 100%; box-sizing: border-box; }
## .mtop { display: none; align-items: center; justify-content: space-between; margin-bottom: 18px; }
## .screen { animation: rise .32s cubic-bezier(.2,.7,.2,1) both; }
## @keyframes rise { from { opacity: 0; transform: translateY(8px); } to { opacity: 1; transform: none; } }
## @media (prefers-reduced-motion: reduce) { .screen, .ring, .bar i { animation: none !important; transition: none !important; } }
## @media (max-width: 860px) { .app { grid-template-columns: minmax(0, 1fr); } .side { position: fixed; top: auto; bottom: 0; left: 0; right: 0; height: auto; z-index: 50; flex-direction: row; padding: 6px 6px calc(6px + env(safe-area-inset-bottom)); border-right: 0; border-top: 1px solid var(--line); gap: 0; } .side .brand, .side .sidefoot { display: none; } .nav { flex-direction: row; flex: 1; justify-content: space-between; gap: 0; } #volt .navbtn { flex-direction: column; gap: 1px; padding: 6px 1px; font-size: .64rem; align-items: center; justify-content: center; flex: 1; min-width: 0; } .navbtn .lbl { display: none; } .navbtn .sh { display: inline; } .main { padding: 16px 16px 100px; } .mtop { display: flex; } }

// ---- typography ---------------------------------------------------------
## .eyebrow { text-transform: uppercase; letter-spacing: .14em; font-size: .72rem; font-weight: 700; color: var(--muted); }
## .h1 { font-family: var(--serif); font-size: clamp(1.9rem, 4vw, 2.7rem); line-height: 1.1; letter-spacing: -.02em; margin: 6px 0 6px; font-weight: 700; }
## .h2 { font-family: var(--serif); font-size: 1.35rem; font-weight: 700; letter-spacing: -.01em; }
## .lede { color: var(--muted); max-width: 62ch; margin: 0; }
## .muted { color: var(--muted); }
## .small { font-size: .86rem; }
## .sec { margin-top: 34px; }
## .sechead { display: flex; align-items: baseline; justify-content: space-between; gap: 12px; margin-bottom: 12px; }

// ---- surfaces ---------------------------------------------------------------
## .grid { display: grid; gap: 14px; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); }
## .stats { display: grid; gap: 14px; grid-template-columns: repeat(4, minmax(0, 1fr)); margin-top: 22px; }
## @media (max-width: 860px) { .stats { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
## .card { background: var(--surface); border: 1px solid var(--line); border-radius: 16px; padding: 18px; box-shadow: var(--shadow); }
## .card.flat { box-shadow: none; }
## .stat .v { font-family: var(--serif); font-size: 2rem; font-weight: 700; line-height: 1.1; }
## .stat .l { color: var(--muted); font-size: .85rem; margin-top: 2px; }
## .row { display: flex; align-items: center; gap: 12px; }
## .wrap { flex-wrap: wrap; }
## .sp { flex: 1; min-width: 0; }
## .stack { display: flex; flex-direction: column; gap: 12px; }
## .empty { border: 1.5px dashed var(--line); border-radius: 16px; padding: 28px; text-align: center; color: var(--muted); }
## .empty b { color: var(--ink); display: block; font-family: var(--serif); font-size: 1.2rem; margin-bottom: 4px; }

// ---- controls --------------------------------------------------------------
## #volt .btn { display: inline-flex; align-items: center; justify-content: center; gap: 8px; padding: 10px 16px; border-radius: 11px; border: 1px solid transparent; text-align: center; transition: transform .12s, background .15s, border-color .15s, filter .15s; }
## #volt .btn:active { transform: translateY(1px); }
## #volt .btn.primary { background: var(--brand); color: #fff; }
## #volt .btn.primary:hover { filter: brightness(1.08); }
## #volt .btn.ghost { border-color: var(--line); background: var(--surface); }
## #volt .btn.ghost:hover { border-color: var(--ink); }
## #volt .btn.danger { border-color: var(--bad); color: var(--bad); background: transparent; }
## #volt .btn.sm { padding: 6px 11px; font-size: .85rem; border-radius: 9px; }
## #volt .btn.acc { background: var(--acc); color: #fff; }
## #volt .btn.wide { width: 100%; padding: 13px; }
## #volt .chip { display: inline-flex; align-items: center; gap: 6px; border: 1px solid var(--line); background: var(--surface); border-radius: 999px; padding: 4px 11px; font-size: .84rem; font-weight: 600; white-space: nowrap; }
## #volt .chip.on { border-color: var(--acc); background: var(--accSoft); }
## #volt .chip.good { background: var(--good-soft); border-color: transparent; color: var(--good); }
## .seg { display: inline-flex; background: var(--surface2); border-radius: 12px; padding: 3px; gap: 2px; }
## #volt .seg button { padding: 7px 14px; border-radius: 9px; color: var(--muted); }
## #volt .seg button.on { background: var(--surface); color: var(--ink); box-shadow: var(--shadow); }
## .field { width: 100%; box-sizing: border-box; font: inherit; padding: 11px 13px; border-radius: 11px; border: 1px solid var(--line); background: var(--surface); color: var(--ink); }
## .field:focus { outline: none; border-color: var(--brand); }
## #volt .day { width: 38px; height: 38px; border-radius: 10px; border: 1px solid var(--line); color: var(--muted); text-align: center; font-size: .8rem; }
## #volt .day.on { background: var(--acc); border-color: var(--acc); color: #fff; }

// ---- per-language accent ----------------------------------------------------
## .lc { --acc: hsl(var(--h) 52% var(--accL)); --accSoft: hsl(var(--h) 55% 50% / .15); }
## .stamp { width: 52px; height: 52px; flex: none; border-radius: 15px; display: grid; place-items: center; background: var(--accSoft); color: var(--acc); font-family: var(--serif); font-size: 1.6rem; font-weight: 700; border: 1px solid hsl(var(--h) 55% 50% / .3); }
## .stamp.sm { width: 36px; height: 36px; border-radius: 11px; font-size: 1.1rem; }
## .bar { height: 8px; border-radius: 99px; background: var(--surface2); overflow: hidden; }
## .bar i { display: block; height: 100%; background: var(--acc, var(--brand)); border-radius: 99px; transition: width .5s ease; }
## .ring { --p: 0; width: 76px; height: 76px; flex: none; border-radius: 50%; display: grid; place-items: center; background: conic-gradient(var(--acc, var(--brand)) calc(var(--p) * 1%), var(--surface2) 0); }
## .ring span { width: 58px; height: 58px; border-radius: 50%; background: var(--surface); display: grid; place-items: center; font-weight: 700; font-size: .95rem; }
## .feed { display: flex; flex-direction: column; }
## .feed .item { display: flex; gap: 12px; align-items: center; padding: 11px 0; border-bottom: 1px solid var(--line); }
## .feed .item:last-child { border-bottom: 0; }
## .feed .when { color: var(--muted); font-size: .8rem; white-space: nowrap; }

// ---- tables and schedule grid ---------------------------------------------
## .tblwrap { overflow-x: auto; }
## .tbl { width: 100%; border-collapse: collapse; min-width: 560px; }
## .tbl th { text-align: left; font-size: .72rem; letter-spacing: .12em; text-transform: uppercase; color: var(--muted); padding: 0 10px 10px; font-weight: 700; }
## .tbl td { padding: 13px 10px; border-top: 1px solid var(--line); vertical-align: middle; }
## .tbl .num { font-variant-numeric: tabular-nums; font-weight: 700; }
## .tbl .nm { display: flex; align-items: center; gap: 10px; font-weight: 700; }
## .sched { display: grid; grid-template-columns: minmax(130px, 1fr) repeat(7, 38px); gap: 8px 6px; align-items: center; min-width: 470px; }
## .sched .hd { text-align: center; font-size: .72rem; color: var(--muted); font-weight: 700; }
## .sched .today { color: var(--brand); }

// ---- focus-mode sessions ------------------------------------------------------
## .focus { min-height: 100vh; display: flex; flex-direction: column; background: var(--bg); }
## .ftop { display: flex; align-items: center; gap: 14px; padding: 14px 22px; max-width: 760px; width: 100%; margin: 0 auto; box-sizing: border-box; }
## .ftop .bar { flex: 1; }
## .fbody { flex: 1; max-width: 760px; width: 100%; margin: 0 auto; padding: 8px 22px 190px; box-sizing: border-box; animation: rise .28s ease both; }
## .fbar { position: fixed; left: 0; right: 0; bottom: 0; padding: 14px 22px calc(14px + env(safe-area-inset-bottom)); border-top: 1px solid var(--line); background: var(--surface); }
## .fbar .in { max-width: 760px; margin: 0 auto; display: flex; align-items: center; gap: 14px; }
## .fbar.good { background: var(--good-soft); } .fbar.bad { background: var(--bad-soft); }
## .fbar .why { flex: 1; font-size: .93rem; }
## .fbar .why b { display: block; font-family: var(--serif); font-size: 1.15rem; }
## .fbar.good b { color: var(--good); } .fbar.bad b { color: var(--bad); }
## .q { font-family: var(--serif); font-size: clamp(1.4rem, 3.4vw, 1.9rem); line-height: 1.25; margin: 14px 0 22px; font-weight: 700; }
## .q .blank { display: inline-block; min-width: 3.2em; border-bottom: 3px solid var(--acc); text-align: center; color: var(--acc); }
## .opts { display: grid; gap: 10px; }
## #volt .opt { display: flex; align-items: center; gap: 12px; text-align: left; padding: 14px 16px; border-radius: 14px; border: 1.5px solid var(--line); background: var(--surface); transition: border-color .12s, background .12s; }
## #volt .opt:hover { border-color: var(--ink); }
## #volt .opt .k { width: 26px; height: 26px; flex: none; border-radius: 8px; border: 1px solid var(--line); display: grid; place-items: center; font-size: .78rem; color: var(--muted); }
## #volt .opt.right { border-color: var(--good); background: var(--good-soft); }
## #volt .opt.wrong { border-color: var(--bad); background: var(--bad-soft); }
## #volt .opt.sel { border-color: var(--acc); background: var(--accSoft); }
## #volt .opt.dim { opacity: .45; }
## .tray { min-height: 56px; border-bottom: 2px solid var(--line); display: flex; flex-wrap: wrap; gap: 8px; padding: 6px 0 10px; margin-bottom: 18px; }
## .pool { display: flex; flex-wrap: wrap; gap: 8px; }
## #volt .piece { padding: 9px 15px; border-radius: 11px; border: 1.5px solid var(--line); background: var(--surface); box-shadow: 0 2px 0 var(--line); }
## #volt .piece.used { opacity: .25; box-shadow: none; }
## .cols { display: grid; grid-template-columns: 1fr 1fr; gap: 10px 16px; }
## .passage { background: var(--surface); border: 1px solid var(--line); border-radius: 14px; padding: 16px 18px; font-size: 1.12rem; line-height: 1.7; margin-bottom: 18px; }
## .bubble { max-width: 82%; padding: 10px 14px; border-radius: 16px; margin: 8px 0; background: var(--surface); border: 1px solid var(--line); }
## .bubble.me { margin-left: auto; background: var(--accSoft); border-color: transparent; }
## .bubble small { display: block; color: var(--muted); }
## .flash { background: var(--surface); border: 1px solid var(--line); border-radius: 20px; padding: 44px 24px; text-align: center; box-shadow: var(--shadow); min-height: 150px; }
## .flash .big { font-family: var(--serif); font-size: 2.4rem; font-weight: 700; }
## .tiles { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 12px; }
## .vocab { display: grid; gap: 8px; }
## .vocab .w { display: flex; align-items: center; gap: 12px; padding: 12px 14px; background: var(--surface); border: 1px solid var(--line); border-radius: 12px; }
## .vocab .w b { font-size: 1.1rem; }
## .gpoint { display: grid; grid-template-columns: minmax(120px, 34%) 1fr; gap: 12px; padding: 10px 0; border-top: 1px solid var(--line); }
## .gpoint code { font-weight: 700; color: var(--acc); }
## @media (max-width: 560px) { .cols { grid-template-columns: 1fr; } .gpoint { grid-template-columns: 1fr; gap: 2px; } }

// ---- statistics ---------------------------------------------------------------
## .chart { display: flex; align-items: flex-end; gap: 6px; height: 130px; padding-top: 8px; }
## .chart .col { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: flex-end; height: 100%; gap: 4px; min-width: 0; }
## .chart .col i { display: block; width: 100%; background: var(--brand); border-radius: 6px 6px 0 0; min-height: 3px; opacity: .9; }
## .chart .col.today i { opacity: 1; box-shadow: 0 0 0 2px var(--ink) inset; }
## .chart .col span { font-size: .66rem; color: var(--muted); }
## .dist { display: flex; height: 16px; border-radius: 99px; overflow: hidden; background: var(--surface2); }
## .dist i { display: block; height: 100%; }
## .legend { display: flex; flex-wrap: wrap; gap: 6px 16px; margin-top: 10px; font-size: .84rem; color: var(--muted); }
## .legend b { display: inline-block; width: 10px; height: 10px; border-radius: 3px; margin-right: 6px; vertical-align: -1px; }
## .badges { display: grid; gap: 12px; grid-template-columns: repeat(auto-fill, minmax(190px, 1fr)); }
## .badge { display: flex; gap: 12px; align-items: center; padding: 12px; border: 1px solid var(--line); border-radius: 14px; background: var(--surface); }
## .badge .ic { width: 38px; height: 38px; border-radius: 12px; display: grid; place-items: center; background: var(--brand); color: #fff; flex: none; font-size: 1.1rem; }
## .badge.locked { opacity: .55; }
## .badge.locked .ic { background: var(--surface2); color: var(--muted); }
## .badge small { display: block; color: var(--muted); line-height: 1.3; }
