import React from 'react';

export interface ToastProps {
  tone?: 'success' | 'error' | 'warn' | 'info';
  message: React.ReactNode;
  /** Optional action label (e.g. "Undo"). */
  action?: string;
  onAction?: () => void;
  onClose?: () => void;
  style?: React.CSSProperties;
}

export function Toast(props: ToastProps): JSX.Element;

export interface ToastStackProps { children: React.ReactNode; style?: React.CSSProperties; }
export function ToastStack(props: ToastStackProps): JSX.Element;
