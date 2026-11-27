import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import http from 'node:http';
import fs from 'node:fs/promises';
import { PassThrough } from 'node:stream';
import { createMuseProviderBroker } from '../muse-provider-broker.mjs';

const SECRET = 'synthetic-private-canary'; // pragma: allowlist secret (synthetic fixture)
const body = JSON.stringify({model:'muse-spark-1.3-contributor',stream:true,input:'public fixture',reasoning:{effort:'max'}});
async function fixture(fn) {
  const root = await mkdtemp(path.join(os.tmpdir(), 'muse-broker-'));
  const socketPath = path.join(root,'b.sock');
  let broker;
  try { await fn(socketPath, async options => broker = await createMuseProviderBroker({socketPath,credential:SECRET,...options})); }
  finally { await broker?.close(); await rm(root,{recursive:true,force:true}); }
}
function call(socketPath, url='/responses', data=body) {
  return new Promise((resolve,reject) => {
    const req = http.request({socketPath,path:url,method:'POST',headers:{authorization:'Bearer attacker',cookie:'private-cookie'}}, res => {
      let text='';res.on('data', c=>text+=c);res.on('end',()=>resolve({status:res.statusCode,text}));res.on('error',reject);
    });req.on('error',reject);req.end(data);
  });
}
test('fixed upstream auth, streaming bytes, and no forwarded client secrets', async()=>fixture(async(socket,start)=>{
  let observed;
  const broker=await start({request:(url,options,respond)=>{
    const req=new PassThrough();let sent='';req.on('data', c=>sent+=c);
    req.on('finish',()=>{
      observed={url:String(url),options,sent};
      const res=new PassThrough();res.statusCode=200;res.headers={'content-type':'text/event-stream','set-cookie':'forbidden'};
      respond(res);res.end('data: fixture\n\n');
    });return req;
  }});
  assert.deepEqual(await call(socket),{status:200,text:'data: fixture\n\n'});
  assert.equal(observed.url,'https://api.meta.ai/v1/responses');
  assert.equal(observed.options.headers.authorization,`Bearer ${SECRET}`);
  assert.equal(observed.options.headers.cookie,undefined);
  assert.equal(observed.sent,body);
  assert.equal(JSON.stringify(broker.snapshot()).includes(SECRET),false);
}));
test('unknown path and wrong model never reach upstream',async()=>fixture(async(socket,start)=>{
  let calls=0;await start({request:()=>{calls++;throw Error(SECRET)}});
  assert.equal((await call(socket,'http://attacker/')).status,403);
  const reply=await call(socket,'/responses',JSON.stringify({model:'other',stream:true}));
  assert.equal(reply.status,502);assert.equal(reply.text.includes(SECRET),false);assert.equal(calls,0);
}));
test('upstream failures are sanitized and request budget is finite',async()=>fixture(async(socket,start)=>{
  let calls=0;await start({maxRequests:1,request:()=>{calls++;throw Error(SECRET)}});
  const reply=await call(socket);assert.equal(reply.status,502);assert.equal(reply.text.includes(SECRET),false);
  assert.equal((await call(socket)).status,429);assert.equal(calls,1);
}));
test('revocation aborts an active upstream and prevents concurrent requests',async()=>fixture(async(socket,start)=>{
  let upstream; let startedResolve;
  const started=new Promise(resolve=>startedResolve=resolve);
  const broker=await start({request:(_url,_options,respond)=>{
    upstream=new PassThrough();upstream.on('data',()=>{});
    upstream.on('finish',()=>{
      const result=new PassThrough();result.statusCode=200;result.headers={'content-type':'text/event-stream'};
      respond(result);result.write('data: partial\n\n');startedResolve();
    });return upstream;
  }});
  const pending=call(socket).catch(error=>error.code);
  await started;
  assert.equal((await call(socket)).status,429);
  const closed=await broker.close();
  assert.equal(closed.closed,true);assert.equal(closed.socketRemoved,true);
  assert.equal(upstream.destroyed,true);
  await pending;
  await assert.rejects(call(socket));
}));
test('socket permission failure removes the listener before rejecting',async t=>fixture(async(socket,start)=>{
  t.mock.method(fs,'chmod',async()=>{throw Object.assign(Error('fixture chmod failure'),{code:'EACCES'});});
  await assert.rejects(start(),/fixture chmod failure/);
  await assert.rejects(call(socket));
  await assert.rejects(fs.lstat(socket),{code:'ENOENT'});
}));
test('slow downstream retains its active slot until the response finishes',async()=>fixture(async(socket,start)=>{
  const broker=await start({request:(_url,_options,respond)=>{
    const req=new PassThrough();req.on('data',()=>{});req.on('finish',()=>{
      const res=new PassThrough();res.statusCode=200;res.headers={'content-type':'text/event-stream'};
      respond(res);res.end(Buffer.alloc(8*1024*1024,97));
    });return req;
  }});
  const req=http.request({socketPath:socket,path:'/responses',method:'POST'});
  const received=new Promise(resolve=>req.once('response',resolve));
  req.end(body);const response=await received;response.pause();
  await new Promise(resolve=>setTimeout(resolve,30));
  assert.equal(broker.snapshot().active,true);
  assert.equal((await call(socket)).status,429);
  response.destroy();req.destroy();
}));
