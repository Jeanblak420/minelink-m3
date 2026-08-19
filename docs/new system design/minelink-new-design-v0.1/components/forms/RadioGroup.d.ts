import React from 'react';

export interface RadioOption { value: string; label: string; hint?: string; }

export interface RadioGroupProps {
  options: (string | RadioOption)[];
  value?: string;
  onChange?: (value: string) => void;
  name?: string;
  disabled?: boolean;
  style?: React.CSSProperties;
}

export function RadioGroup(props: RadioGroupProps): JSX.Element;
