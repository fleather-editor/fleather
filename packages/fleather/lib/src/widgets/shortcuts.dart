import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parchment/parchment.dart';

import 'editor.dart';

class FleatherShortcuts extends Shortcuts {
  FleatherShortcuts({super.key, required super.child})
      : super(
          shortcuts: _shortcuts,
        );

  static Map<ShortcutActivator, Intent> get _shortcuts {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _defaultShortcuts;
      case TargetPlatform.fuchsia:
        return _defaultShortcuts;
      case TargetPlatform.iOS:
        return _macShortcuts;
      case TargetPlatform.linux:
        return _defaultShortcuts;
      case TargetPlatform.macOS:
        return _macShortcuts;
      case TargetPlatform.windows:
        return _defaultShortcuts;
    }
  }

  static const Map<ShortcutActivator, Intent> _defaultShortcuts =
      <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.keyB, control: true):
        ToggleBoldStyleIntent(),
    SingleActivator(LogicalKeyboardKey.keyI, control: true):
        ToggleItalicStyleIntent(),
    SingleActivator(LogicalKeyboardKey.keyU, control: true):
        ToggleUnderlineStyleIntent(),
  };

  static const Map<ShortcutActivator, Intent> _macShortcuts =
      <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.keyB, meta: true):
        ToggleBoldStyleIntent(),
    SingleActivator(LogicalKeyboardKey.keyI, meta: true):
        ToggleItalicStyleIntent(),
    SingleActivator(LogicalKeyboardKey.keyU, meta: true):
        ToggleUnderlineStyleIntent(),
  };
}

class ToggleBoldStyleIntent extends Intent {
  const ToggleBoldStyleIntent();
}

class ToggleItalicStyleIntent extends Intent {
  const ToggleItalicStyleIntent();
}

class ToggleUnderlineStyleIntent extends Intent {
  const ToggleUnderlineStyleIntent();
}

class FleatherActions extends Actions {
  FleatherActions({
    super.key,
    required super.child,
  }) : super(
          actions: _shortcutsActions,
        );

  static final Map<Type, Action<Intent>> _shortcutsActions =
      <Type, Action<Intent>>{
    ToggleBoldStyleIntent: _ToggleInlineStyleAction(ParchmentAttribute.bold),
    ToggleItalicStyleIntent:
        _ToggleInlineStyleAction(ParchmentAttribute.italic),
    ToggleUnderlineStyleIntent:
        _ToggleInlineStyleAction(ParchmentAttribute.underline),
  };
}

class _ToggleInlineStyleAction extends ContextAction<Intent> {
  final ParchmentAttribute attribute;

  _ToggleInlineStyleAction(this.attribute);

  @override
  Object? invoke(Intent intent, [BuildContext? context]) {
    final editorState = context!.findAncestorStateOfType<RawEditorState>()!;
    final style = editorState.controller.getSelectionStyle();
    final actualAttr =
        style.containsSame(attribute) ? attribute.unset : attribute;
    editorState.controller.formatSelection(actualAttr);
    return null;
  }
}
