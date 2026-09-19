import http from 'node:http';
import {readFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {dirname,join,basename} from 'node:path';
import {createInterpreter} from './interpreter.mjs';
import {InputError,JEV_MODEL} from './decision-gate.mjs';
import {createModelAssets} from './model-assets.mjs';
const root=dirname(dirname(fileURLToPath(import.meta.url)));
const publicFiles={'/':'index.html','/index.html':'index.html','/style.css':'style.css','/app.js':'app.js','/voice.js':'voice.js','/speech-worker.js':'speech-worker.js','/recorder-worklet.js':'recorder-worklet.js','/evidence.json':'evidence.json','/api/evidence':'evidence.json'};
function contentType(name){return name.endsWith('.html')?'text/html; charset=utf-8':name.endsWith('.css')?'text/css; charset=utf-8':name.endsWith('.json')?'application/json; charset=utf-8':name.endsWith('.wasm')?'application/wasm':'text/javascript; charset=utf-8';}
async function readJson(req) {
  if(!req.headers['content-type']?.startsWith('application/json'))throw new InputError('Send JSON content.');
  if(Number(req.headers['content-length']??0)>16384){req.resume();throw new InputError('Request body exceeds 16 KB.');}
  const chunks=[];let size=0;for await(const chunk of req){size+=chunk.length;if(size>16384)throw new InputError('Request body exceeds 16 KB.');chunks.push(chunk);}
  try{return JSON.parse(Buffer.concat(chunks).toString('utf8'));}catch{throw new InputError('Request body is not valid JSON.');}
}
export function createRelayServer({port=4431,liveEnabled=false,jevKey='',qwenKey='',maxCalls=60,interpreter,publicDir=join(root,'public'),cacheDir=join(root,'.models')}={}) {
  if(!Number.isInteger(port)||port<0||port>65535)throw new Error('Invalid PORT.');
  const app=interpreter??createInterpreter({jevKey,qwenKey,maxCalls});
  const modelAsset=createModelAssets(cacheDir);let inFlight=0;
  const server=http.createServer(async(req,res)=>{
    res.setHeader('Cache-Control','no-store');res.setHeader('X-Content-Type-Options','nosniff');res.setHeader('X-Frame-Options','DENY');res.setHeader('Referrer-Policy','no-referrer');
    res.setHeader('Permissions-Policy','camera=(), geolocation=(), microphone=(self)');
    res.setHeader('Content-Security-Policy',"default-src 'self'; script-src 'self' 'wasm-unsafe-eval' blob:; worker-src 'self' blob:; style-src 'self' 'unsafe-inline'; font-src 'self'; connect-src 'self'; img-src 'self' data:; media-src 'self' blob:; frame-ancestors 'none'; base-uri 'self'; form-action 'self'");
    const json=(status,value)=>{res.writeHead(status,{'Content-Type':'application/json; charset=utf-8'});res.end(JSON.stringify(value));};
    const boundPort=server.address()?.port??port;const hosts=new Set([`127.0.0.1:${boundPort}`,`localhost:${boundPort}`]);const origins=new Set([...hosts].map(h=>'http://'+h));
    if(!hosts.has(req.headers.host)||req.headers.origin&&!origins.has(req.headers.origin)||req.method==='POST'&&!origins.has(req.headers.origin)){json(403,{code:'origin_rejected',error:'Use the local Relay application.'});return;}
    try {
      const pathname=new URL(req.url,`http://127.0.0.1:${boundPort}`).pathname;
      if(req.method==='GET'&&pathname==='/api/status'){json(200,{liveEnabled,jevConfigured:!!jevKey,qwenConfigured:!!qwenKey,model:JEV_MODEL,maxCalls,remainingCalls:app.remainingCalls});return;}
      if(req.method==='POST'&&pathname==='/api/interpret'){
        if(!liveEnabled||!jevKey){json(503,{code:'live_disabled',error:'Enable LIVE_MODE=1 and configure server-side keys to run live requests.'});return;}
        if(app.remainingCalls<=0){json(429,{code:'budget_exhausted',error:'The process model-request limit has been reached.'});return;}
        if(inFlight>=2){json(429,{code:'busy',error:'Two turns are already running. Wait for one to finish.'});return;}
        const input=await readJson(req);
        if(inFlight>=2){json(429,{code:'busy',error:'Two turns are already running. Wait for one to finish.'});return;}
        inFlight++;
        try{json(200,await app.interpret(input));}finally{inFlight--;}
        return;
      }
      if(req.method!=='GET'){json(405,{code:'method_not_allowed',error:'Method not allowed.'});return;}
      if(Object.hasOwn(publicFiles,pathname)){const file=publicFiles[pathname],bytes=await readFile(join(publicDir,file));res.writeHead(200,{'Content-Type':contentType(file)});res.end(bytes);return;}
      if(pathname==='/vendor/transformers.js'){const bytes=await readFile(join(root,'node_modules/@huggingface/transformers/dist/transformers.js'));res.writeHead(200,{'Content-Type':'text/javascript; charset=utf-8'});res.end(bytes);return;}
      if(/^\/vendor\/ort-wasm-simd-threaded(?:\.asyncify|\.jsep)?\.(?:mjs|wasm)$/.test(pathname)){const bytes=await readFile(join(root,'node_modules/onnxruntime-web/dist',basename(pathname)));res.writeHead(200,{'Content-Type':contentType(pathname)});res.end(bytes);return;}
      const prefix='/models/Xenova/whisper-base/';
      if(pathname.startsWith(prefix)){const name=pathname.slice(prefix.length),data=await modelAsset(name);if(data){res.writeHead(200,{'Content-Type':name.endsWith('.json')?'application/json':'application/octet-stream'});res.end(data);return;}}
      json(404,{code:'not_found',error:'Not found.'});
    } catch(error) {
      if(res.headersSent){res.end();return;}
      json(error instanceof InputError?400:502,{code:error instanceof InputError?'invalid_input':'service_unavailable',error:error instanceof InputError?error.message:'The local service could not complete this request. Check setup and try again.'});
    }
  });
  server.requestTimeout=35000;server.headersTimeout=10000;
  return server;
}
if(process.argv[1]&&fileURLToPath(import.meta.url)===process.argv[1]) {
  const port=Number(process.env.PORT??4431),maxCalls=Number(process.env.MAX_MODEL_CALLS??60);
  if(!Number.isInteger(port)||port<1024||port>65535)throw new Error('PORT must be between 1024 and 65535.');
  const liveEnabled=process.env.LIVE_MODE==='1';
  const server=createRelayServer({port,maxCalls,liveEnabled,jevKey:process.env.TYPESAFE_API_KEY??'',qwenKey:process.env.NEBIUS_API_KEY??''});
  server.listen(port,'127.0.0.1',()=>console.log(`Jev Relay: http://127.0.0.1:${port} (${liveEnabled?'live calls enabled':'recorded replay; live calls disabled'})`));
}
