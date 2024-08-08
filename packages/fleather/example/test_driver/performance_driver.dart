import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() {
  return integrationDriver(
    responseDataCallback: (data) async {
      if (data != null) {
        await writeTimeline(data, 'scrolling_timeline', 'scrolling');
        await writeTimeline(data, 'editing_timeline', 'editing');
      }
    },
  );
}

Future<void> writeTimeline(
    Map<String, dynamic> data, String key, String name) async {
  if (!data.containsKey(key)) return;

  final timeline = driver.Timeline.fromJson(data[key] as Map<String, dynamic>);
  final summary = driver.TimelineSummary.summarize(timeline);
  await summary.writeTimelineToFile(name,
      destinationDirectory: 'build/performance_timelines',
      pretty: true,
      includeSummary: true);
}
