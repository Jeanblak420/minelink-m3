import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

bool isDataUriImage(String? value) {
  final trimmed = value?.trim();
  return trimmed != null && trimmed.startsWith('data:image/');
}

Uint8List? decodeDataUriImage(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || !isDataUriImage(trimmed)) {
    return null;
  }

  final commaIndex = trimmed.indexOf(',');
  if (commaIndex == -1) {
    return null;
  }

  try {
    return base64Decode(trimmed.substring(commaIndex + 1));
  } catch (_) {
    return null;
  }
}

ImageProvider? imageProviderFromString(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  final bytes = decodeDataUriImage(trimmed);
  if (bytes != null) {
    return MemoryImage(bytes);
  }

  return CachedNetworkImageProvider(trimmed);
}
