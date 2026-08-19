import 'package:flutter/foundation.dart';

/// A simple logger class for consistent logging across the app
class Logger {
  final String _tag;

  /// Creates a new logger with the specified tag
  Logger(this._tag);

  /// Log a debug message
  void d(String message) {
    _log('DEBUG', message);
  }

  /// Log an info message
  void i(String message) {
    _log('INFO', message);
  }

  /// Log a warning message
  void w(String message) {
    _log('WARNING', message);
  }

  /// Log an error message
  void e(String message, [dynamic error, StackTrace? stackTrace]) {
    _log('ERROR', message);

    if (error != null) {
      debugPrint('[$_tag] ERROR: $error');
    }

    if (stackTrace != null) {
      debugPrint('[$_tag] STACK TRACE: $stackTrace');
    }
  }

  /// Internal method to log a message with the specified level
  void _log(String level, String message) {
    debugPrint('[$_tag] $level: $message');
  }
}

/// Factory to create loggers for different parts of the app
class LoggerFactory {
  static final Map<String, Logger> _loggers = {};

  /// Get a logger for the specified tag
  static Logger getLogger(String tag) {
    if (!_loggers.containsKey(tag)) {
      _loggers[tag] = Logger(tag);
    }
    return _loggers[tag]!;
  }
}
