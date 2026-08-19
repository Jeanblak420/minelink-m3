import React from 'react';

export interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  /** Helper text below the field. */
  hint?: string;
  required?: boolean;
  /** Leading Material Symbols icon. */
  icon?: string;
  /** Error message (turns the field red). */
  error?: string;
}

export function Input(props: InputProps): JSX.Element;
