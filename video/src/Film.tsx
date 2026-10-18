import React from 'react';
import {AbsoluteFill, Audio, Easing, interpolate, random, spring, staticFile, useCurrentFrame} from 'remotion';
import {Clawd, INK, IVORY, LIGHT, OR, SLATE, Pose} from './Clawd';
import {fontFamily} from './Promo';

// One continuous camera move through a little Mac desktop that Clawd lives on.
export const FILM_DURATION = 690;
const FPS = 30;
const FY = 1050; // the floor Clawd walks on, in world px
const W = 90;    // Clawd's normal size on the desktop
const MONO = 'ui-monospace, "SF Mono", Menlo, monospace';
const BLUE = '#6a9bcc', GREEN = '#788c5d', GLASS = 'rgba(250,248,244,.84)';

const clamp01 = (v: number) => Math.min(1, Math.max(0, v));
const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
const inOut = Easing.bezier(0.65, 0, 0.35, 1);
const prog = (f: number, a: number, b: number) => clamp01((f - a) / (b - a));
const spr = (f: number, delay: number, damping = 12, stiffness = 150, mass = 0.7) =>
  spring({frame: f - delay, fps: FPS, config: {damping, stiffness, mass}});

// ------------------------------------------------------------------ camera
// [frame, focusX, focusY, zoom]; zoom interpolates in log space so pushes feel even
const CAM: [number, number, number, number][] = [
  [0, 960, 1023, 5.6], [70, 960, 1023, 5.0], [118, 960, 540, 1], [130, 960, 560, 1.04],
  [172, 1140, 700, 1.25], [184, 1180, 640, 1.3], [212, 1560, 120, 2.6], [250, 1585, 120, 2.75], [292, 1560, 140, 2.6],
  [322, 640, 700, 1.38], [396, 640, 700, 1.46], [412, 860, 640, 1.25], [446, 870, 640, 1.3], [462, 960, 540, 1],
  [490, 960, 540, 1], [506, 1180, 700, 1.4], [580, 1220, 700, 1.5], [614, 1000, 1008, 2.4], [690, 1000, 1008, 2.4],
];
const camAt = (f: number) => {
  let i = 0;
  while (i < CAM.length - 2 && f >= CAM[i + 1][0]) i++;
  const [f0, x0, y0, z0] = CAM[i], [f1, x1, y1, z1] = CAM[i + 1];
  const t = inOut(clamp01((f - f0) / (f1 - f0)));
  const z = Math.exp(lerp(Math.log(z0), Math.log(z1), t));
  if (f < 70) return {x: x0, y: lerp(y0, y1, t), z};
  if (f < 118) {
    // keep Clawd on screen while pulling out: slide his screen position from where it was to where it lands
    const s0 = 540 + (1008 - 1023) * 5.0, s = lerp(s0, 540 + (1008 - 540), t);
    const cy = 1008 - (s - 540) / z;
    return {x: 960, y: f < 112 ? cy : Math.min(1080 - 540 / z, cy), z};
  }
  const hx = 960 / z, hy = 540 / z;
  const x = Math.min(1920 - hx, Math.max(hx, lerp(x0, x1, t)));
  const y = Math.min(1080 - hy, Math.max(hy, lerp(y0, y1, t)));
  return {x: x + Math.sin(f / 37) * 1.2 / z, y: y + Math.cos(f / 43) * 1.2 / z, z};
};
const toScreen = (f: number, wx: number, wy: number) => {
  const c = camAt(f);
  return {x: 960 + (wx - c.x) * c.z, y: 540 + (wy - c.y) * c.z};
};

// ------------------------------------------------------------------ Clawd's path through the film
type CState = {x: number; by: number; size: number; pose: Pose; sx?: number; sy?: number};
const legs = (f: number, r = 4) => ((Math.floor(f / r) % 2) + 1) as 1 | 2;
const blink = (f: number, p = 70) => (f % p > p - 5 ? 'blink' : 'open') as Pose['eyes'];
const hop = (f: number, at: number, h: number, k = 0.07) => (f < at ? 0 : -Math.abs(Math.sin((f - at) * 0.55)) * h * Math.exp(-(f - at) * k));
const L_FILES = [330, 344, 358];
const BALL_THROW = 515, BALL_HOOP = 541;

const clawdAt = (f: number): CState => {
  if (f < 130) {
    const wave = f >= 64 && f < 96;
    return {x: 960, by: FY, size: W, pose: {eyes: wave ? 'happy' : blink(f - 4, 64), armR: wave ? [0, 2, 3, 2][Math.floor(f / 4) % 4] : 0}};
  }
  if (f < 172) return {x: lerp(960, 1200, prog(f, 130, 172)), by: FY + (f % 8 < 4 ? 0 : -2), size: W, pose: {legs: legs(f), eyeShift: 1}};
  if (f < 178) return {x: 1200, by: FY, size: W, pose: {eyeLift: 1, eyeShift: 1}};
  if (f < 182) return {x: 1200, by: FY, size: W, pose: {eyes: 'wide', squash: true}, sx: 1.12, sy: 0.88};
  if (f < 206) {
    const t = prog(f, 182, 206), e = inOut(t);
    return {x: lerp(1200, 1560, e), by: lerp(FY, 31, e) - Math.sin(Math.PI * t) * 160, size: lerp(W, 26, e), pose: {eyes: 'wide', armL: 3, armR: 3, legs: 1}, sx: 0.92, sy: 1.1};
  }
  if (f < 292) return {x: 1560, by: 31, size: 26, pose: {eyes: f < 232 ? 'happy' : blink(f, 40)}};
  if (f < 318) {
    const t = prog(f, 292, 318);
    return {x: lerp(1560, 800, Easing.out(Easing.quad)(t)), by: lerp(31, FY, t * t) - Math.sin(Math.PI * t) * 90, size: lerp(26, W, Math.sqrt(t)), pose: {eyes: 'wide', armL: 3, armR: 3, legs: 1}};
  }
  if (f < 323) return {x: 800, by: FY, size: W, pose: {eyes: 'happy', squash: true}, sx: 1.25, sy: 0.78};
  if (f < 398) {
    const busy = L_FILES.some(l => f >= l && f < l + 16);
    return {x: 800, by: FY + hop(f, 346, 14) + hop(f, 360, 14) + hop(f, 374, 14), size: W, pose: {eyes: busy ? 'wide' : 'happy', armL: f > 324 && f < 390 ? 3 : 0, armR: f > 324 && f < 390 ? 3 : 0}};
  }
  if (f < 457) return {x: 800, by: FY, size: W, pose: {eyes: 'sleep', squash: true}};
  if (f < 490) return {x: 800, by: FY + hop(f, 458, 46, 0.05), size: W, pose: {eyes: f < 462 ? 'wide' : 'happy', armL: f % 10 < 5 ? 3 : 0, armR: f % 10 < 5 ? 0 : 3, legs: legs(f)}};
  if (f < 506) return {x: lerp(800, 1000, inOut(prog(f, 490, 506))), by: FY + (f % 8 < 4 ? 0 : -2), size: W, pose: {legs: legs(f), eyeShift: 1}};
  if (f < BALL_THROW) return {x: 1000, by: FY, size: W, pose: {armL: 3, armR: 3, eyeShift: 1, eyeLift: 1}};
  if (f < BALL_HOOP + 2) return {x: 1000, by: FY, size: W, pose: {eyes: 'wide', eyeShift: 1, eyeLift: 1, armR: 3}};
  if (f < 590) return {x: 1000, by: FY + hop(f, BALL_HOOP + 2, 40, 0.04), size: W, pose: {eyes: 'happy', armL: f % 10 < 5 ? 3 : 0, armR: f % 10 < 5 ? 0 : 3, legs: legs(f)}};
  return {x: 1000, by: FY, size: W, pose: {eyes: 'happy', armR: [0, 2, 3, 2][Math.floor(f / 4) % 4]}};
};

const ClawdAt: React.FC<{s: CState; shadow?: boolean}> = ({s, shadow = true}) => {
  const h = (s.size * 14) / 15;
  return (
    <>
      {shadow && s.by > FY - 200 && (
        <div style={{position: 'absolute', left: s.x - s.size * 0.42, top: FY - 4, width: s.size * 0.84, height: 10, borderRadius: '50%', background: 'rgba(80,30,10,.22)', filter: 'blur(3px)', opacity: clamp01(1 - (FY - s.by) / 200)}} />
      )}
      <div style={{position: 'absolute', left: s.x - s.size / 2, top: s.by - h, transform: `scale(${s.sx ?? 1},${s.sy ?? 1})`, transformOrigin: '50% 100%'}}>
        <Clawd size={s.size} pose={s.pose} />
      </div>
    </>
  );
};

// pixel-by-pixel assembly for the cold open
const PIXELS: {x: number; y: number; c: string}[] = (() => {
  const out: {x: number; y: number; c: string}[] = [];
  const fill = (x: number, y: number, w: number, h: number, c: string) => {
    for (let i = 0; i < w; i++) for (let j = 0; j < h; j++) out.push({x: x + i, y: 13 - (y + j), c});
  };
  [3, 5, 9, 11].forEach(x => fill(x, 0, 1, 2, OR));
  fill(2, 2, 11, 6, OR); fill(0, 3, 2, 2, OR); fill(13, 3, 2, 2, OR);
  return out.filter(p => !((p.x === 4 || p.x === 10) && (p.y === 8 || p.y === 9))).concat([4, 10].flatMap(x => [{x, y: 8, c: INK}, {x, y: 9, c: INK}]));
})();
const Assemble: React.FC<{f: number}> = ({f}) => (
  <div style={{position: 'absolute', left: 960 - W / 2, top: FY - (W * 14) / 15}}>
    <svg viewBox="0 0 15 14" width={W} height={(W * 14) / 15} shapeRendering="crispEdges" style={{overflow: 'visible', display: 'block'}}>
      {PIXELS.map((p, i) => {
        const eye = p.c === INK;
        const d = eye ? 42 + (p.x > 7 ? 2 : 0) : 6 + random(`d${i}`) * 26;
        const s = spr(f, d, 13, 120, 0.6);
        const dx = (random(`x${i}`) - 0.5) * 60, dy = (random(`y${i}`) - 0.5) * 36 - 6, r = (random(`r${i}`) - 0.5) * 360;
        return <rect key={i} x={p.x} y={p.y} width={1.02} height={1.02} fill={p.c} opacity={clamp01(s * 3)}
          transform={`translate(${dx * (1 - s)} ${dy * (1 - s)}) rotate(${r * (1 - s)} ${p.x + 0.5} ${p.y + 0.5})`} />;
      })}
    </svg>
  </div>
);

// ------------------------------------------------------------------ desktop pieces
const Wallpaper: React.FC<{f: number}> = ({f}) => {
  const b = (x: number, y: number, r: number, c: string, k: number) =>
    `radial-gradient(circle at ${x + 800 + Math.sin(f / 70 + k) * 40}px ${y + 800 + Math.cos(f / 85 + k) * 30}px, ${c} 0, transparent ${r}px)`;
  // bleeds 800px past the screen so camera moves never expose an edge
  return <div style={{position: 'absolute', left: -800, top: -800, width: 3520, height: 2680, background:
    [b(1550, 880, 900, '#e48c6acc', 0), b(380, 180, 900, '#f8d8c4', 1), b(260, 1020, 760, '#b9c4e6cc', 2), b(1120, 320, 620, '#fff6ee', 3), 'linear-gradient(160deg,#f6e4d6,#ecc0a8)'].join(',')}} />;
};

const DesktopIcons = () => (
  <>
    {[['Projects', 'folder'], ['clawd.zip', 'zip'], ['Screenshot.png', 'img']].map(([name, kind], i) => (
      <div key={name} style={{position: 'absolute', left: 1790, top: 70 + i * 118, width: 100, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6}}>
        {kind === 'folder' ? (
          <svg width="64" height="52" viewBox="0 0 64 52"><path d="M2 8a4 4 0 014-4h18l6 6h28a4 4 0 014 4v32a4 4 0 01-4 4H6a4 4 0 01-4-4z" fill="#6a9bcc" /><path d="M2 16h60v30a4 4 0 01-4 4H6a4 4 0 01-4-4z" fill="#86b2de" /></svg>
        ) : kind === 'zip' ? (
          <div style={{width: 44, height: 56, background: '#fff', borderRadius: '4px 14px 4px 4px', boxShadow: '0 4px 10px rgba(0,0,0,.15)', display: 'flex', justifyContent: 'center'}}>
            <div style={{width: 6, height: 30, marginTop: 6, background: 'repeating-linear-gradient(#8e8c83 0 3px, transparent 3px 6px)'}} /></div>
        ) : (
          <div style={{width: 60, height: 44, borderRadius: 4, border: '3px solid #fff', boxShadow: '0 4px 10px rgba(0,0,0,.15)', background: 'linear-gradient(135deg,#e48c6a,#f8d8c4)'}} />
        )}
        <div style={{fontFamily, fontWeight: 600, fontSize: 12, color: SLATE, background: 'rgba(255,255,255,.45)', padding: '1px 6px', borderRadius: 4}}>{name}</div>
      </div>
    ))}
  </>
);

const WifiIcon = () => (
  <svg width="20" height="16" viewBox="0 0 20 16"><path d="M10 14l2.5-3a3.5 3.5 0 00-5 0zM4.5 7.5a8 8 0 0111 0l-1.6 1.8a5.6 5.6 0 00-7.8 0zM1 4a13 13 0 0118 0l-1.6 1.8a10.6 10.6 0 00-14.8 0z" fill={SLATE} /></svg>
);

const MenuBar: React.FC<{f: number}> = ({f}) => {
  const timerOn = f >= 256 && f < 292;
  const secs = 25 * 60 - 1 - Math.floor(Math.max(0, f - 256) / 3);
  return (
    <div style={{position: 'absolute', left: 0, top: 0, width: 1920, height: 38, background: 'rgba(250,245,240,.6)', backdropFilter: 'blur(20px)', borderBottom: '1px solid rgba(0,0,0,.06)', fontFamily, fontSize: 14, color: SLATE}}>
      <div style={{position: 'absolute', left: 22, top: 9, display: 'flex', gap: 22, alignItems: 'center'}}>
        <span style={{color: OR, fontSize: 18, lineHeight: '18px'}}>✻</span><b style={{fontWeight: 600}}>Clawd</b>
        {['File', 'Edit', 'View', 'Window', 'Help'].map(t => <span key={t} style={{opacity: 0.8}}>{t}</span>)}
      </div>
      {timerOn && <div style={{position: 'absolute', left: 1578, top: 9, fontFamily: MONO, fontWeight: 600, fontSize: 15}}>{String(Math.floor(secs / 60)).padStart(2, '0')}:{String(secs % 60).padStart(2, '0')}</div>}
      <div style={{position: 'absolute', left: 1648, top: 10, display: 'flex', gap: 18, alignItems: 'center'}}>
        <WifiIcon />
        <div style={{width: 26, height: 13, border: `1.5px solid ${SLATE}`, borderRadius: 4, padding: 1.5}}><div style={{width: '72%', height: '100%', background: SLATE, borderRadius: 1.5}} /></div>
        <span style={{fontWeight: 600}}>Sat Oct 18&nbsp;&nbsp;9:41</span>
      </div>
    </div>
  );
};

const Win: React.FC<{x: number; y: number; w: number; h: number; s: number; title: string; dark?: boolean; children: React.ReactNode}> = ({x, y, w, h, s, title, dark, children}) => (
  <div style={{position: 'absolute', left: x, top: y, width: w, height: h, borderRadius: 14, overflow: 'hidden', transform: `scale(${s})`, opacity: clamp01(s * 2), transformOrigin: '50% 60%',
    background: dark ? 'rgba(22,21,20,.94)' : GLASS, backdropFilter: 'blur(24px)', border: `1px solid ${dark ? 'rgba(255,255,255,.08)' : 'rgba(255,255,255,.7)'}`, boxShadow: '0 30px 70px rgba(70,30,15,.28), 0 4px 14px rgba(70,30,15,.12)'}}>
    <div style={{height: 38, display: 'flex', alignItems: 'center', padding: '0 14px', gap: 8, borderBottom: `1px solid ${dark ? 'rgba(255,255,255,.06)' : 'rgba(0,0,0,.06)'}`}}>
      {['#ec6a5e', '#f4bf4f', '#61c554'].map(c => <i key={c} style={{width: 12, height: 12, borderRadius: 6, background: c, display: 'block'}} />)}
      <span style={{flex: 1, textAlign: 'center', marginRight: 50, fontFamily, fontWeight: 600, fontSize: 14, color: dark ? '#a9a79d' : '#6b6a64'}}>{title}</span>
    </div>
    {children}
  </div>
);

const Cursor: React.FC<{x: number; y: number; down: boolean; o: number}> = ({x, y, down, o}) => (
  <svg width="22" height="30" viewBox="0 0 17 25" style={{position: 'absolute', left: x, top: y, opacity: o, transform: `scale(${down ? 0.82 : 1})`, transformOrigin: '0 0', filter: 'drop-shadow(0 2px 3px rgba(0,0,0,.3))'}}>
    <path d="M1 1v19.5l4.6-4.4 3.3 7.6 3-1.3-3.3-7.4h6.3z" fill="#fff" stroke="#111" strokeWidth="1.3" strokeLinejoin="round" />
  </svg>
);

// file shelf
const FILES = [
  {name: 'photo.png', tag: 'PNG', c: OR, from: [270, 530], chip: 0, result: 'on the shelf'},
  {name: 'screenshot.png', tag: 'PNG', c: BLUE, from: [400, 530], chip: 3, result: '−81%'},
  {name: 'notes.pdf', tag: 'PDF', c: GREEN, from: [530, 530], chip: 4, result: '.zip'},
];
const CHIPS = ['Hold', '→ PNG', '→ JPG', 'Shrink', 'Zip', 'Path'];
const chipX = (i: number) => 800 - 230 + i * 78 + 35;
const CHIP_Y = 905;
const FileIcon: React.FC<{tag: string; c: string; scale?: number}> = ({tag, c, scale = 1}) => (
  <div style={{width: 48, height: 60, background: '#fff', borderRadius: '5px 16px 5px 5px', boxShadow: '0 6px 14px rgba(0,0,0,.18)', transform: `scale(${scale})`, position: 'relative'}}>
    <div style={{position: 'absolute', left: 0, right: 0, bottom: 8, textAlign: 'center', fontFamily, fontWeight: 800, fontSize: 11, color: '#fff', background: c, margin: '0 6px', borderRadius: 3}}>{tag}</div>
  </div>
);

// ------------------------------------------------------------------ the world (everything the camera films)
const World: React.FC<{f: number}> = ({f}) => {
  const c = clawdAt(f);
  // cold-open blackout with an iris that opens on Clawd
  const iris = interpolate(f, [70, 112], [0, 2300], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.in(Easing.cubic)});
  const glow = clamp01((f - 8) / 30) * (1 - clamp01((f - 90) / 20));
  // menu dropdown + cursor
  const menu = f >= 221 && f < 258 ? spr(f, 221, 14, 260) : 0;
  const curPts: [number, number, number][] = [[204, 1690, 250], [219, 1562, 20], [236, 1562, 20], [250, 1500, 68], [262, 1500, 68], [282, 1700, 220]];
  let cx = curPts[0][1], cy = curPts[0][2];
  for (let i = 0; i < curPts.length - 1; i++) {
    const [a, x0, y0] = curPts[i], [b, x1, y1] = curPts[i + 1];
    if (f >= a) { const t = inOut(prog(f, a, b)); cx = lerp(x0, x1, t); cy = lerp(y0, y1, t); }
  }
  const curO = clamp01((f - 204) / 5) * (1 - clamp01((f - 280) / 8));
  const curDown = (f >= 219 && f < 222) || (f >= 251 && f < 254);
  // windows
  const finder = f < 300 ? 0 : f < 392 ? spr(f, 300, 13, 170) : 1 - prog(f, 392, 402);
  const term = f < 398 ? 0 : f < 488 ? spr(f, 398, 13, 170) : 1 - prog(f, 488, 498);
  const tray = f < 322 ? 0 : f < 388 ? spr(f, 322, 11, 200) : 1 - prog(f, 388, 396);
  const notif = f < 452 ? 0 : f < 484 ? spr(f, 452, 14, 160) : 1 - inOut(prog(f, 484, 494));
  const hoopS = f < 494 ? 0 : spr(f, 494, 10, 170);
  const type = (s: string, at: number, speed = 1.3) => s.slice(0, Math.max(0, Math.floor((f - at) * speed)));
  const spin = ['✻', '✶', '✳', '✢', '·', '✢', '✳', '✶'][Math.floor(f / 3) % 8];
  // ball
  let ball: {x: number; y: number; r: number} | null = null;
  if (f >= 505 && f < BALL_THROW) ball = {x: 1000, y: FY - 96, r: 0};
  else if (f >= BALL_THROW && f < BALL_HOOP) {
    const t = prog(f, BALL_THROW, BALL_HOOP);
    ball = {x: lerp(1000, 1441, t), y: lerp(FY - 96, FY - 346, t) - Math.sin(Math.PI * t) * 230, r: (f - BALL_THROW) * 14};
  } else if (f >= BALL_HOOP && f < 556) {
    const t = prog(f, BALL_HOOP, 556);
    ball = {x: lerp(1441, 1452, t), y: lerp(FY - 346, FY - 16, t * t), r: 370 + t * 40};
  } else if (f >= 556 && f < 600) {
    const t = prog(f, 556, 578);
    ball = {x: lerp(1452, 1500, prog(f, 556, 600)), y: FY - 16 - (f < 578 ? Math.sin(Math.PI * t) * 90 : 0), r: 410 + (f - 556) * 6};
  }
  const net = f >= BALL_HOOP && f < BALL_HOOP + 14 ? 1 + Math.sin((f - BALL_HOOP) * 1.4) * 0.25 * Math.exp(-(f - BALL_HOOP) * 0.2) : 1;
  const rimY = FY - 330;
  return (
    <div style={{position: 'absolute', left: 0, top: 0, width: 1920, height: 1080}}>
      <Wallpaper f={f} />
      <MenuBar f={f} />
      <DesktopIcons />

      {/* Finder */}
      {finder > 0 && (
        <Win x={150} y={360} w={500} h={310} s={finder} title="Downloads">
          <div style={{position: 'relative', height: 270}}>
            {FILES.map((d, i) => {
              const gone = f >= L_FILES[i];
              return <div key={d.name} style={{position: 'absolute', left: d.from[0] - 150 - 24, top: d.from[1] - 360 - 38 - 30, opacity: gone ? 0.25 : 1, display: 'flex', flexDirection: 'column', alignItems: 'center', width: 48}}>
                <FileIcon tag={d.tag} c={d.c} />
                <div style={{fontFamily, fontSize: 12, color: SLATE, marginTop: 8, whiteSpace: 'nowrap'}}>{d.name}</div>
              </div>;
            })}
          </div>
        </Win>
      )}

      {/* Terminal */}
      {term > 0 && (
        <Win x={250} y={250} w={820} h={400} s={term} title="claude — ~/sync-app" dark>
          <div style={{fontFamily: MONO, fontSize: 20, lineHeight: 1.75, color: '#e8e6dc', padding: '18px 26px'}}>
            <div><span style={{color: '#8e8c83'}}>~/sync-app $ </span>{type('claude', 404)}</div>
            {f >= 412 && <div style={{color: '#cfcdc4'}}><span style={{color: OR}}>&gt; </span>{type('fix the flaky sync test', 412, 1.5)}</div>}
            {f >= 430 && f < 444 && <div style={{color: OR}}>{spin} Pondering… <span style={{color: '#8e8c83'}}>(esc to interrupt)</span></div>}
            {f >= 444 && <div><span style={{color: '#b6ff7a'}}>●</span> Update(tests/sync.test.ts)</div>}
            {f >= 446 && <div style={{color: '#8e8c83'}}>&nbsp;&nbsp;⎿ 1 line changed</div>}
            {f >= 449 && <div style={{color: '#b6ff7a'}}>✓ 14 tests passed</div>}
          </div>
        </Win>
      )}

      {/* hoop */}
      {hoopS > 0 && (
        <div style={{position: 'absolute', left: 0, top: 0, transform: `scale(${hoopS})`, transformOrigin: `1500px ${FY}px`}}>
          <div style={{position: 'absolute', left: 1500, top: rimY - 70, width: 12, height: FY - rimY + 70, background: '#5b5a55', borderRadius: 3}} />
          <div style={{position: 'absolute', left: 1484, top: rimY - 110, width: 14, height: 130, background: IVORY, border: `3px solid ${SLATE}`, borderRadius: 3}} />
        </div>
      )}
      {f >= 541 && f < 572 && (
        <div style={{position: 'absolute', left: 1400, top: rimY - 120 - prog(f, 541, 572) * 40, fontFamily, fontWeight: 800, fontSize: 44, color: OR, opacity: 1 - prog(f, 560, 572), transform: `scale(${spr(f, 541, 8, 220)})`}}>+2</div>
      )}

      {/* Clawd (or his assembling pixels) */}
      {f < 56 ? <Assemble f={f} /> : <ClawdAt s={c} />}
      {/* sleepy z's */}
      {f >= 400 && f < 457 && [0, 1, 2, 3].map(i => {
        const t = ((f - 400 + i * 14) % 56) / 56;
        return <div key={i} style={{position: 'absolute', left: 770 - t * 50 + Math.sin(t * 8) * 6, top: FY - 70 - t * 90, fontFamily, fontWeight: 800, fontSize: 16 + t * 14, color: SLATE, opacity: Math.sin(Math.PI * t) * 0.7}}>z</div>;
      })}

      {/* ball, then net and rim drawn over it so it drops through */}
      {ball && (
        <svg width="36" height="36" viewBox="0 0 36 36" style={{position: 'absolute', left: ball.x - 18, top: ball.y - 18, transform: `rotate(${ball.r}deg)`}}>
          <circle cx="18" cy="18" r="16.5" fill="#e07a45" stroke="#9a4a26" strokeWidth="2" />
          <path d="M1.5 18h33M18 1.5v33M6 6c6 6 6 18 0 24M30 6c-6 6-6 18 0 24" stroke="#4a2414" strokeWidth="1.6" fill="none" />
        </svg>
      )}
      {hoopS > 0 && (
        <div style={{position: 'absolute', left: 0, top: 0, transform: `scale(${hoopS})`, transformOrigin: `1500px ${FY}px`}}>
          <svg width="110" height="70" viewBox="0 0 110 70" style={{position: 'absolute', left: 1392, top: rimY, transform: `scaleY(${net})`, transformOrigin: '50% 0'}}>
            {[0, 1, 2, 3, 4, 5].map(i => <path key={i} d={`M${4 + i * 18} 2 L${22 + i * 12} 56`} stroke="#fff" strokeWidth="2.5" opacity=".9" />)}
            {[0, 1, 2, 3, 4, 5].map(i => <path key={`b${i}`} d={`M${94 - i * 18} 2 L${78 - i * 12} 56`} stroke="#fff" strokeWidth="2.5" opacity=".9" />)}
          </svg>
          <div style={{position: 'absolute', left: 1390, top: rimY - 4, width: 100, height: 8, background: '#e2552f', borderRadius: 4}} />
        </div>
      )}

      {/* drop tray + flying files */}
      {tray > 0 && CHIPS.map((t, i) => {
        const hit = FILES.find(d => d.chip === i);
        const landed = hit ? f >= L_FILES[FILES.indexOf(hit)] + 16 : false;
        const flash = landed ? spr(f, L_FILES[FILES.indexOf(hit!)] + 16, 8, 240) : 0;
        const s = spr(f, 322 + i * 2, 10, 220) * (f >= 388 ? tray : 1);
        return <div key={t} style={{position: 'absolute', left: chipX(i) - 35, top: CHIP_Y - 15, width: 70, height: 30, borderRadius: 15, background: landed ? OR : 'rgba(20,20,19,.86)', color: IVORY,
          fontFamily, fontWeight: 600, fontSize: 13, display: 'flex', alignItems: 'center', justifyContent: 'center', transform: `scale(${s * (1 + 0.2 * (1 - flash) * (landed ? 1 : 0))})`, boxShadow: '0 6px 16px rgba(0,0,0,.2)'}}>{t}</div>;
      })}
      {tray > 0 && FILES.map((d, i) => {
        const L = L_FILES[i];
        if (f < L + 16) return null;
        const s = spr(f, L + 16, 9, 220) * tray;
        return <div key={d.name} style={{position: 'absolute', left: chipX(d.chip) - 60, width: 120, top: CHIP_Y - 50, textAlign: 'center', fontFamily, fontWeight: 800, fontSize: 15, color: SLATE, transform: `scale(${s}) translateY(${(1 - s) * 10}px)`}}>
          <span style={{background: IVORY, padding: '3px 9px', borderRadius: 9, boxShadow: '0 4px 10px rgba(0,0,0,.12)'}}>{d.result}</span></div>;
      })}
      {FILES.map((d, i) => {
        const L = L_FILES[i];
        if (f < L || f >= L + 16) return null;
        const t = prog(f, L, L + 16), e = inOut(t);
        const x = lerp(d.from[0], chipX(d.chip), e), y = lerp(d.from[1], CHIP_Y - 10, e) - Math.sin(Math.PI * t) * 150;
        return <div key={d.name} style={{position: 'absolute', left: x - 24, top: y - 30, transform: `rotate(${Math.sin(Math.PI * t) * 18}deg)`}}><FileIcon tag={d.tag} c={d.c} scale={lerp(1, 0.55, e)} /></div>;
      })}

      {/* menu dropdown */}
      {menu > 0 && (
        <div style={{position: 'absolute', left: 1470, top: 42, width: 250, padding: 6, borderRadius: 12, background: 'rgba(250,248,244,.9)', backdropFilter: 'blur(24px)', boxShadow: '0 18px 40px rgba(70,30,15,.25)', border: '1px solid rgba(255,255,255,.7)',
          transform: `scale(${menu})`, transformOrigin: '90px 0', opacity: clamp01(menu * 2), fontFamily, fontSize: 14, color: SLATE}}>
          {[['⏱  Focus · 25 min', true], ['☕  Break · 5 min', false], ['—'], ['🎩  Hats', false], ['⬇  Let Clawd out', false]].map(([t, hi], i) =>
            t === '—' ? <div key={i} style={{height: 1, background: 'rgba(0,0,0,.08)', margin: '5px 8px'}} />
              : <div key={i} style={{padding: '6px 10px', borderRadius: 7, background: hi && f >= 246 ? OR : 'transparent', color: hi && f >= 246 ? IVORY : SLATE, fontWeight: 600}}>{t as string}</div>)}
        </div>
      )}

      {/* notification */}
      {notif > 0 && (
        <div style={{position: 'absolute', left: 1460 + (1 - notif) * 480, top: 54, width: 440, padding: '16px 18px', borderRadius: 18, display: 'flex', gap: 14, alignItems: 'center',
          background: 'rgba(250,248,244,.88)', backdropFilter: 'blur(24px)', boxShadow: '0 20px 50px rgba(70,30,15,.25)', border: '1px solid rgba(255,255,255,.75)'}}>
          <div style={{width: 52, height: 52, borderRadius: 12, background: SLATE, display: 'flex', alignItems: 'center', justifyContent: 'center', flex: '0 0 auto'}}><Clawd size={36} pose={{eyes: 'happy'}} /></div>
          <div style={{fontFamily, color: SLATE}}>
            <div style={{fontWeight: 800, fontSize: 18}}>Clawd <span style={{fontWeight: 600, color: '#8e8c83', fontSize: 14, marginLeft: 6}}>now</span></div>
            <div style={{fontWeight: 600, fontSize: 17}}>Claude Code is done ✓ 14 tests passed</div>
          </div>
        </div>
      )}

      {/* speech bubble while walking */}
      {f >= 138 && f < 176 && (
        <div style={{position: 'absolute', left: c.x - 20, top: FY - 140, transform: `scale(${spr(f, 138, 10, 220) * (1 - prog(f, 170, 176))})`, transformOrigin: '20px 40px'}}>
          <div style={{background: SLATE, color: IVORY, fontFamily, fontWeight: 600, fontSize: 17, padding: '8px 14px', borderRadius: 14, borderBottomLeftRadius: 4, whiteSpace: 'nowrap'}}>
            <span style={{color: OR}}>{spin}</span> {type('Percolating…', 140, 0.8)}</div>
        </div>
      )}

      {/* confetti from the hoop */}
      {f >= 543 && f < 600 && Array.from({length: 26}).map((_, i) => {
        const t = (f - 543) / 30, a = random(`ca${i}`) * Math.PI * 2, v = 120 + random(`cv${i}`) * 160;
        return <div key={i} style={{position: 'absolute', left: 1441 + Math.cos(a) * v * t, top: rimY - 10 + Math.sin(a) * v * t * 0.7 + 260 * t * t, width: 8, height: 8,
          background: [OR, LIGHT, BLUE, GREEN, IVORY][i % 5], transform: `rotate(${f * 12 + i * 30}deg)`, opacity: 1 - clamp01((f - 580) / 20)}} />;
      })}

      {/* cursor */}
      {curO > 0 && <Cursor x={cx} y={cy} down={curDown} o={curO} />}

      {/* blackout + iris for the cold open; Clawd's assembling pixels sit above it */}
      {f < 112 && (
        <>
          <div style={{position: 'absolute', left: -3000, top: -3000, width: 7920, height: 7080, background: '#0d0c0b',
            WebkitMaskImage: `radial-gradient(circle at ${3960}px ${3000 + FY - 42}px, transparent ${iris}px, #000 ${iris + 2}px)`,
            maskImage: `radial-gradient(circle at ${3960}px ${3000 + FY - 42}px, transparent ${iris}px, #000 ${iris + 2}px)`}} />
          <div style={{position: 'absolute', left: 960 - 110, top: FY - 42 - 110, width: 220, height: 220, borderRadius: '50%', background: `radial-gradient(${OR}66, transparent 65%)`, opacity: glow}} />
          {f < 56 ? <Assemble f={f} /> : <ClawdAt s={c} shadow={false} />}
        </>
      )}
    </div>
  );
};

// ------------------------------------------------------------------ captions (screen space)
type Pos = 'tl' | 'bl' | 'br' | 'bc';
const Caption: React.FC<{f: number; from: number; to: number; lines: string[]; pos: Pos; size?: number; color?: string}> = ({f, from, to, lines, pos, size = 78, color = SLATE}) => {
  if (f < from - 2 || f > to + 2) return null;
  let wi = 0;
  const box: React.CSSProperties = {position: 'absolute', fontFamily, fontWeight: 800, fontSize: size, lineHeight: 1.04, letterSpacing: -size * 0.025, color,
    ...(pos === 'tl' ? {left: 100, top: 110} : pos === 'bl' ? {left: 100, bottom: 100} : pos === 'br' ? {right: 100, bottom: 100, textAlign: 'right'} : {left: 0, right: 0, bottom: 90, textAlign: 'center'})};
  return (
    <div style={box}>
      {lines.map((ln, li) => (
        <div key={li}>
          {ln.split(' ').map((w, i) => {
            const k = wi++;
            const accent = w.startsWith('*');
            const s = spr(f, from + k * 2.2, 15, 170, 0.6);
            const out = Easing.in(Easing.cubic)(prog(f, to - 8 + k * 0.6, to + k * 0.6));
            return (
              <span key={i} style={{display: 'inline-block', overflow: 'hidden', verticalAlign: 'top', paddingBottom: '0.14em', marginBottom: '-0.14em', marginRight: '0.24em'}}>
                <span style={{display: 'inline-block', transform: `translateY(${(1 - s) * 110 - out * 110}%) rotate(${(1 - s) * 6}deg)`, color: accent ? OR : color}}>{w.replace(/\*/g, '')}</span>
              </span>
            );
          })}
        </div>
      ))}
    </div>
  );
};

// ------------------------------------------------------------------ outro (revealed underneath the world)
const Outro: React.FC<{f: number}> = ({f}) => {
  const l = f - 606;
  const title = 'clawd-buddy'.split('');
  const dance = Math.floor(f / 5) % 2;
  const cs = spr(l, 4, 9, 150);
  const line = (d: number) => {
    const s = spr(l, d, 14, 150);
    return {transform: `translateY(${(1 - s) * 40}px)`, opacity: clamp01(s * 1.5)};
  };
  return (
    <AbsoluteFill style={{background: '#0f0e0d'}}>
      <div style={{position: 'absolute', left: 520 - 700, top: 604 - 700, width: 1400, height: 1400, borderRadius: '50%', background: `radial-gradient(${OR}40, transparent 60%)`}} />
      {[0, 1, 2].map(i => { const t = ((l + i * 16) % 48) / 48;
        return <div key={i} style={{position: 'absolute', left: 520 - 460 * t, top: 604 - 460 * t, width: 920 * t, height: 920 * t, borderRadius: '50%', border: `3px solid ${OR}`, opacity: (1 - t) * 0.35 * clamp01(l / 10)}} />; })}
      <div style={{position: 'absolute', left: 520 - 210, top: 800 - 392, transform: `scale(${cs}) translateY(${dance ? -12 : 0}px)`, transformOrigin: '50% 100%'}}>
        <Clawd size={420} pose={{eyes: l > 70 && l < 74 ? 'blink' : 'happy', armL: dance ? 3 : 0, armR: [0, 2, 3, 2][Math.floor(f / 4) % 4], legs: (dance + 1) as 1 | 2}} />
      </div>
      <div style={{position: 'absolute', left: 520 - 190, top: 810, width: 380, height: 18, borderRadius: '50%', background: 'rgba(0,0,0,.5)', filter: 'blur(6px)', opacity: cs}} />
      <div style={{position: 'absolute', left: 900, top: 330}}>
        <div style={{fontFamily: MONO, fontSize: 22, color: LIGHT, letterSpacing: 2, ...line(8)}}>✻ FREE &amp; OPEN SOURCE · macOS 14+</div>
        <div style={{display: 'flex', marginTop: 18}}>
          {title.map((ch, i) => {
            const s = spr(l, 12 + i * 1.6, 13, 180, 0.6);
            return <span key={i} style={{display: 'inline-block', overflow: 'hidden', paddingBottom: '0.12em'}}>
              <span style={{display: 'inline-block', fontFamily, fontWeight: 800, fontSize: 128, letterSpacing: -4, lineHeight: 1, color: ch === '-' ? OR : IVORY, transform: `translateY(${(1 - s) * 110}%)`}}>{ch}</span></span>;
          })}
        </div>
        <div style={{fontFamily, fontWeight: 600, fontSize: 38, color: '#cfcdc4', marginTop: 16, ...line(30)}}>a tiny pixel crab that lives on your Mac.</div>
        <div style={{display: 'flex', gap: 18, alignItems: 'center', marginTop: 48, ...line(40)}}>
          <div style={{background: OR, color: IVORY, fontFamily, fontWeight: 800, fontSize: 36, padding: '18px 40px', borderRadius: 100}}>clawd.crooli.com</div>
        </div>
        <div style={{fontFamily: MONO, fontSize: 24, color: '#a9a79d', marginTop: 28, ...line(48)}}>github.com/xandertaylorx/clawd-buddy</div>
      </div>
      <div style={{position: 'absolute', right: 40, bottom: 30, fontFamily, fontSize: 16, color: '#6b6a64', ...line(56)}}>Fan project · not affiliated with Anthropic</div>
    </AbsoluteFill>
  );
};

// ------------------------------------------------------------------ film grain + vignette
const Grain: React.FC<{f: number}> = ({f}) => (
  <>
    <AbsoluteFill style={{background: 'radial-gradient(ellipse at center, transparent 55%, rgba(30,10,0,.22) 100%)', pointerEvents: 'none'}} />
    <svg width="1920" height="1080" style={{position: 'absolute', inset: 0, opacity: 0.07, mixBlendMode: 'overlay'}}>
      <filter id="g"><feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" seed={Math.floor(f / 2)} stitchTiles="stitch" /><feColorMatrix type="saturate" values="0" /></filter>
      <rect width="1920" height="1080" filter="url(#g)" />
    </svg>
  </>
);

export const Film: React.FC = () => {
  const f = useCurrentFrame();
  const cam = camAt(f);
  const cs = clawdAt(f);
  const pc = toScreen(f, cs.x, cs.by - (cs.size * 14) / 30);
  const close = interpolate(f, [586, 614], [1500, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.in(Easing.cubic)});
  return (
    <AbsoluteFill style={{background: '#0f0e0d', overflow: 'hidden'}}>
      <Audio src={staticFile('film-audio.wav')} />
      {f >= 590 && <Outro f={f} />}
      {f < 614 && (
        <AbsoluteFill style={{clipPath: f >= 586 ? `circle(${close}px at ${pc.x}px ${pc.y}px)` : undefined}}>
          <div style={{position: 'absolute', left: 0, top: 0, width: 1920, height: 1080, transformOrigin: '0 0',
            transform: `translate(960px,540px) scale(${cam.z}) translate(${-cam.x}px,${-cam.y}px)`}}>
            <World f={f} />
          </div>
        </AbsoluteFill>
      )}
      <Caption f={f} from={22} to={76} lines={['This is *Clawd.*']} pos="bc" size={96} color={IVORY} />
      <Caption f={f} from={106} to={166} lines={['A tiny pixel crab', 'that lives on your *Mac.*']} pos="tl" />
      <Caption f={f} from={174} to={214} lines={['He moves into', 'your *menu bar.*']} pos="tl" />
      <Caption f={f} from={224} to={296} lines={['Click him for a', '*focus timer.*']} pos="bl" />
      <Caption f={f} from={318} to={396} lines={['Drop files', '*on him.*']} pos="bl" />
      <Caption f={f} from={406} to={486} lines={['He knows when', '*Claude Code* is done.']} pos="br" />
      <Caption f={f} from={500} to={580} lines={['Plays *games,* too.']} pos="tl" />
      <Grain f={f} />
    </AbsoluteFill>
  );
};
