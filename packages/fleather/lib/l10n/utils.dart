import 'package:flutter/widgets.dart';

import 'fleather_localizations.g.dart';
import 'fleather_localizations_en.g.dart';

extension BuildContextLocalizationsExtension on BuildContext {
  FleatherLocalizations get l =>
      FleatherLocalizations.of(this) ?? FleatherLocalizationsEn();
}
