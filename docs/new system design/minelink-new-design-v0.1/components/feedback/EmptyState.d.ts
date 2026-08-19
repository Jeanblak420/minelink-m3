import React from 'react';

export interface EmptyStateProps {
  /** Material Symbols name. */
  icon?: string;
  title: string;
  message?: string;
  /** Optional CTA node (e.g. a <Button/>). */
  action?: React.ReactNode;
  tone?: 'slate' | 'cyan' | 'amber';
  style?: React.CSSProperties;
}

export function EmptyState(props: EmptyStateProps): JSX.Element;
