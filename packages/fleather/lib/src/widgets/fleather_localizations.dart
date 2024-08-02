import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';

/// Provides localizations to descendant widgets.
///
/// Descendant widgets obtain the current theme's [FleatherLocalizations]
/// object using [FleatherLocalizations.of].
///
/// See also:
///   - [FleatherLocalizationsData], which contains actual localizations.

class FleatherLocalizations extends InheritedWidget {
  /// Localizations.
  final FleatherLocalizationsData data;

  const FleatherLocalizations({
    super.key,
    required this.data,
    required super.child,
  });

  @override
  bool updateShouldNotify(FleatherLocalizations oldWidget) {
    return data != oldWidget.data;
  }

  /// The data from the closest [FleatherLocalizationsData] instance
  /// that encloses the given [context].
  static FleatherLocalizationsData of(BuildContext context) {
    final FleatherLocalizations? widget =
        context.dependOnInheritedWidgetOfExactType<FleatherLocalizations>();

    assert(
      widget != null,
      '${FleatherLocalizations.of} called with a context that does not contain a $FleatherLocalizations.',
    );

    return widget!.data;
  }
}

/// Localizations data.
class FleatherLocalizationsData {
  /// Headings labels in the toolbar.
  final HeadingsLocalizations headingsLocalizations;

  /// Label of the text field to enter a link in the link dialog.
  final String linkDialogPasteALink;

  /// Button label to apply the link entered in the link dialog.
  final String linkDialogApply;

  FleatherLocalizationsData({
    required this.headingsLocalizations,
    required this.linkDialogPasteALink,
    required this.linkDialogApply,
  });

  /// Default localizations.
  factory FleatherLocalizationsData.fallback() {
    return FleatherLocalizationsData(
      headingsLocalizations: HeadingsLocalizations.fallback(),
      linkDialogPasteALink: 'Paste a link',
      linkDialogApply: 'Apply',
    );
  }

  FleatherLocalizationsData copyWith({
    HeadingsLocalizations? headingsLocalizations,
    String? linkDialogPasteALink,
    String? linkDialogApply,
  }) {
    return FleatherLocalizationsData(
      headingsLocalizations:
          headingsLocalizations ?? this.headingsLocalizations,
      linkDialogPasteALink: linkDialogPasteALink ?? this.linkDialogPasteALink,
      linkDialogApply: linkDialogApply ?? this.linkDialogApply,
    );
  }

  FleatherLocalizationsData merge(FleatherLocalizationsData other) {
    return copyWith(
      headingsLocalizations: other.headingsLocalizations,
      linkDialogPasteALink: other.linkDialogPasteALink,
      linkDialogApply: other.linkDialogApply,
    );
  }
}

/// Localizations for the headings formatters in the toolbar.
class HeadingsLocalizations {
  /// Normal heading.
  final String headingNormal;

  /// Level 1 heading.
  final String headingLevel1;

  /// Level 2 heading.
  final String headingLevel2;

  /// Level 3 heading.
  final String headingLevel3;

  /// Level 4 heading.
  final String headingLevel4;

  /// Level 5 heading.
  final String headingLevel5;

  /// Level 6 heading.
  final String headingLevel6;

  HeadingsLocalizations({
    required this.headingNormal,
    required this.headingLevel1,
    required this.headingLevel2,
    required this.headingLevel3,
    required this.headingLevel4,
    required this.headingLevel5,
    required this.headingLevel6,
  });

  /// Default localizations.
  factory HeadingsLocalizations.fallback() {
    return HeadingsLocalizations(
      headingNormal: 'Normal',
      headingLevel1: 'Heading 1',
      headingLevel2: 'Heading 2',
      headingLevel3: 'Heading 3',
      headingLevel4: 'Heading 4',
      headingLevel5: 'Heading 5',
      headingLevel6: 'Heading 6',
    );
  }

  /// Returns every heading localization mapped to its [ParchmentAttribute].
  Map<ParchmentAttribute<int>, String> get headingsToText {
    return {
      ParchmentAttribute.heading.unset: headingNormal,
      ParchmentAttribute.heading.level1: headingLevel1,
      ParchmentAttribute.heading.level2: headingLevel2,
      ParchmentAttribute.heading.level3: headingLevel3,
      ParchmentAttribute.heading.level4: headingLevel4,
      ParchmentAttribute.heading.level5: headingLevel5,
      ParchmentAttribute.heading.level6: headingLevel6,
    };
  }
}
