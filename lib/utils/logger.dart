class AppLogger {
  static void info(String message) {
    _log('INFO', message);
  }

  static void warning(String message) {
    _log('WARN', message);
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log('ERROR', message);
    if (error != null) {
      _log('ERROR', 'Error: $error');
    }
    if (stackTrace != null) {
      _log('ERROR', 'StackTrace: $stackTrace');
    }
  }

  static void _log(String level, String message) {
    final timestamp = DateTime.now().toIso8601String();
    // ignore: avoid_print
    print('[$timestamp] [$level] $message');
  }

  static void reportError(Object err, StackTrace stackTrace) {
    AppLogger.error('Error reported', err, stackTrace);
  }
}
