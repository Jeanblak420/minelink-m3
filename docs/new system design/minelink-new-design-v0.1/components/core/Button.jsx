import React from 'react';
import { Icon } from './Icon.jsx';

const SIZES = {
  sm: { pad: '8px 14px', fs: 13, h: 38, icon: 18 },
  md: { pad: '12px 18px', fs: 15, h: 48, icon: 20 },
  lg: { pad: '14px 22px', fs: 16, h: 52, icon: 22 },
};

/**
 * MineLink button. Variants: primary (cyan), go (green confirm),
 * leave (orange depart), tonal (white-on-tint), outline, ghost, danger.
 */
export function Button({
  children,
  variant = 'primary',
  size = 'md',
  icon,
  iconRight,
  block = false,
  disabled = false,
  style,
  ...rest
}) {
  const s = SIZES[size] || SIZES.md;
  const base = {
    display: block ? 'flex' : 'inline-flex',
    width: block ? '100%' : undefined,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    padding: s.pad,
    minHeight: s.h,
    fontFamily: 'var(--font-sans)',
    fontSize: s.fs,
    fontWeight: 700,
    lineHeight: 1,
    borderRadius: 'var(--radius-md)',
    border: '1px solid transparent',
    cursor: disabled ? 'not-allowed' : 'pointer',
    opacity: disabled ? 0.5 : 1,
    transition: 'background var(--dur-fast) var(--ease-out), transform var(--dur-fast) var(--ease-out), box-shadow var(--dur-fast) var(--ease-out)',
    whiteSpace: 'nowrap',
  };

  const variants = {
    primary: { background: 'var(--accent)', color: 'var(--on-accent)', boxShadow: '0 2px 8px rgba(0,181,216,.28)' },
    go: { background: 'linear-gradient(180deg,var(--action-go),var(--action-go-deep))', color: '#fff', boxShadow: '0 2px 8px rgba(22,163,74,.28)' },
    leave: { background: 'linear-gradient(180deg,var(--action-leave),var(--action-leave-deep))', color: '#fff', boxShadow: '0 2px 8px rgba(249,115,22,.28)' },
    tonal: { background: 'var(--surface-card)', color: 'var(--ml-navy-800)', border: '1px solid var(--border-card)' },
    outline: { background: 'transparent', color: 'var(--accent)', border: '1px solid var(--border-strong)' },
    ghost: { background: 'transparent', color: 'var(--text-body)' },
    danger: { background: 'var(--status-error-fg)', color: '#fff' },
  };

  return (
    <button
      type="button"
      disabled={disabled}
      style={{ ...base, ...(variants[variant] || variants.primary), ...style }}
      onMouseEnter={(e) => { if (!disabled) e.currentTarget.style.transform = 'translateY(-1px)'; }}
      onMouseLeave={(e) => { e.currentTarget.style.transform = 'translateY(0)'; }}
      {...rest}
    >
      {icon && <Icon name={icon} size={s.icon} />}
      {children}
      {iconRight && <Icon name={iconRight} size={s.icon} />}
    </button>
  );
}
