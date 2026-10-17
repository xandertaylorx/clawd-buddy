import React from 'react';
import {AbsoluteFill, Audio, Easing, Sequence, interpolate, random, spring, staticFile, useCurrentFrame} from 'remotion';
import {Clawd, DARK, INK, IVORY, LIGHT, OR, SLATE, Pose} from './Clawd';
import {BLUE, GREEN, MONO, Grid, Shadow, Word, blinkEyes, clamp01, ease, fontFamily, useSpr} from './Promo';

const SCENES = [90, 75, 75, 75, 75, 75, 90];
export const DURATION169 = SCENES.reduce((a, b) => a + b, 0);
const STARTS = SCENES.map((_, i) => SCENES.slice(0, i).reduce((a, b) => a + b, 0));

const Stack: React.FC<{lines: [string, string?][]; size: number; color?: string; accent?: string; left?: number; top: number}> =
  ({lines, size, color = IVORY, accent = OR, left = 110, top}) => (
    <div style={{position: 'absolute', left, top, display: 'flex', flexDirection: 'column', gap: 6}}>
      {lines.map(([t, c], i) => <Word key={i} delay={i * 4} size={size} color={c === 'a' ? accent : color}>{t}</Word>)}
    </div>
  );

const Caption: React.FC<{children: React.ReactNode; color: string; from?: number}> = ({children, color, from = 34}) => {
  const f = useCurrentFrame();
  return <div style={{position: 'absolute', left: 114, bottom: 90, fontFamily, fontWeight: 600, fontSize: 44, color, opacity: clamp01((f - from) / 8), transform: `translateY(${(1 - clamp01((f - from) / 8)) * 20}px)`}}>{children}</div>;
};

// slow push-in + floating specks keep every scene alive
const Scene: React.FC<{bg: string; speck: string; children: React.ReactNode}> = ({bg, speck, children}) => {
  const f = useCurrentFrame();
  return (
    <AbsoluteFill style={{background: bg, overflow: 'hidden'}}>
      <div style={{position: 'absolute', inset: 0, transform: `scale(${1 + f * 0.0004})`}}>
        <Grid color={speck + '14'} />
        {Array.from({length: 14}).map((_, i) => {
          const x = random(`a${i}`) * 1920, sz = 8 + random(`b${i}`) * 14, sp = 0.4 + random(`c${i}`) * 0.9;
          const y = 1080 - ((random(`d${i}`) * 1200 + f * sp * 2.2) % 1200);
          return <div key={i} style={{position: 'absolute', left: x, top: y, width: sz, height: sz, background: speck, opacity: 0.22}} />;
        })}
        {children}
      </div>
    </AbsoluteFill>
  );
};

const legsAt = (f: number, rate = 4): 1 | 2 => ((Math.floor(f / rate) % 2) + 1) as 1 | 2;

// 1 ------------------------------------------------------------------
const S1: React.FC = () => {
  const f = useCurrentFrame();
  const land = 16, fall = clamp01(f / land), size = 520, X = 1540;
  const y = f < land ? interpolate(fall * fall, [0, 1], [-1000, 0]) : -Math.abs(Math.sin((f - land) * 0.5)) * 100 * Math.exp(-(f - land) * 0.12);
  const hit = f >= land && f < land + 5;
  const wave = f > 30 ? [0, 2, 3, 2][Math.floor(f / 4) % 4] : 0;
  return (
    <Scene bg={SLATE} speck={OR}>
      <div style={{position: 'absolute', left: X - 600, top: 930 - 560, width: 1200, height: 1200, borderRadius: '50%', background: `radial-gradient(${OR}50, transparent 65%)`, opacity: clamp01((f - 14) / 10)}} />
      <Word delay={2} size={150} color={LIGHT} style={{position: 'absolute', left: 110, top: 210}}>Meet</Word>
      <Word delay={6} size={300} color={IVORY} style={{position: 'absolute', left: 100, top: 340, letterSpacing: -10}}>Clawd</Word>
      <Word delay={24} size={58} color={OR} style={{position: 'absolute', left: 116, top: 700, fontWeight: 600, textTransform: 'none', letterSpacing: 0}}>✻ a tiny pixel crab for your Mac</Word>
      <Shadow w={size * 0.9} x={X} y={915} k={f < land ? clamp01(fall) * 0.8 : 1} />
      <div style={{position: 'absolute', left: X - size / 2, top: 930 - (size * 14) / 15, transform: `translateY(${y}px) scale(${hit ? 1.3 : 1},${hit ? 0.72 : f < land ? 1.12 : 1})`, transformOrigin: '50% 100%'}}>
        <Clawd size={size} pose={{eyes: f < land ? 'wide' : f > 30 ? 'happy' : blinkEyes(f), armR: wave, legs: f > 30 ? legsAt(f, 5) : 0}} />
      </div>
    </Scene>
  );
};

// 2 ------------------------------------------------------------------
const S2: React.FC = () => {
  const f = useCurrentFrame();
  const jump = clamp01((f - 18) / 22), e = ease(jump), inBar = jump >= 1;
  const size = 520, bigX = 1400, bigY = 920, bx = 1500, by = 54;
  const cx = interpolate(e, [0, 1], [bigX, bx]);
  const cy = interpolate(e, [0, 1], [bigY, by]) - Math.sin(jump * Math.PI) * 300;
  const sc = interpolate(e, [0, 1], [1, 0.09]);
  const bubble = useSpr(46, 9, 200);
  return (
    <Scene bg={IVORY} speck={SLATE}>
      <div style={{position: 'absolute', left: 0, top: 0, width: 1920, height: 104, background: 'rgba(20,20,19,.92)', display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: 28, paddingRight: 44}}>
        {[0, 1, 2].map(i => <div key={i} style={{width: 34, height: 34, borderRadius: 8, background: 'rgba(250,249,245,.25)'}} />)}
        <div style={{fontFamily, fontWeight: 600, fontSize: 34, color: IVORY}}>9:41</div>
      </div>
      <div style={{position: 'absolute', left: bx - 40, top: by - 40, width: 80, height: 80, borderRadius: 16, background: 'rgba(217,119,87,.3)', opacity: inBar ? 1 : 0}} />
      <Stack lines={[['Lives in', ''], ['your', ''], ['menu bar', 'a']]} size={190} color={SLATE} top={200} />
      {!inBar && <Shadow w={size * 0.9} x={bigX} y={bigY + 8} k={1 - Math.sin(jump * Math.PI) * 0.4} />}
      <div style={{position: 'absolute', left: cx - (size * sc) / 2, top: cy - ((size * 14) / 15) * sc}}>
        <Clawd size={size * sc} pose={{eyes: jump > 0 && !inBar ? 'wide' : inBar ? 'happy' : blinkEyes(f), armL: inBar ? 0 : 3, armR: jump > 0 ? 3 : 0, legs: jump > 0 && !inBar ? 1 : (Math.floor(f / 6) % 2) as 0 | 1}} />
      </div>
      <div style={{position: 'absolute', right: 400, top: 124, transform: `scale(${bubble}) rotate(${(1 - bubble) * 6}deg)`, transformOrigin: '100% 0', opacity: clamp01(bubble * 2)}}>
        <div style={{background: SLATE, color: IVORY, fontFamily, fontWeight: 600, fontSize: 44, padding: '18px 34px', borderRadius: 30, borderTopRightRadius: 6}}>Ship it! 🚀</div>
      </div>
      <Caption color="#6b6a64">drag him up. he moves in.</Caption>
    </Scene>
  );
};

// 3 ------------------------------------------------------------------
const S3: React.FC = () => {
  const f = useCurrentFrame();
  const prog = clamp01((f - 6) / 40), secs = Math.round((1 - ease(prog)) * 25 * 60), done = prog >= 1;
  const mm = String(Math.floor(secs / 60)).padStart(2, '0'), ss = String(secs % 60).padStart(2, '0');
  const pop = useSpr(0, 10, 160), donePop = useSpr(46, 7, 220);
  const R = 350, C = 2 * Math.PI * R, size = 380, cx = 1400;
  const hop = done ? -Math.abs(Math.sin((f - 46) * 0.6)) * 50 * Math.exp(-(f - 46) * 0.08) : 0;
  const shake = !done && prog > 0.8 ? Math.sin(f * 2.4) * 6 : 0;
  return (
    <Scene bg={BLUE} speck="#ffffff">
      <Stack lines={[['Focus', ''], ['timer', 'a']]} size={250} color={SLATE} accent={IVORY} top={220} />
      <svg width="800" height="800" viewBox="0 0 800 800" style={{position: 'absolute', left: cx - 400, top: 190, transform: `scale(${pop})`}}>
        <circle cx="400" cy="400" r={R} fill="none" stroke="rgba(20,20,19,.18)" strokeWidth="40" />
        <circle cx="400" cy="400" r={R} fill="none" stroke={IVORY} strokeWidth="40" strokeLinecap="round" strokeDasharray={C} strokeDashoffset={C * prog} transform="rotate(-90 400 400)" />
      </svg>
      <div style={{position: 'absolute', left: cx - 190, top: 345, width: 380, height: 140, background: '#0e1a12', borderRadius: 22, border: `8px solid ${SLATE}`, display: 'flex', alignItems: 'center', justifyContent: 'center', transform: `scale(${pop})`}}>
        <div style={{fontFamily: MONO, fontWeight: 700, fontSize: 100, color: done ? '#b6ff7a' : '#7dff9c', letterSpacing: 4, textShadow: '0 0 24px rgba(125,255,156,.7)'}}>{mm}:{ss}</div>
      </div>
      {[-1, 1].map(d => <div key={d} style={{position: 'absolute', left: cx + d * 150 - 20, top: 300, width: 40, height: 40, borderRadius: '50% 50% 0 0', background: DARK, transform: `rotate(${d * 20 + Math.sin(f * 1.8 + d) * (prog > 0.8 ? 14 : 0)}deg) scale(${pop})`}} />)}
      <Shadow w={size * 0.9} x={cx} y={875} />
      <div style={{position: 'absolute', left: cx - size / 2 + shake, top: 880 - (size * 14) / 15 + hop}}>
        <Clawd size={size} pose={{eyes: done ? 'happy' : prog > 0.8 ? 'wide' : blinkEyes(f), armL: done ? 3 : 0, armR: done ? 3 : 0, legs: done ? legsAt(f) : 0}} />
      </div>
      {done && <div style={{position: 'absolute', left: 120, top: 640, transform: `scale(${donePop}) rotate(-6deg)`, background: IVORY, color: SLATE, fontFamily, fontWeight: 800, fontSize: 90, padding: '10px 44px', borderRadius: 28}}>DONE!</div>}
      <Caption color={SLATE}>he turns into an alarm clock ⏰</Caption>
    </Scene>
  );
};

// 4 ------------------------------------------------------------------
const TARGETS = ['Hold', '→ PNG', '→ JPG', 'Shrink', 'Zip', 'Trash'];
const S4: React.FC = () => {
  const f = useCurrentFrame();
  const hitF = 30, fall = clamp01((f - 8) / (hitF - 8)), shrunk = f > hitF, gone = f > hitF + 2;
  const fx = interpolate(ease(fall), [0, 1], [1700, 1130]), fy = interpolate(fall * fall, [0, 1], [-200, 215]);
  const num = shrunk ? interpolate(f, [hitF, hitF + 14], [4.2, 0.8], {extrapolateRight: 'clamp'}) : 4.2;
  const flash = useSpr(hitF, 8, 220), size = 400;
  return (
    <Scene bg={SLATE} speck={IVORY}>
      <Stack lines={[['Drop a', ''], ['file on', ''], ['him', 'a']]} size={190} top={200} />
      <div style={{position: 'absolute', left: 1010, top: 110, width: 780, display: 'flex', flexWrap: 'wrap', gap: 24}}>
        {TARGETS.map((t, i) => {
          const s = spring({frame: f - 6 - i * 3, fps: 30, config: {damping: 9, stiffness: 190, mass: 0.6}}), hot = t === 'Shrink';
          return <div key={t} style={{width: 244, height: 110, borderRadius: 30, background: hot && shrunk ? OR : 'rgba(250,249,245,.1)', border: `3px solid ${hot ? OR : 'rgba(250,249,245,.25)'}`, color: IVORY,
            fontFamily, fontWeight: 600, fontSize: 46, display: 'flex', alignItems: 'center', justifyContent: 'center', transform: `scale(${s * (hot && shrunk ? 1.08 + 0.15 * (1 - flash) : 1)})`, opacity: clamp01(s * 2)}}>{t}</div>;
        })}
      </div>
      {!gone && <div style={{position: 'absolute', left: fx - 55, top: fy, width: 110, height: 140, background: IVORY, borderRadius: '10px 36px 10px 10px', transform: `rotate(${(1 - fall) * 14}deg)`, boxShadow: '0 30px 60px rgba(0,0,0,.4)'}}>
        <div style={{fontFamily, fontWeight: 800, fontSize: 30, color: OR, textAlign: 'center', marginTop: 48}}>PNG</div></div>}
      <div style={{position: 'absolute', left: 1010, width: 780, top: 400, textAlign: 'center', fontFamily: MONO, fontWeight: 700, fontSize: 70, color: shrunk ? '#b6ff7a' : IVORY, opacity: clamp01((f - 24) / 6)}}>
        {shrunk ? `${num.toFixed(1)} MB  −81%` : '4.2 MB'}
      </div>
      <Shadow w={size * 0.9} x={1400} y={1015} />
      <div style={{position: 'absolute', left: 1400 - size / 2, top: 1020 - (size * 14) / 15, transform: `scale(${shrunk ? 1 + 0.12 * (1 - flash) : 1})`, transformOrigin: '50% 100%'}}>
        <Clawd size={size} pose={{eyes: shrunk ? 'happy' : f > 14 ? 'wide' : 'open', armL: 3, armR: 3, legs: shrunk ? legsAt(f) : 0}} />
      </div>
    </Scene>
  );
};

// 5 ------------------------------------------------------------------
const S5: React.FC = () => {
  const f = useCurrentFrame();
  const win = useSpr(4, 12, 150), toast = useSpr(36, 8, 200), ping = f >= 36, size = 340;
  const t = (s: string, start: number) => s.slice(0, Math.max(0, Math.floor((f - start) * 1.6)));
  return (
    <Scene bg={IVORY} speck={SLATE}>
      <Stack lines={[['Tells you', ''], ['when', ''], ['Claude Code', 'a'], ['is done', '']]} size={120} color={SLATE} top={150} />
      <div style={{position: 'absolute', left: 1000, top: 130, width: 800, height: 360, background: SLATE, borderRadius: 30, transform: `scale(${win}) rotate(${(1 - win) * 3}deg)`, transformOrigin: '50% 100%', boxShadow: '0 40px 80px rgba(20,20,19,.3)', overflow: 'hidden'}}>
        <div style={{display: 'flex', gap: 14, padding: '24px 30px'}}>{['#ec6a5e', '#f4bf4f', '#61c554'].map(c => <i key={c} style={{width: 22, height: 22, borderRadius: 11, background: c, display: 'block'}} />)}</div>
        <div style={{fontFamily: MONO, fontSize: 46, lineHeight: 1.6, padding: '0 40px', color: IVORY}}>
          <div style={{color: OR}}>{t('✻ Pondering…', 12)}</div>
          <div style={{color: '#b6ff7a'}}>{t('✓ 14 tests passed', 24)}</div>
          <div style={{color: '#b6ff7a'}}>{t('✓ Build succeeded', 32)}{f % 16 < 8 && f > 40 ? '▌' : ''}</div>
        </div>
      </div>
      <div style={{position: 'absolute', left: 1100, top: 560, transform: `scale(${toast}) rotate(${(1 - toast) * -8}deg)`, transformOrigin: '0 100%', opacity: clamp01(toast * 2)}}>
        <div style={{background: OR, color: IVORY, fontFamily, fontWeight: 800, fontSize: 58, padding: '20px 44px', borderRadius: 36, borderBottomLeftRadius: 8}}>Claude is done! ✻</div>
      </div>
      <Shadow w={size * 0.9} x={1250} y={1010} />
      <div style={{position: 'absolute', left: 1250 - size / 2, top: 1015 - (size * 14) / 15 + (ping ? -Math.abs(Math.sin((f - 36) * 0.7)) * 60 * Math.exp(-(f - 36) * 0.07) : 0)}}>
        <Clawd size={size} pose={{eyes: ping ? 'happy' : 'sleep', armL: ping ? 3 : 0, armR: ping ? 3 : 0, squash: !ping, legs: ping ? legsAt(f) : 0}} />
      </div>
      {!ping && <div style={{position: 'absolute', left: 1380, top: 880, fontFamily, fontWeight: 800, fontSize: 64, color: '#b0aea5'}}>z<span style={{fontSize: 84}}>Z</span>z</div>}
    </Scene>
  );
};

// 6 ------------------------------------------------------------------
const S6: React.FC = () => {
  const f = useCurrentFrame();
  const ph = (f % 20) / 20, h = 4 * ph * (1 - ph), squash = h < 0.08 ? 1 - (0.08 - h) * 3 : 1, dance = Math.floor(f / 5) % 2, size = 380;
  const chips = ['🏀 Basketball', '🐦 Flappy Clawd', '🎾 Ball physics', '🎩 Hats', '🌦 Weather outfits', '🎵 8-bit sounds'];
  return (
    <Scene bg={GREEN} speck="#ffffff">
      <Stack lines={[['and', ''], ['games.', 'a']]} size={270} color={SLATE} accent={IVORY} top={110} />
      <div style={{position: 'absolute', left: 0, top: 880, width: 6000, display: 'flex', gap: 24, transform: `translateX(${-f * 22}px)`}}>
        {[...chips, ...chips, ...chips, ...chips].map((c, i) => <div key={i} style={{flex: '0 0 auto', fontFamily, fontWeight: 800, fontSize: 54, background: IVORY, color: SLATE, padding: '14px 40px', borderRadius: 60, transform: `rotate(${i % 2 ? 2 : -2}deg)`}}>{c}</div>)}
      </div>
      <Shadow w={size * 0.9} x={1340} y={812} />
      <div style={{position: 'absolute', left: 1340 - size / 2, top: 818 - (size * 14) / 15 + (dance ? -14 : 0)}}>
        <Clawd size={size} pose={{eyes: 'happy', armL: dance ? 3 : 0, armR: dance ? 0 : 3, legs: (dance + 1) as 1 | 2}} />
      </div>
      <div style={{position: 'absolute', left: 1730 - 100, top: 800 - h * 520 - 200, width: 200, height: 200, transform: `scale(${1 / squash},${squash}) rotate(${f * 9}deg)`, transformOrigin: '50% 100%'}}>
        <svg viewBox="0 0 220 220" width="200" height="200"><circle cx="110" cy="110" r="106" fill={OR} stroke={DARK} strokeWidth="8" /><path d="M4 110H216M110 4V216M30 36C80 80 80 140 30 184M190 36C140 80 140 140 190 184" stroke={INK} strokeWidth="7" fill="none" /></svg>
      </div>
      <Shadow w={190} x={1730} y={805} k={1 - h * 0.6} />
    </Scene>
  );
};

// 7 ------------------------------------------------------------------
const S7: React.FC = () => {
  const f = useCurrentFrame();
  const title = useSpr(6, 9, 150), sub = useSpr(18, 12, 140), cta = useSpr(30, 8, 190), size = 440, dance = Math.floor(f / 5) % 2;
  return (
    <Scene bg={SLATE} speck={OR}>
      {[0, 1, 2].map(i => { const t = ((f + i * 14) % 42) / 42;
        return <div key={i} style={{position: 'absolute', left: 560 - 520 * t, top: 640 - 520 * t, width: 1040 * t, height: 1040 * t, borderRadius: '50%', border: `6px solid ${OR}`, opacity: (1 - t) * 0.45}} />; })}
      {Array.from({length: 30}).map((_, i) => {
        const x = random(`x${i}`) * 1920, sp = 5 + random(`s${i}`) * 9, y0 = random(`y${i}`) * 1200, sz = 12 + random(`z${i}`) * 22;
        return <div key={i} style={{position: 'absolute', left: x, top: ((y0 + f * sp) % 1300) - 120, width: sz, height: sz, background: [OR, LIGHT, IVORY, BLUE, GREEN][i % 5], opacity: 0.8, transform: `rotate(${f * (i % 3) * 3}deg)`}} />;
      })}
      <div style={{position: 'absolute', left: 0, width: 1920, top: 90, textAlign: 'center', transform: `scale(${title})`, opacity: clamp01(title * 2)}}>
        <div style={{fontFamily, fontWeight: 800, fontSize: 170, color: IVORY, letterSpacing: -6, lineHeight: 1, whiteSpace: 'nowrap'}}>clawd<span style={{color: OR}}>-</span>buddy</div>
      </div>
      <div style={{position: 'absolute', left: 0, width: 1920, top: 300, textAlign: 'center', fontFamily, fontWeight: 600, fontSize: 50, whiteSpace: 'nowrap', color: LIGHT, transform: `translateY(${(1 - sub) * 40}px)`, opacity: clamp01(sub * 2)}}>a tiny pixel crab that lives on your Mac</div>
      <Shadow w={size * 0.9} x={560} y={905} />
      <div style={{position: 'absolute', left: 560 - size / 2, top: 910 - (size * 14) / 15 + (dance ? -18 : 0), transform: `scale(${spring({frame: f, fps: 30, config: {damping: 8, stiffness: 160, mass: 0.6}})})`, transformOrigin: '50% 100%'}}>
        <Clawd size={size} pose={{eyes: 'happy', armL: dance ? 3 : 0, armR: dance ? 0 : 3, legs: (dance + 1) as 1 | 2}} />
      </div>
      <div style={{position: 'absolute', left: 1000, top: 520, display: 'flex', flexDirection: 'column', alignItems: 'flex-start', gap: 30, transform: `scale(${cta})`, transformOrigin: '0 50%', opacity: clamp01(cta * 2)}}>
        <div style={{background: OR, color: IVORY, fontFamily, fontWeight: 800, fontSize: 64, padding: '24px 64px', borderRadius: 100}}>Free · Open source</div>
        <div style={{fontFamily: MONO, fontSize: 34, color: IVORY, opacity: 0.9}}>github.com/xandertaylorx/clawd-buddy</div>
        <div style={{fontFamily, fontWeight: 600, fontSize: 42, color: '#b0aea5'}}>clawd.crooli.com · macOS 14+</div>
      </div>
    </Scene>
  );
};

const Wipes: React.FC = () => {
  const f = useCurrentFrame();
  return <>{STARTS.slice(1).map((b, i) => {
    const t = (f - (b - 7)) / 14;
    if (t < 0 || t > 1) return null;
    const x = t < 0.5 ? interpolate(t, [0, 0.5], [2300, 0], {easing: Easing.out(Easing.cubic)}) : interpolate(t, [0.5, 1], [0, -2300], {easing: Easing.in(Easing.cubic)});
    return <div key={i} style={{position: 'absolute', left: -300, top: -200, width: 2500, height: 1500, background: [OR, IVORY, SLATE, OR, IVORY, OR][i], transform: `translateX(${x}px) skewX(-12deg)`}} />;
  })}</>;
};

export const Promo169: React.FC = () => {
  const comps = [S1, S2, S3, S4, S5, S6, S7];
  return (
    <AbsoluteFill style={{background: SLATE, overflow: 'hidden'}}>
      <Audio src={staticFile('ambient-sfx.wav')} />
      {comps.map((C, i) => <Sequence key={i} from={STARTS[i]} durationInFrames={SCENES[i]}><C /></Sequence>)}
      <Wipes />
    </AbsoluteFill>
  );
};
