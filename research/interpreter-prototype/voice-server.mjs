import http from 'node:http';
import {readFile,writeFile,mkdir,stat} from 'node:fs/promises';
import {dirname,join,basename} from 'node:path';
import {fileURLToPath} from 'node:url';
const dir=dirname(fileURLToPath(import.meta.url));
const port=Number(process.env.VOICE_PORT||4419),corePort=Number(process.env.PORT||4418);
const origin=`http://127.0.0.1:${port}`,core=`http://127.0.0.1:${corePort}`;
const hosts=new Set([`127.0.0.1:${port}`,`localhost:${port}`]);const origins=new Set([origin,`http://localhost:${port}`]);
const files={'/':'index.html','/index.html':'index.html','/app.js':'app.js','/style.css':'style.css','/voice.js':'voice.js','/speech-worker.js':'speech-worker.js','/recorder-worklet.js':'recorder-worklet.js'};
const cache=join(dir,'.models');await mkdir(cache,{recursive:true});
const downloads=new Map();
async function modelFile(name){
 const file=join(cache,name.replaceAll('/','_'));
 try{return await readFile(file);}catch{}
 if(!downloads.has(name))downloads.set(name,(async()=>{const r=await fetch(`https://huggingface.co/Xenova/whisper-base/resolve/main/${name}`);if(!r.ok){const e=new Error('Model file unavailable');e.status=r.status;throw e;}const b=Buffer.from(await r.arrayBuffer());await writeFile(file,b);return b;})().finally(()=>downloads.delete(name)));
 return downloads.get(name);
}
function mime(file){return file.endsWith('.html')?'text/html; charset=utf-8':file.endsWith('.css')?'text/css; charset=utf-8':file.endsWith('.wasm')?'application/wasm':file.endsWith('.json')?'application/json':'text/javascript; charset=utf-8';}
const server=http.createServer(async(req,res)=>{
 res.setHeader('Cache-Control','no-store');res.setHeader('X-Content-Type-Options','nosniff');res.setHeader('X-Frame-Options','DENY');res.setHeader('Referrer-Policy','no-referrer');
 res.setHeader('Content-Security-Policy',"default-src 'self'; script-src 'self' 'wasm-unsafe-eval' blob:; worker-src 'self' blob:; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; connect-src 'self'; img-src 'self' data:; media-src 'self' blob:; frame-ancestors 'none'; base-uri 'self'; form-action 'self'");
 const json=(status,data)=>{res.writeHead(status,{'Content-Type':'application/json'});res.end(JSON.stringify(data));};
 if(!hosts.has(req.headers.host)||req.headers.origin&&!origins.has(req.headers.origin)||req.method==='POST'&&!origins.has(req.headers.origin)){json(403,{error:'Only the local app may access this service.'});return;}
 try{
  const pathname=new URL(req.url,origin).pathname;
  if(['/api/status','/api/config','/api/interpret'].includes(pathname)){
   const chunks=[];let size=0;for await(const b of req){size+=b.length;if(size>16384){json(413,{error:'Request too large.'});return;}chunks.push(b);}
   const upstream=await fetch(core+pathname,{method:req.method,headers:{Origin:core,'Content-Type':'application/json'},body:req.method==='POST'?Buffer.concat(chunks):undefined,signal:AbortSignal.timeout(40000)});
   res.writeHead(upstream.status,{'Content-Type':'application/json'});res.end(Buffer.from(await upstream.arrayBuffer()));return;
  }
  if(req.method!=='GET'){json(404,{error:'Not found.'});return;}
  if(files[pathname]){res.setHeader('Content-Type',mime(files[pathname]));res.end(await readFile(join(dir,'public',files[pathname])));return;}
  if(pathname==='/vendor/transformers.js'){res.setHeader('Content-Type','text/javascript');res.end(await readFile(join(dir,'node_modules/@huggingface/transformers/dist/transformers.js')));return;}
  if(/^\/vendor\/ort-wasm-simd-threaded(?:\.asyncify|\.jsep)?\.(?:mjs|wasm)$/.test(pathname)){res.setHeader('Content-Type',mime(pathname));res.end(await readFile(join(dir,'node_modules/onnxruntime-web/dist',basename(pathname))));return;}
  if(pathname.startsWith('/models/Xenova/whisper-base/')){
   const name=pathname.slice('/models/Xenova/whisper-base/'.length);
   if(!/^(?:[a-z_]+\.json|(?:vocab|merges)\.txt|onnx\/(?:encoder_model|decoder_model_merged)_quantized\.onnx)$/.test(name)){json(404,{error:'Model resource not supported.'});return;}
   res.setHeader('Content-Type',name.endsWith('.json')?'application/json':'application/octet-stream');res.end(await modelFile(name));return;
  }
  json(404,{error:'Not found.'});
 }catch(error){json(error.status||502,{error:'The local service could not complete this request.'});}
});
server.listen(port,'127.0.0.1',()=>console.log(`Voice-ready interpreter: ${origin}; existing Jev connection preserved at ${core}`));
