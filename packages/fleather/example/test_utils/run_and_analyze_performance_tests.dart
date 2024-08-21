// ignore_for_file: avoid_print

import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

/// Runs and analyzes performance tests.
///
/// It's an internal tests for developers and maintainers, and is not safe
/// since you might end up losing your changes.
/// Use with care and commit changes in current branch and master before.
///
/// example: dart run test_utils/run_and_analyze_performance_tests.dart macos
void main(List<String> args) {
  final deviceName = args.first;
  final branchName =
      Process.runSync('git', ['rev-parse', '--abbrev-ref', 'HEAD'])
          .stdout
          .toString()
          .trim();

  warning('Running tests for $branchName');
  Process.runSync(
    'flutter',
    [
      'drive',
      '-d',
      deviceName,
      '--driver=test_driver/performance_driver.dart',
      '--target=integration_test/scrolling_performance_test.dart',
      '--profile',
    ],
    environment: {'FLEATHER_PERF_TEST_OUTPUT_NAME': 'target_scrolling'},
  );
  Process.runSync(
    'flutter',
    [
      'drive',
      '-d',
      deviceName,
      '--driver=test_driver/performance_driver.dart',
      '--target=integration_test/editing_performance_test.dart',
      '--profile',
    ],
    environment: {'FLEATHER_PERF_TEST_OUTPUT_NAME': 'target_editing'},
  );

  Process.runSync('git', ['stash', '--include-untracked']);
  Process.runSync('git', ['fetch', 'origin/master']);
  Process.runSync('git', ['checkout', 'origin/master']);

  warning('Running tests for origin/master');
  Process.runSync(
    'flutter',
    [
      'drive',
      '-d',
      deviceName,
      '--driver=test_driver/performance_driver.dart',
      '--target=integration_test/scrolling_performance_test.dart',
      '--profile',
    ],
    environment: {'FLEATHER_PERF_TEST_OUTPUT_NAME': 'ref_scrolling'},
  );
  Process.runSync(
    'flutter',
    [
      'drive',
      '-d',
      deviceName,
      '--driver=test_driver/performance_driver.dart',
      '--target=integration_test/editing_performance_test.dart',
      '--profile',
    ],
    environment: {'FLEATHER_PERF_TEST_OUTPUT_NAME': 'ref_editing'},
  );

  warning('Analyzing tests for scrolling');
  print(Process.runSync('dart', [
    'run',
    'test_utils/analyze_performance.dart',
    '$testOutputsDirectory/ref_scrolling.timeline_summary.json',
    '$testOutputsDirectory/target_scrolling.timeline_summary.json',
  ]).stdout);

  warning('Analyzing tests for editing');
  print(Process.runSync('dart', [
    'run',
    'test_utils/analyze_performance.dart',
    '$testOutputsDirectory/ref_editing.timeline_summary.json',
    '$testOutputsDirectory/target_editing.timeline_summary.json',
  ]).stdout);

  Process.runSync('git', ['checkout', branchName]);
  Process.runSync('git', ['stash', 'apply']);
}

void warning(String text) => print('\x1B[33m$text\x1B[0m');
