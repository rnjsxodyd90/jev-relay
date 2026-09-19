import {parallelWords,parallelCharacters,sequentialWords,openAI} from './decoder.mjs';
import{writeFile}from'node:fs/promises';
const results=[];
for(const [mode,fn] of [['parallel_words',parallelWords],['parallel_characters',parallelCharacters],['sequential_words',sequentialWords],['gpt_4_1_mini',openAI]]){
 try{const out=await fn('I am tired.');results.push(out);console.log(JSON.stringify({mode,text:out.text,latencyMs:out.latencyMs,calls:out.calls,inputTokens:out.inputTokens,ended:out.ended}));}catch(e){results.push({mode,error:e.message});console.log(JSON.stringify({mode,error:e.message}));}
 await writeFile('pilot-results.json',JSON.stringify(results,null,2)+'\n');
}
