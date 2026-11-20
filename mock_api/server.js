import express from 'express';
import {mkdir,writeFile,rename} from 'node:fs/promises';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createStore,config,seed,employee,balances,fail} from './store.js';
export {config} from './store.js';
export async function createApi(options,now=()=>new Date()){
 const store=await createStore(options,now);
 const app=express();
 app.disable('x-powered-by');
 app.use(express.json({limit:'64kb'}));
 const delay=()=>new Promise(resolve=>setTimeout(resolve,options.delay));
 app.use(async(req,res,next)=>{
  try {
   const scenario=req.get('X-Mock-Scenario')??'success';
   if(!['success','slow','timeout-after-commit','server-error','attendance-conflict','leave-rejection'].includes(scenario)) fail(400,'INVALID_SCENARIO','Unknown scenario.');
   if(scenario==='server-error') fail(500,'MOCK_SERVER_ERROR','Simulated server error.');
   if(req.query.employeeId && req.query.employeeId!==employee.id) fail(422,'INVALID_EMPLOYEE','Unknown employee.');
   if(scenario==='slow') await delay();
   next();
  }catch(error){next(error);}
 });
 app.get('/health',(req,res)=>res.json({status:'ok'}));
 app.get('/employee/me',(req,res)=>res.json(employee));
 app.get('/leave/balance',(req,res)=>res.json(balances(store.getState())));
 app.get('/leave/requests',(req,res)=>res.json({requests:[...store.getState().requests].sort((a,b)=>b.startDate.localeCompare(a.startDate))}));
 app.get('/attendance',(req,res)=>{
  const month=req.query.month;
  if(typeof month!=='string'||!/^\d{4}-(0[1-9]|1[0-2])$/.test(month)) fail(400,'INVALID_MONTH','Supply month=YYYY-MM.');
  res.json({events:store.getState().events.filter(e=>e.companyDate.startsWith(month)).sort((a,b)=>a.timestamp.localeCompare(b.timestamp))});
 });
 for(const [path,kind,scenario,status] of [['/attendance/events','attendance','attendance-conflict',409],['/leave/requests','leave','leave-rejection',422]]){
  app.post(path,async(req,res)=>{
   if(req.get('X-Mock-Scenario')===scenario) fail(status,scenario,'Simulated rejection.');
   const result=await store.submit(req.body,kind);
   if(req.get('X-Mock-Scenario')==='timeout-after-commit') await delay();
   if(!res.destroyed) res.status(result.status).json(result.body);
  });
 }
 app.use((req,res)=>res.status(404).json({code:'NOT_FOUND',message:'Unknown endpoint.'}));
 app.use((error,req,res,next)=>{
  const status=error.status??500;
  res.status(status).json({code:error.type==='entity.parse.failed'?'INVALID_JSON':error.code??'SERVER_ERROR',message:status<500?error.message:'Could not complete request.'});
 });
 return app;
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 try{
  const options=config();
  if(process.argv.includes('--reset')){
   await mkdir(dirname(options.file),{recursive:true});
   await writeFile(options.file+'.tmp',JSON.stringify(seed(new Date()),null,2));
   await rename(options.file+'.tmp',options.file);
   console.log('Data reset.');
  } else {
   const app=await createApi(options);
   app.listen(options.port,options.host,()=>console.log('Mock API: http://'+options.host+':'+options.port));
  }
 }catch(error){console.error(error.message);process.exitCode=1;}
}
