import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FleatherPressedKeys extends ChangeNotifier {
  static FleatherPressedKeys of(BuildContext context) {
    final widget = context
        .dependOnInheritedWidgetOfExactType<_FleatherPressedKeysAccess>();
    return widget!.pressedKeys;
  }

  bool _metaPressed = false;
  bool _controlPressed = false;

  /// Whether meta key is currently pressed.
  bool get metaPressed => _metaPressed;

  /// Whether control key is currently pressed.
  bool get controlPressed => _controlPressed;

  void _updatePressedKeys(Set<LogicalKeyboardKey> pressedKeys) {
    final meta = pressedKeys.contains(LogicalKeyboardKey.metaLeft) ||
        pressedKeys.contains(LogicalKeyboardKey.metaRight);
    final control = pressedKeys.contains(LogicalKeyboardKey.controlLeft) ||
        pressedKeys.contains(LogicalKeyboardKey.controlRight);
    if (_metaPressed != meta || _controlPressed != control) {
      _metaPressed = meta;
      _controlPressed = control;
      notifyListeners();
    }
  }
}

class FleatherKeyboardListener extends StatefulWidget {
  final Widget child;
  const FleatherKeyboardListener({super.key, required this.child});

  @override
  FleatherKeyboardListenerState createState() =>
      FleatherKeyboardListenerState();
}

class FleatherKeyboardListenerState extends State<FleatherKeyboardListener> {
  final FleatherPressedKeys _pressedKeys = FleatherPressedKeys();

  bool _keyEvent(KeyEvent event) {
    _pressedKeys
        ._updatePressedKeys(HardwareKeyboard.instance.logicalKeysPressed);
    return false;
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_keyEvent);
    _pressedKeys
        ._updatePressedKeys(HardwareKeyboard.instance.logicalKeysPressed);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_keyEvent);
    _pressedKeys.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FleatherPressedKeysAccess(
      pressedKeys: _pressedKeys,
      child: widget.child,
    );
  }
}

class _FleatherPressedKeysAccess extends InheritedWidget {
  final FleatherPressedKeys pressedKeys;
  const _FleatherPressedKeysAccess({
    required this.pressedKeys,
    required super.child,
  });

  @override
  bool updateShouldNotify(covariant _FleatherPressedKeysAccess oldWidget) {
    return oldWidget.pressedKeys != pressedKeys;
  }
}
