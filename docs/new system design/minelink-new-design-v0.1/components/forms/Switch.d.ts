import React from 'react';

export interface SwitchProps {
  checked?: boolean;
  onChange?: (next: boolean) => void;
  disabled?: boolean;
  /** Optional row label (renders a full 44px row). */
  label?: string;
  /** Secondary line under the label. */
  hint?: string;
  style?: React.CSSProperties;
}

export function Switch(props: SwitchProps): JSX.Element;
