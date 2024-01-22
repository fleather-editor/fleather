import 'package:test/test.dart';

const isAssertionError = TypeMatcher<AssertionError>();

// ignore: deprecated_member_use
const Matcher throwsAssertionError = Throws(isAssertionError);
