/* MineLink — Buyer extra screens: My Products (+detail, Create PO), Recons filter,
 * Waybill quick-edit. Slides 24-27. Merges into window.BuyerScreens. */
const DBx = window.MineLinkDesignSystem_9acfde;
const { Icon: IcB2, StatusBadge: BdgB2, PlatePill: PltB2, Button: BtnB2, Input: InB2, Select: SelB2 } = DBx;
const { SectionTitle: STitleB2, DataTable: TblB2, SlideOver: SlideB2, Modal: ModalB2 } = window.MLShell;

const PRODUCTS = [
  { id: 'p1', mine: 'Brys Mine', commodity: 'Coal RB2', to: 'Port', km: 450, tons: 15000, trucks: 20,
    d: 695, w: 1665, m: 8611, y: 15000,
    trips: [{ plate: 'HDQ 123 MP', tone: 'transit', status: 'OTW to loading' }, { plate: 'IDD 345 MP', tone: 'done', status: 'OTW to offload' }, { plate: 'WEF 473 MP', tone: 'atmine', status: 'At mine' }] },
  { id: 'p2', mine: 'Henny Mine', commodity: 'Chrome 38/40', to: 'JJ Wash Plant', km: 35, tons: 800, trucks: 6,
    d: 120, w: 640, m: 2400, y: 6800,
    trips: [{ plate: 'JNS 918 MP', tone: 'transit', status: 'OTW to loading' }] },
  { id: 'p3', mine: 'JJ Wash Plant', commodity: 'Chrome 38/40', to: 'Port', km: 150, tons: 500, trucks: 4,
    d: 60, w: 300, m: 1450, y: 4100,
    trips: [{ plate: 'KLM 552 GP', tone: 'done', status: 'OTW to offload' }] },
];
const AVAILABLE_PRODUCTS = ['Coal RB2', 'Chrome 38/40', 'Coal RB1', 'Manganese 44%', 'Iron Ore 62%'];

function Money({ children }) { return <span style={{ fontFamily: 'var(--font-mono)' }}>{children}</span>; }
function TonsGrid({ p }) {
  return (
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 1, background: 'var(--border-card)', borderRadius: 'var(--radius-md)', overflow: 'hidden' }}>
      {[['Day', p.d], ['Week', p.w], ['Month', p.m], ['Year', p.y]].map(([l, v], i) => (
        <div key={i} style={{ background: 'var(--surface-card)', padding: '12px 14px' }}><div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: '.05em', color: 'var(--text-faint)' }}>{l}</div><div style={{ fontSize: 17, fontWeight: 800, color: 'var(--text-strong)', fontFamily: 'var(--font-mono)', marginTop: 2 }}>{v.toLocaleString()} <span style={{ fontSize: 11, color: 'var(--text-muted)' }}>t</span></div></div>
      ))}
    </div>
  );
}

function BuyerProducts({ go }) {
  const [detail, setDetail] = React.useState(null);
  const [po, setPo] = React.useState(false);
  const [reqProd, setReqProd] = React.useState(false);
  return (
    <div style={{ position: 'relative' }}>
      {/* All tons moved */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 16, marginBottom: 20 }}>
        {[['inventory_2', 'Tons moved · Day', '2,000', 'cyan'], ['calendar_view_week', 'This week', '9,000', 'blue'], ['calendar_month', 'This month', '68,000', 'green'], ['stacked_line_chart', 'This year', '450,000', 'amber']].map(([ic, l, v], i) => (
          <DBx.StatCard key={i} icon={ic} label={l} value={v} unit="t" tone={['cyan', 'blue', 'green', 'amber'][i]} />
        ))}
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 16 }}>
        <IcB2 name="inventory" size={22} color="var(--accent)" />
        <h2 style={{ margin: 0, fontSize: 18, fontWeight: 800, color: 'var(--text-strong)', flex: 1 }}>My products</h2>
        <BtnB2 size="sm" variant="outline" icon="local_shipping" onClick={() => go('request-new')}>Request transportation</BtnB2>
        <BtnB2 size="sm" icon="add_shopping_cart" onClick={() => setReqProd(true)}>Request products</BtnB2>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 16 }}>
        {PRODUCTS.map((p) => (
          <div key={p.id} onClick={() => setDetail(p)} style={{ cursor: 'pointer', background: 'var(--surface-card)', border: '1px solid var(--border-card)', borderRadius: 'var(--radius-xl)', boxShadow: 'var(--shadow-sm)', padding: 20, transition: 'box-shadow .18s, transform .18s' }}
            onMouseEnter={(e) => { e.currentTarget.style.boxShadow = 'var(--shadow-lg)'; e.currentTarget.style.transform = 'translateY(-3px)'; }} onMouseLeave={(e) => { e.currentTarget.style.boxShadow = 'var(--shadow-sm)'; e.currentTarget.style.transform = 'none'; }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 12 }}>
              <div style={{ width: 46, height: 46, borderRadius: 13, background: 'var(--ml-well-cyan)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><IcB2 name="diamond" size={23} color="var(--accent)" /></div>
              <div style={{ flex: 1, minWidth: 0 }}><div style={{ fontSize: 16, fontWeight: 800, color: 'var(--text-strong)' }}>{p.mine}</div><div style={{ fontSize: 12.5, color: 'var(--accent)', fontWeight: 600 }}>{p.commodity}</div></div>
              <IcB2 name="chevron_right" size={20} color="var(--text-faint)" />
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 7, fontSize: 13.5, color: 'var(--text-body)' }}>{p.mine} <IcB2 name="arrow_forward" size={13} color="var(--text-faint)" /> {p.to}</div>
            <div style={{ display: 'flex', gap: 16, marginTop: 12, fontSize: 12.5, color: 'var(--text-muted)', fontFamily: 'var(--font-mono)' }}><span>{p.km} km</span><span>{p.tons.toLocaleString()} t</span><span>{p.trucks} trucks</span></div>
          </div>
        ))}
      </div>

      {/* Product detail slide-over */}
      <SlideB2 open={!!detail} title={detail ? `${detail.mine} — ${detail.commodity}` : ''} onClose={() => setDetail(null)} width={520}>
        {detail && (<div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 7, fontSize: 14, color: 'var(--text-body)' }}>{detail.mine} <IcB2 name="arrow_forward" size={14} color="var(--text-faint)" /> {detail.to} · <span style={{ fontFamily: 'var(--font-mono)' }}>{detail.km} km · {detail.trucks} trucks on route</span></div>
          <div><div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: '.08em', color: 'var(--text-faint)', fontWeight: 700, marginBottom: 8 }}>Tons</div><TonsGrid p={detail} /></div>
          <div>
            <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: '.08em', color: 'var(--text-faint)', fontWeight: 700, marginBottom: 8 }}>Active trips on route</div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
              {detail.trips.map((t, i) => (
                <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '9px 12px', border: '1px solid var(--border-card)', borderRadius: 'var(--radius-md)' }}>
                  <IcB2 name="local_shipping" size={18} color="var(--accent)" /><PltB2 size="sm">{t.plate}</PltB2>
                  <BdgB2 tone={t.tone} style={{ marginLeft: 'auto' }}>{t.status}</BdgB2>
                  <IcB2 name="map" size={17} color="var(--text-faint)" />
                </div>
              ))}
            </div>
            <div style={{ fontSize: 11.5, color: 'var(--text-faint)', marginTop: 6 }}>Tap a trip to open truck locations and highlight it on the map.</div>
          </div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
            <BtnB2 size="sm" variant="outline" icon="download">View / download recons</BtnB2>
            <BtnB2 size="sm" variant="outline" icon="edit_document" onClick={() => go('waybills')}>Edit waybill info</BtnB2>
            <BtnB2 size="sm" variant="outline" icon="list">View / edit truck list</BtnB2>
            <BtnB2 size="sm" variant="ghost" icon="science">Stockpiles &amp; assay reports</BtnB2>
          </div>
          <BtnB2 block icon="post_add" onClick={() => setPo(true)}>Create purchase order</BtnB2>
        </div>)}
      </SlideB2>

      {/* Create PO modal */}
      <ModalB2 open={po} title="Create purchase order" onClose={() => setPo(false)} width={460}
        footer={<><BtnB2 variant="outline" onClick={() => setPo(false)}>Cancel</BtnB2><BtnB2 icon="check_circle" onClick={() => setPo(false)}>Create PO</BtnB2></>}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <SelB2 label="Mine / source" icon="conveyor_belt" options={PRODUCTS.map((p) => p.mine)} />
          <SelB2 label="Product" icon="diamond" options={AVAILABLE_PRODUCTS} />
          <div style={{ display: 'flex', gap: 12 }}><div style={{ flex: 1 }}><InB2 label="Tons" type="number" placeholder="e.g. 5,000" /></div><div style={{ flex: 1 }}><InB2 label="Price / ton (R)" type="number" placeholder="0.00" /></div></div>
          <InB2 label="Destination" icon="warehouse" placeholder="e.g. Saldanha Port" />
          <div style={{ display: 'flex', gap: 8, padding: 12, background: 'var(--ml-well-cyan)', borderRadius: 'var(--radius-md)', fontSize: 12.5, color: 'var(--ml-cyan-700)' }}><IcB2 name="info" size={16} color="var(--accent)" />Creating a PO opens a transaction where you can capture waybill details.</div>
        </div>
      </ModalB2>

      <ModalB2 open={reqProd} title="Request products" onClose={() => setReqProd(false)} width={440}
        footer={<><BtnB2 variant="outline" onClick={() => setReqProd(false)}>Cancel</BtnB2><BtnB2 icon="send" onClick={() => setReqProd(false)}>Send request</BtnB2></>}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div style={{ fontSize: 13, color: 'var(--text-muted)' }}>Ask MineLink to source a mineral product for you.</div>
          <SelB2 label="Product" icon="diamond" options={AVAILABLE_PRODUCTS} />
          <InB2 label="Tons required / month" type="number" placeholder="e.g. 4,000" />
          <InB2 label="Preferred destination" icon="warehouse" placeholder="e.g. Vanderbijlpark" />
        </div>
      </ModalB2>
    </div>
  );
}

/* Recons with filter (slide 26) */
function BuyerReconsFull() {
  const rows = [
    { src: 'Brys Mine', product: 'Coal RB2', transporter: 'Roadhaul', loaded: '15,000 t', received: '14,940 t', variance: '-60 t', tone: 'atmine', state: 'REVIEW' },
    { src: 'Henny Mine', product: 'Chrome 38/40', transporter: 'Trans African', loaded: '6,800 t', received: '6,800 t', variance: '0 t', tone: 'done', state: 'MATCHED' },
    { src: 'JJ Wash Plant', product: 'Chrome 38/40', transporter: 'Corridor', loaded: '4,100 t', received: '4,088 t', variance: '-12 t', tone: 'atmine', state: 'REVIEW' },
  ];
  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 16, flexWrap: 'wrap' }}>
        <IcB2 name="balance" size={22} color="var(--accent)" />
        <h2 style={{ margin: 0, fontSize: 18, fontWeight: 800, color: 'var(--text-strong)', flex: 1 }}>Reconciliations</h2>
        <SelB2 label="All mines" icon="conveyor_belt" options={['Brys Mine', 'Henny Mine', 'JJ Wash Plant']} />
        <SelB2 label="All products" icon="diamond" options={AVAILABLE_PRODUCTS} />
        <SelB2 label="All transporters" icon="local_shipping" options={['Roadhaul', 'Trans African', 'Corridor']} />
        <SelB2 label="This month" icon="calendar_month" options={['Today', 'This week', 'This month', 'This year']} />
        <BtnB2 size="sm" variant="outline" icon="download">Export</BtnB2>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 16, marginBottom: 18 }}>
        {[['Total loaded', '25,900 t'], ['Total received', '25,828 t'], ['Net variance', '-72 t'], ['Match rate', '99.7%']].map(([l, v], i) => (
          <div key={i} style={{ background: 'var(--surface-card)', border: '1px solid var(--border-card)', borderRadius: 'var(--radius-lg)', padding: 16 }}><div style={{ fontSize: 12.5, color: 'var(--text-muted)' }}>{l}</div><div style={{ fontSize: 22, fontWeight: 800, color: i === 2 ? 'var(--ml-orange-600)' : 'var(--text-strong)', fontFamily: 'var(--font-mono)', marginTop: 4 }}>{v}</div></div>
        ))}
      </div>
      <DBx.Card padding={22}>
        <TblB2
          columns={[{ key: 'src', label: 'Mine / Source', w: '1.2fr' }, { key: 'product', label: 'Product', w: '1fr' }, { key: 'transporter', label: 'Transporter', w: '1fr' }, { key: 'loaded', label: 'Loaded', w: '0.9fr', align: 'right' }, { key: 'received', label: 'Received', w: '0.9fr', align: 'right' }, { key: 'variance', label: 'Variance', w: '0.8fr', align: 'right' }, { key: 'state', label: 'Status', w: '0.9fr', align: 'right' }]}
          rows={rows}
          renderCell={(r, k) => {
            if (k === 'src') return <span style={{ fontWeight: 700, color: 'var(--text-strong)' }}>{r.src}</span>;
            if (k === 'state') return <BdgB2 tone={r.tone}>{r.state}</BdgB2>;
            if (k === 'variance') return <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 700, color: r.variance === '0 t' ? 'var(--ml-green-600)' : 'var(--ml-orange-600)' }}>{r.variance}</span>;
            if (k === 'product' || k === 'transporter') return <span style={{ fontSize: 13.5, color: 'var(--text-body)' }}>{r[k]}</span>;
            return <span style={{ fontFamily: 'var(--font-mono)', fontSize: 14 }}>{r[k]}</span>;
          }}
        />
      </DBx.Card>
    </div>
  );
}

/* Waybills — quick edit per route (slide 27) */
function BuyerWaybillsFull() {
  const [edit, setEdit] = React.useState(null);
  const routes = [
    { id: 'w1', from: 'Brys Mine', to: 'Port', product: 'Coal RB2', order: 'PO-4471' },
    { id: 'w2', from: 'Henny Mine', to: 'JJ Wash Plant', product: 'Chrome 38/40', order: 'PO-4468' },
    { id: 'w3', from: 'JJ Wash Plant', to: 'Port', product: 'Chrome 38/40', order: 'PO-4465' },
  ];
  return (
    <div style={{ position: 'relative' }}>
      <STitleB2 icon="description">Waybills</STitleB2>
      <p style={{ margin: '-6px 0 16px', fontSize: 13.5, color: 'var(--text-muted)' }}>Click a route to update its waybill — a fast way to keep destination, product and order numbers current.</p>
      <DBx.Card padding={16}>
        {routes.map((r, i) => (
          <button key={r.id} type="button" onClick={() => setEdit(r)} style={{ display: 'flex', alignItems: 'center', gap: 14, width: '100%', textAlign: 'left', border: 'none', background: 'transparent', cursor: 'pointer', padding: '14px 8px', borderBottom: i < routes.length - 1 ? '1px solid var(--divider)' : 'none' }}>
            <div style={{ width: 40, height: 40, borderRadius: 11, background: 'var(--ml-well-amber)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><IcB2 name="description" size={20} color="var(--ml-orange-600)" /></div>
            <div style={{ flex: 1 }}><div style={{ display: 'flex', alignItems: 'center', gap: 7, fontSize: 14.5, fontWeight: 700, color: 'var(--text-strong)' }}>{r.from} <IcB2 name="arrow_forward" size={13} color="var(--text-faint)" /> {r.to}</div><div style={{ fontSize: 12.5, color: 'var(--text-muted)' }}>{r.product} · <span style={{ fontFamily: 'var(--font-mono)' }}>{r.order}</span></div></div>
            <IcB2 name="edit" size={18} color="var(--text-faint)" />
          </button>
        ))}
      </DBx.Card>
      <ModalB2 open={!!edit} title={edit ? `Waybill — ${edit.from} → ${edit.to}` : ''} onClose={() => setEdit(null)}
        footer={<><BtnB2 variant="outline" onClick={() => setEdit(null)}>Cancel</BtnB2><BtnB2 icon="check_circle" onClick={() => setEdit(null)}>Save waybill</BtnB2></>}>
        {edit && (<div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <InB2 label="Destination" icon="warehouse" defaultValue={edit.to} />
          <SelB2 label="Product" icon="diamond" options={AVAILABLE_PRODUCTS} />
          <InB2 label="Order number" icon="tag" defaultValue={edit.order} />
        </div>)}
      </ModalB2>
    </div>
  );
}

window.BuyerScreens = Object.assign(window.BuyerScreens || {}, { BuyerProducts, BuyerReconsFull, BuyerWaybillsFull });
