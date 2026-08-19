import React from 'react';
import { Icon } from '../core/Icon.jsx';

/** Filter/select pill used in table toolbars ("All Clients ▾", "All Routes ▾"). */
export function Select({ label, icon, options = [], value, onChange, style, ...rest }) {
  return (
    <span style={{ position: 'relative', display: 'inline-flex', alignItems: 'center', ...style }}>
      {icon && <span style={{ position: 'absolute', left: 12, pointerEvents: 'none', display: 'flex' }}><Icon name={icon} size={18} color="var(--text-muted)" /></span>}
      <select
        value={value}
        onChange={onChange}
        style={{
          appearance: 'none', WebkitAppearance: 'none',
          padding: icon ? '9px 34px 9px 36px' : '9px 34px 9px 14px',
          background: 'var(--surface-card)', border: '1px solid var(--border-strong)',
          borderRadius: 'var(--radius-md)', fontFamily: 'var(--font-sans)', fontSize: 13.5,
          fontWeight: 600, color: 'var(--text-body)', cursor: 'pointer', outline: 'none',
        }}
        {...rest}
      >
        {label && <option value="">{label}</option>}
        {options.map((o) => (
          <option key={typeof o === 'string' ? o : o.value} value={typeof o === 'string' ? o : o.value}>
            {typeof o === 'string' ? o : o.label}
          </option>
        ))}
      </select>
      <span style={{ position: 'absolute', right: 11, pointerEvents: 'none', display: 'flex' }}>
        <Icon name="expand_more" size={18} color="var(--text-muted)" />
      </span>
    </span>
  );
}
