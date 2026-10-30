// =====================================================================
// Cold Shoulder - a tsundere weather dashboard, written in Volt.
//
// Pick who reads you the weather: Wren (the pedant), Zuri (the diva),
// Ingrid (the ice queen) or Leo (the grump), or hit Shuffle and let fate
// decide. Each has their own look, voice and poke lines. All of them insult
// you for needing a forecast while making very sure you dress properly.
// The sky behind the page follows the real conditions and time of day, and
// the faces and the Tsun/Dere gauge follow the weather.
//
// Almost everything is Volt: the personalities (lines, moods, comfort
// score), the characters, charts and cards are Volt functions that build
// HTML strings and show them with `html`. Raw JavaScript (# lines) is used
// only for what Volt has no word for yet: fetching the forecast, browser
// storage, geolocation and the typewriter effect.
//
// Works on phones, tablets and laptops (see the @media rules below).
// Compile with:  node volt.js 19_html_cold_shoulder.volt   (or Preview in Volt Studio)
// Weather data: Open-Meteo (no key needed).
// =====================================================================
#html

// ------------------------------ design -------------------------------
## :root { color-scheme: dark; --ink:#F5F7FF; --ink2:#C8D0F2; --glass:rgba(10,14,40,.46); --glass2:rgba(10,14,40,.72); --edge:rgba(255,255,255,.2); --acc:#3DDBC4; --acc2:#B4F5EA; --onacc:#14142B; --navy:#1B1B3A; --sun:#FFC83D; --rain:#7BBBFF; --skyA:#1565C8; --skyB:#4A9DE8; --skyC:#7FC0F2; --hair:#3B2A2A; --brow:#3B2A2A; --skin:#F4D2B8; --uni:#2F7D6D; --uni2:#3E9A88; --uni3:#4DB39E; --item:#F2C14E; --pup:#6B4A33; --line:#2A1D1D; --blush:#FF7A8A; --f-display:'Lilita One','Trebuchet MS',system-ui,sans-serif; --f-body:'Nunito',system-ui,-apple-system,'Segoe UI',Roboto,sans-serif; --f-mono:'JetBrains Mono',ui-monospace,Menlo,Consolas,monospace; }
## body.who-0 { --acc:#3DDBC4; --acc2:#B4F5EA; }
## body.who-1 { --acc:#FF8F45; --acc2:#FFD0AD; }
## body.who-2 { --acc:#B7A4FF; --acc2:#DDD4FF; }
## body.who-3 { --acc:#FF6B6B; --acc2:#FFB8B8; }
## html { -webkit-text-size-adjust:100%; }
## body { margin:0; min-height:100vh; min-height:100dvh; color:var(--ink); font:500 16px/1.55 var(--f-body); background:var(--skyA); }
## body #skyBg { position:fixed; inset:0; z-index:-1; pointer-events:none; background:linear-gradient(180deg,var(--skyA) 0%,var(--skyB) 52%,var(--skyC) 100%); }
## body.sky-day { --skyA:#1565C8; --skyB:#4A9DE8; --skyC:#7FC0F2; }
## body.sky-dawn { --skyA:#3B3A7C; --skyB:#C86BA8; --skyC:#FFB07A; }
## body.sky-dusk { --skyA:#2B2A6B; --skyB:#8A4AA0; --skyC:#FF8A65; }
## body.sky-night { --skyA:#070B24; --skyB:#121C4D; --skyC:#2A2A6E; }
## body.sky-cloud { --skyA:#3A4766; --skyB:#5D6C8F; --skyC:#8794B3; }
## body.sky-cloud-night { --skyA:#0E1124; --skyB:#1C2240; --skyC:#2E3556; }
## body.sky-rain { --skyA:#1B2540; --skyB:#31446A; --skyC:#4C6088; }
## body.sky-storm { --skyA:#0C0F22; --skyB:#211A42; --skyC:#392C5E; }
## body.sky-snow { --skyA:#41537A; --skyB:#788CB1; --skyC:#A3B4D2; }
## body.sky-fog { --skyA:#4C566F; --skyB:#6F7A93; --skyC:#939DB2; }
## body::before { content:''; position:fixed; inset:0; pointer-events:none; z-index:0; }
## body.sky-day::before { background:radial-gradient(circle at 84% 9%,rgba(255,246,196,.95) 0,rgba(255,222,112,.42) 7%,transparent 30%); }
## body.sky-dawn::before { background:radial-gradient(ellipse at 16% 100%,rgba(255,200,124,.85),transparent 58%); }
## body.sky-dusk::before { background:radial-gradient(ellipse at 82% 100%,rgba(255,150,110,.8),transparent 58%); }
## body.sky-night::before, body.sky-cloud-night::before { background-image:radial-gradient(circle at 80% 13%,rgba(255,240,190,.5) 0,transparent 11%),radial-gradient(1.6px 1.6px at 8% 12%,#fff,transparent),radial-gradient(1.2px 1.2px at 22% 38%,#fff,transparent),radial-gradient(1.8px 1.8px at 37% 8%,#fff,transparent),radial-gradient(1.2px 1.2px at 52% 26%,#dff,transparent),radial-gradient(1.6px 1.6px at 66% 14%,#fff,transparent),radial-gradient(1.2px 1.2px at 78% 34%,#fff,transparent),radial-gradient(1.8px 1.8px at 90% 9%,#fff,transparent),radial-gradient(1.2px 1.2px at 15% 62%,#fff,transparent),radial-gradient(1.4px 1.4px at 44% 52%,#fff,transparent),radial-gradient(1.2px 1.2px at 86% 58%,#fff,transparent); animation:twinkle 5s ease-in-out infinite alternate; }
## body.sky-cloud-night::before { opacity:.55; }
## body.sky-cloud::before { background:radial-gradient(ellipse 38% 9% at 22% 16%,rgba(255,255,255,.16),transparent),radial-gradient(ellipse 46% 11% at 70% 30%,rgba(255,255,255,.13),transparent),radial-gradient(ellipse 34% 8% at 40% 55%,rgba(255,255,255,.1),transparent); background-size:140% 100%; animation:drift 60s linear infinite alternate; }
## body.sky-rain::before, body.sky-storm::before { background-image:repeating-linear-gradient(104deg,rgba(200,225,255,.3) 0 1.2px,transparent 1.2px 11px),repeating-linear-gradient(104deg,rgba(200,225,255,.18) 0 1px,transparent 1px 17px); background-size:240px 240px,360px 360px; animation:rainfall .7s linear infinite; }
## body.sky-snow::before { background-image:radial-gradient(3px 3px at 20px 30px,#fff,transparent),radial-gradient(2.4px 2.4px at 90px 120px,#fff,transparent),radial-gradient(3.4px 3.4px at 160px 60px,#fff,transparent),radial-gradient(2px 2px at 60px 180px,#fff,transparent); background-size:200px 200px; animation:snowfall 9s linear infinite; }
## body.sky-fog::before { background:linear-gradient(180deg,transparent,rgba(255,255,255,.18) 60%,rgba(255,255,255,.3)); }
## body.sky-storm::after { content:''; position:fixed; inset:0; pointer-events:none; z-index:0; background:#cdd6ff; opacity:0; animation:flash 7s infinite; }
## @keyframes twinkle { from { opacity:.65; } to { opacity:1; } }
## @keyframes drift { to { background-position:30% 0; } }
## @keyframes rainfall { to { background-position:-60px 240px,-90px 360px; } }
## @keyframes snowfall { to { background-position:30px 200px,-20px 200px,40px 200px,-10px 200px; } }
## @keyframes flash { 0%,91%,100% { opacity:0; } 92% { opacity:.35; } 93% { opacity:0; } 95% { opacity:.25; } 96% { opacity:0; } }
## @keyframes shake { 0%,100% { transform:translateX(0) rotate(0); } 20% { transform:translateX(-6px) rotate(-3deg); } 40% { transform:translateX(6px) rotate(3deg); } 60% { transform:translateX(-4px) rotate(-2deg); } 80% { transform:translateX(3px) rotate(1deg); } }
## @keyframes sweep { from { transform:rotate(-90deg); } }
## body #volt { max-width:1180px; margin:0 auto; padding-block:calc(20px + env(safe-area-inset-top,0px)) calc(48px + env(safe-area-inset-bottom,0px)); padding-left:max(16px,env(safe-area-inset-left,0px)); padding-right:max(16px,env(safe-area-inset-right,0px)); display:flex; flex-direction:column; gap:20px; position:relative; z-index:1; }
## .volt-html { min-width:0; }
## button, input { touch-action:manipulation; -webkit-tap-highlight-color:transparent; }
## :focus-visible { outline:3px solid var(--acc2); outline-offset:2px; }

## .top { display:flex; flex-wrap:wrap; align-items:center; gap:12px 16px; position:relative; z-index:5; }
## .brand { display:flex; flex-direction:column; min-width:0; margin-right:auto; }
## .brand h1 { margin:0; font:400 clamp(1.8rem,4.6vw,2.5rem)/1 var(--f-display); letter-spacing:.01em; text-shadow:0 3px 0 var(--acc),0 8px 20px rgba(0,0,0,.25); }
## .brand span { font-size:.9rem; color:var(--ink2); margin-top:8px; }
## .search { display:flex; gap:8px; flex:1 1 300px; max-width:540px; min-width:0; position:relative; }
## .search input { flex:1; min-width:0; min-height:44px; padding:.5rem 1rem; border-radius:999px; border:1px solid var(--edge); background:var(--glass); color:var(--ink); font:inherit; font-size:16px; -webkit-backdrop-filter:blur(12px); backdrop-filter:blur(12px); }
## .search input::placeholder { color:var(--ink2); opacity:.85; }
## button.b { margin:0; min-height:44px; padding:.5rem 1.1rem; border-radius:999px; border:1px solid var(--edge); background:var(--glass); color:var(--ink); font:800 .92rem var(--f-body); cursor:pointer; -webkit-backdrop-filter:blur(12px); backdrop-filter:blur(12px); white-space:nowrap; }
## button.b.primary { background:var(--acc); color:var(--onacc); border-color:transparent; }
## .seg { display:inline-flex; border-radius:999px; border:1px solid var(--edge); overflow:hidden; background:var(--glass); }
## .seg button { margin:0; min-height:44px; min-width:48px; border-radius:0; border:0; background:transparent; color:var(--ink2); padding:.5rem .9rem; font:700 .88rem var(--f-mono); cursor:pointer; }
## .seg button.on { background:var(--ink); color:var(--navy); }
## .res { position:absolute; top:calc(100% + 8px); left:0; right:0; margin:0; padding:6px; list-style:none; background:var(--glass2); border:1px solid var(--edge); border-radius:18px; -webkit-backdrop-filter:blur(18px); backdrop-filter:blur(18px); z-index:20; }
## .res button { width:100%; min-height:44px; text-align:left; margin:0; border:0; background:none; color:var(--ink); border-radius:12px; padding:.55rem .8rem; font:700 .95rem var(--f-body); cursor:pointer; }
## .note { border:1px dashed var(--sun); background:var(--glass); border-radius:14px; padding:10px 14px; font-size:.92rem; }

## .cast { display:grid; grid-template-columns:repeat(5,minmax(0,1fr)); gap:8px; }
## button.pick { margin:0; min-width:0; min-height:44px; display:flex; flex-direction:column; align-items:center; gap:5px; padding:8px 4px; border-radius:18px; border:1px solid var(--edge); background:var(--glass); color:var(--ink); font:inherit; cursor:pointer; text-align:center; -webkit-backdrop-filter:blur(12px); backdrop-filter:blur(12px); transition:transform .15s ease,background .15s ease; }
## button.pick .th { width:46px; height:46px; flex:none; display:block; border-radius:50%; overflow:hidden; background:rgba(255,255,255,.18); }
## button.pick .th svg { width:100%; height:100%; display:block; }
## button.pick .th.sh { display:flex; align-items:center; justify-content:center; font:400 1.6rem/1 var(--f-display); }
## button.pick .tx { display:flex; flex-direction:column; align-items:center; gap:1px; min-width:0; }
## button.pick b { font:800 .88rem/1.15 var(--f-body); }
## button.pick small { font-size:.72rem; line-height:1.2; color:var(--ink2); }
## button.pick.on { background:var(--acc); color:var(--onacc); border-color:transparent; }
## button.pick.on small { color:var(--onacc); opacity:.8; }
## @media (hover:hover) { button.pick:hover, button.b:hover { transform:translateY(-2px); } .res button:hover { background:rgba(255,255,255,.14); } }

## .hero { display:grid; grid-template-columns:minmax(0,1.3fr) minmax(0,1fr); gap:20px 36px; align-items:end; padding-top:4px; }
## .stage { display:flex; align-items:flex-end; gap:20px; min-width:0; }
## button.avatar { position:relative; flex:none; width:clamp(150px,19vw,240px); background:none; border:0; margin:0; padding:0; cursor:pointer; color:inherit; font:inherit; filter:drop-shadow(0 0 1px rgba(255,255,255,.75)) drop-shadow(0 14px 22px rgba(0,0,0,.35)); }
## .avatar svg { width:100%; height:auto; display:block; overflow:visible; }
## .avatar.shake svg { animation:shake .4s; }
## .hair { fill:var(--hair); stroke:rgba(0,0,0,.14); stroke-width:1.5; } .skin { fill:var(--skin); } .uni { fill:var(--uni); } .collar { fill:#fff; } .item { fill:var(--item); }
## .sfx { position:absolute; top:30px; left:-6px; font:400 1.45rem/1 var(--f-display); color:#fff; -webkit-text-stroke:1.5px var(--navy); paint-order:stroke fill; text-shadow:3px 3px 0 var(--acc); transform:rotate(-8deg); pointer-events:none; white-space:nowrap; }
## .poke { display:block; text-align:center; font-size:.74rem; color:var(--ink2); margin-top:4px; }
## .say { position:relative; flex:1 1 0; min-width:0; display:flex; flex-direction:column; gap:14px; align-self:center; }
## .bub { position:relative; background:#fff; color:var(--navy); border:3px solid var(--navy); border-radius:26px; padding:26px 22px 18px; box-shadow:6px 6px 0 rgba(10,14,40,.35); }
## .bub::before { content:''; position:absolute; left:-17px; bottom:36px; width:24px; height:24px; background:#fff; border-left:3px solid var(--navy); border-bottom:3px solid var(--navy); transform:rotate(45deg); }
## .tag { position:absolute; top:-15px; left:20px; background:var(--acc); color:var(--onacc); border:3px solid var(--navy); padding:0 12px; font:400 .86rem/1.55 var(--f-display); letter-spacing:.06em; border-radius:8px; }
## .line { position:relative; margin:0; font-weight:800; font-size:clamp(1.05rem,2.2vw,1.32rem); line-height:1.5; }
## .ghost { visibility:hidden; display:block; }
## .typed { position:absolute; inset:0; display:block; }
## .acts { display:flex; flex-wrap:wrap; gap:10px; }

## .now { display:flex; flex-direction:column; align-items:flex-end; text-align:right; gap:2px; min-width:0; }
## .where { font:800 1.15rem var(--f-body); overflow-wrap:anywhere; }
## .when { font:500 .85rem var(--f-mono); color:var(--ink2); }
## .bigrow { display:flex; align-items:center; gap:14px; margin-top:8px; }
## .temp { font:400 clamp(5rem,15vw,9.5rem)/.85 var(--f-display); letter-spacing:-.02em; text-shadow:0 8px 28px rgba(0,0,0,.28); }
## .temp sup { font-size:.38em; vertical-align:top; position:relative; top:.12em; letter-spacing:0; }
## .cond { font:800 1.3rem var(--f-body); margin-top:8px; }
## .chips { display:flex; flex-wrap:wrap; gap:8px; justify-content:flex-end; margin-top:12px; }
## .chip { background:var(--glass); border:1px solid var(--edge); padding:5px 12px; border-radius:999px; font:600 .85rem var(--f-mono); -webkit-backdrop-filter:blur(12px); backdrop-filter:blur(12px); }

## .card { background:var(--glass); border:1px solid var(--edge); border-radius:20px; -webkit-backdrop-filter:blur(14px) saturate(1.2); backdrop-filter:blur(14px) saturate(1.2); box-shadow:0 12px 32px rgba(0,0,0,.16); }
## .sec { padding:20px; }
## h2.hd { margin:0 0 14px; font:400 1.1rem/1.2 var(--f-display); letter-spacing:.02em; display:flex; flex-wrap:wrap; gap:2px 12px; align-items:baseline; }
## h2.hd small { font:600 .85rem var(--f-body); letter-spacing:0; color:var(--ink2); }
## .stats { display:grid; grid-template-columns:minmax(0,1fr); gap:14px; }
## .stat { padding:16px 18px; display:flex; flex-direction:column; gap:4px; min-width:0; }
## .k { font-size:.72rem; letter-spacing:.1em; text-transform:uppercase; color:var(--ink2); font-weight:800; }
## .v { font:700 1.5rem/1.15 var(--f-mono); overflow-wrap:anywhere; }
## .v.sm { font-size:1.12rem; }
## .c { font-size:.9rem; color:var(--ink2); }
## .gauge-card { padding:16px 18px; flex-wrap:wrap; display:flex; flex-direction:column; align-items:flex-start; gap:12px; min-width:0; }
## .gauge-card svg { width:100%; max-width:190px; display:block; flex:none; }
## .gtxt { display:flex; flex-direction:column; gap:4px; min-width:0; }
## .gtxt .big { font:400 1.35rem/1.2 var(--f-display); }
## .needle { transform-origin:100px 100px; transform:rotate(var(--a)); }
## .fresh .needle { animation:sweep 1s cubic-bezier(.2,.9,.2,1); }
## .gl { font:400 11px var(--f-display); fill:var(--ink2); letter-spacing:.06em; }

## .scroll { overflow-x:auto; padding-bottom:6px; -webkit-overflow-scrolling:touch; overscroll-behavior-x:contain; }
## .chart { display:block; }
## .ct { font:700 13px var(--f-mono); fill:var(--ink); text-anchor:middle; }
## .cl { font:600 11px var(--f-mono); fill:var(--ink2); text-anchor:middle; }
## .cp { font:600 10.5px var(--f-mono); fill:var(--rain); text-anchor:middle; }
## .cnow { fill:var(--acc2); font:800 11px var(--f-mono); text-anchor:middle; }
## .ln { fill:none; stroke:var(--acc2); stroke-width:3; stroke-linecap:round; stroke-linejoin:round; }

## .day { display:flex; align-items:center; gap:14px; padding:10px 0; border-bottom:1px dashed rgba(255,255,255,.2); }
## .day:last-of-type { border-bottom:0; }
## .dd { width:78px; flex:none; display:flex; flex-direction:column; line-height:1.2; }
## .dd b { font-weight:800; }
## .dd span { font:500 .75rem var(--f-mono); color:var(--ink2); }
## .dl { flex:1 1 0; min-width:0; color:var(--ink2); font-size:.92rem; }
## .dp { width:44px; flex:none; text-align:right; font:600 .8rem var(--f-mono); color:var(--rain); }
## .dr { flex:0 0 min(38%,260px); display:flex; align-items:center; gap:8px; font:700 .85rem var(--f-mono); }
## .rt { flex:1; height:9px; background:rgba(255,255,255,.18); border-radius:5px; position:relative; min-width:40px; }
## .rf { position:absolute; top:0; bottom:0; border-radius:5px; background:linear-gradient(90deg,#6DB3FF,#FFC83D,#FF6FA5); }
## .lo { color:var(--ink2); width:3.2ch; text-align:right; }
## .hi { width:3.2ch; }
## .best { margin:14px 0 0; padding-top:14px; border-top:1px solid var(--edge); font-weight:800; }
## .foot { text-align:center; font-size:.82rem; color:var(--ink2); }
## .foot a { color:inherit; }

## .i-sun { fill:var(--sun); } .i-ray { stroke:var(--sun); stroke-width:2.4; stroke-linecap:round; } .i-moon { fill:#FFE08A; }
## .i-cloud { fill:#EEF2FF; } .i-cloud.dk { fill:#98A1CC; }
## .i-rain { stroke:#6DB3FF; stroke-width:2.6; stroke-linecap:round; } .i-snow { fill:#BFE6FF; }
## .i-fog { stroke:#DDE3F7; stroke-width:2.6; stroke-linecap:round; } .i-bolt { fill:#FFD84D; }

// ---- responsive: phone (<600) / tablet (600-1023) / laptop (1024+) ----
## @media (min-width:480px) { .stats { grid-template-columns:repeat(2,minmax(0,1fr)); } .gauge-card { grid-column:span 2; flex-direction:row; align-items:center; gap:16px; } .gtxt { flex:1 1 150px; } }
## @media (min-width:700px) { .stats { grid-template-columns:repeat(4,minmax(0,1fr)); } .stats > .stat:nth-last-child(-n+2) { grid-column:span 2; } }
## @media (min-width:1100px) { .stats { grid-template-columns:repeat(5,minmax(0,1fr)); } .stats > .stat:nth-last-child(-n+2) { grid-column:auto; } }
## @media (min-width:1024px) { .cast { display:flex; gap:10px; } button.pick { flex:1 1 0; flex-direction:row; text-align:left; gap:10px; padding:8px 14px 8px 8px; border-radius:999px; } button.pick .tx { align-items:flex-start; } }
## @media (min-width:1400px) { body #volt { max-width:1280px; } button.avatar { width:260px; } }
## @media (max-width:1023px) { .hero { grid-template-columns:minmax(0,1fr); gap:18px; } .now { order:-1; display:grid; grid-template-columns:minmax(0,1fr) auto; column-gap:20px; align-items:center; text-align:left; } .now > * { grid-column:1; } .now .bigrow { grid-column:2; grid-row:1 / span 4; margin:0; } .now .chips { justify-content:flex-start; } }
## @media (max-width:599px) { .now { display:flex; flex-direction:column; align-items:flex-start; } .now .bigrow { margin-top:8px; } .stage { flex-direction:column; align-items:flex-start; } .say { width:100%; align-self:stretch; } .bub::before { left:34px; bottom:auto; top:-14px; transform:rotate(135deg); } .dl { display:none; } .dr { flex:1 1 0; } button.avatar { width:150px; } .search { max-width:none; flex-basis:100%; } .sec { padding:16px; } }
## @media (max-width:479px) { button.pick small { display:none; } button.pick .th { width:42px; height:42px; } .acts button.b { flex:1 1 auto; } }
## @media (max-height:500px) and (orientation:landscape) { button.avatar { width:120px; } .temp { font-size:4.6rem; } }
## @media (prefers-reduced-motion: reduce) { body::before, body::after, .avatar.shake svg, .fresh .needle { animation:none !important; } button.pick, button.b { transition:none; } }

// ------------------------------- state --------------------------------
let unitF = 0
let latT = "-1.2864"
let lonT = "36.8172"
let city = "Nairobi"
let place = "Nairobi, Kenya"

let ready = 0
let loading = 1
let demo = 0
let fresh = 0
let shake = 0
let pokes = 0
let who = 0
let shuf = 0
let lastN = 99
let showRes = 0

let temp = 0
let feels = 0
let hum = 0
let wind = 0
let pres = 0
let wcode = 0
let isDay = 1
let uvMax = 0
let popToday = 0
let nowMin = 0
let riseMin = 0
let setMin = 0
let sunriseT = ""
let sunsetT = ""
let whenText = ""
let updated = ""

let hT = []
let hC = []
let hP = []
let hD = []
let hL = []
let dMax = []
let dMin = []
let dC = []
let dP = []
let dN = []
let dDate = []
let resLabel = []
let resLat = []
let resLon = []

let mood = "huff"
let sayText = ""
let sky = "cloud"

// ------------------------------- units --------------------------------
fn U() {
  if unitF == 1 {
    return "°F"
  }
  return "°C"
}

fn T(c) {
  if unitF == 1 {
    if c < 0 {
      return 32 - ((0 - c) * 18 + 5) / 10
    }
    return (c * 18 + 5) / 10 + 32
  }
  return c
}

fn WK(k) {
  if unitF == 1 {
    return (k * 62 + 50) / 100
  }
  return k
}

fn WUn() {
  if unitF == 1 {
    return "mph"
  }
  return "km/h"
}

// ------------------------- weather vocabulary -------------------------
fn kindOf(c) {
  if c <= 1 { return "clear" }
  if c == 2 { return "partly" }
  if c == 3 { return "cloud" }
  if c == 45 or c == 48 { return "fog" }
  if c >= 51 and c <= 57 { return "drizzle" }
  if c >= 61 and c <= 67 { return "rain" }
  if c >= 71 and c <= 77 { return "snow" }
  if c >= 80 and c <= 82 { return "rain" }
  if c == 85 or c == 86 { return "snow" }
  if c >= 95 { return "storm" }
  return "cloud"
}

fn labelOf(c) {
  if c == 0 { return "Clear sky" }
  if c == 1 { return "Mostly clear" }
  if c == 2 { return "Partly cloudy" }
  if c == 3 { return "Overcast" }
  if c == 45 { return "Fog" }
  if c == 48 { return "Rime fog" }
  if c == 51 { return "Light drizzle" }
  if c == 53 { return "Drizzle" }
  if c == 55 { return "Heavy drizzle" }
  if c == 56 or c == 57 { return "Freezing drizzle" }
  if c == 61 { return "Light rain" }
  if c == 63 { return "Rain" }
  if c == 65 { return "Heavy rain" }
  if c == 66 or c == 67 { return "Freezing rain" }
  if c == 71 { return "Light snow" }
  if c == 73 { return "Snow" }
  if c == 75 { return "Heavy snow" }
  if c == 77 { return "Snow grains" }
  if c == 80 or c == 81 { return "Rain showers" }
  if c == 82 { return "Violent showers" }
  if c == 85 { return "Snow showers" }
  if c == 86 { return "Heavy snow showers" }
  if c == 95 { return "Thunderstorm" }
  if c == 96 { return "Thunderstorm, hail" }
  if c == 99 { return "Severe thunderstorm" }
  return "Weather happened"
}

fn comfort(t, k, w, h, pp) {
  let s = 100 - min(60, abs(t - 23) * 4)
  if k == "storm" { s -= 40 }
  if k == "rain" { s -= 25 }
  if k == "drizzle" { s -= 15 }
  if k == "snow" { s -= 25 }
  if k == "fog" { s -= 10 }
  if w > 25 { s -= min(20, w - 25) }
  if h > 80 { s -= 10 }
  s -= pp * 15 / 100
  return constrain(s, 4, 98)
}

fn category() {
  let k = kindOf(wcode)
  if k == "storm" { return "storm" }
  if k == "snow" { return "snow" }
  if k == "rain" or k == "drizzle" { return "rain" }
  if k == "fog" { return "fog" }
  if wind >= 35 { return "windy" }
  if temp >= 31 { return "hot" }
  if temp >= 26 { return "warm" }
  if temp < 11 { return "cold" }
  if temp < 17 { return "cool" }
  if isDay == 0 { return "night" }
  if k == "clear" or k == "partly" { return "nice" }
  return "grey"
}

fn moodFor(c) {
  if c == "storm" { return "angry" }
  if c == "snow" or c == "cold" { return "shiver" }
  if c == "rain" or c == "windy" or c == "grey" { return "huff" }
  if c == "hot" { return "sweat" }
  if c == "night" or c == "nice" { return "blush" }
  return "smug"
}

fn sfxFor(m) {
  if m == "angry" { return "GRRR!" }
  if m == "huff" { return "HMPH." }
  if m == "blush" { return "AHEM..." }
  if m == "sweat" { return "UGH..." }
  if m == "shiver" { return "BRRR!" }
  return "TCH."
}

fn skyClass() {
  if ready == 0 { return "cloud" }
  let k = kindOf(wcode)
  if k == "storm" { return "storm" }
  if k == "rain" or k == "drizzle" { return "rain" }
  if k == "snow" { return "snow" }
  if k == "fog" { return "fog" }
  if isDay == 0 {
    if k == "cloud" { return "cloud-night" }
    return "night"
  }
  if k == "cloud" { return "cloud" }
  if abs(nowMin - riseMin) <= 40 { return "dawn" }
  if abs(nowMin - setMin) <= 45 { return "dusk" }
  return "day"
}

// ------------------------------ the cast ------------------------------
fn cName(i) {
  if i == 0 { return "Wren" }
  if i == 1 { return "Zuri" }
  if i == 2 { return "Ingrid" }
  return "Leo"
}

fn cRole(i) {
  if i == 0 { return "The pedant" }
  if i == 1 { return "The diva" }
  if i == 2 { return "The ice queen" }
  return "The grump"
}

fn countFor(c) {
  if c == "nice" { return 4 }
  if c == "rain" or c == "warm" { return 3 }
  if c == "grey" or c == "cool" or c == "night" { return 3 }
  return 2
}

// ---- Wren: dry, precise, has read the studies, definitely cares ------
fn wrenLine(c, n) {
  if c == "storm" {
    if n == 0 { return "Thunderstorm over " + city + ". Statistically, indoors is safest. I'm telling you for the sake of the data, not because I'd be bothered if you weren't." }
    return "Lightning. Stay in, unplug the fragile things, and stop standing near the window. That is a recommendation, not concern."
  }
  if c == "rain" {
    if n == 0 { return "It's raining in " + city + ". You could have confirmed this by looking out a window, an invention I'm told is quite old. Take an umbrella. Obviously." }
    if n == 1 { return "Precipitation, " + T(temp) + U() + ". Your shoes are not waterproof and we both know it. I'm not offering spare socks. I'm merely noting that I own some." }
    return "Rain. Cite me when you stay dry. Or don't. I'll know either way."
  }
  if c == "snow" {
    if n == 0 { return "Snow, " + T(temp) + U() + ". Walk like a penguin: small steps, arms out, no dignity. It has worked for them for millions of years." }
    return "Everything is white and slippery. There happen to be gloves in my bag. Take them. They were going spare."
  }
  if c == "fog" {
    if n == 0 { return "Fog. Visibility is poor, which is something it shares with your decision-making. Slow down." }
    return "You can't see ten metres. Lights on, speed down, ego aside."
  }
  if c == "windy" {
    if n == 0 { return WK(wind) + " " + WUn() + " winds. Papers, hats and loose opinions will be airborne. Secure all three." }
    return "Gusty. Your hair will do something regrettable. I'd offer a hair tie, but, well. I have two. Here."
  }
  if c == "hot" {
    if n == 0 { return T(temp) + U() + " in " + city + ". Drink water. Not because I care about your hydration; because your conversation quality drops sharply without it." }
    return "It feels like " + T(feels) + U() + ". Find shade, find a fan, find a brain cell. I've seen worse. Not by much."
  }
  if c == "warm" {
    if n == 0 { return T(temp) + U() + ". Wear something breathable, not whatever you wear to look mysterious." }
    if n == 1 { return "Pleasantly warm. Sunscreen. I won't say it twice. ...I will say it twice, actually. Sunscreen." }
    return "Warm out. Go outside; sunlight is documented to help. I've read the studies. Purely for my own purposes."
  }
  if c == "nice" {
    if n == 0 { return T(temp) + U() + " and clear in " + city + ". It is, regrettably, a very good day. Go outside. I'll be here with my book. Not waiting." }
    if n == 1 { return "Conditions are ideal. I checked three sources. Not because I wanted you to have a good day. Quality control." }
    if n == 2 { return "Don't get used to it, but today is lovely. Take a walk. I may happen to be walking in the same direction. Coincidence." }
    return "It's a beautiful day and I'm glad you get to see it. That's the whole sentence. No footnote this time."
  }
  if c == "grey" {
    if n == 0 { return "Overcast. Neither good nor bad, much like your last three ideas. Bring a jacket." }
    if n == 1 { return T(temp) + U() + " and grey. The sky has the energy of a Monday. So do you." }
    return "Cloudy. Ideal for finally doing the thing you've been avoiding. I'll check in. Rhetorically."
  }
  if c == "cool" {
    if n == 0 { return T(temp) + U() + ". Wear a jacket. 'I'll be fine' is not a data point." }
    if n == 1 { return "A bit cool. Layer up. Being sniffled at all day is not an experience I'm opting into." }
    return "Cool and crisp. Hot drinks weather. I made too much tea this morning, by the way. Hypothetically."
  }
  if c == "cold" {
    if n == 0 { return T(temp) + U() + ". Coat, gloves, hat. A sweater is not a plan." }
    return "Feels like " + T(feels) + U() + ". If you get sick I'll be forced to bring you soup. That is not an offer. It's a threat."
  }
  if n == 0 { return "It's night, " + T(temp) + U() + ". Sleep is not optional, it's biology. Go. I'll be up reading. Unrelated." }
  if n == 1 { return "Why are you checking the weather at this hour? It will be the same after you sleep. Goodnight. Not warmly." }
  return "Clear and quiet out. The stars are visible if you look up, which you won't, because you're looking at a phone. As am I."
}

// ---- Zuri: fabulous, loud, would never admit she checked on you -------
fn zuriLine(c, n) {
  if c == "storm" {
    if n == 0 { return "Thunderstorm in " + city + ". Stay home. My hair did NOT survive the last one. ...Stay safe, though. Not that I'm asking." }
    return "Lightning. Rude. Unplug something, sit down, and do not film it from the window. I like you in one piece."
  }
  if c == "rain" {
    if n == 0 { return "It's raining. Do NOT wear the white sneakers. I say this for the sake of everyone who has to look at you." }
    if n == 1 { return "Wet out there, " + T(temp) + U() + ". Umbrella. A big one. Not that I'm walking under it with you. Unless it's big." }
    return "Rain again. Sawa, put on a jacket with a hood. You in a soggy tee is a look I can't unsee."
  }
  if c == "snow" {
    if n == 0 { return "Snow. Bundle up. A puffer coat is fashion AND physics. Don't argue." }
    return "Slippery out. Walk like you have somewhere to be and nowhere to fall."
  }
  if c == "fog" {
    if n == 0 { return "Fog. Mysterious, moody, terrible for photos. Drive slow." }
    return "Can't see a thing out there. Headlights on. Even I can't make 'crashed into a bin' look good."
  }
  if c == "windy" {
    if n == 0 { return WK(wind) + " " + WUn() + " wind. Hair, hat, skirt: secure everything. I mean you. Secure yourself." }
    return "Windy. Lip gloss plus wind equals hair stuck to your face. Learn from my pain."
  }
  if c == "hot" {
    if n == 0 { return T(temp) + U() + ". Linen. Sunglasses. Water. If you show up sweaty, I'm pretending not to know you." }
    return "It's " + T(temp) + U() + " in " + city + ", feels like " + T(feels) + U() + ". Drink water. I've said it, I won't say it again. Okay, I'll say it again later."
  }
  if c == "warm" {
    if n == 0 { return T(temp) + U() + ". Warm. Wear something light. Not that grey hoodie again. We talked about it." }
    if n == 1 { return "Nice warm day. Go out, be seen. I'd say 'be seen with me' but let's not get ahead of ourselves." }
    return "Warm and bright. Sunscreen. Glowing is cute, burnt is not."
  }
  if c == "nice" {
    if n == 0 { return T(temp) + U() + " and clear in " + city + ". Literally perfect. So obviously I'm in a good mood. Which is not YOUR doing." }
    if n == 1 { return "Gorgeous out. Go outside, wear something decent, take pictures. Send me one. For quality control. Only." }
    if n == 2 { return "The weather's showing off today and honestly? Same. Get out of the house. I'm leaving in five. You can... come along if you're ready." }
    return "Today's gorgeous and so are you. Don't let it go to your head. ...Okay, a little to your head. Just today."
  }
  if c == "grey" {
    if n == 0 { return "Overcast. The sky is in a mood. It's a vibe, but bring a jacket." }
    if n == 1 { return T(temp) + U() + " and grey. Great for moody photos, bad for your attitude. Pick one." }
    return "Cloudy. Perfect day to be productive. Yes, YOU."
  }
  if c == "cool" {
    if n == 0 { return T(temp) + U() + ". Cool. Layer up. The oversized cardigan, not the one with holes. ...Okay the one with holes is vintage. Whatever." }
    if n == 1 { return "Chilly. Grab a jacket. No, 'cold is a mindset' is not a jacket." }
    return "Cool weather means scarves, and scarves mean looking good effortlessly. Use this knowledge."
  }
  if c == "cold" {
    if n == 0 { return T(temp) + U() + ". Coat. Scarf. Beanie. You are not 'tough', you are 'cold and sniffling'." }
    return "Feels like " + T(feels) + U() + ". Bundle up. I'm not lending you my scarf. ...Okay, fine, a corner of it."
  }
  if n == 0 { return "It's night. Sleep. You need your beauty rest more than I do. Which is saying something, because I need almost none." }
  if n == 1 { return "Why are you checking the weather at this hour? Bed. Now. Also the sky is gorgeous tonight. Don't tell anyone I said so." }
  return T(temp) + U() + " and clear. Go to sleep. And text me if you can't. ...I said what I said."
}

// ---- Ingrid: regal, formal, secretly knitted you something -----------
fn ingridLine(c, n) {
  if c == "storm" {
    if n == 0 { return "A thunderstorm in " + city + ". I would remain indoors, were I you. I am not concerned. I merely dislike unnecessary funerals." }
    return "The heavens are loud today. Unplug your devices and remain seated. Obey. For your own sake, not mine."
  }
  if c == "rain" {
    if n == 0 { return "Rain. A commoner gets wet. A prepared person carries an umbrella. Be prepared." }
    if n == 1 { return T(temp) + U() + " and wet. Your coat is on the hook. Wear it. I will not lend you mine; it is cashmere, and you are chaos." }
    return "It is raining. I was not going to mention it, but there is a second umbrella in my bag. By coincidence. Take it."
  }
  if c == "snow" {
    if n == 0 { return "Snow. At last, weather with some dignity. You, however, will slip. Wear boots with proper grip." }
    return T(temp) + U() + ". This is my climate, not yours. You will want three layers and a better attitude."
  }
  if c == "fog" {
    if n == 0 { return "Fog. The world has been veiled. Drive carefully and at a sensible speed, as befits a person of limited vision." }
    return "I cannot see the end of the street. Lights on. Slowly. That is an order."
  }
  if c == "windy" {
    if n == 0 { return WK(wind) + " " + WUn() + " winds. My braid is unbothered. Yours will not be. Secure your hat." }
    return "Gusts. Hold your hat, hold your papers, and hold your tongue about my hair."
  }
  if c == "hot" {
    if n == 0 { return T(temp) + U() + ". I find this intolerable, and I am not even the one sweating. Drink water. Seek shade. Cool yourself, subject." }
    return "Feels like " + T(feels) + U() + ". I am melting. Metaphorically. Bring me a cold drink. ...Bring yourself one too, I suppose."
  }
  if c == "warm" {
    if n == 0 { return T(temp) + U() + ". Acceptable. Wear lighter fabrics. Linen, cotton. Not whatever that is." }
    if n == 1 { return "A warm day. Do go outdoors; sunlight does wonders for your dreary disposition." }
    return "Warm and bright. Sunscreen and a wide-brimmed hat. I shall not repeat this royal decree."
  }
  if c == "nice" {
    if n == 0 { return T(temp) + U() + " and clear in " + city + ". A splendid day. Go and enjoy it. I shall remain here, composed. Unmoved. ...Smiling slightly, perhaps. Briefly." }
    if n == 1 { return "The weather is, I admit, exceptional. Do not mistake my approval for affection." }
    if n == 2 { return "A pleasant day. A stroll is in order. I may accompany you, purely to supervise." }
    return "It is a beautiful day, and I am glad you are here to see it with me. I will not repeat myself, so listen well."
  }
  if c == "grey" {
    if n == 0 { return "Overcast. The sky mirrors your ambitions: grey, and indecisive. Bring a coat." }
    if n == 1 { return T(temp) + U() + " and dreary. Not even the clouds have conviction. Be better than the clouds." }
    return "Clouds. A fine day for tea and for completing the tasks you have deferred. I will be pouring. For myself."
  }
  if c == "cool" {
    if n == 0 { return T(temp) + U() + ". Cool. A coat is wise. Do not insult me by declaring yourself 'fine'." }
    if n == 1 { return "Cool air. A wool scarf is advisable. Preferably the one I left on your chair. By accident." }
    return "A crisp day. Most agreeable. Dress warmly, or suffer in silence. I will pretend not to hear the sniffling."
  }
  if c == "cold" {
    if n == 0 { return T(temp) + U() + ". Finally, civilised weather. You will need a heavier coat, gloves and a hat. I am not worried. I am disappointed in advance." }
    return "Feels like " + T(feels) + U() + ". Dress in layers. If you freeze, the paperwork will be tedious."
  }
  if n == 0 { return "It is night. Retire. The forecast will be just as unimpressive in the morning." }
  if n == 1 { return T(temp) + U() + " under a clear sky. Rest. I do not stay up for others. ...The stars are remarkable tonight. Do not tell anyone." }
  return "Why consult the weather at this hour? Go to bed, subject. Goodnight. That was not a pleasantry."
}

// ---- Leo: gruff, awkward, definitely brought you a hoodie -------------
fn leoLine(c, n) {
  if c == "storm" {
    if n == 0 { return "Storm. Stay in. Not like I'm worried or anything. I just don't wanna carry your stuff if you get fried." }
    return "Thunder, " + T(temp) + U() + ". Unplug stuff. Sit down. Don't be a hero. Heroes get hit by lightning."
  }
  if c == "rain" {
    if n == 0 { return "It's raining. Take an umbrella, dude. ...Or don't, see if I care. (Take it.)" }
    if n == 1 { return T(temp) + U() + " and wet. Your shoes are gonna die. Wear the boots. Yeah, those." }
    return "Rain. I've got a spare hoodie in my bag. Why? No reason. Do you want it or not?"
  }
  if c == "snow" {
    if n == 0 { return "Snow. Cool. I mean cold. I mean... just wear a coat, idiot." }
    return "Slippery out. Watch your step. If you fall I'm not laughing. I'm... okay, I'm laughing a little."
  }
  if c == "fog" {
    if n == 0 { return "Fog. Can't see squat. Go slow. Seriously." }
    return "It's like soup out there. Lights on. Don't be a hero."
  }
  if c == "windy" {
    if n == 0 { return WK(wind) + " " + WUn() + " wind. Hold onto your hat. And your stuff. And... never mind." }
    return "Super windy. Your hair's gonna be a disaster. Not that it wasn't. Okay, bad joke."
  }
  if c == "hot" {
    if n == 0 { return T(temp) + U() + ". It's boiling. Drink water. Don't make me carry you home. I will, but I'll complain." }
    return "Feels like " + T(feels) + U() + " in " + city + ". Hat. Water. Shade. Don't be dumb about it."
  }
  if c == "warm" {
    if n == 0 { return T(temp) + U() + ". Nice and warm. Wear a t-shirt like a normal person." }
    if n == 1 { return "Warm out. Go outside, get some sun. You look like you live in a cave. No offense. Some offense." }
    return "Warm day. Sunscreen. My mom says it works. Not that I use it. Okay, I use it."
  }
  if c == "nice" {
    if n == 0 { return T(temp) + U() + " and clear in " + city + ". It's, uh, a good day. A really good day. Go outside. Whatever. Wanna go skate? ...I mean, if you're free. Don't make it weird." }
    if n == 1 { return "Perfect weather. Don't just sit around. Not that I wanna hang out. I just have nothing better to do." }
    if n == 2 { return "Nice day. Seriously. Get out of the house. I'll... maybe see you out there. Maybe." }
    return "It's a really nice day. I'm glad you're around for it. ...Yeah, I said it. Don't look at me like that."
  }
  if c == "grey" {
    if n == 0 { return "Overcast. Meh. Bring a jacket and a better mood." }
    if n == 1 { return T(temp) + U() + " and grey. Boring weather. Like homework. Go do something anyway." }
    return "Cloudy. Not great, not terrible. Kinda like you. (That was a compliment. Sort of.)"
  }
  if c == "cool" {
    if n == 0 { return T(temp) + U() + ". Chilly. Hoodie. Wear it. Don't make me say it twice." }
    if n == 1 { return "It's cool out. Grab a jacket. Your nose goes red when it's cold. Not that I notice." }
    return "Cool and crisp. Good for hot chocolate. I'm making some. For me. There's extra. Whatever."
  }
  if c == "cold" {
    if n == 0 { return T(temp) + U() + ". Wear a coat, gloves, the whole thing. Don't tough it out, that's dumb." }
    return "Feels like " + T(feels) + U() + ". You're gonna freeze. Here, take my scarf. ...It was just sitting here. Take it."
  }
  if n == 0 { return "It's late. Go to sleep, man. The weather'll be the same tomorrow. Probably." }
  if n == 1 { return T(temp) + U() + " and clear. Sky's pretty cool tonight. Don't tell anyone I said that." }
  return "Why are you up? Bed. Now. I'm going too. Not because of you. I'm just tired. Night."
}

fn lineFor(c, n) {
  if who == 0 { return wrenLine(c, n) }
  if who == 1 { return zuriLine(c, n) }
  if who == 2 { return ingridLine(c, n) }
  return leoLine(c, n)
}

// ---------------------------- poke lines -----------------------------
fn pokeLine(n) {
  if who == 0 {
    if n == 1 { return "Please do not poke the researcher." }
    if n == 2 { return "That is the second time. There is no experiment here." }
    if n == 3 { return "Stop. Poking. Is. Not. Data." }
    return "...It is, technically, an interactive element. Still: stop."
  }
  if who == 1 {
    if n == 1 { return "Excuse me?! Hands off the hair." }
    if n == 2 { return "I SAID don't. Do you have no boundaries?" }
    if n == 3 { return "Stop. Poking. The. Diva." }
    return "...Okay, technically it's a button. STILL."
  }
  if who == 2 {
    if n == 1 { return "You dare touch royalty?" }
    if n == 2 { return "Once is a mistake. Twice is insolence." }
    if n == 3 { return "Enough. I will have you removed." }
    return "...Very well, it is a button. Cease at once."
  }
  if n == 1 { return "Hey! Quit it." }
  if n == 2 { return "I said stop. Are you five?" }
  if n == 3 { return "Dude. Stop. Poking. Me." }
  return "...Yeah, okay, it's a button. Still. Stop."
}

fn pokeSoft() {
  if who == 0 { return "...Fine. A few more. For science. Idiot." }
  if who == 1 { return "Fine. Poke away. Only because I'm in a good mood. Don't push it." }
  if who == 2 { return "...Continue, then. Gently. I have decided to permit it." }
  return "...Fine. Whatever. A couple more. Doesn't bother me."
}

// the mask fully drops, no qualifier walked back - the real payoff for
// sticking around, not a one-time easter egg
fn pokeTrueDere() {
  if who == 0 { return "...Fine, I'll say it properly, once. I check the forecast every morning because of you, not the isobars. There. Don't make this weird. I will deny this conversation happened." }
  if who == 1 { return "Okay, don't repeat this: you showing up and poking this stupid button every day is genuinely the best part of mine. There, I said it. Now never bring it up or I'm denying everything." }
  if who == 2 { return "Very well - the truth, once, under duress: I enjoy this. Your company, specifically. I will deny having said it, and you will let me." }
  return "...Okay, real talk, for real this time. I like when you check in. It's a good part of my day. Don't - don't make a thing of it. I mean it. ...Thanks, though."
}

// ------------------------- system messages ---------------------------
fn sysWren(kind) {
  if kind == "loading" { return "One moment. I'm consulting the sources. This is my job and has nothing to do with you." }
  if kind == "empty" { return "Type a city. Letters, in the box. I believe in your motor skills." }
  if kind == "searching" { return "Searching. It takes however long it takes. Stop watching." }
  if kind == "nosearch" { return "The search server isn't answering. Not my fault. Check your connection." }
  if kind == "notplace" { return "That is not a place. Check your spelling." }
  if kind == "several" { return "Several matches. Choose carefully. I have faith. Mild faith." }
  if kind == "locating" { return "Triangulating you. Hold still. Metaphorically." }
  return "Couldn't find you. Type a city like a normal person."
}

fn sysZuri(kind) {
  if kind == "loading" { return "Hold on, checking the sky. Don't rush me. Nobody rushes me." }
  if kind == "empty" { return "Type a city. In the box. With your fingers. You can do it." }
  if kind == "searching" { return "Looking it up. Stop hovering." }
  if kind == "nosearch" { return "The search server is ignoring me. Rude. Not my fault, check your Wi-Fi." }
  if kind == "notplace" { return "That's not a place. Spell it right. I'm begging." }
  if kind == "several" { return "Multiple places. Pick one. Choose well, I'm watching." }
  if kind == "locating" { return "Finding you. Stop moving. Stop being dramatic." }
  return "Couldn't find you. Lost again? Type a city."
}

fn sysIngrid(kind) {
  if kind == "loading" { return "Patience. I am consulting the heavens. They do not hurry for you." }
  if kind == "empty" { return "A place name is required. Type it in the box. Slowly, if necessary." }
  if kind == "searching" { return "I am looking. Cease hovering." }
  if kind == "nosearch" { return "The search servers are silent. Check your connection. I am blameless." }
  if kind == "notplace" { return "That is not a place. Spell it properly." }
  if kind == "several" { return "Several places match. Select one. Wisely." }
  if kind == "locating" { return "Locating you. Remain where you are." }
  return "You are unfindable. Type a city instead."
}

fn sysLeo(kind) {
  if kind == "loading" { return "Hang on, pulling it up. Don't stare." }
  if kind == "empty" { return "You gotta type a city first, dude." }
  if kind == "searching" { return "Looking it up. Quit hovering." }
  if kind == "nosearch" { return "Search server's down. Not my fault. Check your connection." }
  if kind == "notplace" { return "That's not a real place, dude. Spelling." }
  if kind == "several" { return "A few matches. Pick one. Don't overthink it." }
  if kind == "locating" { return "Finding you. This'd be faster if you stayed put." }
  return "Couldn't find you. Just type a city, man."
}

fn sys(kind) {
  if who == 0 { return sysWren(kind) }
  if who == 1 { return sysZuri(kind) }
  if who == 2 { return sysIngrid(kind) }
  return sysLeo(kind)
}

fn speak() {
  if shuf == 1 {
    let w = random(0, 3)
    if w == who {
      w = (w + 1) % 4
    }
    who = w
  }
  let c = category()
  let cnt = countFor(c)
  let n = random(0, cnt - 1)
  if n == lastN and cnt > 1 {
    n = (n + 1) % cnt
  }
  lastN = n
  sayText = lineFor(c, n)
  mood = moodFor(c)
}

// ------------------------------ drawing -------------------------------
fn rays(a, b) {
  let s = ""
  for k from 0 to 7 {
    s += "<line x1='" + a + "' y1='0' x2='" + b + "' y2='0' transform='rotate(" + (k * 45) + ")'/>"
  }
  return s
}

fn sunSvg(cx, cy, r) {
  return "<g transform='translate(" + cx + " " + cy + ")'><circle r='" + r + "' class='i-sun'/><g class='i-ray'>" + rays(r + 3, r + 6) + "</g></g>"
}

fn moonSvg(x, y, s) {
  return "<path class='i-moon' transform='translate(" + x + " " + y + ") scale(" + s + ")' d='M24 4 A18 18 0 1 0 42 28 A14 14 0 0 1 24 4 Z'/>"
}

fn cloudSvg(x, y, s, cls) {
  return "<g class='" + cls + "' transform='translate(" + x + " " + y + ") scale(" + s + ")'><circle cx='14' cy='26' r='7'/><circle cx='24' cy='21' r='9'/><circle cx='33' cy='26' r='6.5'/><rect x='14' y='26' width='19' height='7'/></g>"
}

fn iconInner(k, day) {
  if k == "clear" {
    if day == 1 { return sunSvg(24, 24, 8) }
    return moonSvg(0, 0, "1")
  }
  if k == "partly" {
    if day == 1 { return sunSvg(17, 17, 6) + cloudSvg(4, 8, "1", "i-cloud") }
    return moonSvg(-2, -2, "0.7") + cloudSvg(4, 8, "1", "i-cloud")
  }
  if k == "fog" {
    return cloudSvg(0, -6, "1", "i-cloud") + "<line x1='10' y1='33' x2='38' y2='33' class='i-fog'/><line x1='12' y1='38' x2='36' y2='38' class='i-fog'/><line x1='14' y1='43' x2='34' y2='43' class='i-fog'/>"
  }
  if k == "rain" or k == "drizzle" {
    return cloudSvg(0, -5, "1", "i-cloud") + "<line x1='16' y1='32' x2='13' y2='41' class='i-rain'/><line x1='24' y1='32' x2='21' y2='41' class='i-rain'/><line x1='32' y1='32' x2='29' y2='41' class='i-rain'/>"
  }
  if k == "snow" {
    return cloudSvg(0, -5, "1", "i-cloud") + "<circle cx='16' cy='34' r='1.9' class='i-snow'/><circle cx='24' cy='38' r='1.9' class='i-snow'/><circle cx='32' cy='34' r='1.9' class='i-snow'/><circle cx='20' cy='43' r='1.9' class='i-snow'/><circle cx='28' cy='43' r='1.9' class='i-snow'/>"
  }
  if k == "storm" {
    return cloudSvg(0, -6, "1", "i-cloud dk") + "<polygon class='i-bolt' points='26,26 18,38 24,38 21,47 32,33 26,33 30,26'/>"
  }
  return cloudSvg(-1, 2, "1.1", "i-cloud")
}

fn icon(k, day, size) {
  return "<svg class='ico' viewBox='0 0 48 48' width='" + size + "' height='" + size + "' aria-hidden='true'>" + iconInner(k, day) + "</svg>"
}

// ---- faces: one small function per feature; the mood picks the mix ----
fn eyeSvg(cx, cy, dx, dy, ry, lid) {
  let s = "<ellipse cx='" + cx + "' cy='" + cy + "' rx='10' ry='" + ry + "' fill='#fff' stroke='var(--line)' stroke-width='2'/>"
  s += "<circle cx='" + (cx + dx) + "' cy='" + (cy + dy) + "' r='5.5' fill='var(--pup)'/><circle cx='" + (cx + dx) + "' cy='" + (cy + dy) + "' r='2.6' fill='var(--line)'/><circle cx='" + (cx + dx + 2) + "' cy='" + (cy + dy - 2) + "' r='1.3' fill='#fff'/>"
  if lid == 1 {
    s += "<rect x='" + (cx - 12) + "' y='" + (cy - ry - 2) + "' width='24' height='" + (ry + 2) + "' fill='var(--skin)'/><path d='M" + (cx - 11) + " " + cy + " H" + (cx + 11) + "' stroke='var(--line)' stroke-width='3' stroke-linecap='round'/>"
  }
  return s
}

fn lineSvg(d, w) {
  return "<path d='" + d + "' stroke='var(--line)' stroke-width='" + w + "' stroke-linecap='round' stroke-linejoin='round' fill='none'/>"
}

fn browSvg(a, b) {
  return "<path d='" + a + "' stroke='var(--brow)' stroke-width='5' stroke-linecap='round' fill='none'/><path d='" + b + "' stroke='var(--brow)' stroke-width='5' stroke-linecap='round' fill='none'/>"
}

fn cheekSvg(col, op) {
  return "<ellipse cx='62' cy='140' rx='11' ry='6' fill='" + col + "' opacity='" + op + "'/><ellipse cx='138' cy='140' rx='11' ry='6' fill='" + col + "' opacity='" + op + "'/>"
}

fn heartSvg(x, y, s) {
  return "<path transform='translate(" + x + " " + y + ") scale(" + s + ")' d='M0 -2 C0 -7 -7 -7 -7 -2 C-7 2 0 6 0 8 C0 6 7 2 7 -2 C7 -7 0 -7 0 -2 Z' fill='#FF5C7A'/>"
}

fn faceSvg(m) {
  if m == "angry" {
    return cheekSvg("var(--blush)", ".35") + browSvg("M58 92 L90 108", "M142 92 L110 108") + eyeSvg(76, 123, 4, 1, 8, 0) + eyeSvg(124, 123, -4, 1, 8, 0) + lineSvg("M86 156 Q100 142 114 156", "3.5") + "<path d='M150 70 l9 -9 M164 84 l12 -3 M146 56 l2 -12' stroke='#FF4D4D' stroke-width='3.4' stroke-linecap='round' fill='none'/>"
  }
  if m == "huff" {
    return cheekSvg("var(--blush)", ".4") + browSvg("M62 101 L88 98", "M112 98 L138 101") + eyeSvg(76, 122, 6, 0, 10, 1) + eyeSvg(124, 122, 6, 0, 10, 1) + "<ellipse cx='106' cy='151' rx='6' ry='4' fill='var(--line)'/>"
  }
  if m == "blush" {
    return cheekSvg("var(--blush)", ".9") + browSvg("M62 97 Q74 90 88 99", "M112 99 Q126 90 138 97") + eyeSvg(76, 122, -4, 3, 11, 0) + eyeSvg(124, 122, -4, 3, 11, 0) + lineSvg("M89 151 Q94 146 99 151 T110 151", "3.5") + heartSvg(168, 100, "0.9") + heartSvg(34, 110, "0.7")
  }
  if m == "sweat" {
    return cheekSvg("var(--blush)", ".3") + browSvg("M62 101 L86 105", "M114 105 L138 101") + eyeSvg(76, 124, 0, 2, 9, 1) + eyeSvg(124, 124, 0, 2, 9, 1) + lineSvg("M88 153 Q94 149 100 153 T112 153", "3.5") + "<path d='M160 100 q9 13 0 20 q-9 -7 0 -20 z' fill='#6DB3FF'/><path d='M42 92 q7 10 0 16 q-7 -6 0 -16 z' fill='#6DB3FF' opacity='.8'/>"
  }
  if m == "shiver" {
    return cheekSvg("#58BDE8", ".55") + browSvg("M62 99 L86 102", "M114 102 L138 99") + eyeSvg(76, 122, 0, 0, 12, 0) + eyeSvg(124, 122, 0, 0, 12, 0) + lineSvg("M88 152 l4 -5 l4 5 l4 -5 l4 5 l4 -5 l4 5", "3.5") + "<path d='M26 96 l-9 -4 M28 112 l-11 0 M174 96 l9 -4 M172 112 l11 0' stroke='#BFE6FF' stroke-width='3' stroke-linecap='round'/>"
  }
  return cheekSvg("var(--blush)", ".3") + browSvg("M60 101 L86 93", "M114 98 L138 102") + eyeSvg(76, 122, 3, 1, 10, 1) + eyeSvg(124, 122, 3, 1, 10, 1) + lineSvg("M86 147 Q100 159 114 144", "3.5")
}

// ---- the cast: palette, hair, outfit and little extras per character ----
fn pal(i) {
  if i == 0 { return "--hair:#3B2A2A;--brow:#3B2A2A;--skin:#F4D2B8;--uni:#2F7D6D;--uni2:#3E9A88;--uni3:#4DB39E;--item:#F2C14E;--pup:#6B4A33;--line:#2A1D1D;--blush:#FF7A8A;" }
  if i == 1 { return "--hair:#1E1416;--brow:#1E1416;--skin:#8A5A3C;--uni:#E0622A;--uni2:#F27D43;--uni3:#FF9A62;--item:#2B2B4A;--pup:#3A2418;--line:#1E1416;--blush:#E0574A;" }
  if i == 2 { return "--hair:#E7ECF7;--brow:#9AA6C2;--skin:#FBE5DB;--uni:#44557F;--uni2:#566A9C;--uni3:#6B83B8;--item:#8EC9F0;--pup:#4C86C6;--line:#2C3556;--blush:#FFA3B5;" }
  return "--hair:#B8341F;--brow:#7A2416;--skin:#D8A074;--uni:#343A48;--uni2:#454C5E;--uni3:#575F74;--item:#F0B429;--pup:#4A3426;--line:#2A1D1D;--blush:#D9695A;"
}

fn hairBack(i) {
  if i == 0 {
    return "<path class='hair' d='M40 104 C30 44 170 44 160 104 L168 176 Q100 194 32 176 Z'/>"
  }
  if i == 1 {
    return "<ellipse class='hair' cx='100' cy='58' rx='66' ry='48'/><circle class='hair' cx='38' cy='106' r='22'/><circle class='hair' cx='162' cy='106' r='22'/>"
  }
  if i == 2 {
    return "<path class='hair' d='M38 104 C26 40 174 40 162 104 C172 170 176 220 170 262 L30 262 C24 220 28 170 38 104 Z'/>"
  }
  return ""
}

fn hairFront(i) {
  if i == 0 {
    return "<path class='hair' d='M44 114 C34 14 166 14 156 114 L148 114 L148 92 Q100 102 52 92 L52 114 Z'/>"
  }
  if i == 1 {
    return "<path class='hair' d='M46 112 C38 12 162 12 154 112 C150 92 130 80 100 80 C70 80 50 92 46 112 Z'/>"
  }
  if i == 2 {
    return "<path class='hair' d='M44 114 C38 14 162 14 156 114 C152 92 126 70 100 62 C74 70 48 92 44 114 Z'/>"
  }
  return "<path class='hair' d='M44 112 L38 64 L56 62 L54 30 L76 52 L88 16 L104 50 L124 20 L130 52 L150 34 L148 66 L162 62 L156 112 C150 94 130 84 100 84 C70 84 50 94 44 112 Z'/>"
}

fn furCollar() {
  let s = ""
  for k from 0 to 7 {
    s += "<circle cx='" + (62 + k * 11) + "' cy='" + (204 + abs(2 * k - 7) * 2) + "' r='10' fill='#E6EAF5'/>"
  }
  for k from 0 to 7 {
    s += "<circle cx='" + (62 + k * 11) + "' cy='" + (192 + abs(2 * k - 7) * 2) + "' r='11' fill='#F5F7FC' stroke='rgba(60,70,110,.22)' stroke-width='1.5'/>"
  }
  return s
}

fn outfit(i) {
  if i == 0 {
    return "<path fill='#fff' d='M70 184 L100 210 L130 184 Z'/><path class='collar' d='M62 200 L100 232 L138 200 L128 186 L100 206 L72 186 Z'/><path class='item' d='M100 206 l-15 -8 v16 z M100 206 l15 -8 v16 z'/><circle class='item' cx='100' cy='206' r='4.5'/>"
  }
  if i == 1 {
    return "<path fill='var(--uni2)' stroke='rgba(0,0,0,.18)' stroke-width='2' d='M50 200 Q100 244 150 200 L142 184 Q100 214 58 184 Z'/><path d='M90 212 V244 M110 212 V244' stroke='var(--item)' stroke-width='3' stroke-linecap='round'/><circle cx='90' cy='246' r='4' fill='var(--item)'/><circle cx='110' cy='246' r='4' fill='var(--item)'/>"
  }
  if i == 2 {
    return furCollar() + "<circle class='item' cx='100' cy='226' r='6' stroke='#fff' stroke-width='1.5'/>"
  }
  return "<path fill='var(--uni2)' stroke='rgba(0,0,0,.25)' stroke-width='2' d='M56 200 L88 188 L98 226 L58 230 Z'/><path fill='var(--uni2)' stroke='rgba(0,0,0,.25)' stroke-width='2' d='M144 200 L112 188 L102 226 L142 230 Z'/><path class='item' d='M120 214 L142 208 L148 254 L124 258 Z'/><path d='M123 234 L146 230 M124 245 L147 241' stroke='rgba(0,0,0,.22)' stroke-width='3'/><path class='item' d='M66 182 Q100 212 134 182 L140 200 Q100 232 60 200 Z'/>"
}

fn arms() {
  return "<path d='M50 246 L156 266' stroke='var(--uni2)' stroke-width='28' stroke-linecap='round'/><path d='M150 246 L44 268' stroke='var(--uni3)' stroke-width='28' stroke-linecap='round'/><circle class='skin' cx='160' cy='270' r='12'/><circle class='skin' cx='42' cy='272' r='12'/>"
}

fn braid() {
  let s = ""
  for k from 0 to 6 {
    s += "<ellipse class='hair' cx='" + (60 - k * 2) + "' cy='" + (176 + k * 16) + "' rx='11' ry='10'/>"
  }
  s += "<ellipse class='hair' cx='48' cy='287' rx='7' ry='5'/><rect class='item' x='38' y='273' width='20' height='8' rx='3'/>"
  return s
}

fn extras(i) {
  if i == 0 {
    return "<circle cx='76' cy='122' r='16' fill='rgba(255,255,255,.2)' stroke='#2A2A3A' stroke-width='3'/><circle cx='124' cy='122' r='16' fill='rgba(255,255,255,.2)' stroke='#2A2A3A' stroke-width='3'/><path d='M92 120 Q100 114 108 120' stroke='#2A2A3A' stroke-width='3' fill='none'/><path d='M60 120 L47 116 M140 120 L153 116' stroke='#2A2A3A' stroke-width='3' stroke-linecap='round'/>"
  }
  if i == 1 {
    return "<path d='M46 100 C70 72 130 72 154 100' stroke='var(--item)' stroke-width='8' stroke-linecap='round' fill='none'/><circle cx='48' cy='146' r='9' fill='none' stroke='#F4C542' stroke-width='3'/><circle cx='152' cy='146' r='9' fill='none' stroke='#F4C542' stroke-width='3'/>"
  }
  if i == 2 {
    return "<path class='item' d='M138 74 l7 -7 l7 7 l-7 7 z' stroke='#fff' stroke-width='1.5'/><circle cx='51' cy='146' r='3.5' fill='#8EC9F0' stroke='#fff' stroke-width='1'/><circle cx='149' cy='146' r='3.5' fill='#8EC9F0' stroke='#fff' stroke-width='1'/>"
  }
  return "<rect x='46' y='134' width='30' height='10' rx='3' fill='#F6E3C8' stroke='rgba(0,0,0,.22)' transform='rotate(-20 61 139)'/><circle cx='55' cy='139' r='1.2' fill='rgba(0,0,0,.25)'/><circle cx='67' cy='135' r='1.2' fill='rgba(0,0,0,.25)'/>"
}

fn avatarSvg(i, m, thumb) {
  let vb = "0 0 200 290"
  if thumb == 1 {
    vb = "22 6 156 172"
  }
  let s = "<svg viewBox='" + vb + "' style='" + pal(i) + "' aria-hidden='true'>"
  s += hairBack(i)
  s += "<path class='uni' d='M26 290 C26 214 60 182 100 182 C140 182 174 214 174 290 Z'/><rect class='skin' x='88' y='160' width='24' height='28' rx='8'/>"
  s += outfit(i)
  s += arms()
  if i == 2 {
    s += braid()
  }
  s += "<ellipse class='skin' cx='100' cy='112' rx='56' ry='60'/>"
  s += hairFront(i)
  s += faceSvg(m)
  s += extras(i)
  s += "</svg>"
  return s
}

fn gaugeSvg(dere) {
  let ang = dere * 180 / 100 - 90
  let s = "<svg viewBox='0 0 200 124' aria-hidden='true'><defs><linearGradient id='gg' x1='0' x2='1'><stop offset='0' stop-color='#6DB3FF'/><stop offset='.5' stop-color='#C58BFF'/><stop offset='1' stop-color='#FF6FA5'/></linearGradient></defs>"
  s += "<path d='M20 100 A80 80 0 0 1 180 100' fill='none' stroke='rgba(255,255,255,.18)' stroke-width='16' stroke-linecap='round'/>"
  s += "<path d='M20 100 A80 80 0 0 1 180 100' fill='none' stroke='url(#gg)' stroke-width='16' stroke-linecap='round'/>"
  s += "<g class='needle' style='--a:" + ang + "deg'><line x1='100' y1='100' x2='100' y2='36' stroke='#fff' stroke-width='4' stroke-linecap='round'/><circle cx='100' cy='100' r='8' fill='#fff'/></g>"
  s += "<text x='20' y='120' class='gl'>TSUN</text><text x='180' y='120' class='gl' text-anchor='end'>DERE</text></svg>"
  return s
}

// ------------------------------- helpers ------------------------------
fn esc(s) {
  # return String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

fn typeIt() {
  # clearInterval(window.__bbTimer);
  # const g = document.querySelector('.ghost'), t = document.querySelector('.typed');
  # if (!g || !t) return 0;
  # const full = g.textContent;
  # if (matchMedia('(prefers-reduced-motion: reduce)').matches) { t.textContent = full; return 0; }
  # let i = 0;
  # window.__bbTimer = setInterval(() => { i += 2; t.textContent = full.slice(0, i); if (i >= full.length) clearInterval(window.__bbTimer); }, 16);
}

fn statCardSm(k, v, c) {
  return "<div class='card stat'><span class='k'>" + k + "</span><span class='v sm'>" + v + "</span><span class='c'>" + c + "</span></div>"
}

fn statCard(k, v, c) {
  return "<div class='card stat'><span class='k'>" + k + "</span><span class='v'>" + v + "</span><span class='c'>" + c + "</span></div>"
}

// ------------------------------- sections -----------------------------
fn headerHtml() {
  let onC = ""
  let onF = ""
  if unitF == 1 {
    onF = " on"
  } else {
    onC = " on"
  }
  let h = "<header class='top'><div class='brand'><h1>Cold Shoulder</h1><span>Weather, but rude. Four forecasters, zero warmth (allegedly).</span></div>"
  h += "<form class='search' onsubmit='return searchSubmit(event)' autocomplete='off' role='search'><input name='q' aria-label='Search for a city' placeholder='Search a city' maxlength='80'><button class='b primary' type='submit'>Go</button>"
  if showRes == 1 {
    h += "<ul class='res'>"
    for i from 0 to length(resLabel) - 1 {
      h += "<li><button type='button' onclick='pickResult(" + i + ")'>" + esc(resLabel[i]) + "</button></li>"
    }
    h += "</ul>"
  }
  h += "</form>"
  h += "<button class='b' type='button' onclick='locateMe()'>Locate me</button>"
  h += "<div class='seg' role='group' aria-label='Temperature unit'><button type='button' class='" + onC + "' onclick='setUnit(0)'>°C</button><button type='button' class='" + onF + "' onclick='setUnit(1)'>°F</button></div>"
  h += "</header>"
  return h
}

fn nowHtml() {
  let h = "<div class='now'><div class='where'>" + esc(place) + "</div>"
  if ready == 0 {
    h += "<div class='when'>checking the sky...</div><div class='bigrow'><div class='temp'>--<sup>°</sup></div></div></div>"
    return h
  }
  h += "<div class='when'>" + esc(whenText) + "</div>"
  h += "<div class='bigrow'>" + icon(kindOf(wcode), isDay, 84) + "<div class='temp'>" + T(temp) + "<sup>°</sup></div></div>"
  h += "<div class='cond'>" + labelOf(wcode) + "</div>"
  h += "<div class='chips'><span class='chip'>Feels " + T(feels) + U() + "</span><span class='chip'>H " + T(dMax[0]) + "° · L " + T(dMin[0]) + "°</span><span class='chip'>Updated " + updated + "</span></div></div>"
  return h
}

fn castHtml() {
  let h = "<nav class='cast' aria-label='Choose your forecaster'>"
  for i from 0 to 3 {
    let pOn = ""
    let pr = "false"
    if shuf == 0 and who == i {
      pOn = " on"
      pr = "true"
    }
    h += "<button type='button' class='pick" + pOn + "' aria-pressed='" + pr + "' onclick='pickWho(" + i + ")'><span class='th'>" + avatarSvg(i, "smug", 1) + "</span><span class='tx'><b>" + cName(i) + "</b><small>" + cRole(i) + "</small></span></button>"
  }
  let sOn = ""
  let spr = "false"
  if shuf == 1 {
    sOn = " on"
    spr = "true"
  }
  h += "<button type='button' class='pick" + sOn + "' aria-pressed='" + spr + "' onclick='pickShuffle()'><span class='th sh'>?</span><span class='tx'><b>Shuffle</b><small>Surprise me</small></span></button>"
  h += "</nav>"
  return h
}

fn heroHtml() {
  let cls = "avatar"
  if shake == 1 {
    cls = "avatar shake"
  }
  let h = "<section class='hero' aria-label='Current weather'><div class='stage'>"
  h += "<button class='" + cls + "' type='button' onclick='pokeHer()' aria-label='Poke " + cName(who) + "'>" + avatarSvg(who, mood, 0) + "<span class='sfx'>" + sfxFor(mood) + "</span><span class='poke'>(tap to poke)</span></button>"
  h += "<div class='say'><div class='bub'><span class='tag'>" + upper(cName(who)) + "</span><p class='line'><span class='ghost'>" + esc(sayText) + "</span><span class='typed'></span></p></div>"
  h += "<div class='acts'><button class='b primary' type='button' onclick='hitAgain()'>Hit me again</button><button class='b' type='button' onclick='refreshData()'>Refresh data</button></div></div></div>"
  h += nowHtml()
  h += "</section>"
  return h
}

fn statsHtml() {
  let k = kindOf(wcode)
  let dere = comfort(temp, k, wind, hum, 0)
  let gcls = "card gauge-card"
  if fresh == 1 {
    gcls = "card gauge-card fresh"
  }
  let note = "Mostly hostile."
  if dere >= 75 {
    note = "Dangerously close to being nice."
  } else if dere >= 50 {
    note = "Tolerable. She's only being civil."
  } else if dere < 25 {
    note = "Peak hostility. Take cover."
  }
  let h = "<section class='stats' aria-label='Conditions'>"
  h += "<div class='" + gcls + "'>" + gaugeSvg(dere) + "<div class='gtxt'><span class='k'>Mood gauge</span><span class='big'>Tsun " + (100 - dere) + "% / Dere " + dere + "%</span><span class='c'>" + note + "</span></div></div>"

  let fcap = "Matches the thermometer. Rare for you to agree with facts."
  if abs(feels - temp) >= 3 {
    fcap = "Your body disagrees with the thermometer. Typical."
  }
  h += statCard("Feels like", T(feels) + U(), fcap)

  let hcap = "Normal. Don't make it weird."
  if hum < 35 {
    hcap = "Dry. Moisturize, you crumbling biscuit."
  } else if hum > 70 {
    hcap = "Sticky. Your hair has already given up."
  }
  h += statCard("Humidity", hum + "%", hcap)

  let wcap = "A decent breeze. Hold your papers."
  if wind < 8 {
    wcap = "Barely a breeze. Boring."
  } else if wind >= 25 {
    wcap = "Hold your hat. Or your dignity."
  }
  h += statCard("Wind", WK(wind) + " " + WUn(), wcap)

  let ucap = "Extreme. Go outside and you'll deserve it."
  if uvMax < 3 {
    ucap = "Low. Nothing to fear. For once."
  } else if uvMax < 6 {
    ucap = "Moderate. Sunscreen. I won't repeat myself."
  } else if uvMax < 8 {
    ucap = "High. Cover up. Don't argue."
  }
  h += statCard("UV today", "" + uvMax, ucap)

  let rcap = "Likely. I'm not saying I warned you, but I warned you."
  if popToday < 20 {
    rcap = "Dry. For now."
  } else if popToday < 50 {
    rcap = "Maybe. Pack the umbrella, coward."
  }
  h += statCard("Rain today", popToday + "%", rcap)

  let pcap = "Normal. Nothing to complain about. Try anyway."
  if pres < 1008 {
    pcap = "Low. Expect the weather to be rude."
  } else if pres > 1020 {
    pcap = "High and stable. Unlike you."
  }
  h += statCard("Pressure", pres + " hPa", pcap)

  let scap = "The sun's gone. You should be in bed."
  if isDay == 1 {
    scap = "Be home before it sets. I'm not waiting up."
  }
  h += statCardSm("Sunrise / sunset", sunriseT + " / " + sunsetT, scap)
  let dayMin = setMin - riseMin
  h += statCard("Daylight", (dayMin / 60) + "h " + (dayMin % 60) + "m", "That's how long you have to be useful. Don't waste it.")
  h += "</section>"
  return h
}

fn hoursHtml() {
  let n = min(24, length(hT))
  let cw = 66
  let w = n * cw
  let lo = hT[0]
  let hi = hT[0]
  for i from 0 to n - 1 {
    lo = min(lo, hT[i])
    hi = max(hi, hT[i])
  }
  if hi == lo {
    hi = lo + 1
  }
  let d = ""
  let px = 0
  let py = 0
  let cols = ""
  for i from 0 to n - 1 {
    let x = i * cw + cw / 2
    let y = map(hT[i], lo, hi, 150, 78)
    if i == 0 {
      d = "M" + x + "," + y
    } else {
      d += " C" + (px + cw / 2) + "," + py + " " + (x - cw / 2) + "," + y + " " + x + "," + y
    }
    px = x
    py = y
    cols += "<circle cx='" + x + "' cy='" + y + "' r='4.5' fill='#fff' stroke='var(--acc)' stroke-width='2.5'/>"
    cols += "<text class='ct' x='" + x + "' y='" + (y - 14) + "'>" + T(hT[i]) + "°</text>"
    cols += "<svg x='" + (x - 17) + "' y='8' width='34' height='34' viewBox='0 0 48 48'>" + iconInner(kindOf(hC[i]), hD[i]) + "</svg>"
    if i == 0 {
      cols += "<text class='cnow' x='" + x + "' y='214'>NOW</text>"
    } else {
      cols += "<text class='cl' x='" + x + "' y='214'>" + hL[i] + "</text>"
    }
    if hP[i] > 0 {
      cols += "<text class='cp' x='" + x + "' y='230'>" + hP[i] + "%</text>"
    }
  }
  let svg = "<svg class='chart' width='" + w + "' height='240' viewBox='0 0 " + w + " 240' role='img' aria-label='Hourly temperature for the next 24 hours'>"
  svg += "<defs><linearGradient id='ar' x1='0' y1='0' x2='0' y2='1'><stop offset='0' stop-color='var(--acc)' stop-opacity='.45'/><stop offset='1' stop-color='var(--acc)' stop-opacity='0'/></linearGradient></defs>"
  svg += "<path d='" + d + " L" + px + ",190 L" + (cw / 2) + ",190 Z' fill='url(#ar)'/>"
  svg += "<path class='ln' d='" + d + "'/>" + cols + "</svg>"
  return "<section class='card sec' aria-label='Next 24 hours'><h2 class='hd'>Next 24 hours <small>Don't blink. Or do, I can't stop you.</small></h2><div class='scroll'>" + svg + "</div></section>"
}

fn weekHtml() {
  let n = length(dMax)
  let lo = dMin[0]
  let hi = dMax[0]
  for i from 0 to n - 1 {
    lo = min(lo, dMin[i])
    hi = max(hi, dMax[i])
  }
  if hi == lo {
    hi = lo + 1
  }
  let rows = ""
  let bestI = 0
  let bestS = 0
  for i from 0 to n - 1 {
    let kd = kindOf(dC[i])
    let left = map(dMin[i], lo, hi, 0, 100)
    let right = map(dMax[i], lo, hi, 0, 100)
    let wid = max(8, right - left)
    if left + wid > 100 {
      wid = 100 - left
    }
    rows += "<div class='day'><div class='dd'><b>" + dN[i] + "</b><span>" + dDate[i] + "</span></div>" + icon(kd, 1, 32) + "<span class='dl'>" + labelOf(dC[i]) + "</span><span class='dp'>" + dP[i] + "%</span>"
    rows += "<div class='dr'><span class='lo'>" + T(dMin[i]) + "°</span><div class='rt'><div class='rf' style='left:" + left + "%;width:" + wid + "%'></div></div><span class='hi'>" + T(dMax[i]) + "°</span></div></div>"
    let s = comfort((2 * dMax[i] + dMin[i]) / 3, kd, 0, 50, dP[i])
    if s > bestS {
      bestS = s
      bestI = i
    }
  }
  let best = "Best day this week: " + dN[bestI] + ". Don't read into it. I only picked it so you'd stop asking."
  if bestI == 0 {
    best = "Best day this week? Today. Don't read into it. Go outside before it changes its mind."
  }
  return "<section class='card sec' aria-label='Seven day forecast'><h2 class='hd'>The week ahead <small>Try to survive it.</small></h2><div class='week'>" + rows + "</div><p class='best'>" + best + "</p></section>"
}

fn footHtml() {
  return "<footer class='foot'>Forecast data by <a href='https://open-meteo.com/' target='_blank' rel='noopener'>Open-Meteo</a>. I'm crediting them because the license says so, not because I'm grateful.</footer>"
}

// ------------------------------- the page -----------------------------
fn render() {
  clear
  html headerHtml()
  html castHtml()
  if demo == 1 {
    html "<div class='note'>I couldn't reach the weather servers, so these numbers are made up (demo data). It's not my fault. Check your connection.</div>"
  }
  html heroHtml()
  if ready == 1 {
    html statsHtml()
    html hoursHtml()
    html weekHtml()
  }
  html footHtml()
  sky = skyClass()
  # document.body.className = 'sky-' + sky + ' who-' + who;
  typeIt()
  shake = 0
  fresh = 0
}

// ---------------------- raw-JS edges (network, storage) ----------------
fn makeDemo() {
  # const now = new Date(), pad = (n) => String(n).padStart(2, '0');
  # const fmt = (d) => d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) + 'T' + pad(d.getHours()) + ':' + pad(d.getMinutes());
  # const day0 = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  # const codes = [1, 2, 3, 61, 2, 0, 80], pops = [5, 15, 30, 70, 20, 5, 60];
  # const hourly = { time: [], temperature_2m: [], weather_code: [], precipitation_probability: [], is_day: [] };
  # for (let i = 0; i < 168; i++) { const d = new Date(day0.getTime() + i * 3600e3), h = d.getHours(), k = Math.floor(i / 24) % 7; hourly.time.push(fmt(d).slice(0, 13) + ':00'); hourly.temperature_2m.push(19 + 7 * Math.sin((h - 9) / 24 * 2 * Math.PI)); hourly.weather_code.push(codes[k]); hourly.precipitation_probability.push(pops[k]); hourly.is_day.push(h >= 6 && h < 18 ? 1 : 0); }
  # const daily = { time: [], weather_code: codes.slice(), temperature_2m_max: [26, 25, 23, 21, 27, 28, 22], temperature_2m_min: [14, 14, 13, 13, 15, 15, 13], precipitation_probability_max: pops.slice(), sunrise: [], sunset: [], uv_index_max: [8, 7, 5, 3, 9, 10, 4] };
  # for (let i = 0; i < 7; i++) { const s = fmt(new Date(day0.getTime() + i * 864e5)).slice(0, 10); daily.time.push(s); daily.sunrise.push(s + 'T06:18'); daily.sunset.push(s + 'T18:24'); }
  # const hi = now.getHours();
  # return { current: { time: fmt(now), temperature_2m: hourly.temperature_2m[hi], apparent_temperature: hourly.temperature_2m[hi] + 1.5, relative_humidity_2m: 62, is_day: hourly.is_day[hi], weather_code: 2, wind_speed_10m: 14, pressure_msl: 1014 }, hourly: hourly, daily: daily };
}

fn savePrefs() {
  # try { localStorage.setItem('cold-shoulder', JSON.stringify({ u: unitF, w: who, s: shuf, lat: latT, lon: lonT, city: city, place: place })); } catch (e) {}
}

fn loadPrefs() {
  # try {
  #   const s = JSON.parse(localStorage.getItem('cold-shoulder') || '{}');
  #   if (s.u === 1) unitF = 1;
  #   if (typeof s.w === 'number' && s.w >= 0 && s.w <= 3) who = s.w; else who = Math.floor(Math.random() * 4);
  #   if (s.s === 1) shuf = 1;
  #   if (s.lat && s.lon) { latT = String(s.lat); lonT = String(s.lon); city = String(s.city || city); place = String(s.place || place); }
  # } catch (e) {}
}

fn loadWeather(quiet) {
  if quiet == 0 {
    loading = 1
    mood = "huff"
    sayText = sys("loading")
    render()
  }
  # let d = null, bad = false;
  # try {
  #   const u = 'https://api.open-meteo.com/v1/forecast?latitude=' + latT + '&longitude=' + lonT + '&current=temperature_2m,apparent_temperature,relative_humidity_2m,is_day,weather_code,wind_speed_10m,pressure_msl&hourly=temperature_2m,weather_code,precipitation_probability,is_day&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset,uv_index_max&timezone=auto&forecast_days=7';
  #   const ctl = new AbortController(), to = setTimeout(() => ctl.abort(), 9000);
  #   const r = await fetch(u, { signal: ctl.signal });
  #   clearTimeout(to);
  #   if (!r.ok) throw new Error('http ' + r.status);
  #   d = await r.json();
  # } catch (e) { bad = true; }
  # if (bad) { d = await makeDemo(); demo = 1; } else { demo = 0; }
  # const hm = (s) => parseInt(s.slice(11, 13), 10) * 60 + parseInt(s.slice(14, 16), 10);
  # const c = d.current, dl = d.daily, hr = d.hourly;
  # temp = Math.round(c.temperature_2m); feels = Math.round(c.apparent_temperature); hum = Math.round(c.relative_humidity_2m);
  # wind = Math.round(c.wind_speed_10m); pres = Math.round(c.pressure_msl); wcode = c.weather_code; isDay = c.is_day ? 1 : 0;
  # uvMax = Math.round(dl.uv_index_max[0]); popToday = dl.precipitation_probability_max[0] || 0;
  # nowMin = hm(c.time); riseMin = hm(dl.sunrise[0]); setMin = hm(dl.sunset[0]);
  # sunriseT = dl.sunrise[0].slice(11, 16); sunsetT = dl.sunset[0].slice(11, 16); updated = c.time.slice(11, 16);
  # const wd = new Date(c.time.slice(0, 10) + 'T12:00:00');
  # whenText = wd.toLocaleDateString('en-GB', { weekday: 'short', day: 'numeric', month: 'short' }) + ' · ' + c.time.slice(11, 16) + ' local';
  # let i0 = hr.time.findIndex((t) => t.slice(0, 13) >= c.time.slice(0, 13)); if (i0 < 0) i0 = 0;
  # const sl = (a) => a.slice(i0, i0 + 24);
  # hT = sl(hr.temperature_2m).map(Math.round); hC = sl(hr.weather_code); hP = sl(hr.precipitation_probability).map((v) => v || 0); hD = sl(hr.is_day);
  # hL = sl(hr.time).map((t) => t.slice(11, 13) + ':00');
  # dMax = dl.temperature_2m_max.map(Math.round); dMin = dl.temperature_2m_min.map(Math.round); dC = dl.weather_code.slice(); dP = dl.precipitation_probability_max.map((v) => v || 0);
  # dN = dl.time.map((t, i) => i === 0 ? 'Today' : new Date(t + 'T12:00:00').toLocaleDateString('en-GB', { weekday: 'short' }));
  # dDate = dl.time.map((t) => new Date(t + 'T12:00:00').toLocaleDateString('en-GB', { day: 'numeric', month: 'short' }));
  loading = 0
  ready = 1
  fresh = 1
  savePrefs()
  if quiet == 0 {
    speak()
  }
  render()
}

fn doSearch(q) {
  mood = "huff"
  showRes = 0
  if length(q) == 0 {
    sayText = sys("empty")
    render()
    return 0
  }
  sayText = sys("searching")
  render()
  # let list = [];
  # try {
  #   const r = await fetch('https://geocoding-api.open-meteo.com/v1/search?name=' + encodeURIComponent(q) + '&count=5&language=en&format=json');
  #   const j = await r.json(); list = j.results || [];
  # } catch (e) { list = null; }
  # if (list === null) { sayText = await sys('nosearch'); await render(); return 0; }
  # if (list.length === 0) { mood = 'angry'; sayText = '"' + q + '"? ' + await sys('notplace'); await render(); return 0; }
  # const lab = (p) => [p.name, p.admin1, p.country].filter(Boolean).join(', ');
  # if (list.length === 1) { latT = String(list[0].latitude); lonT = String(list[0].longitude); city = list[0].name; place = lab(list[0]); await loadWeather(0); return 0; }
  # resLabel = list.map(lab); resLat = list.map((p) => String(p.latitude)); resLon = list.map((p) => String(p.longitude)); showRes = 1;
  # sayText = await sys('several'); mood = 'smug';
  render()
}

fn pickResult(i) {
  # latT = resLat[i]; lonT = resLon[i]; place = resLabel[i]; city = resLabel[i].split(',')[0];
  showRes = 0
  loadWeather(0)
}

fn locateMe() {
  mood = "huff"
  sayText = sys("locating")
  render()
  # try {
  #   const p = await new Promise((res, rej) => navigator.geolocation.getCurrentPosition(res, rej, { timeout: 8000 }));
  #   latT = p.coords.latitude.toFixed(3); lonT = p.coords.longitude.toFixed(3); city = 'Your location'; place = 'Your location';
  #   await loadWeather(0);
  # } catch (e) { sayText = await sys('nolocate'); mood = 'huff'; await render(); }
}

// ------------------------------ interaction ---------------------------
fn setUnit(u) {
  unitF = u
  savePrefs()
  speak()
  render()
}

fn pickWho(i) {
  who = i
  shuf = 0
  lastN = 99
  savePrefs()
  speak()
  render()
}

fn pickShuffle() {
  shuf = 1
  lastN = 99
  savePrefs()
  speak()
  render()
}

fn hitAgain() {
  speak()
  render()
}

fn refreshData() {
  loadWeather(0)
}

fn pokeHer() {
  pokes += 1
  shake = 1
  if pokes <= 4 {
    mood = "angry"
    sayText = pokeLine(pokes)
  } else if pokes % 20 == 0 {
    // the deeper, unguarded moment - repeats, and hits harder each time
    // because it's still rare
    mood = "blush"
    sayText = pokeTrueDere()
  } else if pokes % 12 == 0 {
    // the lighter "fine, keep going" softening - also repeats now,
    // instead of being a single easter egg at poke 12
    mood = "blush"
    sayText = pokeSoft()
  } else {
    speak()
  }
  render()
}

// -------------------------------- start -------------------------------
# document.title = 'Cold Shoulder';
# const vpm = document.querySelector('meta[name=viewport]'); if (vpm && vpm.content.indexOf('viewport-fit') < 0) vpm.content += ', viewport-fit=cover';
# const fontLink = document.createElement('link'); fontLink.rel = 'stylesheet'; fontLink.href = 'https://fonts.googleapis.com/css2?family=Lilita+One&family=Nunito:wght@500;700;800&family=JetBrains+Mono:wght@500;700&display=swap'; document.head.appendChild(fontLink);
# const skyBg = document.createElement('div'); skyBg.id = 'skyBg'; document.body.insertBefore(skyBg, document.body.firstChild);
# window.searchSubmit = function (ev) { ev.preventDefault(); doSearch(ev.target.elements.q.value.trim()); return false; };

loadPrefs()
loadWeather(0)

every 600s {
  loadWeather(1)
}
