import React from 'react';

/**
 * @startingPoint section="Dashboard" subtitle="KPI tile with tinted icon well and trend delta" viewport="700x150"
 */
export interface StatCardProps {
  /** Material Symbols name. */
  icon: string;
  label: string;
  /** Headline value, e.g. "33.2" or "12". */
  value: React.ReactNode;
  /** Optional unit suffix, e.g. "t". */
  unit?: string;
  /** Optional delta text, e.g. "12.5t" or "2". */
  delta?: string;
  deltaDir?: 'up' | 'down';
  /** Icon well tint. */
  tone?: 'cyan' | 'amber' | 'green' | 'blue';
  style?: React.CSSProperties;
}

export function StatCard(props: StatCardProps): JSX.Element;
