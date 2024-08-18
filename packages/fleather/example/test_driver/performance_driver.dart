import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() {
  final outputName = Platform.environment['FLEATHER_PERF_TEST_OUTPUT_NAME']!;
  return integrationDriver(
    responseDataCallback: (data) async {
      if (data != null) {
        final timeline =
            driver.Timeline.fromJson(data['timeline'] as Map<String, dynamic>);
        final summary = driver.TimelineSummary.summarize(timeline);
        await summary.writeTimelineToFile(outputName,
            pretty: true, includeSummary: true);
      }
    },
  );
}
