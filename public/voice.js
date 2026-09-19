let worker=null,ready=false,loading=null,pending=null,serial=0,loadTimer=null;
let progressCallback=()=>{},loadResolve=null,loadReject=null;
function resetWorker(message) {
  const error=new Error(message);clearTimeout(loadTimer);worker?.terminate();worker=null;ready=false;loading=null;
  loadReject?.(error);loadResolve=null;loadReject=null;
  if(pending){clearTimeout(pending.timer);pending.reject(error);pending=null;}
}
export function prepareVoice(progress) {
  if(typeof progress==='function')progressCallback=progress;
  if(ready)return Promise.resolve();if(loading)return loading;
  loading=new Promise((resolve,reject)=>{loadResolve=resolve;loadReject=reject;});
  const pendingLoad=loading;
  try {
    worker=new Worker('/speech-worker.js',{type:'module'});
    worker.onmessage=({data})=>{
      if(data.type==='progress')progressCallback(`Preparing local speech: ${Math.round(data.progress||0)}% of the current model file`);
      if(data.type==='ready'){clearTimeout(loadTimer);ready=true;loadResolve?.();loadResolve=null;loadReject=null;progressCallback('Local speech is ready. Audio stays on this device.');}
      if(data.type==='result'&&pending?.id===data.id){clearTimeout(pending.timer);pending.resolve(data);pending=null;}
      if(data.type==='error'){resetWorker('Local speech could not complete this turn. Prepare the speech engine again and retry.');progressCallback('Local speech needs a retry.');}
    };
    worker.onerror=()=>resetWorker('The local speech worker failed. Prepare the speech engine again.');
    loadTimer=setTimeout(()=>resetWorker('Speech preparation timed out. Check your connection, then retry.'),180000);
    worker.postMessage({type:'load'});
  } catch {resetWorker('The browser could not start the local speech worker.');}
  return pendingLoad;
}
export async function transcribeAudio(audio,language='en') {
  await prepareVoice();
  if(pending)throw new Error('A turn is already being transcribed.');
  if(!(audio instanceof Float32Array)||audio.length<4000)throw new Error('Record at least a quarter-second of speech.');
  if(audio.length>16000*30)throw new Error('Keep audio turns below 30 seconds.');
  let energy=0;for(const sample of audio){if(!Number.isFinite(sample))throw new Error('Audio samples are invalid.');energy+=sample*sample;}
  if(Math.sqrt(energy/audio.length)<.0015)throw new Error('No audible speech detected. Check your microphone and retry.');
  const id=++serial;
  return new Promise((resolve,reject)=>{
    const timer=setTimeout(()=>resetWorker('Local transcription timed out. Try a shorter turn.'),90000);
    pending={id,resolve,reject,timer};try{worker.postMessage({type:'transcribe',id,audio,language:language==='nl'?'dutch':'english'},[audio.buffer]);}catch{resetWorker('Audio could not be sent to the local speech worker. Prepare it again.');}
  });
}
async function resample(samples,rate) {
  if(rate===16000)return samples;
  const context=new OfflineAudioContext(1,Math.ceil(samples.length*16000/rate),16000),buffer=context.createBuffer(1,samples.length,rate);
  buffer.copyToChannel(samples,0);const node=context.createBufferSource();node.buffer=buffer;node.connect(context.destination);node.start();
  return new Float32Array((await context.startRendering()).getChannelData(0));
}
export async function openMicrophone(onLevel=()=>{},onLimit=()=>{}) {
  let expired=false,permissionTimer;
  const request=navigator.mediaDevices.getUserMedia({audio:{echoCancellation:true,noiseSuppression:true,channelCount:1}}).then(stream=>{if(expired){stream.getTracks().forEach(t=>t.stop());throw new Error('Microphone permission arrived after the request expired. Try again.');}return stream;});
  let stream;try{stream=await Promise.race([request,new Promise((_,reject)=>{permissionTimer=setTimeout(()=>{expired=true;reject(new Error('Allow microphone access in the browser, then try again.'));},20000);})]);}finally{clearTimeout(permissionTimer);}
  let context,node,source,timer,chunks=[],length=0,stopped=false;
  try {
    context=new AudioContext();await context.resume();await context.audioWorklet.addModule('/recorder-worklet.js');
    source=context.createMediaStreamSource(stream);node=new AudioWorkletNode(context,'turn-recorder');const mute=context.createGain();mute.gain.value=0;source.connect(node);node.connect(mute).connect(context.destination);
    node.port.onmessage=({data})=>{chunks.push(data);length+=data.length;let peak=0;for(const sample of data)peak=Math.max(peak,Math.abs(sample));onLevel(peak,length/context.sampleRate);};
    timer=setTimeout(onLimit,29000);
  } catch(error){stream.getTracks().forEach(t=>t.stop());if(context)await context.close().catch(()=>{});throw error;}
  return {async stop(discard=false){
    if(stopped)return null;stopped=true;clearTimeout(timer);node.port.onmessage=null;node.disconnect();source.disconnect();stream.getTracks().forEach(t=>t.stop());const rate=context.sampleRate;await context.close();
    if(discard){chunks=[];return null;}const audio=new Float32Array(length);let position=0;for(const chunk of chunks){audio.set(chunk,position);position+=chunk.length;}chunks=[];return resample(audio,rate);
  }};
}
export async function decodeAudioFile(file) {
  if(file.size>15*1024*1024)throw new Error('Choose an audio file below 15 MB.');
  const context=new AudioContext();
  try{let buffer;try{buffer=await context.decodeAudioData(await file.arrayBuffer());}catch{throw new Error('This audio file could not be decoded. Try a complete WAV, MP3 or M4A file.');}if(buffer.duration>30)throw new Error('Choose an audio clip shorter than 30 seconds.');const mono=new Float32Array(buffer.length);for(let channel=0;channel<buffer.numberOfChannels;channel++){const samples=buffer.getChannelData(channel);for(let i=0;i<samples.length;i++)mono[i]+=samples[i]/buffer.numberOfChannels;}return resample(mono,buffer.sampleRate);}
  finally{await context.close();}
}
