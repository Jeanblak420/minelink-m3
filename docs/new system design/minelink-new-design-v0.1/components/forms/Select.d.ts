import React from 'react';

export interface SelectOption { value: string; label: string; }

export interface SelectProps {
  /** Placeholder shown as the first, empty-value option. */
  label?: string;
  icon?: string;
  options?: (string | SelectOption)[];
  value?: string;
  onChange?: (e: React.ChangeEvent<HTMLSelectElement>) => void;
  style?: React.CSSProperties;
}

export function Select(props: SelectProps): JSX.Element;
