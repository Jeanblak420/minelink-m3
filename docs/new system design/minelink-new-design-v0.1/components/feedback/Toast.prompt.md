One-liner: Navy snackbar toast with a colored tone bar/icon, optional action (Undo) and close — plus `ToastStack` for bottom-center stacking.

```jsx
<ToastStack>
  <Toast tone="success" message="Load confirmed · 34.5 t" onClose={dismiss} />
  <Toast tone="info" message="Notification cleared" action="Undo" onAction={undo} onClose={dismiss} />
</ToastStack>
```

Tones: success (green), error (red), warn (orange), info (cyan). Mirrors the app's SnackBar with Undo (e.g. clearing a notification).
