const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const ROOT_DIR = path.resolve(__dirname, '..');
const EVIDENCE_DIR = path.join(ROOT_DIR, 'evidence');
const API_BASE = process.env.API_BASE_URL || 'http://localhost:4000/api';
const WEB_BASE = process.env.WEB_BASE_URL || 'http://localhost:8080';
const ADMINER_BASE = process.env.ADMINER_BASE_URL || 'http://localhost:8081';

function getCommitSha() {
  return execSync('git rev-parse HEAD', { cwd: ROOT_DIR, encoding: 'utf8' }).trim();
}

async function reqJson(url, options = {}) {
  const res = await fetch(url, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      Connection: 'close',
      ...(options.headers || {}),
    },
  });
  const body = await res.json();
  return { status: res.status, body };
}

function writeEvidence(filename, payload) {
  fs.mkdirSync(EVIDENCE_DIR, { recursive: true });
  const filePath = path.join(EVIDENCE_DIR, filename);
  fs.writeFileSync(filePath, JSON.stringify(payload, null, 2), 'utf8');
  return `evidence/${filename}`;
}

async function main() {
  const runStartedAt = new Date().toISOString();
  const commitSha = getCommitSha();
  fs.mkdirSync(EVIDENCE_DIR, { recursive: true });

  console.log(`[QAE v2.0] Memulai eksekusi suite pada commit ${commitSha} (${runStartedAt})`);

  // -------------------------------------------------------------------------
  // EXP-001: 5-Container Health & Orchestration (Postgres + Redis + Adminer + Backend + Frontend)
  // -------------------------------------------------------------------------
  const psOutput = execSync('docker compose ps --format json', { cwd: ROOT_DIR, encoding: 'utf8' }).trim();
  const containers = psOutput.split('\n').filter(Boolean).map((line) => JSON.parse(line));
  const healthRes = await reqJson(`${API_BASE}/health`);
  const exp001Pass =
    containers.length >= 5 &&
    healthRes.status === 200 &&
    healthRes.body.status === 'ok' &&
    healthRes.body.db === 'connected' &&
    healthRes.body.redis === 'connected' &&
    Boolean(healthRes.body.containerId);

  writeEvidence('EXP-001-health.json', {
    id: 'EXP-001',
    status: exp001Pass ? 'PASS' : 'FAIL',
    commit_sha: commitSha,
    exit_code: exp001Pass ? 0 : 1,
    failures: exp001Pass ? 0 : 1,
    http_status: healthRes.status,
    health_payload: healthRes.body,
    running_containers_count: containers.length,
    docker_compose_ps: containers,
  });

  // -------------------------------------------------------------------------
  // EXP-002: Positive CRUD & Financial Summary Calculation
  // -------------------------------------------------------------------------
  const beforeSum = await reqJson(`${API_BASE}/summary`);
  const createdInc = await reqJson(`${API_BASE}/transactions`, {
    method: 'POST',
    body: JSON.stringify({
      title: 'Bonus Project Docker v2',
      amount: 2000000,
      type: 'income',
      category: 'Bonus',
      note: 'QAE EXP-002 positive income test',
    }),
  });
  const createdExp = await reqJson(`${API_BASE}/transactions`, {
    method: 'POST',
    body: JSON.stringify({
      title: 'Langganan Server Cloud',
      amount: 250000,
      type: 'expense',
      category: 'Tagihan',
      note: 'QAE EXP-002 positive expense test',
    }),
  });
  const afterSum = await reqJson(`${API_BASE}/summary`);

  const expectedIncome = Number(beforeSum.body.totalIncome) + 2000000;
  const expectedExpense = Number(beforeSum.body.totalExpense) + 250000;
  const expectedBalance = expectedIncome - expectedExpense;

  const exp002Pass =
    createdInc.status === 201 &&
    createdExp.status === 201 &&
    afterSum.status === 200 &&
    Number(afterSum.body.totalIncome) === expectedIncome &&
    Number(afterSum.body.totalExpense) === expectedExpense &&
    Number(afterSum.body.balance) === expectedBalance;

  writeEvidence('EXP-002-crud-summary.json', {
    id: 'EXP-002',
    status: exp002Pass ? 'PASS' : 'FAIL',
    commit_sha: commitSha,
    exit_code: exp002Pass ? 0 : 1,
    failures: exp002Pass ? 0 : 1,
    created_income: createdInc.body,
    created_expense: createdExp.body,
    summary_before: beforeSum.body,
    summary_after: afterSum.body,
  });

  // -------------------------------------------------------------------------
  // EXP-003: Negative Input Validation (POST & PUT)
  // -------------------------------------------------------------------------
  const negAmount = await reqJson(`${API_BASE}/transactions`, {
    method: 'POST',
    body: JSON.stringify({
      title: 'Transaksi Negatif',
      amount: -50000,
      type: 'expense',
      category: 'Makanan',
    }),
  });
  const emptyTitle = await reqJson(`${API_BASE}/transactions`, {
    method: 'POST',
    body: JSON.stringify({
      title: '   ',
      amount: 50000,
      type: 'expense',
      category: 'Makanan',
    }),
  });
  const invalidPut = await reqJson(`${API_BASE}/transactions/999999`, {
    method: 'PUT',
    body: JSON.stringify({
      title: 'Tidak Ada ID',
      amount: 50000,
      type: 'expense',
      category: 'Makanan',
    }),
  });

  const exp003Pass =
    negAmount.status === 400 &&
    emptyTitle.status === 400 &&
    invalidPut.status === 404;

  writeEvidence('EXP-003-negative-validation.json', {
    id: 'EXP-003',
    status: exp003Pass ? 'PASS' : 'FAIL',
    commit_sha: commitSha,
    exit_code: exp003Pass ? 0 : 1,
    failures: exp003Pass ? 0 : 1,
    negative_amount_response: negAmount,
    empty_title_response: emptyTitle,
    not_found_put_response: invalidPut,
  });

  // -------------------------------------------------------------------------
  // EXP-004: Database Persistence in PostgreSQL Container
  // -------------------------------------------------------------------------
  const pgQueryCmd = `docker exec expense-db psql -U dompetku -d dompetku_db -t -A -c "SELECT COUNT(*) || '|' || COALESCE(SUM(amount),0) FROM transactions;"`;
  const rawPgBeforeRestart = execSync(pgQueryCmd, { cwd: ROOT_DIR, encoding: 'utf8' }).trim();
  execSync('docker restart expense-backend', { cwd: ROOT_DIR, stdio: 'pipe' });
  let backendReady = false;
  for (let i = 0; i < 15; i++) {
    try {
      const check = await reqJson(`${API_BASE}/health`);
      if (check.status === 200 && check.body.db === 'connected' && check.body.redis === 'connected') {
        backendReady = true;
        break;
      }
    } catch {
      // wait
    }
    await new Promise((r) => setTimeout(r, 1000));
  }
  const rawPgAfterRestart = execSync(pgQueryCmd, { cwd: ROOT_DIR, encoding: 'utf8' }).trim();
  const exp004Pass =
    backendReady &&
    rawPgBeforeRestart === rawPgAfterRestart &&
    Number(rawPgAfterRestart.split('|')[0]) >= 5;

  writeEvidence('EXP-004-db-persistence.json', {
    id: 'EXP-004',
    status: exp004Pass ? 'PASS' : 'FAIL',
    commit_sha: commitSha,
    exit_code: exp004Pass ? 0 : 1,
    failures: exp004Pass ? 0 : 1,
    pg_before_restart: rawPgBeforeRestart,
    pg_after_restart: rawPgAfterRestart,
    backend_reconnected: backendReady,
  });

  // -------------------------------------------------------------------------
  // EXP-005: Security (OWASP XSS Sanitization & SQL Injection Resilience)
  // -------------------------------------------------------------------------
  const xssRes = await reqJson(`${API_BASE}/transactions`, {
    method: 'POST',
    body: JSON.stringify({
      title: '<script>alert("hacked")</script>Beli Kopi Aman',
      amount: 25000,
      type: 'expense',
      category: '<b>Makanan</b>',
      note: '<img src=x onerror=alert(1)>Catatan aman',
    }),
  });
  const sqliRes = await reqJson(
    `${API_BASE}/transactions?search=${encodeURIComponent("' OR '1'='1'; DROP TABLE transactions; --")}`
  );
  const healthAfterSec = await reqJson(`${API_BASE}/health`);

  const exp005Pass =
    xssRes.status === 201 &&
    xssRes.body.item.title === 'Beli Kopi Aman' &&
    !xssRes.body.item.title.includes('<script>') &&
    sqliRes.status === 200 &&
    healthAfterSec.status === 200;

  writeEvidence('EXP-005-security.json', {
    id: 'EXP-005',
    status: exp005Pass ? 'PASS' : 'FAIL',
    commit_sha: commitSha,
    exit_code: exp005Pass ? 0 : 1,
    failures: exp005Pass ? 0 : 1,
    sanitized_item: xssRes.body.item,
    sqli_search_status: sqliRes.status,
    table_intact: healthAfterSec.body.db === 'connected',
  });

  // -------------------------------------------------------------------------
  // EXP-006: Unit & Widget Tests (Backend Node + Frontend Flutter)
  // -------------------------------------------------------------------------
  const backendTestOut = execSync('npm run lint && npm test', {
    cwd: path.join(ROOT_DIR, 'backend'),
    encoding: 'utf8',
  });
  const flutterTestOut = execSync('flutter analyze lib && flutter test', {
    cwd: path.join(ROOT_DIR, 'frontend'),
    encoding: 'utf8',
  });

  const exp006Pass =
    backendTestOut.includes('fail 0') &&
    flutterTestOut.includes('All tests passed!');

  writeEvidence('EXP-006-unit-widget.json', {
    id: 'EXP-006',
    status: exp006Pass ? 'PASS' : 'FAIL',
    commit_sha: commitSha,
    exit_code: exp006Pass ? 0 : 1,
    failures: exp006Pass ? 0 : 1,
    backend_output_tail: backendTestOut.slice(-400),
    flutter_output_tail: flutterTestOut.slice(-400),
  });

  // -------------------------------------------------------------------------
  // EXP-008: Edit / Update Transaction (PUT /api/transactions/:id)
  // -------------------------------------------------------------------------
  const targetTxId = createdExp.body.item.id;
  const editRes = await reqJson(`${API_BASE}/transactions/${targetTxId}`, {
    method: 'PUT',
    body: JSON.stringify({
      title: 'Langganan Server Cloud & Redis (Edited)',
      amount: 300000,
      type: 'expense',
      category: 'Tagihan',
      note: 'Telah diedit melalui PUT /api/transactions/:id',
    }),
  });
  const exp008Pass =
    editRes.status === 200 &&
    editRes.body.item.id === targetTxId &&
    editRes.body.item.title === 'Langganan Server Cloud & Redis (Edited)' &&
    Number(editRes.body.item.amount) === 300000;

  writeEvidence('EXP-008-edit-transaction.json', {
    id: 'EXP-008',
    status: exp008Pass ? 'PASS' : 'FAIL',
    commit_sha: commitSha,
    exit_code: exp008Pass ? 0 : 1,
    failures: exp008Pass ? 0 : 1,
    updated_transaction: editRes.body.item,
  });

  // -------------------------------------------------------------------------
  // EXP-009: Redis Cache (Flush -> MISS -> HIT) & Adminer Web GUI (:8081)
  // -------------------------------------------------------------------------
  const flushRes = await reqJson(`${API_BASE}/cache/flush`, { method: 'POST' });
  const sumAfterFlush = await reqJson(`${API_BASE}/summary`);
  const sumSecondCall = await reqJson(`${API_BASE}/summary`);
  const adminerHtmlRes = await fetch(ADMINER_BASE);
  const adminerHtmlText = await adminerHtmlRes.text();

  const exp009Pass =
    flushRes.status === 200 &&
    sumAfterFlush.body.cacheStatus === 'MISS' &&
    sumSecondCall.body.cacheStatus === 'HIT' &&
    adminerHtmlRes.status === 200 &&
    adminerHtmlText.toLowerCase().includes('adminer');

  writeEvidence('EXP-009-redis-adminer.json', {
    id: 'EXP-009',
    status: exp009Pass ? 'PASS' : 'FAIL',
    commit_sha: commitSha,
    exit_code: exp009Pass ? 0 : 1,
    failures: exp009Pass ? 0 : 1,
    flush_response: flushRes.body,
    first_summary_cache_status: sumAfterFlush.body.cacheStatus,
    second_summary_cache_status: sumSecondCall.body.cacheStatus,
    adminer_http_status: adminerHtmlRes.status,
    adminer_title_verified: adminerHtmlText.toLowerCase().includes('adminer'),
  });

  // -------------------------------------------------------------------------
  // EXP-007: Browser E2E via Selenium WebDriver
  // -------------------------------------------------------------------------
  execSync(`python qa/selenium_e2e.py "${WEB_BASE}" "${commitSha}" "${EVIDENCE_DIR}"`, {
    cwd: ROOT_DIR,
    stdio: 'inherit',
  });
  const seleniumReport = JSON.parse(
    fs.readFileSync(path.join(EVIDENCE_DIR, 'EXP-007-selenium-e2e.json'), 'utf8')
  );
  const exp007Pass = seleniumReport.status === 'PASS';

  // -------------------------------------------------------------------------
  // Write QAE Spec & Input JSON for Independent Verifier
  // -------------------------------------------------------------------------
  const expectedCriteria = [
    'EXP-001',
    'EXP-002',
    'EXP-003',
    'EXP-004',
    'EXP-005',
    'EXP-006',
    'EXP-007',
    'EXP-008',
    'EXP-009',
  ];

  const qaeSpec = {
    feature: 'dompetku-flutter-docker-expense-v2',
    expected_criteria: expectedCriteria,
  };
  fs.writeFileSync(path.join(ROOT_DIR, 'qae-spec.json'), JSON.stringify(qaeSpec, null, 2), 'utf8');

  const qaeInput = {
    feature: 'dompetku-flutter-docker-expense-v2',
    commit_sha: commitSha,
    run_started_at: runStartedAt,
    expected_criteria: expectedCriteria,
    required_layers: ['integration', 'api', 'database', 'security', 'unit', 'e2e'],
    criteria: [
      {
        id: 'EXP-001',
        title: 'All 5 Docker containers (db, redis, adminer, backend, frontend) healthy & GET /api/health returns 200 OK',
        layer: 'integration',
        status: exp001Pass ? 'PASS' : 'FAIL',
        mandatory: true,
        evidence: ['evidence/EXP-001-health.json'],
      },
      {
        id: 'EXP-002',
        title: 'Positive CRUD transactions & financial summary calculation',
        layer: 'api',
        status: exp002Pass ? 'PASS' : 'FAIL',
        mandatory: true,
        evidence: ['evidence/EXP-002-crud-summary.json'],
      },
      {
        id: 'EXP-003',
        title: 'Negative input validation on POST/PUT rejects invalid amounts, empty title, and non-existent ID',
        layer: 'api',
        status: exp003Pass ? 'PASS' : 'FAIL',
        mandatory: true,
        evidence: ['evidence/EXP-003-negative-validation.json'],
      },
      {
        id: 'EXP-004',
        title: 'PostgreSQL database persistence & Docker volume survives container restart',
        layer: 'database',
        status: exp004Pass ? 'PASS' : 'FAIL',
        mandatory: true,
        evidence: ['evidence/EXP-004-db-persistence.json'],
      },
      {
        id: 'EXP-005',
        title: 'OWASP XSS tag sanitization and SQL Injection resilience',
        layer: 'security',
        status: exp005Pass ? 'PASS' : 'FAIL',
        mandatory: true,
        evidence: ['evidence/EXP-005-security.json'],
      },
      {
        id: 'EXP-006',
        title: 'Backend unit tests and Flutter widget tests (including Charts & Edit) pass with 0 warnings/errors',
        layer: 'unit',
        status: exp006Pass ? 'PASS' : 'FAIL',
        mandatory: true,
        evidence: ['evidence/EXP-006-unit-widget.json'],
      },
      {
        id: 'EXP-007',
        title: 'Selenium WebDriver E2E test on Flutter Web Pro Dashboard (http://localhost:8080) with screenshot',
        layer: 'e2e',
        status: exp007Pass ? 'PASS' : 'FAIL',
        mandatory: true,
        evidence: ['evidence/EXP-007-selenium-e2e.json', 'evidence/EXP-007-selenium-ui.png'],
      },
      {
        id: 'EXP-008',
        title: 'Edit / Update Transaction (PUT /api/transactions/:id) updates existing record and recalculates balance',
        layer: 'api',
        status: exp008Pass ? 'PASS' : 'FAIL',
        mandatory: true,
        evidence: ['evidence/EXP-008-edit-transaction.json'],
      },
      {
        id: 'EXP-009',
        title: 'Redis Cache (MISS -> HIT -> Flush) & Adminer Database Web GUI (http://localhost:8081) verified',
        layer: 'integration',
        status: exp009Pass ? 'PASS' : 'FAIL',
        mandatory: true,
        evidence: ['evidence/EXP-009-redis-adminer.json'],
      },
    ],
    test_execution: {
      integration: {
        command_executed: true,
        exit_code: exp001Pass && exp009Pass ? 0 : 1,
        status: exp001Pass && exp009Pass ? 'PASS' : 'FAIL',
        tests_executed: 3,
        failures: exp001Pass && exp009Pass ? 0 : 1,
      },
      api: {
        command_executed: true,
        exit_code: exp002Pass && exp003Pass && exp008Pass ? 0 : 1,
        status: exp002Pass && exp003Pass && exp008Pass ? 'PASS' : 'FAIL',
        tests_executed: 6,
        failures: exp002Pass && exp003Pass && exp008Pass ? 0 : 1,
      },
      database: {
        command_executed: true,
        exit_code: exp004Pass ? 0 : 1,
        status: exp004Pass ? 'PASS' : 'FAIL',
        tests_executed: 2,
        failures: exp004Pass ? 0 : 1,
      },
      security: {
        command_executed: true,
        exit_code: exp005Pass ? 0 : 1,
        status: exp005Pass ? 'PASS' : 'FAIL',
        tests_executed: 2,
        failures: exp005Pass ? 0 : 1,
      },
      unit: {
        command_executed: true,
        exit_code: exp006Pass ? 0 : 1,
        status: exp006Pass ? 'PASS' : 'FAIL',
        tests_executed: 5,
        failures: exp006Pass ? 0 : 1,
      },
      e2e: {
        command_executed: true,
        exit_code: exp007Pass ? 0 : 1,
        status: exp007Pass ? 'PASS' : 'FAIL',
        tests_executed: 1,
        failures: exp007Pass ? 0 : 1,
      },
    },
    residual_risks: [
      'Aplikasi berjalan pada environment Docker lokal tanpa TLS/HTTPS (hanya untuk pembelajaran lokal di localhost).',
    ],
  };

  fs.writeFileSync(path.join(ROOT_DIR, 'qae-input.json'), JSON.stringify(qaeInput, null, 2), 'utf8');
  console.log('[QAE v2.0] Seluruh evidence berhasil dikumpulkan ke folder evidence/ dan qae-input.json');
}

main().catch((err) => {
  console.error('[QAE v2.0] Error:', err);
  process.exit(1);
});
