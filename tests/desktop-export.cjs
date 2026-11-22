'use strict';

// Exercise the shipping executable and its pack together, including the city data.
const {spawnSync} = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const executable = path.resolve(process.argv[2]);
const log = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'kestrel-desktop-')), 'game.log');
const result = spawnSync(executable, ['--headless', '--fixed-fps', '60', '--quit-after', '240', '--log-file', log], {
  encoding: 'utf8', timeout: 180_000,
});
if (result.error) throw result.error;
const output = fs.existsSync(log) ? fs.readFileSync(log, 'utf8') : '';
if (result.status !== 0 || !/GODOT_PROTOTYPE_READY vehicles=[1-9]/.test(output) ||
    !output.includes('LIGHTING_WARMUP_COMPLETE') || /SCRIPT ERROR:|^ERROR:/m.test(output)) {
  throw Error('Packaged city failed to start.\n' + output + '\n' + result.stderr);
}
console.log(output.trim());
