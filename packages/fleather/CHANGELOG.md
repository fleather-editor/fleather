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
