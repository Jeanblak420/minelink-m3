import React from 'react';

export interface IconProps {
  /** Material Symbols Rounded ligature name, e.g. "local_shipping". */
  name: string;
  /** Pixel size. Default 22. */
  size?: number;
  /** CSS color. Defaults to inherited text color. */
  color?: string;
  /** 0 outlined, 1 filled. Default 0. (Forced to 1 when dimensional.) */
  fill?: 0 | 1;
  /** Optical weight 100–700. Default 400. */
  weight?: number;
  /** Render the faux-3D "extruded" look (gradient fill, depth edge, contact shadow). */
  dimensional?: boolean;
  /** Color ramp for the dimensional look. Default "cyan". */
  tone?: 'cyan' | 'blue' | 'green' | 'amber' | 'red' | 'teal' | 'navy';
  style?: React.CSSProperties;
}

export function Icon(props: IconProps): JSX.Element;
