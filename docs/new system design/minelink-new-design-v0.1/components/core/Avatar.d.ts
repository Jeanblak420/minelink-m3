import React from 'react';

export interface AvatarProps {
  /** Full name — initials are derived from it. */
  name?: string;
  /** Optional image URL (overrides initials). */
  src?: string;
  size?: number;
  tone?: 'cyan' | 'navy' | 'slate';
  style?: React.CSSProperties;
}

export function Avatar(props: AvatarProps): JSX.Element;
