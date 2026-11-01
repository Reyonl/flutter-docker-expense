import json
import os
import sys
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC


def run_selenium_e2e(base_url: str, commit_sha: str, evidence_dir: str) -> dict:
    os.makedirs(evidence_dir, exist_ok=True)
    screenshot_rel = "evidence/EXP-007-selenium-ui.png"
    screenshot_abs = os.path.join(os.path.dirname(evidence_dir), screenshot_rel)

    options = webdriver.ChromeOptions()
    options.add_argument("--headless=new")
    options.add_argument("--window-size=1400,1050")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.set_capability("goog:loggingPrefs", {"browser": "ALL"})

    driver = webdriver.Chrome(options=options)
    driver.implicitly_wait(0)
    wait = WebDriverWait(driver, timeout=30)

    steps = []
    console_errors = []
    network_errors = []

    try:
        steps.append(f"Step 1: Open Dockerized Flutter Web Pro Dashboard at {base_url}")
        driver.get(base_url)

        steps.append("Step 2: Explicit wait for document title and Flutter root element (flutter-view / flt-glass-pane)")
        wait.until(lambda d: len(d.title) > 0)
        wait.until(
            lambda d: d.execute_script(
                "return document.querySelector('flutter-view, flt-glass-pane') !== null;"
            )
        )

        steps.append("Step 3: Verify Nginx proxy for Create, Edit (PUT), and Redis Cache (MISS -> HIT) from browser context")
        browser_api_check = driver.execute_async_script(
            """
            const done = arguments[arguments.length - 1];
            (async () => {
              try {
                // 1. Create a transaction
                const createRes = await fetch('/api/transactions', {
                  method: 'POST',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify({
                    title: 'Langganan Docker Pro (Draft)',
                    amount: 100000,
                    type: 'expense',
                    category: 'Edukasi',
                    note: 'Sebelum diedit'
                  })
                });
                const createData = await createRes.json();
                const txId = createData.item.id;

                // 2. Edit (PUT) the transaction
                const editRes = await fetch(`/api/transactions/${txId}`, {
                  method: 'PUT',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify({
                    title: 'Langganan Docker Pro & Redis (Edited)',
                    amount: 175000,
                    type: 'expense',
                    category: 'Edukasi',
                    note: 'Diverifikasi Edit + Redis Cache E2E'
                  })
                });
                const editData = await editRes.json();

                // 3. First summary fetch after PUT -> MISS, second -> HIT
                const sumMissRes = await fetch('/api/summary');
                const sumMissData = await sumMissRes.json();
                const sumHitRes = await fetch('/api/summary');
                const sumHitData = await sumHitRes.json();

                done({
                  ok: createRes.status === 201 && editRes.status === 200 && sumMissData.cacheStatus === 'MISS' && sumHitData.cacheStatus === 'HIT',
                  editedTitle: editData.item.title,
                  editedAmount: editData.item.amount,
                  firstCache: sumMissData.cacheStatus,
                  secondCache: sumHitData.cacheStatus,
                  updatedBalance: sumHitData.balance,
                  containerId: sumHitData.containerId
                });
              } catch (err) {
                done({ ok: false, error: String(err) });
              }
            })();
            """
        )

        if not browser_api_check.get("ok"):
            network_errors.append(f"Browser API check failed: {browser_api_check}")

        steps.append("Step 4: Reload Flutter Web UI so it renders with Redis Cache: HIT and Donut/Cashflow Charts")
        driver.refresh()
        wait.until(
            lambda d: d.execute_script(
                "return document.querySelector('flutter-view, flt-glass-pane') !== null && document.readyState === 'complete';"
            )
        )
        # Wait explicitly for Flutter first frame paint on canvas/scene
        wait.until(
            lambda d: d.execute_script(
                """
                const fv = document.querySelector('flutter-view, flt-glass-pane');
                return fv !== null && fv.clientHeight > 400;
                """
            )
        )
        flutter_host = wait.until(
            EC.presence_of_element_located((By.CSS_SELECTOR, "flutter-view, flt-glass-pane, body"))
        )
        dom_tag = flutter_host.tag_name

        steps.append(f"Step 5: Capture screenshot evidence to {screenshot_rel}")
        driver.save_screenshot(screenshot_abs)

        for entry in driver.get_log("browser"):
            if entry.get("level") == "SEVERE":
                msg = entry.get("message", "")
                if "favicon.ico" not in msg:
                    console_errors.append(msg)

        passed = (
            bool(browser_api_check.get("ok"))
            and len(console_errors) == 0
            and len(network_errors) == 0
            and os.path.exists(screenshot_abs)
            and os.path.getsize(screenshot_abs) > 0
        )

        report = {
            "status": "PASS" if passed else "FAIL",
            "commit_sha": commit_sha,
            "exit_code": 0 if passed else 1,
            "failures": 0 if passed else 1,
            "scenario": "EXP-007: Flutter Web v2.0 Fintech Pro Dashboard (Charts + Edit + Redis HIT/MISS) E2E",
            "steps": steps,
            "expected_result": "Flutter Web v2.0 loads at http://localhost:8080, executes Create + Edit (PUT), transitions Redis cache from MISS to HIT, and renders with 0 console/network errors.",
            "actual_result": (
                f"Flutter root <{dom_tag}> rendered; containerId={browser_api_check.get('containerId')}; "
                f"editedTitle='{browser_api_check.get('editedTitle')}'; cache={browser_api_check.get('firstCache')}->{browser_api_check.get('secondCache')}; "
                f"balance={browser_api_check.get('updatedBalance')}"
            ),
            "evidence": {
                "screenshot": screenshot_rel,
                "console_errors": console_errors,
                "network_errors": network_errors,
                "dom_state": f"Root element <{dom_tag}> active, title='{driver.title}'",
            },
            "root_cause": "N/A" if passed else "Browser console or API proxy error detected",
            "recommendation": "All E2E checks passed" if passed else "Inspect container logs",
        }
        return report
    finally:
        driver.quit()


if __name__ == "__main__":
    target_url = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8080"
    sha = sys.argv[2] if len(sys.argv) > 2 else "HEAD"
    ev_dir = sys.argv[3] if len(sys.argv) > 3 else os.path.abspath("evidence")
    result = run_selenium_e2e(target_url, sha, ev_dir)
    out_file = os.path.join(ev_dir, "EXP-007-selenium-e2e.json")
    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2)
    print(json.dumps(result, indent=2))
    sys.exit(0 if result["status"] == "PASS" else 1)
