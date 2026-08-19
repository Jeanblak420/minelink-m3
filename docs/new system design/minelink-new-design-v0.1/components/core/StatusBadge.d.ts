import React from 'react';

export interface StatusBadgeProps {
  children: React.ReactNode;
  /** transit=OTW (blue), atmine (amber), done=loaded/available (green), warn=maintenance (orange), error, neutral. */
  tone?: 'transit' | 'atmine' | 'done' | 'warn' | 'error' | 'neutral';
  /** Show a leading status dot. */
  dot?: boolean;
  style?: React.CSSProperties;
}

export function StatusBadge(props: StatusBadgeProps): JSX.Element;
