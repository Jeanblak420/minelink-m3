import React from 'react';

export interface SegmentedOption { value: string; label: string; }

export interface SegmentedProps {
  options: (string | SegmentedOption)[];
  value?: string;
  onChange?: (value: string) => void;
  size?: 'sm' | 'md';
  style?: React.CSSProperties;
}

export function Segmented(props: SegmentedProps): JSX.Element;
