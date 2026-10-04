// Tiny MCP client for Roblox Studio's built-in StudioMCP.exe (stdio JSON-RPC).
// Usage: node tools/studio.mjs list
//        node tools/studio.mjs call <tool> '<json args>'
//        node tools/studio.mjs call <tool> @file.json
import { spawn } from 'node:child_process';
import { readdirSync, readFileSync, existsSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';

const versions = join(process.env.LOCALAPPDATA, 'Roblox', 'Versions');
const exe = readdirSync(versions).map(v => join(versions, v, 'StudioMCP.exe')).find(existsSync);
if (!exe) { console.error('StudioMCP.exe not found'); process.exit(1); }

const [, , cmd = 'list', tool, rawArgs] = process.argv;
let args = {};
if (rawArgs) args = rawArgs.startsWith('@') ? JSON.parse(readFileSync(rawArgs.slice(1), 'utf8')) : JSON.parse(rawArgs);

const child = spawn(exe, ['--stdio'], { stdio: ['pipe', 'pipe', 'pipe'] });
let buf = '', id = 0;
const pending = new Map();
child.stdout.on('data', d => {
  buf += d.toString();
  let i;
  while ((i = buf.indexOf('\n')) >= 0) {
    const line = buf.slice(0, i).trim(); buf = buf.slice(i + 1);
    if (!line) continue;
    let msg; try { msg = JSON.parse(line); } catch { continue; }
    if (msg.id != null && pending.has(msg.id)) { pending.get(msg.id)(msg); pending.delete(msg.id); }
  }
});
child.stderr.on('data', d => { if (process.env.MCP_DEBUG) process.stderr.write(d); });
const send = (method, params) => new Promise(res => {
  const mid = ++id; pending.set(mid, res);
  child.stdin.write(JSON.stringify({ jsonrpc: '2.0', id: mid, method, params }) + '\n');
});
const notify = (method, params) => child.stdin.write(JSON.stringify({ jsonrpc: '2.0', method, params }) + '\n');

const timeout = setTimeout(() => { console.error('timeout'); child.kill(); process.exit(2); }, Number(process.env.MCP_TIMEOUT || 120000));
const init = await send('initialize', { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 'firstrobloxgame', version: '1' } });
notify('notifications/initialized', {});
let out;
if (cmd === 'list') {
  out = await send('tools/list', {});
  if (out.result) out = out.result.tools.map(t => ({ name: t.name, description: t.description, input: t.inputSchema }));
} else {
  // Wait for Studio to register with the proxy, then target it automatically.
  let studios = [];
  for (let i = 0; i < 40 && !studios.length; i++) {
    const r = await send('tools/call', { name: 'list_roblox_studios', arguments: {} });
    try { studios = JSON.parse(r.result.content[0].text).studios || []; } catch { studios = []; }
    if (!studios.length) await new Promise(r => setTimeout(r, 500));
  }
  if (tool === 'list_roblox_studios') { console.log(JSON.stringify(studios, null, 2)); child.kill(); process.exit(0); }
  if (!studios.length) { console.error('No Studio connected'); child.kill(); process.exit(3); }
  const pick = process.env.STUDIO_NAME ? studios.find(s => s.name.includes(process.env.STUDIO_NAME)) : studios[0];
  if (!args.studio_id) args.studio_id = (pick || studios[0]).id;
  out = await send('tools/call', { name: tool, arguments: args });
  if (out.result?.content) {
    const capDir = join(process.cwd(), 'scratch', 'captures'); let n = 0;
    out = out.result.content.map(c => {
      if (c.type === 'image' && c.data) {
        mkdirSync(capDir, { recursive: true });
        const ext = (c.mimeType || 'image/png').split('/')[1].replace('jpeg', 'jpg');
        const f = join(capDir, (process.env.CAP_NAME || ('cap_' + Date.now())) + (n++ ? '_' + n : '') + '.' + ext);
        writeFileSync(f, Buffer.from(c.data, 'base64'));
        return '[image saved] ' + f;
      }
      return c.text ?? JSON.stringify(c);
    }).join('\n') + (out.result.isError ? '\n[isError]' : '');
  }
}
clearTimeout(timeout);
console.log(typeof out === 'string' ? out : JSON.stringify(out, null, 2));
child.kill();
process.exit(0);
