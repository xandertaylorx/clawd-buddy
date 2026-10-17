/* Clawd site: the live crab, download button, copy buttons, tabs, reveals.
   The sprite is a direct port of the app's drawing code: everything is filled rectangles. */
(() => {
  'use strict';

  const OR = '#d97757', DARK = '#b86143', LIGHT = '#f59e7a', INK = '#1a1210';
  const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const $ = (s, el = document) => el.querySelector(s);
  const $$ = (s, el = document) => [...el.querySelectorAll(s)];
  const rand = (a, b) => a + Math.random() * (b - a);
  const pick = a => a[Math.floor(Math.random() * a.length)];
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

  /* ---------------------------------------------------------------- sprite */
  const P = (o = {}) => Object.assign({ eyes: 'open', eyeShift: 0, eyeLift: 0, armL: 0, armR: 0, legs: 0, bob: 0, squash: false,
                                       ball: false, ballStep: 0, ballSquash: 0 }, o);

  // origin (ox, oyb): left edge and bottom edge of the sprite's 15x14 pixel canvas, in CSS px
  function drawClawd(ctx, p, U, ox, oyb) {
    const R = (x, y, w, h, c) => { ctx.fillStyle = c; ctx.fillRect(Math.round(ox + x * U), Math.round(oyb - (y + h) * U), w * U, h * U); };
    if (p.ball) {
      const cx = 7.5, cy = 7, th = p.ballStep * Math.PI / 16;
      const rx = p.ballSquash === 2 ? 5.3 : p.ballSquash === 1 ? 7 : 6.4;
      const ry = p.ballSquash === 1 ? 5.3 : p.ballSquash === 2 ? 7 : 6.4;
      for (let row = -7; row <= 6; row++) {
        const n = (row + 0.5) / ry;
        if (Math.abs(n) >= 1) continue;
        const hw = rx * Math.sqrt(1 - n * n);
        const x0 = Math.round(cx - hw), x1 = Math.round(cx + hw);
        if (x1 > x0) R(x0, 7 + row, x1 - x0, 1, row <= -5 ? DARK : OR);
      }
      R(Math.trunc(cx - 3), 11, 2, 1, LIGHT);
      for (let k = 0; k < 4; k++) {
        const a = th + k * Math.PI / 2;
        R(Math.round(cx + Math.cos(a) * (rx - 0.6) - 1), Math.round(cy + Math.sin(a) * (ry - 0.6) - 1), 2, 2, DARK);
      }
      const phi = th + Math.PI / 2, fx = cx + Math.cos(phi) * 2.6, fy = cy + Math.sin(phi) * 2.6;
      for (const s of [-1, 1]) R(Math.round(fx - Math.sin(phi) * 1.7 * s), Math.round(fy + Math.cos(phi) * 1.7 * s - 1), 1, 2, INK);
      return;
    }
    const sq = p.squash ? 1 : 0, b = 2 - sq + (p.squash ? 0 : p.bob), bodyH = 6 - sq;
    [3, 5, 9, 11].forEach((x, i) => {
      const lifted = (p.legs === 1 && (i === 0 || i === 3)) || (p.legs === 2 && (i === 1 || i === 2));
      if (p.squash) { if (!lifted) R(x, 0, 1, 1, OR); }
      else if (lifted) R(x, 1, 1, 1, OR);
      else R(x, 0, 1, 2, OR);
    });
    R(2, b, 11, bodyH, OR);
    R(0, b + 1 + p.armL, 2, 2, OR);
    R(13, b + 1 + p.armR, 2, 2, OR);
    if (p.armL > 1) R(1, b + 1, 1, p.armL + 2, OR);
    if (p.armR > 1) R(13, b + 1, 1, p.armR + 2, OR);
    const ey = b + 2 + p.eyeLift;
    for (const ex of [4 + p.eyeShift, 10 + p.eyeShift]) {
      switch (p.eyes) {
        case 'open': R(ex, ey, 1, 2, INK); break;
        case 'blink': R(ex, ey, 1, 1, INK); break;
        case 'wide': R(ex, ey, 2, 3, INK); break;
        case 'happy': R(ex - 1, ey, 1, 1, INK); R(ex, ey + 1, 1, 1, INK); R(ex + 1, ey, 1, 1, INK); break;
        case 'sleep': R(ex - 1, ey, 3, 1, INK); break;
      }
    }
  }

  // little logos
  for (const id of ['logo', 'logo2']) {
    const c = document.getElementById(id);
    if (c) drawClawd(c.getContext('2d'), P({ eyes: 'open', armR: 0 }), 2, 0, 28);
  }

  /* ------------------------------------------------------------------- pet */
  const U = 4, PAD = 4, CW = 15 * U + PAD * 2, CH = 14 * U + PAD * 2;
  const canvas = $('#pet'), bubbleEl = $('#bubble');
  if (!canvas) return;
  const dpr = Math.min(devicePixelRatio || 1, 3);
  canvas.width = CW * dpr; canvas.height = CH * dpr;
  const ctx = canvas.getContext('2d');
  ctx.scale(dpr, dpr);
  ctx.imageSmoothingEnabled = false;

  const BR = 6.4 * U;      // ball radius
  const G = 1500;          // gravity, px/s²
  const WORDS = ['✻ Pondering…', '✻ Flibbertigibbeting…', '✻ Percolating…', "You're absolutely right!", 'Let me take a look at that.',
                 'Psst. Click me.', 'Drag me anywhere!', 'Try throwing me!', 'Have you tried the ball button?', 'Tests are passing. Probably.',
                 'Ship it!', 'I live in your menu bar, too.', '*scuttles*', 'Download me, I dare you.', 'Hi! I\'m Clawd.'];

  const pet = { x: rand(120, innerWidth - 120), y: -90, vx: 0, vy: 0, mode: 'fall', act: 'idle', t: 0, dur: 2, dir: 1,
                blinkIn: 2.5, blinkLeft: 0, perch: null, hop: null, squashT: 0, pose: P(), hidden: false, nextPerch: 25, speakIn: 5 };
  const ball = { x: 0, y: 0, vx: 0, vy: 0, angle: 0, spin: 0, squash: 0, squashT: 0, held: false, last: { x: 0, y: 0 }, vest: { x: 0, y: 0 }, lastClick: 0 };
  const mouse = { x: innerWidth / 2, y: innerHeight / 2 };
  const drag = { on: false, ox: 0, oy: 0, moved: 0, sx: 0, sy: 0, samples: [] };
  const bub = { text: '', shown: 0, until: 0, active: false };
  let platforms = [], lastScroll = scrollY, scrollDelta = 0;

  addEventListener('pointermove', e => { mouse.x = e.clientX; mouse.y = e.clientY; }, { passive: true });
  addEventListener('scroll', () => { scrollDelta += scrollY - lastScroll; lastScroll = scrollY; }, { passive: true });

  function say(text, hold = 3.2) {
    bub.text = text; bub.shown = 0; bub.until = performance.now() / 1000 + hold + text.length / 35; bub.active = true;
    bubbleEl.style.visibility = 'hidden';
    bubbleEl.hidden = false;
  }

  function visiblePerches() {
    const out = [];
    for (const el of $$('[data-perch]')) {
      const r = el.getBoundingClientRect();
      if (r.width > 120 && r.top > 170 && r.top < innerHeight - 70 && r.bottom > 0) out.push({ el, left: r.left, right: r.right, top: r.top });
    }
    return out;
  }

  function ground() {
    if (pet.perch) {
      const r = pet.perch.getBoundingClientRect();
      return r.top;
    }
    return innerHeight - 4;
  }

  function perchValid() {
    if (!pet.perch || !pet.perch.isConnected) return false;
    const r = pet.perch.getBoundingClientRect();
    return r.top > 120 && r.top < innerHeight - 56 && r.width > 100;
  }

  function startAct(a) {
    pet.act = a; pet.t = 0;
    switch (a) {
      case 'idle': pet.dur = rand(1.5, 4); break;
      case 'walk': pet.dur = rand(2, 6); pet.dir = Math.random() < .5 ? -1 : 1; break;
      case 'look': pet.dur = 2.4; break;
      case 'wave': pet.dur = 1.8; if (Math.random() < .6) say(pick(['Hi!', 'Hello!', 'Hey you!', 'o/']), 1.6); break;
      case 'jump': pet.dur = .7; pet.jumpH = rand(34, 56); break;
      case 'dance': pet.dur = 2.6; say('♪ ♫ ♪', 2); break;
      case 'sleep': pet.dur = rand(7, 12); pet.zStep = -1; break;
    }
  }
  function pickNext() {
    const r = Math.random() * 100;
    if (r < 26) startAct('idle'); else if (r < 56) startAct('walk'); else if (r < 66) startAct('look');
    else if (r < 74) startAct('wave'); else if (r < 84) startAct('jump'); else if (r < 90) startAct('dance'); else startAct('sleep');
  }
  startAct('idle');

  function hopTo(target) {
    pet.hop = { fx: pet.x, fy: pet.y, tx: clamp(rand(target.left + 40, target.right - 40), 30, innerWidth - 30), ty: target.top,
                t: 0, dur: 0.8, el: target.el };
    pet.mode = 'hop'; pet.perch = null;
  }
  function tryPerch() {
    const ps = platforms.filter(p => p.el !== pet.perch);
    if (!ps.length) { say('Nothing up here to climb.', 2); return; }
    hopTo(pick(ps));
  }

  function updatePet(dt, now) {
    const p = P();
    let jumpY = 0;
    pet.t += dt;

    if (pet.mode === 'pet') {
      if (pet.perch && !perchValid()) { pet.perch = null; pet.mode = 'fall'; pet.vy = 0; }
      pet.y = ground();
      if (!reduceMotion) {
        if (pet.t >= pet.dur) pickNext();
        pet.nextPerch -= dt;
        if (pet.nextPerch <= 0 && pet.act !== 'sleep') {
          pet.nextPerch = rand(25, 55);
          if (pet.perch) { pet.perch = null; pet.mode = 'fall'; pet.vy = -260; }   // hop back down
          else tryPerch();
        }
        pet.speakIn -= dt;
        if (pet.speakIn <= 0 && pet.act !== 'sleep' && !bub.active) { pet.speakIn = rand(9, 20); say(pick(WORDS)); }
      }
      const lo = pet.perch ? pet.perch.getBoundingClientRect().left + 30 : 30;
      const hi = pet.perch ? pet.perch.getBoundingClientRect().right - 30 : innerWidth - 30;
      switch (pet.act) {
        case 'idle': p.bob = Math.floor(pet.t / .8) % 2;
          p.eyeShift = clamp(Math.round((mouse.x - pet.x) / 160), -1, 1); p.eyeLift = mouse.y < pet.y - 240 ? 1 : 0; break;
        case 'walk': { const s = Math.floor(pet.t / .16); p.legs = s % 2 ? 2 : 1; p.bob = s % 2; p.eyeShift = pet.dir;
          pet.x += pet.dir * 58 * dt; if (pet.x < lo) { pet.x = lo; pet.dir = 1; } if (pet.x > hi) { pet.x = hi; pet.dir = -1; } break; }
        case 'look': p.eyeShift = [-1, -1, 0, 1, 1, 0][Math.min(5, Math.floor(pet.t / .4))]; break;
        case 'wave': p.eyes = 'happy'; p.armR = Math.floor(pet.t / .18) % 2 ? 3 : 5; break;
        case 'jump': { const u = Math.min(1, pet.t / pet.dur); jumpY = 4 * pet.jumpH * u * (1 - u);
          if (u < .1 || u > .9) p.squash = true; else { p.armL = 3; p.armR = 3; p.eyes = 'happy'; } break; }
        case 'dance': { const s = Math.floor(pet.t / .22), ev = s % 2 === 0; p.eyes = 'happy'; p.armL = ev ? 5 : 1; p.armR = ev ? 1 : 5; p.bob = s % 2; p.legs = ev ? 1 : 2; break; }
        case 'sleep': { p.eyes = 'sleep'; p.squash = true; const z = Math.floor(pet.t / 1.2) % 3;
          if (z !== pet.zStep) { pet.zStep = z; say(['z', 'zZ', 'zZz'][z], 1.3); } break; }
      }
      if (!reduceMotion) {
        if (pet.blinkLeft > 0) pet.blinkLeft -= dt; else { pet.blinkIn -= dt; if (pet.blinkIn <= 0) { pet.blinkLeft = .13; pet.blinkIn = rand(2, 5); } }
        if (pet.blinkLeft > 0 && p.eyes === 'open') p.eyes = 'blink';
      }
      if (pet.squashT > 0) { pet.squashT -= dt; p.squash = true; }
      pet.y -= jumpY;
    } else if (pet.mode === 'hop') {
      const h = pet.hop; h.t += dt;
      const u = Math.min(1, h.t / h.dur);
      const r = h.el.getBoundingClientRect(); h.ty = r.top;
      pet.x = h.fx + (h.tx - h.fx) * u;
      pet.y = h.fy + (h.ty - h.fy) * u - 90 * 4 * u * (1 - u);
      p.eyes = 'happy'; p.armL = 3; p.armR = 3; p.squash = u < .08 || u > .94;
      if (u >= 1) { pet.perch = h.el; pet.mode = 'pet'; pet.y = h.ty; startAct('idle'); pet.nextPerch = rand(10, 20); say(pick(['Nice view up here.', 'King of the card!', "Don't mind me."]), 2.4); }
    } else if (pet.mode === 'fall') {
      const prevY = pet.y;
      pet.vy += G * dt; pet.y += pet.vy * dt; pet.x += pet.vx * dt; pet.vx *= 1 - 1.6 * dt;
      pet.x = clamp(pet.x, 30, innerWidth - 30);
      p.eyes = 'wide'; p.armL = 4; p.armR = 4; p.legs = Math.floor(now * 8) % 2 + 1;
      let landed = null;
      if (pet.vy >= 0) for (const pl of platforms) {
        if (prevY <= pl.top + 3 && pet.y >= pl.top && pet.x > pl.left + 8 && pet.x < pl.right - 8) { landed = pl; break; }
      }
      const floor = innerHeight - 4;
      if (landed || pet.y >= floor) {
        const hard = pet.vy > 520;
        pet.perch = landed ? landed.el : null;
        pet.y = landed ? landed.top : floor; pet.vy = 0; pet.vx = 0; pet.mode = 'pet';
        if (hard) pet.squashT = .2;
        startAct('idle'); pet.t = 0;
      }
    } else if (pet.mode === 'drag') {
      p.eyes = 'wide'; const s = Math.floor(now * 7); p.legs = s % 2 ? 2 : 1; p.armL = s % 2; p.armR = (s + 1) % 2;
    } else if (pet.mode === 'ball') {
      updateBall(dt);
    }
    pet.pose = p;
  }

  function updateBall(dt) {
    const b = ball;
    const tol = Math.abs(scrollDelta) + 6;
    scrollDelta = 0;
    let resting = false;
    if (b.held) {
      b.vx = 0; b.vy = 0;
    } else {
      const steps = 3, h = dt / steps;
      let onSurface = false;
      for (let i = 0; i < steps; i++) {
        const prevBottom = b.y + BR;
        b.vy += G * h; b.vx *= 1 - .03 * h; b.x += b.vx * h; b.y += b.vy * h;
        const floor = innerHeight - 2 - BR;
        if (b.y > floor) { b.y = floor; if (b.vy > 0) { hit(b.vy, 1); b.vy = b.vy > 120 ? -b.vy * .72 : 0; } onSurface = true; }
        if (b.y < BR) { b.y = BR; if (b.vy < 0) b.vy = -b.vy * .6; }
        if (b.x < BR) { b.x = BR; if (b.vx < 0) { hit(-b.vx, 2); b.spin += b.vy / BR * .3; b.vx = -b.vx * .75; } }
        if (b.x > innerWidth - BR) { b.x = innerWidth - BR; if (b.vx > 0) { hit(b.vx, 2); b.spin -= b.vy / BR * .3; b.vx = -b.vx * .75; } }
        if (b.vy >= 0) for (const pl of platforms) {
          const top = pl.top, bottom = b.y + BR;
          if (b.x > pl.left - 6 && b.x < pl.right + 6 && prevBottom <= top + tol && bottom >= top && bottom <= top + 30 + tol) {
            b.y = top - BR; hit(b.vy, 1); b.vy = b.vy > 120 ? -b.vy * .72 : 0; onSurface = true; break;
          }
        }
      }
      if (onSurface && Math.abs(b.vy) < 8) {
        b.vx *= Math.exp(-.35 * dt); b.angle -= b.vx / BR * dt; b.spin = -b.vx / BR;
        if (Math.abs(b.vx) < 5) { b.vx = 0; resting = true; }
      } else { b.angle += b.spin * dt; b.spin *= 1 - .08 * dt; }
    }
    if (resting) {   // sit there and look at the cursor
      const want = Math.atan2(-(mouse.y - b.y), mouse.x - b.x) - Math.PI / 2;
      let d = (want - b.angle) % (2 * Math.PI); if (d > Math.PI) d -= 2 * Math.PI; if (d < -Math.PI) d += 2 * Math.PI;
      b.angle += d * Math.min(1, dt * 5);
    }
    if (b.squashT > 0) b.squashT -= dt;
    pet.pose = P({ ball: true, ballStep: ((Math.round(b.angle / (Math.PI / 16)) % 32) + 32) % 32, ballSquash: b.squashT > 0 ? b.squash : 0 });
  }
  function hit(speed, axis) { if (speed > 220) { ball.squash = axis; ball.squashT = .13; } }

  function setBall(on) {
    const btn = $('[data-act="ball"]');
    if (on && pet.mode !== 'ball') {
      ball.x = pet.x; ball.y = pet.y - BR; ball.vx = 0; ball.vy = -420; ball.angle = 0; ball.spin = 0; ball.held = false;
      pet.mode = 'ball'; pet.perch = null; ball.squash = 1; ball.squashT = .2;
      say('Wheee! Grab me and throw me. Double-click to unroll.', 3.5);
    } else if (!on && pet.mode === 'ball') {
      pet.x = ball.x; pet.y = ball.y + BR; pet.vy = 0; pet.vx = 0; pet.mode = 'fall'; startAct('idle');
      say('Phew, unrolled.', 2);
    }
    if (btn) { btn.setAttribute('aria-pressed', pet.mode === 'ball'); btn.textContent = pet.mode === 'ball' ? 'Unroll him' : 'Roll into a ball'; }
  }

  /* ---- drag / throw ---- */
  canvas.addEventListener('pointerdown', e => {
    canvas.setPointerCapture(e.pointerId);
    drag.on = true; drag.moved = 0; drag.sx = e.clientX; drag.sy = e.clientY; drag.samples = [{ t: performance.now(), x: e.clientX, y: e.clientY }];
    if (pet.mode === 'ball') { drag.ox = ball.x - e.clientX; drag.oy = ball.y - e.clientY; }
    else { drag.ox = pet.x - e.clientX; drag.oy = pet.y - e.clientY; }
    e.preventDefault();
  });
  canvas.addEventListener('pointermove', e => {
    if (!drag.on) return;
    drag.moved = Math.max(drag.moved, Math.hypot(e.clientX - drag.sx, e.clientY - drag.sy));
    const now = performance.now();
    drag.samples.push({ t: now, x: e.clientX, y: e.clientY });
    while (drag.samples.length > 2 && now - drag.samples[0].t > 90) drag.samples.shift();
    if (drag.moved < 5) return;
    canvas.classList.add('dragging');
    if (pet.mode === 'ball') { ball.held = true; ball.x = e.clientX + drag.ox; ball.y = e.clientY + drag.oy; }
    else { pet.mode = 'drag'; pet.perch = null; pet.x = e.clientX + drag.ox; pet.y = e.clientY + drag.oy; bub.active = false; bubbleEl.hidden = true; }
  });
  function release() {
    if (!drag.on) return;
    drag.on = false; canvas.classList.remove('dragging');
    const s = drag.samples, a = s[0], z = s[s.length - 1];
    let vx = 0, vy = 0;
    if (s.length > 1 && z.t > a.t) { vx = (z.x - a.x) / ((z.t - a.t) / 1000); vy = (z.y - a.y) / ((z.t - a.t) / 1000); }
    const sp = Math.hypot(vx, vy), cap = 2600;
    if (sp > cap) { vx *= cap / sp; vy *= cap / sp; }
    if (drag.moved < 5) {   // a click
      const t = performance.now();
      if (pet.mode === 'ball') { if (t - ball.lastClick < 400) setBall(false); else ball.vy = -560; ball.lastClick = t; }
      else if (t - ball.lastClick < 400) setBall(true);
      else { ball.lastClick = t; startAct('jump'); say(pick(WORDS)); }
      return;
    }
    if (pet.mode === 'ball') { ball.held = false; ball.vx = sp < 100 ? 0 : vx; ball.vy = sp < 100 ? 0 : vy; ball.spin = -ball.vx / BR * .7; }
    else { pet.mode = 'fall'; pet.vx = vx * .35; pet.vy = vy * .35; }
  }
  canvas.addEventListener('pointerup', release);
  canvas.addEventListener('pointercancel', release);

  /* ---- render loop ---- */
  let last = performance.now();
  function frame(nowMs) {
    const now = nowMs / 1000, dt = Math.min(0.05, (nowMs - last) / 1000); last = nowMs;
    if (!pet.hidden && !document.hidden) {
      platforms = visiblePerches();
      updatePet(dt, now);
      // draw
      ctx.clearRect(0, 0, CW, CH);
      drawClawd(ctx, pet.pose, U, PAD, CH - PAD);
      const ball_ = pet.mode === 'ball';
      const cx = ball_ ? ball.x : pet.x;
      const left = Math.round(cx - (PAD + 7.5 * U));
      const top = Math.round(ball_ ? ball.y - (CH - PAD - 7 * U) : pet.y - (CH - PAD));
      canvas.style.transform = `translate(${left}px, ${top}px)`;
      // bubble
      if (bub.active) {
        if (now > bub.until) { bub.active = false; bubbleEl.hidden = true; }
        else {
          bub.shown = Math.min(bub.text.length, bub.shown + dt * 38);
          bubbleEl.textContent = bub.text.slice(0, Math.floor(bub.shown)) || '​';
          const bw = bubbleEl.offsetWidth, bh = bubbleEl.offsetHeight;
          const bl = clamp(cx - bw / 2, 8, innerWidth - bw - 8);
          bubbleEl.style.setProperty('--tail', clamp(cx - bl, 14, bw - 14) + 'px');
          bubbleEl.style.transform = `translate(${Math.round(bl)}px, ${Math.round(Math.max(8, top - bh - 10))}px)`;
          bubbleEl.style.visibility = 'visible';
        }
      }
    }
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);

  window.__clawd = { pet, ball, say, setBall, startAct };

  /* ---- buttons that boss him around ---- */
  $$('[data-act]').forEach(btn => btn.addEventListener('click', () => {
    const a = btn.dataset.act;
    if (a === 'ball') { setBall(pet.mode !== 'ball'); return; }
    if (pet.hidden) return;
    if (pet.mode === 'ball') setBall(false);
    if (pet.mode !== 'pet' && pet.mode !== 'fall') return;
    pet.mode = pet.mode === 'fall' ? 'fall' : 'pet';
    if (a === 'talk') { say(pick(WORDS)); return; }
    if (a === 'perch') { tryPerch(); return; }
    startAct(a);
    if (a === 'sleep') pet.dur = 6;
  }));

  const hideBtn = $('#hide-pet');
  if (hideBtn) hideBtn.addEventListener('click', () => {
    pet.hidden = !pet.hidden; canvas.hidden = pet.hidden; bubbleEl.hidden = true; bub.active = false;
    hideBtn.textContent = pet.hidden ? 'Bring back the crab' : 'Hide the crab';
  });

  setTimeout(() => say(pick(['Hi! I\'m Clawd.', 'Psst. Click me.', 'Hello! Drag me around.']), 3.5), 2200);

  /* ------------------------------------------------------------- the rest */
  // nav shadow
  const nav = $('.nav');
  const onScroll = () => nav.classList.toggle('scrolled', scrollY > 8);
  addEventListener('scroll', onScroll, { passive: true }); onScroll();

  // reveal on scroll (a plain scroll check is more reliable than IntersectionObserver across embedded browsers)
  let pending = $$('.reveal');
  function reveal() {
    pending = pending.filter(el => {
      const r = el.getBoundingClientRect();
      if (r.top < innerHeight * 0.94) { el.classList.add('in'); return false; }   // in view, or already scrolled past
      return true;
    });
  }
  addEventListener('scroll', reveal, { passive: true });
  addEventListener('resize', reveal);
  reveal();
  setTimeout(reveal, 120);

  // toast + copy
  const toast = $('#toast');
  let toastT;
  function showToast(msg) { toast.textContent = msg; toast.classList.add('show'); clearTimeout(toastT); toastT = setTimeout(() => toast.classList.remove('show'), 1900); }
  async function copyText(text) {
    try { await navigator.clipboard.writeText(text); return true; }
    catch { const t = document.createElement('textarea'); t.value = text; t.style.position = 'fixed'; t.style.opacity = 0; document.body.appendChild(t); t.select();
      let ok = false; try { ok = document.execCommand('copy'); } catch {} t.remove(); return ok; }
  }
  $$('[data-copy]').forEach(btn => btn.addEventListener('click', async () => {
    const ok = await copyText(btn.dataset.copy);
    const label = $('.copy-label', btn), old = label ? label.textContent : '';
    btn.classList.add('copied'); if (label) label.textContent = ok ? 'Copied ✓' : 'Press ⌘C';
    showToast(ok ? 'Install command copied. Paste it in Terminal.' : 'Select the command and copy it');
    if (ok && !pet.hidden && pet.mode === 'pet') { startAct('dance'); say('Nice. Paste it in Terminal!', 2.5); }
    setTimeout(() => { btn.classList.remove('copied'); if (label) label.textContent = old; }, 1800);
  }));

  // tabs
  $$('.tabs button').forEach(t => t.addEventListener('click', () => {
    $$('.tabs button').forEach(b => b.setAttribute('aria-selected', b === t));
    $$('.tab-panel').forEach(p => { p.hidden = p.dataset.panel !== t.dataset.tab; });
  }));

  // latest release: version, size, direct asset link
  fetch('https://api.github.com/repos/xandertaylorx/clawd-buddy/releases/latest', { headers: { Accept: 'application/vnd.github+json' } })
    .then(r => r.ok ? r.json() : Promise.reject())
    .then(j => {
      const asset = (j.assets || []).find(a => a.name === 'Clawd.zip');
      const mb = asset ? (asset.size / 1048576).toFixed(1) + ' MB' : '';
      $('#ver').textContent = j.tag_name + (mb ? ' · ' + mb : '');
      const meta = $('#dl-meta');
      if (meta) meta.textContent = `${j.tag_name}${mb ? ' · ' + mb : ''} · macOS 14 or later · released ${new Date(j.published_at).toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' })}`;
      if (asset) $$('[data-download-link]').forEach(a => { a.href = asset.browser_download_url; });
    })
    .catch(() => {});
})();
