'use strict';

const {build, buildClassic} = require('./godot.cjs');
if (process.argv.includes('--classic')) buildClassic();
else build();
