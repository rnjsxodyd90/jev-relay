import {readFile, mkdir, writeFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';

const backendRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const sourceFiles = Object.freeze([
  'supabase/functions/_shared/decision-gate.mjs',
  'supabase/functions/_shared/memory.mjs',
  'supabase/functions/_shared/providers.mjs',
  'supabase/functions/_shared/handler.mjs',
  'supabase/functions/_shared/supabase.mjs',
  'supabase/functions/native-backend/index.ts',
]);
const outputFile = path.join(backendRoot, 'dist/native-backend-dashboard.ts');
const requiredRuntimeMarkers = Object.freeze([
  "'/health'",
  "'/interpret'",
  "'/delete-session'",
  "'idempotency-key'",
  'combineAbortSignals',
  'TRUSTED_AMBIGUITY_CATALOG',
  'Deno.serve(handler)',
]);

function flattenModule(source, relativePath) {
  let runtimeSource = source;
  if (relativePath.endsWith('.ts')) {
    runtimeSource = runtimeSource
      .replace('(name: string)', '(name)')
      .replace('let auth: {getUser(token: string): Promise<{id: string}>} =', 'let auth =')
      .replace('let quota: {reserve(input: unknown): Promise<void>} =', 'let quota =')
      .replace('let accounts: {deleteUser(userId: string): Promise<void>} =', 'let accounts =');
  }
  const withoutImports = runtimeSource.replace(/^import\s+[^'"\n]+from\s+['"][^'"]+['"];\s*$/gm, '');
  const withoutExports = withoutImports.replace(/^export\s+(?=(?:const|class|function)\b)/gm, '');
  if (/^\s*(?:import|export)\s/m.test(withoutExports) || /\b(?:const|let|var|function)\s+\w+\s*:\s*/.test(withoutExports)) throw new Error(`Unsupported module syntax in ${relativePath}.`);
  return `// BEGIN ${relativePath}\n${withoutExports.trim()}\n// END ${relativePath}`;
}

export async function buildDashboardBundle({write = true} = {}) {
  const sections = [];
  for (const relativePath of sourceFiles) {
    const source = await readFile(path.join(backendRoot, relativePath), 'utf8');
    sections.push(flattenModule(source, relativePath));
  }
  const output = [
    '// @ts-nocheck',
    '// Generated deterministically by backend/scripts/build-dashboard-bundle.mjs.',
    '// Paste this single file into the Supabase Edge Function Dashboard editor.',
    '// Do not edit this output directly; edit the source modules and rebuild.',
    '',
    ...sections,
    '',
  ].join('\n\n');
  for (const marker of requiredRuntimeMarkers) {
    if (!output.includes(marker)) throw new Error(`Dashboard bundle is missing required runtime marker: ${marker}`);
  }
  if (write) {
    await mkdir(path.dirname(outputFile), {recursive: true});
    await writeFile(outputFile, output, 'utf8');
  }
  return {output, outputFile, sourceFiles: [...sourceFiles], requiredRuntimeMarkers: [...requiredRuntimeMarkers]};
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const result = await buildDashboardBundle();
  console.log(path.relative(process.cwd(), result.outputFile));
}
