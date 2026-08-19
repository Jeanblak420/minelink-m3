import React from 'react';

export interface UploadedFile { name: string; kind: 'image' | 'pdf'; }

export interface FileUploadProps {
  label?: string;
  /** Helper line inside the dropzone. */
  hint?: string;
  /** Accept attribute. Default 'image/*,application/pdf'. */
  accept?: string;
  /** Camera-first affordance (POD photos, ID docs). */
  capture?: boolean;
  value?: UploadedFile | null;
  onChange?: (file: UploadedFile | null) => void;
  disabled?: boolean;
  style?: React.CSSProperties;
}

export function FileUpload(props: FileUploadProps): JSX.Element;
