import assert from 'node:assert/strict';
import {readFile, readdir} from 'node:fs/promises';
import {join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const root = resolve(fileURLToPath(new URL('../', import.meta.url)));
const read = relative => readFile(join(root, relative), 'utf8');
async function walk(directory) {
  const result = [];
  for (const entry of await readdir(directory, {withFileTypes: true})) {
    const location = join(directory, entry.name);
    if (entry.isDirectory()) result.push(...await walk(location));
    else if (entry.name.endsWith('.swift')) result.push(location);
  }
  return result;
}

for (const location of await walk(join(root, 'JevRelay'))) {
  const source = await readFile(location, 'utf8');
  assert(!/RelayAPIClient|\bAuthService\b|SUPABASE_URL|SUPABASE_PUBLISHABLE_KEY|RELAY_BACKEND_URL|TYPESAFE_API_KEY|NEBIUS_API_KEY|\.supabase\.co/.test(source), 'Native production source must not contain the legacy owner-funded route or environment keys.');
}
const config = await read('Config/Service.xcconfig');
const info = await read('JevRelay/Resources/Info.plist');
for (const source of [config, info]) {
  assert(!/SUPABASE_|RELAY_BACKEND_URL|TYPESAFE_API_KEY|NEBIUS_API_KEY/.test(source), 'Owner-relay configuration or provider keys must not be bundled.');
}
const service = await read('JevRelay/Core/ServiceConfiguration.swift');
assert(service.includes('https://api.typesafe.ai/v1/systemone'));
assert(service.includes('https://api.tokenfactory.nebius.com/v1/chat/completions'));
const keychain = await read('JevRelay/Core/KeychainStore.swift');
assert(keychain.includes('kSecAttrAccessibleWhenUnlockedThisDeviceOnly'));
assert(keychain.includes('kSecAttrSynchronizable as String: false'));
assert(!/UserDefaults|print\(|NSLog\(/.test(keychain), 'Provider keys must not be logged or kept in preferences.');
const model = await read('JevRelay/App/AppModel.swift');
assert(model.includes('transmissionConsent.byok.v2'), 'Legacy relay consent must not authorize direct BYOK transmission.');
assert(model.includes('DirectProviderClient'));
const client = await read('JevRelay/Core/APIClient.swift');
assert(!/print\(|NSLog\(/.test(client), 'Provider transport must not log credential-bearing requests.');
console.log('BYOK architecture checks passed: direct destinations, no legacy relay configuration, device-only Keychain, fresh consent, no transport logging.');
