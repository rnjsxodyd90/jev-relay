import{readdir,readFile}from'node:fs/promises';import{spawnSync}from'node:child_process';import{join}from'node:path';import{createHash}from'node:crypto';
async function walk(dir){const out=[];for(const e of await readdir(dir,{withFileTypes:true})){const p=join(dir,e.name);if(e.isDirectory())out.push(...await walk(p));else out.push(p);}return out;}
const files=[...await walk('src'),...await walk('public'),...await walk('test'),...await walk('scripts')].filter(f=>/\.(?:m?js)$/.test(f));for(const file of files){const r=spawnSync(process.execPath,['--check',file],{stdio:'inherit'});if(r.status!==0)process.exit(1);}
const protocol=JSON.parse(await readFile('research/decision-speed/protocol.json','utf8'));const hash=createHash('sha256').update(await readFile('research/decision-speed/cases.json')).digest('hex');if(hash!==protocol.sha256)throw Error('Frozen decision cases hash does not match.');
const data=JSON.parse(await readFile('public/evidence.json','utf8'));if(data.results.length!==216||data.cases.length!==36)throw Error('Incomplete benchmark evidence.');
console.log(`Syntax valid: ${files.length} JavaScript files. Frozen case hash and evidence counts verified.`);
