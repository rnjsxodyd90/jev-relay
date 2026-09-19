if(location.port==='4418'){location.replace('http://127.0.0.1:4419/');await new Promise(()=>{});}
const {prepareVoice,openMicrophone,transcribeAudio,decodeAudioFile}=await import('/voice.js');
const $ = id => document.getElementById(id);
const languages = [ ['en','English','en-US'],['nl','Dutch','nl-NL'],['ko','Korean','ko-KR'],['es','Spanish','es-ES'],['fr','French','fr-FR'],['de','German','de-DE'],['ja','Japanese','ja-JP'],['zh-CN','Chinese','zh-CN'],['it','Italian','it-IT'],['pt','Portuguese','pt-PT'] ];
const nameOf = code => languages.find(l => l[0] === code)?.[1] || code;
const localeOf = code => languages.find(l => l[0] === code)?.[2] || code;
for (const id of ['sourceLang','targetLang']) for (const [code,name] of languages) $(id).add(new Option(name,code));
$('sourceLang').value='en'; $('targetLang').value='nl';
let busy=false, result=null, history=[], recognition=null, listening=false, requestController=null, requestId=0, speech=null, ignoreRecognition=false, previousSource='en', previousTarget='nl';
const Recognition=!!navigator.mediaDevices?.getUserMedia;
let micSession=null,voiceReady=false,transcribing=false,micStarting=false;
let voiceVersion=0;let pendingSpeechMs=0;
const emptyOutput = $('translationOutput').innerHTML;
const emptyHistory = $('history').innerHTML;
function message(text,error=false){ $('statusMessage').textContent=text; $('statusMessage').classList.toggle('error',error); }
function byteCount(){return new TextEncoder().encode($('sourceText').value.trim()).length;}
function updateControls(){
 const bytes=byteCount(); $('charCount').textContent=`${bytes} / 450 bytes`; $('charCount').style.color=bytes>450?'#b34c2d':'';
 $('translateButton').disabled=busy||listening||transcribing||micStarting||!$('sourceText').value.trim()||bytes>450;
 $('translateButton').innerHTML=busy?'Interpreting…':'Interpret <span>↗</span>';
 for(const id of ['sourceLang','targetLang','swapButton']) $(id).disabled=busy||listening||transcribing||micStarting;
 $('sourceText').readOnly=busy||listening||transcribing; $('micButton').disabled=busy||transcribing||micStarting||!voiceReady||!Recognition||!window.isSecureContext; $('audioUpload').disabled=busy||listening||transcribing||!voiceReady;
 $('clearButton').disabled=(!history.length&&!result&&!$('sourceText').value&&!busy&&!listening&&!transcribing);
 $('exportButton').disabled=!history.length;
}
function stopPlayback(){window.speechSynthesis?.cancel();speech=null;$('speakButton').innerHTML='<span aria-hidden="true">▷</span> Play voice';}
function clearResult(){stopPlayback();result=null;$('translationOutput').innerHTML=emptyOutput;$('translationOutput').classList.remove('loading');$('decision').hidden=true;$('copyButton').disabled=true;$('speakButton').disabled=true;$('latency').textContent='Ready when you are';}
function languageChanged(which){
 if($('sourceLang').value===$('targetLang').value){if(which==='source')$('targetLang').value=previousSource;else $('sourceLang').value=previousTarget;}
 previousSource=$('sourceLang').value;previousTarget=$('targetLang').value; clearResult();updateControls();
}
$('sourceLang').addEventListener('change',()=>languageChanged('source'));
$('targetLang').addEventListener('change',()=>languageChanged('target'));
$('swapButton').addEventListener('click',()=>{const old=$('sourceLang').value;$('sourceLang').value=$('targetLang').value;$('targetLang').value=old;previousSource=$('sourceLang').value;previousTarget=old;$('sourceText').value='';clearResult();updateControls();$('sourceText').focus();message(`Ready for the reply in ${nameOf($('sourceLang').value)}.`);});
$('sourceText').addEventListener('input',()=>{pendingSpeechMs=0;clearResult();updateControls();});
$('sourceText').addEventListener('keydown',event=>{if((event.ctrlKey||event.metaKey)&&event.key==='Enter'){event.preventDefault();if(!$('translateButton').disabled) interpret();}});
async function refreshStatus(){
 try{const response=await fetch('/api/status');if(!response.ok)throw Error();const status=await response.json();$('connectionDot').classList.toggle('connected',status.jevConfigured);$('engineState').textContent=status.jevConfigured?`${status.model} · Key configured, ready for a live call`:'Not connected · Connect your TypeSafe key';if(!history.length)message(status.jevConfigured?'Jev key configured. Every interpretation now uses your TypeSafe account.':'Connect Jev for candidate selection. Without it, translations are clearly marked unverified.');}
 catch{$('engineState').textContent='Local server not available';message('Start the app with npm start, then open http://127.0.0.1:4419.',true);}
}
async function interpret(){
 if(busy||listening||!$('sourceText').value.trim()||byteCount()>450)return;
 stopPlayback();const transcriptionMs=pendingSpeechMs;pendingSpeechMs=0;busy=true;const id=++requestId;requestController=new AbortController();updateControls();
 $('translationOutput').innerHTML=emptyOutput;$('translationOutput').classList.add('loading');$('translationOutput').querySelector('p').textContent='Finding the words…';$('translationOutput').querySelector('.empty-output > span').textContent='Translating, then checking with Jev.';$('decision').hidden=true;$('speakButton').disabled=true;$('copyButton').disabled=true;
 message('Preparing translation candidates and evaluating the turn…');
 const payload={text:$('sourceText').value.trim(),source:$('sourceLang').value,target:$('targetLang').value,context:history.slice(-2).map(t=>`${nameOf(t.source)}: ${t.sourceText}\n${nameOf(t.target)}: ${t.translatedText}`).join('\n').slice(-2000)};
 try{
  const response=await fetch('/api/interpret',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(payload),signal:requestController.signal});const data=await response.json();if(id!==requestId)return;
  if(!response.ok)throw Error(data.error||'Interpretation failed. Please try again.');
  if(!data.decision||typeof data.translatedText!=='string')throw Error('The server returned an incomplete interpretation.');
  result={...data,timing:{...data.timing,transcriptionMs,totalMs:(data.timing?.totalMs||0)+transcriptionMs},at:new Date().toISOString()};history.push(result); renderResult();renderHistory();
  message(result.decision.status==='approved'?'Jev selected this candidate. Check important details before relying on it.':result.decision.status==='review'?'Review needed. Automatic voice playback is paused.':'Baseline translation only. Jev has not evaluated this turn.');
  if($('autoSpeak').checked&&result.decision.status==='approved') playResult(true);
 }catch(error){if(id!==requestId||error.name==='AbortError')return;result=null;$('translationOutput').innerHTML=emptyOutput;message(error.message||'Connection failed. Please try again.',true);$('latency').textContent='Not translated';}
 finally{if(id===requestId){busy=false;requestController=null;$('translationOutput').classList.remove('loading');updateControls();}}
}
function renderResult(){
 $('translationOutput').textContent=result.translatedText||'Could you say that another way?';$('translationOutput').lang=localeOf(result.target);
 const {status,confidence,reason}=result.decision;
 const label=status==='approved'?'Jev selected':status==='review'?'Review needed':'Not evaluated by Jev';
 $('decision').hidden=false;$('decision').className=`decision ${status}`;$('decision').textContent=`${label}${Number.isFinite(confidence)?` · ${Math.round(confidence*100)}% decision confidence`:''}. ${reason}`;
 const t=result.timing||{};$('latency').textContent=`${Math.round(t.totalMs||0)} ms total${t.transcriptionMs?` · ${Math.round(t.transcriptionMs)} ms speech`:""}${Number.isFinite(t.jevMs)?` · ${Math.round(t.jevMs)} ms Jev`:''}`;
 $('copyButton').disabled=!result.translatedText;$('speakButton').disabled=!result.translatedText||!window.speechSynthesis;
}
function renderHistory(){
 $('turnCount').textContent=history.length;$('history').replaceChildren();
 for(const turn of [...history].reverse()){
  const row=document.createElement('article');row.className='turn';const meta=document.createElement('div');meta.className='turn-meta';const langs=document.createElement('span');langs.textContent=`${nameOf(turn.source)} → ${nameOf(turn.target)}`;const time=document.createElement('time');time.dateTime=turn.at;time.textContent=new Date(turn.at).toLocaleTimeString([],{hour:'2-digit',minute:'2-digit'});meta.append(langs,time);
  const texts=document.createElement('div');texts.className='turn-texts';for(const [text,lang] of [[turn.sourceText,turn.source],[turn.translatedText||'Clarification requested',turn.target]]){const p=document.createElement('p');p.textContent=text;p.dir='auto';p.lang=localeOf(lang);texts.append(p);}
  const status=document.createElement('div');status.className='turn-status';status.textContent=turn.decision.status==='approved'?'Selected by Jev':turn.decision.status==='review'?'Needs review · not auto-played':'Baseline · Jev not connected';row.append(meta,texts,status);$('history').append(row);
 }if(!history.length)$('history').innerHTML=emptyHistory;updateControls();
}
function playResult(automatic=false){
 if(!result?.translatedText||!window.speechSynthesis)return;
 if(speech){stopPlayback();return;}
 if(automatic&&result.decision.status!=='approved')return;
 const voices=window.speechSynthesis.getVoices();const locale=localeOf(result.target);const exact=voices.find(v=>v.lang.toLowerCase()===locale.toLowerCase());const voice=exact||voices.find(v=>v.lang.split('-')[0]===locale.split('-')[0]);
 if(!voice){message(`No ${nameOf(result.target)} voice is installed. Add a system voice to hear this translation.`,true);return;}
 window.speechSynthesis.cancel();speech=new SpeechSynthesisUtterance(result.translatedText);speech.lang=locale;speech.voice=voice;speech.rate=.94;
 speech.onend=()=>{speech=null;$('speakButton').innerHTML='<span aria-hidden="true">▷</span> Play voice';};speech.onerror=event=>{speech=null;$('speakButton').innerHTML='<span aria-hidden="true">▷</span> Play voice';if(event.error!=='canceled'&&event.error!=='interrupted')message('Voice playback was blocked. Press Play voice to try again.',true);};
 $('speakButton').innerHTML='<span aria-hidden="true">□</span> Stop voice';window.speechSynthesis.speak(speech);
}
$('speakButton').addEventListener('click',()=>playResult());
window.speechSynthesis?.getVoices();
$('copyButton').addEventListener('click',async()=>{if(!result?.translatedText)return;try{await navigator.clipboard.writeText(result.translatedText);message('Translation copied.');}catch{message('Clipboard is unavailable. Select the translation text to copy it.',true);}});
$('translateButton').addEventListener('click',interpret);
async function processAudio(audio,version){
 if(!audio||version!==voiceVersion)return;transcribing=true;updateControls();message('Transcribing locally. Your audio stays on this device…');
 try{const data=await transcribeAudio(audio,$('sourceLang').value);if(version!==voiceVersion)return;if(!data.text)throw Error('No speech was recognized. Try a clearer, shorter turn.');$('sourceText').value=data.text;pendingSpeechMs=data.ms;clearResult();message('Speech recognized locally in '+data.ms+' ms. Translating…');transcribing=false;updateControls();if(byteCount()>450)message('Speech recognized. Shorten this turn to 450 bytes before translating.',true);else await interpret();}
 catch(error){if(version===voiceVersion)message(error.message,true);}
 finally{if(version===voiceVersion){transcribing=false;updateControls();}}
}
async function finishRecording(discard=false){
 if(!micSession)return;const session=micSession;micSession=null;listening=false;transcribing=!discard;$('micButton').classList.remove('recording');$('micLabel').textContent='Start speaking';$('inputHint').textContent='Local microphone · press Finish turn when done';const version=voiceVersion;updateControls();try{const audio=await session.stop(discard);if(!discard)await processAudio(audio,version);}catch(error){transcribing=false;message(error.message,true);updateControls();}
}
$('micButton').addEventListener('click',async()=>{
 if(listening){await finishRecording();return;}if(busy||transcribing||!voiceReady)return;
 stopPlayback();clearResult();micStarting=true;const micVersion=++voiceVersion;updateControls();message('Allow microphone access in the browser prompt to start recording.');
 try{micSession=await openMicrophone((level,seconds)=>{$('inputHint').textContent=(level>.015?'Hearing audio':'Listening')+' · '+Math.floor(seconds)+'s / 29s';},()=>finishRecording());if(micVersion!==voiceVersion){await micSession.stop(true);micSession=null;return;}listening=true;$('micButton').classList.add('recording');$('micLabel').textContent='Finish turn';message('Recording locally. Speak, then press Finish turn.');}
 catch(error){message(error.name==='NotAllowedError'?'Microphone permission was denied. Allow it in the browser, or upload an audio clip.':error.name==='NotFoundError'?'No microphone found. Connect a microphone or upload audio.':'Could not open the microphone: '+error.message,true);}
 finally{micStarting=false;updateControls();}
});
$('audioUpload').addEventListener('change',async event=>{const file=event.target.files?.[0];event.target.value='';if(!file)return;stopPlayback();clearResult();const version=++voiceVersion;transcribing=true;updateControls();try{await processAudio(await decodeAudioFile(file),version);}catch(error){message(error.message,true);}finally{transcribing=false;updateControls();}});
prepareVoice(text=>{$('voiceState').textContent=text;}).then(()=>{voiceReady=true;$('voiceState').textContent='Local speech ready · audio stays on this device';updateControls();}).catch(error=>{$('voiceState').textContent='Local speech setup failed: '+error.message;message('Local voice could not load. Reload to retry; typed translation is still available.',true);});
$('clearButton').addEventListener('click',()=>{++voiceVersion;finishRecording(true);transcribing=false;micStarting=false;pendingSpeechMs=0;++requestId;requestController?.abort();requestController=null;busy=false;ignoreRecognition=true;recognition?.abort();listening=false;$('micButton').classList.remove('recording');$('micLabel').textContent=Recognition?'Start speaking':'Microphone unavailable';history=[];$('sourceText').value='';clearResult();renderHistory();message('Conversation cleared. Nothing was saved by this app.');});
$('exportButton').addEventListener('click',()=>{if(!history.length)return;const text=['Jev Interpreter / conversation',`Exported ${new Date().toLocaleString()}`,'Machine translation, not a certified interpretation.','',...history.map(t=>`${nameOf(t.source)}: ${t.sourceText}\n${nameOf(t.target)}: ${t.translatedText||'[Clarification requested]'}\nStatus: ${t.decision.status}; ${t.decision.reason}\n`)].join('\n');const url=URL.createObjectURL(new Blob([text],{type:'text/plain;charset=utf-8'}));const a=document.createElement('a');a.href=url;a.download=`jev-conversation-${new Date().toISOString().slice(0,10)}.txt`;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);message('Conversation exported to a text file.');});
$('settingsButton').addEventListener('click',()=>{$('configMessage').textContent='';$('settingsDialog').showModal();});
$('closeSettings').addEventListener('click',()=>{$('apiKey').value='';$('settingsDialog').close();});
$('settingsDialog').addEventListener('close',()=>{$('apiKey').value='';});
$('settingsForm').addEventListener('submit',async event=>{event.preventDefault();const key=$('apiKey').value.trim();if(!key)return;$('saveKey').disabled=true;$('configMessage').textContent='Connecting…';try{const response=await fetch('/api/config',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({apiKey:key})});const data=await response.json();if(!response.ok)throw Error(data.error||'Could not configure Jev.');$('apiKey').value='';await refreshStatus();$('settingsDialog').close();message('Key configured in server memory. Your next turn will make a live TypeSafe request; usage may incur charges.');}catch(error){$('configMessage').textContent=error.message;}finally{$('saveKey').disabled=false;}});
window.addEventListener('pagehide',()=>{++voiceVersion;micSession?.stop(true);ignoreRecognition=true;recognition?.abort();stopPlayback();requestController?.abort();});
updateControls();refreshStatus();
