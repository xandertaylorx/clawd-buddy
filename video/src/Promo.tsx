import React from 'react';
import {AbsoluteFill, Audio, Easing, Sequence, interpolate, random, spring, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';
import {loadFont} from '@remotion/google-fonts/Poppins';
import {Clawd, DARK, INK, IVORY, LIGHT, OR, SLATE, Pose} from './Clawd';

export const {fontFamily} = loadFont('normal', {weights: ['600', '800'], subsets: ['latin']});
export const MONO = 'ui-monospace, "SF Mono", Menlo, monospace';
export const BLUE = '#6a9bcc'; export const GREEN = '#788c5d';

const SCENES = [75, 60, 60, 60, 60, 60, 75];
export const DURATION = SCENES.reduce((a, b) => a + b, 0);
const STARTS = SCENES.map((_, i) => SCENES.slice(0, i).reduce((a, b) => a + b, 0));

export const clamp01 = (v: number) => Math.min(1, Math.max(0, v));
export const ease = Easing.bezier(0.2, 0.9, 0.2, 1);
export const useSpr = (delay = 0, damping = 11, stiffness = 140) => {
  const f = useCurrentFrame(); const {fps} = useVideoConfig();
  return spring({frame: f - delay, fps, config: {damping, stiffness, mass: 0.7}});
};

// ---------- kinetic text ----------
export const Word: React.FC<{children: string; delay: number; size: number; color?: string; rot?: number; style?: React.CSSProperties}> =
  ({children, delay, size, color = IVORY, rot = -4, style}) => {
    const s = useSpr(delay, 10, 170);
    return (
      <div style={{fontFamily, fontWeight: 800, fontSize: size, whiteSpace: 'nowrap', lineHeight: 0.92, letterSpacing: -size * 0.03, color, textTransform: 'uppercase',
        transform: `translateY(${(1 - s) * 140}px) rotate(${(1 - s) * rot}deg) scale(${0.6 + 0.4 * s})`, opacity: clamp01(s * 1.6), transformOrigin: '0 100%', ...style}}>
        {children}
      </div>
    );
  };

const Stack: React.FC<{lines: [string, string?][]; size?: number; color?: string; accent?: string; top?: number}> =
  ({lines, size = 190, color = IVORY, accent = OR, top = 170}) => (
    <div style={{position: 'absolute', left: 70, top, display: 'flex', flexDirection: 'column', gap: 6}}>
      {lines.map(([t, c], i) => <Word key={i} delay={i * 4} size={size} color={c === 'a' ? accent : color}>{t}</Word>)}
    </div>
  );

// ---------- pixel grid backdrop ----------
export const Grid: React.FC<{color: string}> = ({color}) => {
  const f = useCurrentFrame();
  return <AbsoluteFill style={{backgroundImage: `linear-gradient(${color} 2px, transparent 2px), linear-gradient(90deg, ${color} 2px, transparent 2px)`,
    backgroundSize: '90px 90px', backgroundPosition: `0 ${f * 1.5}px`, opacity: 0.5}} />;
};

export const Shadow: React.FC<{w: number; x: number; y: number; k?: number}> = ({w, x, y, k = 1}) => (
  <div style={{position: 'absolute', left: x - (w * k) / 2, top: y, width: w * k, height: w * 0.12, borderRadius: '50%', background: 'rgba(0,0,0,.28)', filter: 'blur(10px)', opacity: k}} />
);

export const blinkEyes = (f: number): Pose['eyes'] => (f % 60 > 54 ? 'blink' : 'open');

// ---------- 1. meet clawd ----------
const S1: React.FC = () => {
  const f = useCurrentFrame();
  const land = 16, fall = clamp01(f / land);
  const y = f < land ? interpolate(fall * fall, [0, 1], [-1100, 0]) : -Math.abs(Math.sin((f - land) * 0.5)) * 90 * Math.exp(-(f - land) * 0.12);
  const hit = f >= land && f < land + 5;
  const sx = hit ? 1.3 : 1 + (f < land ? 0.05 : 0), sy = hit ? 0.72 : f < land ? 1.12 : 1;
  const wave = f > 30 ? [0, 2, 3, 2][Math.floor(f / 4) % 4] : 0;
  const size = 600;
  return (
    <AbsoluteFill style={{background: SLATE}}>
      <Grid color="rgba(217,119,87,.10)" />
      <div style={{position: 'absolute', left: 540 - 520, top: 1130 - 520, width: 1040, height: 1040, borderRadius: '50%', background: `radial-gradient(${OR}55, transparent 65%)`, opacity: clamp01((f - 14) / 10)}} />
      <Word delay={2} size={150} color={LIGHT} style={{position: 'absolute', left: 70, top: 200}}>Meet</Word>
      <Word delay={6} size={285} color={IVORY} style={{position: 'absolute', left: 64, top: 300, letterSpacing: -10}}>Clawd</Word>
      <Word delay={22} size={64} color={OR} style={{position: 'absolute', left: 74, top: 640, fontWeight: 600, textTransform: 'none', letterSpacing: 0}}>✻ a tiny pixel crab for your Mac</Word>
      <Shadow w={size * 0.9} x={540} y={1495} k={f < land ? clamp01(fall) * 0.8 : 1} />
      <div style={{position: 'absolute', left: 540 - size / 2, top: 1500 - (size * 14) / 15, transform: `translateY(${y}px) scale(${sx},${sy})`, transformOrigin: '50% 100%'}}>
        <Clawd size={size} pose={{eyes: f < land ? 'wide' : f > 30 ? 'happy' : blinkEyes(f), armR: wave, legs: f > 30 ? ((Math.floor(f / 5) % 2) + 1) as 1 | 2 : 0}} />
      </div>
    </AbsoluteFill>
  );
};

// ---------- 2. menu bar ----------
const S2: React.FC = () => {
  const f = useCurrentFrame();
  const jump = clamp01((f - 18) / 22), e = ease(jump);
  const bx = 150, by = 52; // tiny clawd target in bar
  const size = 560, bigX = 540, bigY = 1300;
  const cx = interpolate(e, [0, 1], [bigX, bx]);
  const cy = interpolate(e, [0, 1], [bigY, by]) - Math.sin(jump * Math.PI) * 420;
  const sc = interpolate(e, [0, 1], [1, 0.09]);
  const inBar = jump >= 1;
  const bubble = useSpr(46, 9, 200);
  return (
    <AbsoluteFill style={{background: IVORY}}>
      <Grid color="rgba(20,20,19,.05)" />
      <div style={{position: 'absolute', left: 0, top: 0, width: 1080, height: 104, background: 'rgba(20,20,19,.92)', display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: 28, paddingRight: 36}}>
        {[0, 1, 2].map(i => <div key={i} style={{width: 34, height: 34, borderRadius: 8, background: 'rgba(250,249,245,.25)'}} />)}
        <div style={{fontFamily, fontWeight: 600, fontSize: 34, color: IVORY}}>9:41</div>
      </div>
      <div style={{position: 'absolute', left: 150 - 40, top: 52 - 40, width: 80, height: 80, borderRadius: 16, background: 'rgba(217,119,87,.28)', opacity: inBar ? 1 : 0}} />
      <Stack lines={[['Lives in', ''], ['your', ''], ['menu bar', 'a']]} size={180} color={SLATE} top={290} />
      {!inBar && <Shadow w={size * 0.9} x={540} y={bigY + 8} k={1 - Math.sin(jump * Math.PI) * 0.4} />}
      <div style={{position: 'absolute', left: cx - (size * sc) / 2, top: cy - ((size * 14) / 15) * sc, transformOrigin: '0 0'}}>
        <Clawd size={size * sc} pose={{eyes: jump > 0 && !inBar ? 'wide' : inBar ? 'happy' : blinkEyes(f), armL: inBar ? 0 : 3, armR: jump > 0 ? 3 : 0, legs: jump > 0 && !inBar ? 1 : (Math.floor(f / 6) % 2) as 0 | 1}} />
      </div>
      <div style={{position: 'absolute', left: 230, top: 124, transform: `scale(${bubble}) rotate(${(1 - bubble) * -6}deg)`, transformOrigin: '0 0', opacity: clamp01(bubble * 2)}}>
        <div style={{background: SLATE, color: IVORY, fontFamily, fontWeight: 600, fontSize: 44, padding: '18px 34px', borderRadius: 30, borderTopLeftRadius: 6}}>Ship it! 🚀</div>
      </div>
      <div style={{position: 'absolute', left: 70, bottom: 150, fontFamily, fontWeight: 600, fontSize: 52, color: '#6b6a64', opacity: clamp01((f - 34) / 8)}}>drag him up. he moves in.</div>
    </AbsoluteFill>
  );
};

// ---------- 3. focus timer ----------
const S3: React.FC = () => {
  const f = useCurrentFrame();
  const prog = clamp01((f - 6) / 40);
  const secs = Math.round((1 - ease(prog)) * 25 * 60);
  const mm = String(Math.floor(secs / 60)).padStart(2, '0'), ss = String(secs % 60).padStart(2, '0');
  const done = prog >= 1;
  const pop = useSpr(0, 10, 160), donePop = useSpr(46, 7, 220);
  const R = 400, C = 2 * Math.PI * R, size = 480;
  const hop = done ? -Math.abs(Math.sin((f - 46) * 0.6)) * 60 * Math.exp(-(f - 46) * 0.08) : 0;
  const shake = !done && prog > 0.8 ? Math.sin(f * 2.4) * 6 : 0;
  return (
    <AbsoluteFill style={{background: BLUE}}>
      <Grid color="rgba(255,255,255,.12)" />
      <Stack lines={[['Focus', ''], ['timer', 'a']]} size={230} color={SLATE} accent={IVORY} top={160} />
      <svg width="1080" height="1080" viewBox="0 0 1080 1080" style={{position: 'absolute', left: 0, top: 600, transform: `scale(${pop})`}}>
        <circle cx="540" cy="540" r={R} fill="none" stroke="rgba(20,20,19,.18)" strokeWidth="46" />
        <circle cx="540" cy="540" r={R} fill="none" stroke={IVORY} strokeWidth="46" strokeLinecap="round" strokeDasharray={C} strokeDashoffset={C * prog} transform="rotate(-90 540 540)" />
      </svg>
      <div style={{position: 'absolute', left: 340, top: 780, width: 400, height: 150, background: '#0e1a12', borderRadius: 22, border: `8px solid ${SLATE}`, display: 'flex', alignItems: 'center', justifyContent: 'center', transform: `scale(${pop})`}}>
        <div style={{fontFamily: MONO, fontWeight: 700, fontSize: 108, color: done ? '#b6ff7a' : '#7dff9c', letterSpacing: 4, textShadow: '0 0 24px rgba(125,255,156,.7)'}}>{mm}:{ss}</div>
      </div>
      {[430, 610].map((x, i) => <div key={i} style={{position: 'absolute', left: x, top: 715 + (i ? 0 : 0), width: 40, height: 40, borderRadius: '50% 50% 0 0', background: DARK, transform: `rotate(${(i ? 1 : -1) * 20 + Math.sin(f * 1.8 + i) * (prog > 0.8 ? 14 : 0)}deg) scale(${pop})`}} />)}
      <Shadow w={size * 0.9} x={540} y={1320} k={1} />
      <div style={{position: 'absolute', left: 540 - size / 2 + shake, top: 1325 - (size * 14) / 15 + hop}}>
        <Clawd size={size} pose={{eyes: done ? 'happy' : prog > 0.8 ? 'wide' : blinkEyes(f), armL: done ? 3 : 0, armR: done ? 3 : 0, legs: done ? ((Math.floor(f / 4) % 2) + 1) as 1 | 2 : 0}} />
      </div>
      {done && <div style={{position: 'absolute', right: 70, top: 1360, transform: `scale(${donePop}) rotate(8deg)`, background: IVORY, color: SLATE, fontFamily, fontWeight: 800, fontSize: 80, padding: '10px 36px', borderRadius: 24}}>DONE!</div>}
      <div style={{position: 'absolute', left: 70, bottom: 130, fontFamily, fontWeight: 600, fontSize: 48, color: SLATE}}>he turns into an alarm clock ⏰</div>
    </AbsoluteFill>
  );
};

// ---------- 4. drop files ----------
const TARGETS = ['Hold', '→ PNG', '→ JPG', 'Shrink', 'Zip', 'Trash'];
const S4: React.FC = () => {
  const f = useCurrentFrame();
  const hitF = 30;
  const fall = clamp01((f - 8) / (hitF - 8));
  const fx = interpolate(ease(fall), [0, 1], [820, 540 - 0]);
  const fy = interpolate(fall * fall, [0, 1], [-200, 880]);
  const gone = f > hitF + 2;
  const shrunk = f > hitF;
  const num = shrunk ? interpolate(f, [hitF, hitF + 14], [4.2, 0.8], {extrapolateRight: 'clamp'}) : 4.2;
  const flash = useSpr(hitF, 8, 220);
  const size = 440;
  return (
    <AbsoluteFill style={{background: SLATE}}>
      <Grid color="rgba(250,249,245,.05)" />
      <Stack lines={[['Drop a', ''], ['file on', ''], ['him', 'a']]} size={170} top={150} />
      <div style={{position: 'absolute', left: 90, top: 780, width: 900, display: 'flex', flexWrap: 'wrap', gap: 24, justifyContent: 'center'}}>
        {TARGETS.map((t, i) => {
          const s = spring({frame: f - 6 - i * 3, fps: 30, config: {damping: 9, stiffness: 190, mass: 0.6}});
          const hot = t === 'Shrink';
          return <div key={t} style={{width: 270, height: 120, borderRadius: 30, background: hot && shrunk ? OR : 'rgba(250,249,245,.1)', border: `3px solid ${hot ? OR : 'rgba(250,249,245,.25)'}`, color: IVORY,
            fontFamily, fontWeight: 600, fontSize: 48, display: 'flex', alignItems: 'center', justifyContent: 'center', transform: `scale(${s * (hot && shrunk ? 1 + 0.15 * (1 - flash) + 0.08 : 1)})`, opacity: clamp01(s * 2)}}>{t}</div>;
        })}
      </div>
      {!gone && (
        <div style={{position: 'absolute', left: fx - 80, top: fy, width: 160, height: 200, background: IVORY, borderRadius: '14px 50px 14px 14px', transform: `rotate(${(1 - fall) * 14}deg)`, boxShadow: '0 30px 60px rgba(0,0,0,.4)'}}>
          <div style={{fontFamily, fontWeight: 800, fontSize: 40, color: OR, textAlign: 'center', marginTop: 70}}>PNG</div>
        </div>
      )}
      <div style={{position: 'absolute', left: 0, width: 1080, top: 1010, textAlign: 'center', fontFamily: MONO, fontWeight: 700, fontSize: 76, color: shrunk ? '#b6ff7a' : IVORY, opacity: clamp01((f - 24) / 6)}}>
        {shrunk ? `${num.toFixed(1)} MB  −81%` : '4.2 MB'}
      </div>
      <Shadow w={size * 0.9} x={540} y={1665} />
      <div style={{position: 'absolute', left: 540 - size / 2, top: 1670 - (size * 14) / 15, transform: `scale(${shrunk ? 1 + 0.12 * (1 - flash) : 1})`, transformOrigin: '50% 100%'}}>
        <Clawd size={size} pose={{eyes: shrunk ? 'happy' : f > 14 ? 'wide' : 'open', eyeLift: shrunk ? 0 : 0, armL: 3, armR: 3, legs: shrunk ? ((Math.floor(f / 4) % 2) + 1) as 1 | 2 : 0}} />
      </div>
    </AbsoluteFill>
  );
};

// ---------- 5. claude code alert ----------
const S5: React.FC = () => {
  const f = useCurrentFrame();
  const win = useSpr(4, 12, 150), toast = useSpr(36, 8, 200);
  const line1 = '✻ Pondering…', line2 = '✓ 14 tests passed', line3 = '✓ Build succeeded';
  const t = (s: string, start: number) => s.slice(0, Math.max(0, Math.floor((f - start) * 1.6)));
  const size = 420, ping = f >= 36;
  return (
    <AbsoluteFill style={{background: IVORY}}>
      <Grid color="rgba(20,20,19,.05)" />
      <Stack lines={[['Tells you', ''], ['when', ''], ['Claude Code', 'a'], ['is done', '']]} size={128} color={SLATE} top={130} />
      <div style={{position: 'absolute', left: 80, top: 800, width: 920, height: 400, background: SLATE, borderRadius: 32, transform: `scale(${win}) rotate(${(1 - win) * 3}deg)`, transformOrigin: '50% 100%', boxShadow: '0 40px 80px rgba(20,20,19,.3)', overflow: 'hidden'}}>
        <div style={{display: 'flex', gap: 14, padding: '26px 30px'}}>{['#ec6a5e', '#f4bf4f', '#61c554'].map(c => <i key={c} style={{width: 24, height: 24, borderRadius: 12, background: c, display: 'block'}} />)}</div>
        <div style={{fontFamily: MONO, fontSize: 50, lineHeight: 1.6, padding: '0 40px', color: IVORY}}>
          <div style={{color: OR}}>{t(line1, 12)}</div>
          <div style={{color: '#b6ff7a'}}>{t(line2, 24)}</div>
          <div style={{color: '#b6ff7a'}}>{t(line3, 32)}{f % 16 < 8 && f > 40 ? '▌' : ''}</div>
        </div>
      </div>
      <div style={{position: 'absolute', left: 180, top: 1235, transform: `scale(${toast}) rotate(${(1 - toast) * 8}deg)`, transformOrigin: '0 100%', opacity: clamp01(toast * 2)}}>
        <div style={{background: OR, color: IVORY, fontFamily, fontWeight: 800, fontSize: 60, padding: '20px 44px', borderRadius: 36, borderBottomLeftRadius: 8}}>Claude is done! ✻</div>
      </div>
      <Shadow w={size * 0.9} x={300} y={1745} />
      <div style={{position: 'absolute', left: 300 - size / 2, top: 1750 - (size * 14) / 15 + (ping ? -Math.abs(Math.sin((f - 36) * 0.7)) * 70 * Math.exp(-(f - 36) * 0.07) : 0)}}>
        <Clawd size={size} pose={{eyes: ping ? 'happy' : 'sleep', armL: ping ? 3 : 0, armR: ping ? 3 : 0, squash: !ping, legs: ping ? ((Math.floor(f / 4) % 2) + 1) as 1 | 2 : 0}} />
      </div>
      {!ping && <div style={{position: 'absolute', left: 430, top: 1560, fontFamily, fontWeight: 800, fontSize: 70, color: '#b0aea5'}}>z<span style={{fontSize: 90}}>Z</span>z</div>}
    </AbsoluteFill>
  );
};

// ---------- 6. games ----------
const S6: React.FC = () => {
  const f = useCurrentFrame();
  const period = 20, ph = (f % period) / period;
  const by = Math.abs(Math.cos(ph * Math.PI)) ; // 1 at floor? use parabola
  const h = 4 * ph * (1 - ph); // 0 at floor, 1 at peak
  const ballY = 1560 - h * 560;
  const squash = h < 0.08 ? 1 - (0.08 - h) * 3 : 1;
  const rot = f * 9;
  const size = 380, dance = Math.floor(f / 5) % 2;
  const chips = ['🏀 Basketball', '🐦 Flappy Clawd', '🎾 Ball physics', '🎩 Hats', '🌦 Weather outfits', '🎵 8-bit sounds'];
  return (
    <AbsoluteFill style={{background: GREEN}}>
      <Grid color="rgba(255,255,255,.1)" />
      <Stack lines={[['and', ''], ['games.', 'a']]} size={260} color={SLATE} accent={IVORY} top={150} />
      <div style={{position: 'absolute', left: 0, top: 720, width: 4000, display: 'flex', gap: 24, transform: `translateX(${-f * 22}px)`}}>
        {[...chips, ...chips, ...chips].map((c, i) => <div key={i} style={{flex: '0 0 auto', fontFamily, fontWeight: 800, fontSize: 56, background: IVORY, color: SLATE, padding: '14px 40px', borderRadius: 60, transform: `rotate(${i % 2 ? 2 : -2}deg)`}}>{c}</div>)}
      </div>
      <div style={{position: 'absolute', left: 90, top: 1000, width: 900, height: 360, border: `10px solid ${SLATE}`, borderRadius: 24, opacity: 0}} />
      <Shadow w={size * 0.9} x={330} y={1590} />
      <div style={{position: 'absolute', left: 330 - size / 2, top: 1595 - (size * 14) / 15 + (dance ? -14 : 0)}}>
        <Clawd size={size} pose={{eyes: 'happy', armL: dance ? 3 : 0, armR: dance ? 0 : 3, legs: (dance + 1) as 1 | 2}} />
      </div>
      <div style={{position: 'absolute', left: 690 - 110, top: ballY - 220, width: 220, height: 220, transform: `scale(${1 / squash},${squash}) rotate(${rot}deg)`, transformOrigin: '50% 100%'}}>
        <svg viewBox="0 0 220 220" width="220" height="220">
          <circle cx="110" cy="110" r="106" fill={OR} stroke={DARK} strokeWidth="8" />
          <path d="M4 110H216M110 4V216M30 36C80 80 80 140 30 184M190 36C140 80 140 140 190 184" stroke={INK} strokeWidth="7" fill="none" />
        </svg>
      </div>
      <Shadow w={200} x={690} y={1590} k={1 - h * 0.6} />
    </AbsoluteFill>
  );
};

// ---------- 7. outro ----------
const S7: React.FC = () => {
  const f = useCurrentFrame();
  const title = useSpr(6, 9, 150), sub = useSpr(18, 12, 140), cta = useSpr(30, 8, 190);
  const size = 520, dance = Math.floor(f / 5) % 2;
  return (
    <AbsoluteFill style={{background: SLATE}}>
      <Grid color="rgba(217,119,87,.10)" />
      {[0, 1, 2].map(i => {
        const t = ((f + i * 14) % 42) / 42;
        return <div key={i} style={{position: 'absolute', left: 540 - 560 * t, top: 1010 - 560 * t, width: 1120 * t, height: 1120 * t, borderRadius: '50%', border: `6px solid ${OR}`, opacity: (1 - t) * 0.5}} />;
      })}
      {Array.from({length: 26}).map((_, i) => {
        const x = random(`x${i}`) * 1080, sp = 6 + random(`s${i}`) * 10, y0 = random(`y${i}`) * 1920, sz = 14 + random(`z${i}`) * 26;
        return <div key={i} style={{position: 'absolute', left: x, top: ((y0 + f * sp) % 2100) - 100, width: sz, height: sz, background: [OR, LIGHT, IVORY, BLUE, GREEN][i % 5], opacity: 0.85, transform: `rotate(${f * (i % 3) * 3}deg)`}} />;
      })}
      <div style={{position: 'absolute', left: 0, width: 1080, top: 250, textAlign: 'center', transform: `scale(${title})`, opacity: clamp01(title * 2)}}>
        <div style={{fontFamily, fontWeight: 800, fontSize: 150, color: IVORY, letterSpacing: -6, lineHeight: 1, whiteSpace: 'nowrap'}}>clawd<span style={{color: OR}}>-</span>buddy</div>
      </div>
      <div style={{position: 'absolute', left: 0, width: 1080, top: 440, textAlign: 'center', fontFamily, fontWeight: 600, fontSize: 46, whiteSpace: 'nowrap', color: LIGHT, transform: `translateY(${(1 - sub) * 40}px)`, opacity: clamp01(sub * 2)}}>a tiny pixel crab that lives on your Mac</div>
      <Shadow w={size * 0.9} x={540} y={1215} />
      <div style={{position: 'absolute', left: 540 - size / 2, top: 1220 - (size * 14) / 15 + (dance ? -18 : 0), transform: `scale(${spring({frame: f, fps: 30, config: {damping: 8, stiffness: 160, mass: 0.6}})})`, transformOrigin: '50% 100%'}}>
        <Clawd size={size} pose={{eyes: 'happy', armL: dance ? 3 : 0, armR: dance ? 0 : 3, legs: (dance + 1) as 1 | 2}} />
      </div>
      <div style={{position: 'absolute', left: 0, width: 1080, top: 1400, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 28, transform: `scale(${cta})`, opacity: clamp01(cta * 2)}}>
        <div style={{background: OR, color: IVORY, fontFamily, fontWeight: 800, fontSize: 64, padding: '26px 70px', borderRadius: 100}}>Free · Open source</div>
        <div style={{fontFamily: MONO, fontSize: 40, color: IVORY, opacity: 0.85}}>github.com/xandertaylorx/clawd-buddy</div>
        <div style={{fontFamily, fontWeight: 600, fontSize: 42, color: '#b0aea5'}}>clawd.crooli.com · macOS 14+</div>
      </div>
    </AbsoluteFill>
  );
};

// ---------- wipes between scenes ----------
const Wipes: React.FC = () => {
  const f = useCurrentFrame();
  return (
    <>
      {STARTS.slice(1).map((b, i) => {
        const t = (f - (b - 7)) / 14;
        if (t < 0 || t > 1) return null;
        const x = t < 0.5 ? interpolate(t, [0, 0.5], [1500, 0], {easing: Easing.out(Easing.cubic)}) : interpolate(t, [0.5, 1], [0, -1500], {easing: Easing.in(Easing.cubic)});
        const col = [OR, IVORY, SLATE, OR, IVORY, OR][i];
        return <div key={i} style={{position: 'absolute', left: -200, top: -200, width: 1480, height: 2320, background: col, transform: `translateX(${x}px) skewX(-12deg)`}} />;
      })}
    </>
  );
};

export const Promo: React.FC = () => {
  const comps = [S1, S2, S3, S4, S5, S6, S7];
  return (
    <AbsoluteFill style={{background: SLATE, overflow: 'hidden'}}>
      <Audio src={staticFile('beat.wav')} volume={0.9} />
      {comps.map((C, i) => (
        <Sequence key={i} from={STARTS[i]} durationInFrames={SCENES[i]}><C /></Sequence>
      ))}
      <Wipes />
    </AbsoluteFill>
  );
};
