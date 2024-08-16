## 1.18.0

* Expose `parchment_delta` by Parchment

## 1.15.0

* Add support for decoding indentation, <hr>, and <img> in HTML codec 
* Add support for checkbox in Markdown codec
* [Fix] decoding Markdown with multiple links
* Upgrade dependencies

## 1.14.0

* Replace quill_delta package with parchment_delta

## 1.13.0

* Upgrade dependencies

## 1.12.0

* Introduce AutoFormats to handle automatic text formatting and make Heuristics only responsible for validity of document
* [Fix] preserve line style on new line

## 1.11.0

* Add support for strike-through in Markdown codec
* [Fix] HTML encoder for tangled inline tags

## 1.9.0

* Migrated to Dart 3
* New foreground color attribute - `fg`
* HTML codec handles backgound color & foreground color
* Added eading attribute levels 3 to 6

## 1.8.0

* Upgrade to intl 0.18.0

## 1.7.0

* [Breaking Change] Change codecs to accept ParchmentDocument instead of Delta
* [Fix] Blocks serialization/deserialization issues in markdown codec

## 1.6.0

* Allow to undo/redo changes from toolbar

## 1.5.0

* Format link after hitting newline

## 1.4.0

* Support modifying document rules
* [Fix] HTML codec fixes

## 1.3.1

* HTML codec
* Markdown codec

## 1.2.1

* [Fix] new line after inline embed insertion

## 1.2.0

* Support for background color
* Added support for inline embeds

## 1.1.0

* Added indent attribute
* Added AutoTextDirection heuristic

## 1.0.0

* Initial release
