import http from 'k6/http';
import { check } from 'k6';
import { BASE, headers, thresholds } from './common.js';

export const options = {
  scenarios: { config: { executor: 'constant-arrival-rate', rate: 200, timeUnit: '1s', duration: '2m', preAllocatedVUs: 100 } },
  thresholds,
};

export default function () {
  const res = http.get(`${BASE}/v1/config`, { headers });
  check(res, { 'config 200 or 304': (r) => r.status === 200 || r.status === 304 });
}
