import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Trend, Rate } from 'k6/metrics';

// Custom metrics
const failedRequests = new Counter('failed_requests');
const successRate = new Rate('success_rate');
const responseTime = new Trend('response_time');

// Stress test - high load to test system limits and behavior
export const options = {
  stages: [
    { duration: '30s', target: 10 },   // Normal load
    { duration: '2m', target: 100 },   // Ramp up to 100 VUs
    { duration: '30s', target: 100 },  // Maintain high load
    { duration: '2m', target: 10 },    // Quick recovery to normal
    { duration: '3m', target: 10 },    // Stay at normal (observation)
    { duration: '30s', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<5000'], // Allow higher latency during stress
    http_req_failed: ['rate<0.1'],     // Allow 10% error rate during stress
  },
  tags: {
    test_type: 'stress',
    testid: 'stress-test-001',
  },
};

export default function () {
  const baseUrl = 'http://10.0.1.20';

  // Test main endpoint (HAProxy frontend)
  const res = http.get(baseUrl, {
    timeout: '10s', // Longer timeout for stress conditions
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

  // Minimal sleep during stress test
  sleep(0.1);
}

export function handleSummary(data) {
  let summary = '\n  Stress Test Results:\n';
  summary += '  ===================\n';
  summary += `  Test ID: ${data.config?.tags?.testId || 'unknown'}\n`;
  summary += `  Total Requests: ${data.metrics.http_reqs?.values?.count || 0}\n`;
  summary += `  Failed Requests: ${data.metrics.http_req_failed?.values?.rate ? (data.metrics.http_req_failed.values.rate * 100).toFixed(2) : 0}%\n`;
  summary += `  Success Rate: ${data.metrics.success_rate?.values?.rate ? (data.metrics.success_rate.values.rate * 100).toFixed(2) : 0}%\n`;
  summary += `  Avg Response Time: ${data.metrics.http_req_duration?.values?.avg?.toFixed(2) || 0}ms\n`;
  summary += `  P95 Response Time: ${data.metrics.http_req_duration?.values?.['p(95)']?.toFixed(2) || 0}ms\n`;
  summary += `  P99 Response Time: ${data.metrics.http_req_duration?.values?.['p(99)']?.toFixed(2) || 0}ms\n`;
  summary += `  Max Response Time: ${data.metrics.http_req_duration?.values?.max?.toFixed(2) || 0}ms\n`;
  summary += '\n  Note: High latency and some failures are expected during stress\n';

  return {
    'stdout': summary,
  };
}
