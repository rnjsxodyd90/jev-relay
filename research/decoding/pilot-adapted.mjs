import {parallelCharacters,hierarchicalParallel,hierarchicalSequential,myMemory} from './decoder.mjs';
import{writeFile}from'node:fs/promises';
const results=[];
for(const [mode,fn] of [['parallel_characters',parallelCharacters],['hierarchical_parallel_words',hierarchicalParallel],['hierarchical_sequential_words',hierarchicalSequential],['mymemory_service',myMemory]]){try{const out=await fn('I am tired.');results.push(out);console.log(JSON.stringify({mode,text:out.text,latencyMs:out.latencyMs,calls:out.calls,inputTokens:out.inputTokens,ended:out.ended}));}catch(e){results.push({mode,error:e.message});console.log(JSON.stringify({mode,error:e.message}));}await writeFile('pilot-adapted-results.json',JSON.stringify(results,null,2)+'\n');}
