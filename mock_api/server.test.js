import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,rm,writeFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createApi,config} from './server.js';
async function fixture(t){
 const dir=await mkdtemp(join(tmpdir(),'hrms-api-'));
 const options={file:join(dir,'state.json'),latitude:0,longitude:0,delay:30};
 let time=new Date('2026-11-20T12:00:00Z');
 let app=await createApi(options,()=>time);
 let server=await new Promise(resolve=>{const active=app.listen(0,'127.0.0.1',()=>resolve(active));});
 const close=()=>new Promise(resolve=>server.close(resolve));
 t.after(async()=>{await close();await rm(dir,{recursive:true,force:true});});
 async function request(path,body,scenario='success'){
  const response=await fetch('http://127.0.0.1:'+server.address().port+path,{method:body===undefined?'GET':'POST',headers:{'Content-Type':'application/json','X-Mock-Scenario':scenario},...(body===undefined?{}:{body:JSON.stringify(body)})});
  return {status:response.status,body:await response.json()};
 }
 return {request,options,restart:async()=>{await close();app=await createApi(options,()=>time);server=await new Promise(resolve=>{const active=app.listen(0,'127.0.0.1',()=>resolve(active));});},setTime:value=>time=new Date(value),port:()=>server.address().port};
}
const attendance=(extra={})=>({id:'event-1',employeeId:'EMP001',companyDate:'2026-11-20',type:'checkIn',timestamp:'2026-11-20T09:00:00Z',latitude:0,longitude:0,...extra});
const leave=(extra={})=>({id:'leave-1',employeeId:'EMP001',type:'casual',startDate:'2026-11-21',endDate:'2026-11-22',reason:'Family appointment',...extra});
test('endpoint contracts and repeatable failures',async t=>{
 const api=await fixture(t);
 assert.equal((await api.request('/health')).body.status,'ok');
 assert.equal((await api.request('/employee/me')).body.id,'EMP001');
 assert.deepEqual((await api.request('/leave/balance')).body,{casual:7,sick:4});
 assert.equal((await api.request('/leave/requests')).body.requests.length,3);
 assert.deepEqual((await api.request('/attendance?month=2026-11')).body.events,[]);
 assert.equal((await api.request('/attendance?month=bad')).status,400);
 assert.equal((await api.request('/health?employeeId=bad')).status,422);
 assert.equal((await api.request('/health',undefined,'server-error')).status,500);
 assert.equal((await api.request('/attendance/events',attendance(),'attendance-conflict')).status,409);
 assert.equal((await api.request('/leave/requests',leave(),'leave-rejection')).status,422);
 assert.equal((await api.request('/attendance?month=2026-11')).body.events.length,0);
 const malformed=await fetch('http://127.0.0.1:'+api.port()+'/leave/requests',{method:'POST',headers:{'Content-Type':'application/json'},body:'{'});
 assert.equal(malformed.status,400);
 const started=Date.now();
 await api.request('/health',undefined,'slow');
 assert.ok(Date.now()-started>=25);
});
test('attendance validates order, radius, day, identity and safe retry',async t=>{
 const api=await fixture(t);
 const post=x=>api.request('/attendance/events',attendance(x));
 assert.equal((await post({id:'out',type:'checkOut'})).status,422);
 assert.equal((await post({latitude:0.002})).status,422);
 assert.equal((await post({employeeId:'OTHER'})).status,422);
 assert.equal((await post({timestamp:'2026-11-20T13:00:00Z'})).status,422);
 assert.equal((await post({companyDate:'2026-10-21',timestamp:'2026-10-21T09:00:00Z'})).status,422);
 assert.equal((await post({id:'old-event',companyDate:'2026-10-22',timestamp:'2026-10-22T09:00:00Z'})).status,201);
 const concurrent=await Promise.all([post(),post()]);
 assert.deepEqual(concurrent.map(x=>x.status).sort(),[200,201]);
 assert.equal((await post({latitude:0.001})).status,409);
 assert.equal((await post({id:'duplicate'})).status,409);
 assert.equal((await post({id:'out',type:'checkOut',timestamp:'2026-11-20T08:00:00Z'})).status,422);
 assert.equal((await post({id:'out',type:'checkOut',timestamp:'2026-11-20T10:00:00Z'})).status,201);
 await api.restart();
 api.setTime('2027-01-01T12:00:00Z');
 assert.equal((await post()).status,200);
 assert.equal((await api.request('/attendance?month=2026-11')).body.events.length,2);
});
test('timeout after commit and leave rules survive restart',async t=>{
 const api=await fixture(t);
 const delayed=api.request('/attendance/events',attendance(),'timeout-after-commit');
 await new Promise(resolve=>setTimeout(resolve,10));
 assert.equal((await api.request('/attendance/events',attendance())).status,200);
 assert.equal((await delayed).status,201);
 const post=x=>api.request('/leave/requests',leave(x));
 assert.equal((await post({startDate:'2026-11-19'})).status,422);
 assert.equal((await post({endDate:'2026-11-20'})).status,422);
 assert.equal((await post({reason:'12345 6789'})).status,422);
 assert.equal((await post({startDate:'2026-12-01',endDate:'2026-12-08'})).status,422);
 assert.equal((await post({startDate:'2026-11-27',endDate:'2026-11-27'})).status,422);
 assert.equal((await post()).status,201);
 assert.equal((await post()).status,200);
 assert.equal((await post({reason:'Changed reason'})).status,409);
 assert.equal((await post({id:'overlap',type:'sick',startDate:'2026-11-22',endDate:'2026-11-23'})).status,422);
 assert.equal((await api.request('/leave/balance')).body.casual,5);
 await api.restart();
 assert.equal((await api.request('/leave/balance')).body.casual,5);
});
test('startup rejects missing configuration and corrupt storage',async t=>{
 assert.throws(()=>config({}),/OFFICE/);
 const api=await fixture(t);
 await writeFile(api.options.file,'invalid');
 await assert.rejects(createApi(api.options),/Cannot load/);
});
