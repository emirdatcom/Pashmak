import { check } from 'k6';
import { register, thresholds } from './common.js';

// NOTE: /v1/auth/device is rate limited to 10/hour/IP in production. For this test run staging with a
// raised limit or generate load from many source IPs; otherwise ~all requests will (correctly) be 429.
export const options = {
  scenarios: { device: { executor: 'constant-arrival-rate', rate: 200, timeUnit: '1s', duration: '1m', preAllocatedVUs: 100 } },
  thresholds,
};

export default function () {
  check(register(), { 'got a token': (t) => t !== null });
}
