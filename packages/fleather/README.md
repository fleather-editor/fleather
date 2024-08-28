[![Fleather & Parchment](https://github.com/fleather-editor/fleather/actions/workflows/fleather.yml/badge.svg)](https://github.com/fleather-editor/fleather/actions/workflows/fleather.yml)
[![codecov](https://codecov.io/gh/fleather-editor/fleather/branch/master/graph/badge.svg?token=JRNFZ218FY)](https://codecov.io/gh/fleather-editor/fleather)
[![pub package](https://img.shields.io/pub/v/fleather.svg)](https://pub.dartlang.org/packages/fleather)

# Fleather
![banner](https://github.com/fleather-editor/fleather/raw/master/packages/fleather/images/banner.png)
Soft and gentle rich text editing for Flutter applications based on [Zefyr](https://github.com/memspace/zefyr). It uses a document model named [Parchment](https://github.com/fleather-editor/fleather/tree/master/packages/parchment) based on [Notus](https://github.com/memspace/zefyr/tree/master/packages/notus).

<img src="https://github.com/fleather-editor/fleather/raw/master/packages/fleather/images/screenshot.png" width="600">

**👉 Live demo [here](https://fleather-editor.github.io/demo).**

## Features
* Works on Android, iOS, Web, macOS, Linux and Windows
* Inline attributes like **bold**, *italic*, ~~strikethrough~~ and etc.
* Line attributes like direction, alignment, heading, number and bullet list and etc.
* Block attributes like code, quote and etc.
* Supports inline and block embeds
* Markdown-inspired semantics
* Supports markdown shortcuts
* Using [Quill.js Delta](https://quilljs.com/docs/delta) as underlying data format by [Parchment](packages/parchment/README.md), Fleather is ready for collaborative editing using [OT](https://en.wikipedia.org/wiki/Operational_transformation) (Not provided as a built-in functionality)

**Full documentation can be found [here](https://fleather-editor.github.io/docs/getting-started/quick-start/).**

## Get started
Add Fleather to your dependencies.
```yaml
dependencies:
  flutter:
    sdk: flutter
  fleather: ^1.18.0
```

## Usage
**For a complete working project using Fleather, check our [example](https://github.com/fleather-editor/fleather/blob/master/packages/fleather/example/lib/main.dart).**

1. Create a `FleatherController`
```dart
document = ParchmentDocument.fromJson(json);
controller = FleatherController(document);
```
2. Add `FleatherEditor` or `FleatherField` with a `FleatherToolbar` to your widgets.
```dart
Column(
  children: [
    FleatherToolbar.basic(controller: _controller!),
    Expanded(
      child: FleatherEditor(controller: controller),
    ),
    //or
    FleatherField(controller: controller)
  ],
),
```

## Migration
For migration guides check out [MIGRATION.md](https://github.com/fleather-editor/fleather/blob/master/MIGRATION.md).

## Credits

* [Zefyr](https://github.com/memspace/zefyr) contributors
* [Mohammadreza Ziadzadeh](https://github.com/moharnadreza) for banner
