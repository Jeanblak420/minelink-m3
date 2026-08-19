/* MineLink — Notifications feature. Bell panel + full management screen.
 * Types & importance mirror notification_model.dart. */
const DSn = window.MineLinkDesignSystem_9acfde;
const { Icon: IconN, StatusBadge: BadgeN, Button: BtnN, Avatar: AvN } = DSn;
const { SectionTitle: STitleN } = window.MLShell;

// type -> {icon, tone}
const NTYPE = {
  employeeRequest: { icon: 'person_add', tone: 'cyan', label: 'Employee Request' },
  roleAssigned: { icon: 'badge', tone: 'green', label: 'Role Assigned' },
  requestDeclined: { icon: 'block', tone: 'red', label: 'Request Declined' },
  roleConfirmation: { icon: 'verified', tone: 'green', label: 'Role Confirmation' },
  securityAlert: { icon: 'security', tone: 'red', label: 'Security Alert' },
  controllerAction: { icon: 'tune', tone: 'cyan', label: 'Controller Action' },
  dismissalInitiated: { icon: 'gavel', tone: 'amber', label: 'Employee Dismissal' },
  dismissalAppeal: { icon: 'balance', tone: 'amber', label: 'Dismissal Appeal' },
  fleetVehicleAdded: { icon: 'local_shipping', tone: 'blue', label: 'Vehicle Added' },
  fleetDriverAssigned: { icon: 'assignment_ind', tone: 'blue', label: 'Driver Assigned' },
  general: { icon: 'notifications', tone: 'slate', label: 'General' },
};
const IMP = { normal: { c: 'var(--ml-blue-600)', bg: 'var(--ml-blue-50)', label: 'Normal' }, high: { c: 'var(--ml-orange-600)', bg: 'var(--status-warn-bg)', label: 'High' }, extreme: { c: 'var(--ml-red-600)', bg: 'var(--status-error-bg)', label: 'EXTREME' } };
const TONE_FG = { cyan: 'var(--accent)', green: 'var(--ml-green-600)', amber: 'var(--ml-orange-600)', blue: 'var(--ml-blue-600)', red: 'var(--ml-red-600)', slate: 'var(--text-muted)' };
const TONE_BG = { cyan: 'var(--ml-well-cyan)', green: 'var(--ml-well-green)', amber: 'var(--ml-well-amber)', blue: 'var(--ml-well-blue)', red: 'var(--status-error-bg)', slate: 'var(--surface-sunken)' };

const SEED_NOTIFS = [
  { id: 'n1', type: 'securityAlert', importance: 'extreme', title: 'Unregistered truck at Gate 2', message: 'A vehicle without a valid waybill attempted entry at Gate 2. Security has been dispatched.', at: '4m ago', read: false, by: 'Gate Security' },
  { id: 'n2', type: 'employeeRequest', importance: 'high', title: 'New employee request', message: 'Thabo Mokoena requested to join Iron Hills Mining as a driver. Review and assign a role.', at: '22m ago', read: false, by: null },
  { id: 'n3', type: 'roleAssigned', importance: 'normal', title: 'Role assigned', message: 'You have been assigned the Controller role. Load-control features are now available.', at: '1h ago', read: false, by: 'Nadia Admin' },
  { id: 'n4', type: 'fleetDriverAssigned', importance: 'normal', title: 'Driver assigned to CDF 789 LP', message: 'Thabo Mokoena is now the assigned driver for CDF 789 LP.', at: '2h ago', read: true, by: 'Roadhaul Admin' },
  { id: 'n5', type: 'dismissalInitiated', importance: 'high', title: 'Dismissal initiated', message: 'A dismissal process was started for Mandla Zulu. Management review required within 48 hours.', at: '3h ago', read: true, by: 'Pieter Management' },
  { id: 'n6', type: 'controllerAction', importance: 'normal', title: 'Load recorded', message: 'Load of 34.5 t recorded for JKL 012 NW · ticket WB-0045.', at: '5h ago', read: true, by: 'Lerato Load Control' },
];

function NotifItem({ n, onRead, onDelete, compact }) {
  const meta = NTYPE[n.type] || NTYPE.general;
  const imp = IMP[n.importance] || IMP.normal;
  return (
    <div onClick={() => onRead(n.id)} style={{ display: 'flex', gap: 13, padding: compact ? '12px 14px' : '16px 18px', cursor: 'pointer', background: n.read ? 'transparent' : 'var(--ml-well-cyan)', borderRadius: compact ? 0 : 'var(--radius-md)', border: compact ? 'none' : '1px solid var(--border-card)', borderBottom: compact ? '1px solid var(--divider)' : '1px solid var(--border-card)', position: 'relative', transition: 'background .15s' }}>
      {!n.read && <span style={{ position: 'absolute', left: 5, top: '50%', width: 6, height: 6, borderRadius: 999, background: 'var(--accent)', transform: 'translateY(-50%)' }} />}
      <div style={{ width: 42, height: 42, borderRadius: 12, background: TONE_BG[meta.tone], display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><IconN name={meta.icon} size={21} color={TONE_FG[meta.tone]} fill={n.importance === 'extreme' ? 1 : 0} /></div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
          <span style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--text-strong)' }}>{n.title}</span>
          {n.importance !== 'normal' && <span style={{ fontSize: 10, fontWeight: 800, letterSpacing: '.05em', color: imp.c, background: imp.bg, padding: '2px 7px', borderRadius: 999 }}>{imp.label}</span>}
        </div>
        <div style={{ fontSize: 13, color: 'var(--text-muted)', marginTop: 3, lineHeight: 1.45 }}>{n.message}</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 6, fontSize: 11.5, color: 'var(--text-faint)' }}>
          <span style={{ fontWeight: 700, color: TONE_FG[meta.tone] }}>{meta.label}</span>
          <span>· {n.at}</span>
          {n.by && <span>· by {n.by}</span>}
        </div>
      </div>
      <button type="button" onClick={(e) => { e.stopPropagation(); onDelete(n.id); }} style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--text-faint)', display: 'flex', alignSelf: 'flex-start' }}><IconN name="close" size={18} /></button>
    </div>
  );
}

/* Bell dropdown panel (overlay) */
function NotifBell({ notifs, onRead, onReadAll, onDelete, onViewAll }) {
  const [open, setOpen] = React.useState(true);
  const unread = notifs.filter((n) => !n.read).length;
  return (
    <div style={{ position: 'relative' }}>
      <button type="button" onClick={() => setOpen((o) => !o)} style={{ position: 'relative', width: 46, height: 46, borderRadius: 999, border: '1px solid var(--border-card)', background: 'var(--surface-card)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-body)' }}>
        <IconN name="notifications" size={24} fill={open ? 1 : 0} />
        {unread > 0 && <span style={{ position: 'absolute', top: 6, right: 6, minWidth: 18, height: 18, padding: '0 5px', borderRadius: 999, background: 'var(--ml-red-600)', color: '#fff', fontSize: 10.5, fontWeight: 800, display: 'flex', alignItems: 'center', justifyContent: 'center', border: '2px solid var(--surface-card)' }}>{unread}</span>}
      </button>
      {open && (
        <div style={{ position: 'absolute', top: 54, right: 0, width: 400, maxHeight: 560, background: 'var(--surface-card)', borderRadius: 'var(--radius-lg)', boxShadow: 'var(--shadow-lg)', border: '1px solid var(--border-card)', zIndex: 30, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '15px 18px', borderBottom: '1px solid var(--divider)' }}>
            <span style={{ fontSize: 16, fontWeight: 800, color: 'var(--text-strong)', flex: 1 }}>Notifications</span>
            {unread > 0 && <button type="button" onClick={onReadAll} style={{ border: 'none', background: 'transparent', color: 'var(--accent)', fontWeight: 700, fontSize: 12.5, cursor: 'pointer' }}>Mark all read</button>}
          </div>
          <div style={{ flex: 1, overflowY: 'auto' }}>
            {notifs.length ? notifs.map((n) => <NotifItem key={n.id} n={n} onRead={onRead} onDelete={onDelete} compact />)
              : <div style={{ padding: 40, textAlign: 'center', color: 'var(--text-faint)' }}><IconN name="notifications_off" size={40} color="var(--ml-slate-300)" /><div style={{ marginTop: 10, fontSize: 14 }}>You're all caught up</div></div>}
          </div>
          <button type="button" onClick={onViewAll} style={{ padding: 14, border: 'none', borderTop: '1px solid var(--divider)', background: 'var(--surface-app)', color: 'var(--accent)', fontWeight: 700, fontSize: 13.5, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6 }}>View all notifications <IconN name="arrow_forward" size={16} /></button>
        </div>
      )}
    </div>
  );
}

function NotificationsScreen() {
  const [notifs, setNotifs] = React.useState(SEED_NOTIFS);
  const [filter, setFilter] = React.useState('all');
  const read = (id) => setNotifs((ns) => ns.map((n) => n.id === id ? { ...n, read: true } : n));
  const readAll = () => setNotifs((ns) => ns.map((n) => ({ ...n, read: true })));
  const del = (id) => setNotifs((ns) => ns.filter((n) => n.id !== id));
  const filtered = filter === 'all' ? notifs : filter === 'unread' ? notifs.filter((n) => !n.read) : notifs.filter((n) => n.importance !== 'normal');
  const unread = notifs.filter((n) => !n.read).length;

  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 14, marginBottom: 18 }}>
        <div style={{ flex: 1 }}>
          <h2 style={{ margin: 0, fontSize: 22, fontWeight: 800, color: 'var(--text-strong)' }}>Recent alerts and updates</h2>
          <div style={{ fontSize: 13.5, color: 'var(--text-muted)', marginTop: 2 }}>{unread} unread · {notifs.length} total</div>
        </div>
        <BtnN variant="outline" size="sm" icon="done_all" onClick={readAll}>Mark all read</BtnN>
        <BtnN variant="ghost" size="sm" icon="clear_all" onClick={() => setNotifs([])}>Clear all</BtnN>
      </div>
      <div style={{ display: 'flex', gap: 8, marginBottom: 18 }}>
        {[['all', 'All', notifs.length], ['unread', 'Unread', unread], ['priority', 'Priority', notifs.filter((n) => n.importance !== 'normal').length]].map(([k, l, n]) => {
          const sel = filter === k;
          return <button key={k} type="button" onClick={() => setFilter(k)} style={{ display: 'inline-flex', alignItems: 'center', gap: 7, padding: '8px 15px', borderRadius: 999, cursor: 'pointer', fontFamily: 'var(--font-sans)', fontSize: 13.5, fontWeight: 700, border: `1px solid ${sel ? 'var(--accent)' : 'var(--border-strong)'}`, background: sel ? 'var(--accent)' : 'var(--surface-card)', color: sel ? '#fff' : 'var(--text-body)' }}>{l}<span style={{ fontFamily: 'var(--font-mono)', fontSize: 12, padding: '1px 6px', borderRadius: 999, background: sel ? 'rgba(255,255,255,.22)' : 'var(--surface-sunken)', color: sel ? '#fff' : 'var(--text-muted)' }}>{n}</span></button>;
        })}
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        {filtered.length ? filtered.map((n) => <NotifItem key={n.id} n={n} onRead={read} onDelete={del} />)
          : <div style={{ padding: 60, textAlign: 'center', color: 'var(--text-faint)' }}><IconN name="notifications_none" size={56} color="var(--ml-slate-300)" /><div style={{ fontSize: 18, fontWeight: 700, color: 'var(--text-muted)', marginTop: 12 }}>No notifications</div><div style={{ fontSize: 14, marginTop: 4 }}>You're all caught up.</div></div>}
      </div>
    </div>
  );
}

window.NotifScreens = { NotificationsScreen, NotifBell, NotifItem, SEED_NOTIFS };
