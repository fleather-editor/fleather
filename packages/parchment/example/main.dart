import 'package:parchment/parchment.dart';

void main() {
  final doc = ParchmentDocument();
  // Modify this document with insert, delete and format operations
  doc.insert(0,
      'Parchment package provides rich text document model for Fleather editor');
  doc.format(0, 5, ParchmentAttribute.bold); // Makes first word bold.
  doc.format(0, 0, ParchmentAttribute.h1); // Makes first line a heading.
  doc.delete(23, 10); // Deletes "rich text " segment.

  // Collects style attributes at 1 character in this document.
  doc.collectStyle(1, 0); // returned style would include "bold" and "h1".

  // Listen to all changes applied to this document.
  doc.changes.listen((change) {
    print(change);
  });

  // Dispose resources allocated by this document, e.g. closes "changes" stream.
  // After document is closed it cannot be modified.
  doc.close();
}
