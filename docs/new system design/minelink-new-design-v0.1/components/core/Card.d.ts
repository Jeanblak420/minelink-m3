import React from 'react';

export interface CardProps {
  children: React.ReactNode;
  /** plain (white), hero (cyan-tinted gradient overview tile), inset (sunken well), chrome (navy). */
  tone?: 'plain' | 'hero' | 'inset' | 'chrome';
  /** Inner padding px. Default 20. */
  padding?: number;
  onClick?: () => void;
  style?: React.CSSProperties;
}

export function Card(props: CardProps): JSX.Element;
