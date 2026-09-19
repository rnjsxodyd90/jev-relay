import {readFile,writeFile,rename,unlink,mkdir} from 'node:fs/promises';
import {createHash,randomUUID} from 'node:crypto';
import {join} from 'node:path';
const manifest=JSON.parse(await readFile(new URL('./model-manifest.json',import.meta.url),'utf8'));
export function createModelAssets(cacheDir,{fetchImpl=fetch}={}) {
  const downloads=new Map();
  const valid=(bytes,expected)=>bytes.length===expected.bytes && createHash('sha256').update(bytes).digest('hex')===expected.sha256;
  return async function modelAsset(name) {
    if(!Object.hasOwn(manifest.files,name)) return null;
    if(downloads.has(name))return downloads.get(name);
    const work=(async()=>{
      const expected=manifest.files[name],file=join(cacheDir,name.replaceAll('/','_'));
      try {const bytes=await readFile(file);if(valid(bytes,expected))return bytes;} catch {}
      const response=await fetchImpl(`https://huggingface.co/${manifest.model}/resolve/${manifest.revision}/${name}`,{signal:AbortSignal.timeout(120000)});
      if(!response.ok)throw new Error('Model asset unavailable.');
      const reader=response.body.getReader(),chunks=[];let size=0;
      while(true){const {done,value}=await reader.read();if(done)break;size+=value.byteLength;if(size>expected.bytes){await reader.cancel();throw new Error('Model asset too large.');}chunks.push(value);}
      const bytes=Buffer.concat(chunks);
      if(!valid(bytes,expected))throw new Error('Model integrity verification failed.');
      await mkdir(cacheDir,{recursive:true});const temp=file+'.'+randomUUID()+'.part';
      try {await writeFile(temp,bytes,{mode:0o600});await rename(temp,file);}finally{await unlink(temp).catch(()=>{});}
      return bytes;
    })();
    downloads.set(name,work);try{return await work;}finally{downloads.delete(name);}
  };
}
