import React from 'react';

/**
 * @startingPoint section="Core" subtitle="Primary, confirm, depart, outline & ghost buttons" viewport="700x150"
 */
export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  /** primary=cyan, go=green confirm, leave=orange depart, tonal, outline, ghost, danger. */
  variant?: 'primary' | 'go' | 'leave' | 'tonal' | 'outline' | 'ghost' | 'danger';
  size?: 'sm' | 'md' | 'lg';
  /** Material Symbols name shown before the label. */
  icon?: string;
  /** Material Symbols name shown after the label. */
  iconRight?: string;
  /** Full-width. */
  block?: boolean;
  disabled?: boolean;
}

export function Button(props: ButtonProps): JSX.Element;
