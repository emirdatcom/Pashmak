import http from 'k6/http';
import { check } from 'k6';
import { uuidv4 } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';
import { BASE, headers, register, thresholds } from './common.js';

export const options = {
  scenarios: { events: { executor: 'constant-arrival-rate', rate: 200, timeUnit: '1s', duration: '2m', preAllocatedVUs: 100 } },
  thresholds,
};

let token = null;
export default function () {
  if (!token) token = register();
  const body = JSON.stringify({
    sent_at: new Date().toISOString(),
    events: [
      { event_id: uuidv4(), name: 'app_opened', ts: new Date().toISOString(), session_id: `s-${__VU}`, props: { source: 'launcher', app_version: '1.0.0', market: 'bazaar' } },
    ],
  });
  const res = http.post(`${BASE}/v1/events`, body, { headers: { ...headers, Authorization: `Bearer ${token}` } });
  check(res, { 'events 200': (r) => r.status === 200 });
}
