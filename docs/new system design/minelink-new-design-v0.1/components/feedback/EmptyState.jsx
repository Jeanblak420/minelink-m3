import React from 'react';
import { Icon } from '../core/Icon.jsx';

/** Empty / zero-data state. Icon in a tinted well, title, message, optional action. */
export function EmptyState({ icon = 'inbox', title, message, action, tone = 'slate', style }) {
  const wells = {
    slate: { bg: 'var(--surface-sunken)', fg: 'var(--ml-slate-400)' },
    cyan: { bg: 'var(--ml-well-cyan)', fg: 'var(--accent)' },
    amber: { bg: 'var(--ml-well-amber)', fg: 'var(--ml-orange-600)' },
  };
  const w = wells[tone] || wells.slate;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center', padding: '48px 24px', gap: 6, ...style }}>
      <div style={{ width: 72, height: 72, borderRadius: 20, background: w.bg, display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 8 }}>
        <Icon name={icon} size={36} color={w.fg} />
      </div>
      <div style={{ fontFamily: 'var(--font-sans)', fontSize: 18, fontWeight: 800, color: 'var(--text-strong)' }}>{title}</div>
      {message && <div style={{ fontSize: 14, color: 'var(--text-muted)', maxWidth: 380, lineHeight: 1.5 }}>{message}</div>}
      {action && <div style={{ marginTop: 12 }}>{action}</div>}
    </div>
  );
}
