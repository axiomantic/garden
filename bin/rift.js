#!/usr/bin/env node
const { spawnSync } = require('child_process');
const path = require('path');

function run() {
  let binScript;
  try {
    const mainEntry = require.resolve('rift-snapshot');
    const riftRoot = path.dirname(path.dirname(mainEntry));
    binScript = path.join(riftRoot, 'bin', 'rift.js');
  } catch (e) {
    console.error('Error: rift-snapshot dependency is missing or not installed.');
    console.error(e.message);
    process.exit(1);
  }

  const res = spawnSync(process.execPath, [binScript, ...process.argv.slice(2)], {
    stdio: 'inherit',
    env: process.env
  });

  if (res.error) {
    console.error(`Failed to execute rift: ${res.error.message}`);
    process.exit(1);
  }

  process.exit(res.status !== null ? res.status : (res.signal ? 1 : 0));
}

run();
