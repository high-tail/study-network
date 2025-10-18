import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Trend, Rate } from 'k6/metrics';

// Custom metrics
const failedRequests = new Counter('failed_requests');
const successRate = new Rate('success_rate');
const responseTime = new Trend('response_time');

// Spike test - sudden burst of traffic to test system recovery
export const options = {
  stages: [
    { duration: '30s', target: 10 },   // Normal load
    { duration: '1m', target: 200 },   // Sudden spike to 200 VUs
    { duration: '30s', target: 200 },  // Maintain spike
    { duration: '1m', target: 10 },    // Quick recovery to normal
    { duration: '2m', target: 10 },    // Stay at normal (recovery observation)
    { duration: '30s', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<3000'], // Allow high latency during spike
    http_req_failed: ['rate<0.2'],     // Allow 20% error rate during spike
  },
  tags: {
    test_type: 'spike',
    testid: 'spike-test-001',
  },
};

export default function () {
  const baseUrl = 'http://10.0.1.20';

  // Test main endpoint
  const res = http.get(baseUrl, {
    timeout: '10s', // Longer timeout for spike conditions
  });

  // Record custom metrics
  responseTime.add(res.timings.duration);

  // Verify response
  const checkResult = check(res, {
    'status is 200': (r) => r.status === 200,
    'response received': (r) => r.body !== undefined,
  });

  successRate.add(checkResult);

  if (!checkResult) {
    failedRequests.add(1);
  }

  // Minimal sleep during spike
  sleep(0.3);
}

export function handleSummary(data) {
  let summary = '\n  Spike Test Results:\n';
  summary += '  ===================\n';
  summary += `  Test ID: ${data.config?.tags?.testId || 'unknown'}\n`;
  summary += `  Total Requests: ${data.metrics.http_reqs?.values?.count || 0}\n`;
  summary += `  Failed Requests: ${data.metrics.http_req_failed?.values?.rate ? (data.metrics.http_req_failed.values.rate * 100).toFixed(2) : 0}%\n`;
  summary += `  Success Rate: ${data.metrics.success_rate?.values?.rate ? (data.metrics.success_rate.values.rate * 100).toFixed(2) : 0}%\n`;
  summary += `  Avg Response Time: ${data.metrics.http_req_duration?.values?.avg?.toFixed(2) || 0}ms\n`;
  summary += `  P95 Response Time: ${data.metrics.http_req_duration?.values?.['p(95)']?.toFixed(2) || 0}ms\n`;
  summary += `  P99 Response Time: ${data.metrics.http_req_duration?.values?.['p(99)']?.toFixed(2) || 0}ms\n`;
  summary += `  Max Response Time: ${data.metrics.http_req_duration?.values?.max?.toFixed(2) || 0}ms\n`;
  summary += '\n  Note: High latency and some failures are expected during spike\n';

  return {
    'stdout': summary,
  };
}
