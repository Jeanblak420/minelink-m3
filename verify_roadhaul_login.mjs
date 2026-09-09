import { chromium } from 'playwright-core';

const chromePath = 'C:/Users/Somebody Someone/AppData/Local/ms-playwright/chromium-1234/chrome-win64/chrome.exe';
const browser = await chromium.launch({
  headless: true,
  executablePath: chromePath,
  args: [
    '--no-sandbox',
    '--disable-setuid-sandbox',
    '--disable-dev-shm-usage',
    '--disable-web-security',
    '--disable-background-networking',
    '--no-first-run',
    '--no-default-browser-check',
  ],
});
const context = await browser.newContext({
  viewport: { width: 1280, height: 800 },
  javaScriptEnabled: true,
});
const page = await context.newPage();

const errors = [];
const consoleMsgs = [];
page.on('console', msg => {
  const text = '[' + msg.type() + '] ' + msg.text();
  consoleMsgs.push(text);
  if (msg.type() === 'error') errors.push(msg.text());
});
page.on('pageerror', err => errors.push(String(err)));

console.log('1. Navigating to http://localhost:61783...');
await page.goto('http://localhost:61783', { waitUntil: 'networkidle', timeout: 60000 });

// Wait for Flutter to render the form
console.log('2. Waiting for form to render (checking every 5s up to 90s)...');
let formReady = false;
for (let waitSec = 0; waitSec <= 90; waitSec += 5) {
  await page.waitForTimeout(5000);

  const state = await page.evaluate(() => {
    const inputs = document.querySelectorAll('input');
    const types = [];
    inputs.forEach(i => types.push(i.type));
    return {
      count: inputs.length,
      types: types,
      hasEmail: types.includes('text'),
      hasPassword: types.includes('password'),
      hasSubmit: types.includes('submit'),
    };
  });

  console.log('  Waited ' + (waitSec + 5) + 's: inputs=' + state.count + ' types=[' + state.types.join(',') + ']');

  if (state.hasEmail && state.hasPassword && state.hasSubmit) {
    formReady = true;
    console.log('  FORM READY!');
    break;
  }
}

console.log('Form ready: ' + formReady);
await page.screenshot({ path: 'c:/Users/Somebody Someone/Music/SHOWME!/MineLink-M3/login_page.png', fullPage: true });

console.log('=== LAST 10 CONSOLE MESSAGES ===');
consoleMsgs.slice(-10).forEach(m => console.log(m));

// Fill form using Playwright locators
if (formReady) {
  console.log('=== Filling form ===');
  const emailInput = page.locator('input[type="text"]');
  await emailInput.first().fill('roadhaul.owner@mineralguide.com', { timeout: 10000 });
  console.log('Email filled');
  await page.waitForTimeout(3000);

  const pwdInput = page.locator('input[type="password"]');
  await pwdInput.first().fill('MineralGuide123!', { timeout: 10000 });
  console.log('Password filled');

  const submit = page.locator('input[type="submit"]');
  console.log('Clicking submit...');
  await submit.first().click({ timeout: 10000 });
  console.log('Submit clicked, waiting 25s...');
  await page.waitForTimeout(25000);

  await page.screenshot({ path: 'c:/Users/Somebody Someone/Music/SHOWME!/MineLink-M3/after_login.png', fullPage: true });

  // Check for errors
  const afterConsole = consoleMsgs.slice(-50);
  const errorMsgs = afterConsole.filter(m =>
    m.toLowerCase().includes('error') ||
    m.toLowerCase().includes('exception') ||
    m.toLowerCase().includes('subtype')
  );
  console.log('=== Error-related messages after login ===');
  if (errorMsgs.length > 0) {
    errorMsgs.forEach(m => console.log(m));
  } else {
    console.log('NONE - no errors detected!');
  }

  const bodyText = await page.evaluate(() => {
    return (document.body.innerText || document.body.textContent || '');
  });
  const hasWorkspaceError = bodyText.includes('Error loading workspace');
  console.log('Page contains "Error loading workspace": ' + hasWorkspaceError);

  console.log('=== FINAL CONSOLE (last 30) ===');
  consoleMsgs.slice(-30).forEach(m => console.log(m));
} else {
  console.log('Form did not fully render within timeout');
  console.log('=== ALL CONSOLE MESSAGES ===');
  consoleMsgs.forEach(m => console.log(m));
}

await browser.close();
console.log('Done');
