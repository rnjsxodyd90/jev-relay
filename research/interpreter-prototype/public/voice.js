let worker=null,ready=false,current=null,serial=0,loading=null,progressCallback=()=>{};
export function prepareVoice(progress){
 progressCallback=progress||(()=>{});if(loading)return loading;
 loading=new Promise((resolve,reject)=>{
  worker=new Worker('/speech-worker.js',{type:'module'});
  worker.onmessage=({data})=>{
   if(data.type==='progress')progressCallback(`Downloading local speech model: ${Math.round(data.progress||0)}%`);
   if(data.type==='ready'){ready=true;resolve();progressCallback('Local speech ready · audio stays on this device');}
   if(data.type==='result'&&current?.id===data.id){current.resolve(data);current=null;}
   if(data.type==='error'){if(!ready){loading=null;reject(Error(data.message));}if(current){current.reject(Error(data.message));current=null;}progressCallback('Local speech engine needs a retry');}
  };
  worker.onerror=()=>{const e=Error('The local speech worker could not start. Reload this page to retry.');reject(e);current?.reject(e);current=null;};
  worker.postMessage({type:'load'});
 });return loading;
}
export async function transcribeAudio(audio,language){
 await prepareVoice(progressCallback);if(current)throw Error('A turn is already being transcribed.');
 if(audio.length<4000)throw Error('Record at least a quarter-second of speech.');
 if(audio.length>16000*30)throw Error('Keep audio turns below 30 seconds.');
 let energy=0;for(const v of audio)energy+=v*v;
 if(Math.sqrt(energy/audio.length)<.0015)throw Error('No audible speech detected. Check your microphone and try again.');
 const names={en:'english',nl:'dutch',ko:'korean',es:'spanish',fr:'french',de:'german',ja:'japanese','zh-CN':'chinese',it:'italian',pt:'portuguese'};
 const id=++serial;return new Promise((resolve,reject)=>{current={id,resolve,reject};worker.postMessage({type:'transcribe',id,audio,language:names[language]},{transfer:[audio.buffer]});});
}
async function resample(samples,rate){if(rate===16000)return samples;const ctx=new OfflineAudioContext(1,Math.ceil(samples.length*16000/rate),16000);const buf=ctx.createBuffer(1,samples.length,rate);buf.copyToChannel(samples,0);const node=ctx.createBufferSource();node.buffer=buf;node.connect(ctx.destination);node.start();return new Float32Array((await ctx.startRendering()).getChannelData(0));}
export async function openMicrophone(onLevel,onLimit){
 let expired=false,permissionTimer;
 const request=navigator.mediaDevices.getUserMedia({audio:{echoCancellation:true,noiseSuppression:true,channelCount:1}}).then(stream=>{if(expired){stream.getTracks().forEach(t=>t.stop());throw Error('Microphone request expired. Press Start speaking to try again.');}return stream;});
 let stream;try{stream=await Promise.race([request,new Promise((_,reject)=>{permissionTimer=setTimeout(()=>{expired=true;reject(Error('Microphone permission is waiting. Allow microphone access in the browser address bar, then press Start speaking again.'));},20000);})]);}finally{clearTimeout(permissionTimer);}
 const context=new AudioContext();await context.resume();let node,source,timer,chunks=[],length=0;
 try{await context.audioWorklet.addModule('/recorder-worklet.js');source=context.createMediaStreamSource(stream);node=new AudioWorkletNode(context,'turn-recorder');const mute=context.createGain();mute.gain.value=0;source.connect(node);node.connect(mute).connect(context.destination);node.port.onmessage=({data})=>{chunks.push(data);length+=data.length;let peak=0;for(const v of data)peak=Math.max(peak,Math.abs(v));onLevel(peak,length/context.sampleRate);};timer=setTimeout(onLimit,29000);}
 catch(error){stream.getTracks().forEach(t=>t.stop());await context.close();throw error;}
 return {async stop(discard=false){clearTimeout(timer);node.port.onmessage=null;node.disconnect();source.disconnect();stream.getTracks().forEach(t=>t.stop());const rate=context.sampleRate;await context.close();if(discard){chunks=[];return null;}const audio=new Float32Array(length);let pos=0;for(const chunk of chunks){audio.set(chunk,pos);pos+=chunk.length;}chunks=[];return resample(audio,rate);}};
}
export async function decodeAudioFile(file){
 if(file.size>15*1024*1024)throw Error('Choose an audio file smaller than 15 MB.');
 const ctx=new AudioContext();try{const buffer=await ctx.decodeAudioData(await file.arrayBuffer());if(buffer.duration>30)throw Error('Choose an audio clip shorter than 30 seconds.');const mono=new Float32Array(buffer.length);for(let c=0;c<buffer.numberOfChannels;c++){const samples=buffer.getChannelData(c);for(let i=0;i<samples.length;i++)mono[i]+=samples[i]/buffer.numberOfChannels;}return resample(mono,buffer.sampleRate);}finally{await ctx.close();}
}
