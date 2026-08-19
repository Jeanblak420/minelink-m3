import React from 'react';
import { Icon } from './Icon.jsx';
import { Icon3D, resolveIcon3D } from './Icon3D.jsx';

/** Compact KPI tile: tinted icon well, label, big value, optional delta. */
export function StatCard({ icon, label, value, unit, delta, deltaDir = 'up', tone = 'cyan', style }) {
  const wells = {
    cyan: { bg: 'var(--ml-well-cyan)', fg: 'var(--accent)' },
    amber: { bg: 'var(--ml-well-amber)', fg: 'var(--ml-orange-600)' },
    green: { bg: 'var(--ml-well-green)', fg: 'var(--ml-green-600)' },
    blue: { bg: 'var(--ml-well-blue)', fg: 'var(--ml-blue-600)' },
  };
  const w = wells[tone] || wells.cyan;
  const up = deltaDir === 'up';
  const three = resolveIcon3D(icon);
  return (
    <div style={{
      background: 'var(--surface-card)', border: '1px solid var(--border-card)',
      borderRadius: 'var(--radius-lg)', boxShadow: 'var(--shadow-sm)', padding: 18,
      display: 'flex', flexDirection: 'column', gap: 12, boxSizing: 'border-box', ...style,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
        <div style={{
          width: 44, height: 44, borderRadius: 13, background: three ? 'transparent' : w.bg,
          display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
        }}>
          {three ? <Icon3D name={three} size={42} /> : <Icon name={icon} size={22} color={w.fg} />}
        </div>
        <div style={{ fontSize: 14, color: 'var(--text-muted)', fontWeight: 500 }}>{label}</div>
      </div>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 4 }}>
        <span style={{ fontSize: 30, fontWeight: 800, color: 'var(--text-strong)', letterSpacing: '-0.01em', lineHeight: 1 }}>{value}</span>
        {unit && <span style={{ fontSize: 18, fontWeight: 800, color: 'var(--text-strong)' }}>{unit}</span>}
      </div>
      {delta && (
        <div style={{ display: 'flex', alignItems: 'center', gap: 4, fontSize: 12.5, color: 'var(--text-muted)' }}>
          <Icon name={up ? 'arrow_outward' : 'south_east'} size={15} color={up ? 'var(--ml-green-600)' : 'var(--status-error-fg)'} />
          <span style={{ color: up ? 'var(--ml-green-600)' : 'var(--status-error-fg)', fontWeight: 700 }}>{delta}</span>
          <span>vs yesterday</span>
        </div>
      )}
    </div>
  );
}
