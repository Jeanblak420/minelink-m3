/* MineLink — Stockpile management. Rebuilt from the earlier codebase mount
 * (stockpile_audit_screen + stockpile_detail_screen + ledger/transactions),
 * which is not present in the current worktree. Per-mineral tonnage on hand,
 * a movement ledger (loads in / dispatches out / audit adjustments) with
 * opening & closing balances, and an audit adjustment flow. */
const DSs = window.MineLinkDesignSystem_9acfde;
const { Icon: IconS, StatCard: StatS, StatusBadge: BadgeS, Button: BtnS, Input: InS, Select: SelS, FileUpload: FileS } = DSs;
const { DataTable: TableS, SlideOver: SlideS, Modal: ModalS } = window.MLShell;

const PILES = [
  { id: 'sp1', mineral: 'Iron Ore', grade: '62% Fe', onHand: 9640, capacity: 14000, tone: 'cyan', trend: '+420', dir: 'up', location: 'Pad A — North', buyer: 'Atlas Buyer Group' },
  { id: 'sp2', mineral: 'Chrome Ore', grade: '40% Cr₂O₃', onHand: 3120, capacity: 6000, tone: 'amber', trend: '-180', dir: 'down', location: 'Pad B — East', buyer: 'Pioneer Mining' },
  { id: 'sp3', mineral: 'Manganese', grade: '44% Mn', onHand: 1840, capacity: 4000, tone: 'green', trend: '+95', dir: 'up', location: 'Pad C — South', buyer: 'Bathopele Trading' },
];
const TONE_FG = { cyan: 'var(--accent)', amber: 'var(--ml-orange-600)', green: 'var(--ml-green-600)' };
const TONE_BG = { cyan: 'var(--ml-well-cyan)', amber: 'var(--ml-well-amber)', green: 'var(--ml-well-green)' };

// Ledger per pile: in = loaded to stockpile, out = dispatched, audit = correction
const LEDGER = {
  sp1: [
    { id: 'l1', kind: 'in', ref: 'WB-0051', party: 'Crusher Plant → Pad A', tons: 320, when: 'Jul 3 · 09:14', by: 'Lerato Load Control' },
    { id: 'l2', kind: 'out', ref: 'WB-0045', party: 'Dispatch → Atlas (CDF 789 LP)', tons: -34.5, when: 'Jul 3 · 09:19', by: 'Gate Security' },
    { id: 'l3', kind: 'out', ref: 'WB-0047', party: 'Dispatch → Atlas (BKG 456 GP)', tons: -31.8, when: 'Jul 2 · 16:02', by: 'Gate Security' },
    { id: 'l4', kind: 'audit', ref: 'AUD-014', party: 'Survey correction (drone volume)', tons: -12, when: 'Jul 2 · 07:30', by: 'Pieter Management' },
    { id: 'l5', kind: 'in', ref: 'WB-0040', party: 'Crusher Plant → Pad A', tons: 480, when: 'Jul 1 · 15:20', by: 'Lerato Load Control' },
  ],
  sp2: [
    { id: 'c1', kind: 'out', ref: 'WB-0046', party: 'Dispatch → Pioneer (JKL 012 NW)', tons: -34.5, when: 'Jul 3 · 08:40', by: 'Gate Security' },
    { id: 'c2', kind: 'in', ref: 'WB-0038', party: 'Crusher Plant → Pad B', tons: 210, when: 'Jul 1 · 11:02', by: 'Lerato Load Control' },
  ],
  sp3: [
    { id: 'm1', kind: 'in', ref: 'WB-0039', party: 'Crusher Plant → Pad C', tons: 95, when: 'Jul 2 · 13:44', by: 'Lerato Load Control' },
  ],
};

const KIND = {
  in: { icon: 'south_west', tone: 'done', label: 'RECEIVED', fg: 'var(--ml-green-600)' },
  out: { icon: 'north_east', tone: 'transit', label: 'DISPATCHED', fg: 'var(--ml-blue-600)' },
  audit: { icon: 'tune', tone: 'warn', label: 'AUDIT', fg: 'var(--ml-orange-600)' },
};

function fmt(n) { return (n > 0 ? '+' : '') + n.toLocaleString(undefined, { maximumFractionDigits: 1 }); }

function PileCard({ p, onOpen, onAdd }) {
  const pct = Math.round((p.onHand / p.capacity) * 100);
  return (
    <div style={{ background: 'var(--surface-card)', border: '1px solid var(--border-card)', borderRadius: 'var(--radius-xl)', boxShadow: 'var(--shadow-sm)', padding: 22, transition: 'box-shadow .2s' }}>
      <div onClick={() => onOpen(p)} style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 12, cursor: 'pointer' }}>
        <div style={{ width: 48, height: 48, borderRadius: 14, background: TONE_BG[p.tone], display: 'flex', alignItems: 'center', justifyContent: 'center' }}><IconS name="terrain" size={24} color={TONE_FG[p.tone]} /></div>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 17, fontWeight: 800, color: 'var(--text-strong)' }}>{p.mineral}</div>
          <div style={{ fontSize: 12.5, color: 'var(--text-muted)' }}>{p.grade} · {p.location}</div>
        </div>
        <IconS name="chevron_right" size={22} color="var(--text-faint)" />
      </div>
      <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6, padding: '4px 10px', borderRadius: 999, background: 'var(--surface-sunken)', marginBottom: 14 }}><IconS name="handshake" size={14} color="var(--accent)" /><span style={{ fontSize: 12, fontWeight: 600, color: 'var(--text-body)' }}>For {p.buyer}</span></div>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
        <span style={{ fontSize: 30, fontWeight: 800, color: 'var(--text-strong)', fontFamily: 'var(--font-mono)', letterSpacing: '-.01em' }}>{p.onHand.toLocaleString()}</span>
        <span style={{ fontSize: 16, fontWeight: 800, color: 'var(--text-strong)' }}>t</span>
        <span style={{ marginLeft: 'auto', display: 'inline-flex', alignItems: 'center', gap: 3, fontSize: 13, fontWeight: 700, color: p.dir === 'up' ? 'var(--ml-green-600)' : 'var(--ml-orange-600)' }}><IconS name={p.dir === 'up' ? 'arrow_outward' : 'south_east'} size={15} />{p.trend} t today</span>
      </div>
      {/* capacity bar */}
      <div style={{ marginTop: 14 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 11.5, color: 'var(--text-muted)', marginBottom: 5 }}><span>Capacity used</span><span style={{ fontFamily: 'var(--font-mono)', fontWeight: 700, color: pct > 85 ? 'var(--ml-orange-600)' : 'var(--text-body)' }}>{pct}% · {p.capacity.toLocaleString()} t</span></div>
        <div style={{ height: 8, borderRadius: 999, background: 'var(--surface-sunken)', overflow: 'hidden' }}><div style={{ width: `${pct}%`, height: '100%', borderRadius: 999, background: pct > 85 ? 'var(--ml-orange-500)' : TONE_FG[p.tone], transition: 'width .5s var(--ease-out)' }} /></div>
      </div>
      <div style={{ display: 'flex', gap: 8, marginTop: 16 }}>
        <BtnS size="sm" icon="add" onClick={() => onAdd(p)} style={{ flex: 1 }}>Add tons</BtnS>
        <BtnS size="sm" variant="outline" icon="chevron_right" iconRight="" onClick={() => onOpen(p)}>Ledger</BtnS>
      </div>
    </div>
  );
}

function StockpileManagement() {
  const [detail, setDetail] = React.useState(null);
  const [audit, setAudit] = React.useState(false);
  const [addTons, setAddTons] = React.useState(null);
  const totalOnHand = PILES.reduce((a, p) => a + p.onHand, 0);

  return (
    <div style={{ position: 'relative' }}>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 16, marginBottom: 20 }}>
        <StatS icon="inventory_2" label="Total On Hand" value={totalOnHand.toLocaleString()} unit="t" tone="cyan" />
        <StatS icon="south_west" label="Received Today" value="415" unit="t" delta="80t" deltaDir="up" tone="green" />
        <StatS icon="north_east" label="Dispatched Today" value="101" unit="t" tone="blue" />
        <StatS icon="tune" label="Audit Adjustments" value="1" tone="amber" />
      </div>

      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 16 }}>
        <IconS name="terrain" size={22} color="var(--accent)" />
        <h2 style={{ margin: 0, fontSize: 18, fontWeight: 800, color: 'var(--text-strong)', flex: 1 }}>Stockpiles</h2>
        <BtnS variant="outline" size="sm" icon="fact_check" onClick={() => setAudit(true)}>New audit</BtnS>
        <BtnS size="sm" icon="add">Add stockpile</BtnS>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 16 }}>
        {PILES.map((p) => <PileCard key={p.id} p={p} onOpen={setDetail} onAdd={setAddTons} />)}
      </div>

      {/* Add tons + upload results/picture (slides 6 & 13) */}
      <ModalS open={!!addTons} title={addTons ? `Add tons — ${addTons.mineral}` : ''} onClose={() => setAddTons(null)} width={460}
        footer={<><BtnS variant="outline" onClick={() => setAddTons(null)}>Cancel</BtnS><BtnS variant="go" icon="add" onClick={() => setAddTons(null)}>Add to stockpile</BtnS></>}>
        {addTons && (<div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 13, color: 'var(--text-muted)' }}><IconS name="handshake" size={16} color="var(--accent)" />Stockpile for <b style={{ color: 'var(--text-body)' }}>{addTons.buyer}</b> · on hand {addTons.onHand.toLocaleString()} t</div>
          <InS label="Tons to add" required type="number" placeholder="e.g. 320" icon="scale" />
          <FileS label="Upload results (assay / lab)" hint="PDF or image of assay results" />
          <FileS label="Upload picture" capture hint="Photo of the stockpile" />
          <div style={{ display: 'flex', gap: 10, padding: 12, background: 'var(--ml-well-cyan)', borderRadius: 'var(--radius-md)', fontSize: 12.5, color: 'var(--ml-cyan-700)' }}><IconS name="info" size={16} color="var(--accent)" />Added tons update the stockpile balance, mine inventory and the buyer's visibility.</div>
        </div>)}
      </ModalS>

      {/* Detail ledger slide-over */}
      <SlideS open={!!detail} title={detail ? `${detail.mineral} — Stockpile Ledger` : ''} onClose={() => setDetail(null)} width={520}>
        {detail && <PileDetail pile={detail} onAudit={() => { setAudit(true); }} />}
      </SlideS>

      {/* Audit modal */}
      <ModalS open={audit} title="Stockpile audit adjustment" onClose={() => setAudit(false)} width={460}
        footer={<><BtnS variant="outline" onClick={() => setAudit(false)}>Cancel</BtnS><BtnS variant="leave" icon="fact_check" onClick={() => setAudit(false)}>Post adjustment</BtnS></>}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <label style={{ display: 'flex', flexDirection: 'column', gap: 7 }}><span style={{ fontSize: 14, fontWeight: 600, color: 'var(--text-body)' }}>Stockpile</span><SelS options={PILES.map((p) => p.mineral)} /></label>
          <div style={{ display: 'flex', gap: 12 }}>
            <label style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 7 }}><span style={{ fontSize: 14, fontWeight: 600, color: 'var(--text-body)' }}>Direction</span><SelS options={['Decrease (−)', 'Increase (+)']} /></label>
            <InS label="Tons" required type="number" placeholder="12.0" style={{ flex: 1 }} />
          </div>
          <label style={{ display: 'flex', flexDirection: 'column', gap: 7 }}><span style={{ fontSize: 14, fontWeight: 600, color: 'var(--text-body)' }}>Reason</span><SelS options={['Survey correction', 'Moisture loss', 'Spillage / loss', 'Reclassification', 'Physical count']} /></label>
          <InS label="Reference / note" placeholder="e.g. Drone volumetric survey Jul 3" icon="description" />
          <div style={{ display: 'flex', gap: 10, padding: 12, background: 'var(--status-warn-bg)', borderRadius: 'var(--radius-md)', fontSize: 12.5, color: 'var(--ml-orange-700)' }}><IconS name="info" size={17} color="var(--ml-orange-700)" />Audit adjustments are logged to the ledger with your name and require Management role.</div>
        </div>
      </ModalS>
    </div>
  );
}

function PileDetail({ pile, onAudit }) {
  const rows = LEDGER[pile.id] || [];
  const net = rows.reduce((a, r) => a + r.tons, 0);
  const opening = pile.onHand - net;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
      {/* balance hero */}
      <div style={{ background: 'linear-gradient(150deg,var(--ml-well-cyan),var(--surface-card))', border: '1px solid var(--border-accent)', borderRadius: 'var(--radius-lg)', padding: 18 }}>
        <div style={{ display: 'flex', gap: 20 }}>
          <div><div style={{ fontSize: 11.5, textTransform: 'uppercase', letterSpacing: '.06em', color: 'var(--text-muted)' }}>Opening (period)</div><div style={{ fontSize: 22, fontWeight: 800, fontFamily: 'var(--font-mono)', color: 'var(--text-strong)' }}>{opening.toLocaleString()} t</div></div>
          <div style={{ display: 'flex', alignItems: 'center' }}><IconS name="arrow_forward" size={20} color="var(--text-faint)" /></div>
          <div><div style={{ fontSize: 11.5, textTransform: 'uppercase', letterSpacing: '.06em', color: 'var(--text-muted)' }}>Net movement</div><div style={{ fontSize: 22, fontWeight: 800, fontFamily: 'var(--font-mono)', color: net >= 0 ? 'var(--ml-green-600)' : 'var(--ml-orange-600)' }}>{fmt(net)} t</div></div>
          <div style={{ marginLeft: 'auto', textAlign: 'right' }}><div style={{ fontSize: 11.5, textTransform: 'uppercase', letterSpacing: '.06em', color: 'var(--text-muted)' }}>Closing (on hand)</div><div style={{ fontSize: 22, fontWeight: 800, fontFamily: 'var(--font-mono)', color: 'var(--accent)' }}>{pile.onHand.toLocaleString()} t</div></div>
        </div>
      </div>

      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: '.08em', color: 'var(--text-faint)', fontWeight: 700, flex: 1 }}>Movement ledger</div>
        <BtnS variant="outline" size="sm" icon="fact_check" onClick={onAudit}>Audit</BtnS>
        <BtnS variant="ghost" size="sm" icon="download">Export</BtnS>
      </div>

      <div style={{ display: 'flex', flexDirection: 'column' }}>
        {rows.map((r, i) => {
          const k = KIND[r.kind];
          return (
            <div key={r.id} style={{ display: 'flex', alignItems: 'center', gap: 13, padding: '13px 0', borderBottom: i < rows.length - 1 ? '1px solid var(--divider)' : 'none' }}>
              <div style={{ width: 38, height: 38, borderRadius: 11, background: `var(--status-${k.tone === 'done' ? 'done' : k.tone === 'transit' ? 'transit' : 'warn'}-bg)`, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><IconS name={k.icon} size={19} color={k.fg} /></div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}><span style={{ fontFamily: 'var(--font-mono)', fontSize: 13, fontWeight: 700, color: 'var(--text-strong)' }}>{r.ref}</span><BadgeS tone={k.tone}>{k.label}</BadgeS></div>
                <div style={{ fontSize: 13, color: 'var(--text-muted)', marginTop: 2 }}>{r.party}</div>
                <div style={{ fontSize: 11.5, color: 'var(--text-faint)', marginTop: 2 }}>{r.when} · {r.by}</div>
              </div>
              <span style={{ fontFamily: 'var(--font-mono)', fontSize: 15, fontWeight: 800, color: r.tons >= 0 ? 'var(--ml-green-600)' : 'var(--ml-orange-600)' }}>{fmt(r.tons)} t</span>
            </div>
          );
        })}
      </div>
    </div>
  );
}

window.StockpileScreens = { StockpileManagement };
