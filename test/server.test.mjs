import test from 'node:test';
import assert from 'node:assert/strict';
import {once} from 'node:events';
import {get} from 'node:http';
import {createRelayServer} from '../src/server.mjs';
async function fixture(t,options={}) {
  const server=createRelayServer({port:0,...options});server.listen(0,'127.0.0.1');await once(server,'listening');
  t.after(()=>new Promise(resolve=>{server.closeAllConnections();server.close(resolve);}));
  return `http://127.0.0.1:${server.address().port}`;
}
test('recorded mode exposes only configuration booleans',async t=>{
  const base=await fixture(t,{jevKey:'not-a-real-key'});const r=await fetch(base+'/api/status');assert.equal(r.status,200);const body=await r.json();assert.equal(body.liveEnabled,false);assert.equal(body.jevConfigured,true);assert.equal(JSON.stringify(body).includes('not-a-real-key'),false);assert.match(r.headers.get('content-security-policy'),/frame-ancestors 'none'/);
});
test('live mode is disabled by default without any provider call',async t=>{
  let calls=0;const base=await fixture(t,{interpreter:{remainingCalls:60,interpret(){calls++;}}});const r=await fetch(base+'/api/interpret',{method:'POST',headers:{Origin:base,'Content-Type':'application/json'},body:JSON.stringify({text:'Hello'})});assert.equal(r.status,503);assert.equal(calls,0);
});
test('reject foreign or missing origins and forged hostnames',async t=>{
  const base=await fixture(t);for(const origin of [undefined,'https://attacker.invalid']){const r=await fetch(base+'/api/interpret',{method:'POST',headers:{...(origin?{Origin:origin}:{}),'Content-Type':'application/json'},body:'{}'});assert.equal(r.status,403);}const status=await new Promise((resolve,reject)=>{get(base+'/api/status',{headers:{Host:'attacker.invalid'}},r=>{r.resume();resolve(r.statusCode);}).on('error',reject);});assert.equal(status,403);
});
test('never serves secrets, source files, or arbitrary model files',async t=>{
  const base=await fixture(t);for(const path of ['/.env','/src/interpreter.mjs','/models/Xenova/whisper-base/evil.json','/node_modules/package.json']){assert.equal((await fetch(base+path)).status,404);}
});
test('bounded JSON and malformed content never reach the interpreter',async t=>{
  let calls=0;const base=await fixture(t,{liveEnabled:true,jevKey:'fake',interpreter:{remainingCalls:60,interpret(){calls++;}}});
  for(const [body,type]of [['{','application/json'],['x'.repeat(20000),'application/json'],['{}','text/plain']]){const r=await fetch(base+'/api/interpret',{method:'POST',headers:{Origin:base,'Content-Type':type},body});assert.equal(r.status,400);}assert.equal(calls,0);
});
test('live route forwards validated envelope without exposing internal errors',async t=>{
  const base=await fixture(t,{liveEnabled:true,jevKey:'fake',interpreter:{remainingCalls:60,async interpret(){throw Error('secret internal debug message');}}});const r=await fetch(base+'/api/interpret',{method:'POST',headers:{Origin:base,'Content-Type':'application/json'},body:'{"text":"Hello"}'});assert.equal(r.status,502);assert.equal((await r.text()).includes('secret internal'),false);
});
test('concurrency is capped after asynchronous body parsing',async t=>{
  const waiting=[];const base=await fixture(t,{liveEnabled:true,jevKey:'fake',interpreter:{remainingCalls:60,interpret(){return new Promise(resolve=>waiting.push(resolve));}}});
  const request=()=>fetch(base+'/api/interpret',{method:'POST',headers:{Origin:base,'Content-Type':'application/json'},body:'{"text":"Hello"}'});
  const a=request(),b=request();for(let i=0;i<100&&waiting.length<2;i++)await new Promise(r=>setTimeout(r,5));assert.equal(waiting.length,2);const c=await request();assert.equal(c.status,429);waiting.forEach(resolve=>resolve({route:'review'}));assert.equal((await a).status,200);assert.equal((await b).status,200);
});
test('an exhausted process budget blocks a new live request',async t=>{
  const base=await fixture(t,{liveEnabled:true,jevKey:'fake',interpreter:{remainingCalls:0,interpret(){assert.fail('must not call');}}});const r=await fetch(base+'/api/interpret',{method:'POST',headers:{Origin:base,'Content-Type':'application/json'},body:'{}'});assert.equal(r.status,429);
});
test('recorded evidence is complete and does not need credentials',async t=>{
  const base=await fixture(t);const r=await fetch(base+'/api/evidence');assert.equal(r.status,200);const data=await r.json();assert.equal(data.cases.length,36);assert.equal(data.results.length,216);
});
