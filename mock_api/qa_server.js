import express from 'express';
import {mkdtemp, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createApi} from './server.js';

const directory = await mkdtemp(join(tmpdir(), 'rebs-live-qa-'));
const options = {file: join(directory, 'state.json'), latitude: 12.9716, longitude: 77.5946, delay: 1500};
let api = await createApi(options);
const app = express();
app.post('/__qa/reset', async (req, res) => {
  await rm(options.file, {force: true});
  api = await createApi(options);
  res.json({status: 'reset'});
});
app.use((req, res, next) => api(req, res, next));
const server = app.listen(8081, '127.0.0.1', () => console.log('Isolated QA API: http://127.0.0.1:8081'));
async function close() {
  server.close();
  await rm(directory, {recursive: true, force: true});
  process.exit(0);
}
process.on('SIGINT', close);
process.on('SIGTERM', close);
