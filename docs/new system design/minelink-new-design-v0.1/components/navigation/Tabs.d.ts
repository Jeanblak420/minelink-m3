import React from 'react';

export interface TabItem { key: string; label: string; icon?: string; badge?: string | number; }

export interface TabsProps {
  tabs: TabItem[];
  active?: string;
  onChange?: (key: string) => void;
  /** underline (default, section tabs) or pill (filter chips). */
  variant?: 'underline' | 'pill';
  style?: React.CSSProperties;
}

export function Tabs(props: TabsProps): JSX.Element;
