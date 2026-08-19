import React from 'react';
import { Icon } from '../core/Icon.jsx';

const NTYPE = {
  employeeRequest: { icon: 'person_add', tone: 'cyan', label: 'Employee Request' },
  roleAssigned: { icon: 'badge', tone: 'green', label: 'Role Assigned' },
  requestDeclined: { icon: 'block', tone: 'red', label: 'Request Declined' },
  roleConfirmation: { icon: 'verified', tone: 'green', label: 'Role Confirmation' },
  securityAlert: { icon: 'security', tone: 'red', label: 'Security Alert' },
  controllerAction: { icon: 'tune', tone: 'cyan', label: 'Controller Action' },
  dismissalInitiated: { icon: 'gavel', tone: 'amber', label: 'Employee Dismissal' },
  fleetVehicleAdded: { icon: 'local_shipping', tone: 'blue', label: 'Vehicle Added' },
  fleetDriverAssigned: { icon: 'assignment_ind', tone: 'blue', label: 'Driver Assigned' },
  general: { icon: 'notifications', tone: 'slate', label: 'General' },
};
const IMP = { normal: { c: 'var(--ml-blue-600)', bg: 'var(--ml-blue-50)', label: 'Normal' }, high: { c: 'var(--ml-orange-600)', bg: 'var(--status-warn-bg)', label: 'High' }, extreme: { c: 'var(--ml-red-600)', bg: 'var(--status-error-bg)', label: 'EXTREME' } };
const FG = { cyan: 'var(--accent)', green: 'var(--ml-green-600)', amber: 'var(--ml-orange-600)', blue: 'var(--ml-blue-600)', red: 'var(--ml-red-600)', slate: 'var(--text-muted)' };
const BG = { cyan: 'var(--ml-well-cyan)', green: 'var(--ml-well-green)', amber: 'var(--ml-well-amber)', blue: 'var(--ml-well-blue)', red: 'var(--status-error-bg)', slate: 'var(--surface-sunken)' };

/** One operational notification row. Excludes chat (chat has its own launcher). */
export function NotificationCard({ notification, onClick, onDismiss, compact = false, style }) {
  const n = notification;
  const meta = NTYPE[n.type] || NTYPE.general;
  const imp = IMP[n.importance] || IMP.normal;
  return (
    <div onClick={() => onClick && onClick(n)} style={{
      display: 'flex', gap: 13, padding: compact ? '12px 14px' : '16px 18px', cursor: onClick ? 'pointer' : 'default',
      background: n.read ? 'transparent' : 'var(--ml-well-cyan)',
      borderRadius: compact ? 0 : 'var(--radius-md)', border: '1px solid var(--border-card)',
      position: 'relative', fontFamily: 'var(--font-sans)', ...style,
    }}>
      {!n.read && <span style={{ position: 'absolute', left: 5, top: '50%', width: 6, height: 6, borderRadius: 999, background: 'var(--accent)', transform: 'translateY(-50%)' }} />}
      <div style={{ width: 42, height: 42, borderRadius: 12, background: BG[meta.tone], display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
        <Icon name={meta.icon} size={21} color={FG[meta.tone]} fill={n.importance === 'extreme' ? 1 : 0} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
          <span style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--text-strong)' }}>{n.title}</span>
          {n.importance && n.importance !== 'normal' && <span style={{ fontSize: 10, fontWeight: 800, letterSpacing: '.05em', color: imp.c, background: imp.bg, padding: '2px 7px', borderRadius: 999 }}>{imp.label}</span>}
        </div>
        <div style={{ fontSize: 13, color: 'var(--text-muted)', marginTop: 3, lineHeight: 1.45 }}>{n.message}</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 6, fontSize: 11.5, color: 'var(--text-faint)' }}>
          <span style={{ fontWeight: 700, color: FG[meta.tone] }}>{meta.label}</span>
          <span>· {n.at}</span>
          {n.by && <span>· by {n.by}</span>}
        </div>
      </div>
      {onDismiss && <button type="button" onClick={(e) => { e.stopPropagation(); onDismiss(n); }} style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--text-faint)', display: 'flex', alignSelf: 'flex-start' }}><Icon name="close" size={18} /></button>}
    </div>
  );
}
