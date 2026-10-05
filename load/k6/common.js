import http from 'k6/http';
import { check } from 'k6';
import { uuidv4 } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';

export const BASE = __ENV.BASE_URL || 'http://localhost:8080';
export const headers = { 'Content-Type': 'application/json', 'X-App-Version': '1.0.0', 'X-Market': 'bazaar' };

// One device registration per virtual user (the endpoint is limited to 10/h per IP, so run the
// load test from several IPs or raise the staging limit through the env; see load/README.md).
export function register() {
  const res = http.post(`${BASE}/v1/auth/device`, JSON.stringify({
    install_id: uuidv4(), device_hash_raw: `k6-${__VU}-${Math.random()}`, market: 'bazaar',
    app_version: '1.0.0', os_version: '14', model: 'k6',
  }), { headers });
  check(res, { 'device registered': (r) => r.status === 200 });
  return res.status === 200 ? res.json('access_token') : null;
}

export const thresholds = {
  http_req_failed: ['rate<0.005'],      // error < 0.5%
  http_req_duration: ['p(95)<200'],     // p95 < 200ms
};
