import React from 'react';
import { Icon } from '../core/Icon.jsx';

const TOAST = {
  success: { icon: 'check_circle', fg: 'var(--ml-green-600)', bar: 'var(--ml-green-600)' },
  error: { icon: 'error', fg: 'var(--ml-red-600)', bar: 'var(--ml-red-600)' },
  warn: { icon: 'warning', fg: 'var(--ml-orange-600)', bar: 'var(--ml-orange-500)' },
  info: { icon: 'info', fg: 'var(--accent)', bar: 'var(--accent)' },
};

/** Single toast / snackbar. Dark navy surface, colored leading icon, optional action + undo. */
export function Toast({ tone = 'info', message, action, onAction, onClose, style }) {
  const t = TOAST[tone] || TOAST.info;
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 12, minWidth: 300, maxWidth: 460,
      padding: '13px 14px 13px 16px', background: 'var(--ml-navy-800)', color: '#fff',
      borderRadius: 'var(--radius-md)', boxShadow: 'var(--shadow-lg)', position: 'relative', overflow: 'hidden',
      fontFamily: 'var(--font-sans)', ...style,
    }}>
      <span style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: 4, background: t.bar }} />
      <Icon name={t.icon} size={21} color={t.fg} fill={1} />
      <span style={{ flex: 1, fontSize: 14, fontWeight: 500 }}>{message}</span>
      {action && <button type="button" onClick={onAction} style={{ border: 'none', background: 'transparent', color: 'var(--ml-cyan-300)', fontFamily: 'var(--font-sans)', fontSize: 13.5, fontWeight: 700, cursor: 'pointer', whiteSpace: 'nowrap' }}>{action}</button>}
      {onClose && <button type="button" onClick={onClose} style={{ border: 'none', background: 'transparent', color: 'rgba(255,255,255,.6)', cursor: 'pointer', display: 'flex' }}><Icon name="close" size={18} /></button>}
    </div>
  );
}

/** Fixed bottom-center stack container for toasts. */
export function ToastStack({ children, style }) {
  return (
    <div style={{ position: 'fixed', left: '50%', bottom: 28, transform: 'translateX(-50%)', zIndex: 80, display: 'flex', flexDirection: 'column', gap: 10, alignItems: 'center', ...style }}>
      {children}
    </div>
  );
}
