#!/usr/bin/env bash
set -euo pipefail

OUTPUT_PATH="${1:-docs/screenshots/grafana-normal.png}"
TIME_RANGE="${TIME_RANGE:-now-15m}"
DASHBOARD_UID="${DASHBOARD_UID:-incident-lab-podinfo}"
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-admin}"
TMP_PW_DIR="${TMPDIR:-/tmp}/k8s-incident-lab-pw"

if ! command -v node >/dev/null 2>&1; then
  echo "node is required."
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "npm is required."
  exit 1
fi

if ! command -v google-chrome >/dev/null 2>&1; then
  echo "google-chrome is required."
  exit 1
fi

mkdir -p "${TMP_PW_DIR}"

if [ ! -d "${TMP_PW_DIR}/node_modules/playwright-core" ]; then
  echo "Installing temporary playwright-core into ${TMP_PW_DIR} ..."
  (
    cd "${TMP_PW_DIR}"
    npm init -y >/dev/null 2>&1 || true
    npm install playwright-core@1.59.1 >/dev/null
  )
fi

mkdir -p "$(dirname "${OUTPUT_PATH}")"

NODE_PATH="${TMP_PW_DIR}/node_modules" \
OUTPUT_PATH="${OUTPUT_PATH}" \
TIME_RANGE="${TIME_RANGE}" \
DASHBOARD_UID="${DASHBOARD_UID}" \
GRAFANA_URL="${GRAFANA_URL}" \
GRAFANA_USER="${GRAFANA_USER}" \
GRAFANA_PASSWORD="${GRAFANA_PASSWORD}" \
node <<'NODE'
const { chromium } = require('playwright-core');

async function main() {
  const browser = await chromium.launch({
    executablePath: '/usr/bin/google-chrome',
    headless: true,
    args: ['--no-sandbox'],
  });

  const page = await browser.newPage({ viewport: { width: 1600, height: 1200 } });
  const base = process.env.GRAFANA_URL;
  const uid = process.env.DASHBOARD_UID;
  const from = process.env.TIME_RANGE;
  const out = process.env.OUTPUT_PATH;

  await page.goto(`${base}/login`, { waitUntil: 'networkidle' });

  if (await page.locator('input[name="user"]').count()) {
    await page.fill('input[name="user"]', process.env.GRAFANA_USER);
    await page.fill('input[name="password"]', process.env.GRAFANA_PASSWORD);
    await page.click('button[type="submit"]');
    await page.waitForLoadState('networkidle');
  }

  await page.goto(
    `${base}/d/${uid}/${uid}?orgId=1&from=${from}&to=now&refresh=15s&kiosk`,
    { waitUntil: 'networkidle' }
  );

  await page.waitForTimeout(10000);
  await page.locator('main').first().screenshot({ path: out });
  await browser.close();
  console.log(`Saved screenshot to ${out}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
NODE
