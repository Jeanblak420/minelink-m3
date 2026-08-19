One-liner: Drag-drop / camera document field with an uploaded-state chip — for POD photos, certificates, employee documents.

```jsx
<FileUpload label="Proof of delivery" capture hint="Photo of signed waybill" onChange={setPod} />
<FileUpload label="Certificate of Analysis" onChange={setCoa} />
```

Dashed dropzone (cyan on drag) that swaps to a cyan "Uploaded" chip with file icon + remove. `capture` shows a camera prompt for mobile POD/ID capture. Demo simulates a picked file on click.
