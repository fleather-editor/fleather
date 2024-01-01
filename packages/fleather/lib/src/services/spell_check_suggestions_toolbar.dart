// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../widgets/editor.dart';

// The default height of the SpellCheckSuggestionsToolbar, which
// assumes there are the maximum number of spell check suggestions available, 3.
// Size eyeballed on Pixel 4 emulator running Android API 31.
const double _kDefaultToolbarHeight = 193.0;

/// The maximum number of suggestions in the toolbar is 3, plus a delete button.
const int _kMaxSuggestions = 3;

/// The default spell check suggestions toolbar for Android.
///
/// Tries to position itself below the [anchor], but if it doesn't fit, then it
/// readjusts to fit above bottom view insets.
class FleatherSpellCheckSuggestionsToolbar extends StatelessWidget {
  /// Constructs a [FleatherSpellCheckSuggestionsToolbar] with the default children for
  /// an [EditorState].
  ///
  FleatherSpellCheckSuggestionsToolbar.editor({
    super.key,
    required EditorState editorState,
  })  : buttonItems =
            buildButtonItems(editorState) ?? <ContextMenuButtonItem>[],
        anchor = getToolbarAnchor(editorState.contextMenuAnchors);

  /// The focal point below which the toolbar attempts to position itself.
  final Offset anchor;

  /// The [ContextMenuButtonItem]s that will be turned into the correct button
  /// widgets and displayed in the spell check suggestions toolbar.
  ///
  /// Must not contain more than four items, typically three suggestions and a
  /// delete button.
  ///
  /// See also:
  ///
  ///  * [AdaptiveTextSelectionToolbar.buttonItems], the list of
  ///    [ContextMenuButtonItem]s that are used to build the buttons of the
  ///    text selection toolbar.
  ///  * [FleatherCupertinoSpellCheckSuggestionsToolbar.buttonItems], the list of
  ///    [ContextMenuButtonItem]s used to build the Cupertino style spell check
  ///    suggestions toolbar.
  final List<ContextMenuButtonItem> buttonItems;

  /// Builds the button items for the toolbar based on the available
  /// spell check suggestions.
  static List<ContextMenuButtonItem>? buildButtonItems(
    EditorState editorState,
  ) {
    // Determine if composing region is misspelled.
    final SuggestionSpan? spanAtCursorIndex =
        editorState.findSuggestionSpanAtCursorIndex(
      editorState.textEditingValue.selection.baseOffset,
    );

    if (spanAtCursorIndex == null) {
      return null;
    }

    final List<ContextMenuButtonItem> buttonItems = <ContextMenuButtonItem>[];

    // Build suggestion buttons.
    for (final String suggestion
        in spanAtCursorIndex.suggestions.take(_kMaxSuggestions)) {
      buttonItems.add(ContextMenuButtonItem(
        onPressed: () {
          if (!editorState.mounted) {
            return;
          }
          _replaceText(
            editorState,
            suggestion,
            spanAtCursorIndex.range,
          );
        },
        label: suggestion,
      ));
    }

    // Build delete button.
    final ContextMenuButtonItem deleteButton = ContextMenuButtonItem(
      onPressed: () {
        if (!editorState.mounted) {
          return;
        }
        _replaceText(
          editorState,
          '',
          editorState.textEditingValue.composing,
        );
      },
      type: ContextMenuButtonType.delete,
    );
    buttonItems.add(deleteButton);

    return buttonItems;
  }

  static void _replaceText(
      EditorState editorState, String text, TextRange replacementRange) {
    // Replacement cannot be performed if the text is read only or obscured.
    assert(!editorState.widget.readOnly);

    final TextEditingValue newValue = editorState.textEditingValue.replaced(
      replacementRange,
      text,
    );
    editorState.userUpdateTextEditingValue(
        newValue, SelectionChangedCause.toolbar);

    // Schedule a call to bringIntoView() after renderEditable updates.
    SchedulerBinding.instance.addPostFrameCallback((Duration duration) {
      if (editorState.mounted) {
        editorState
            .bringIntoView(editorState.textEditingValue.selection.extent);
      }
    });
    editorState.hideToolbar();
  }

  /// Determines the Offset that the toolbar will be anchored to.
  static Offset getToolbarAnchor(TextSelectionToolbarAnchors anchors) {
    // Since this will be positioned below the anchor point, use the secondary
    // anchor by default.
    return anchors.secondaryAnchor == null
        ? anchors.primaryAnchor
        : anchors.secondaryAnchor!;
  }

  /// Builds the toolbar buttons based on the [buttonItems].
  List<Widget> _buildToolbarButtons(BuildContext context) {
    return buttonItems.map((ContextMenuButtonItem buttonItem) {
      final TextSelectionToolbarTextButton button =
          TextSelectionToolbarTextButton(
        padding: const EdgeInsets.fromLTRB(20, 0, 0, 0),
        onPressed: buttonItem.onPressed,
        alignment: Alignment.centerLeft,
        child: Text(
          AdaptiveTextSelectionToolbar.getButtonLabel(context, buttonItem),
          style: buttonItem.type == ContextMenuButtonType.delete
              ? const TextStyle(color: Colors.blue)
              : null,
        ),
      );

      if (buttonItem.type != ContextMenuButtonType.delete) {
        return button;
      }
      return DecoratedBox(
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey))),
        child: button,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (buttonItems.isEmpty) {
      return const SizedBox.shrink();
    }

    // Adjust toolbar height if needed.
    final double spellCheckSuggestionsToolbarHeight =
        _kDefaultToolbarHeight - (48.0 * (4 - buttonItems.length));
    // Incorporate the padding distance between the content and toolbar.
    final MediaQueryData mediaQueryData = MediaQuery.of(context);
    final double softKeyboardViewInsetsBottom =
        mediaQueryData.viewInsets.bottom;
    final double paddingAbove = mediaQueryData.padding.top +
        CupertinoTextSelectionToolbar.kToolbarScreenPadding;
    // Makes up for the Padding.
    final Offset localAdjustment = Offset(
      CupertinoTextSelectionToolbar.kToolbarScreenPadding,
      paddingAbove,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        CupertinoTextSelectionToolbar.kToolbarScreenPadding,
        paddingAbove,
        CupertinoTextSelectionToolbar.kToolbarScreenPadding,
        CupertinoTextSelectionToolbar.kToolbarScreenPadding +
            softKeyboardViewInsetsBottom,
      ),
      child: CustomSingleChildLayout(
        delegate: SpellCheckSuggestionsToolbarLayoutDelegate(
          anchor: anchor - localAdjustment,
        ),
        child: AnimatedSize(
          // This duration was eyeballed on a Pixel 2 emulator running Android
          // API 28 for the Material TextSelectionToolbar.
          duration: const Duration(milliseconds: 140),
          child: _SpellCheckSuggestionsToolbarContainer(
            height: spellCheckSuggestionsToolbarHeight,
            children: <Widget>[..._buildToolbarButtons(context)],
          ),
        ),
      ),
    );
  }
}

/// The Material-styled toolbar outline for the spell check suggestions
/// toolbar.
class _SpellCheckSuggestionsToolbarContainer extends StatelessWidget {
  const _SpellCheckSuggestionsToolbarContainer({
    required this.height,
    required this.children,
  });

  final double height;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      // This elevation was eyeballed on a Pixel 4 emulator running Android
      // API 31 for the SpellCheckSuggestionsToolbar.
      elevation: 2.0,
      type: MaterialType.card,
      child: SizedBox(
        // This width was eyeballed on a Pixel 4 emulator running Android
        // API 31 for the SpellCheckSuggestionsToolbar.
        width: 165.0,
        height: height,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// The default spell check suggestions toolbar for iOS.
///
/// Tries to position itself below the [anchors], but if it doesn't fit, then it
/// readjusts to fit above bottom view insets.
///
/// See also:
///  * [FleatherSpellCheckSuggestionsToolbar], which is similar but for both the
///    Material and Cupertino libraries.
class FleatherCupertinoSpellCheckSuggestionsToolbar extends StatelessWidget {
  /// Constructs a [FleatherCupertinoSpellCheckSuggestionsToolbar] with the default
  /// children for an [EditorState].
  FleatherCupertinoSpellCheckSuggestionsToolbar.editor({
    super.key,
    required EditorState editorState,
  })  : buttonItems =
            buildButtonItems(editorState) ?? <ContextMenuButtonItem>[],
        anchors = editorState.contextMenuAnchors;

  /// The location on which to anchor the menu.
  final TextSelectionToolbarAnchors anchors;

  /// The [ContextMenuButtonItem]s that will be turned into the correct button
  /// widgets and displayed in the spell check suggestions toolbar.
  ///
  /// Must not contain more than three items.
  ///
  /// See also:
  ///
  ///  * [AdaptiveTextSelectionToolbar.buttonItems], the list of
  ///    [ContextMenuButtonItem]s that are used to build the buttons of the
  ///    text selection toolbar.
  ///  * [FleatherSpellCheckSuggestionsToolbar.buttonItems], the list of
  ///    [ContextMenuButtonItem]s used to build the Material style spell check
  ///    suggestions toolbar.
  final List<ContextMenuButtonItem> buttonItems;

  /// Builds the button items for the toolbar based on the available
  /// spell check suggestions.
  static List<ContextMenuButtonItem>? buildButtonItems(
    EditorState editorState,
  ) {
    // Determine if composing region is misspelled.
    final SuggestionSpan? spanAtCursorIndex =
        editorState.findSuggestionSpanAtCursorIndex(
      editorState.textEditingValue.selection.baseOffset,
    );

    if (spanAtCursorIndex == null) {
      return null;
    }
    if (spanAtCursorIndex.suggestions.isEmpty) {
      assert(debugCheckHasCupertinoLocalizations(editorState.context));
      final CupertinoLocalizations localizations =
          CupertinoLocalizations.of(editorState.context);
      return <ContextMenuButtonItem>[
        ContextMenuButtonItem(
          onPressed: null,
          label: localizations.noSpellCheckReplacementsLabel,
        )
      ];
    }

    final List<ContextMenuButtonItem> buttonItems = <ContextMenuButtonItem>[];

    // Build suggestion buttons.
    for (final String suggestion
        in spanAtCursorIndex.suggestions.take(_kMaxSuggestions)) {
      buttonItems.add(ContextMenuButtonItem(
        onPressed: () {
          if (!editorState.mounted) {
            return;
          }
          _replaceText(
            editorState,
            suggestion,
            spanAtCursorIndex.range,
          );
        },
        label: suggestion,
      ));
    }
    return buttonItems;
  }

  static void _replaceText(
      EditorState editorState, String text, TextRange replacementRange) {
    // Replacement cannot be performed if the text is read only or obscured.
    assert(!editorState.widget.readOnly);

    final TextEditingValue newValue = editorState.textEditingValue
        .replaced(
          replacementRange,
          text,
        )
        .copyWith(
          selection: TextSelection.collapsed(
            offset: replacementRange.start + text.length,
          ),
        );
    editorState.userUpdateTextEditingValue(
        newValue, SelectionChangedCause.toolbar);

    // Schedule a call to bringIntoView() after renderEditable updates.
    SchedulerBinding.instance.addPostFrameCallback((Duration duration) {
      if (editorState.mounted) {
        editorState
            .bringIntoView(editorState.textEditingValue.selection.extent);
      }
    });
    editorState.hideToolbar();
  }

  /// Builds the toolbar buttons based on the [buttonItems].
  List<Widget> _buildToolbarButtons(BuildContext context) {
    return buttonItems.map((ContextMenuButtonItem buttonItem) {
      return CupertinoTextSelectionToolbarButton.buttonItem(
        buttonItem: buttonItem,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (buttonItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<Widget> children = _buildToolbarButtons(context);
    return CupertinoTextSelectionToolbar(
      anchorAbove: anchors.primaryAnchor,
      anchorBelow: anchors.secondaryAnchor == null
          ? anchors.primaryAnchor
          : anchors.secondaryAnchor!,
      children: children,
    );
  }
}
