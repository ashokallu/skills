// Model-free integration fixture. This executable is never used by the wrapper.
import fs from 'node:fs';
import { startBroker } from './pi-broker.mjs';

const config = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const token = `public.${Buffer.from(JSON.stringify({
  'https://api.openai.com/auth': { chatgpt_account_id: 'public-fixture-account' }
})).toString('base64url')}.fixture`;
let calls = 0;
startBroker(config, { type: 'oauth', access: token, expires: Date.now() + 600000 }, async (_url, init) => {
  if (JSON.parse(init.body).reasoning?.effort !== config.provider_effort) {
    return new Response('{"detail":"fixture requires requested provider effort"}', { status: 400 });
  }
  calls++;
  const item = calls === 1 ? {
    type: 'function_call', id: 'fc_public', call_id: 'call_public',
    name: config.role === 'contributor' ? 'write' : 'read',
    arguments: JSON.stringify(config.role === 'contributor'
      ? { path: config.fixture_path || 'fixture.txt', content: 'after\n' }
      : { path: config.fixture_path || 'fixture.txt' })
  } : { type: 'message', id: 'msg_public', role: 'assistant', status: 'completed',
    content: [{ type: 'output_text', text: 'public-result', annotations: [] }] };
  const response = { id: 'resp_public', model: config.model, status: 'completed',
    usage: { input_tokens: 2, output_tokens: 1, total_tokens: 3 }, output: [item] };
  const events = [
    { type: 'response.created', response: { ...response, status: 'in_progress' } },
    { type: 'response.output_item.done', output_index: 0, item },
    // The live backend may omit output content in the terminal envelope.
    { type: 'response.completed', response: { ...response, output: [] } }
  ];
  return new Response(events.map(event => `data: ${JSON.stringify(event)}\n\n`).join(''),
    { headers: { 'content-type': 'text/event-stream' } });
});
