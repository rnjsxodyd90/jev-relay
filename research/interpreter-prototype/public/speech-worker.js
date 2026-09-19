import {pipeline,env} from '/vendor/transformers.js';
env.allowLocalModels=false;
env.useWasmCache=false;
env.remoteHost=location.origin;
env.remotePathTemplate='/models/{model}/';
env.backends.onnx.wasm.numThreads=1;
env.backends.onnx.wasm.wasmPaths={mjs:location.origin+'/vendor/ort-wasm-simd-threaded.asyncify.mjs',wasm:location.origin+'/vendor/ort-wasm-simd-threaded.asyncify.wasm'};
let pipePromise=null;
function load(){
 if(!pipePromise)pipePromise=pipeline('automatic-speech-recognition','Xenova/whisper-base',{dtype:'q8',device:'wasm',progress_callback:event=>{if(event.status==='progress')postMessage({type:'progress',file:event.file,progress:event.progress});}}).then(pipe=>{postMessage({type:'ready'});return pipe;}).catch(error=>{pipePromise=null;throw error;});
 return pipePromise;
}
self.onmessage=async({data})=>{
 try{
  const pipe=await load();if(data.type==='load')return;
  const started=performance.now();const output=await pipe(data.audio,{language:data.language,task:'transcribe',return_timestamps:false,max_new_tokens:160,do_sample:false});
  postMessage({type:'result',id:data.id,text:output.text?.trim()||'',ms:Math.round(performance.now()-started)});
 }catch(error){postMessage({type:'error',id:data.id,message:error.message||'Local speech recognition failed.'});}
};
