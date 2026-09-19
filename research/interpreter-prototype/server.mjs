import http from 'node:http';
import {readFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {dirname,join} from 'node:path';
import {interpret,InputError} from './pipeline.mjs';
const dir=dirname(fileURLToPath(import.meta.url));
const port=Number(process.env.PORT||4418);
if(!Number.isInteger(port)||port<1024||port>65535)throw Error('PORT must be between 1024 and 65535.');
let apiKey=process.env.TYPESAFE_API_KEY||process.env.TYPESAFE_AI_API_KEY||'';
const model=process.env.TYPESAFE_MODEL||'jev-latest';
const allowedOrigins=new Set([`http://127.0.0.1:${port}`,`http://localhost:${port}`]);
const allowedHosts=new Set([`127.0.0.1:${port}`,`localhost:${port}`]);
const files={'/':['index.html','text/html; charset=utf-8'],'/index.html':['index.html','text/html; charset=utf-8'],'/app.js':['app.js','text/javascript; charset=utf-8'],'/style.css':['style.css','text/css; charset=utf-8']};
let inFlight=0;
function send(res,status,data){res.writeHead(status,{'Content-Type':'application/json; charset=utf-8'});res.end(JSON.stringify(data));}
async function body(req){
 if(!req.headers['content-type']?.startsWith('application/json'))throw new InputError('Send JSON content.');
 let length=0;const chunks=[];for await (const chunk of req){length+=chunk.length;if(length>16384)throw new InputError('Request body is too large.');chunks.push(chunk);}
 try{return JSON.parse(Buffer.concat(chunks).toString('utf8'));}catch{throw new InputError('Request body must be valid JSON.');}
}
const server=http.createServer(async(req,res)=>{
 res.setHeader('Cache-Control','no-store');res.setHeader('X-Content-Type-Options','nosniff');res.setHeader('X-Frame-Options','DENY');res.setHeader('Referrer-Policy','no-referrer');
 res.setHeader('Content-Security-Policy',"default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; connect-src 'self'; img-src 'self' data:; frame-ancestors 'none'; base-uri 'self'; form-action 'self'");
 if(!allowedHosts.has(req.headers.host)){send(res,403,{error:'Invalid host.'});return;}
 if(req.headers.origin&&!allowedOrigins.has(req.headers.origin)){send(res,403,{error:'Cross-origin requests are not allowed.'});return;}
 if(req.method==='POST'&&!allowedOrigins.has(req.headers.origin)){send(res,403,{error:'This action must be made from the local app.'});return;}
 const pathname=new URL(req.url,`http://127.0.0.1:${port}`).pathname;
 try{
  if(req.method==='GET'&&pathname==='/api/status'){send(res,200,{jevConfigured:!!apiKey,model});return;}
  if(req.method==='POST'&&pathname==='/api/config'){
   const input=await body(req);if(typeof input.apiKey!=='string'||input.apiKey.trim().length<8||input.apiKey.length>4096||/[\r\n]/.test(input.apiKey))throw new InputError('Enter a valid TypeSafe API key.');
   apiKey=input.apiKey.trim();send(res,200,{jevConfigured:true,model});return;
  }
  if(req.method==='POST'&&pathname==='/api/interpret'){
   const input=await body(req);if(inFlight>=4){send(res,429,{error:'Too many active turns. Please wait.'});return;}
   inFlight++;try{send(res,200,await interpret(input,{apiKey,model}));}finally{inFlight--;}return;
  }
  if(req.method==='GET'&&files[pathname]){const [filename,type]=files[pathname];const data=await readFile(join(dir,'public',filename));res.writeHead(200,{'Content-Type':type});res.end(data);return;}
  send(res,404,{error:'Not found.'});
 }catch(error){send(res,error instanceof InputError?400:502,{error:error instanceof InputError?error.message:pathname==='/api/interpret'?error.message:'The request could not be completed.'});}
});
server.requestTimeout=45000;server.headersTimeout=10000;
server.listen(port,'127.0.0.1',()=>{console.log(`Jev Interpreter is running at http://127.0.0.1:${port}`);console.log(`Jev: ${apiKey?'key configured':'not connected; use Connection in the app'}`);});
