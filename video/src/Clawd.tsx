import React from 'react';

export const OR = '#d97757', DARK = '#b86143', LIGHT = '#f59e7a', INK = '#1a1210', IVORY = '#faf9f5', SLATE = '#141413';

export type Pose = {
  eyes?: 'open' | 'blink' | 'wide' | 'happy' | 'sleep';
  eyeShift?: number; eyeLift?: number; armL?: number; armR?: number;
  legs?: 0 | 1 | 2; bob?: number; squash?: boolean; color?: string;
};

// Direct port of the app's sprite: everything is filled rectangles on a 15x14 grid.
export const Clawd: React.FC<{pose?: Pose; size: number; style?: React.CSSProperties}> = ({pose = {}, size, style}) => {
  const p = {eyes: 'open', eyeShift: 0, eyeLift: 0, armL: 0, armR: 0, legs: 0, bob: 0, squash: false, color: OR, ...pose};
  const rects: React.ReactNode[] = [];
  let k = 0;
  const R = (x: number, y: number, w: number, h: number, c: string) =>
    rects.push(<rect key={k++} x={x} y={14 - (y + h)} width={w} height={h} fill={c} />);
  const sq = p.squash ? 1 : 0, b = 2 - sq + (p.squash ? 0 : p.bob), bodyH = 6 - sq;
  [3, 5, 9, 11].forEach((x, i) => {
    const lifted = (p.legs === 1 && (i === 0 || i === 3)) || (p.legs === 2 && (i === 1 || i === 2));
    if (p.squash) { if (!lifted) R(x, 0, 1, 1, p.color); }
    else if (lifted) R(x, 1, 1, 1, p.color);
    else R(x, 0, 1, 2, p.color);
  });
  R(2, b, 11, bodyH, p.color);
  R(0, b + 1 + p.armL, 2, 2, p.color);
  R(13, b + 1 + p.armR, 2, 2, p.color);
  if (p.armL > 1) R(1, b + 1, 1, p.armL + 2, p.color);
  if (p.armR > 1) R(13, b + 1, 1, p.armR + 2, p.color);
  const ey = b + 2 + p.eyeLift;
  for (const ex of [4 + p.eyeShift, 10 + p.eyeShift]) {
    if (p.eyes === 'open') R(ex, ey, 1, 2, INK);
    if (p.eyes === 'blink') R(ex, ey, 1, 1, INK);
    if (p.eyes === 'wide') R(ex, ey, 2, 3, INK);
    if (p.eyes === 'happy') { R(ex - 1, ey, 1, 1, INK); R(ex, ey + 1, 1, 1, INK); R(ex + 1, ey, 1, 1, INK); }
    if (p.eyes === 'sleep') R(ex - 1, ey, 3, 1, INK);
  }
  return (
    <svg viewBox="0 0 15 14" width={size} height={(size * 14) / 15} shapeRendering="crispEdges" style={{display: 'block', overflow: 'visible', ...style}}>
      {rects}
    </svg>
  );
};
