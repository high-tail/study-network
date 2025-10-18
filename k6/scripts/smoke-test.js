import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Trend } from 'k6/metrics';

// Custom metrics
const failedRequests = new Counter('failed_requests');
const responseTime = new Trend('response_time');

// Smoke test - minimal load to verify system works
export const options = {
  vus: 1, // 1 virtual user
  duration: '1m', // run for 1 minute
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests should be below 500ms
    http_req_failed: ['rate<0.01'], // error rate should be less than 1%
  },
  tags: {
    test_type: 'smoke',
    testid: 'smoke-test-001',
  },
};

export default function () {
  const baseUrl = 'http://10.0.1.20';

  // Test load-balanced endpoint
  const res = http.get(baseUrl);

  // Record custom metrics
  responseTime.add(res.timings.duration);

  // Verify response
  const checkResult = check(res, {
    'status is 200': (r) => r.status === 200,
    'response has content': (r) => r.body.length > 0,
    'server header present': (r) => r.headers['Server'] !== undefined,
  });

  if (!checkResult) {
    failedRequests.add(1);
  }

  sleep(1); // Wait 1 second between iterations
}

export function handleSummary(data) {
  return {
    'stdout': textSummary(data, { indent: ' ', enableColors: true }),
  };
}

function textSummary(data, options) {
  const indent = options?.indent || '';
  const enableColors = options?.enableColors || false;

  let summary = `\n${indent}Smoke Test Results:\n`;
  summary += `${indent}==================\n`;
  summary += `${indent}VUs: ${data.metrics.vus?.values?.value || 'N/A'}\n`;
  summary += `${indent}Duration: ${options.duration || 'N/A'}\n`;
  summary += `${indent}Requests: ${data.metrics.http_reqs?.values?.count || 0}\n`;
  summary += `${indent}Failed: ${data.metrics.http_req_failed?.values?.rate || 0}\n`;
  summary += `${indent}Avg Response: ${data.metrics.http_req_duration?.values?.avg?.toFixed(2) || 0}ms\n`;
  summary += `${indent}P95 Response: ${data.metrics.http_req_duration?.values?.['p(95)']?.toFixed(2) || 0}ms\n`;

  return summary;
}
