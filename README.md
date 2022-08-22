[![Fleather & Parchment](https://github.com/fleather-editor/fleather/actions/workflows/fleather.yml/badge.svg)](https://github.com/fleather-editor/fleather/actions/workflows/fleather.yml)
[![codecov](https://codecov.io/gh/fleather-editor/fleather/branch/master/graph/badge.svg?token=JRNFZ218FY)](https://codecov.io/gh/fleather-editor/fleather)

# About Fleather

<!-- [![Build Status](https://travis-ci.com/memspace/zefyr.svg?branch=master)](https://travis-ci.com/memspace/zefyr) [![codecov](https://codecov.io/gh/memspace/zefyr/branch/master/graph/badge.svg)](https://codecov.io/gh/memspace/zefyr) -->

*Soft and gentle rich text editing for Flutter applications based on [Zefyr](https://github.com/memspace/zefyr).*

## Clean and modern look

Fleather's rich text editor is built with simplicity and flexibility in
mind. It provides clean interface for distraction-free editing. Think
Medium.com-like experience.

[comment]: <> (<img src="https://github.com/fleather-editor/fleather/raw/master/assets/zefyr-1.png" width="375"> <img src="https://github.com/fleather-editor/fleather/raw/master/assets/zefyr-2.png" width="375">)

## Markdown-inspired semantics

Ever needed to have a heading line inside of a quote block, like in
this Markdown block:

> ### I'm a Markdown heading
> And I'm a regular paragraph

Fleather can deliver exactly that.

[comment]: <> (<img src="https://github.com/fleather-editor/fleather/raw/master/assets/markdown-semantics.png" width="375">)


## Ready for collaborative editing

Fleather's document model uses data format compatible with
[Operational Transformation][ot] which makes it possible to use for
collaborative editing use cases or whenever there is a need for
conflict-free resolution of changes.

> Fleather editor uses Quill.js **Delta** as underlying data format. Read
> more about Fleather and Deltas in our [documentation](doc/concepts/data-and-document.md).
> Make sure to checkout [official documentation][delta] for Delta format
> as well.

[delta]: https://quilljs.com/docs/delta/
[ot]: https://en.wikipedia.org/wiki/Operational_transformation
