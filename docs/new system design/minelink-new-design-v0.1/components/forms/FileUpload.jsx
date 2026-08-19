import React from 'react';
import { Icon } from '../core/Icon.jsx';

/** Drag-drop / camera document upload field. Purely presentational demo:
 * simulates a picked file. Use for POD upload, employee docs, certificates. */
export function FileUpload({ label, hint, accept = 'image/*,application/pdf', capture = false, value, onChange, disabled = false, style }) {
  const [file, setFile] = React.useState(value || null);
  const [drag, setDrag] = React.useState(false);
  const pick = (name, kind) => { const f = { name, kind }; setFile(f); onChange && onChange(f); };
  const simulate = () => pick(capture ? 'IMG_pod_4471.jpg' : 'document.pdf', capture ? 'image' : 'pdf');

  return (
    <label style={{ display: 'flex', flexDirection: 'column', gap: 7, fontFamily: 'var(--font-sans)', ...style }}>
      {label && <span style={{ fontSize: 14, fontWeight: 600, color: 'var(--text-body)' }}>{label}</span>}
      {file ? (
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 14px', border: '1.5px solid var(--border-accent)', background: 'var(--ml-well-cyan)', borderRadius: 'var(--radius-md)' }}>
          <div style={{ width: 40, height: 40, borderRadius: 10, background: 'var(--surface-card)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <Icon name={file.kind === 'image' ? 'image' : 'picture_as_pdf'} size={22} color="var(--accent)" />
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 13.5, fontWeight: 600, color: 'var(--text-strong)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{file.name}</div>
            <div style={{ fontSize: 12, color: 'var(--ml-green-700)', display: 'flex', alignItems: 'center', gap: 4 }}><Icon name="check_circle" size={13} fill={1} color="var(--ml-green-600)" />Uploaded</div>
          </div>
          <button type="button" onClick={() => { setFile(null); onChange && onChange(null); }} style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--text-faint)', display: 'flex' }}><Icon name="close" size={20} /></button>
        </div>
      ) : (
        <div
          onClick={() => !disabled && simulate()}
          onDragOver={(e) => { e.preventDefault(); setDrag(true); }}
          onDragLeave={() => setDrag(false)}
          onDrop={(e) => { e.preventDefault(); setDrag(false); if (!disabled) simulate(); }}
          style={{
            display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 8,
            padding: '24px 18px', borderRadius: 'var(--radius-md)', textAlign: 'center',
            border: `1.5px dashed ${drag ? 'var(--accent)' : 'var(--border-strong)'}`,
            background: drag ? 'var(--ml-well-cyan)' : 'var(--surface-sunken)',
            cursor: disabled ? 'not-allowed' : 'pointer', opacity: disabled ? 0.5 : 1,
            transition: 'border-color var(--dur-fast), background var(--dur-fast)',
          }}
        >
          <div style={{ width: 44, height: 44, borderRadius: 12, background: 'var(--surface-card)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Icon name={capture ? 'photo_camera' : 'cloud_upload'} size={24} color="var(--accent)" />
          </div>
          <div style={{ fontSize: 14, fontWeight: 700, color: 'var(--text-strong)' }}>{capture ? 'Take a photo or upload' : 'Drop a file or click to upload'}</div>
          <div style={{ fontSize: 12.5, color: 'var(--text-muted)' }}>{hint || 'PDF or image · up to 10 MB'}</div>
        </div>
      )}
    </label>
  );
}
