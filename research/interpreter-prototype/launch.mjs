import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {dirname} from 'node:path';
const dir=dirname(fileURLToPath(import.meta.url));
const corePort=Number(process.env.PORT||4418),voicePort=Number(process.env.VOICE_PORT||4419);
async function alive(port){try{const r=await fetch(`http://127.0.0.1:${port}/api/status`,{signal:AbortSignal.timeout(1000)});return r.ok&&(typeof (await r.json()).jevConfigured==='boolean');}catch{return false;}}
const children=[];
if(!await alive(corePort)){children.push(spawn(process.execPath,['--env-file-if-exists=.env','server.mjs'],{cwd:dir,stdio:'inherit'}));await new Promise(resolve=>setTimeout(resolve,500));}
if(!await alive(voicePort))children.push(spawn(process.execPath,['--env-file-if-exists=.env','voice-server.mjs'],{cwd:dir,stdio:'inherit'}));
console.log(`Open http://127.0.0.1:${voicePort}`);
process.on('SIGINT',()=>{children.forEach(p=>p.kill());process.exit(0);});
process.on('SIGTERM',()=>{children.forEach(p=>p.kill());process.exit(0);});
