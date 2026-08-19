import React from 'react';

export interface PlatePillProps {
  children: React.ReactNode;
  size?: 'sm' | 'md' | 'lg';
  style?: React.CSSProperties;
}

export function PlatePill(props: PlatePillProps): JSX.Element;
