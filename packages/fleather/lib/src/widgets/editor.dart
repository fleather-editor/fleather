import 'dart:math' as math;
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:parchment/parchment.dart';

import '../../util.dart';
import '../rendering/editor.dart';
import '../services/clipboard_manager.dart';
import '../services/spell_check_suggestions_toolbar.dart';
import 'controller.dart';
import 'cursor.dart';
import 'editable_text_block.dart';
import 'editable_text_line.dart';
import 'editor_input_client_mixin.dart';
import 'editor_selection_delegate_mixin.dart';
import 'history.dart';
import 'keyboard_listener.dart';
import 'link.dart';
import 'shortcuts.dart';
import 'text_line.dart';
import 'text_selection.dart';
import 'theme.dart';

class _WebClipboardStatusNotifier extends ClipboardStatusNotifier {
  @override
  ClipboardStatus value = ClipboardStatus.pasteable;

  @override
  Future<void> update() => Future<void>.value();
}

/// Widget builder function for context menu in [FleatherEditor].
typedef FleatherContextMenuBuilder = Widget Function(
  BuildContext context,
  EditorState editableTextState,
);

/// Default implementation of a widget builder function for context menu.
Widget defaultContextMenuBuilder(
        BuildContext context, EditorState editorState) =>
    AdaptiveTextSelectionToolbar.buttonItems(
      buttonItems: editorState.contextMenuButtonItems,
      anchors: editorState.contextMenuAnchors,
    );

Widget defaultSpellCheckMenuBuilder(
    BuildContext context, EditorState editorState) {
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return FleatherCupertinoSpellCheckSuggestionsToolbar.editor(
          editorState: editorState);
    case TargetPlatform.android:
      return FleatherSpellCheckSuggestionsToolbar.editor(
          editorState: editorState);
    case TargetPlatform.macOS:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
    case TargetPlatform.fuchsia:
    default:
      throw UnsupportedError('Only iOS and Android support spell check');
  }
}

/// Builder function for embeddable objects in [FleatherEditor].
typedef FleatherEmbedBuilder = Widget Function(
    BuildContext context, EmbedNode node);

/// Default implementation of a builder function for embeddable objects in
/// Fleather.
///
/// Only supports "horizontal rule" embeds.
Widget defaultFleatherEmbedBuilder(BuildContext context, EmbedNode node) {
  if (node.value.type == 'hr') {
    final fleatherThemeData = FleatherTheme.of(context)!;

    return Divider(
      height: fleatherThemeData.horizontalRule.height,
      thickness: fleatherThemeData.horizontalRule.thickness,
      color: fleatherThemeData.horizontalRule.color,
    );
  }
  throw UnimplementedError(
      'Embeddable type "${node.value.type}" is not supported by default embed '
      'builder of FleatherEditor. You must pass your own builder function to '
      'embedBuilder property of FleatherEditor or FleatherField widgets.');
}

/// Widget for editing rich text documents.
class FleatherEditor extends StatefulWidget {
  /// Controller object which establishes a link between a rich text document
  /// and this editor.
  ///
  /// Must not be null.
  final FleatherController controller;

  /// Controls whether this editor has keyboard focus.
  ///
  /// Can be `null` in which case this editor creates its own instance to
  /// control keyboard focus.
  final FocusNode? focusNode;

  /// The [ScrollController] to use when vertically scrolling the contents.
  ///
  /// If `null` and [scrollable] is `true` then this editor instantiates a
  /// new ScrollController
  final ScrollController? scrollController;

  /// Whether this editor should create a scrollable container for its content.
  ///
  /// When set to `true` the editor's height can be controlled by [minHeight],
  /// [maxHeight] and [expands] properties.
  ///
  /// When set to `false` the editor always expands to fit the entire content
  /// of the document and should normally be placed as a child of another
  /// scrollable widget, otherwise the content may be clipped.
  ///
  /// Set to `true` by default.
  final bool scrollable;

  /// Additional space around the content of this editor.
  final EdgeInsetsGeometry padding;

  /// Whether this editor should focus itself if nothing else is already
  /// focused.
  ///
  /// If true, the keyboard will open as soon as this editor obtains focus.
  /// Otherwise, the keyboard is only shown after the user taps the editor.
  ///
  /// Defaults to `false`. Cannot be `null`.
  final bool autofocus;

  /// Whether to show cursor.
  ///
  /// The cursor refers to the blinking caret when the editor is focused.
  final bool showCursor;

  /// Whether the text can be changed.
  ///
  /// When this is set to `true`, the text cannot be modified
  /// by any shortcut or keyboard operation. The text is still selectable.
  ///
  /// Defaults to `false`. Must not be `null`.
  final bool readOnly;

  /// Whether to enable autocorrection.
  ///
  /// Defaults to `true`.
  final bool autocorrect;

  /// Whether to show input suggestions as the user types.
  ///
  /// This flag only affects Android. On iOS, suggestions are tied directly to
  /// [autocorrect], so that suggestions are only shown when [autocorrect] is
  /// true. On Android autocorrection and suggestion are controlled separately.
  ///
  /// Defaults to true.
  final bool enableSuggestions;

  /// Whether to enable user interface affordances for changing the
  /// text selection.
  ///
  /// For example, setting this to true will enable features such as
  /// long-pressing the editor to select text and show the
  /// cut/copy/paste menu, and tapping to move the text cursor.
  ///
  /// When this is false, the text selection cannot be adjusted by
  /// the user, text cannot be copied, and the user cannot paste into
  /// the text field from the clipboard.
  final bool enableInteractiveSelection;

  /// The minimum height to be occupied by this editor.
  ///
  /// This only has effect if [scrollable] is set to `true` and [expands] is
  /// set to `false`.
  final double? minHeight;

  /// The maximum height to be occupied by this editor.
  ///
  /// This only has effect if [scrollable] is set to `true` and [expands] is
  /// set to `false`.
  final double? maxHeight;

  /// The maximum width to be occupied by the content of this editor.
  ///
  /// If this is not null and and this editor's width is larger than this value
  /// then the contents will be constrained to the provided maximum width and
  /// horizontally centered. This is mostly useful on devices with wide screens.
  final double? maxContentWidth;

  /// Whether this editor's height will be sized to fill its parent.
  ///
  /// This only has effect if [scrollable] is set to `true`.
  ///
  /// If expands is set to true and wrapped in a parent widget like [Expanded]
  /// or [SizedBox], the editor will expand to fill the parent.
  ///
  /// [maxHeight] and [minHeight] must both be `null` when this is set to
  /// `true`.
  ///
  /// Defaults to `false`.
  final bool expands;

  /// Configures how the platform keyboard will select an uppercase or
  /// lowercase keyboard.
  ///
  /// Only supports text keyboards, other keyboard types will ignore this
  /// configuration. Capitalization is locale-aware.
  ///
  /// Defaults to [TextCapitalization.sentences]. Must not be `null`.
  final TextCapitalization textCapitalization;

  /// The appearance of the keyboard.
  ///
  /// This setting is only honored on iOS devices.
  ///
  /// Defaults to [ThemeData.brightness].
  final Brightness? keyboardAppearance;

  /// The [ScrollPhysics] to use when vertically scrolling the input.
  ///
  /// This only has effect if [scrollable] is set to `true`.
  ///
  /// If not specified, it will behave according to the current platform.
  ///
  /// See [Scrollable.physics].
  final ScrollPhysics? scrollPhysics;

  /// Callback to invoke when user wants to launch a URL.
  final ValueChanged<String?>? onLaunchUrl;

  /// Builder function for embeddable objects.
  ///
  /// Defaults to [defaultFleatherEmbedBuilder].
  final FleatherEmbedBuilder embedBuilder;

  /// Configuration that details how spell check should be performed.
  ///
  /// Specifies the [SpellCheckService] used to spell check text input and the
  /// [TextStyle] used to style text with misspelled words.
  ///
  /// If the [SpellCheckService] is left null, spell check is disabled by
  /// default unless the [DefaultSpellCheckService] is supported, in which case
  /// it is used. It is currently supported only on Android and iOS.
  ///
  /// If this configuration is left null, then spell check is disabled by default.
  final SpellCheckConfiguration? spellCheckConfiguration;

  /// Builds the text selection toolbar when requested by the user.
  ///
  /// Defaults to [defaultContextMenuBuilder].
  final FleatherContextMenuBuilder contextMenuBuilder;

  /// Delegate function responsible for showing menu with link actions on
  /// mobile platforms (iOS, Android).
  ///
  /// The menu is triggered in editing mode ([readOnly] is set to `false`)
  /// when the user long-presses a link-styled text segment.
  ///
  /// Fleather provides default implementation which can be overridden by this
  /// field to customize the user experience.
  ///
  /// By default on iOS the menu is displayed with [showCupertinoModalPopup]
  /// which constructs an instance of [CupertinoActionSheet]. For Android,
  /// the menu is displayed with [showModalBottomSheet] and a list of
  /// Material [ListTile]s.
  final LinkActionPickerDelegate linkActionPickerDelegate;

  /// Provides clipboard status and getter and setter for clipboard data
  /// for paste, copy and cut functionality.
  ///
  /// Defaults to [PlainTextClipboardManager]
  final ClipboardManager clipboardManager;

  /// Provide a notifier that indicated whether current content of clipboard
  /// can be pasted
  ///
  /// Defaults to [ClipboardStatusNotifier] or [_WebClipboardStatusNotifier]
  final ClipboardStatusNotifier? clipboardStatus;

  final GlobalKey<EditorState>? editorKey;

  final TextSelectionControls? textSelectionControls;

  const FleatherEditor(
      {super.key,
      required this.controller,
      this.editorKey,
      this.focusNode,
      this.scrollController,
      this.scrollable = true,
      this.padding = EdgeInsets.zero,
      this.autofocus = false,
      this.showCursor = true,
      this.readOnly = false,
      this.autocorrect = true,
      this.enableSuggestions = true,
      this.enableInteractiveSelection = true,
      this.minHeight,
      this.maxHeight,
      this.maxContentWidth,
      this.expands = false,
      this.textCapitalization = TextCapitalization.sentences,
      this.keyboardAppearance,
      this.scrollPhysics,
      this.onLaunchUrl,
      this.spellCheckConfiguration,
      this.clipboardManager = const PlainTextClipboardManager(),
      this.clipboardStatus,
      this.contextMenuBuilder = defaultContextMenuBuilder,
      this.embedBuilder = defaultFleatherEmbedBuilder,
      this.linkActionPickerDelegate = defaultLinkActionPickerDelegate,
      this.textSelectionControls});

  @override
  State<FleatherEditor> createState() => _FleatherEditorState();
}

class _FleatherEditorState extends State<FleatherEditor>
    implements EditorTextSelectionGestureDetectorBuilderDelegate {
  GlobalKey<EditorState>? _editorKey;

  bool _showSelectionHandles = false;

  @override
  GlobalKey<EditorState> get editableTextKey => widget.editorKey ?? _editorKey!;

  @override
  bool get forcePressEnabled => true;

  @override
  bool get selectionEnabled => widget.enableInteractiveSelection;

  late EditorTextSelectionGestureDetectorBuilder
      _selectionGestureDetectorBuilder;

  void _requestKeyboard() => editableTextKey.currentState?.requestKeyboard();

  @override
  void didUpdateWidget(covariant FleatherEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editorKey != null && widget.editorKey == null) {
      _editorKey = GlobalKey<EditorState>();
    } else if (widget.editorKey != null) {
      _editorKey = null;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.editorKey == null) {
      _editorKey = GlobalKey<EditorState>();
    }
    _selectionGestureDetectorBuilder =
        _FleatherEditorSelectionGestureDetectorBuilder(state: this);
  }

  void _handleSelectionChanged(
      TextSelection selection, SelectionChangedCause? cause) {
    final bool willShowSelectionHandles = _shouldShowSelectionHandles(cause);
    if (willShowSelectionHandles != _showSelectionHandles) {
      setState(() {
        _showSelectionHandles = willShowSelectionHandles;
      });
    }
  }

  bool _shouldShowSelectionHandles(SelectionChangedCause? cause) {
    // When the editor is activated by something that doesn't trigger the
    // selection overlay, we shouldn't show the handles either.
    if (!_selectionGestureDetectorBuilder.shouldShowSelectionToolbar) {
      return false;
    }

    if (cause == SelectionChangedCause.keyboard) {
      return false;
    }

    if (widget.readOnly && widget.controller.selection.isCollapsed) {
      return false;
    }

    if (cause == SelectionChangedCause.longPress ||
        cause == SelectionChangedCause.scribble) {
      return true;
    }

    if (widget.controller.document.toPlainText().length > 2) {
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectionTheme = TextSelectionTheme.of(context);

    TextSelectionControls textSelectionControls;
    bool paintCursorAboveText;
    bool cursorOpacityAnimates;
    Offset? cursorOffset;
    Color cursorColor;
    Color selectionColor;
    Radius? cursorRadius;

    final keyboardAppearance = widget.keyboardAppearance ?? theme.brightness;

    switch (theme.platform) {
      case TargetPlatform.iOS:
        final cupertinoTheme = CupertinoTheme.of(context);
        textSelectionControls =
            widget.textSelectionControls ?? cupertinoTextSelectionControls;
        paintCursorAboveText = true;
        cursorOpacityAnimates = true;
        cursorColor = selectionTheme.cursorColor ?? cupertinoTheme.primaryColor;
        selectionColor = selectionTheme.selectionColor ??
            cupertinoTheme.primaryColor.withOpacity(0.40);
        cursorRadius = const Radius.circular(2.0);
        cursorOffset = Offset(
            iOSHorizontalOffset / MediaQuery.of(context).devicePixelRatio, 0);
        break;

      case TargetPlatform.macOS:
        final CupertinoThemeData cupertinoTheme = CupertinoTheme.of(context);
        textSelectionControls = widget.textSelectionControls ??
            cupertinoDesktopTextSelectionControls;
        paintCursorAboveText = true;
        cursorOpacityAnimates = false;
        cursorColor = selectionTheme.cursorColor ?? cupertinoTheme.primaryColor;
        selectionColor = selectionTheme.selectionColor ??
            cupertinoTheme.primaryColor.withOpacity(0.40);
        cursorRadius ??= const Radius.circular(2.0);
        cursorOffset = Offset(
            iOSHorizontalOffset / MediaQuery.of(context).devicePixelRatio, 0);
        break;

      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        textSelectionControls =
            widget.textSelectionControls ?? materialTextSelectionControls;
        paintCursorAboveText = false;
        cursorOpacityAnimates = false;
        cursorColor = selectionTheme.cursorColor ?? theme.colorScheme.primary;
        selectionColor = selectionTheme.selectionColor ??
            theme.colorScheme.primary.withOpacity(0.40);
        break;

      case TargetPlatform.linux:
      case TargetPlatform.windows:
        textSelectionControls =
            widget.textSelectionControls ?? desktopTextSelectionControls;
        paintCursorAboveText = false;
        cursorOpacityAnimates = false;
        cursorColor = selectionTheme.cursorColor ?? theme.colorScheme.primary;
        selectionColor = selectionTheme.selectionColor ??
            theme.colorScheme.primary.withOpacity(0.40);
        break;
    }

    Widget child = RawEditor(
      key: editableTextKey,
      controller: widget.controller,
      focusNode: widget.focusNode,
      scrollController: widget.scrollController,
      scrollable: widget.scrollable,
      padding: widget.padding,
      autofocus: widget.autofocus,
      autocorrect: widget.autocorrect,
      showCursor: widget.showCursor,
      readOnly: widget.readOnly,
      enableSuggestions: widget.enableSuggestions,
      enableInteractiveSelection: widget.enableInteractiveSelection,
      minHeight: widget.minHeight,
      maxHeight: widget.maxHeight,
      maxContentWidth: widget.maxContentWidth,
      expands: widget.expands,
      textCapitalization: widget.textCapitalization,
      keyboardAppearance: keyboardAppearance,
      scrollPhysics: widget.scrollPhysics,
      onLaunchUrl: widget.onLaunchUrl,
      embedBuilder: widget.embedBuilder,
      spellCheckConfiguration: widget.spellCheckConfiguration,
      linkActionPickerDelegate: widget.linkActionPickerDelegate,
      clipboardManager: widget.clipboardManager,
      clipboardStatus: widget.clipboardStatus ??
          (kIsWeb ? _WebClipboardStatusNotifier() : ClipboardStatusNotifier()),
      // encapsulated fields below
      cursorStyle: CursorStyle(
        color: cursorColor,
        backgroundColor: Colors.grey,
        width: 2.0,
        radius: cursorRadius,
        offset: cursorOffset,
        paintAboveText: paintCursorAboveText,
        opacityAnimates: cursorOpacityAnimates,
      ),
      selectionColor: selectionColor,
      showSelectionHandles: _showSelectionHandles,
      onSelectionChanged: _handleSelectionChanged,
      selectionControls: textSelectionControls,
    );

    child = FleatherShortcuts(
      child: FleatherActions(
        child: FleatherHistory(
          controller: widget.controller,
          child: child,
        ),
      ),
    );

    return widget.enableInteractiveSelection
        ? _selectionGestureDetectorBuilder.buildGestureDetector(
            behavior: HitTestBehavior.translucent, child: child)
        : child;
  }
}

class _FleatherEditorSelectionGestureDetectorBuilder
    extends EditorTextSelectionGestureDetectorBuilder {
  _FleatherEditorSelectionGestureDetectorBuilder({
    required _FleatherEditorState state,
  })  : _state = state,
        super(delegate: state);

  final _FleatherEditorState _state;

  @override
  void onForcePressStart(ForcePressDetails details) {
    super.onForcePressStart(details);
    if (delegate.selectionEnabled && shouldShowSelectionToolbar) {
      editor.showToolbar();
    }
  }

  @override
  void onSingleTapUp(TapDragUpDetails details) {
    super.onSingleTapUp(details);
    _state._requestKeyboard();
  }

  @override
  void onSingleLongTapStart(LongPressStartDetails details) {
    super.onSingleLongTapStart(details);
    if (delegate.selectionEnabled) {
      switch (Theme.of(_state.context).platform) {
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          break;
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          Feedback.forLongPress(_state.context);
          break;
      }
    }
  }
}

class RawEditor extends StatefulWidget {
  const RawEditor({
    super.key,
    required this.controller,
    this.focusNode,
    this.scrollController,
    this.scrollable = true,
    this.padding = EdgeInsets.zero,
    this.autofocus = false,
    bool? showCursor,
    this.readOnly = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.enableInteractiveSelection = true,
    this.minHeight,
    this.maxHeight,
    this.maxContentWidth,
    this.expands = false,
    this.textCapitalization = TextCapitalization.none,
    this.keyboardAppearance = Brightness.light,
    this.onLaunchUrl,
    required this.selectionColor,
    this.scrollPhysics,
    required this.cursorStyle,
    required this.clipboardManager,
    required this.clipboardStatus,
    this.showSelectionHandles = false,
    this.selectionControls,
    this.onSelectionChanged,
    this.contextMenuBuilder = defaultContextMenuBuilder,
    this.spellCheckConfiguration,
    this.embedBuilder = defaultFleatherEmbedBuilder,
    this.linkActionPickerDelegate = defaultLinkActionPickerDelegate,
  })  : assert(maxHeight == null || maxHeight > 0),
        assert(minHeight == null || minHeight >= 0),
        assert(
          (maxHeight == null) ||
              (minHeight == null) ||
              (maxHeight >= minHeight),
          'minHeight can\'t be greater than maxHeight',
        ),
        showCursor = showCursor ?? !readOnly;

  /// Controls the document being edited.
  final FleatherController controller;

  /// Controls whether this editor has keyboard focus.
  final FocusNode? focusNode;

  final ScrollController? scrollController;

  final bool scrollable;

  /// Additional space around the editor contents.
  final EdgeInsetsGeometry padding;

  /// Whether the text can be changed.
  ///
  /// When this is set to true, the text cannot be modified
  /// by any shortcut or keyboard operation. The text is still selectable.
  ///
  /// Defaults to false. Must not be null.
  final bool readOnly;

  /// Whether to enable autocorrection.
  ///
  /// Defaults to `true`.
  final bool autocorrect;

  /// Whether to show input suggestions as the user types.
  ///
  /// This flag only affects Android. On iOS, suggestions are tied directly to
  /// [autocorrect], so that suggestions are only shown when [autocorrect] is
  /// true. On Android autocorrection and suggestion are controlled separately.
  ///
  /// Defaults to true.
  final bool enableSuggestions;

  /// Callback which is triggered when the user wants to open a URL from
  /// a link in the document.
  final ValueChanged<String?>? onLaunchUrl;

  /// Builds the text selection toolbar when requested by the user.
  ///
  /// Defaults to [defaultContextMenuBuilder].
  final FleatherContextMenuBuilder contextMenuBuilder;

  /// Configuration that details how spell check should be performed.
  ///
  /// Specifies the [SpellCheckService] used to spell check text input and the
  /// [TextStyle] used to style text with misspelled words.
  ///
  /// If the [SpellCheckService] is left null, spell check is disabled by
  /// default unless the [DefaultSpellCheckService] is supported, in which case
  /// it is used. It is currently supported only on Android and iOS.
  ///
  /// If this configuration is left null, then spell check is disabled by default.
  final SpellCheckConfiguration? spellCheckConfiguration;

  /// Whether to show selection handles.
  ///
  /// When a selection is active, there will be two handles at each side of
  /// boundary, or one handle if the selection is collapsed. The handles can be
  /// dragged to adjust the selection.
  ///
  /// See also:
  ///
  ///  * [showCursor], which controls the visibility of the cursor..
  final bool showSelectionHandles;

  /// Called when the user changes the selection of text (including the cursor
  /// location).
  final SelectionChangedCallback? onSelectionChanged;

  /// Whether to show cursor.
  ///
  /// The cursor refers to the blinking caret when the editor is focused.
  ///
  /// See also:
  ///
  ///  * [cursorStyle], which controls the cursor visual representation.
  ///  * [showSelectionHandles], which controls the visibility of the selection
  ///    handles.
  final bool showCursor;

  /// The style to be used for the editing cursor.
  final CursorStyle cursorStyle;

  /// Configures how the platform keyboard will select an uppercase or
  /// lowercase keyboard.
  ///
  /// Only supports text keyboards, other keyboard types will ignore this
  /// configuration. Capitalization is locale-aware.
  ///
  /// Defaults to [TextCapitalization.none]. Must not be null.
  ///
  /// See also:
  ///
  ///  * [TextCapitalization], for a description of each capitalization behavior.
  final TextCapitalization textCapitalization;

  /// The maximum height this editor can have.
  ///
  /// If this is null then there is no limit to the editor's height and it will
  /// expand to fill its parent.
  final double? maxHeight;

  /// The minimum height this editor can have.
  final double? minHeight;

  /// The maximum width to be occupied by the content of this editor.
  ///
  /// If this is not null and and this editor's width is larger than this value
  /// then the contents will be constrained to the provided maximum width and
  /// horizontally centered. This is mostly useful on devices with wide screens.
  final double? maxContentWidth;

  /// Whether this widget's height will be sized to fill its parent.
  ///
  /// If set to true and wrapped in a parent widget like [Expanded] or
  ///
  /// Defaults to false.
  final bool expands;

  /// Whether this editor should focus itself if nothing else is already
  /// focused.
  ///
  /// If true, the keyboard will open as soon as this text field obtains focus.
  /// Otherwise, the keyboard is only shown after the user taps the text field.
  ///
  /// Defaults to false. Cannot be null.
  final bool autofocus;

  /// The color to use when painting the selection.
  final Color selectionColor;

  /// Optional delegate for building the text selection handles and toolbar.
  ///
  /// The [RawEditor] widget used on its own will not trigger the display
  /// of the selection toolbar by itself. The toolbar is shown by calling
  /// [RawEditorState.showToolbar] in response to an appropriate user event.
  final TextSelectionControls? selectionControls;

  /// The appearance of the keyboard.
  ///
  /// This setting is only honored on iOS devices.
  ///
  /// Defaults to [Brightness.light].
  final Brightness keyboardAppearance;

  /// If true, then long-pressing this TextField will select text and show the
  /// cut/copy/paste menu, and tapping will move the text caret.
  ///
  /// True by default.
  ///
  /// If false, most of the accessibility support for selecting text, copy
  /// and paste, and moving the caret will be disabled.
  final bool enableInteractiveSelection;

  /// The [ScrollPhysics] to use when vertically scrolling the input.
  ///
  /// If not specified, it will behave according to the current platform.
  ///
  /// See [Scrollable.physics].
  final ScrollPhysics? scrollPhysics;

  /// Builder function for embeddable objects.
  ///
  /// Defaults to [defaultFleatherEmbedBuilder].
  final FleatherEmbedBuilder embedBuilder;

  final LinkActionPickerDelegate linkActionPickerDelegate;

  final ClipboardManager clipboardManager;

  final ClipboardStatusNotifier clipboardStatus;

  bool get selectionEnabled => enableInteractiveSelection;

  @override
  State<RawEditor> createState() {
    return RawEditorState();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
        .add(DiagnosticsProperty<FleatherController>('controller', controller));
    properties.add(DiagnosticsProperty<FocusNode>('focusNode', focusNode));
    properties.add(DoubleProperty('maxLines', maxHeight, defaultValue: null));
    properties.add(DoubleProperty('minLines', minHeight, defaultValue: null));
    properties.add(
        DiagnosticsProperty<bool>('autofocus', autofocus, defaultValue: false));
    properties.add(DiagnosticsProperty<ScrollPhysics>(
        'scrollPhysics', scrollPhysics,
        defaultValue: null));
  }
}

/// Base interface for the editor state which defines contract used by
/// various mixins.
///
/// Following mixins rely on this interface:
///
///   * [RawEditorStateKeyboardMixin],
///   * [RawEditorStateTextInputClientMixin]
///   * [RawEditorStateSelectionDelegateMixin]
///
abstract class EditorState extends State<RawEditor>
    implements TextSelectionDelegate {
  @override
  bool lookUpEnabled = false;

  @override
  bool shareEnabled = false;

  @override
  bool searchWebEnabled = false;

  ClipboardStatusNotifier get clipboardStatus;

  ScrollController get scrollController;

  RenderEditor get renderEditor;

  EditorTextSelectionOverlay? get selectionOverlay;

  FleatherThemeData get themeData;

  /// Controls the floating cursor animation when it is released.
  /// The floating cursor is animated to merge with the regular cursor.
  AnimationController get floatingCursorResetController;

  /// Whether or not spell check is enabled.
  ///
  /// Spell check is enabled when a [SpellCheckConfiguration] has been specified
  /// for the widget.
  bool get spellCheckEnabled;

  FocusNode get effectiveFocusNode;

  TextSelectionToolbarAnchors get contextMenuAnchors;

  List<ContextMenuButtonItem> get contextMenuButtonItems;

  /// Shows toolbar
  ///
  /// if [createIfNull] is `true`, create the [EditorTextSelectionOverlay]
  /// if the latter is null
  bool showToolbar({createIfNull = false});

  /// Shows toolbar with spell check suggestions of misspelled words that are
  /// available for click-and-replace.
  bool showSpellCheckSuggestionsToolbar();

  /// Finds specified [SuggestionSpan] that matches the provided index using
  /// binary search.
  ///
  /// See also:
  ///
  ///  * [SpellCheckSuggestionsToolbar], the Material style spell check
  ///    suggestions toolbar that uses this method to render the correct
  ///    suggestions in the toolbar for a misspelled word.
  SuggestionSpan? findSuggestionSpanAtCursorIndex(int cursorIndex);

  Future<void> performSpellCheck(final String text);

  void toggleToolbar([bool hideHandles = true]);

  /// Shows the magnifier at the position given by `positionToShow`,
  /// if there is no magnifier visible.
  ///
  /// Updates the magnifier to the position given by `positionToShow`,
  /// if there is a magnifier visible.
  ///
  /// Does nothing if a magnifier couldn't be shown, such as when the selection
  /// overlay does not currently exist.
  void showMagnifier(Offset positionToShow);

  /// Hides the magnifier if it is visible.
  void hideMagnifier();

  void requestKeyboard();
}

// TODO: apply styling and color to spelling suggestion
class RawEditorState extends EditorState
    with
        AutomaticKeepAliveClientMixin<RawEditor>,
        WidgetsBindingObserver,
        TickerProviderStateMixin<RawEditor>,
        RawEditorStateTextInputClientMixin,
        RawEditorStateSelectionDelegateMixin
    implements TextSelectionDelegate {
  final GlobalKey _editorKey = GlobalKey();
  final GlobalKey _scrollableKey = GlobalKey();

  // Theme
  late FleatherThemeData _themeData;

  @override
  FleatherThemeData get themeData => _themeData;

  // Cursors
  late CursorController _cursorController;

  FleatherController get controller => widget.controller;

  // Selection overlay
  @override
  EditorTextSelectionOverlay? get selectionOverlay => _selectionOverlay;
  EditorTextSelectionOverlay? _selectionOverlay;

  @override
  ScrollController get scrollController => _scrollController;
  late ScrollController _scrollController;

  @override
  AnimationController get floatingCursorResetController =>
      _floatingCursorResetController;
  late AnimationController _floatingCursorResetController;

  @override
  ClipboardStatusNotifier get clipboardStatus => widget.clipboardStatus;

  final LayerLink _toolbarLayerLink = LayerLink();
  final LayerLink _startHandleLayerLink = LayerLink();
  final LayerLink _endHandleLayerLink = LayerLink();

  bool _didAutoFocus = false;

  FocusNode? _internalFocusNode;

  @override
  FocusNode get effectiveFocusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  bool get _hasFocus => effectiveFocusNode.hasFocus;

  @override
  bool get wantKeepAlive => _hasFocus;

  TextDirection get _textDirection {
    final result = Directionality.maybeOf(context);
    assert(result != null,
        '$runtimeType created without a textDirection and with no ambient Directionality.');
    return result!;
  }

  /// The renderer for this widget's editor descendant.
  ///
  /// This property is typically used to notify the renderer of input gestures.
  @override
  RenderEditor get renderEditor =>
      _editorKey.currentContext!.findRenderObject() as RenderEditor;

  /// Express interest in interacting with the keyboard.
  ///
  /// If this control is already attached to the keyboard, this function will
  /// request that the keyboard become visible. Otherwise, this function will
  /// ask the focus system that it become focused. If successful in acquiring
  /// focus, the control will then attach to the keyboard and request that the
  /// keyboard become visible.
  @override
  void requestKeyboard() {
    if (_hasFocus) {
      openConnectionIfNeeded();
    } else {
      effectiveFocusNode.requestFocus();
    }
  }

  /// Shows the selection toolbar at the location of the current cursor.
  ///
  /// Returns `false` if a toolbar couldn't be shown, such as when the toolbar
  /// is already shown, or when no text selection currently exists.
  @override
  bool showToolbar({createIfNull = false}) {
    // Web is using native dom elements to enable clipboard functionality of the
    // toolbar: copy, paste, select, cut. It might also provide additional
    // functionality depending on the browser (such as translate). Due to this
    // we should not show a Flutter toolbar for the editable text elements.
    if (kIsWeb && BrowserContextMenu.enabled) {
      return false;
    }

    if (_selectionOverlay == null) {
      if (createIfNull) {
        _selectionOverlay = _createSelectionOverlay();
      } else {
        return false;
      }
    } else if (_selectionOverlay!.toolbarIsVisible) {
      return false;
    }

    clipboardStatus.update();
    _selectionOverlay!.showToolbar();
    return true;
  }

  @override
  void toggleToolbar([bool hideHandles = true]) {
    final selectionOverlay = _selectionOverlay ??= _createSelectionOverlay();

    if (selectionOverlay.toolbarIsVisible) {
      hideToolbar(hideHandles);
    } else {
      showToolbar();
    }
  }

  @override
  void showMagnifier(Offset positionToShow) {
    if (_selectionOverlay == null) {
      return;
    }

    if (_selectionOverlay!.magnifierIsVisible) {
      _selectionOverlay!.updateMagnifier(positionToShow);
    } else {
      _selectionOverlay!.showMagnifier(positionToShow);
    }
  }

  @override
  void hideMagnifier() {
    if (_selectionOverlay == null) {
      return;
    }

    if (_selectionOverlay!.magnifierIsVisible) {
      _selectionOverlay!.hideMagnifier();
    }
  }

  @override
  bool showSpellCheckSuggestionsToolbar() {
    // Spell check suggestions toolbars are intended to be shown on non-web
    // platforms. Additionally, the Cupertino style toolbar can't be drawn on
    // the web with the HTML renderer due to
    // https://github.com/flutter/flutter/issues/123560.
    final bool platformNotSupported = kIsWeb && BrowserContextMenu.enabled;
    if (!spellCheckEnabled ||
        platformNotSupported ||
        widget.readOnly ||
        _selectionOverlay == null ||
        !_spellCheckResultsReceived ||
        findSuggestionSpanAtCursorIndex(
                textEditingValue.selection.extentOffset) ==
            null) {
      // Only attempt to show the spell check suggestions toolbar if there
      // is a toolbar specified and spell check suggestions available to show.
      return false;
    }

    _selectionOverlay!.showSpellCheckSuggestionsToolbar(
      (BuildContext context) => defaultSpellCheckMenuBuilder(context, this),
    );
    return true;
  }

  late SpellCheckConfiguration _spellCheckConfiguration;

  /// Configuration that determines how spell check will be performed.
  ///
  /// If possible, this configuration will contain a default for the
  /// [SpellCheckService] if it is not otherwise specified.
  ///
  /// See also:
  ///  * [DefaultSpellCheckService], the spell check service used by default.
  @visibleForTesting
  SpellCheckConfiguration get spellCheckConfiguration =>
      _spellCheckConfiguration;

  @override
  bool get spellCheckEnabled => _spellCheckConfiguration.spellCheckEnabled;

  /// The most up-to-date spell check results for text input.
  ///
  /// These results will be updated via calls to spell check through a
  /// [SpellCheckService] and used by this widget to build the [TextSpan] tree
  /// for text input and menus for replacement suggestions of misspelled words.
  SpellCheckResults? spellCheckResults;

  bool get _spellCheckResultsReceived =>
      spellCheckEnabled &&
      spellCheckResults != null &&
      spellCheckResults!.suggestionSpans.isNotEmpty;

  /// Infers the [SpellCheckConfiguration] used to perform spell check.
  ///
  /// If spell check is enabled, this will try to infer a value for
  /// the [SpellCheckService] if left unspecified.
  static SpellCheckConfiguration _inferSpellCheckConfiguration(
      SpellCheckConfiguration? configuration) {
    final SpellCheckService? spellCheckService =
        configuration?.spellCheckService;
    final bool spellCheckAutomaticallyDisabled = configuration == null ||
        configuration == const SpellCheckConfiguration.disabled();
    final bool spellCheckServiceIsConfigured = spellCheckService != null ||
        spellCheckService == null &&
            WidgetsBinding
                .instance.platformDispatcher.nativeSpellCheckServiceDefined;
    if (spellCheckAutomaticallyDisabled || !spellCheckServiceIsConfigured) {
      // Only enable spell check if a non-disabled configuration is provided
      // and if that configuration does not specify a spell check service,
      // a native spell checker must be supported.
      assert(() {
        if (!spellCheckAutomaticallyDisabled &&
            !spellCheckServiceIsConfigured) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: FlutterError(
                'Spell check was enabled with spellCheckConfiguration, but the '
                'current platform does not have a supported spell check '
                'service, and none was provided. Consider disabling spell '
                'check for this platform or passing a SpellCheckConfiguration '
                'with a specified spell check service.',
              ),
              library: 'widget library',
              stack: StackTrace.current,
            ),
          );
        }
        return true;
      }());
      return const SpellCheckConfiguration.disabled();
    }

    return configuration.copyWith(
        spellCheckService: spellCheckService ?? DefaultSpellCheckService());
  }

  @override
  Future<void> performSpellCheck(final String text) async {
    try {
      final Locale? localeForSpellChecking =
          Localizations.maybeLocaleOf(context);

      assert(
        localeForSpellChecking != null,
        'Locale must be specified in widget or Localization widget must be in scope',
      );

      final List<SuggestionSpan>? suggestions = await _spellCheckConfiguration
          .spellCheckService
          ?.fetchSpellCheckSuggestions(localeForSpellChecking!, text);

      if (suggestions == null) {
        // The request to fetch spell check suggestions was canceled due to ongoing request.
        return;
      }

      spellCheckResults = SpellCheckResults(text, suggestions);
      // TODO : renderEditable.text = buildTextSpan();
    } catch (exception, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: exception,
        stack: stack,
        library: 'widgets',
        context: ErrorDescription('while performing spell check'),
      ));
    }
  }

  @override
  SuggestionSpan? findSuggestionSpanAtCursorIndex(int cursorIndex) {
    if (!_spellCheckResultsReceived ||
        spellCheckResults!.suggestionSpans.last.range.end < cursorIndex) {
      // No spell check results have been received or the cursor index is out
      // of range that suggestionSpans covers.
      return null;
    }

    final List<SuggestionSpan> suggestionSpans =
        spellCheckResults!.suggestionSpans;
    int leftIndex = 0;
    int rightIndex = suggestionSpans.length - 1;
    int midIndex = 0;

    while (leftIndex <= rightIndex) {
      midIndex = ((leftIndex + rightIndex) / 2).floor();
      final int currentSpanStart = suggestionSpans[midIndex].range.start;
      final int currentSpanEnd = suggestionSpans[midIndex].range.end;

      if (cursorIndex <= currentSpanEnd && cursorIndex >= currentSpanStart) {
        return suggestionSpans[midIndex];
      } else if (cursorIndex <= currentSpanStart) {
        rightIndex = midIndex - 1;
      } else {
        leftIndex = midIndex + 1;
      }
    }
    return null;
  }

  /// Copy current selection to clipboard.
  @override
  void copySelection(SelectionChangedCause cause) {
    final TextSelection selection = textEditingValue.selection;
    if (selection.isCollapsed) {
      return;
    }

    _setClipboardData();
    if (cause == SelectionChangedCause.toolbar) {
      bringIntoView(textEditingValue.selection.extent);
      hideToolbar(false);

      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
          break;
        case TargetPlatform.macOS:
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          // Collapse the selection and hide the toolbar and handles.
          userUpdateTextEditingValue(
            TextEditingValue(
              text: textEditingValue.text,
              selection: TextSelection.collapsed(
                  offset: textEditingValue.selection.end),
            ),
            SelectionChangedCause.toolbar,
          );
          break;
      }
    }
    clipboardStatus.update();
  }

  /// Cut current selection to clipboard.
  @override
  void cutSelection(SelectionChangedCause cause) {
    if (widget.readOnly) {
      return;
    }
    final TextSelection selection = textEditingValue.selection;
    if (selection.isCollapsed) {
      return;
    }
    _setClipboardData();
    _replaceText(ReplaceTextIntent(textEditingValue, '', selection, cause));
    if (cause == SelectionChangedCause.toolbar) {
      bringIntoView(textEditingValue.selection.extent);
      hideToolbar();
    }
    clipboardStatus.update();
  }

  void _setClipboardData() {
    final TextSelection selection = textEditingValue.selection;
    widget.clipboardManager.setData(FleatherClipboardData(
      plainText: selection.textInside(textEditingValue.text),
      delta: controller.document.toDelta().slice(
          math.min(selection.baseOffset, selection.extentOffset),
          math.max(selection.baseOffset, selection.extentOffset)),
    ));
  }

  /// Paste text from clipboard.
  @override
  Future<void> pasteText(SelectionChangedCause cause) async {
    if (widget.readOnly) {
      return;
    }
    final TextSelection selection = textEditingValue.selection;
    if (!selection.isValid) {
      return;
    }
    // Snapshot the input before using `await`.
    // See https://github.com/flutter/flutter/issues/11427
    final data = await widget.clipboardManager.getData();
    if (data == null || data.isEmpty) {
      return;
    }

    Delta pasteDelta = Delta();
    pasteDelta.retain(selection.baseOffset);
    pasteDelta.delete(selection.extentOffset - selection.baseOffset);

    if (data.hasDelta) {
      pasteDelta = pasteDelta.concat(data.delta!);
    } else {
      pasteDelta.insert(data.plainText!);
    }

    controller.compose(pasteDelta,
        source: ChangeSource.local, forceUpdateSelection: true);

    if (cause == SelectionChangedCause.toolbar) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          bringIntoView(textEditingValue.selection.extent);
        }
      });
      hideToolbar();
    }
  }

  /// Select the entire text value.
  @override
  void selectAll(SelectionChangedCause cause) {
    userUpdateTextEditingValue(
      textEditingValue.copyWith(
        selection: TextSelection(
            baseOffset: 0, extentOffset: textEditingValue.text.length),
      ),
      cause,
    );

    if (cause == SelectionChangedCause.toolbar) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
        case TargetPlatform.iOS:
        case TargetPlatform.fuchsia:
          break;
        case TargetPlatform.macOS:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          hideToolbar();
      }
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          bringIntoView(textEditingValue.selection.extent);
        case TargetPlatform.macOS:
        case TargetPlatform.iOS:
          break;
      }
    }
  }

  void _updateSelectionOverlayForScroll() {
    _selectionOverlay?.updateForScroll();
  }

  // State lifecycle:

  @override
  void initState() {
    super.initState();

    clipboardStatus.addListener(_onChangedClipboardStatus);

    _spellCheckConfiguration =
        _inferSpellCheckConfiguration(widget.spellCheckConfiguration);

    widget.controller.addListener(_didChangeTextEditingValue);

    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_updateSelectionOverlayForScroll);

    // Cursor
    _cursorController = CursorController(
      showCursor: ValueNotifier<bool>(widget.showCursor),
      style: widget.cursorStyle,
      tickerProvider: this,
    );

    // Floating cursor
    _floatingCursorResetController = AnimationController(vsync: this);
    _floatingCursorResetController.addListener(onFloatingCursorResetTick);

    // Focus
    effectiveFocusNode.addListener(_handleFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final parentTheme = FleatherTheme.of(context, nullOk: true);
    final fallbackTheme = FleatherThemeData.fallback(context);
    _themeData = (parentTheme != null)
        ? fallbackTheme.merge(parentTheme)
        : fallbackTheme;

    if (!_didAutoFocus && widget.autofocus) {
      FocusScope.of(context).autofocus(effectiveFocusNode);
      _didAutoFocus = true;
    }
    performSpellCheck(widget.controller.plainTextEditingValue.text);
  }

  @override
  void didUpdateWidget(RawEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    performSpellCheck(widget.controller.plainTextEditingValue.text);

    _cursorController.showCursor.value = widget.showCursor;
    _cursorController.style = widget.cursorStyle;

    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_didChangeTextEditingValue);
      widget.controller.addListener(_didChangeTextEditingValue);
      updateRemoteValueIfNeeded();
    }

    if (widget.scrollController != null &&
        widget.scrollController != _scrollController) {
      _scrollController.removeListener(_updateSelectionOverlayForScroll);
      _scrollController = widget.scrollController!;
      _scrollController.addListener(_updateSelectionOverlayForScroll);
    }

    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode?.removeListener(_handleFocusChanged);
      if (widget.focusNode != null) {
        _internalFocusNode?.dispose();
        _internalFocusNode = null;
      }
      effectiveFocusNode.addListener(_handleFocusChanged);
      updateKeepAlive();
    }

    if (widget.controller.selection != oldWidget.controller.selection) {
      _selectionOverlay?.update(textEditingValue);
      _selectionOverlay?.hideToolbar();
    }

    _selectionOverlay?.handlesVisible = widget.showSelectionHandles;

    if (!shouldCreateInputConnection) {
      closeConnectionIfNeeded();
    } else {
      if (oldWidget.readOnly && _hasFocus) {
        openConnectionIfNeeded();
      } else if (oldWidget.autocorrect != widget.autocorrect ||
          oldWidget.enableSuggestions != widget.enableSuggestions ||
          oldWidget.keyboardAppearance != widget.keyboardAppearance ||
          oldWidget.textCapitalization != widget.textCapitalization ||
          oldWidget.enableInteractiveSelection !=
              widget.enableInteractiveSelection) {
        updateConnectionConfig();
      }
    }
  }

  @override
  void dispose() {
    closeConnectionIfNeeded();
    assert(!hasConnection);
    _selectionOverlay?.dispose();
    _selectionOverlay = null;
    widget.controller.removeListener(_didChangeTextEditingValue);
    effectiveFocusNode.removeListener(_handleFocusChanged);
    _internalFocusNode?.dispose();
    _cursorController.dispose();
    clipboardStatus.removeListener(_onChangedClipboardStatus);
    clipboardStatus.dispose();
    super.dispose();
  }

  void _didChangeTextEditingValue() {
    _showCaretOnScreen();
    updateRemoteValueIfNeeded();
    _cursorController.startOrStopCursorTimerIfNeeded(
        _hasFocus, widget.controller.selection);
    if (hasConnection) {
      // To keep the cursor from blinking while typing, we want to restart the
      // cursor timer every time a new character is typed.
      _cursorController.stopCursorTimer(resetCharTicks: false);
      _cursorController.startCursorTimer();
    }
    setState(() {
      /*
       * We use widget.controller.value in build().
       * We need to run this before updating SelectionOverlay to ensure
       * that renderers are in line with the document.
       */
    });
    // When a new document node is added or removed due to a line/block
    // insertion or deletion, we must wait for next frame the ensure the
    // RenderEditor's child list reflects the new document node structure
    SchedulerBinding.instance.addPersistentFrameCallback((timeStamp) {
      _updateOrDisposeSelectionOverlayIfNeeded();
    });
    _verticalSelectionUpdateAction.stopCurrentVerticalRunIfSelectionChanges();
  }

  void _handleSelectionChanged(
      TextSelection selection, SelectionChangedCause cause) {
    final oldSelection = widget.controller.selection;
    widget.controller.updateSelection(selection, source: ChangeSource.local);
    updateTextInputConnectionStyle(selection.base);

    if (widget.selectionControls == null) {
      _selectionOverlay?.dispose();
      _selectionOverlay = null;
    } else {
      if (_selectionOverlay == null) {
        _selectionOverlay = _createSelectionOverlay();
      } else {
        _selectionOverlay!.update(textEditingValue);
      }
      _selectionOverlay!.handlesVisible = widget.showSelectionHandles;
      _selectionOverlay!.showHandles();
    }

    // This will show the keyboard for all selection changes on the
    // editor, not just changes triggered by user gestures.
    requestKeyboard();

    if (cause == SelectionChangedCause.drag) {
      // When user updates the selection while dragging make sure to
      // bring the updated position (base or extent) into view.
      if (oldSelection.baseOffset != selection.baseOffset) {
        bringIntoView(selection.base);
      } else if (oldSelection.extentOffset != selection.extentOffset) {
        bringIntoView(selection.extent);
      }
    }

    widget.onSelectionChanged?.call(selection, cause);
  }

  EditorTextSelectionOverlay _createSelectionOverlay() {
    return EditorTextSelectionOverlay(
      context: context,
      value: textEditingValue,
      debugRequiredFor: widget,
      toolbarLayerLink: _toolbarLayerLink,
      startHandleLayerLink: _startHandleLayerLink,
      endHandleLayerLink: _endHandleLayerLink,
      renderObject: renderEditor,
      selectionControls: widget.selectionControls,
      selectionDelegate: this,
      dragStartBehavior: DragStartBehavior.start,
      contextMenuBuilder: (context) => widget.contextMenuBuilder(context, this),
      magnifierConfiguration: TextMagnifier.adaptiveMagnifierConfiguration,
    );
  }

  void _handleFocusChanged() {
    openOrCloseConnection();
    _cursorController.startOrStopCursorTimerIfNeeded(
        _hasFocus, widget.controller.selection);
    _updateOrDisposeSelectionOverlayIfNeeded();
    if (_hasFocus) {
      // Listen for changing viewInsets, which indicates keyboard showing up.
      WidgetsBinding.instance.addObserver(this);
      _lastBottomViewInset = View.of(context).viewInsets.bottom;
      _showCaretOnScreen();
//      _lastBottomViewInset = WidgetsBinding.instance.window.viewInsets.bottom;
//      if (!_value.selection.isValid) {
      // Place cursor at the end if the selection is invalid when we receive focus.
//        _handleSelectionChanged(TextSelection.collapsed(offset: _value.text.length), renderEditable, null);
//      }
    } else {
      WidgetsBinding.instance.removeObserver(this);
      // TODO: teach editor about state of the toolbar and whether the user is in the middle of applying styles.
      //       this is needed because some buttons in toolbar can steal focus from the editor
      //       but we want to preserve the selection, maybe adjusting its style slightly.
      //
      // Clear the selection and composition state if this widget lost focus.
      // widget.controller.updateSelection(TextSelection.collapsed(offset: 0),
      //     source: ChangeSource.local);
//      _currentPromptRectRange = null;
    }
    setState(() {
      // Inform the widget that the value of focus has changed. (so that cursor can repaint appropriately)
    });
    updateKeepAlive();
  }

  void _updateOrDisposeSelectionOverlayIfNeeded() {
    if (_selectionOverlay != null) {
      if (_hasFocus) {
        _selectionOverlay!.update(textEditingValue);
      } else {
        _selectionOverlay!.dispose();
        _selectionOverlay = null;
      }
    }
  }

  // Animation configuration for scrolling the caret back on screen.
  static const Duration _caretAnimationDuration = Duration(milliseconds: 100);
  static const Curve _caretAnimationCurve = Curves.fastOutSlowIn;

  bool _showCaretOnScreenScheduled = false;

  void _showCaretOnScreen([bool withAnimation = true]) {
    if (!widget.showCursor || _showCaretOnScreenScheduled) {
      return;
    }

    _showCaretOnScreenScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      _showCaretOnScreenScheduled = false;

      if (!mounted) {
        return;
      }

      final offset = renderEditor.getOffsetToRevealCursor(
          _scrollController.position.viewportDimension,
          _scrollController.offset);

      if (offset != null) {
        if (withAnimation) {
          _scrollController.animateTo(
            math.min(offset, _scrollController.position.maxScrollExtent),
            duration: _caretAnimationDuration,
            curve: _caretAnimationCurve,
          );
        } else {
          _scrollController.jumpTo(
              math.min(offset, _scrollController.position.maxScrollExtent));
        }
      }
    });
  }

  void _onChangedClipboardStatus() {
    setState(() {
      // Inform the widget that the value of clipboardStatus has changed.
    });
  }

  Future<LinkMenuAction> _linkActionPicker(Node linkNode) async {
    final link =
        (linkNode as StyledNode).style.get(ParchmentAttribute.link)!.value!;
    return widget.linkActionPickerDelegate(context, link);
  }

  @override
  void didChangeInputControl(
      TextInputControl? oldControl, TextInputControl? newControl) {
    if (_hasFocus && hasConnection) {
      oldControl?.hide();
      newControl?.show();
    }
  }

  late double _lastBottomViewInset;

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) {
      return;
    }
    final bottomViewInset = View.of(context).viewInsets.bottom;
    if (_lastBottomViewInset != bottomViewInset) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _selectionOverlay?.updateForScroll();
      });
      if (_lastBottomViewInset < bottomViewInset) {
        // Because the metrics change signal from engine will come here every frame
        // (on both iOS and Android). So we don't need to show caret with animation.
        _showCaretOnScreen(false);
      }
    }
    _lastBottomViewInset = bottomViewInset;
  }

  // On MacOS some actions are sent as selectors. We need to manually find the right Action and invoke it.
  // Ref: https://github.com/flutter/flutter/blob/3.7.0/packages/flutter/lib/src/widgets/editable_text.dart#L3731
  @override
  void performSelector(String selectorName) {
    final Intent? intent = intentForMacOSSelector(selectorName);

    if (intent != null) {
      final BuildContext? primaryContext = primaryFocus?.context;
      if (primaryContext != null) {
        Actions.invoke(primaryContext, intent);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMediaQuery(context));
    super.build(context); // See AutomaticKeepAliveClientMixin.

    final Widget child;

    if (widget.scrollable) {
      child = Scrollable(
        key: _scrollableKey,
        excludeFromSemantics: true,
        controller: _scrollController,
        axisDirection: AxisDirection.down,
        scrollBehavior: ScrollConfiguration.of(context).copyWith(
          scrollbars: true,
          overscroll: false,
        ),
        physics: widget.scrollPhysics,
        viewportBuilder: (context, offset) => CompositedTransformTarget(
          link: _toolbarLayerLink,
          child: _Editor(
            key: _editorKey,
            offset: offset,
            document: widget.controller.document,
            selection: widget.controller.selection,
            hasFocus: _hasFocus,
            textDirection: _textDirection,
            startHandleLayerLink: _startHandleLayerLink,
            endHandleLayerLink: _endHandleLayerLink,
            onSelectionChanged: _handleSelectionChanged,
            padding: widget.padding,
            maxContentWidth: widget.maxContentWidth,
            cursorController: _cursorController,
            children: _buildChildren(context),
          ),
        ),
      );
    } else {
      child = CompositedTransformTarget(
        link: _toolbarLayerLink,
        child: Semantics(
          child: _Editor(
            key: _editorKey,
            offset: ViewportOffset.zero(),
            document: widget.controller.document,
            selection: widget.controller.selection,
            hasFocus: _hasFocus,
            cursorController: _cursorController,
            textDirection: _textDirection,
            startHandleLayerLink: _startHandleLayerLink,
            endHandleLayerLink: _endHandleLayerLink,
            onSelectionChanged: _handleSelectionChanged,
            padding: widget.padding,
            maxContentWidth: widget.maxContentWidth,
            children: _buildChildren(context),
          ),
        ),
      );
    }

    final constraints = widget.scrollable
        ? widget.expands
            ? const BoxConstraints.expand()
            : const BoxConstraints.expand().copyWith(minHeight: 0)
        : BoxConstraints(
            minHeight: widget.minHeight ?? 0.0,
            maxHeight: widget.maxHeight ?? double.infinity);

    return FleatherTheme(
      data: _themeData,
      child: MouseRegion(
        cursor: SystemMouseCursors.text,
        child: Actions(
          actions: _actions,
          child: Focus(
            focusNode: effectiveFocusNode,
            child: FleatherKeyboardListener(
              child: ConstrainedBox(
                constraints: constraints,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildChildren(BuildContext context) {
    final result = <Widget>[];
    for (final node in widget.controller.document.root.children) {
      if (node is LineNode) {
        result.add(Directionality(
          textDirection: getDirectionOfNode(node),
          child: EditableTextLine(
            node: node,
            indentWidth: _getIndentForLine(node),
            spacing: _getSpacingForLine(node, _themeData),
            cursorController: _cursorController,
            selection: widget.controller.selection,
            selectionColor: widget.selectionColor,
            enableInteractiveSelection: widget.enableInteractiveSelection,
            body: TextLine(
              node: node,
              readOnly: widget.readOnly,
              controller: widget.controller,
              embedBuilder: widget.embedBuilder,
              linkActionPicker: _linkActionPicker,
              onLaunchUrl: widget.onLaunchUrl,
            ),
            hasFocus: _hasFocus,
            devicePixelRatio: MediaQuery.of(context).devicePixelRatio,
          ),
        ));
      } else if (node is BlockNode) {
        final block = node.style.get(ParchmentAttribute.block);
        result.add(Directionality(
          textDirection: getDirectionOfNode(node),
          child: EditableTextBlock(
            node: node,
            controller: widget.controller,
            readOnly: widget.readOnly,
            spacing: _getSpacingForBlock(node, _themeData),
            cursorController: _cursorController,
            selection: widget.controller.selection,
            selectionColor: widget.selectionColor,
            enableInteractiveSelection: widget.enableInteractiveSelection,
            hasFocus: _hasFocus,
            contentPadding: (block == ParchmentAttribute.block.code)
                ? const EdgeInsets.all(16.0)
                : null,
            embedBuilder: widget.embedBuilder,
            linkActionPicker: _linkActionPicker,
            onLaunchUrl: widget.onLaunchUrl,
          ),
        ));
      } else {
        throw StateError('Unreachable.');
      }
    }
    return result;
  }

  double _getIndentForLine(LineNode node) {
    final indentationLevel =
        node.style.get(ParchmentAttribute.indent)?.value ?? 0;
    return indentationLevel * 16;
  }

  VerticalSpacing _getSpacingForLine(LineNode node, FleatherThemeData theme) {
    final style = node.style.get(ParchmentAttribute.heading);
    if (style == ParchmentAttribute.heading.level1) {
      return theme.heading1.spacing;
    } else if (style == ParchmentAttribute.heading.level2) {
      return theme.heading2.spacing;
    } else if (style == ParchmentAttribute.heading.level3) {
      return theme.heading3.spacing;
    } else if (style == ParchmentAttribute.heading.level4) {
      return theme.heading4.spacing;
    } else if (style == ParchmentAttribute.heading.level5) {
      return theme.heading5.spacing;
    }

    return theme.paragraph.spacing;
  }

  VerticalSpacing _getSpacingForBlock(BlockNode node, FleatherThemeData theme) {
    final style = node.style.get(ParchmentAttribute.block);
    if (style == ParchmentAttribute.block.code) {
      return theme.code.spacing;
    } else if (style == ParchmentAttribute.block.quote) {
      return theme.quote.spacing;
    } else {
      return theme.lists.spacing;
    }
  }

  // --------------------------- Text Editing Actions ---------------------------

  _TextBoundary _characterBoundary(DirectionalTextEditingIntent intent) {
    final _TextBoundary atomicTextBoundary =
        _CharacterBoundary(textEditingValue);
    return _CollapsedSelectionBoundary(atomicTextBoundary, intent.forward);
  }

  _TextBoundary _nextWordBoundary(DirectionalTextEditingIntent intent) {
    final _TextBoundary atomicTextBoundary;
    final _TextBoundary boundary;

    // final TextEditingValue textEditingValue =
    //     _textEditingValueforTextLayoutMetrics;
    atomicTextBoundary = _CharacterBoundary(textEditingValue);
    // This isn't enough. Newline characters.
    boundary = _ExpandedTextBoundary(_WhitespaceBoundary(textEditingValue),
        _WordBoundary(renderEditor, textEditingValue));

    final _MixedBoundary mixedBoundary = intent.forward
        ? _MixedBoundary(atomicTextBoundary, boundary)
        : _MixedBoundary(boundary, atomicTextBoundary);
    // Use a _MixedBoundary to make sure we don't leave invalid codepoints in
    // the field after deletion.
    return _CollapsedSelectionBoundary(mixedBoundary, intent.forward);
  }

  _TextBoundary _linebreak(DirectionalTextEditingIntent intent) {
    final _TextBoundary atomicTextBoundary;
    final _TextBoundary boundary;

    // final TextEditingValue textEditingValue =
    //     _textEditingValueforTextLayoutMetrics;
    atomicTextBoundary = _CharacterBoundary(textEditingValue);
    boundary = _LineBreak(renderEditor, textEditingValue);

    // The _MixedBoundary is to make sure we don't leave invalid code units in
    // the field after deletion.
    // `boundary` doesn't need to be wrapped in a _CollapsedSelectionBoundary,
    // since the document boundary is unique and the linebreak boundary is
    // already caret-location based.
    return intent.forward
        ? _MixedBoundary(
            _CollapsedSelectionBoundary(atomicTextBoundary, true), boundary)
        : _MixedBoundary(
            boundary, _CollapsedSelectionBoundary(atomicTextBoundary, false));
  }

  _TextBoundary _paragraphBoundary(DirectionalTextEditingIntent intent) =>
      _ParagraphBoundary(textEditingValue);

  _TextBoundary _documentBoundary(DirectionalTextEditingIntent intent) =>
      _DocumentBoundary(textEditingValue);

  // Scrolls either to the beginning or end of the document depending on the
  // intent's `forward` parameter.
  void _scrollToDocumentBoundary(ScrollToDocumentBoundaryIntent intent) {
    if (intent.forward) {
      bringIntoView(TextPosition(offset: textEditingValue.text.length));
    } else {
      bringIntoView(const TextPosition(offset: 0));
    }
  }

  /// Handles [ScrollIntent] by scrolling the [Scrollable] inside of
  /// [EditableText].
  void _scroll(ScrollIntent intent) {
    if (intent.type != ScrollIncrementType.page) {
      return;
    }

    final ScrollPosition position = _scrollController.position;
    // If the field isn't scrollable, do nothing. For example, when the lines of
    // text is less than maxLines, the field has nothing to scroll.
    if (position.maxScrollExtent == 0.0 && position.minScrollExtent == 0.0) {
      return;
    }

    final ScrollableState? state =
        _scrollableKey.currentState as ScrollableState?;
    final double increment =
        ScrollAction.getDirectionalIncrement(state!, intent);
    final double destination = clampDouble(
      position.pixels + increment,
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (destination == position.pixels) {
      return;
    }
    _scrollController.jumpTo(destination);
  }

  Action<T> _makeOverridable<T extends Intent>(Action<T> defaultAction) {
    return Action<T>.overridable(
        context: context, defaultAction: defaultAction);
  }

  void _replaceText(ReplaceTextIntent intent) {
    userUpdateTextEditingValue(
      intent.currentTextEditingValue
          .replaced(intent.replacementRange, intent.replacementText),
      intent.cause,
    );
  }

  late final Action<ReplaceTextIntent> _replaceTextAction =
      CallbackAction<ReplaceTextIntent>(onInvoke: _replaceText);

  void _updateSelection(UpdateSelectionIntent intent) {
    userUpdateTextEditingValue(
      intent.currentTextEditingValue.copyWith(selection: intent.newSelection),
      intent.cause,
    );
  }

  late final Action<UpdateSelectionIntent> _updateSelectionAction =
      CallbackAction<UpdateSelectionIntent>(onInvoke: _updateSelection);

  late final _UpdateTextSelectionVerticallyAction<
          DirectionalCaretMovementIntent> _verticalSelectionUpdateAction =
      _UpdateTextSelectionVerticallyAction<DirectionalCaretMovementIntent>(
          this);

  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    DoNothingAndStopPropagationTextIntent: DoNothingAction(consumesKey: false),
    ReplaceTextIntent: _replaceTextAction,
    UpdateSelectionIntent: _updateSelectionAction,
    DirectionalFocusIntent: DirectionalFocusAction.forTextField(),

    // Delete
    DeleteCharacterIntent: _makeOverridable(
        _DeleteTextAction<DeleteCharacterIntent>(this, _characterBoundary)),
    DeleteToNextWordBoundaryIntent: _makeOverridable(
        _DeleteTextAction<DeleteToNextWordBoundaryIntent>(
            this, _nextWordBoundary)),
    DeleteToLineBreakIntent: _makeOverridable(
        _DeleteTextAction<DeleteToLineBreakIntent>(this, _linebreak)),

    // Extend/Move Selection
    ExtendSelectionByCharacterIntent: _makeOverridable(
        _UpdateTextSelectionAction<ExtendSelectionByCharacterIntent>(
      this,
      false,
      _characterBoundary,
    )),
    ExtendSelectionToNextWordBoundaryIntent: _makeOverridable(
        _UpdateTextSelectionAction<ExtendSelectionToNextWordBoundaryIntent>(
            this, true, _nextWordBoundary)),
    ExtendSelectionToLineBreakIntent: _makeOverridable(
        _UpdateTextSelectionAction<ExtendSelectionToLineBreakIntent>(
            this, true, _linebreak)),
    ExpandSelectionToLineBreakIntent:
        _makeOverridable(_UpdateTextSelectionAction(this, false, _linebreak)),
    ExtendSelectionVerticallyToAdjacentLineIntent:
        _makeOverridable(_verticalSelectionUpdateAction),
    ExtendSelectionVerticallyToAdjacentPageIntent:
        _makeOverridable(_verticalSelectionUpdateAction),
    ExtendSelectionToDocumentBoundaryIntent: _makeOverridable(
        _UpdateTextSelectionAction<ExtendSelectionToDocumentBoundaryIntent>(
            this, false, _documentBoundary)),
    ExtendSelectionToNextParagraphBoundaryOrCaretLocationIntent:
        _makeOverridable(_UpdateTextSelectionAction<
                ExtendSelectionToNextParagraphBoundaryOrCaretLocationIntent>(
            this, true, _paragraphBoundary)),
    ExpandSelectionToDocumentBoundaryIntent: _makeOverridable(
        _UpdateTextSelectionAction<ExpandSelectionToDocumentBoundaryIntent>(
            this, true, _documentBoundary)),
    ExtendSelectionToNextWordBoundaryOrCaretLocationIntent: _makeOverridable(
        _ExtendSelectionOrCaretPositionAction(this, _nextWordBoundary)),
    ScrollToDocumentBoundaryIntent: _makeOverridable(
        CallbackAction<ScrollToDocumentBoundaryIntent>(
            onInvoke: _scrollToDocumentBoundary)),
    ScrollIntent: CallbackAction<ScrollIntent>(onInvoke: _scroll),

    // Copy Paste
    SelectAllTextIntent: _makeOverridable(_SelectAllAction(this)),
    CopySelectionTextIntent: _makeOverridable(_CopySelectionAction(this)),
    PasteTextIntent: _makeOverridable(CallbackAction<PasteTextIntent>(
        onInvoke: (PasteTextIntent intent) => pasteText(intent.cause))),
  };

  @override
  void insertTextPlaceholder(Size size) {
    // TODO: implement insertTextPlaceholder
  }

  @override
  void removeTextPlaceholder() {
    // TODO: implement removeTextPlaceholder
  }

  /// Returns the anchor points for the default context menu.
  @override
  TextSelectionToolbarAnchors get contextMenuAnchors {
    if (renderEditor.lastSecondaryTapDownPosition != null) {
      return TextSelectionToolbarAnchors(
          primaryAnchor: renderEditor.lastSecondaryTapDownPosition!);
    }
    final selection = textEditingValue.selection;
    // Find the horizontal midpoint, just above the selected text.
    final List<TextSelectionPoint> endpoints =
        renderEditor.getEndpointsForSelection(selection);

    final baseLineHeight = renderEditor.preferredLineHeight(selection.base);
    final extentLineHeight = renderEditor.preferredLineHeight(selection.extent);
    final smallestLineHeight = math.min(baseLineHeight, extentLineHeight);

    return _textSelectionToolbarAnchorsFromSelection(
        startGlyphHeight: smallestLineHeight,
        endGlyphHeight: smallestLineHeight,
        selectionEndpoints: endpoints);
  }

  TextSelectionToolbarAnchors _textSelectionToolbarAnchorsFromSelection({
    required double startGlyphHeight,
    required double endGlyphHeight,
    required List<TextSelectionPoint> selectionEndpoints,
  }) {
    // If editor is scrollable, the editing region is only the viewport
    // otherwise use editor as editing region
    final paintOffset = renderEditor.paintOffset;
    final Rect editingRegion = Rect.fromPoints(
      renderEditor.localToGlobal(Offset.zero),
      renderEditor.localToGlobal(renderEditor.size.bottomRight(Offset.zero)),
    );

    if (editingRegion.left.isNaN ||
        editingRegion.top.isNaN ||
        editingRegion.right.isNaN ||
        editingRegion.bottom.isNaN) {
      return const TextSelectionToolbarAnchors(primaryAnchor: Offset.zero);
    }
    final viewportAdjustedBasePointDy =
        selectionEndpoints.first.point.dy + paintOffset.dy;
    final viewportAdjustedEndPointDy =
        selectionEndpoints.last.point.dy + paintOffset.dy;
    final bool isMultiline =
        viewportAdjustedEndPointDy - viewportAdjustedBasePointDy >
            endGlyphHeight / 2;

    final Rect selectionRect = Rect.fromLTRB(
      isMultiline
          ? editingRegion.left
          : editingRegion.left + selectionEndpoints.first.point.dx,
      editingRegion.top + viewportAdjustedBasePointDy - startGlyphHeight,
      isMultiline
          ? editingRegion.right
          : editingRegion.left + selectionEndpoints.last.point.dx,
      editingRegion.top + viewportAdjustedEndPointDy,
    );

    return TextSelectionToolbarAnchors(
      primaryAnchor: Offset(
        selectionRect.left + selectionRect.width / 2,
        clampDouble(selectionRect.top, editingRegion.top, editingRegion.bottom),
      ),
      secondaryAnchor: Offset(
        selectionRect.left + selectionRect.width / 2,
        clampDouble(
            selectionRect.bottom, editingRegion.top, editingRegion.bottom),
      ),
    );
  }

  /// Returns the [ContextMenuButtonItem]s representing the buttons in this
  /// platform's default selection menu using [EditableText.getEditableButtonItems].
  @override
  List<ContextMenuButtonItem> get contextMenuButtonItems {
    return EditableText.getEditableButtonItems(
        clipboardStatus: clipboardStatus.value,
        onCopy: copyEnabled
            ? () => copySelection(SelectionChangedCause.toolbar)
            : null,
        onCut: cutEnabled
            ? () => cutSelection(SelectionChangedCause.toolbar)
            : null,
        onPaste: pasteEnabled
            ? () => pasteText(SelectionChangedCause.toolbar)
            : null,
        onSelectAll: selectAllEnabled
            ? () => selectAll(SelectionChangedCause.toolbar)
            : null,
        onLookUp: null,
        onSearchWeb: null,
        onShare: null,
        onLiveTextInput: null);
  }

  @override
  bool liveTextInputEnabled = false;
}

class _Editor extends MultiChildRenderObjectWidget {
  const _Editor({
    required Key super.key,
    required super.children,
    required this.offset,
    required this.document,
    required this.textDirection,
    required this.hasFocus,
    required this.selection,
    required this.startHandleLayerLink,
    required this.endHandleLayerLink,
    required this.onSelectionChanged,
    required this.cursorController,
    this.padding = EdgeInsets.zero,
    this.maxContentWidth,
  });

  final ViewportOffset offset;
  final ParchmentDocument document;
  final TextDirection textDirection;
  final bool hasFocus;
  final TextSelection selection;
  final LayerLink startHandleLayerLink;
  final LayerLink endHandleLayerLink;
  final TextSelectionChangedHandler onSelectionChanged;
  final EdgeInsetsGeometry padding;
  final double? maxContentWidth;
  final CursorController cursorController;

  @override
  RenderEditor createRenderObject(BuildContext context) {
    return RenderEditor(
      offset: offset,
      document: document,
      textDirection: textDirection,
      hasFocus: hasFocus,
      selection: selection,
      startHandleLayerLink: startHandleLayerLink,
      endHandleLayerLink: endHandleLayerLink,
      onSelectionChanged: onSelectionChanged,
      cursorController: cursorController,
      padding: padding,
      maxContentWidth: maxContentWidth,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderEditor renderObject) {
    renderObject.offset = offset;
    renderObject.document = document;
    renderObject.node = document.root;
    renderObject.textDirection = textDirection;
    renderObject.hasFocus = hasFocus;
    renderObject.selection = selection;
    renderObject.startHandleLayerLink = startHandleLayerLink;
    renderObject.endHandleLayerLink = endHandleLayerLink;
    renderObject.onSelectionChanged = onSelectionChanged;
    renderObject.padding = padding;
    renderObject.maxContentWidth = maxContentWidth;
  }
}

/// An interface for retrieving the logical text boundary (left-closed-right-open)
/// at a given location in a document.
///
/// Depending on the implementation of the [_TextBoundary], the input
/// [TextPosition] can either point to a code unit, or a position between 2 code
/// units (which can be visually represented by the caret if the selection were
/// to collapse to that position).
///
/// For example, [_LineBreak] interprets the input [TextPosition] as a caret
/// location, since in Flutter the caret is generally painted between the
/// character the [TextPosition] points to and its previous character, and
/// [_LineBreak] cares about the affinity of the input [TextPosition]. Most
/// other text boundaries however, interpret the input [TextPosition] as the
/// location of a code unit in the document, since it's easier to reason about
/// the text boundary given a code unit in the text.
///
/// To convert a "code-unit-based" [_TextBoundary] to "caret-location-based",
/// use the [_CollapsedSelectionBoundary] combinator.
abstract class _TextBoundary {
  const _TextBoundary();

  TextEditingValue get textEditingValue;

  /// Returns the leading text boundary at the given location, inclusive.
  TextPosition getLeadingTextBoundaryAt(TextPosition position);

  /// Returns the trailing text boundary at the given location, exclusive.
  TextPosition getTrailingTextBoundaryAt(TextPosition position);

  TextRange getTextBoundaryAt(TextPosition position) {
    return TextRange(
      start: getLeadingTextBoundaryAt(position).offset,
      end: getTrailingTextBoundaryAt(position).offset,
    );
  }
}

// -----------------------------  Text Boundaries -----------------------------

// TODO: Check whether to use it or remove it
// ignore: unused_element
class _CodeUnitBoundary extends _TextBoundary {
  const _CodeUnitBoundary(this.textEditingValue);

  @override
  final TextEditingValue textEditingValue;

  @override
  TextPosition getLeadingTextBoundaryAt(TextPosition position) =>
      TextPosition(offset: position.offset);

  @override
  TextPosition getTrailingTextBoundaryAt(TextPosition position) => TextPosition(
      offset: math.min(position.offset + 1, textEditingValue.text.length));
}

// The word modifier generally removes the word boundaries around white spaces
// (and newlines), IOW white spaces and some other punctuations are considered
// a part of the next word in the search direction.
class _WhitespaceBoundary extends _TextBoundary {
  const _WhitespaceBoundary(this.textEditingValue);

  @override
  final TextEditingValue textEditingValue;

  @override
  TextPosition getLeadingTextBoundaryAt(TextPosition position) {
    for (int index = position.offset; index >= 0; index -= 1) {
      if (!TextLayoutMetrics.isWhitespace(
          textEditingValue.text.codeUnitAt(index))) {
        return TextPosition(offset: index);
      }
    }
    return const TextPosition(offset: 0);
  }

  @override
  TextPosition getTrailingTextBoundaryAt(TextPosition position) {
    for (int index = position.offset;
        index < textEditingValue.text.length;
        index += 1) {
      if (!TextLayoutMetrics.isWhitespace(
          textEditingValue.text.codeUnitAt(index))) {
        return TextPosition(offset: index + 1);
      }
    }
    return TextPosition(offset: textEditingValue.text.length);
  }
}

// Most apps delete the entire grapheme when the backspace key is pressed.
// Also always put the new caret location to character boundaries to avoid
// sending malformed UTF-16 code units to the paragraph builder.
class _CharacterBoundary extends _TextBoundary {
  const _CharacterBoundary(this.textEditingValue);

  @override
  final TextEditingValue textEditingValue;

  @override
  TextPosition getLeadingTextBoundaryAt(TextPosition position) {
    final int endOffset =
        math.min(position.offset + 1, textEditingValue.text.length);
    return TextPosition(
      offset:
          CharacterRange.at(textEditingValue.text, position.offset, endOffset)
              .stringBeforeLength,
    );
  }

  @override
  TextPosition getTrailingTextBoundaryAt(TextPosition position) {
    final int endOffset =
        math.min(position.offset + 1, textEditingValue.text.length);
    final CharacterRange range =
        CharacterRange.at(textEditingValue.text, position.offset, endOffset);
    return TextPosition(
      offset: textEditingValue.text.length - range.stringAfterLength,
    );
  }

  @override
  TextRange getTextBoundaryAt(TextPosition position) {
    final int endOffset =
        math.min(position.offset + 1, textEditingValue.text.length);
    final CharacterRange range =
        CharacterRange.at(textEditingValue.text, position.offset, endOffset);
    return TextRange(
      start: range.stringBeforeLength,
      end: textEditingValue.text.length - range.stringAfterLength,
    );
  }
}

// [UAX #29](https://unicode.org/reports/tr29/) defined word boundaries.
class _WordBoundary extends _TextBoundary {
  const _WordBoundary(this.textLayout, this.textEditingValue);

  final TextLayoutMetrics textLayout;

  @override
  final TextEditingValue textEditingValue;

  @override
  TextPosition getLeadingTextBoundaryAt(TextPosition position) {
    return TextPosition(
      offset: textLayout.getWordBoundary(position).start,
      // Word boundary seems to always report downstream on many platforms.
      affinity:
          TextAffinity.downstream, // ignore: avoid_redundant_argument_values
    );
  }

  @override
  TextPosition getTrailingTextBoundaryAt(TextPosition position) {
    return TextPosition(
      offset: textLayout.getWordBoundary(position).end,
      // Word boundary seems to always report downstream on many platforms.
      affinity:
          TextAffinity.downstream, // ignore: avoid_redundant_argument_values
    );
  }
}

// The line breaks of the current text layout. The input [TextPosition]s are
// interpreted as caret locations because [TextPainter.getLineAtOffset] is
// text-affinity-aware.
class _LineBreak extends _TextBoundary {
  const _LineBreak(this.textLayout, this.textEditingValue);

  final TextLayoutMetrics textLayout;

  @override
  final TextEditingValue textEditingValue;

  @override
  TextPosition getLeadingTextBoundaryAt(TextPosition position) {
    return TextPosition(
      offset: textLayout.getLineAtOffset(position).start,
    );
  }

  @override
  TextPosition getTrailingTextBoundaryAt(TextPosition position) {
    return TextPosition(
      offset: textLayout.getLineAtOffset(position).end,
      affinity: TextAffinity.upstream,
    );
  }
}

// A text boundary that uses paragraphs as logical boundaries.
// A paragraph is defined as the range between line terminators. If no
// line terminators exist then the paragraph boundary is the entire document.
class _ParagraphBoundary extends _TextBoundary {
  const _ParagraphBoundary(this.textEditingValue);

  @override
  final TextEditingValue textEditingValue;

  String get _text => textEditingValue.text;

  @override
  TextPosition getLeadingTextBoundaryAt(TextPosition position) {
    assert(position.offset >= 0);

    if (position.offset >= _text.length) {
      return TextPosition(offset: _text.length);
    }

    if (position.offset == 0) {
      return const TextPosition(offset: 0);
    }

    int index = position.offset;

    if (index > 1 &&
        _text.codeUnitAt(index) == 0x0A &&
        _text.codeUnitAt(index - 1) == 0x0D) {
      index -= 2;
    } else if (TextLayoutMetrics.isLineTerminator(_text.codeUnitAt(index))) {
      index -= 1;
    }

    while (index > 0) {
      if (TextLayoutMetrics.isLineTerminator(_text.codeUnitAt(index))) {
        return TextPosition(offset: index + 1);
      }
      index -= 1;
    }

    return TextPosition(offset: max(index, 0));
  }

  @override
  TextPosition getTrailingTextBoundaryAt(TextPosition position) {
    assert(position.offset < _text.length);

    if (_text.isEmpty) {
      return position;
    }

    if (position.offset < 0) {
      return const TextPosition(offset: 0);
    }

    int index = position.offset;

    while (!TextLayoutMetrics.isLineTerminator(_text.codeUnitAt(index))) {
      index += 1;
      if (index == _text.length) {
        return TextPosition(offset: index);
      }
    }

    return TextPosition(
        offset: index < _text.length - 1 &&
                _text.codeUnitAt(index) == 0x0D &&
                _text.codeUnitAt(index + 1) == 0x0A
            ? index + 2
            : index + 1);
  }
}

// The document boundary is unique and is a constant function of the input
// position.
class _DocumentBoundary extends _TextBoundary {
  const _DocumentBoundary(this.textEditingValue);

  @override
  final TextEditingValue textEditingValue;

  @override
  TextPosition getLeadingTextBoundaryAt(TextPosition position) =>
      const TextPosition(offset: 0);

  @override
  TextPosition getTrailingTextBoundaryAt(TextPosition position) {
    return TextPosition(
      offset: textEditingValue.text.length,
      affinity: TextAffinity.upstream,
    );
  }
}

// ------------------------  Text Boundary Combinators ------------------------

// Expands the innerTextBoundary with outerTextBoundary.
class _ExpandedTextBoundary extends _TextBoundary {
  _ExpandedTextBoundary(this.innerTextBoundary, this.outerTextBoundary);

  final _TextBoundary innerTextBoundary;
  final _TextBoundary outerTextBoundary;

  @override
  TextEditingValue get textEditingValue {
    assert(innerTextBoundary.textEditingValue ==
        outerTextBoundary.textEditingValue);
    return innerTextBoundary.textEditingValue;
  }

  @override
  TextPosition getLeadingTextBoundaryAt(TextPosition position) {
    return outerTextBoundary.getLeadingTextBoundaryAt(
      innerTextBoundary.getLeadingTextBoundaryAt(position),
    );
  }

  @override
  TextPosition getTrailingTextBoundaryAt(TextPosition position) {
    return outerTextBoundary.getTrailingTextBoundaryAt(
      innerTextBoundary.getTrailingTextBoundaryAt(position),
    );
  }
}

// Force the innerTextBoundary to interpret the input [TextPosition]s as caret
// locations instead of code unit positions.
//
// The innerTextBoundary must be a [_TextBoundary] that interprets the input
// [TextPosition]s as code unit positions.
class _CollapsedSelectionBoundary extends _TextBoundary {
  _CollapsedSelectionBoundary(this.innerTextBoundary, this.isForward);

  final _TextBoundary innerTextBoundary;
  final bool isForward;

  @override
  TextEditingValue get textEditingValue => innerTextBoundary.textEditingValue;

  @override
  TextPosition getLeadingTextBoundaryAt(TextPosition position) {
    return isForward
        ? innerTextBoundary.getLeadingTextBoundaryAt(position)
        : position.offset <= 0
            ? const TextPosition(offset: 0)
            : innerTextBoundary.getLeadingTextBoundaryAt(
                TextPosition(offset: position.offset - 1));
  }

  @override
  TextPosition getTrailingTextBoundaryAt(TextPosition position) {
    return isForward
        ? innerTextBoundary.getTrailingTextBoundaryAt(position)
        : position.offset <= 0
            ? const TextPosition(offset: 0)
            : innerTextBoundary.getTrailingTextBoundaryAt(
                TextPosition(offset: position.offset - 1));
  }
}

// A _TextBoundary that creates a [TextRange] where its start is from the
// specified leading text boundary and its end is from the specified trailing
// text boundary.
class _MixedBoundary extends _TextBoundary {
  _MixedBoundary(this.leadingTextBoundary, this.trailingTextBoundary);

  final _TextBoundary leadingTextBoundary;
  final _TextBoundary trailingTextBoundary;

  @override
  TextEditingValue get textEditingValue {
    assert(leadingTextBoundary.textEditingValue ==
        trailingTextBoundary.textEditingValue);
    return leadingTextBoundary.textEditingValue;
  }

  @override
  TextPosition getLeadingTextBoundaryAt(TextPosition position) =>
      leadingTextBoundary.getLeadingTextBoundaryAt(position);

  @override
  TextPosition getTrailingTextBoundaryAt(TextPosition position) =>
      trailingTextBoundary.getTrailingTextBoundaryAt(position);
}

// -------------------------------  Text Actions -------------------------------
class _DeleteTextAction<T extends DirectionalTextEditingIntent>
    extends ContextAction<T> {
  _DeleteTextAction(this.state, this.getTextBoundariesForIntent);

  final RawEditorState state;
  final _TextBoundary Function(T intent) getTextBoundariesForIntent;

  TextRange _expandNonCollapsedRange(TextEditingValue value) {
    final TextRange selection = value.selection;
    assert(selection.isValid);
    assert(!selection.isCollapsed);
    final _TextBoundary atomicBoundary = _CharacterBoundary(value);

    return TextRange(
      start: atomicBoundary
          .getLeadingTextBoundaryAt(TextPosition(offset: selection.start))
          .offset,
      end: atomicBoundary
          .getTrailingTextBoundaryAt(TextPosition(offset: selection.end - 1))
          .offset,
    );
  }

  @override
  Object? invoke(T intent, [BuildContext? context]) {
    final TextSelection selection = state.textEditingValue.selection;
    assert(selection.isValid);

    if (!selection.isCollapsed) {
      return Actions.invoke(
        context!,
        ReplaceTextIntent(
            state.textEditingValue,
            '',
            _expandNonCollapsedRange(state.textEditingValue),
            SelectionChangedCause.keyboard),
      );
    }

    final _TextBoundary textBoundary = getTextBoundariesForIntent(intent);
    if (!textBoundary.textEditingValue.selection.isValid) {
      return null;
    }
    if (!textBoundary.textEditingValue.selection.isCollapsed) {
      return Actions.invoke(
        context!,
        ReplaceTextIntent(
            state.textEditingValue,
            '',
            _expandNonCollapsedRange(textBoundary.textEditingValue),
            SelectionChangedCause.keyboard),
      );
    }

    return Actions.invoke(
      context!,
      ReplaceTextIntent(
        textBoundary.textEditingValue,
        '',
        textBoundary
            .getTextBoundaryAt(textBoundary.textEditingValue.selection.base),
        SelectionChangedCause.keyboard,
      ),
    );
  }

  @override
  bool get isActionEnabled =>
      !state.widget.readOnly && state.textEditingValue.selection.isValid;
}

class _UpdateTextSelectionVerticallyAction<
    T extends DirectionalCaretMovementIntent> extends ContextAction<T> {
  _UpdateTextSelectionVerticallyAction(this.state);

  final RawEditorState state;

  FleatherVerticalCaretMovementRun? _verticalMovementRun;
  TextSelection? _runSelection;

  void stopCurrentVerticalRunIfSelectionChanges() {
    final TextSelection? runSelection = _runSelection;
    if (runSelection == null) {
      assert(_verticalMovementRun == null);
      return;
    }
    _runSelection = state.textEditingValue.selection;
    final TextSelection currentSelection = state.widget.controller.selection;
    final bool continueCurrentRun = currentSelection.isValid &&
        currentSelection.isCollapsed &&
        currentSelection.baseOffset == runSelection.baseOffset &&
        currentSelection.extentOffset == runSelection.extentOffset;
    if (!continueCurrentRun) {
      _verticalMovementRun = null;
      _runSelection = null;
    }
  }

  @override
  void invoke(T intent, [BuildContext? context]) {
    assert(state.textEditingValue.selection.isValid);

    final bool collapseSelection =
        intent.collapseSelection || !state.widget.selectionEnabled;
    final TextEditingValue value = state.textEditingValue;
    if (!value.selection.isValid) {
      return;
    }

    final currentRun = _verticalMovementRun ??
        state.renderEditor
            .startVerticalCaretMovement(state.renderEditor.selection.extent);

    final bool shouldMove =
        intent is ExtendSelectionVerticallyToAdjacentPageIntent
            ? currentRun.moveByOffset(
                (intent.forward ? 1.0 : -1.0) * state.renderEditor.size.height)
            : intent.forward
                ? currentRun.moveNext()
                : currentRun.movePrevious();

    TextPosition computeNewExtent() {
      if (shouldMove) return currentRun.current;

      if (intent.forward) {
        if (collapseSelection) {
          state.updateLastKnownWithSelection(TextSelection.collapsed(
              offset: state.textEditingValue.text.length));
        }
        return TextPosition(offset: state.textEditingValue.text.length - 1);
      }

      return const TextPosition(offset: 0);
    }

    final TextPosition newExtent = computeNewExtent();
    final TextSelection newSelection = collapseSelection
        ? TextSelection.fromPosition(newExtent)
        : value.selection.extendTo(newExtent);

    Actions.invoke(
      context!,
      UpdateSelectionIntent(
          value, newSelection, SelectionChangedCause.keyboard),
    );
    state.bringIntoView(state.textEditingValue.selection.extent);
    if (state.textEditingValue.selection == newSelection) {
      _verticalMovementRun = currentRun;
      _runSelection = newSelection;
    }
  }

  @override
  bool get isActionEnabled => state.textEditingValue.selection.isValid;
}

class _UpdateTextSelectionAction<T extends DirectionalCaretMovementIntent>
    extends ContextAction<T> {
  _UpdateTextSelectionAction(this.state, this.ignoreNonCollapsedSelection,
      this.getTextBoundariesForIntent);

  final RawEditorState state;
  final bool ignoreNonCollapsedSelection;
  final _TextBoundary Function(T intent) getTextBoundariesForIntent;

  @override
  Object? invoke(T intent, [BuildContext? context]) {
    final TextSelection selection = state.textEditingValue.selection;
    assert(selection.isValid);

    final bool collapseSelection =
        intent.collapseSelection || !state.widget.selectionEnabled;
    // Collapse to the logical start/end.
    TextSelection collapse(TextSelection selection) {
      assert(selection.isValid);
      assert(!selection.isCollapsed);
      return selection.copyWith(
        baseOffset: intent.forward ? selection.end : selection.start,
        extentOffset: intent.forward ? selection.end : selection.start,
      );
    }

    if (!selection.isCollapsed &&
        !ignoreNonCollapsedSelection &&
        collapseSelection) {
      return Actions.invoke(
        context!,
        UpdateSelectionIntent(state.textEditingValue, collapse(selection),
            SelectionChangedCause.keyboard),
      );
    }

    final _TextBoundary textBoundary = getTextBoundariesForIntent(intent);
    final TextSelection textBoundarySelection =
        textBoundary.textEditingValue.selection;
    if (!textBoundarySelection.isValid) {
      return null;
    }
    if (!textBoundarySelection.isCollapsed &&
        !ignoreNonCollapsedSelection &&
        collapseSelection) {
      return Actions.invoke(
        context!,
        UpdateSelectionIntent(state.textEditingValue,
            collapse(textBoundarySelection), SelectionChangedCause.keyboard),
      );
    }

    final TextPosition extent = textBoundarySelection.extent;
    final TextPosition newExtent = intent.forward
        ? textBoundary.getTrailingTextBoundaryAt(extent)
        : textBoundary.getLeadingTextBoundaryAt(extent);

    final TextSelection newSelection = collapseSelection
        ? TextSelection.fromPosition(newExtent)
        : textBoundarySelection.extendTo(newExtent);

    // If collapseAtReversal is true and would have an effect, collapse it.
    if (!selection.isCollapsed &&
        intent.collapseAtReversal &&
        (selection.baseOffset < selection.extentOffset !=
            newSelection.baseOffset < newSelection.extentOffset)) {
      return Actions.invoke(
        context!,
        UpdateSelectionIntent(
          state.textEditingValue,
          TextSelection.fromPosition(selection.base),
          SelectionChangedCause.keyboard,
        ),
      );
    }

    return Actions.invoke(
      context!,
      UpdateSelectionIntent(textBoundary.textEditingValue, newSelection,
          SelectionChangedCause.keyboard),
    );
  }

  @override
  bool get isActionEnabled => state.textEditingValue.selection.isValid;
}

class _ExtendSelectionOrCaretPositionAction extends ContextAction<
    ExtendSelectionToNextWordBoundaryOrCaretLocationIntent> {
  _ExtendSelectionOrCaretPositionAction(
      this.state, this.getTextBoundariesForIntent);

  final RawEditorState state;
  final _TextBoundary Function(
          ExtendSelectionToNextWordBoundaryOrCaretLocationIntent intent)
      getTextBoundariesForIntent;

  @override
  Object? invoke(ExtendSelectionToNextWordBoundaryOrCaretLocationIntent intent,
      [BuildContext? context]) {
    final TextSelection selection = state.textEditingValue.selection;
    assert(selection.isValid);

    final _TextBoundary textBoundary = getTextBoundariesForIntent(intent);
    final TextSelection textBoundarySelection =
        textBoundary.textEditingValue.selection;
    if (!textBoundarySelection.isValid) {
      return null;
    }

    final TextPosition extent = textBoundarySelection.extent;
    final TextPosition newExtent = intent.forward
        ? textBoundary.getTrailingTextBoundaryAt(extent)
        : textBoundary.getLeadingTextBoundaryAt(extent);

    final TextSelection newSelection =
        (newExtent.offset - textBoundarySelection.baseOffset) *
                    (textBoundarySelection.extentOffset -
                        textBoundarySelection.baseOffset) <
                0
            ? textBoundarySelection.copyWith(
                extentOffset: textBoundarySelection.baseOffset,
                affinity: textBoundarySelection.extentOffset >
                        textBoundarySelection.baseOffset
                    ? TextAffinity.downstream
                    : TextAffinity.upstream,
              )
            : textBoundarySelection.extendTo(newExtent);

    return Actions.invoke(
      context!,
      UpdateSelectionIntent(textBoundary.textEditingValue, newSelection,
          SelectionChangedCause.keyboard),
    );
  }

  @override
  bool get isActionEnabled =>
      state.widget.selectionEnabled && state.textEditingValue.selection.isValid;
}

class _SelectAllAction extends ContextAction<SelectAllTextIntent> {
  _SelectAllAction(this.state);

  final RawEditorState state;

  @override
  Object? invoke(SelectAllTextIntent intent, [BuildContext? context]) {
    return Actions.invoke(
      context!,
      UpdateSelectionIntent(
        state.textEditingValue,
        TextSelection(
            baseOffset: 0, extentOffset: state.textEditingValue.text.length),
        intent.cause,
      ),
    );
  }

  @override
  bool get isActionEnabled => state.widget.selectionEnabled;
}

class _CopySelectionAction extends ContextAction<CopySelectionTextIntent> {
  _CopySelectionAction(this.state);

  final RawEditorState state;

  @override
  void invoke(CopySelectionTextIntent intent, [BuildContext? context]) {
    if (intent.collapseSelection) {
      state.cutSelection(intent.cause);
    } else {
      state.copySelection(intent.cause);
    }
  }

  @override
  bool get isActionEnabled =>
      state.textEditingValue.selection.isValid &&
      !state.textEditingValue.selection.isCollapsed;
}
