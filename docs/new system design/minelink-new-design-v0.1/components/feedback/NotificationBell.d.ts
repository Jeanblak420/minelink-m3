import React from 'react';
import { AppNotification } from './NotificationCard';

export interface NotificationBellProps {
  notifications: AppNotification[];
  onRead?: (n: AppNotification) => void;
  onReadAll?: () => void;
  onDismiss?: (n: AppNotification) => void;
  onViewAll?: () => void;
  style?: React.CSSProperties;
}

export function NotificationBell(props: NotificationBellProps): JSX.Element;
