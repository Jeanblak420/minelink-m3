import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/utils/realtime_test.dart';
import 'package:flutter_application_1/core/utils/realtime_setup.dart';
import 'package:flutter_application_1/core/utils/logger.dart';

/// Command line tool to test realtime features
void main(List<String> args) async {
  final logger = LoggerFactory.getLogger('RealtimeTest');
  // Initialize Supabase
  await SupabaseConfig.initialize();

  // Enable realtime for all tables
  await RealtimeSetup.enableRealtimeForAllTables();

  if (args.isEmpty) {
    printUsage(logger);
    return;
  }

  final command = args[0];

  switch (command) {
    case 'subscription':
      if (args.length < 3) {
        logger.e('Error: Missing table name or primary key.');
        printUsage(logger);
        return;
      }
      await RealtimeTest.testRealtimeSubscription(args[1], args[2]);
      break;

    case 'stream':
      if (args.length < 3) {
        logger.e('Error: Missing table name or primary key.');
        printUsage(logger);
        return;
      }
      await RealtimeTest.testStreamSubscription(args[1], args.sublist(2));
      break;

    case 'broadcast':
      await RealtimeTest.testBroadcast();
      break;

    case 'presence':
      await RealtimeTest.testPresence();
      break;

    case 'all':
      await RealtimeTest.runAllTests();
      break;

    default:
      logger.e('Error: Unknown command "$command".');
      printUsage(logger);
  }
}

void printUsage(Logger logger) {
  logger.i('Usage: dart bin/realtime_test.dart <command> [args]');
  logger.i('');
  logger.i('Commands:');
  logger.i('  subscription <table> <primary_key>  Test realtime subscription to a table');
  logger.i('  stream <table> <primary_key...>     Test stream subscription to a table');
  logger.i('  broadcast                           Test broadcast feature');
  logger.i('  presence                            Test presence feature');
  logger.i('  all                                 Run all tests');
  logger.i('');
  logger.i('Examples:');
  logger.i('  dart bin/realtime_test.dart subscription companies id');
  logger.i('  dart bin/realtime_test.dart stream employees id');
  logger.i('  dart bin/realtime_test.dart broadcast');
  logger.i('  dart bin/realtime_test.dart presence');
  logger.i('  dart bin/realtime_test.dart all');
}
