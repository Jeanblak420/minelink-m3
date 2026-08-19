import React from 'react';

/**
 * @startingPoint section="Dashboard" subtitle="Navigational feature tile with icon chip and Open action" viewport="700x260"
 */
export interface FeatureCardProps {
  icon: string;
  title: string;
  description: React.ReactNode;
  /** Button label. Default "Open". */
  actionLabel?: string;
  tone?: 'cyan' | 'amber' | 'green' | 'blue';
  onOpen?: () => void;
  style?: React.CSSProperties;
}

export function FeatureCard(props: FeatureCardProps): JSX.Element;
