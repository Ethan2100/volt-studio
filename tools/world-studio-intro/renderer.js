'use strict';

const fs = require('fs');
const path = require('path');

const canvas = document.getElementById('video');
const ctx = canvas.getContext('2d');
const status = document.getElementById('status');
const root = path.resolve(__dirname, '../..');
const storyboard = JSON.parse(fs.readFileSync(path.join(root, 'tools/world-studio-intro/storyboard.json'), 'utf8'));
const outPath = path.join(root, 'docs/world-studio-intro.webm');
const W = canvas.width, H = canvas.height;
console.log('World Studio video renderer page initialized');
const C = { bg:'#10151e', panel:'#191f2a', panel2:'#222a38', line:'#303a4d', text:'#e4eaf5', muted:'#9aa8bd', yellow:'#ffd23f', blue:'#6ea8ff', green:'#5fe0a0', purple:'#b892ff' };
const clamp = (v,a,b)=>Math.max(a,Math.min(b,v));
const ease = (v)=>{v=clamp(v,0,1);return v*v*(3-2*v)};
const roundRect=(x,y,w,h,r,fill,stroke)=>{ctx.beginPath();ctx.roundRect(x,y,w,h,r);ctx.fillStyle=fill;ctx.fill();if(stroke){ctx.strokeStyle=stroke;ctx.lineWidth=1;ctx.stroke();}};
const text=(s,x,y,size=18,color=C.text,font='Segoe UI',weight='400')=>{ctx.fillStyle=color;ctx.font=`${weight} ${size}px "${font}"`;ctx.fillText(s,x,y);};
const wrap=(value,maxWidth,font)=>{ctx.font=font;const lines=[];for(const para of value.split('\n')){let line='';for(const word of para.split(/\s+/)){const test=line?line+' '+word:word;if(ctx.measureText(test).width>maxWidth&&line){lines.push(line);line=word;}else line=test;}lines.push(line);}return lines;};

function drawGrid(x,y,w,h,fade=1){ctx.save();ctx.globalAlpha=fade;ctx.strokeStyle='#3a4659';ctx.lineWidth=1;for(let i=0;i<13;i++){const u=i/12;ctx.beginPath();ctx.moveTo(x+u*w,y+h*.15);ctx.lineTo(x+(u-.5)*w,y+h);ctx.stroke();}for(let i=0;i<9;i++){const u=i/8;const yy=y+h*.15+u*u*h*.85;ctx.beginPath();ctx.moveTo(x,y+yy-y);ctx.lineTo(x+w,yy);ctx.stroke();}ctx.strokeStyle='#ff5b65';ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(x+w*.28,y+h*.46);ctx.lineTo(x+w*.78,y+h*.83);ctx.stroke();ctx.strokeStyle='#5a9dff';ctx.beginPath();ctx.moveTo(x+w*.72,y+h*.42);ctx.lineTo(x+w*.35,y+h*.86);ctx.stroke();ctx.restore();}

function drawWorld(cx,cy,scale=1,selected=true){
  ctx.save();ctx.translate(cx,cy);ctx.scale(scale,scale);
  drawGrid(-205,17,410,170,.7);
  // simple perspective room, with shapes located to echo the editor's Three.js preview
  ctx.fillStyle='#303746';ctx.beginPath();ctx.moveTo(-198,10);ctx.lineTo(0,-18);ctx.lineTo(199,10);ctx.lineTo(0,48);ctx.closePath();ctx.fill();
  ctx.fillStyle='#222a37';ctx.beginPath();ctx.moveTo(-198,10);ctx.lineTo(0,48);ctx.lineTo(0,178);ctx.lineTo(-198,115);ctx.closePath();ctx.fill();
  ctx.fillStyle='#1b2330';ctx.beginPath();ctx.moveTo(198,10);ctx.lineTo(0,48);ctx.lineTo(0,178);ctx.lineTo(198,115);ctx.closePath();ctx.fill();
  drawGrid(-196,12,392,155,.55);
  // pillars / crates
  roundRect(-144,35,31,61,2,'#5e6777');
  roundRect(93,30,34,48,3,'#8a6a3a');
  ctx.fillStyle='#a58448';ctx.beginPath();ctx.moveTo(93,30);ctx.lineTo(103,22);ctx.lineTo(137,22);ctx.lineTo(127,30);ctx.closePath();ctx.fill();
  ctx.fillStyle='#6e522e';ctx.beginPath();ctx.moveTo(127,30);ctx.lineTo(137,22);ctx.lineTo(137,70);ctx.lineTo(127,78);ctx.closePath();ctx.fill();
  ctx.fillStyle=C.yellow;ctx.beginPath();ctx.arc(115,15,5,0,Math.PI*2);ctx.fill();
  if(selected){ctx.strokeStyle=C.blue;ctx.lineWidth=1.5;ctx.setLineDash([4,3]);ctx.strokeRect(88,19,50,64);ctx.setLineDash([]);}
  ctx.restore();
}

function drawInterface(progress, chapterIndex){
  const intro = chapterIndex===0;
  // desktop editor frame
  ctx.fillStyle='#0c1017';ctx.fillRect(0,0,W,H);
  ctx.fillStyle=C.panel;ctx.fillRect(0,0,W,53);text('⚡  Volt Studio',24,33,21,C.yellow,'Segoe UI','600');text('File    Edit    Sketch    Tools    View    Help',221,32,15,C.muted);
  roundRect(1010,11,105,32,7,'#263040',C.line);text('Compile',1033,33,15,C.text);roundRect(1124,11,130,32,7,'#45cf91');text('◉  Preview',1149,33,15,'#082117','Segoe UI','600');
  // left palette
  ctx.fillStyle=C.panel;ctx.fillRect(0,53,94,568);text('ADD',19,79,12,C.muted,'Segoe UI','700');
  ['▣ Part','▱ Wall','▰ Floor','▮ Pillar','● Ball','✦ Light','⚑ Spawn','◆ Model','☻ Char','✎ Script','✺ Effect'].forEach((s,i)=>{roundRect(8,91+i*43,78,37,6,C.panel2,C.line);text(s,15,115+i*43,14,i>8?C.purple:C.text);});
  // world tab and transform toolbar
  ctx.fillStyle=C.panel;ctx.fillRect(94,53,1186,45);text('VOLT / WORLD STUDIO',116,81,16,C.text,'Segoe UI','700');text('3D workspace · build, arrange and playtest your world',332,81,14,C.muted);
  ctx.fillStyle='#161d27';ctx.fillRect(94,98,1186,45);
  ['↶','↷','▢','×','Pick  Q','Move  W','Turn  E','Size  R','Grid','Axes','Frame','Focus'].forEach((v,i)=>{const x=108+i*87;roundRect(x,105,80,31,6,i>=8&&i<=9?'#293f5d':C.panel2,C.line);text(v,x+10,126,13,C.text);});
  // viewport
  roundRect(104,151,864,360,5,'#151b24',C.line);
  drawWorld(538,326,1.62,true);
  roundRect(122,165,254,31,6,'#101722','#354156');text('Right drag: orbit · Middle: pan · Wheel: zoom',132,186,13,C.muted);
  roundRect(122,462,218,34,6,'#101722','#354156');text('Frame     Focus     Grid  ✓     Axes  ✓',132,484,14,C.text);
  // scene tree
  roundRect(984,151,284,216,5,C.panel,C.line);text('THINGS',1004,177,13,C.muted,'Segoe UI','700');
  [['⌄  World',0],['   Floor',1],['   WallEast',1],['   Pillar',1],['▾  Crate',1],['      Effect',2],['      Script',2],['   Spawn',1]].forEach(([v,i],j)=>{const y=205+j*19;if(v.includes('Crate')||v.includes('Script'))roundRect(996,y-14,256,20,4,v.includes('Script')?'#263951':'#242d3b');text(v,1004+i*18,y,14,v.includes('Script')?C.blue:C.text);});
  roundRect(984,379,284,132,5,C.panel,C.line);text('PROPERTIES',1004,405,13,C.muted,'Segoe UI','700');
  [['Position','-200, 40, -250 cm'],['Size','80 × 80 × 80 cm'],['Color','#8a6a3a'],['Solid','On']].forEach(([k,v],j)=>{const y=431+j*19;text(k,1005,y,13,C.muted);text(v,1100,y,13,C.text,'Consolas');});
  // code editor band
  ctx.fillStyle='#11151d';ctx.fillRect(0,527,W,94);text('WORLD FILE   ·   generated Volt code',18,551,13,C.muted,'Segoe UI','700');
  text('let Crate = block3d(-200, 40, -250, 80, 80, 80, "#8a6a3a")',21,579,16,'#f1c75b','Consolas');
  text('solid(-200, -250, 40, 40, 0, 80)     playerStart(0, 400, 0)',21,604,16,'#8fc8ff','Consolas');
  // lower caption rail
  ctx.fillStyle='#181e29';ctx.fillRect(0,621,W,99);
  const ch=storyboard.chapters[chapterIndex];
  text(ch.tag,36,649,13,C.yellow,'Segoe UI','700');
  text(ch.title,36,684,26,C.text,'Segoe UI','600');
  ctx.fillStyle='#2b3444';ctx.fillRect(376,641,850,5);ctx.fillStyle=C.yellow;ctx.fillRect(376,641,850*progress,5);
  text('Illustrated UI · based on Volt Studio World Studio',846,696,14,C.muted);
  // build scene progress: highlight region for each chapter
  const focusBoxes=[{x:352,y:0,w:600,h:515},{x:104,y:96,w:862,h:416},{x:104,y:151,w:864,h:360},{x:984,y:151,w:284,h:360},{x:0,y:527,w:1280,h:94},{x:0,y:527,w:1280,h:94},{x:984,y:151,w:284,h:216},{x:1008,y:8,w:254,h:39}];
  const f=focusBoxes[chapterIndex];ctx.save();ctx.globalAlpha=.8;ctx.strokeStyle=C.yellow;ctx.lineWidth=2;ctx.strokeRect(f.x,f.y,f.w,f.h);ctx.restore();
  if(intro){ctx.fillStyle='rgba(7,10,15,.70)';ctx.fillRect(0,0,W,H);text('WORLD STUDIO',104,278,28,C.yellow,'Segoe UI','700');text('Your first 3D world',104,341,52,C.text,'Segoe UI','700');text('Build it visually. Understand the Volt code. Make it playable.',106,382,23,C.muted);roundRect(106,420,218,45,9,C.yellow);text('A beginner walkthrough',124,449,17,'#211a00','Segoe UI','600');}
}

function drawChapterCard(ch,elapsed,duration,index){
  const p=elapsed/duration;
  drawInterface(p,index);
  // right-side glass panel for chapter notes and code, scaled to fit over viewport
  const x=728,y=142,w=510;
  const codeLines=String(ch.code||'').split('\n');
  const codeHeight=ch.code?Math.min(184,Math.max(62,codeLines.length*18+18)):0;
  const captionLines=wrap(ch.caption||'',w-48,'15px "Segoe UI"');
  const captionHeight=captionLines.length*20+15;
  const h=Math.min(478,Math.max(338,127+ch.points.length*34+captionHeight+codeHeight));
  roundRect(x,y,w,h,12,'rgba(12,17,25,.94)','#46536b');
  text(ch.tag,x+22,y+32,14,C.yellow,'Segoe UI','700');
  text(ch.title,x+22,y+68,25,C.text,'Segoe UI','600');
  let yy=y+105;
  for(const pt of ch.points){text('•',x+24,yy,18,C.green,'Segoe UI','700');const lines=wrap(pt,w-65,'15px "Segoe UI"');for(const line of lines){text(line,x+45,yy,15,C.text);yy+=20;}yy+=8;}
  const captionY=yy+2;
  captionLines.forEach((line,i)=>text(line,x+24,captionY+i*20,15,C.muted));
  // accent pulse and chapter number progress
  const pulse=.5+.5*Math.sin(elapsed*2.2);ctx.globalAlpha=.3+.55*pulse;ctx.fillStyle=C.yellow;ctx.beginPath();ctx.arc(x+w-25,y+25,5,0,Math.PI*2);ctx.fill();ctx.globalAlpha=1;
  if(ch.code){const boxY=y+h-codeHeight-12;roundRect(x+20,boxY,w-40,codeHeight,7,'#0c1118','#334058');codeLines.slice(0,9).forEach((line,i)=>text(line,x+32,boxY+21+i*18,12.5,i===0?'#f0cf69':'#a8d5ff','Consolas'));}
  // actual scene motion subtly pans/zooms as the chapter plays
  if(index===2||index===3){ctx.save();ctx.globalAlpha=.65;ctx.strokeStyle=C.blue;ctx.lineWidth=2;const q=ease(p);ctx.beginPath();ctx.arc(540+q*16,320,24+Math.sin(elapsed*3)*2,0,Math.PI*2);ctx.stroke();ctx.restore();}
}

async function start(){
  if (window.renderStarted) return;
  window.renderStarted = true;
  try{
    console.log('Starting frame capture');
    const durations=storyboard.chapters.map(ch=>Math.max(14,ch.narration.trim().split(/\s+/).length/2.55));
    const starts=[];let total=0;for(const duration of durations){starts.push(total);total+=duration;}
    console.log('Video timeline seconds:',total);
    status.textContent=`Recording ${Math.round(total)} seconds of captioned World Studio walkthrough…`;
    drawChapterCard(storyboard.chapters[0],0,durations[0],0);
    fs.writeFileSync(path.join(root,'dist/world-studio-intro-preview.png'),Buffer.from(canvas.toDataURL('image/png').split(',')[1],'base64'));
    const stream=canvas.captureStream(30);
    const mime=['video/webm;codecs=vp9,opus','video/webm;codecs=vp8,opus','video/webm'].find(t=>MediaRecorder.isTypeSupported(t));
    if(!mime)throw new Error('This Electron build cannot record WebM video.');
    console.log('Selected video format:',mime);
    const recorder=new MediaRecorder(stream,{mimeType:mime,videoBitsPerSecond:1250000});
    const chunks=[];recorder.ondataavailable=e=>{if(e.data.size)chunks.push(e.data);};
    const done=new Promise((resolve,reject)=>{recorder.onerror=e=>reject(e.error||new Error('Video recorder failed'));recorder.onstop=resolve;});
    const t0=performance.now()+200;
    const draw=now=>{
      const elapsed=Math.max(0,(now-t0)/1000);let idx=starts.findIndex((s,i)=>elapsed>=s&&elapsed<s+durations[i]);if(idx<0)idx=durations.length-1;
      const local=clamp(elapsed-starts[idx],0,durations[idx]);drawChapterCard(storyboard.chapters[idx],local,durations[idx],idx);
      if(elapsed<total){requestAnimationFrame(draw);}else if(recorder.state==='recording'){recorder.stop();}
    };
    recorder.start(1000);console.log('MediaRecorder started');requestAnimationFrame(draw);await done;
    const blob=new Blob(chunks,{type:mime});const data=Buffer.from(await blob.arrayBuffer());fs.writeFileSync(outPath,data);
    status.textContent=`Saved ${outPath} (${(data.length/1024/1024).toFixed(1)} MB)`;
    console.log(JSON.stringify({path:outPath,bytes:data.length,duration:total,mime}));setTimeout(()=>require('electron').ipcRenderer.send('recording-done',{path:outPath,bytes:data.length,duration:total,mime}),1500);
  }catch(error){status.textContent=`Render failed: ${error.message}`;console.error(error.stack);require('electron').ipcRenderer.send('recording-failed',error.message);}
}

window.addEventListener('load',()=>setTimeout(start,350));
