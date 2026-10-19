#!/usr/bin/env node
const { spawnSync } = require('child_process');
const path = require('path');

function run() {
  let binScript;
  try {
    const pkgJson = require.resolve('@axiomantic/vine/package.json');
    binScript = path.join(path.dirname(pkgJson), 'bin', 'run.js');
  } catch (e) {
    console.error('Error: @axiomantic/vine dependency is missing or not installed.');
    console.error(e.message);
    process.exit(1);
  }

  const res = spawnSync(process.execPath, [binScript, ...process.argv.slice(2)], {
    stdio: 'inherit',
    env: process.env
  });

  if (res.error) {
    console.error(`Failed to execute vine: ${res.error.message}`);
    process.exit(1);
  }

  process.exit(res.status !== null ? res.status : (res.signal ? 1 : 0));
}

run();
