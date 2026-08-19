import React from 'react';
import { Icon } from '../core/Icon.jsx';
import { NotificationCard } from './NotificationCard.jsx';

/** App-bar notification bell with unread badge + dropdown panel.
 * Operational alerts ONLY — chat has its own floating launcher. */
export function NotificationBell({ notifications = [], onRead, onReadAll, onDismiss, onViewAll, style }) {
  const [open, setOpen] = React.useState(false);
  const unread = notifications.filter((n) => !n.read).length;
  return (
    <div style={{ position: 'relative', ...style }}>
      <button type="button" onClick={() => setOpen((o) => !o)} style={{ position: 'relative', width: 46, height: 46, borderRadius: 999, border: '1px solid var(--border-card)', background: 'var(--surface-card)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-body)' }}>
        <Icon name="notifications" size={24} fill={open ? 1 : 0} />
        {unread > 0 && <span style={{ position: 'absolute', top: 6, right: 6, minWidth: 18, height: 18, padding: '0 5px', borderRadius: 999, background: 'var(--ml-red-600)', color: '#fff', fontSize: 10.5, fontWeight: 800, display: 'flex', alignItems: 'center', justifyContent: 'center', border: '2px solid var(--surface-card)' }}>{unread > 99 ? '99+' : unread}</span>}
      </button>
      {open && (
        <div style={{ position: 'absolute', top: 54, right: 0, width: 400, maxHeight: 560, background: 'var(--surface-card)', borderRadius: 'var(--radius-lg)', boxShadow: 'var(--shadow-lg)', border: '1px solid var(--border-card)', zIndex: 40, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '15px 18px', borderBottom: '1px solid var(--divider)' }}>
            <span style={{ fontSize: 16, fontWeight: 800, color: 'var(--text-strong)', flex: 1, fontFamily: 'var(--font-sans)' }}>Notifications</span>
            {unread > 0 && <button type="button" onClick={onReadAll} style={{ border: 'none', background: 'transparent', color: 'var(--accent)', fontWeight: 700, fontSize: 12.5, cursor: 'pointer', fontFamily: 'var(--font-sans)' }}>Mark all read</button>}
          </div>
          <div style={{ flex: 1, overflowY: 'auto' }}>
            {notifications.length ? notifications.map((n) => (
              <div key={n.id} style={{ borderBottom: '1px solid var(--divider)' }}>
                <NotificationCard notification={n} compact onClick={onRead} onDismiss={onDismiss} />
              </div>
            )) : (
              <div style={{ padding: 40, textAlign: 'center', color: 'var(--text-faint)', fontFamily: 'var(--font-sans)' }}>
                <Icon name="notifications_off" size={40} color="var(--ml-slate-300)" />
                <div style={{ marginTop: 10, fontSize: 14 }}>You're all caught up</div>
              </div>
            )}
          </div>
          <button type="button" onClick={onViewAll} style={{ padding: 14, border: 'none', borderTop: '1px solid var(--divider)', background: 'var(--surface-app)', color: 'var(--accent)', fontWeight: 700, fontSize: 13.5, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6, fontFamily: 'var(--font-sans)' }}>
            View all notifications <Icon name="arrow_forward" size={16} />
          </button>
        </div>
      )}
    </div>
  );
}
