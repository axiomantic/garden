const { spawnSync } = require('child_process');
const path = require('path');
const assert = require('assert');

console.log('[Suite] Garden Bin Riders Execution Suite');

// Test 1: rhizo runner
const rhizoBin = path.join(__dirname, '..', 'bin', 'rhizo.js');
const resRhizo = spawnSync(process.execPath, [rhizoBin, '--version'], { encoding: 'utf-8' });
assert.strictEqual(resRhizo.status, 0, `rhizo.js exited with ${resRhizo.status}: ${resRhizo.stderr}`);
assert(resRhizo.stdout.includes('rhizo'), `rhizo.js output unexpected: ${resRhizo.stdout}`);
console.log('  [OK] bin/rhizo.js successfully executes @axiomantic/rhizo');

// Test 2: vine runner
const vineBin = path.join(__dirname, '..', 'bin', 'vine.js');
const resVine = spawnSync(process.execPath, [vineBin, '--version'], { encoding: 'utf-8' });
assert.strictEqual(resVine.status, 0, `vine.js exited with ${resVine.status}: ${resVine.stderr}`);
assert(resVine.stdout.includes('vine'), `vine.js output unexpected: ${resVine.stdout}`);
console.log('  [OK] bin/vine.js successfully executes @axiomantic/vine');

// Test 3: rift runner
const riftBin = path.join(__dirname, '..', 'bin', 'rift.js');
const resRift = spawnSync(process.execPath, [riftBin, '--help'], { encoding: 'utf-8' });
assert.strictEqual(resRift.status, 0, `rift.js exited with ${resRift.status}: ${resRift.stderr}`);
assert(resRift.stdout.includes('rift'), `rift.js output unexpected: ${resRift.stdout}`);
console.log('  [OK] bin/rift.js successfully executes rift-snapshot');

console.log('All bin rider tests passed successfully.');
