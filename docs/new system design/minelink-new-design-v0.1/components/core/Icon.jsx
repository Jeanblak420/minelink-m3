import React from 'react';

/**
 * MineLink icon — Material Symbols Rounded, the portal's icon language.
 * The consuming page must load the font once:
 *   <link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Rounded:opsz,wght,FILL,GRAD@24,400,0,0&display=swap" rel="stylesheet">
 *
 * Two looks:
 *   • flat (default)      — single-color glyph for nav, inline, dense UI.
 *   • dimensional         — faux-3D "extruded" glyph: gradient top-light fill,
 *                           stacked depth edge and a soft contact shadow. Pure
 *                           CSS over the same font, so it stays lightweight
 *                           (no WebGL, no image assets) while reading as a
 *                           colorful 3D object. Use for marketing tiles, empty
 *                           states, feature wells, dashboard headers.
 */

// Tone ramps for the dimensional look: top-lit face → shaded base → extruded edges.
export const ICON_TONES = {
  cyan:  { top: '#5fe0f4', bottom: '#0aa3c4', edge: '#067994', edge2: '#055f74' },
  blue:  { top: '#7ea6ff', bottom: '#2f6bef', edge: '#1d4fc4', edge2: '#163c95' },
  green: { top: '#5ceb9a', bottom: '#18ab50', edge: '#108239', edge2: '#0c632c' },
  amber: { top: '#fdd267', bottom: '#f1701b', edge: '#c4530f', edge2: '#97400b' },
  red:   { top: '#fd97a6', bottom: '#e22f33', edge: '#b71f23', edge2: '#8c181b' },
  teal:  { top: '#4ee6d2', bottom: '#108aa4', edge: '#0c6c81', edge2: '#095260' },
  navy:  { top: '#5b7da8', bottom: '#243b5e', edge: '#1a2c46', edge2: '#111e32' },
};

function buildDimensional(size, tone) {
  const t = ICON_TONES[tone] || ICON_TONES.cyan;
  const u = Math.max(0.8, size * 0.05);            // depth unit, scales with size
  const layers = [];
  for (let i = 1; i <= 5; i++) {
    const off = (u * i).toFixed(2);
    layers.push(`${off}px ${off}px 0 ${i <= 2 ? t.edge : t.edge2}`);
  }
  // soft cast/contact shadow under the object
  layers.push(`0 ${(size * 0.16).toFixed(0)}px ${(size * 0.2).toFixed(0)}px rgba(13,26,43,.4)`);
  return {
    backgroundImage: `linear-gradient(158deg, ${t.top} 0%, ${t.bottom} 78%)`,
    WebkitBackgroundClip: 'text',
    backgroundClip: 'text',
    color: 'transparent',
    textShadow: layers.join(', '),
  };
}

export function Icon({
  name,
  size = 22,
  color,
  fill = 0,
  weight = 400,
  dimensional = false,
  tone = 'cyan',
  style,
  ...rest
}) {
  const dim = dimensional ? buildDimensional(size, tone) : null;
  return (
    <span
      className="material-symbols-rounded"
      style={{
        fontFamily: "'Material Symbols Rounded'",
        fontSize: size,
        lineHeight: 1,
        color: color || 'inherit',
        fontVariationSettings: `'FILL' ${dimensional ? 1 : fill}, 'wght' ${weight}, 'GRAD' 0, 'opsz' 24`,
        userSelect: 'none',
        ...(dim || {}),
        ...style,
      }}
      {...rest}
    >
      {name}
    </span>
  );
}
