import React from 'react';

export interface CheckboxProps {
  checked?: boolean;
  /** Show a dash instead of a tick (mixed state). */
  indeterminate?: boolean;
  onChange?: (next: boolean) => void;
  disabled?: boolean;
  label?: string;
  hint?: string;
  style?: React.CSSProperties;
}

export function Checkbox(props: CheckboxProps): JSX.Element;
