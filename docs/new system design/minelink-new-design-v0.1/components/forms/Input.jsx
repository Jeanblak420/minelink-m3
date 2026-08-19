import React from 'react';
import { Icon } from '../core/Icon.jsx';

/** Labelled text input matching the portal's filled-field style. */
export function Input({ label, hint, required, icon, error, style, ...rest }) {
  return (
    <label style={{ display: 'flex', flexDirection: 'column', gap: 7, fontFamily: 'var(--font-sans)', ...style }}>
      {label && (
        <span style={{ fontSize: 14, fontWeight: 600, color: 'var(--text-body)' }}>
          {label}{required && <span style={{ color: 'var(--status-error-fg)' }}> *</span>}
        </span>
      )}
      <span style={{ position: 'relative', display: 'flex', alignItems: 'center' }}>
        {icon && (
          <span style={{ position: 'absolute', left: 14, display: 'flex', pointerEvents: 'none' }}>
            <Icon name={icon} size={20} color="var(--text-faint)" />
          </span>
        )}
        <input
          style={{
            width: '100%', boxSizing: 'border-box',
            padding: icon ? '13px 14px 13px 44px' : '13px 14px',
            background: 'var(--surface-sunken)',
            border: `1.5px solid ${error ? 'var(--status-error-fg)' : 'transparent'}`,
            borderRadius: 'var(--radius-md)',
            fontFamily: 'var(--font-sans)', fontSize: 15, color: 'var(--text-strong)',
            outline: 'none', transition: 'border-color var(--dur-fast) var(--ease-out), background var(--dur-fast)',
          }}
          onFocus={(e) => { e.target.style.borderColor = 'var(--accent)'; e.target.style.background = 'var(--surface-card)'; }}
          onBlur={(e) => { e.target.style.borderColor = error ? 'var(--status-error-fg)' : 'transparent'; e.target.style.background = 'var(--surface-sunken)'; }}
          {...rest}
        />
      </span>
      {(error || hint) && (
        <span style={{ fontSize: 12.5, color: error ? 'var(--status-error-fg)' : 'var(--text-muted)' }}>{error || hint}</span>
      )}
    </label>
  );
}
