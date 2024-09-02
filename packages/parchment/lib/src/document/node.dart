import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:parchment_delta/parchment_delta.dart';

import 'attributes.dart';
import 'line.dart';

/// An abstract node in a document tree.
///
/// Represents a segment of a Parchment document with specified [offset]
/// and [length].
///
/// The [offset] property is relative to [parent]. See also [documentOffset]
/// which provides absolute offset of this node within the document.
///
/// The current parent node is exposed by the [parent] property. A node is
/// considered [mounted] when the [parent] property is not `null`.
abstract base class Node extends LinkedListEntry<Node> {
  /// Current parent of this node. May be null if this node is not mounted.
  ContainerNode? get parent => _parent;
  ContainerNode? _parent;

  /// Returns `true` if this node is the first node in the [parent] list.
  bool get isFirst => list!.first == this;

  /// Returns `true` if this node is the last node in the [parent] list.
  bool get isLast => list!.last == this;

  /// Length of this node in characters.
  int get length;

  /// Returns `true` if this node is currently mounted, e.g. [parent] is not
  /// `null`.
  bool get mounted => _parent != null;

  int? _offsetCache;

  /// Offset in characters of this node relative to [parent] node.
  ///
  /// To get offset of this node in the document see [documentOffset].
  int get offset {
    if (_offsetCache != null) return _offsetCache!;

    if (isFirst) return _offsetCache = 0;
    var offset = 0;
    var node = this;
    do {
      node = node.previous!;
      offset += node.length;
    } while (!node.isFirst);
    return _offsetCache = offset;
  }

  int? _documentOffsetCache;

  /// Offset in characters of this node in the document.
  int get documentOffset {
    if (_documentOffsetCache != null) return _documentOffsetCache!;

    final parentOffset = (_parent is! RootNode) ? _parent!.documentOffset : 0;
    return _documentOffsetCache = parentOffset + offset;
  }

  /// Returns `true` if this node contains character at specified [offset] in
  /// the document.
  bool containsOffset(int offset) {
    final o = documentOffset;
    return o <= offset && offset < o + length;
  }

  /// Optimize this node within [parent].
  ///
  /// Subclasses should override this method to perform necessary optimizations.
  void optimize();

  /// Returns [Delta] representation of this node.
  Delta toDelta();

  /// Returns plain-text representation of this node.
  String toPlainText();

  /// Insert [data] at specified character [index] with style [style].
  void insert(int index, Object data, ParchmentStyle? style);

  /// Format [length] characters of this node starting from [index] with
  /// specified style [style].
  void retain(int index, int length, ParchmentStyle? style);

  /// Delete [length] characters of this node starting from [index].
  void delete(int index, int length);

  @override
  void insertBefore(Node entry) {
    assert(entry._parent == null && _parent != null);
    entry._parent = _parent;
    super.insertBefore(entry);
    _parent?.invalidateLength();
    invalidateOffset();
  }

  @override
  void insertAfter(Node entry) {
    assert(entry._parent == null && _parent != null);
    entry._parent = _parent;
    super.insertAfter(entry);
    parent?.invalidateLength();
    entry.invalidateOffset();
  }

  @override
  void unlink() {
    assert(_parent != null);
    final oldParent = _parent;
    final oldNext = next;
    _parent = null;
    super.unlink();
    oldNext?.invalidateOffset();
    oldParent?.invalidateLength();
  }

  @mustCallSuper
  void invalidateOffset() {
    _offsetCache = null;
    invalidateDocumentOffset();
    next?.invalidateOffset();
  }

  @mustCallSuper
  void invalidateDocumentOffset() {
    _documentOffsetCache = null;
  }
}

/// Result of a child lookup in a [ContainerNode].
class LookupResult {
  /// The child node if found, otherwise `null`.
  final Node? node;

  /// Starting offset within the child [node] which points at the same
  /// character in the document as the original offset passed to
  /// [ContainerNode.lookup] method.
  final int offset;

  LookupResult(this.node, this.offset);

  /// Returns `true` if there is no child node found, e.g. [node] is `null`.
  bool get isEmpty => node == null;

  /// Returns `true` [node] is not `null`.
  bool get isNotEmpty => node != null;
}

/// Container node can accommodate other nodes.
///
/// Delegates insert, retain and delete operations to children nodes. For each
/// operation container looks for a child at specified index position and
/// forwards operation to that child.
///
/// Most of the operation handling logic is implemented by [LineNode] and
/// [TextNode].
abstract base class ContainerNode<T extends Node> extends Node {
  final LinkedList<Node> _children = LinkedList<Node>();

  /// List of children.
  LinkedList<Node> get children => _children;

  /// Returns total number of child nodes in this container.
  ///
  /// To get text length of this container see [length].
  int get childCount => _children.length;

  /// Returns the first child [Node].
  Node get first => _children.first;

  /// Returns the last child [Node].
  Node get last => _children.last;

  /// Returns an instance of default child for this container node.
  ///
  /// Always returns fresh instance.
  T get defaultChild;

  /// Returns `true` if this container has no child nodes.
  bool get isEmpty => _children.isEmpty;

  /// Returns `true` if this container has at least 1 child.
  bool get isNotEmpty => _children.isNotEmpty;

  /// Adds [node] to the end of this container children list.
  void add(T node) {
    assert(node._parent == null);
    node._parent = this;
    _children.add(node);
    node.invalidateOffset();
    invalidateLength();
  }

  /// Adds [node] to the beginning of this container children list.
  void addFirst(T node) {
    assert(node._parent == null);
    node._parent = this;
    _children.addFirst(node);
    node.invalidateOffset();
    invalidateLength();
  }

  /// Removes [node] from this container.
  void remove(T node) {
    assert(node._parent == this);
    node._parent = null;
    final oldNext = node.next;
    final removed = _children.remove(node);
    if (removed) {
      invalidateLength();
      oldNext?.invalidateOffset();
    }
  }

  /// Moves children of this node to [newParent].
  void moveChildren(ContainerNode newParent) {
    if (isEmpty) return;
    var toBeOptimized = newParent.isEmpty ? null : newParent.last;
    while (isNotEmpty) {
      var child = first;
      child.unlink();
      newParent.add(child);
    }

    /// In case [newParent] already had children we need to make sure
    /// combined list is optimized.
    if (toBeOptimized != null) toBeOptimized.optimize();
  }

  /// Looks up a child [Node] at specified character [offset] in this container.
  ///
  /// Returns [LookupResult]. The result may contain found node or `null` if
  /// no node is found at specified offset.
  ///
  /// [LookupResult.offset] is set to relative offset within returned child node
  /// which points at the same character position in the document as the
  /// original [offset].
  LookupResult lookup(int offset, {bool inclusive = false}) {
    assert(offset >= 0 && offset <= length);

    for (final node in children) {
      final length = node.length;
      if (offset < length || (inclusive && offset == length && (node.isLast))) {
        return LookupResult(node, offset);
      }
      offset -= length;
    }
    return LookupResult(null, 0);
  }

  //
  // Overridden members
  //

  @override
  String toPlainText() => children.map((child) => child.toPlainText()).join();

  int? _length;

  /// Content length of this node's children. To get number of children in this
  /// node use [childCount].
  @override
  int get length => _length ??=
      _children.fold<int>(0, (current, node) => current + node.length);

  @override
  void insert(int index, Object data, ParchmentStyle? style) {
    assert(index == 0 || (index > 0 && index < length));

    if (isEmpty) {
      assert(index == 0);
      final node = defaultChild;
      add(node);
      node.insert(index, data, style);
    } else {
      final result = lookup(index);
      result.node!.insert(result.offset, data, style);
    }
  }

  @override
  void retain(int index, int length, ParchmentStyle? style) {
    assert(isNotEmpty);
    final res = lookup(index);
    res.node!.retain(res.offset, length, style);
  }

  @override
  void delete(int index, int length) {
    assert(isNotEmpty);
    final res = lookup(index);
    res.node!.delete(res.offset, length);
  }

  @override
  String toString() => _children.join('\n');

  @override
  void invalidateDocumentOffset() {
    super.invalidateDocumentOffset();
    for (var child in children) {
      child.invalidateDocumentOffset();
    }
  }

  void invalidateLength() {
    _length = null;
    next?.invalidateOffset();
    parent?.invalidateLength();
  }
}

/// Mixin used by nodes that wish to implement [StyledNode] interface.
base mixin StyledNode on Node {
  ParchmentStyle get style => _style;
  ParchmentStyle _style = ParchmentStyle();

  /// Applies style [attribute] to this node.
  void applyAttribute(ParchmentAttribute attribute) {
    _style = _style.merge(attribute);
  }

  /// Applies new style [value] to this node. Provided [value] is merged
  /// into current style.
  void applyStyle(ParchmentStyle value) {
    _style = _style.mergeAll(value);
  }

  /// Clears style of this node.
  void clearStyle() {
    _style = ParchmentStyle();
  }
}

/// Root node of document tree.
base class RootNode extends ContainerNode<ContainerNode<Node>> {
  @override
  ContainerNode<Node> get defaultChild => LineNode();

  @override
  void optimize() {/* no-op */}

  @override
  Delta toDelta() => children
      .map((child) => child.toDelta())
      .fold(Delta(), (a, b) => a.concat(b));
}
