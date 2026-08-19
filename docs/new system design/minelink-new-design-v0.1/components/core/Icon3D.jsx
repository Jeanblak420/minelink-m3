import React from 'react';
import { Icon } from './Icon.jsx';

/**
 * MineLink Icon3D — the portal's expressive "3D" icon set.
 *
 * Soft-shaded vector icons: smooth gradients, a real thickness/side face and
 * a soft contact shadow give the illusion of a rendered 3D object, but every
 * icon is pure inline SVG — no image assets, no WebGL — so they stay sharp at
 * any size and cost nothing at runtime. Use for marketing tiles, dashboard
 * headers, empty states and feature wells. For dense/inline UI keep the flat
 * `Icon` (Material Symbols).
 *
 *   <Icon3D name="shipment" size={72} />
 *
 * All icons share a 0 0 112 116 canvas and are centered, so a row of mixed
 * icons lines up. `name` falls back to a neutral box if unknown.
 */

const VB = '0 0 112 116';

// shared soft contact shadow under each object
const Shadow = ({ cy = 108, rx = 30, ry = 6, o = 0.28 }) => (
  <ellipse cx="56" cy={cy} rx={rx} ry={ry} fill="#000" opacity={o} />
);

// neutral rounded cube shown when `name` matches nothing in the set
const FALLBACK = (
  <>
    <Shadow rx="28" />
    <defs>
      <linearGradient id="i3-fb" x1="0" y1="0" x2="0.4" y2="1">
        <stop offset="0" stopColor="#a7b6ca" /><stop offset="1" stopColor="#5a6b85" />
      </linearGradient>
    </defs>
    <rect x="26" y="32" width="60" height="60" rx="14" fill="#3a475e" transform="translate(0,5)" />
    <rect x="26" y="30" width="60" height="60" rx="14" fill="url(#i3-fb)" />
    <rect x="40" y="44" width="32" height="7" rx="3.5" fill="#fff" opacity=".3" />
    <rect x="40" y="58" width="20" height="7" rx="3.5" fill="#fff" opacity=".18" />
  </>
);

const ICONS = {
  /* ───────────── SECURITY · shield ───────────── */
  security: (
    <>
      <Shadow rx="26" />
      <defs>
        <linearGradient id="i3-sh" x1="0" y1="0" x2="0.4" y2="1">
          <stop offset="0" stopColor="#5bb4ff" /><stop offset="1" stopColor="#1f63cf" />
        </linearGradient>
        <linearGradient id="i3-shHi" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#fff" stopOpacity=".55" /><stop offset="1" stopColor="#fff" stopOpacity="0" />
        </linearGradient>
      </defs>
      <path d="M56 12 L92 26 V52 C92 82 74 100 56 110 C38 100 20 82 20 52 V26 Z" fill="#163f86" transform="translate(0,5)" />
      <path d="M56 12 L92 26 V52 C92 82 74 100 56 110 C38 100 20 82 20 52 V26 Z" fill="url(#i3-sh)" strokeLinejoin="round" />
      <path d="M56 12 L92 26 V40 C80 35 68 33 56 33 C44 33 32 35 20 40 V26 Z" fill="url(#i3-shHi)" />
      <path d="M41 58 L52 72 L76 43" fill="none" stroke="#c2820a" strokeWidth="10" strokeLinecap="round" strokeLinejoin="round" transform="translate(0,3)" opacity=".5" />
      <path d="M41 58 L52 72 L76 43" fill="none" stroke="#ffce3d" strokeWidth="10" strokeLinecap="round" strokeLinejoin="round" />
    </>
  ),

  /* ───────────── ROUTE · pin ───────────── */
  route: (
    <>
      <Shadow cy="110" rx="20" />
      <defs>
        <linearGradient id="i3-pn" x1="0.2" y1="0" x2="0.7" y2="1">
          <stop offset="0" stopColor="#48e0f4" /><stop offset="1" stopColor="#0792b2" />
        </linearGradient>
      </defs>
      <path d="M56 12 C34 12 18 28 18 50 C18 78 56 110 56 110 C56 110 94 78 94 50 C94 28 78 12 56 12 Z" fill="#075f74" transform="translate(0,4)" />
      <path d="M56 12 C34 12 18 28 18 50 C18 78 56 110 56 110 C56 110 94 78 94 50 C94 28 78 12 56 12 Z" fill="url(#i3-pn)" />
      <circle cx="56" cy="49" r="15" fill="#06485a" />
      <path d="M36 30 C40 21 48 17 57 17" fill="none" stroke="#fff" strokeWidth="6" strokeLinecap="round" opacity=".5" />
    </>
  ),

  /* ───────────── ALERTS · bell ───────────── */
  alerts: (
    <>
      <Shadow rx="28" />
      <defs>
        <linearGradient id="i3-bl" x1="0.2" y1="0" x2="0.6" y2="1">
          <stop offset="0" stopColor="#ffd95e" /><stop offset="1" stopColor="#f0a014" />
        </linearGradient>
      </defs>
      <path d="M56 22 C39 22 30 34 30 52 L30 70 C30 78 26 84 20 88 L92 88 C86 84 82 78 82 70 L82 52 C82 34 73 22 56 22 Z" fill="#c47d0c" transform="translate(0,4)" />
      <circle cx="56" cy="18" r="7" fill="#c47d0c" transform="translate(0,4)" />
      <path d="M56 22 C39 22 30 34 30 52 L30 70 C30 78 26 84 20 88 L92 88 C86 84 82 78 82 70 L82 52 C82 34 73 22 56 22 Z" fill="url(#i3-bl)" />
      <circle cx="56" cy="18" r="7" fill="url(#i3-bl)" />
      <path d="M41 36 C44 29 49 26 56 26" fill="none" stroke="#fff" strokeWidth="6" strokeLinecap="round" opacity=".5" />
      <path d="M46 90 C46 97 50 102 56 102 C62 102 66 97 66 90 Z" fill="#e7eef6" />
    </>
  ),

  /* ───────────── CONTRACT · document ───────────── */
  contract: (
    <>
      <Shadow rx="24" />
      <defs>
        <linearGradient id="i3-dc" x1="0" y1="0" x2="0.3" y2="1">
          <stop offset="0" stopColor="#ffffff" /><stop offset="1" stopColor="#dde6f0" />
        </linearGradient>
      </defs>
      <path d="M32 12 H66 L86 32 V100 C86 104 83 106 80 106 H32 C29 106 27 104 27 100 V18 C27 14 29 12 32 12 Z" fill="#9fb0c4" transform="translate(2,4)" />
      <path d="M30 10 H64 L84 30 V98 C84 102 81 104 78 104 H30 C27 104 25 102 25 98 V16 C25 12 27 10 30 10 Z" fill="url(#i3-dc)" />
      <path d="M64 10 L84 30 H70 C67 30 64 27 64 24 Z" fill="#c3d0df" />
      <rect x="36" y="50" width="38" height="7" rx="3.5" fill="#f1701b" />
      <rect x="36" y="66" width="38" height="7" rx="3.5" fill="#ccd7e3" />
      <rect x="36" y="82" width="24" height="7" rx="3.5" fill="#ccd7e3" />
    </>
  ),

  /* ───────────── INVENTORY · iso box ───────────── */
  inventory: (
    <>
      <Shadow rx="30" />
      <defs>
        <linearGradient id="i3-bxT" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#ffd95e" /><stop offset="1" stopColor="#f7b733" />
        </linearGradient>
        <linearGradient id="i3-bxF" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#f6b22f" /><stop offset="1" stopColor="#e08c14" />
        </linearGradient>
      </defs>
      <path d="M56 22 L92 38 L56 54 L20 38 Z" fill="url(#i3-bxT)" />
      <path d="M20 38 L56 54 V100 L20 84 Z" fill="url(#i3-bxF)" />
      <path d="M92 38 L56 54 V100 L92 84 Z" fill="#c87a0f" />
      <path d="M34 30 L70 46 V58 L62 54.5 V49 L42 40 Z" fill="#fff" opacity=".18" />
    </>
  ),

  /* ───────────── SHIPMENT · truck ───────────── */
  shipment: (
    <>
      <Shadow rx="34" cy="104" />
      <defs>
        <linearGradient id="i3-tkB" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#7ea6ff" /><stop offset="1" stopColor="#3061d8" />
        </linearGradient>
        <linearGradient id="i3-tkC" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#5bd6ee" /><stop offset="1" stopColor="#0a9ec0" />
        </linearGradient>
      </defs>
      {/* trailer box */}
      <rect x="14" y="36" width="52" height="44" rx="7" fill="#274f9e" transform="translate(0,4)" />
      <rect x="14" y="36" width="52" height="44" rx="7" fill="url(#i3-tkB)" />
      <rect x="20" y="42" width="40" height="14" rx="4" fill="#fff" opacity=".18" />
      {/* cab */}
      <path d="M66 80 V52 C66 49 68 47 71 47 H82 L96 64 V80 Z" fill="#0a7e9b" transform="translate(0,4)" />
      <path d="M66 80 V52 C66 49 68 47 71 47 H82 L96 64 V80 Z" fill="url(#i3-tkC)" />
      <path d="M73 53 H81 L90 64 H73 Z" fill="#cdeef6" />
      {/* wheels */}
      <circle cx="34" cy="86" r="11" fill="#1c2740" /><circle cx="34" cy="86" r="4.5" fill="#5b6c8c" />
      <circle cx="82" cy="86" r="11" fill="#1c2740" /><circle cx="82" cy="86" r="4.5" fill="#5b6c8c" />
    </>
  ),

  /* ───────────── WEIGHBRIDGE · balance scale ───────────── */
  weighbridge: (
    <>
      <Shadow rx="26" cy="104" />
      <defs>
        <linearGradient id="i3-sc" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#5ceb9a" /><stop offset="1" stopColor="#16a04c" />
        </linearGradient>
      </defs>
      {/* base + post */}
      <path d="M40 96 H72 C72 90 66 88 56 88 C46 88 40 90 40 96 Z" fill="#0c632c" />
      <rect x="52" y="30" width="8" height="60" rx="3" fill="#138a42" />
      <circle cx="56" cy="28" r="7" fill="url(#i3-sc)" />
      {/* beam */}
      <rect x="20" y="30" width="72" height="8" rx="4" fill="url(#i3-sc)" />
      {/* pans */}
      <path d="M24 36 L34 56 L14 56 Z" fill="#0e7a3a" /><path d="M12 54 H36 C36 62 30 66 24 66 C18 66 12 62 12 54 Z" fill="url(#i3-sc)" />
      <path d="M88 36 L98 56 L78 56 Z" fill="#0e7a3a" /><path d="M76 54 H100 C100 62 94 66 88 66 C82 66 76 62 76 54 Z" fill="url(#i3-sc)" />
    </>
  ),

  /* ───────────── MAP · folded map ───────────── */
  map: (
    <>
      <Shadow rx="32" cy="104" />
      <defs>
        <linearGradient id="i3-mp" x1="0" y1="0" x2="0.3" y2="1">
          <stop offset="0" stopColor="#4ee6d2" /><stop offset="1" stopColor="#0f9aa0" />
        </linearGradient>
      </defs>
      <path d="M16 32 L44 22 L68 32 L96 22 V84 L68 94 L44 84 L16 94 Z" fill="#0c6c72" transform="translate(0,4)" />
      <path d="M16 32 L44 22 L68 32 L96 22 V84 L68 94 L44 84 L16 94 Z" fill="url(#i3-mp)" />
      <path d="M44 22 V84 M68 32 V94" stroke="#0b5a60" strokeWidth="3" opacity=".55" />
      <path d="M56 40 C48 40 42 46 42 53 C42 63 56 76 56 76 C56 76 70 63 70 53 C70 46 64 40 56 40 Z" fill="#fff" opacity=".9" />
      <circle cx="56" cy="53" r="5.5" fill="#0f9aa0" />
    </>
  ),

  /* ───────────── PAYMENT · cards ───────────── */
  payment: (
    <>
      <Shadow rx="32" cy="100" />
      <defs>
        <linearGradient id="i3-cdA" x1="0" y1="0" x2="0.4" y2="1">
          <stop offset="0" stopColor="#7ea6ff" /><stop offset="1" stopColor="#2f6bef" />
        </linearGradient>
        <linearGradient id="i3-cdB" x1="0" y1="0" x2="0.4" y2="1">
          <stop offset="0" stopColor="#fd8090" /><stop offset="1" stopColor="#e02c30" />
        </linearGradient>
      </defs>
      <g transform="rotate(-12 56 60)">
        <rect x="18" y="34" width="76" height="48" rx="9" fill="#1f4fb8" />
        <rect x="18" y="34" width="76" height="48" rx="9" fill="url(#i3-cdA)" />
      </g>
      <g transform="rotate(8 56 60)">
        <rect x="20" y="40" width="76" height="48" rx="9" fill="#b71f23" transform="translate(0,3)" />
        <rect x="20" y="40" width="76" height="48" rx="9" fill="url(#i3-cdB)" />
        <rect x="20" y="50" width="76" height="11" fill="#7c1417" />
        <rect x="30" y="70" width="20" height="8" rx="2" fill="#ffd35e" />
      </g>
    </>
  ),

  /* ───────────── TEAM · people ───────────── */
  team: (
    <>
      <Shadow rx="32" cy="104" />
      <defs>
        <linearGradient id="i3-tmA" x1="0" y1="0" x2="0.4" y2="1">
          <stop offset="0" stopColor="#7ea6ff" /><stop offset="1" stopColor="#2f6bef" />
        </linearGradient>
        <linearGradient id="i3-tmB" x1="0" y1="0" x2="0.4" y2="1">
          <stop offset="0" stopColor="#5fe0f4" /><stop offset="1" stopColor="#0aa3c4" />
        </linearGradient>
      </defs>
      {/* back person */}
      <circle cx="80" cy="44" r="13" fill="url(#i3-tmB)" />
      <path d="M58 96 C58 78 68 70 80 70 C92 70 102 78 102 96 Z" fill="url(#i3-tmB)" />
      {/* front person */}
      <circle cx="44" cy="40" r="16" fill="#1f4fb8" /><circle cx="44" cy="40" r="16" fill="url(#i3-tmA)" />
      <path d="M14 98 C14 76 26 66 44 66 C62 66 74 76 74 98 Z" fill="#1f4fb8" /><path d="M14 98 C14 76 26 66 44 66 C62 66 74 76 74 98 Z" fill="url(#i3-tmA)" />
    </>
  ),

  /* ───────────── SETTINGS · gear ───────────── */
  settings: (
    <>
      <Shadow rx="28" />
      <defs>
        <linearGradient id="i3-gr" x1="0" y1="0" x2="0.4" y2="1">
          <stop offset="0" stopColor="#a7b6ca" /><stop offset="1" stopColor="#5a6b85" />
        </linearGradient>
      </defs>
      {Array.from({ length: 8 }).map((_, i) => (
        <rect key={i} x="50" y="14" width="12" height="22" rx="4" fill="#34435d"
          transform={`rotate(${i * 45} 56 58)`} />
      ))}
      {Array.from({ length: 8 }).map((_, i) => (
        <rect key={'f' + i} x="50" y="12" width="12" height="20" rx="4" fill="url(#i3-gr)"
          transform={`rotate(${i * 45} 56 56)`} />
      ))}
      <circle cx="56" cy="60" r="30" fill="#34435d" />
      <circle cx="56" cy="56" r="30" fill="url(#i3-gr)" />
      <circle cx="56" cy="56" r="13" fill="#2b384e" />
      <path d="M40 44 C44 38 50 35 56 35" fill="none" stroke="#fff" strokeWidth="5" strokeLinecap="round" opacity=".4" />
    </>
  ),

  /* ───────────── DASHBOARD · gauge ───────────── */
  dashboard: (
    <>
      <Shadow rx="30" />
      <defs>
        <linearGradient id="i3-dbF" x1="0" y1="0" x2="0.3" y2="1">
          <stop offset="0" stopColor="#5fe0f4" /><stop offset="1" stopColor="#0aa3c4" />
        </linearGradient>
        <radialGradient id="i3-dbDial" cx="0.4" cy="0.35" r="0.7">
          <stop offset="0" stopColor="#11324a" /><stop offset="1" stopColor="#05202f" />
        </radialGradient>
      </defs>
      <circle cx="56" cy="60" r="42" fill="#067994" />
      <circle cx="56" cy="56" r="42" fill="url(#i3-dbF)" />
      <circle cx="56" cy="56" r="31" fill="url(#i3-dbDial)" />
      {/* ticks */}
      {Array.from({ length: 9 }).map((_, i) => {
        const a = (-210 + i * 30) * Math.PI / 180;
        const r1 = 28, r2 = 22;
        return (
          <line key={i} x1={56 + r1 * Math.cos(a)} y1={56 + r1 * Math.sin(a)}
            x2={56 + r2 * Math.cos(a)} y2={56 + r2 * Math.sin(a)}
            stroke="#5fe0f4" strokeWidth="2.5" strokeLinecap="round" opacity=".8" />
        );
      })}
      {/* needle */}
      <line x1="56" y1="56" x2="74" y2="42" stroke="#ffce3d" strokeWidth="4.5" strokeLinecap="round" />
      <circle cx="56" cy="56" r="6" fill="#ffce3d" />
    </>
  ),

  /* ───────────── COMPANIES · office building ───────────── */
  companies: (
    <>
      <Shadow rx="28" />
      <defs>
        <linearGradient id="i3-coF" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#5fe0f4" /><stop offset="1" stopColor="#0aa3c4" />
        </linearGradient>
        <linearGradient id="i3-coS" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#0a93b3" /><stop offset="1" stopColor="#067088" />
        </linearGradient>
      </defs>
      <rect x="22" y="30" width="40" height="72" rx="6" fill="#067488" transform="translate(0,4)" />
      <rect x="22" y="30" width="40" height="72" rx="6" fill="url(#i3-coF)" />
      <rect x="60" y="50" width="30" height="52" rx="6" fill="url(#i3-coS)" />
      {[40, 56, 72].map((y) => [29, 41, 53].map((x) => (
        <rect key={x + '-' + y} x={x} y={y} width="8" height="8" rx="2" fill="#eafaff" opacity=".9" />
      )))}
      {[62, 76].map((y) => [66, 78].map((x) => (
        <rect key={'s' + x + '-' + y} x={x} y={y} width="7" height="7" rx="2" fill="#d6f3fa" opacity=".75" />
      )))}
    </>
  ),

  /* ───────────── MINE · ore mountain + dig ───────────── */
  mine: (
    <>
      <Shadow rx="32" cy="104" />
      <defs>
        <linearGradient id="i3-mnF" x1="0" y1="0" x2="0.3" y2="1">
          <stop offset="0" stopColor="#a7b6ca" /><stop offset="1" stopColor="#5a6b85" />
        </linearGradient>
      </defs>
      <path d="M14 96 L44 40 L62 70 L78 50 L98 96 Z" fill="#46566e" transform="translate(0,4)" />
      <path d="M14 96 L44 40 L62 70 L78 50 L98 96 Z" fill="url(#i3-mnF)" />
      <path d="M44 40 L52 53 L44 58 L37 50 Z" fill="#eef3f9" opacity=".9" />
      <path d="M78 50 L86 63 L74 66 L70 58 Z" fill="#eef3f9" opacity=".75" />
      <circle cx="50" cy="86" r="7" fill="#ffce3d" />
      <circle cx="64" cy="90" r="5" fill="#f1a814" />
      <circle cx="57" cy="94" r="4" fill="#ffce3d" />
    </>
  ),

  /* ───────────── TOKEN · key ───────────── */
  token: (
    <>
      <Shadow rx="26" />
      <defs>
        <linearGradient id="i3-tk" x1="0.2" y1="0" x2="0.7" y2="1">
          <stop offset="0" stopColor="#5ceb9a" /><stop offset="1" stopColor="#16a04c" />
        </linearGradient>
      </defs>
      <circle cx="42" cy="44" r="24" fill="#0e7a3a" transform="translate(0,4)" />
      <circle cx="42" cy="44" r="24" fill="url(#i3-tk)" />
      <circle cx="42" cy="44" r="10" fill="#0c632c" />
      <path d="M28 32 C31 26 37 23 43 23" fill="none" stroke="#fff" strokeWidth="5" strokeLinecap="round" opacity=".5" />
      <path d="M58 60 L86 88 L78 96 L72 90 L66 96 L60 90 L54 96 L50 92 Z" fill="#0e7a3a" transform="translate(2,2)" />
      <path d="M56 58 L84 86 L76 94 L70 88 L64 94 L58 88 L52 94 L48 90 Z" fill="url(#i3-tk)" />
    </>
  ),

  /* ───────────── WARNING · triangle ───────────── */
  warning: (
    <>
      <Shadow rx="30" cy="104" />
      <defs>
        <linearGradient id="i3-wn" x1="0.2" y1="0" x2="0.6" y2="1">
          <stop offset="0" stopColor="#ffd95e" /><stop offset="1" stopColor="#f0701b" />
        </linearGradient>
      </defs>
      <path d="M56 16 C60 16 63 18 65 22 L100 90 C103 96 99 102 92 102 L20 102 C13 102 9 96 12 90 L47 22 C49 18 52 16 56 16 Z" fill="#c4530f" transform="translate(0,4)" />
      <path d="M56 16 C60 16 63 18 65 22 L100 90 C103 96 99 102 92 102 L20 102 C13 102 9 96 12 90 L47 22 C49 18 52 16 56 16 Z" fill="url(#i3-wn)" />
      <path d="M50 24 C52 21 60 21 62 24 L66 34 L46 34 Z" fill="#fff" opacity=".4" />
      <rect x="50" y="44" width="12" height="30" rx="6" fill="#7c3a08" />
      <circle cx="56" cy="86" r="7" fill="#7c3a08" />
    </>
  ),

  /* ───────────── ENERGY · lightning bolt ───────────── */
  energy: (
    <>
      <Shadow rx="22" cy="106" />
      <defs>
        <linearGradient id="i3-en" x1="0.2" y1="0" x2="0.7" y2="1">
          <stop offset="0" stopColor="#7ea6ff" /><stop offset="1" stopColor="#2f6bef" />
        </linearGradient>
      </defs>
      <path d="M62 10 L30 62 L50 62 L44 104 L84 48 L62 48 Z" fill="#1d4fc4" transform="translate(2,3)" />
      <path d="M62 10 L30 62 L50 62 L44 104 L84 48 L62 48 Z" fill="url(#i3-en)" />
      <path d="M60 16 L38 52" fill="none" stroke="#fff" strokeWidth="5" strokeLinecap="round" opacity=".45" />
    </>
  ),

  /* ───────────── DRIVER · steering wheel ───────────── */
  driver: (
    <>
      <Shadow rx="30" />
      <defs>
        <linearGradient id="i3-drv" x1="0" y1="0" x2="0.4" y2="1">
          <stop offset="0" stopColor="#7ea6ff" /><stop offset="1" stopColor="#2f6bef" />
        </linearGradient>
      </defs>
      <circle cx="56" cy="60" r="42" fill="#1f4fb8" />
      <circle cx="56" cy="56" r="42" fill="url(#i3-drv)" />
      <circle cx="56" cy="56" r="27" fill="#14356e" />
      <circle cx="56" cy="56" r="11" fill="url(#i3-drv)" />
      {[90, 210, 330].map((a) => (
        <rect key={a} x="56" y="52" width="30" height="8" rx="4" fill="url(#i3-drv)" transform={`rotate(${a} 56 56)`} />
      ))}
      <path d="M34 40 C40 32 47 29 55 29" fill="none" stroke="#fff" strokeWidth="5" strokeLinecap="round" opacity=".4" />
    </>
  ),

  /* ───────────── SUPERVISOR · hard hat ───────────── */
  supervisor: (
    <>
      <Shadow rx="30" cy="104" />
      <defs>
        <linearGradient id="i3-sv" x1="0.2" y1="0" x2="0.6" y2="1">
          <stop offset="0" stopColor="#ffd95e" /><stop offset="1" stopColor="#f0a014" />
        </linearGradient>
      </defs>
      <path d="M22 82 C22 52 34 36 56 36 C78 36 90 52 90 82 Z" fill="#b9760a" transform="translate(0,5)" />
      <path d="M14 80 Q56 96 98 80 L98 86 Q56 102 14 86 Z" fill="#c47d0c" transform="translate(0,4)" />
      <path d="M14 80 Q56 96 98 80 L98 86 Q56 102 14 86 Z" fill="url(#i3-sv)" />
      <path d="M22 82 C22 52 34 36 56 36 C78 36 90 52 90 82 Z" fill="url(#i3-sv)" />
      <rect x="51" y="36" width="10" height="46" rx="5" fill="#fff" opacity=".28" />
      <rect x="34" y="46" width="7" height="36" rx="3.5" fill="#c47d0c" opacity=".5" />
      <rect x="71" y="46" width="7" height="36" rx="3.5" fill="#c47d0c" opacity=".5" />
      <path d="M34 52 C39 44 46 40 54 40" fill="none" stroke="#fff" strokeWidth="5" strokeLinecap="round" opacity=".45" />
    </>
  ),

  /* ───────────── BUYER · storefront ───────────── */
  buyer: (
    <>
      <Shadow rx="30" />
      <defs>
        <linearGradient id="i3-buyB" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#5fe0f4" /><stop offset="1" stopColor="#0aa3c4" />
        </linearGradient>
        <linearGradient id="i3-buyA" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#7fe9f8" /><stop offset="1" stopColor="#22bcd8" />
        </linearGradient>
      </defs>
      <rect x="24" y="48" width="64" height="54" rx="7" fill="#067488" transform="translate(0,4)" />
      <rect x="24" y="48" width="64" height="54" rx="7" fill="url(#i3-buyB)" />
      <rect x="46" y="66" width="20" height="36" rx="3" fill="#06485a" />
      <rect x="31" y="60" width="12" height="14" rx="2" fill="#d6f6fb" opacity=".85" />
      <rect x="69" y="60" width="12" height="14" rx="2" fill="#d6f6fb" opacity=".7" />
      <path d="M16 46 L26 28 H86 L96 46 Z" fill="#0a93b3" transform="translate(0,3)" />
      <path d="M16 46 L26 28 H86 L96 46 Z" fill="url(#i3-buyA)" />
      <path d="M26 28 H86 L83 40 H29 Z" fill="#fff" opacity=".18" />
    </>
  ),

  /* ───────────── CONSOLE · super-admin control panel ───────────── */
  console: (
    <>
      <Shadow rx="30" cy="104" />
      <defs>
        <linearGradient id="i3-cnF" x1="0" y1="0" x2="0.3" y2="1">
          <stop offset="0" stopColor="#7ea6ff" /><stop offset="1" stopColor="#2f6bef" />
        </linearGradient>
      </defs>
      <rect x="46" y="82" width="20" height="16" fill="#22407e" />
      <rect x="34" y="94" width="44" height="9" rx="4.5" fill="#22407e" />
      <rect x="16" y="24" width="80" height="62" rx="11" fill="#1f4fb8" transform="translate(0,4)" />
      <rect x="16" y="24" width="80" height="62" rx="11" fill="url(#i3-cnF)" />
      <rect x="25" y="33" width="62" height="44" rx="6" fill="#12325a" />
      <rect x="33" y="43" width="46" height="6" rx="3" fill="#3a63c9" />
      <circle cx="66" cy="46" r="6" fill="#ffce3d" />
      <rect x="33" y="58" width="46" height="6" rx="3" fill="#3a63c9" />
      <circle cx="45" cy="61" r="6" fill="#5fe0f4" />
      <path d="M24 34 C28 30 34 28 40 28" fill="none" stroke="#fff" strokeWidth="4" strokeLinecap="round" opacity=".4" />
    </>
  ),

  /* ───────────── STOCKPILE · ore heap ───────────── */
  stockpile: (
    <>
      <Shadow rx="34" cy="104" />
      <defs>
        <linearGradient id="i3-stkF" x1="0" y1="0" x2="0.3" y2="1">
          <stop offset="0" stopColor="#ffd95e" /><stop offset="1" stopColor="#e08c14" />
        </linearGradient>
      </defs>
      <path d="M56 30 L96 96 L16 96 Z" fill="#c87a0f" transform="translate(0,4)" />
      <path d="M56 30 L96 96 L16 96 Z" fill="url(#i3-stkF)" />
      <path d="M56 30 L96 96 L56 96 Z" fill="#c87a0f" opacity=".42" />
      <path d="M56 30 L45 62" fill="none" stroke="#fff" strokeWidth="5" strokeLinecap="round" opacity=".4" />
      <circle cx="43" cy="86" r="6" fill="#fff" opacity=".22" />
      <circle cx="67" cy="88" r="5" fill="#7c4a08" opacity=".3" />
    </>
  ),

  /* ───────────── ACTIVE · check badge ───────────── */
  active: (
    <>
      <Shadow rx="28" />
      <defs>
        <linearGradient id="i3-act" x1="0.2" y1="0" x2="0.6" y2="1">
          <stop offset="0" stopColor="#5ceb9a" /><stop offset="1" stopColor="#16a04c" />
        </linearGradient>
      </defs>
      <circle cx="56" cy="60" r="40" fill="#0e7a3a" transform="translate(0,4)" />
      <circle cx="56" cy="56" r="40" fill="url(#i3-act)" />
      <path d="M38 58 L50 71 L76 43" fill="none" stroke="#0c632c" strokeWidth="11" strokeLinecap="round" strokeLinejoin="round" transform="translate(0,3)" opacity=".35" />
      <path d="M38 58 L50 71 L76 43" fill="none" stroke="#fff" strokeWidth="11" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M40 42 C44 36 50 33 56 33" fill="none" stroke="#fff" strokeWidth="5" strokeLinecap="round" opacity=".4" />
    </>
  ),

  /* ───────────── EXPIRED · clock ───────────── */
  expired: (
    <>
      <Shadow rx="28" />
      <defs>
        <linearGradient id="i3-exp" x1="0.2" y1="0" x2="0.6" y2="1">
          <stop offset="0" stopColor="#ffd95e" /><stop offset="1" stopColor="#f0a014" />
        </linearGradient>
      </defs>
      <rect x="49" y="12" width="14" height="9" rx="3" fill="#c47d0c" transform="translate(0,4)" />
      <circle cx="56" cy="60" r="40" fill="#c47d0c" transform="translate(0,4)" />
      <rect x="49" y="12" width="14" height="9" rx="3" fill="url(#i3-exp)" />
      <circle cx="56" cy="56" r="40" fill="url(#i3-exp)" />
      <circle cx="56" cy="56" r="29" fill="#7c4a08" opacity=".22" />
      <rect x="53" y="34" width="6" height="26" rx="3" fill="#7c4a08" />
      <rect x="55" y="53" width="20" height="6" rx="3" fill="#7c4a08" />
      <circle cx="56" cy="56" r="5" fill="#7c4a08" />
      <path d="M36 40 C40 33 47 30 54 30" fill="none" stroke="#fff" strokeWidth="5" strokeLinecap="round" opacity=".4" />
    </>
  ),

  /* ───────────── SUSPENDED · no-entry ───────────── */
  suspended: (
    <>
      <Shadow rx="28" />
      <defs>
        <linearGradient id="i3-sus" x1="0.2" y1="0" x2="0.6" y2="1">
          <stop offset="0" stopColor="#fd8090" /><stop offset="1" stopColor="#e02c30" />
        </linearGradient>
      </defs>
      <circle cx="56" cy="60" r="40" fill="#b71f23" transform="translate(0,4)" />
      <circle cx="56" cy="56" r="40" fill="url(#i3-sus)" />
      <circle cx="56" cy="56" r="26" fill="none" stroke="#fff" strokeWidth="9" opacity=".92" />
      <rect x="34" y="51" width="44" height="10" rx="5" fill="#fff" transform="rotate(-45 56 56)" />
      <path d="M36 40 C40 33 47 30 54 30" fill="none" stroke="#fff" strokeWidth="5" strokeLinecap="round" opacity=".3" />
    </>
  ),

  /* ───────────── HISTORY · timeline / logs ───────────── */
  history: (
    <>
      <Shadow rx="26" />
      <defs>
        <linearGradient id="i3-his" x1="0" y1="0" x2="0.3" y2="1">
          <stop offset="0" stopColor="#a7b6ca" /><stop offset="1" stopColor="#5a6b85" />
        </linearGradient>
      </defs>
      <rect x="24" y="24" width="64" height="72" rx="12" fill="#34435d" transform="translate(2,4)" />
      <rect x="22" y="22" width="64" height="72" rx="12" fill="url(#i3-his)" />
      <rect x="36" y="36" width="4" height="46" rx="2" fill="#2b384e" opacity=".5" />
      {[40, 58, 76].map((y, i) => (
        <React.Fragment key={y}>
          <circle cx="38" cy={y} r="6" fill={i === 0 ? '#ffce3d' : '#dbe3ee'} />
          <rect x="50" y={y - 4} width={i === 2 ? 20 : 28} height="7" rx="3.5" fill="#dbe3ee" opacity=".85" />
        </React.Fragment>
      ))}
      <path d="M32 32 C36 28 42 26 48 26" fill="none" stroke="#fff" strokeWidth="4" strokeLinecap="round" opacity=".35" />
    </>
  ),

  /* ───────────── REGISTER · add company ───────────── */
  register: (
    <>
      <Shadow rx="28" />
      <defs>
        <linearGradient id="i3-regF" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#5fe0f4" /><stop offset="1" stopColor="#0aa3c4" /></linearGradient>
        <linearGradient id="i3-regP" x1="0" y1="0" x2="0.4" y2="1"><stop offset="0" stopColor="#5ceb9a" /><stop offset="1" stopColor="#16a04c" /></linearGradient>
      </defs>
      <rect x="22" y="30" width="46" height="72" rx="7" fill="#067488" transform="translate(0,4)" />
      <rect x="22" y="30" width="46" height="72" rx="7" fill="url(#i3-regF)" />
      {[42, 58, 74].map((y) => [29, 45].map((x) => (
        <rect key={x + '-' + y} x={x} y={y} width="9" height="9" rx="2" fill="#eafaff" opacity=".9" />
      )))}
      <circle cx="80" cy="76" r="20" fill="#0e7a3a" transform="translate(0,3)" />
      <circle cx="80" cy="73" r="20" fill="url(#i3-regP)" />
      <rect x="76" y="64" width="8" height="18" rx="4" fill="#fff" />
      <rect x="71" y="69" width="18" height="8" rx="4" fill="#fff" />
    </>
  ),

  /* ───────────── EXPORT · open / manage ───────────── */
  export: (
    <>
      <Shadow rx="26" />
      <defs>
        <linearGradient id="i3-exF" x1="0" y1="0" x2="0.3" y2="1"><stop offset="0" stopColor="#5fe0f4" /><stop offset="1" stopColor="#0aa3c4" /></linearGradient>
      </defs>
      <rect x="22" y="36" width="56" height="56" rx="13" fill="#067488" transform="translate(0,5)" />
      <rect x="22" y="36" width="56" height="56" rx="13" fill="url(#i3-exF)" />
      <rect x="32" y="46" width="36" height="36" rx="8" fill="#06485a" />
      <rect x="56" y="46" width="44" height="10" rx="5" fill="#ffce3d" transform="rotate(-45 78 51)" />
      <path d="M64 28 L94 28 L94 58" fill="none" stroke="#ffce3d" strokeWidth="9" strokeLinecap="round" strokeLinejoin="round" />
    </>
  ),
};

export const ICON3D_NAMES = Object.keys(ICONS);

/**
 * Maps the portal's flat Material Symbols names to the nearest Icon3D concept,
 * so display surfaces (feature/stat wells, section headers) can auto-upgrade to
 * the 3D set. Functional glyphs with no 3D equivalent (add, search, chevrons,
 * download, person, key, warning…) are intentionally absent → callers keep the
 * flat `Icon` for those.
 */
export const ICON3D_ALIASES = {
  local_shipping: 'shipment', truck: 'shipment', fire_truck: 'shipment',
  alt_route: 'route', route: 'route', directions: 'route', fork_right: 'route',
  balance: 'weighbridge', scale: 'weighbridge', monitor_weight: 'weighbridge',
  map: 'map', place: 'map', location_on: 'map', my_location: 'map', pin_drop: 'map',
  inventory_2: 'inventory', inventory: 'inventory', package_2: 'inventory', widgets: 'inventory',
  groups: 'team', group: 'team', people: 'team', diversity_3: 'team',
  admin_panel_settings: 'settings', tune: 'settings', settings: 'settings', manage_accounts: 'settings',
  security: 'security', shield: 'security', verified_user: 'security', gpp_good: 'security', lock: 'security',
  description: 'contract', article: 'contract', assignment: 'contract', handshake: 'contract', receipt_long: 'contract',
  dashboard: 'dashboard', space_dashboard: 'dashboard', speed: 'dashboard', monitoring: 'dashboard',
  notifications: 'alerts', notifications_active: 'alerts', campaign: 'alerts',
  payments: 'payment', payment: 'payment', credit_card: 'payment', paid: 'payment',
  apartment: 'companies', business: 'companies', domain: 'companies', corporate_fare: 'companies',
  conveyor_belt: 'mine', factory: 'mine', landscape: 'mine', terrain: 'mine', diamond: 'mine',
  key: 'token', vpn_key: 'token', password: 'token', token: 'token',
  warning: 'warning', error: 'warning', report: 'warning', priority_high: 'warning', gpp_maybe: 'warning',
  bolt: 'energy', flash_on: 'energy', electric_bolt: 'energy', flash: 'energy',

  /* ── people / roles ── */
  badge: 'driver', directions_car: 'driver', local_taxi: 'driver', drive_eta: 'driver', airport_shuttle: 'driver', no_crash: 'driver',
  engineering: 'supervisor', construction: 'supervisor', hard_hat: 'supervisor', foreman: 'supervisor', supervisor_account: 'supervisor', precision_manufacturing: 'supervisor',
  // Load Controllers work at the weighbridge → reuse the scale concept.
  forklift: 'weighbridge', pallet: 'weighbridge',
  /* ── org types / commerce ── */
  storefront: 'buyer', shopping_bag: 'buyer', store: 'buyer', shopping_cart: 'buyer', local_mall: 'buyer', business_center: 'buyer',
  /* ── super-admin / platform console ── */
  dns: 'console', terminal: 'console', account_tree: 'console', developer_board: 'console', hub: 'console', memory: 'console', settings_applications: 'console', shield_person: 'console',
  /* ── stockpile / ore ── */
  stockpile: 'stockpile', grain: 'stockpile', dataset: 'stockpile',
  /* ── status / state counts ── */
  check_circle: 'active', task_alt: 'active', done_all: 'active', verified_user: 'active',
  timer_off: 'expired', timer: 'expired', hourglass_bottom: 'expired', hourglass_empty: 'expired', history_toggle_off: 'expired',
  block: 'suspended', do_not_disturb_on: 'suspended', cancel: 'suspended', remove_circle: 'suspended', gpp_bad: 'suspended',
  /* ── utility ── */
  history: 'history', restore: 'history', timeline: 'history', manage_history: 'history', schedule_send: 'history',
  add_business: 'register', domain_add: 'register', add_home_work: 'register',
  open_in_new: 'export', launch: 'export', ios_share: 'export', open_in_full: 'export',
};

/**
 * Resolve any icon name to an Icon3D concept: returns the concept for a flat
 * Material Symbols alias (`business` → `companies`), passes through a direct
 * Icon3D name (`buyer` → `buyer`), or `null` when there is no 3D equivalent.
 * Display primitives (StatCard, FeatureCard, IconWell) use this to auto-upgrade.
 * When the platform icon mode is switched to 'fallback' it returns null, so
 * every display well falls back to its flat Material Symbols icon.
 */
export function resolveIcon3D(name) {
  if (!name) return null;
  if (typeof window !== 'undefined' && window.MLIconMode === 'fallback') return null;
  if (ICON3D_ALIASES[name]) return ICON3D_ALIASES[name];
  return ICON3D_NAMES.includes(name) ? name : null;
}

/**
 * FALLBACK ICON SET — the flat Material Symbols the portals used before the
 * expressive Icon3D set. Saved on purpose: the platform can switch back to
 * these thin-line icons on request via `window.MLIcons.setMode('fallback')`
 * (default mode is '3d'). Each concept maps to the Material Symbols glyph that
 * best represents it. Nothing uses these unless the mode is switched.
 */
export const ICON3D_FALLBACK = {
  security: 'shield', route: 'alt_route', alerts: 'notifications', contract: 'description',
  inventory: 'inventory_2', shipment: 'local_shipping', weighbridge: 'monitor_weight',
  map: 'map', payment: 'payments', team: 'groups', settings: 'settings', dashboard: 'space_dashboard',
  companies: 'apartment', mine: 'terrain', token: 'vpn_key', warning: 'warning', energy: 'bolt',
  driver: 'badge', supervisor: 'engineering', buyer: 'storefront', console: 'admin_panel_settings',
  stockpile: 'grain', active: 'check_circle', expired: 'timer', suspended: 'block',
  history: 'history', register: 'add_business', export: 'open_in_new',
};

/* Platform icon mode ('3d' default | 'fallback'), persisted, off until asked. */
if (typeof window !== 'undefined') {
  if (!window.MLIconMode) {
    try { window.MLIconMode = (window.localStorage && localStorage.getItem('ml-icon-mode')) || '3d'; } catch (e) { window.MLIconMode = '3d'; }
  }
  window.MLIcons = window.MLIcons || {
    get: function () { return window.MLIconMode; },
    setMode: function (m) { try { localStorage.setItem('ml-icon-mode', m); } catch (e) {} window.MLIconMode = m; if (typeof location !== 'undefined') location.reload(); },
  };
}

export function Icon3D({ name, size = 72, title, style, ...rest }) {
  // Fallback mode: render the saved flat Material Symbols icon in place.
  if (typeof window !== 'undefined' && window.MLIconMode === 'fallback') {
    const flat = ICON3D_FALLBACK[name] || (ICON3D_ALIASES[name] ? ICON3D_FALLBACK[ICON3D_ALIASES[name]] : null) || name;
    return <Icon name={flat} size={Math.round(size * 0.62)} title={title || name} style={style} {...rest} />;
  }
  const glyph = ICONS[name] || FALLBACK;
  return (
    <svg
      width={size}
      height={(size * 116) / 112}
      viewBox={VB}
      role="img"
      aria-label={title || name}
      style={{ display: 'block', overflow: 'visible', filter: 'drop-shadow(0 12px 14px rgba(8,18,30,.28))', ...style }}
      {...rest}
    >
      {title ? <title>{title}</title> : null}
      {glyph}
    </svg>
  );
}
