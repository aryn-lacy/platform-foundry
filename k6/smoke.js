// k6 smoke profile — the fixed load shape the perf gate judges against
// the committed baseline (issue #5, ADR-005).
//
// Fixed by design: the BASELINE is only meaningful if the load profile
// that produced it never varies. Tunables (BASE_URL, DURATION, VUS_MAX)
// exist for wiring, not for per-run tweaking — CI always runs defaults.
//
// Endpoints: public RealWorld API routes (no auth — login scenarios need
// seeded users; deferred and documented in the PR). JVM warmup is why
// the profile ramps (2 -> VUS_MAX) instead of slamming from zero, and
// why the sanity ceiling is generous (3s p95) — the REGRESSION gate is
// the baseline diff, not these ceilings.
import http from 'k6/http';
import { check } from 'k6';
import { Trend, Rate } from 'k6/metrics';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const DURATION = __ENV.DURATION || '30s';
const VUS_MAX = parseInt(__ENV.VUS || '10', 10);

const articlesLatency = new Trend('smoke_articles_latency', true);
const tagsLatency = new Trend('smoke_tags_latency', true);
const articlesFailed = new Rate('smoke_articles_failed');
const tagsFailed = new Rate('smoke_tags_failed');

export const options = {
  scenarios: {
    articles_list: {
      executor: 'ramping-vus',
      startVUs: 2,
      stages: [
        { duration: '10s', target: VUS_MAX },
        { duration: DURATION, target: VUS_MAX },
        { duration: '5s', target: 0 },
      ],
      gracefulRampDown: '5s',
      exec: 'articles',
    },
    tags: {
      executor: 'ramping-vus',
      startVUs: 2,
      stages: [
        { duration: '10s', target: Math.max(2, Math.floor(VUS_MAX / 2)) },
        { duration: DURATION, target: Math.max(2, Math.floor(VUS_MAX / 2)) },
        { duration: '5s', target: 0 },
      ],
      gracefulRampDown: '5s',
      exec: 'tags',
      startTime: '2s',
    },
  },
  thresholds: {
    // Sanity ceilings only — the regression gate is the baseline diff.
    'http_req_duration{scenario:articles_list}': ['p(95)<3000'],
    'http_req_duration{scenario:tags}': ['p(95)<3000'],
    'http_req_failed': ['rate<0.01'],
  },
};

export function articles() {
  const res = http.get(`${BASE_URL}/articles?limit=10`, {
    tags: { scenario: 'articles_list' },
  });
  articlesLatency.add(res.timings.duration);
  articlesFailed.add(res.status === 0 || res.status >= 400);
  check(res, { 'articles 200': (r) => r.status === 200 });
}

export function tags() {
  const res = http.get(`${BASE_URL}/tags`, {
    tags: { scenario: 'tags' },
  });
  tagsLatency.add(res.timings.duration);
  tagsFailed.add(res.status === 0 || res.status >= 400);
  check(res, { 'tags 200': (r) => r.status === 200 });
}

// Machine-readable summary for scripts/check-regression.sh
export function handleSummary(data) {
  // NOTE: run k6 with K6_SUMMARY_TREND_STATS="avg,p(95),p(99),count" —
  // k6 v2's default trend stats omit p(99)/count, which the gate reports.
  // The env is set by perf.yml and seed-baseline.sh; a bare `k6 run`
  // still yields p95/avg/error_rate (the gated metrics).
  const pick = (name) => {
    const t = data.metrics[`smoke_${name}_latency`];
    const f = data.metrics[`smoke_${name}_failed`];
    return {
      p95: t && t.values ? t.values['p(95)'] : null,
      p99: t && t.values ? t.values['p(99)'] : null,
      avg: t && t.values ? t.values.avg : null,
      error_rate: f && f.values ? f.values.rate : null,
      count: (t && t.values && t.values.count) ?? 0,
    };
  };
  return {
    'summary-handle.json': JSON.stringify(
      {
        generated_at: new Date().toISOString(),
        scenarios: {
          articles: pick('articles'),
          tags: pick('tags'),
        },
        overall_http_failed: data.metrics.http_req_failed
          ? data.metrics.http_req_failed.values.rate
          : null,
      },
      null,
      2
    ),
  };
}
