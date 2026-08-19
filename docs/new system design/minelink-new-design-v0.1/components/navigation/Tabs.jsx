import React from 'react';
import { Icon } from '../core/Icon.jsx';

/** Tabs. variant: underline | pill. tabs: [{key,label,icon,badge}]. */
export function Tabs({ tabs = [], active, onChange, variant = 'underline', style }) {
  if (variant === 'pill') {
    return (
      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', ...style }}>
        {tabs.map((t) => {
          const sel = t.key === active;
          return (
            <button key={t.key} type="button" onClick={() => onChange && onChange(t.key)}
              style={{
                display: 'inline-flex', alignItems: 'center', gap: 8, padding: '9px 16px', borderRadius: 'var(--radius-pill)',
                cursor: 'pointer', fontFamily: 'var(--font-sans)', fontSize: 13.5, fontWeight: 700,
                border: `1px solid ${sel ? 'var(--accent)' : 'var(--border-strong)'}`,
                background: sel ? 'var(--accent)' : 'var(--surface-card)', color: sel ? '#fff' : 'var(--text-body)',
                transition: 'background var(--dur-fast)',
              }}
            >
              {t.icon && <Icon name={t.icon} size={17} fill={sel ? 1 : 0} color={sel ? '#fff' : 'var(--text-muted)'} />}
              {t.label}
              {t.badge != null && <span style={{ fontFamily: 'var(--font-mono)', fontSize: 11.5, padding: '1px 6px', borderRadius: 999, background: sel ? 'rgba(255,255,255,.22)' : 'var(--surface-sunken)', color: sel ? '#fff' : 'var(--text-muted)' }}>{t.badge}</span>}
            </button>
          );
        })}
      </div>
    );
  }
  // underline
  return (
    <div style={{ display: 'flex', gap: 4, borderBottom: '1px solid var(--divider)', ...style }}>
      {tabs.map((t) => {
        const sel = t.key === active;
        return (
          <button key={t.key} type="button" onClick={() => onChange && onChange(t.key)}
            style={{
              display: 'inline-flex', alignItems: 'center', gap: 8, padding: '12px 16px', border: 'none', background: 'transparent',
              cursor: 'pointer', fontFamily: 'var(--font-sans)', fontSize: 14, fontWeight: sel ? 700 : 500,
              color: sel ? 'var(--accent)' : 'var(--text-muted)', borderBottom: `2.5px solid ${sel ? 'var(--accent)' : 'transparent'}`,
              marginBottom: -1, transition: 'color var(--dur-fast)',
            }}
          >
            {t.icon && <Icon name={t.icon} size={18} fill={sel ? 1 : 0} />}
            {t.label}
            {t.badge != null && <span style={{ fontSize: 11, fontWeight: 800, padding: '1px 6px', borderRadius: 999, background: sel ? 'var(--ml-well-cyan)' : 'var(--surface-sunken)', color: sel ? 'var(--accent)' : 'var(--text-muted)' }}>{t.badge}</span>}
          </button>
        );
      })}
    </div>
  );
}
