import 'dart:convert';
import 'dart:io';

class Criteria {
  final String key, title;
  final double threshold;

  const Criteria(this.key, this.title, {this.threshold = 0.1});

  bool isRegression(double target, double reference) {
    final double changeRatio = (target - reference) / reference;
    return changeRatio > threshold;
  }

  bool isWorse(double target, double reference) => target > reference;
}

const _criterias = [
  Criteria('average_frame_build_time_millis', 'Average Frame Build Time'),
  Criteria('90th_percentile_frame_build_time_millis',
      '90th Percentile Frame Build Time'),
  Criteria('99th_percentile_frame_build_time_millis',
      '90th Percentile Frame Build Time'),
  Criteria('average_gpu_frame_time', 'Average GPU Frame Time'),
  Criteria('average_memory_usage', 'Average Memory Usage'),
  Criteria('average_cpu_usage', 'Average CPU Usage'),
];

const _performanceTimelinesPath = 'build/performance_timelines';
const _referencePerformanceTimelinesPath =
    'build/reference_performance_timelines';

void main() {
  final outputBuffer = StringBuffer();
  bool hasRegression = false;

  final performanceTimelinesDir = Directory(_performanceTimelinesPath);
  for (final fileEntity in performanceTimelinesDir.listSync()) {
    if (!fileEntity.path.contains('timeline_summary.json')) continue;
    final fileName = fileEntity.path.split('/').last;
    final result = _analyze(fileName);
    hasRegression = hasRegression || result.$2;
    outputBuffer.writeln(result.$1);
  }

  if (hasRegression) {
    outputBuffer.write(buildErrorMessage('Performance tests found regression'));
  } else {
    outputBuffer
        .write(buildSuccessMessage('Performance tests found no regression'));
  }

  print(outputBuffer.toString());
  exit(hasRegression ? 1 : 0);
}

(String, bool) _analyze(String fileName) {
  final Map<String, dynamic> targetSummary = jsonDecode(
      File('$_performanceTimelinesPath/$fileName').readAsStringSync());
  Map<String, dynamic>? referenceSummary;
  final referenceSummaryFile =
      File('$_referencePerformanceTimelinesPath/$fileName');
  if (referenceSummaryFile.existsSync()) {
    referenceSummary = jsonDecode(referenceSummaryFile.readAsStringSync());
  }

  bool testHasRegression = false;
  final outputBuffer = StringBuffer();

  for (final criteria in _criterias) {
    if (!targetSummary.containsKey(criteria.key)) continue;
    bool criteriaHasRegression = false;
    final double targetValue = targetSummary[criteria.key];
    final double? referenceValue = referenceSummary?[criteria.key];
    if (referenceValue != null) {
      criteriaHasRegression =
          criteria.isRegression(targetValue, referenceValue);
    }
    outputBuffer.write('${criteria.title}: Target: ');
    if (referenceValue != null &&
        criteria.isWorse(targetValue, referenceValue)) {
      outputBuffer.write(buildErrorMessage(targetValue.toStringAsFixed(2)));
    } else {
      outputBuffer.write(targetValue.toStringAsFixed(2));
    }
    if (referenceValue != null) {
      outputBuffer
          .writeln(' Reference: ${referenceValue.toStringAsFixed(2)}');
    } else {
      outputBuffer.writeln();
    }
    testHasRegression = testHasRegression || criteriaHasRegression;
  }

  outputBuffer
      .write('Performance tests for ${fileName.split('.').first} found ');
  if (testHasRegression) {
    outputBuffer.writeln(buildErrorMessage('regression'));
  } else {
    outputBuffer.writeln('no regression');
  }

  return (outputBuffer.toString(), testHasRegression);
}

void assertTrueOrExit(bool assertion, [String? message]) {
  if (!assertion) {
    if (message != null) {
      error(message);
    }
    exit(1);
  }
}

void error(String message) => print(buildErrorMessage(message));

String buildErrorMessage(String message) => '\x1B[31m$message\x1B[0m';
String buildSuccessMessage(String message) => '\x1B[32m$message\x1B[0m';
