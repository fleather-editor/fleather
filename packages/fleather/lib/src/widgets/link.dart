import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:parchment/parchment.dart';

import '../../l10n/l10n.dart';

/// List of possible actions returned from [LinkActionPickerDelegate].
enum LinkMenuAction {
  /// Launch the link
  launch,

  /// Copy to clipboard
  copy,

  /// Remove link style attribute
  remove,

  /// No-op
  none,
}

/// Used internally by Fleather widget layer.
typedef LinkActionPicker = Future<LinkMenuAction> Function(Node linkNode);

typedef LinkActionPickerDelegate = Future<LinkMenuAction> Function(
    BuildContext context, String link);

Future<LinkMenuAction> defaultLinkActionPickerDelegate(
    BuildContext context, String link) async {
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return _showCupertinoLinkMenu(context, link);
    case TargetPlatform.android:
      return _showMaterialMenu(context, link);
    default:
      assert(false,
          'defaultShowLinkActionsMenu not supposed to be invoked for $defaultTargetPlatform');
      return LinkMenuAction.none;
  }
}

Future<LinkMenuAction> _showCupertinoLinkMenu(
  BuildContext context,
  String link,
) async {
  final result = await showCupertinoModalPopup<LinkMenuAction>(
    context: context,
    builder: (context) {
      return CupertinoActionSheet(
        title: Text(link),
        actions: [
          _CupertinoAction(
            title: context.l.linkDialogOpen,
            icon: Icons.language_sharp,
            onPressed: () => Navigator.of(context).pop(LinkMenuAction.launch),
          ),
          _CupertinoAction(
            title: context.l.linkDialogCopy,
            icon: Icons.copy_sharp,
            onPressed: () => Navigator.of(context).pop(LinkMenuAction.copy),
          ),
          _CupertinoAction(
            title: context.l.linkDialogRemove,
            icon: Icons.link_off_sharp,
            onPressed: () => Navigator.of(context).pop(LinkMenuAction.remove),
          ),
        ],
      );
    },
  );
  return result ?? LinkMenuAction.none;
}

class _CupertinoAction extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onPressed;

  const _CupertinoAction({
    required this.title,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CupertinoActionSheetAction(
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.start,
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            ),
            Icon(
              icon,
              size: theme.iconTheme.size,
              color: theme.colorScheme.onSurface.withOpacity(0.75),
            )
          ],
        ),
      ),
    );
  }
}

Future<LinkMenuAction> _showMaterialMenu(
  BuildContext context,
  String link,
) async {
  final result = await showModalBottomSheet<LinkMenuAction>(
    clipBehavior: Clip.hardEdge,
    context: context,
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MaterialAction(
              title: context.l.linkDialogOpen,
              icon: Icons.language_sharp,
              onPressed: () => Navigator.of(context).pop(LinkMenuAction.launch),
            ),
            _MaterialAction(
              title: context.l.linkDialogCopy,
              icon: Icons.copy_sharp,
              onPressed: () => Navigator.of(context).pop(LinkMenuAction.copy),
            ),
            _MaterialAction(
              title: context.l.linkDialogRemove,
              icon: Icons.link_off_sharp,
              onPressed: () => Navigator.of(context).pop(LinkMenuAction.remove),
            ),
          ],
        ),
      );
    },
  );

  return result ?? LinkMenuAction.none;
}

class _MaterialAction extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onPressed;

  const _MaterialAction({
    required this.title,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(
        icon,
        size: theme.iconTheme.size,
        color: theme.colorScheme.onSurface.withOpacity(0.75),
      ),
      title: Text(title),
      onTap: onPressed,
    );
  }
}
