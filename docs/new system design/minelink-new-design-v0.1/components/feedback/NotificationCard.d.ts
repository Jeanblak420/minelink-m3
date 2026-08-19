import React from 'react';

export type NotificationTypeKey =
  | 'employeeRequest' | 'roleAssigned' | 'requestDeclined' | 'roleConfirmation'
  | 'securityAlert' | 'controllerAction' | 'dismissalInitiated'
  | 'fleetVehicleAdded' | 'fleetDriverAssigned' | 'general';

export interface AppNotification {
  id: string;
  type: NotificationTypeKey;
  importance?: 'normal' | 'high' | 'extreme';
  title: string;
  message: string;
  at: string;
  by?: string;
  read?: boolean;
}

export interface NotificationCardProps {
  notification: AppNotification;
  onClick?: (n: AppNotification) => void;
  onDismiss?: (n: AppNotification) => void;
  compact?: boolean;
  style?: React.CSSProperties;
}

export function NotificationCard(props: NotificationCardProps): JSX.Element;
