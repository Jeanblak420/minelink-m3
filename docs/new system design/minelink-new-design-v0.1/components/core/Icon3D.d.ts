import React from 'react';

/** Names available in the Icon3D set. */
export type Icon3DName =
  | 'security' | 'route' | 'alerts' | 'contract' | 'inventory'
  | 'shipment' | 'weighbridge' | 'map' | 'payment' | 'team'
  | 'settings' | 'dashboard'
  | 'companies' | 'mine' | 'token' | 'warning' | 'energy'
  | 'driver' | 'supervisor' | 'buyer' | 'console' | 'stockpile'
  | 'active' | 'expired' | 'suspended' | 'history' | 'register' | 'export';

/** Flat Material Symbols name → Icon3D concept, for auto-upgrading display wells. */
export const ICON3D_ALIASES: Record<string, string>;

export interface Icon3DProps {
  /** Icon key from the set. Unknown names fall back to a neutral box. */
  name: Icon3DName | string;
  /** Rendered width in px (height scales to the 112×116 canvas). Default 72. */
  size?: number;
  /** Accessible label / <title>. Defaults to `name`. */
  title?: string;
  style?: React.CSSProperties;
}

/** Every name in the set, for iteration. */
export const ICON3D_NAMES: string[];

/** Soft-shaded faux-3D vector icon (no images, no WebGL). */
export function Icon3D(props: Icon3DProps): JSX.Element;
