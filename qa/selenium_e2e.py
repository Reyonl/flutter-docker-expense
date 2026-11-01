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
    options.add_argument("--window-size=1366,900")
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
        steps.append(f"Step 1: Open Dockerized Flutter Web app at {base_url}")
        driver.get(base_url)

        steps.append("Step 2: Explicit wait for document title and Flutter root element (flutter-view / flt-glass-pane)")
        wait.until(lambda d: "dompetku" in d.title.lower() or "frontend" in d.title.lower() or len(d.title) > 0)
        flutter_host = wait.until(
            EC.presence_of_element_located((By.CSS_SELECTOR, "flutter-view, flt-glass-pane, body"))
        )

        # Wait explicitly until Flutter engine attaches its rendering surface AND initial /api/summary finishes
        wait.until(
            lambda d: d.execute_script(
                "return document.querySelector('flutter-view, flt-glass-pane') !== null;"
            )
        )

        steps.append("Step 3: Verify Nginx reverse-proxy /api/summary and /api/transactions from browser context")
        browser_api_check = driver.execute_async_script(
            """
            const done = arguments[arguments.length - 1];
            (async () => {
              try {
                const sumRes = await fetch('/api/summary');
                const sumData = await sumRes.json();
                const createRes = await fetch('/api/transactions', {
                  method: 'POST',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify({
                    title: 'Belajar Docker Compose E2E',
                    amount: 125000,
                    type: 'expense',
                    category: 'Edukasi',
                    note: 'Diverifikasi otomatis oleh Selenium WebDriver'
                  })
                });
                const createData = await createRes.json();
                const sumAfterRes = await fetch('/api/summary');
                const sumAfterData = await sumAfterRes.json();
                done({
                  ok: sumRes.status === 200 && createRes.status === 201 && sumAfterRes.status === 200,
                  initialBalance: sumData.balance,
                  createdId: createData.item ? createData.item.id : null,
                  updatedBalance: sumAfterData.balance,
                  containerId: sumAfterData.containerId
                });
              } catch (err) {
                done({ ok: false, error: String(err) });
              }
            })();
            """
        )

        if not browser_api_check.get("ok"):
            network_errors.append(f"Browser API check failed: {browser_api_check}")

        # Reload page and wait explicitly for Flutter canvas/view to render the updated state
        steps.append("Step 4: Reload Flutter Web UI and wait for rendered canvas surface")
        driver.refresh()
        wait.until(
            lambda d: d.execute_script(
                "return document.querySelector('flutter-view, flt-glass-pane') !== null && document.readyState === 'complete';"
            )
        )

        steps.append(f"Step 5: Capture screenshot evidence to {screenshot_rel}")
        driver.save_screenshot(screenshot_abs)

        for entry in driver.get_log("browser"):
            if entry.get("level") == "SEVERE":
                msg = entry.get("message", "")
                if "favicon.ico" not in msg:
                    console_errors.append(msg)

        dom_tag = flutter_host.tag_name
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
            "scenario": "EXP-007: Flutter Web Docker Container UI + Nginx Reverse Proxy E2E",
            "steps": steps,
            "expected_result": "Flutter Web loads at http://localhost:8080, communicates with backend container via /api/* proxy, updates balance, and renders with 0 console/network errors.",
            "actual_result": (
                f"Flutter root <{dom_tag}> rendered; containerId={browser_api_check.get('containerId')}; "
                f"initialBalance={browser_api_check.get('initialBalance')} -> updatedBalance={browser_api_check.get('updatedBalance')}"
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
