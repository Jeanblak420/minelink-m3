#!/usr/bin/env dart

import 'dart:io';
import 'package:logging/logging.dart';

final _logger = Logger('PreCommitHook');

/// A pre-commit hook to check if new provider methods include action tracking
void main() {
  // Get the list of staged files
  final result = Process.runSync('git', ['diff', '--cached', '--name-only']);
  final stagedFiles = (result.stdout as String).split('\n');
  
  // Filter for Dart files that might contain provider notifiers
  final dartFiles = stagedFiles.where((file) => 
    file.endsWith('.dart') && 
    (file.contains('provider') || file.contains('notifier'))
  ).toList();
  
  bool hasIssues = false;
  
  // Check each file
  for (final file in dartFiles) {
    final fileContent = File(file).readAsStringSync();
    
    // Look for methods that might represent user actions
    final methodRegex = RegExp(r'Future<void>\s+(\w+)\s*\(');
    final methods = methodRegex.allMatches(fileContent);
    
    for (final method in methods) {
      final methodName = method.group(1);
      
      // Skip methods that are likely not user actions
      if (methodName == null || 
          methodName.startsWith('_') || 
          methodName == 'loadData' || 
          methodName == 'initialize' ||
          methodName == 'dispose') {
        continue;
      }
      
      // Check if the method includes action tracking
      final hasTracking = fileContent.contains('trackUserAction') || 
                          fileContent.contains('notifyUser') ||
                          fileContent.contains('createNotification');
      
      if (!hasTracking) {
        _logger.warning('Method "$methodName" in $file might be missing action tracking.');
        hasIssues = true;
      }
    }
  }
  
  if (hasIssues) {
    _logger.warning('\nSome methods might be missing action tracking.');
    _logger.warning('Please ensure all user actions create appropriate notifications.');
    _logger.warning('See docs/action_tracking_guide.md for more information.\n');
    
    // Uncomment to make this a blocking check
    // exit(1);
  }
  
  exit(0);
}
