// ignore_for_file: avoid_print

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

void main(List<String> args) {
  final outputBuffer = StringBuffer();
  bool hasRegression = false;

  final reference = args[0];
  final target = args[1];

  final result = _analyze(reference, target);
  hasRegression = hasRegression || result.$2;
  outputBuffer.writeln(result.$1);

  print(outputBuffer.toString());
  exit(hasRegression ? 1 : 0);
}

(String, bool) _analyze(String reference, String target) {
  final Map<String, dynamic> referenceSummary =
      jsonDecode(File(reference).readAsStringSync());
  final Map<String, dynamic> targetSummary =
      jsonDecode(File(target).readAsStringSync());

  bool testHasRegression = false;
  final outputBuffer = StringBuffer();

  for (final criteria in _criterias) {
    if (!targetSummary.containsKey(criteria.key)) continue;
    bool criteriaHasRegression = false;
    final double targetValue = targetSummary[criteria.key];
    final double referenceValue = referenceSummary[criteria.key];
    criteriaHasRegression = criteria.isRegression(targetValue, referenceValue);
    outputBuffer.write('${criteria.title}: Target: ');
    if (criteria.isWorse(targetValue, referenceValue)) {
      outputBuffer.write(buildErrorMessage(targetValue.toStringAsFixed(2)));
    } else {
      outputBuffer.write(targetValue.toStringAsFixed(2));
    }
    outputBuffer.writeln(' Reference: ${referenceValue.toStringAsFixed(2)}');
    testHasRegression = testHasRegression || criteriaHasRegression;
  }

  outputBuffer.write('Performance tests found ');
  if (testHasRegression) {
    outputBuffer.writeln(buildErrorMessage('regression'));
  } else {
    outputBuffer.writeln(buildSuccessMessage('no regression'));
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
