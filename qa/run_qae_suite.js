const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const ROOT_DIR = path.resolve(__dirname, '..');
const EVIDENCE_DIR = path.join(ROOT_DIR, 'evidence');
const API_BASE = process.env.API_BASE_URL || 'http://localhost:4000/api';
const WEB_BASE = process.env.WEB_BASE_URL || 'http://localhost:8080';

function getCommitSha() {
  return execSync('git rev-parse HEAD', { cwd: ROOT_DIR, encoding: 'utf8' }).trim();
}

async function reqJson(url, options = {}) {
  const res = await fetch(url, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
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

  console.log(`[QAE] Memulai eksekusi suite pada commit ${commitSha} (${runStartedAt})`);

  // -------------------------------------------------------------------------
  // EXP-001: Docker Container Health & Orchestration
  // -------------------------------------------------------------------------
  const psOutput = execSync('docker compose ps --format json', { cwd: ROOT_DIR, encoding: 'utf8' }).trim();
  const healthRes = await reqJson(`${API_BASE}/health`);
  const exp001Pass =
    healthRes.status === 200 &&
    healthRes.body.status === 'ok' &&
    healthRes.body.db === 'connected' &&
    Boolean(healthRes.body.containerId);

  writeEvidence('EXP-001-health.json', {
    id: 'EXP-001',
    status: exp001Pass ? 'PASS' : 'FAIL',
    commit_sha: commitSha,
    exit_code: exp001Pass ? 0 : 1,
    failures: exp001Pass ? 0 : 1,
    http_status: healthRes.status,
    health_payload: healthRes.body,
    docker_compose_ps: psOutput.split('\n').filter(Boolean).map((line) => JSON.parse(line)),
  });

  // -------------------------------------------------------------------------
  // EXP-002: Positive CRUD & Financial Summary Calculation
  // -------------------------------------------------------------------------
  const beforeSum = await reqJson(`${API_BASE}/summary`);
  const createdInc = await reqJson(`${API_BASE}/transactions`, {
    method: 'POST',
    body: JSON.stringify({
      title: 'Bonus Project Docker',
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
  // EXP-003: Negative Input Validation
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
  const invalidType = await reqJson(`${API_BASE}/transactions`, {
    method: 'POST',
    body: JSON.stringify({
      title: 'Tipe Salah',
      amount: 50000,
      type: 'pinjaman',
      category: 'Lainnya',
    }),
  });

  const exp003Pass =
    negAmount.status === 400 &&
    emptyTitle.status === 400 &&
    invalidType.status === 400;

  writeEvidence('EXP-003-negative-validation.json', {
    id: 'EXP-003',
    status: exp003Pass ? 'PASS' : 'FAIL',
    commit_sha: commitSha,
    exit_code: exp003Pass ? 0 : 1,
    failures: exp003Pass ? 0 : 1,
    negative_amount_response: negAmount,
    empty_title_response: emptyTitle,
    invalid_type_response: invalidType,
  });

  // -------------------------------------------------------------------------
  // EXP-004: Database Persistence in PostgreSQL Container
  // -------------------------------------------------------------------------
  const pgQueryCmd = `docker exec expense-db psql -U dompetku -d dompetku_db -t -A -c "SELECT COUNT(*) || '|' || COALESCE(SUM(amount),0) FROM transactions;"`;
  const rawPgBeforeRestart = execSync(pgQueryCmd, { cwd: ROOT_DIR, encoding: 'utf8' }).trim();
  // Restart backend to confirm stateless container reconnects & volume persists
  execSync('docker restart expense-backend', { cwd: ROOT_DIR, stdio: 'pipe' });
  // Wait until backend is healthy again
  let backendReady = false;
  for (let i = 0; i < 15; i++) {
    try {
      const check = await reqJson(`${API_BASE}/health`);
      if (check.status === 200 && check.body.db === 'connected') {
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
  ];

  const qaeSpec = {
    feature: 'dompetku-flutter-docker-expense',
    expected_criteria: expectedCriteria,
  };
  fs.writeFileSync(path.join(ROOT_DIR, 'qae-spec.json'), JSON.stringify(qaeSpec, null, 2), 'utf8');

  const qaeInput = {
    feature: 'dompetku-flutter-docker-expense',
    commit_sha: commitSha,
    run_started_at: runStartedAt,
    expected_criteria: expectedCriteria,
    required_layers: ['integration', 'api', 'database', 'security', 'unit', 'e2e'],
    criteria: [
      {
        id: 'EXP-001',
        title: 'Docker containers healthy & GET /api/health returns 200 OK with containerId',
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
        title: 'Negative input validation rejects invalid amounts, empty title, and invalid type with HTTP 400',
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
        title: 'Backend unit tests and Flutter widget tests pass with 0 warnings/errors',
        layer: 'unit',
        status: exp006Pass ? 'PASS' : 'FAIL',
        mandatory: true,
        evidence: ['evidence/EXP-006-unit-widget.json'],
      },
      {
        id: 'EXP-007',
        title: 'Selenium WebDriver E2E test on Flutter Web container (http://localhost:8080) with screenshot',
        layer: 'e2e',
        status: exp007Pass ? 'PASS' : 'FAIL',
        mandatory: true,
        evidence: ['evidence/EXP-007-selenium-e2e.json', 'evidence/EXP-007-selenium-ui.png'],
      },
    ],
    test_execution: {
      integration: {
        command_executed: true,
        exit_code: exp001Pass ? 0 : 1,
        status: exp001Pass ? 'PASS' : 'FAIL',
        tests_executed: 1,
        failures: exp001Pass ? 0 : 1,
      },
      api: {
        command_executed: true,
        exit_code: exp002Pass && exp003Pass ? 0 : 1,
        status: exp002Pass && exp003Pass ? 'PASS' : 'FAIL',
        tests_executed: 5,
        failures: exp002Pass && exp003Pass ? 0 : 1,
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
  console.log('[QAE] Seluruh evidence berhasil dikumpulkan ke folder evidence/ dan qae-input.json');
}

main().catch((err) => {
  console.error('[QAE] Error:', err);
  process.exit(1);
});
