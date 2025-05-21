import 'package:fleather/fleather.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide SystemContextMenu;

/// This is a modification of /flutter/lib/src/widgets/system_context_menu.dart
/// which accepts EditorState instead of EditableTextState.
class SystemContextMenu extends StatefulWidget {
  /// Creates an instance of [SystemContextMenu] that points to the given
  /// [anchor].
  const SystemContextMenu._({
    super.key,
    required this.anchor,
    required this.items,
    this.onSystemHide,
  });

  /// Creates an instance of [SystemContextMenu] for the field indicated by the
  /// given [EditorState].
  factory SystemContextMenu.editor({
    Key? key,
    required EditorState editorState,
    List<IOSSystemContextMenuItem>? items,
  }) {
    final (
      startGlyphHeight: double startGlyphHeight,
      endGlyphHeight: double endGlyphHeight
    ) = editorState.getGlyphHeights();

    return SystemContextMenu._(
      key: key,
      anchor: TextSelectionToolbarAnchors.getSelectionRect(
        editorState.renderEditor,
        startGlyphHeight,
        endGlyphHeight,
        editorState.renderEditor.getEndpointsForSelection(
          editorState.textEditingValue.selection,
        ),
      ),
      items: items ?? getDefaultItems(editorState),
      onSystemHide: editorState.hideToolbar,
    );
  }

  /// The [Rect] that the context menu should point to.
  final Rect anchor;

  /// A list of the items to be displayed in the system context menu.
  ///
  /// When passed, items will be shown regardless of the state of text input.
  /// For example, [IOSSystemContextMenuItemCopy] will produce a copy button
  /// even when there is no selection to copy. Use [EditableTextState] and/or
  /// the result of [getDefaultItems] to add and remove items based on the state
  /// of the input.
  ///
  /// Defaults to the result of [getDefaultItems].
  final List<IOSSystemContextMenuItem> items;

  /// Called when the system hides this context menu.
  ///
  /// For example, tapping outside of the context menu typically causes the
  /// system to hide the menu.
  ///
  /// This is not called when showing a new system context menu causes another
  /// to be hidden.
  final VoidCallback? onSystemHide;

  /// Whether the current device supports showing the system context menu.
  ///
  /// Currently, this is only supported on newer versions of iOS.
  static bool isSupported(BuildContext context) {
    return MediaQuery.maybeSupportsShowingSystemContextMenu(context) ?? false;
  }

  /// The default [items] for the given [EditableTextState].
  ///
  /// For example, [IOSSystemContextMenuItemCopy] will only be included when the
  /// field represented by the [EditableTextState] has a selection.
  ///
  /// See also:
  ///
  ///  * [EditableTextState.contextMenuButtonItems], which provides the default
  ///    [ContextMenuButtonItem]s for the Flutter-rendered context menu.
  static List<IOSSystemContextMenuItem> getDefaultItems(
      EditorState editorState) {
    return <IOSSystemContextMenuItem>[
      if (editorState.copyEnabled) const IOSSystemContextMenuItemCopy(),
      if (editorState.cutEnabled) const IOSSystemContextMenuItemCut(),
      if (editorState.pasteEnabled) const IOSSystemContextMenuItemPaste(),
      if (editorState.selectAllEnabled)
        const IOSSystemContextMenuItemSelectAll(),
      if (editorState.lookUpEnabled) const IOSSystemContextMenuItemLookUp(),
      if (editorState.searchWebEnabled)
        const IOSSystemContextMenuItemSearchWeb(),
    ];
  }

  @override
  State<SystemContextMenu> createState() => _SystemContextMenuState();
}

class _SystemContextMenuState extends State<SystemContextMenu> {
  late final SystemContextMenuController _systemContextMenuController;

  @override
  void initState() {
    super.initState();
    _systemContextMenuController =
        SystemContextMenuController(onSystemHide: widget.onSystemHide);
  }

  @override
  void dispose() {
    _systemContextMenuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(SystemContextMenu.isSupported(context));

    if (widget.items.isNotEmpty) {
      final WidgetsLocalizations localizations =
          WidgetsLocalizations.of(context);
      final List<IOSSystemContextMenuItemData> itemDatas = widget.items
          .map((IOSSystemContextMenuItem item) => item.getData(localizations))
          .toList();
      _systemContextMenuController.showWithItems(widget.anchor, itemDatas);
    }

    return const SizedBox.shrink();
  }
}
