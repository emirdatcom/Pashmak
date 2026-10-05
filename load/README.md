# Load tests (k6)

```bash
k6 run -e BASE_URL=https://staging-api.example.ir load/k6/config.js
k6 run -e BASE_URL=https://staging-api.example.ir load/k6/events.js
k6 run -e BASE_URL=https://staging-api.example.ir load/k6/auth_device.js   # needs a raised per-IP limit, see the file
```
Targets (prompt 20 §4): 200 rps, p95 < 200 ms, error rate < 0.5 %. **Not run in the authoring environment**
(no staging server, no k6); record the results in `docs/release-checklist-<version>.md`.
