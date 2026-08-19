import React from 'react';
import { Icon } from './Icon.jsx';
import { Icon3D, resolveIcon3D } from './Icon3D.jsx';

/** Large navigational tile: icon chip, title, description, "Open →" action. */
export function FeatureCard({ icon, title, description, actionLabel = 'Open', tone = 'cyan', onOpen, style }) {
  const wells = {
    cyan: { bg: 'var(--ml-well-cyan)', fg: 'var(--accent)' },
    amber: { bg: 'var(--ml-well-amber)', fg: 'var(--ml-orange-600)' },
    green: { bg: 'var(--ml-well-green)', fg: 'var(--ml-green-600)' },
    blue: { bg: 'var(--ml-well-blue)', fg: 'var(--ml-blue-600)' },
  };
  const w = wells[tone] || wells.cyan;
  const three = resolveIcon3D(icon);
  return (
    <div style={{
      background: 'var(--surface-card)', border: '1px solid var(--border-card)',
      borderRadius: 'var(--radius-xl)', boxShadow: 'var(--shadow-sm)', padding: 22,
      display: 'flex', flexDirection: 'column', gap: 14, boxSizing: 'border-box', ...style,
    }}>
      <div style={{ width: 54, height: 54, borderRadius: 16, background: three ? 'transparent' : w.bg, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        {three ? <Icon3D name={three} size={50} /> : <Icon name={icon} size={26} color={w.fg} />}
      </div>
      <div style={{ fontSize: 19, fontWeight: 800, color: 'var(--text-strong)', letterSpacing: '-0.01em' }}>{title}</div>
      <div style={{ fontSize: 14, color: 'var(--text-muted)', lineHeight: 1.5, flex: 1 }}>{description}</div>
      <button
        type="button"
        onClick={onOpen}
        style={{
          alignSelf: 'flex-start', display: 'inline-flex', alignItems: 'center', gap: 8,
          padding: '9px 16px', borderRadius: 'var(--radius-md)', border: '1px solid var(--border-strong)',
          background: 'transparent', color: 'var(--accent)', fontFamily: 'var(--font-sans)',
          fontSize: 14, fontWeight: 700, cursor: 'pointer',
        }}
      >
        {actionLabel}
        <Icon name="arrow_forward" size={17} />
      </button>
    </div>
  );
}
