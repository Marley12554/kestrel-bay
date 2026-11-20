'use strict';

// Register before Godot installs its canvas listener. This UI survives loss of the GPU.
(() => {
  const canvas = document.getElementById('canvas');
  canvas.addEventListener('webglcontextlost', event => {
    event.preventDefault();
    event.stopImmediatePropagation();
    if (document.getElementById('graphics-recovery')) return;
    if (document.pointerLockElement) document.exitPointerLock();
    const panel = document.createElement('section');
    panel.id = 'graphics-recovery';
    panel.setAttribute('role', 'alertdialog');
    panel.setAttribute('aria-labelledby', 'graphics-heading');
    panel.style.cssText = 'position:fixed;inset:0;z-index:1000;background:#16272e;color:#fff4da;display:grid;place-content:center;justify-items:center;gap:1em;font:17px system-ui;text-align:center;padding:24px';
    const heading = document.createElement('h2');
    heading.id = 'graphics-heading';
    heading.textContent = 'The browser lost its graphics connection';
    const retry = document.createElement('a');
    const url = new URL(location.href);
    url.searchParams.set('graphics', 'low');
    retry.href = url.href;
    retry.textContent = 'Restart with lighter graphics';
    const classic = document.createElement('a');
    classic.href = './classic/';
    classic.textContent = 'Play Kestrel Bay Classic';
    for (const link of [retry, classic]) link.style.color = '#ffd38c';
    panel.append(heading, retry, classic);
    document.body.append(panel);
    retry.focus();
    if (typeof engine !== 'undefined') engine.requestQuit();
  }, {capture:true});
})();
