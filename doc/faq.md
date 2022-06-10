## Frequently asked questions

### Q: Are Parchment documents compatible with Quill documents?

Short answer is no. Even though Parchment uses Quill Delta as underlying
representation for its documents there are at least differences in
attribute declarations. For instance heading style in Quill
editor uses "header" as the attribute key, in Parchment it's "heading".

There are also semantic differences. In Quill, both list and heading
styles are treated as block styles. This means applying "heading"
style to a list item removes the item from the list. In Parchment, heading
style is handled separately from block styles like lists and quotes.
As a consequence you can have a heading line inside of a quote block.
This is intentional and inspired by how Markdown handles such scenarios.
In fact, Parchment format tries to follow Markdown semantics as close as
possible.
