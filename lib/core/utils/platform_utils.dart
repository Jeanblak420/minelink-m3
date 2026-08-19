import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;

class PlatformUtils {
  static bool get isWeb => kIsWeb;
  static bool get isMobile =>
      !kIsWeb && (io.Platform.isAndroid || io.Platform.isIOS);
  static bool get isDesktop =>
      !kIsWeb &&
      (io.Platform.isWindows || io.Platform.isMacOS || io.Platform.isLinux);
}
