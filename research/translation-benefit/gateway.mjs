import http from 'node:http';
const jevKey=process.env.TYPESAFE_API_KEY;
const openaiKey=process.env.OPENAI_API_KEY||'';
if(!jevKey)throw Error('Set TYPESAFE_API_KEY in a private .env file or environment.');
let jevCalls=0,comparisonCalls=0,jevTokens=0,comparisonTokens=0;let active=0;
const server=http.createServer(async(req,res)=>{
 const reply=(status,body)=>{res.writeHead(status,{'Content-Type':'application/json','Cache-Control':'no-store'});res.end(JSON.stringify(body));};
 if(req.headers.host!=='127.0.0.1:4423'||req.headers.origin){reply(403,{error:'Only local benchmark clients are allowed.'});return;}
 if(req.method==='GET'&&req.url==='/status'){reply(200,{jevCalls,comparisonCalls,jevTokens,comparisonTokens,limits:{jevCalls:150,comparisonCalls:16,jevTokens:1500000}});return;}
 if(req.method!=='POST'||!['/jev','/compare'].includes(req.url)){reply(404,{error:'Not found'});return;}
 if(active>=4){reply(429,{error:'Too many active requests'});return;}
 const isJev=req.url==='/jev';
 if(isJev&&(jevCalls>=150||jevTokens>=1500000)||!isJev&&comparisonCalls>=16){reply(429,{error:'Experiment request budget exhausted'});return;}
 active++;
 try{
  const chunks=[];let size=0;for await(const chunk of req){size+=chunk.length;if(size>1024*1024)throw Error('Input too large');chunks.push(chunk);}
  const body=JSON.parse(Buffer.concat(chunks));isJev?jevCalls++:comparisonCalls++;
  const start=performance.now();
  const upstream=await fetch(isJev?'https://api.typesafe.ai/v1/systemone':'https://api.openai.com/v1/chat/completions',{method:'POST',headers:{Authorization:`Bearer ${isJev?jevKey:openaiKey}`,'Content-Type':'application/json'},body:JSON.stringify(body),signal:AbortSignal.timeout(45000)});
  const elapsedMs=Math.round(performance.now()-start);const data=await upstream.json();
  if(!upstream.ok){reply(502,{error:'Provider error',status:upstream.status,details:data.error?.message||data.detail||data.responseDetails||JSON.stringify(data)});return;}
  isJev?jevTokens+=data.usage?.input_tokens||0:comparisonTokens+=data.usage?.total_tokens||0;
  reply(200,{elapsedMs,data});
 }catch(error){reply(502,{error:error.name==='TimeoutError'?'Provider timeout':'Experiment request failed'});}finally{active--;}
});
server.listen(4423,'127.0.0.1',()=>console.log('Capped experiment gateway ready; credentials are in memory only.'));
setTimeout(()=>{server.close(()=>process.exit(0));setTimeout(()=>process.exit(0),1000);},45*60*1000).unref();
