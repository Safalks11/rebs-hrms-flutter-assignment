
import { readFile, mkdir, writeFile, rename } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';


const DAY = 86400000;
const employee = { id: 'EMP001', name: 'Alex Johnson', department: 'Engineering' };
const dateKey = value => new Date(new Date(value).getTime() + 19800000).toISOString().slice(0, 10);
const fail = (status, code, message) => { throw Object.assign(new Error(message), { status, code }); };
function date(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value) ||
      !Number.isFinite(Date.parse(value)) || new Date(value).toISOString().slice(0, 10) !== value) {
    fail(400, 'INVALID_DATE', 'Dates must use valid YYYY-MM-DD values.');
  }
  return Date.parse(value);
}
function identity(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) fail(400, 'INVALID_BODY', 'Expected a JSON object.');
  if (input.employeeId !== employee.id) fail(422, 'INVALID_EMPLOYEE', 'Unknown employee.');
  if (typeof input.id !== 'string' || !input.id.trim()) fail(400, 'INVALID_ID', 'A stable nonempty request ID is required.');
}
function normalize(input, kind) {
  identity(input);
  if (kind === 'attendance') {
    if (!['checkIn', 'checkOut'].includes(input.type)) fail(400, 'INVALID_TYPE', 'Invalid attendance type.');
    date(input.companyDate);
    if (typeof input.timestamp !== 'string' || !/(Z|[+-]\d{2}:\d{2})$/.test(input.timestamp) || !Number.isFinite(Date.parse(input.timestamp))) fail(400, 'INVALID_TIMESTAMP', 'Timestamp must include a timezone.');
    if (!Number.isFinite(input.latitude) || Math.abs(input.latitude) > 90 || !Number.isFinite(input.longitude) || Math.abs(input.longitude) > 180) fail(400, 'INVALID_COORDINATES', 'Invalid coordinates.');
    return { id: input.id, employeeId: input.employeeId, companyDate: input.companyDate, type: input.type, timestamp: new Date(input.timestamp).toISOString(), latitude: input.latitude, longitude: input.longitude };
  }
  if (!['casual', 'sick'].includes(input.type)) fail(400, 'INVALID_TYPE', 'Invalid leave type.');
  date(input.startDate); date(input.endDate);
  if (typeof input.reason !== 'string') fail(400, 'INVALID_REASON', 'Reason is required.');
  return { id: input.id, employeeId: input.employeeId, type: input.type, startDate: input.startDate, endDate: input.endDate, reason: input.reason.trim() };
}
const days = request => (date(request.endDate) - date(request.startDate)) / DAY + 1;
function balances(state) {
  const result = { casual: 8, sick: 5 };
  for (const request of state.requests) if (request.status !== 'rejected') result[request.type] -= days(request);
  return result;
}
export function seed() {
  return { version: 1, events: [], requests: [] };
}
function distance(a, b, c, d) {
  const rad = n => n * Math.PI / 180;
  const h = Math.sin(rad(c - a) / 2) ** 2 + Math.cos(rad(a)) * Math.cos(rad(c)) * Math.sin(rad(d - b) / 2) ** 2;
  return 6371000 * 2 * Math.asin(Math.sqrt(Math.min(1, h)));
}
export function config(env = process.env) {
  const latitude = Number(env.OFFICE_LATITUDE), longitude = Number(env.OFFICE_LONGITUDE);
  if (!env.OFFICE_LATITUDE?.trim() || !env.OFFICE_LONGITUDE?.trim() || !Number.isFinite(latitude) || Math.abs(latitude) > 90 || !Number.isFinite(longitude) || Math.abs(longitude) > 180) throw new Error('Set valid OFFICE_LATITUDE and OFFICE_LONGITUDE.');
  const port = Number(env.PORT ?? 8080), delay = Number(env.MOCK_DELAY_MS ?? 20000);
  if (!Number.isInteger(port) || port < 0 || port > 65535 || !Number.isFinite(delay) || delay < 0 || delay > 120000) throw new Error('Invalid PORT or MOCK_DELAY_MS (0–120000).');
  return { latitude, longitude, port, delay, host: env.HOST ?? '127.0.0.1', file: resolve(env.DATA_FILE ?? 'data/state.json') };
}
export async function createStore(options, now) {
  const persist = async state => {
    await mkdir(dirname(options.file), { recursive: true });
    await writeFile(options.file + '.tmp', JSON.stringify(state, null, 2));
    await rename(options.file + '.tmp', options.file);
  };
  let state;
  try {
    state = JSON.parse(await readFile(options.file, 'utf8'));
    if (state.version !== 1 || !Array.isArray(state.events) || !Array.isArray(state.requests)) throw new Error('Invalid storage structure.');
    for (const [kind, entries] of [['attendance', state.events], ['leave', state.requests]]) {
      const ids = new Set();
      for (const entry of entries) {
        normalize(entry, kind);
        if (ids.has(entry.id)) throw new Error('Duplicate stored ID.');
        ids.add(entry.id);
        if (kind === 'leave' && (!['pending', 'approved', 'rejected'].includes(entry.status) || days(entry) < 1)) throw new Error('Invalid stored leave.');
      }
    }
    if (Object.values(balances(state)).some(value => value < 0)) throw new Error('Invalid stored balances.');
  } catch (error) {
    if (error.code !== 'ENOENT') throw new Error('Cannot load mock storage: ' + error.message);
    state = seed(now());
    await persist(state);
  }
  let queue = Promise.resolve();
  function mutate(work) {
    const operation = queue.then(async () => {
      const next = structuredClone(state);
      const result = work(next);
      await persist(next);
      state = next;
      return result;
    });
    queue = operation.catch(() => {});
    return operation;
  }
  async function submit(input, kind) {
    const value = normalize(input, kind);
    return mutate(next => {
      const entries = kind === 'attendance' ? next.events : next.requests;
      const existing = entries.find(entry => entry.id === value.id);
      if (existing) {
        if (JSON.stringify(normalize(existing, kind)) !== JSON.stringify(value)) fail(409, 'ID_CONFLICT', 'This ID was used with different data.');
        return { status: 200, body: existing };
      }
      if (kind === 'attendance') {
        const timestamp = Date.parse(value.timestamp);
        const age = (date(dateKey(now())) - date(value.companyDate)) / DAY;
        if (timestamp > now().getTime() || age < 0 || age > 29 || dateKey(value.timestamp) !== value.companyDate) fail(422, 'INVALID_ATTENDANCE_DAY', 'Attendance must belong to today or the preceding 29 company dates.');
        if (distance(options.latitude, options.longitude, value.latitude, value.longitude) > 200) fail(422, 'OUTSIDE_OFFICE', 'Attendance must be within 200 metres of the office.');
        const session = entries.filter(entry => entry.companyDate === value.companyDate);
        if (session.some(entry => entry.type === value.type)) fail(409, 'DUPLICATE_ATTENDANCE', 'Attendance action already exists.');
        const checkIn = session.find(entry => entry.type === 'checkIn');
        if (value.type === 'checkOut' && (!checkIn || timestamp < Date.parse(checkIn.timestamp))) fail(422, 'INVALID_ORDER', 'Check in on the same company date before checking out.');
        entries.push(value);
        return { status: 201, body: value };
      }
      if (date(value.startDate) < date(dateKey(now())) || days(value) < 1) fail(422, 'INVALID_LEAVE_DATES', 'Start must be today or later and end must not precede start.');
      if (value.reason.replace(/\s/g, '').length < 10) fail(422, 'SHORT_REASON', 'Reason needs 10 non-whitespace characters.');
      if (entries.some(entry => entry.status !== 'rejected' && value.startDate <= entry.endDate && value.endDate >= entry.startDate)) fail(422, 'OVERLAPPING_LEAVE', 'Dates overlap existing leave.');
      if (days(value) > balances(next)[value.type]) fail(422, 'INSUFFICIENT_BALANCE', 'Requested days exceed available balance.');
      const created = { ...value, status: 'pending' };
      entries.push(created);
      return { status: 201, body: created };
    });
  }
return { submit, getState: () => state };
}
export { employee, balances, fail };
