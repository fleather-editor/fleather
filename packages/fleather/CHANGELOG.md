##  1.26.0

- Editor and cursor brought into viewport if is wrapped with a scrollable regardless of it's `scrollable` property 
- [Fix] incorrect width when using TextWidthBasis.longestLine with multiple lines
- [Fix] exception thrown when editor starts with an element that do not compute distance to actual baseline

##  1.25.1

- [Fix] Empty line height greater than non-empty line height

##  1.25.0

- Upgrade to Flutter 3.35
- Add attributes to images
- Support `TextWidthBasis.longestLine`
- Support custom `StrutStyle`
- Built-in emoji shortcuts
- [Fix] Corrupted cursor position when deleting blocks
- [Fix] Error when using multi-level lists of different nature

## 1.24.0+1

* Use Flutter context menu when read-only on iOS
* Add translations for Hungarian
* [Fix] `merge` method not applying horizontal rule theme data
* [Fix] regex for ul in Markdown decoder

## 1.23.0

* Use system context menu on iOS
* Upgrade to Flutter 3.32.0

## 1.22.0

* `tab` (resp. `shift+ tab`) indents (resp. un-indents) line
* `AutoExitRule` un-indents lists
* iOS selection improvements
* [Fix] iOS floating cursor wrongly position when editor has padding

## 1.21.0

* Add Portuguese & Brazilian Portuguese support
* Add Korean support
* Upgrade to Flutter 3.29
* `contextMenuBuilder` can be overridden
* [Fix] Inappropriate leading numbers in code block
* [Fix] Theme not being applied to checklist

## 1.20.1

* [Fix] markdown decoder not recognizing all ul tokens
* [Fix] scroll jumps when toggling checkbox
* [Fix] null check on null value error in _onChangedClipboardStatus

## 1.20.0

* Upgrade to Flutter 3.27
* Add translations for Dutch and German

## 1.19.0

* Improve performance when handling long documents
* Add translations for Persian
* Ability to cherrypick autoformats natively available
* Add support for indentation in blocks in Markdow codec
* [Fix] Autoformat cannot be undone on iOS

## 1.18.0

* Add the ability to use custom `TextSelectionControls`
* Add foundations for localization
* Add translations for French
* Add clear method on controller
* Improve performance by using repaint boundary
* Fix hit test issue when scrolled
* Fix copy issue when selection is inverted

## 1.17.0

* Fleather manages the viewport
* Add ability to provide custom clipboard status notifier
* Fix editor requests keyboard and focus when checklist toggled

Behavior for `scrollable` and `expand` changed. Check https://github.com/fleather-editor/fleather/pull/338#issuecomment-2212484545;

## 1.16.0

* Inline Markdown shortcuts
* Enable auto-correct on mobile devices
* Enable suggestions on Android devices
* [UI change] Adjust default theme
* [Fix] selectors in toolbar going under keyboard

## 1.15.0+1

* Upgrade to Flutter 3.22
* Remove selection gestures when enableInteractiveSelection is `false`
* Upgrade dependencies

## 1.14.5+1

* [Fix] toolbar moving out of viewport upon scrolling
* [Fix] list number using the wrong theme
* [Fix] link bottom sheet UI issues
* [Fix] toolbar selector positioning
* [Fix] scroll to cursor when cursor is bigger than viewport

## 1.14.4

* [Fix] selection handles not disposed after disposing selection overlay
* [Fix] wrong selection after pasting
* [Fix] multiple cursor on editor after selecting Android keyboard suggestion  
* [Fix] FleatherThemeData.merge not applying heading 6 theme
* [Fix] get selection style for beginning of new line
* [Fix] sending invalid composing range to engine

## 1.14.3

* Hide collapsed selection handle in read-only mode
* Hide text selection highlight when editor is unfocused
* Scroll to selection after keyboard opened

## 1.14.2

* Update selection correctly after pasting text
* Make color attributes toggleable
* Revert "Use normalized text editing value for updating remote value"

## 1.14.1

* Use normalized text editing value for updating remote value
* Expose `SelectorScope`
* Remove `dart:io` usages
* Relax `intl` version

## 1.14.0+1

* Add `ClipboardManager` which can be used to implement rich clipboard
* Use overlay entries to prevent focus loss when selection color or heading in default toolbar
* Replace quill_delta package with parchment_delta
* [Fix] Caret movement issues
* [Fix] Caret painting on focus gain

## 1.13.2

* [Fix] pub.dev issues

## 1.13.1

* Example enriched with ImagePicker
* [Fix] web - erratic cursor positioning when navigating document with keyboard
* [Fix] Persistent context menu when updating `FleatherEditor` widget
* [Fix] pub.dev warnings - dependencies upgraded

## 1.13.0

* Enhanced text selection experience on mobile (including magnifier)
* [Fix] Vertical cursor movements have incorrect behavior when initiated from a line with large embeds

## 1.12.0

* Introduce AutoFormats to handle automatic text formatting and make Heuristics only responsible for validity of document
* Show context menu on desktop
* Add unset background and text color option
* Handle more text editing intents (See #180 for the list)
* [Fix] toolbar button design
* [Fix] preserve line style on new line
* [Fix] example app build for Android

## 1.11.0 

* Support for Flutter 3.16
* [Fix] exception thrown when inserting new line with toggled inline styles

## 1.10.0 

* Support for Flutter 3.13
  
## 1.9.1

* [Fix] light theme inline code background color for Material 3
* [Fix] wrong bounding box for text lines in block
* [Fix] alignment and direction in blocks

## 1.9.0

* Migrated to Dart 3
* Support for foreground color & heading levels 1 to 6
* [Fix] Incorrect `ParchmentStyle` returned by controller at start of line

## 1.8.0

* Support for Flutter 3.10
* [Fix] Checkbox alignment
* [Fix] Assertion error when merging two blocks by removing line between them

## 1.7.0

* Adaptive selection controls for platforms

## 1.6.0

* Allow to undo/redo changes from toolbar
* Remove use of deprecated ToolbarOptions
* [Fix] Wrong context toolbar positioning
* [Fix] Last separated character selection on iOS
* [Fix] Hide selection handles when text changes

## 1.5.0

* [Fix] Ensure that text boxes are only the required size
* [Fix] History not working when widget updated 
* Support Flutter v3.7
* Support `TextEditingDelta` handling

## 1.4.0

* Keyboard appearance depends on default brightness
* [Fix] Line height accounts for `SpanEmbed` height
* [Fix] Editor toolbar UI

## 1.3.1

* [Fix] Incorrect style behaviour when toggling formats

## 1.3.0

* Support document history (undo/redo)
* Updated README
* [Fix] Cursor not appearing when setting focus on empty document

## 1.2.2

* New example for Fleather
* Improve checkbox design
* [Fix] new line after inline embed insertion
* [Fix] null focusNode causing _CastError

## 1.2.1

* [Fix] toolbar not showing up on empty documents

## 1.2.0

* Add support for inline embeds
* Add support for background color
* [Fix] toolbar not always showing up

## 1.1.0

* Added support for indentation
* Added ability to determine text direction and alignment based on input

## 1.0.0

* Initial release.
