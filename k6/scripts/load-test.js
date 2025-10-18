import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Trend, Rate } from 'k6/metrics';

// Custom metrics
const failedRequests = new Counter('failed_requests');
const successRate = new Rate('success_rate');
const responseTime = new Trend('response_time');
const web1Hits = new Counter('web1_hits');
const web2Hits = new Counter('web2_hits');

// Load test - normal traffic simulation
export const options = {
  stages: [
    { duration: '2m', target: 10 },  // Ramp up to 10 VUs over 2 minutes
    { duration: '5m', target: 10 },  // Stay at 10 VUs for 5 minutes
    { duration: '2m', target: 20 },  // Ramp up to 20 VUs over 2 minutes
    { duration: '5m', target: 20 },  // Stay at 20 VUs for 5 minutes
    { duration: '2m', target: 0 },   // Ramp down to 0 VUs over 2 minutes
  ],
  thresholds: {
    http_req_duration: ['p(95)<1000'], // 95% of requests should be below 1s
    http_req_failed: ['rate<0.05'],    // error rate should be less than 5%
    'success_rate': ['rate>0.95'],     // success rate should be above 95%
  },
  tags: {
    test_type: 'load',
    testid: 'load-test-001',
  },
};

export default function () {
  const baseUrl = 'http://10.0.1.20';

  // Test main endpoint
  const res = http.get(baseUrl);

  // Record custom metrics
  responseTime.add(res.timings.duration);

  // Check which backend server responded
  if (res.body.includes('Web Server 1')) {
    web1Hits.add(1);
  } else if (res.body.includes('Web Server 2')) {
    web2Hits.add(1);
  }

  // Verify response
  const checkResult = check(res, {
    'status is 200': (r) => r.status === 200,
    'response has content': (r) => r.body.length > 0,
    'response time < 1s': (r) => r.timings.duration < 1000,
    'load balancer working': (r) => r.body.includes('Web Server'),
  });

  successRate.add(checkResult);

  if (!checkResult) {
    failedRequests.add(1);
  }

  // Simulate user think time
  sleep(Math.random() * 3 + 1); // Random sleep between 1-4 seconds
}

export function handleSummary(data) {
  const summary = {
    'stdout': textSummary(data),
    '/tmp/k6-summary.json': JSON.stringify(data),
  };

  return summary;
}

function textSummary(data) {
  let summary = '\n  Load Test Results:\n';
  summary += '  ==================\n';
  summary += `  Total Requests: ${data.metrics.http_reqs?.values?.count || 0}\n`;
  summary += `  Failed Requests: ${data.metrics.http_req_failed?.values?.rate ? (data.metrics.http_req_failed.values.rate * 100).toFixed(2) : 0}%\n`;
  summary += `  Success Rate: ${data.metrics.success_rate?.values?.rate ? (data.metrics.success_rate.values.rate * 100).toFixed(2) : 0}%\n`;
  summary += `  Avg Response Time: ${data.metrics.http_req_duration?.values?.avg?.toFixed(2) || 0}ms\n`;
  summary += `  P95 Response Time: ${data.metrics.http_req_duration?.values?.['p(95)']?.toFixed(2) || 0}ms\n`;
  summary += `  P99 Response Time: ${data.metrics.http_req_duration?.values?.['p(99)']?.toFixed(2) || 0}ms\n`;
  summary += `  Max Response Time: ${data.metrics.http_req_duration?.values?.max?.toFixed(2) || 0}ms\n`;
  summary += `  Web1 Hits: ${data.metrics.web1_hits?.values?.count || 0}\n`;
  summary += `  Web2 Hits: ${data.metrics.web2_hits?.values?.count || 0}\n`;

  return summary;
}
