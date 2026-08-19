/* MineLink Chat — shared fake data + org-scoped contact logic.
 * Mirrors the CPS chat feature (1:1 DMs, group rooms, replies, @mentions,
 * presence, delivered/read receipts) but with MineLink's company-scoping rules:
 *  - a user's contacts = their own company's users (internal)
 *  - PLUS both Super Global Admins (always auto-added)
 *  - PLUS users of any OTHER org the admin has granted a connection to
 *  - Super admins see every org + every user, grouped by org
 *  - Admins grant / revoke org-to-org connections; revoke keeps history but
 *    blocks new messages (shows a "contact Mine-Link" banner).
 * Exposed on window.ChatData. */
(function () {
  const SUPER_ADMINS = [
    { id: 'sa1', name: 'MineLink Admin', role: 'Super Global Admin', org: 'minelink', presence: 'online' },
    { id: 'sa2', name: 'MineLink Ops', role: 'Super Global Admin', org: 'minelink', presence: 'away' },
  ];

  const ORGS = [
    { id: 'ironhills', name: 'Iron Hills Mining', type: 'Mine', tone: 'cyan', icon: 'conveyor_belt' },
    { id: 'atlas', name: 'Atlas Buyer Group', type: 'Buyer', tone: 'amber', icon: 'handshake' },
    { id: 'roadhaul', name: 'Roadhaul Logistics', type: 'Transporter', tone: 'green', icon: 'local_shipping' },
    { id: 'pioneer', name: 'Pioneer Mining', type: 'Mine', tone: 'cyan', icon: 'conveyor_belt' },
  ];

  const USERS = [
    // Iron Hills (Mine)
    { id: 'ih1', name: 'Johan Steyn', role: 'Owner', org: 'ironhills', presence: 'online' },
    { id: 'ih2', name: 'Gate Security', role: 'Security', org: 'ironhills', presence: 'online' },
    { id: 'ih3', name: 'Lerato Load Control', role: 'Controller', org: 'ironhills', presence: 'away' },
    { id: 'ih4', name: 'Nadia Admin', role: 'Admin', org: 'ironhills', presence: 'offline', lastSeen: '2h ago' },
    { id: 'ih5', name: 'Pieter Management', role: 'Management', org: 'ironhills', presence: 'offline', lastSeen: 'yesterday' },
    // Atlas (Buyer)
    { id: 'at1', name: 'Eli Naidoo', role: 'Owner', org: 'atlas', presence: 'online' },
    { id: 'at2', name: 'Atlas Admin', role: 'Admin', org: 'atlas', presence: 'away' },
    { id: 'at3', name: 'Atlas Management', role: 'Management', org: 'atlas', presence: 'offline', lastSeen: '30m ago' },
    // Roadhaul (Transporter)
    { id: 'rh1', name: 'Sipho Dube', role: 'Owner', org: 'roadhaul', presence: 'online' },
    { id: 'rh2', name: 'Thabo Driver', role: 'Driver', org: 'roadhaul', presence: 'online' },
    { id: 'rh3', name: 'Roadhaul Admin', role: 'Admin', org: 'roadhaul', presence: 'offline', lastSeen: '5m ago' },
    // Pioneer (Mine)
    { id: 'pi1', name: 'Pioneer Owner', role: 'Owner', org: 'pioneer', presence: 'away' },
    { id: 'pi2', name: 'Pioneer Security', role: 'Security', org: 'pioneer', presence: 'online' },
  ];

  // Org-to-org connection grants (undirected pairs). Seeded: Iron Hills ↔ Atlas.
  // status: 'granted' | 'revoked'. Revoked keeps history but blocks sending.
  let CONNECTIONS = [
    { a: 'ironhills', b: 'atlas', status: 'granted', since: '12 May 2026' },
    { a: 'atlas', b: 'roadhaul', status: 'revoked', since: '02 Jun 2026', revokedOn: '28 Jun 2026' },
  ];

  const pairKey = (x, y) => [x, y].sort().join('|');
  function connectionStatus(orgA, orgB) {
    if (orgA === orgB) return 'internal';
    const c = CONNECTIONS.find((c) => pairKey(c.a, c.b) === pairKey(orgA, orgB));
    return c ? c.status : 'none';
  }
  function setConnection(orgA, orgB, status) {
    const key = pairKey(orgA, orgB);
    const existing = CONNECTIONS.find((c) => pairKey(c.a, c.b) === key);
    if (existing) { existing.status = status; if (status === 'revoked') existing.revokedOn = 'today'; }
    else CONNECTIONS.push({ a: orgA, b: orgB, status, since: 'today' });
    return CONNECTIONS.slice();
  }
  const getConnections = () => CONNECTIONS.slice();

  const org = (id) => id === 'minelink' ? { id: 'minelink', name: 'Mine-Link', type: 'Platform', tone: 'cyan', icon: 'verified' } : ORGS.find((o) => o.id === id);
  const user = (id) => USERS.find((u) => u.id === id) || SUPER_ADMINS.find((u) => u.id === id);
  const usersOf = (orgId) => USERS.filter((u) => u.org === orgId);

  /* Build the grouped contact list for a given viewer (a user id). */
  function contactsFor(viewerId) {
    const viewer = user(viewerId);
    if (!viewer) return [];
    // Super admin: every org, each as a group of its users, plus the other admin.
    if (viewer.org === 'minelink') {
      const groups = [{ kind: 'admin', label: 'MINE-LINK', org: org('minelink'), users: SUPER_ADMINS.filter((u) => u.id !== viewerId) }];
      ORGS.forEach((o) => groups.push({ kind: 'org', label: o.name, org: o, users: usersOf(o.id) }));
      return groups;
    }
    const groups = [];
    // Internal — own company
    groups.push({ kind: 'internal', label: org(viewer.org).name, org: org(viewer.org), users: usersOf(viewer.org).filter((u) => u.id !== viewerId) });
    // Mine-Link admins — always present
    groups.push({ kind: 'admin', label: 'MINE-LINK', org: org('minelink'), users: SUPER_ADMINS.slice() });
    // Connected orgs (granted or revoked — revoked still shows, but blocked)
    ORGS.filter((o) => o.id !== viewer.org).forEach((o) => {
      const st = connectionStatus(viewer.org, o.id);
      if (st === 'granted' || st === 'revoked') {
        groups.push({ kind: 'connected', label: o.name, org: o, status: st, users: usersOf(o.id) });
      }
    });
    return groups;
  }

  const now = Date.now();
  const t = (min) => new Date(now - min * 60000).toISOString();
  // Seed conversations: keyed by sorted participant pair or room id.
  const MESSAGES = {
    'ih1|at1': [
      { id: 'm1', from: 'at1', text: 'Morning Johan — can Iron Hills cover the Saldanha route next week? Need 12 loads.', at: t(240), status: 'read' },
      { id: 'm2', from: 'ih1', text: 'Morning Eli. Yes, we can. I\'ll get @Lerato Load Control to confirm slots.', at: t(232), status: 'read', mentions: ['ih3'] },
      { id: 'm3', from: 'at1', text: 'Perfect. Payment terms 30 days as usual?', at: t(228), status: 'read' },
      { id: 'm4', from: 'ih1', text: 'Correct. I\'ll send the waybill numbers once the first trucks load.', at: t(20), status: 'delivered' },
    ],
    'ih1|ih3': [
      { id: 'n1', from: 'ih1', text: 'Lerato, please confirm 12 loading slots for Atlas next week.', at: t(230), status: 'read' },
      { id: 'n2', from: 'ih3', text: 'On it — Mon–Wed fully open, checking Thu/Fri.', at: t(210), status: 'read' },
    ],
    'ih1|sa1': [
      { id: 's1', from: 'sa1', text: 'Hi Johan, your token renews in 42 days. Reply here if you\'d like to add seats.', at: t(1440), status: 'read' },
      { id: 's2', from: 'ih1', text: 'Thanks — we may add 2 Security seats. Will confirm.', at: t(1400), status: 'read' },
    ],
    // revoked example (Atlas ↔ Roadhaul) — history preserved
    'at1|rh1': [
      { id: 'r1', from: 'rh1', text: 'Fleet is ready for the Vanderbijlpark contract.', at: t(6000), status: 'read' },
      { id: 'r2', from: 'at1', text: 'Great, let\'s finalise rates.', at: t(5990), status: 'read' },
    ],
  };
  const convKey = (a, b) => [a, b].sort().join('|');
  const messagesBetween = (a, b) => MESSAGES[convKey(a, b)] || [];
  function addMessage(a, b, msg) {
    const k = convKey(a, b);
    (MESSAGES[k] = MESSAGES[k] || []).push(msg);
    return MESSAGES[k];
  }

  /* -------- Org-to-org group chats --------
   * A group belongs to a connected org-pair. Each org owns its own member list
   * and may add/remove only its OWN company's users. */
  let GROUPS = [
    {
      id: 'g1', name: 'Iron Hills × Atlas — Saldanha Contract', orgs: ['ironhills', 'atlas'],
      createdBy: 'ih1',
      members: { ironhills: ['ih1', 'ih3'], atlas: ['at1', 'at2'] },
      messages: [
        { id: 'gm1', from: 'ih1', text: 'Welcome all — this thread is for the Saldanha iron-ore contract.', at: t(300), status: 'read' },
        { id: 'gm2', from: 'at1', text: 'Thanks Johan. @Lerato Load Control what are the confirmed slots?', at: t(288), status: 'read', mentions: ['ih3'] },
        { id: 'gm3', from: 'ih3', text: '12 slots Mon–Wed, adding Thu/Fri shortly.', at: t(280), status: 'read' },
      ],
    },
  ];
  const groupsFor = (viewerId) => {
    const v = user(viewerId);
    if (!v) return [];
    if (v.org === 'minelink') return GROUPS.slice(); // admins observe all
    return GROUPS.filter((g) => (g.members[v.org] || []).includes(viewerId));
  };
  const groupById = (id) => GROUPS.find((g) => g.id === id);
  const groupMembers = (g) => Object.entries(g.members).flatMap(([o, ids]) => ids.map((id) => ({ ...user(id), _org: o })));
  function groupBlocked(g) { return connectionStatus(g.orgs[0], g.orgs[1]) !== 'granted'; }
  function addGroupMessage(id, msg) { const g = groupById(id); if (g) g.messages.push(msg); return g && g.messages; }
  function setGroupMember(id, orgId, userId, on) {
    const g = groupById(id); if (!g) return;
    g.members[orgId] = g.members[orgId] || [];
    if (on && !g.members[orgId].includes(userId)) g.members[orgId].push(userId);
    if (!on) g.members[orgId] = g.members[orgId].filter((x) => x !== userId);
    return g;
  }
  function createGroup(name, orgA, orgB, creatorId) {
    const g = { id: 'g' + (GROUPS.length + 1), name, orgs: [orgA, orgB], createdBy: creatorId, members: { [orgA]: [creatorId], [orgB]: [] }, messages: [] };
    GROUPS.push(g); return g;
  }
  /* Which OTHER orgs is this viewer's org connected to (granted only)? */
  const connectedOrgs = (viewerId) => {
    const v = user(viewerId); if (!v || v.org === 'minelink') return [];
    return ORGS.filter((o) => o.id !== v.org && connectionStatus(v.org, o.id) === 'granted');
  };

  /* -------- Support tickets --------
   * Any user of any company logs a ticket to the Super Global Admins. Both
   * admins can be assigned to the inbox; whoever ACCEPTS becomes the handler and
   * the ticket auto-advances to In progress. Admins can ask the logger questions
   * and mark it completed. Every stage change notifies the logger. */
  const SUPPORT_CATEGORIES = ['Question', 'App problem', 'Bug report', 'Billing / account', 'Other'];
  let INBOX = { sa1: true, sa2: true };           // which admins receive tickets
  const getInbox = () => ({ ...INBOX });
  const setInbox = (adminId, on) => { INBOX[adminId] = on; return getInbox(); };
  const inboxAdmins = () => SUPER_ADMINS.filter((a) => INBOX[a.id]);

  const NOTIFS = {};                               // userId -> [{id,ticketId,text,at,read}]
  function notify(userId, ticketId, text) {
    (NOTIFS[userId] = NOTIFS[userId] || []).unshift({ id: 'nt' + Date.now() + Math.random().toString(36).slice(2, 6), ticketId, text, at: new Date().toISOString(), read: false });
  }
  const notificationsFor = (userId) => (NOTIFS[userId] || []).slice();
  const unreadNotifCount = (userId) => (NOTIFS[userId] || []).filter((n) => !n.read).length;
  function markNotifsRead(userId, ticketId) { (NOTIFS[userId] || []).forEach((n) => { if (!ticketId || n.ticketId === ticketId) n.read = true; }); }

  const nowISO = () => new Date().toISOString();
  let TICKETS = [
    { id: 'tk1', subject: 'Cannot upload waybill PDF', category: 'App problem', from: 'at1', org: 'atlas',
      status: 'in_progress', acceptedBy: 'sa1', acceptedByName: 'MineLink Admin', createdAt: t(180),
      events: [{ type: 'sent', at: t(180) }, { type: 'accepted', at: t(150), actorName: 'MineLink Admin' }, { type: 'in_progress', at: t(150) }],
      messages: [
        { id: 'tm1', from: 'at1', text: 'When I attach a waybill PDF the upload spins forever. Web app, Chrome.', at: t(180) },
        { id: 'tm2', from: 'sa1', text: 'Thanks for reporting — roughly what file size is the PDF?', at: t(148) },
      ] },
    { id: 'tk2', subject: 'How do I add a second Security seat?', category: 'Question', from: 'ih1', org: 'ironhills',
      status: 'sent', acceptedBy: null, acceptedByName: null, createdAt: t(40),
      events: [{ type: 'sent', at: t(40) }],
      messages: [{ id: 'tm3', from: 'ih1', text: 'We want to add another gate Security login — where do I do that?', at: t(40) }] },
  ];
  const ticketById = (id) => TICKETS.find((k) => k.id === id);
  const ticketsForUser = (userId) => TICKETS.filter((k) => k.from === userId).sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
  const ticketsForAdmin = () => TICKETS.slice().sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
  function createTicket(fromId, subject, category, body) {
    const u = user(fromId);
    const k = { id: 'tk' + Date.now().toString(36), subject, category, from: fromId, org: u.org, status: 'sent', acceptedBy: null, acceptedByName: null, createdAt: nowISO(), events: [{ type: 'sent', at: nowISO() }], messages: body ? [{ id: 'tm' + Date.now(), from: fromId, text: body, at: nowISO() }] : [] };
    TICKETS.push(k);
    notify(fromId, k.id, `Ticket sent — “${subject}”. The Mine-Link support team has been notified.`);
    return k;
  }
  function acceptTicket(ticketId, adminId) {
    const k = ticketById(ticketId); if (!k || k.status !== 'sent') return k;
    const name = user(adminId).name;
    k.acceptedBy = adminId; k.acceptedByName = name; k.status = 'in_progress';
    k.events.push({ type: 'accepted', at: nowISO(), actorName: name });
    k.events.push({ type: 'in_progress', at: nowISO() });
    notify(k.from, k.id, `Ticket accepted by ${name} — now In progress.`);
    return k;
  }
  function completeTicket(ticketId, adminId) {
    const k = ticketById(ticketId); if (!k || k.status === 'completed') return k;
    const name = user(adminId).name;
    k.status = 'completed';
    k.events.push({ type: 'completed', at: nowISO(), actorName: name });
    notify(k.from, k.id, `Ticket completed by ${name}. Thanks for your patience.`);
    return k;
  }
  function addTicketMessage(ticketId, fromId, text) {
    const k = ticketById(ticketId); if (!k) return k;
    k.messages.push({ id: 'tm' + Date.now(), from: fromId, text, at: nowISO() });
    if (user(fromId).org === 'minelink') notify(k.from, k.id, `${user(fromId).name} replied on your ticket “${k.subject}”.`);
    return k;
  }

  window.ChatData = {
    SUPER_ADMINS, ORGS, USERS, org, user, usersOf,
    connectionStatus, setConnection, getConnections,
    contactsFor, messagesBetween, addMessage, convKey,
    groupsFor, groupById, groupMembers, groupBlocked, addGroupMessage,
    setGroupMember, createGroup, connectedOrgs,
    SUPPORT_CATEGORIES, getInbox, setInbox, inboxAdmins,
    notificationsFor, unreadNotifCount, markNotifsRead,
    ticketById, ticketsForUser, ticketsForAdmin,
    createTicket, acceptTicket, completeTicket, addTicketMessage,
  };
})();
