import 'package:fleather/l10n/fleather_localizations_en.g.dart';
import 'package:flutter/widgets.dart';

import 'fleather_localizations.g.dart';

extension BuildContextLocalizationsExtension on BuildContext {
  FleatherLocalizations get l =>
      FleatherLocalizations.of(this) ?? FleatherLocalizationsEn();
}
