const log=[];
require('http').createServer((req,res)=>{let b='';req.on('data',c=>b+=c);req.on('end',()=>{
 if(req.url==='/log'){res.end(JSON.stringify(log));return;}
 const j=JSON.parse(b); log.push(j);
 res.writeHead(200,{'content-type':'application/json'});res.end(JSON.stringify({content:[{type:'text',text:'Reply #'+log.length+' to: '+j.messages[j.messages.length-1].content+'\nsecond line <b>x</b>'}]}));});}).listen(8792);
