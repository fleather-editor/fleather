import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'fleather_localizations_en.g.dart';
import 'fleather_localizations_fa.g.dart';
import 'fleather_localizations_fr.g.dart';

/// Callers can lookup localized strings with an instance of FleatherLocalizations
/// returned by `FleatherLocalizations.of(context)`.
///
/// Applications need to include `FleatherLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/fleather_localizations.g.dart';
///
/// return MaterialApp(
///   localizationsDelegates: FleatherLocalizations.localizationsDelegates,
///   supportedLocales: FleatherLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the FleatherLocalizations.supportedLocales
/// property.
abstract class FleatherLocalizations {
  FleatherLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static FleatherLocalizations? of(BuildContext context) {
    return Localizations.of<FleatherLocalizations>(
        context, FleatherLocalizations);
  }

  static const LocalizationsDelegate<FleatherLocalizations> delegate =
      _FleatherLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fa'),
    Locale('fr')
  ];

  /// Automatically assign a foreground color to the text
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get foregroundColorAutomatic;

  /// Assign no background color to the text
  ///
  /// In en, this message translates to:
  /// **'No color'**
  String get backgroundColorNoColor;

  /// A normal heading text style
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get headingNormal;

  /// A level 1 heading text style
  ///
  /// In en, this message translates to:
  /// **'Heading 1'**
  String get headingLevel1;

  /// A level 2 heading text style
  ///
  /// In en, this message translates to:
  /// **'Heading 2'**
  String get headingLevel2;

  /// A level 3 heading text style
  ///
  /// In en, this message translates to:
  /// **'Heading 3'**
  String get headingLevel3;

  /// A level 4 heading text style
  ///
  /// In en, this message translates to:
  /// **'Heading 4'**
  String get headingLevel4;

  /// A level 5 heading text style
  ///
  /// In en, this message translates to:
  /// **'Heading 5'**
  String get headingLevel5;

  /// A level 6 heading text style
  ///
  /// In en, this message translates to:
  /// **'Heading 6'**
  String get headingLevel6;

  /// Label for the input decoration of the link text field in the add link dialog
  ///
  /// In en, this message translates to:
  /// **'Paste a link'**
  String get addLinkDialogPasteLink;

  /// Label for the confirmation button in the link dialog
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get addLinkDialogApply;

  /// Open the link
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get linkDialogOpen;

  /// Copy the link
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get linkDialogCopy;

  /// Remove the link
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get linkDialogRemove;
}

class _FleatherLocalizationsDelegate
    extends LocalizationsDelegate<FleatherLocalizations> {
  const _FleatherLocalizationsDelegate();

  @override
  Future<FleatherLocalizations> load(Locale locale) {
    return SynchronousFuture<FleatherLocalizations>(
        lookupFleatherLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fa', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_FleatherLocalizationsDelegate old) => false;
}

FleatherLocalizations lookupFleatherLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return FleatherLocalizationsEn();
    case 'fa':
      return FleatherLocalizationsFa();
    case 'fr':
      return FleatherLocalizationsFr();
  }

  throw FlutterError(
      'FleatherLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
