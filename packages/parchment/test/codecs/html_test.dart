import 'package:parchment/parchment.dart';
import 'package:parchment/src/codecs/html.dart';
import 'package:test/test.dart';

void main() {
  final codec = ParchmentHtmlCodec();

  group('Encode', () {
    group('Basic text', () {
      test('only two lines', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': '\n\n'},
        ]);
        expect(codec.encode(doc), '<p><br></p><p></p>');
      });

      test('plain text', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Something in the way mmmm...\n'}
        ]);
        expect(codec.encode(doc), 'Something in the way mmmm...');
      });

      test('bold text', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Something '},
          {
            'insert': 'in the way',
            'attributes': {'b': true}
          },
          {'insert': ' mmmm...\n'}
        ]);
        expect(
            codec.encode(doc), 'Something <strong>in the way</strong> mmmm...');
      });

      test('background color', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Something '},
          {
            'insert': 'in the way',
            'attributes': {'bg': 0xFFFF0000}
          },
          {'insert': ' mmmm...\n'}
        ]);
        expect(codec.encode(doc),
            'Something <span style="background-color: rgba(255,0,0,1.0)">in the way</span> mmmm...');
      });

      test('text color', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Something '},
          {
            'insert': 'in the way',
            'attributes': {'fg': 0xFFFF0000}
          },
          {'insert': ' mmmm...\n'}
        ]);
        expect(codec.encode(doc),
            'Something <span style="color: rgba(255,0,0,1.0)">in the way</span> mmmm...');
      });

      test('italic + code + underlined + strikethrough text', () {
        final doc = ParchmentDocument.fromJson([
          {
            'insert': 'Something ',
            'attributes': {'s': true, 'u': true}
          },
          {
            'insert': 'in the way',
            'attributes': {'i': true}
          },
          {
            'insert': ' mmmm...',
            'attributes': {'c': true}
          },
          {'insert': '\n'}
        ]);
        expect(codec.encode(doc),
            '<del><u>Something </u></del><em>in the way</em><code> mmmm...</code>');
      });

      test('embedded inline attributes text', () {
        final doc = ParchmentDocument.fromJson([
          {
            'insert': 'Something ',
            'attributes': {'a': 'https://wikipedia.org', 'u': true}
          },
          {
            'insert': 'in the way',
            'attributes': {'i': true, 'u': true}
          },
          {
            'insert': ' mmmm...',
            'attributes': {'u': true}
          },
          {'insert': '\n'}
        ]);
        expect(codec.encode(doc),
            '<u><a href="https://wikipedia.org">Something </a><em>in the way</em> mmmm...</u>');
      });

      test('tangled inline tags', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'AAA'},
          {
            'insert': 'BB',
            'attributes': {'b': true}
          },
          {
            'insert': 'B',
            'attributes': {'b': true, 's': true}
          },
          {
            'insert': 'CCC',
            'attributes': {'s': true}
          },
          {'insert': '\n'}
        ]);
        expect(codec.encode(doc),
            'AAA<strong>BB<del>B</del></strong><del>CCC</del>');
      });

      test('html escaping', () {
        final doc = ParchmentDocument.fromJson([
          {
            'insert':
                'HTML special characters like < > & are escaped, but not \' " /.\n',
          },
        ]);
        expect(codec.encode(doc),
            'HTML special characters like &lt; &gt; &amp; are escaped, but not \' " /.');
      });

      test('multiple line breaks in a row should render as actual line breaks',
          () {
        // This has three blank lines between the Line 1/Line2 pair.
        // The Line3/Line4 pair does not have blank lines, but both pairs should render to the
        // same height. The Line5/Line6 pair has 3 blank lines but also were emboldened in Fleather.
        // The blank line after Line5 has a space in it just to distinguish it from a completely
        // blank line.
        final doc = ParchmentDocument.fromJson([
          {
            'insert':
                'Line 1\n\n\n\nLine 2\nLine3\nnot blank1\nnot blank2\nnot blank3\nLine 4\n'
          },
          {
            'insert': 'Line 5',
            'attributes': {'b': true}
          },
          {'insert': '\n \n\n\n'},
          {
            'insert': 'Line 6',
            'attributes': {'b': true}
          },
          {'insert': '\n'}
        ]);
        expect(
            codec.encode(doc),
            '<p>Line 1</p>'
            '<p><br></p>'
            '<p><br></p>'
            '<p><br></p>'
            '<p>Line 2</p>'
            '<p>Line3</p>'
            '<p>not blank1</p>'
            '<p>not blank2</p>'
            '<p>not blank3</p>'
            '<p>Line 4</p>'
            '<p><strong>Line 5</strong></p>'
            '<p> <br></p>'
            '<p><br></p>'
            '<p><br></p>'
            '<p><strong>Line 6</strong></p>');
      });

      test('several styled lines in a row', () {
        // Tests that we don't generate nested <p> tags.
        final doc = ParchmentDocument.fromJson([
          {
            'insert': 'Bold',
            'attributes': {'b': true}
          },
          {'insert': '\n'},
          {
            'insert': 'Italic',
            'attributes': {'i': true}
          },
          {'insert': '\n'},
          {
            'insert': 'Bold',
            'attributes': {'b': true}
          },
          {'insert': '\n'},
          {
            'insert': 'Italic',
            'attributes': {'i': true}
          },
          {'insert': '\n'},
          {
            'insert': 'Bold',
            'attributes': {'b': true}
          },
          {'insert': '\n'},
        ]);
        expect(
            codec.encode(doc),
            '<p><strong>Bold</strong></p>'
            '<p><em>Italic</em></p>'
            '<p><strong>Bold</strong></p>'
            '<p><em>Italic</em></p>'
            '<p><strong>Bold</strong></p>');
      });
    });

    group('Headings', () {
      test('1', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'heading': 1}
          },
        ]);

        expect(codec.encode(doc), '<h1>Hello World!</h1>');
      });

      test('2', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'heading': 2}
          }
        ]);

        expect(codec.encode(doc), '<h2>Hello World!</h2>');
      });

      test('3', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'heading': 3}
          }
        ]);

        expect(codec.encode(doc), '<h3>Hello World!</h3>');
      });

      test('4', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'heading': 4}
          }
        ]);

        expect(codec.encode(doc), '<h4>Hello World!</h4>');
      });

      test('5', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'heading': 5}
          }
        ]);

        expect(codec.encode(doc), '<h5>Hello World!</h5>');
      });

      test('6', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'heading': 6}
          }
        ]);

        expect(codec.encode(doc), '<h6>Hello World!</h6>');
      });
    });

    group('Blocks', () {
      group('Paragraph', () {
        test('multiple', () {
          final doc = ParchmentDocument.fromJson([
            {'insert': 'Hello World!\nBye World!\n'},
          ]);
          expect(codec.encode(doc), '<p>Hello World!</p><p>Bye World!</p>');
        });

        test('multiple formatted', () {
          final doc = ParchmentDocument.fromJson([
            {
              'insert': 'Hello World!',
              'attributes': {'b': true}
            },
            {'insert': '\n'},
            {
              'insert': 'Bye World!',
              'attributes': {'b': true}
            },
            {'insert': '\n'}
          ]);
          expect(codec.encode(doc),
              '<p><strong>Hello World!</strong></p><p><strong>Bye World!</strong></p>');
        });
      });

      group('Quote', () {
        test('Single', () {
          final doc = ParchmentDocument.fromJson([
            {'insert': 'Hello World!'},
            {
              'insert': '\n',
              'attributes': {'block': 'quote'}
            }
          ]);

          expect(codec.encode(doc),
              '<blockquote style="margin: 0 0 0 0.8ex; border-left: 1px solid rgb(204, 204, 204); padding-left: 1ex;">Hello World!</blockquote>');
        });

        test('Consecutive with same style', () {
          final doc = ParchmentDocument.fromJson([
            {'insert': 'Hello World!'},
            {
              'insert': '\n',
              'attributes': {'block': 'quote'}
            },
            {'insert': 'Hello World!'},
            {
              'insert': '\n',
              'attributes': {'block': 'quote'}
            }
          ]);

          expect(
              codec.encode(doc),
              '<blockquote style="margin: 0 0 0 0.8ex; border-left: 1px solid rgb(204, 204, 204); padding-left: 1ex;">Hello World!</blockquote>'
              '<blockquote style="margin: 0 0 0 0.8ex; border-left: 1px solid rgb(204, 204, 204); padding-left: 1ex;">Hello World!</blockquote>');
        });

        test('Consecutive with different styles', () {
          final doc = ParchmentDocument.fromJson([
            {'insert': 'Hello World!'},
            {
              'insert': '\n',
              'attributes': {'block': 'quote'}
            },
            {'insert': 'Hello World!'},
            {
              'insert': '\n',
              'attributes': {'block': 'quote', 'alignment': 'center'}
            }
          ]);

          expect(
              codec.encode(doc),
              '<blockquote style="margin: 0 0 0 0.8ex; border-left: 1px solid rgb(204, 204, 204); padding-left: 1ex;">Hello World!</blockquote>'
              '<blockquote style="text-align:center;margin: 0 0 0 0.8ex; border-left: 1px solid rgb(204, 204, 204); padding-left: 1ex;">Hello World!</blockquote>');
        });
      });

      test('Code', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'void main() {'},
          {
            'insert': '\n\n',
            'attributes': {'block': 'code'}
          },
          {'insert': '  print("Hello World!");'},
          {
            'insert': '\n',
            'attributes': {'block': 'code'}
          },
          {'insert': '}'},
          {
            'insert': '\n',
            'attributes': {'block': 'code'}
          }
        ]);

        expect(
          codec.encode(doc),
          '<pre><code>void main() {\n'
          '\n'
          '  print("Hello World!");\n'
          '}\n'
          '</code></pre>',
        );
      });

      test('Code then paragraph', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'some code'},
          {
            'insert': '\n',
            'attributes': {'block': 'code'}
          },
          {'insert': 'Hello world\n'},
        ]);
        expect(
          codec.encode(doc),
          '<pre><code>some code\n'
          '</code></pre><p>Hello world</p>',
        );
      });

      test('Code then bold paragraph', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'some code'},
          {
            'insert': '\n',
            'attributes': {'block': 'code'}
          },
          {
            'insert': 'Hello world',
            'attributes': {'b': true}
          },
          {'insert': '\n'}
        ]);
        expect(
          codec.encode(doc),
          '<pre><code>some code\n'
          '</code></pre><p><strong>Hello world</strong></p>',
        );
      });

      test('Paragraphs then quote', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Hello world\n'},
          {
            'insert': 'Another',
            'attributes': {'b': true}
          },
          {'insert': ' one\n'},
          {'insert': 'some '},
          {
            'insert': 'quote',
            'attributes': {'b': true}
          },
          {
            'insert': '\n',
            'attributes': {'block': 'quote'}
          },
        ]);
        expect(
          codec.encode(doc),
          '<p>Hello world</p>'
          '<p><strong>Another</strong> one</p>'
          '<blockquote style="margin: 0 0 0 0.8ex; border-left: 1px solid rgb(204, 204, 204); padding-left: 1ex;">some <strong>quote</strong></blockquote>',
        );
      });

      test('Set of blocks', () {
        final doc = ParchmentDocument.fromJson([
          {
            'insert':
                'Hello world\nHello world\nHello world\nHello world\nsome code'
          },
          {
            'insert': '\n',
            'attributes': {'block': 'code'}
          },
          {'insert': 'Hello world\nsome quote'},
          {
            'insert': '\n',
            'attributes': {'block': 'quote'}
          },
          {'insert': 'Hello world\n'},
        ]);
        expect(
          codec.encode(doc),
          '<p>Hello world</p>'
          '<p>Hello world</p>'
          '<p>Hello world</p>'
          '<p>Hello world</p>'
          '<pre><code>some code\n</code></pre>'
          '<p>Hello world</p>'
          '<blockquote style="margin: 0 0 0 0.8ex; border-left: 1px solid rgb(204, 204, 204); padding-left: 1ex;">some quote</blockquote>'
          '<p>Hello world</p>',
        );
      });

      test('Ordered list', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol'}
          },
          {'insert': 'This is Fleather!'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol'}
          }
        ]);

        expect(codec.encode(doc),
            '<ol><li>Hello World!</li><li>This is Fleather!</li></ol>');
      });

      test('List with bold', () {
        final doc = ParchmentDocument.fromJson([
          {
            'insert': 'Hello World!',
            'attributes': {'b': true}
          },
          {
            'insert': '\n',
            'attributes': {'block': 'ol'}
          },
          {'insert': 'This is Fleather!'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol'}
          }
        ]);

        expect(codec.encode(doc),
            '<ol><li><strong>Hello World!</strong></li><li>This is Fleather!</li></ol>');
      });

      test('Unordered list', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'block': 'ul'}
          },
          {'insert': 'This is Fleather!'},
          {
            'insert': '\n',
            'attributes': {'block': 'ul'}
          }
        ]);

        expect(codec.encode(doc),
            '<ul><li>Hello World!</li><li>This is Fleather!</li></ul>');
      });
      test('Checklist', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'item'},
          {
            'insert': '\n',
            'attributes': {'block': 'cl', 'checked': true}
          },
          {'insert': 'item'},
          {
            'insert': '\n',
            'attributes': {'block': 'cl'}
          }
        ]);

        expect(
            codec.encode(doc),
            '<div class="checklist">'
            '<div class="checklist-item"><input type="checkbox" checked disabled><label>&nbsp;item</label></div>'
            '<div class="checklist-item"><input type="checkbox" disabled><label>&nbsp;item</label></div>'
            '</div>');
      });

      test('Checklist followed by a link', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Check - 1'},
          {
            'insert': '\n',
            'attributes': {'block': 'cl', 'checked': true}
          },
          {'insert': 'Check - 2'},
          {
            'insert': '\n',
            'attributes': {'block': 'cl'}
          },
          {'insert': 'A link to a '},
          {
            'insert': 'site',
            'attributes': {'a': 'https://example.com'}
          },
          {'insert': '.\n'}
        ]);

        expect(
            codec.encode(doc),
            '<div class="checklist">'
            '<div class="checklist-item"><input type="checkbox" checked disabled><label>&nbsp;Check - 1</label></div>'
            '<div class="checklist-item"><input type="checkbox" disabled><label>&nbsp;Check - 2</label></div>'
            '</div>'
            '<p>A link to a <a href="https://example.com">site</a>.</p>');
      });

      test('Checklist followed by a paragraph', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Check - 1'},
          {
            'insert': '\n',
            'attributes': {'block': 'cl', 'checked': true}
          },
          {'insert': 'Check - 2'},
          {
            'insert': '\n',
            'attributes': {'block': 'cl'}
          },
          {'insert': 'Paragraph\n'},
        ]);

        expect(
            codec.encode(doc),
            '<div class="checklist">'
            '<div class="checklist-item"><input type="checkbox" checked disabled><label>&nbsp;Check - 1</label></div>'
            '<div class="checklist-item"><input type="checkbox" disabled><label>&nbsp;Check - 2</label></div></div>'
            '<p>Paragraph</p>');
      });
    });

    group('Links', () {
      test('Plain', () {
        final doc = ParchmentDocument.fromJson([
          {
            'insert': 'Hello World!',
            'attributes': {'a': 'http://fake.link'},
          },
          {'insert': '\n'}
        ]);

        expect(
            codec.encode(doc), '<a href="http://fake.link">Hello World!</a>');
      });

      test('Italic', () {
        final doc = ParchmentDocument.fromJson([
          {
            'insert': 'Hello World!',
            'attributes': {'a': 'http://fake.link', 'i': true},
          },
          {'insert': '\n'}
        ]);

        expect(codec.encode(doc),
            '<a href="http://fake.link"><em>Hello World!</em></a>');
      });

      test('In list', () {
        final doc = ParchmentDocument.fromJson([
          {
            'insert': 'Hello World!',
            'attributes': {'a': 'http://fake.link'},
          },
          {
            'insert': '\n',
            'attributes': {'block': 'ul'},
          }
        ]);

        expect(codec.encode(doc),
            '<ul><li><a href="http://fake.link">Hello World!</a></li></ul>');
      });
    });

    group('Direction', () {
      test('RTL', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Hello World!'},
          {'insert': '\n'},
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'direction': 'rtl'}
          }
        ]);

        expect(codec.encode(doc),
            '<p>Hello World!</p><p dir="rtl">Hello World!</p>');
      });

      test('In list', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol'},
          },
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {
              'direction': 'rtl',
              'block': 'ol',
              'alignment': 'center'
            },
          },
        ]);

        expect(codec.encode(doc),
            '<ol><li>Hello World!</li><li dir="rtl" style="text-align:center;">Hello World!</li></ol>');
      });
    });

    group('Alignment', () {
      test('center', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'alignment': 'center'}
          }
        ]);
        expect(codec.encode(doc),
            '<p style="text-align:center;">Hello World!</p>');
      });

      test('all paragraph alignments', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'alignment': null}
          },
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'alignment': 'right'}
          },
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'alignment': 'center'}
          },
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'alignment': 'justify'}
          }
        ]);
        expect(
          codec.encode(doc),
          '<p>Hello World!</p>'
          '<p style="text-align:right;">Hello World!</p>'
          '<p style="text-align:center;">Hello World!</p>'
          '<p style="text-align:justify;">Hello World!</p>',
        );
      });

      test('all list alignments', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol', 'alignment': null}
          },
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol', 'alignment': 'right'}
          },
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol', 'alignment': 'center'}
          },
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol', 'alignment': 'justify'}
          }
        ]);
        expect(
            codec.encode(doc),
            '<ol>'
            '<li>Hello World!</li>'
            '<li style="text-align:right;">Hello World!</li>'
            '<li style="text-align:center;">Hello World!</li>'
            '<li style="text-align:justify;">Hello World!</li>'
            '</ol>');
      });
    });

    group('Indentation', () {
      test('Nested lists - 3 levels', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'item'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol'}
          },
          {'insert': 'sub-item'},
          {
            'insert': '\n',
            'attributes': {'block': 'ul', 'indent': 1}
          },
          {'insert': 'sub-sub-item'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol', 'indent': 2}
          },
          {'insert': 'sub-sub-item'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol', 'indent': 2}
          },
          {'insert': 'sub-item'},
          {
            'insert': '\n',
            'attributes': {'block': 'ul', 'indent': 1}
          },
          {'insert': 'item'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol'}
          },
        ]);

        expect(
            codec.encode(doc),
            '<ol>'
            '<li>item</li>'
            '<ul>'
            '<li>sub-item</li>'
            '<ol>'
            '<li>sub-sub-item</li>'
            '<li>sub-sub-item</li>'
            '</ol>'
            '<li>sub-item</li>'
            '</ul>'
            '<li>item</li>'
            '</ol>');
      });

      test('Multiple nested lists - 4 levels', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'item'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol'}
          },
          {'insert': 'sub-item'},
          {
            'insert': '\n',
            'attributes': {'block': 'ul', 'indent': 1}
          },
          {'insert': 'sub-sub-item'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol', 'indent': 2}
          },
          {'insert': 'sub-sub-item'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol', 'indent': 2}
          },
          {'insert': 'sub-item'},
          {
            'insert': '\n',
            'attributes': {'block': 'ul', 'indent': 1}
          },
          {'insert': 'item'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol'}
          },
          {'insert': 'sub-item'},
          {
            'insert': '\n',
            'attributes': {'block': 'ul', 'indent': 1}
          },
          {'insert': 'sub-sub-item'},
          {
            'insert': '\n',
            'attributes': {'block': 'ul', 'indent': 2}
          },
          {'insert': 'sub-sub-sub-item'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol', 'indent': 3}
          },
          {'insert': 'sub-sub-sub-item'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol', 'indent': 3}
          },
          {'insert': 'sub-sub-item'},
          {
            'insert': '\n',
            'attributes': {'block': 'ul', 'indent': 2}
          },
          {'insert': 'sub-item'},
          {
            'insert': '\n',
            'attributes': {'block': 'ul', 'indent': 1}
          },
        ]);

        expect(
          codec.encode(doc),
          '<ol>'
          '<li>item</li>'
          '<ul>'
          '<li>sub-item</li>'
          '<ol>'
          '<li>sub-sub-item</li>'
          '<li>sub-sub-item</li>'
          '</ol>'
          '<li>sub-item</li>'
          '</ul>'
          '<li>item</li>'
          '<ul>'
          '<li>sub-item</li>'
          '<ul>'
          '<li>sub-sub-item</li>'
          '<ol>'
          '<li>sub-sub-sub-item</li>'
          '<li>sub-sub-sub-item</li>'
          '</ol>'
          '<li>sub-sub-item</li>'
          '</ul>'
          '<li>sub-item</li>'
          '</ul>'
          '</ol>',
        );
      });

      test('Multi-level lists with trailing paragraph', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Test\n'},
          {'insert': 'Level 1 - 1'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol'}
          },
          {'insert': 'Level 1 - 2'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol'}
          },
          {'insert': 'Level 2 - 1'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol', 'indent': 1}
          },
          {'insert': 'Level 2 - 2'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol', 'indent': 1}
          },
          {'insert': 'No longer in list\n'}
        ]);
        expect(codec.encode(doc),
            '<p>Test</p><ol><li>Level 1 - 1</li><li>Level 1 - 2</li><ol><li>Level 2 - 1</li><li>Level 2 - 2</li></ol></ol><p>No longer in list</p>');
      });

      test('Extreme multi-level lists with trailing paragraph', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Test\n'},
          {'insert': 'Level 1 - 1'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol'}
          },
          {'insert': 'Level 1 - 2'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol'}
          },
          {'insert': 'Level 2 - 1'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol', 'indent': 1}
          },
          {'insert': 'Level 2 - 2'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol', 'indent': 1}
          },
          {'insert': 'Level 3 - 1'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol', 'indent': 2}
          },
          {'insert': 'Level 3 - 2'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol', 'indent': 2}
          },
          {'insert': 'Level 4 - 1'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol', 'indent': 3}
          },
          {'insert': 'Level 4 - 2'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol', 'indent': 3}
          },
          {'insert': 'No longer in list\n'}
        ]);
        expect(codec.encode(doc),
            '<p>Test</p><ol><li>Level 1 - 1</li><li>Level 1 - 2</li><ol><li>Level 2 - 1</li><li>Level 2 - 2</li><ol><li>Level 3 - 1</li><li>Level 3 - 2</li><ol><li>Level 4 - 1</li><li>Level 4 - 2</li></ol></ol></ol></ol><p>No longer in list</p>');
      });

      test('Multiple Multi-level lists', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Test\n'},
          {'insert': 'Level 1 - 1'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol'}
          },
          {'insert': 'Level 1 - 2'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol'}
          },
          {'insert': 'Level 2 - 1'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol', 'indent': 1}
          },
          {'insert': 'Level 2 - 2'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol', 'indent': 1}
          },
          {'insert': 'No longer in list\n'},
          {'insert': 'In a new list - 1'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol'}
          },
          {'insert': 'In a new list - 2'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol'}
          },
        ]);
        expect(codec.encode(doc),
            '<p>Test</p><ol><li>Level 1 - 1</li><li>Level 1 - 2</li><ol><li>Level 2 - 1</li><li>Level 2 - 2</li></ol></ol><p>No longer in list</p><ol><li>In a new list - 1</li><li>In a new list - 2</li></ol>');
      });

      test('Paragraph with margin', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Something in the way...\nSomething in the way...'},
          {
            'insert': '\n',
            'attributes': {'indent': 1}
          },
        ]);
        expect(
            codec.encode(doc),
            '<p>Something in the way...</p>'
            '<p style="padding-left:32px;">Something in the way...</p>');
      });

      test('Quotes with indent', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Something in the way...\nSomething in the way...'},
          {
            'insert': '\n',
            'attributes': {'block': 'quote', 'indent': 1}
          },
        ]);
        expect(
            codec.encode(doc),
            '<p>Something in the way...</p>'
            '<blockquote style="margin: 0 0 0 0.8ex; border-left: 1px solid rgb(204, 204, 204); padding-left: 1ex;padding-left:32px;">Something in the way...</blockquote>');
      });

      test('Quote with embedded heading', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Quote'},
          {
            'insert': '\n',
            'attributes': {'block': 'quote'}
          },
          {'insert': 'header'},
          {
            'insert': '\n',
            'attributes': {'block': 'quote', 'heading': 1}
          },
          {'insert': 'Not in quote\n'},
        ]);
        expect(codec.encode(doc),
            '<blockquote style="margin: 0 0 0 0.8ex; border-left: 1px solid rgb(204, 204, 204); padding-left: 1ex;">Quote</blockquote><blockquote style="margin: 0 0 0 0.8ex; border-left: 1px solid rgb(204, 204, 204); padding-left: 1ex;"><h1 style="margin: 0 0 0 0.8ex; border-left: 1px solid rgb(204, 204, 204); padding-left: 1ex;">header</blockquote></h1><p>Not in quote</p>');
      });
    });

    group('Embeds', () {
      test('Image', () {
        final html =
            '<img src="http://fake.link/image.png" style="max-width: 100%; object-fit: contain;">';
        final doc = ParchmentDocument.fromJson([
          {'insert': '\n'}
        ]);
        doc.insert(0, BlockEmbed.image('http://fake.link/image.png'));

        expect(codec.encode(doc), html);
      });

      test('Line', () {
        final html = '<hr>';
        final doc = ParchmentDocument.fromJson([
          {'insert': '\n'}
        ]);
        doc.insert(0, BlockEmbed.horizontalRule);

        expect(codec.encode(doc), html);
      });
    });

    test('Multiple styles', () {
      final act = codec.encode(ParchmentDocument.fromDelta(delta));
      expect(act, htmlDoc);
    });
  });

  group('Decode', () {
    group('Basic text', () {
      test('Plain paragraph', () {
        final html = 'Hello World!';
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Hello World!\n'}
        ]);

        expect(codec.decode(html).toDelta(), doc.toDelta());
      });

      test('Background color', () {
        final htmlRGBA =
            '<span style="background-color: rgba(255,0,0,1)">Hello</span> world!';
        final doc = ParchmentDocument.fromJson([
          {
            'insert': 'Hello',
            'attributes': {'bg': 0xffff0000}
          },
          {'insert': ' world!\n'}
        ]);

        expect(codec.decode(htmlRGBA).toDelta(), doc.toDelta());
      });

      test('Foreground color', () {
        final htmlRGBA =
            '<span style="color: rgba(255,0,0,1)">Hello</span> world!';
        final doc = ParchmentDocument.fromJson([
          {
            'insert': 'Hello',
            'attributes': {'fg': 0xffff0000}
          },
          {'insert': ' world!\n'}
        ]);

        expect(codec.decode(htmlRGBA).toDelta(), doc.toDelta());
      });

      test('Bold paragraph', () {
        final html = '<strong>Hello World!</strong>';
        final doc = ParchmentDocument.fromJson([
          {
            'insert': 'Hello World!',
            'attributes': {'b': true}
          },
          {'insert': '\n'},
        ]);

        expect(codec.decode(html).toDelta(), doc.toDelta());
      });

      test('Underline paragraph', () {
        final html = '<u>Hello World!</u>';
        final doc = ParchmentDocument.fromJson([
          {
            'insert': 'Hello World!',
            'attributes': {'u': true}
          },
          {'insert': '\n'},
        ]);

        expect(codec.decode(html).toDelta(), doc.toDelta());
      });

      test('Strikethrough paragraph', () {
        final html = '<del>Hello World!</del>';
        final doc = ParchmentDocument.fromJson([
          {
            'insert': 'Hello World!',
            'attributes': {'s': true}
          },
          {'insert': '\n'},
        ]);

        expect(codec.decode(html).toDelta(), doc.toDelta());
      });

      test('Italic paragraph', () {
        final html = '<em>Hello World!</em>';
        final doc = ParchmentDocument.fromJson([
          {
            'insert': 'Hello World!',
            'attributes': {'i': true}
          },
          {'insert': '\n'},
        ]);

        expect(codec.decode(html).toDelta(), doc.toDelta());
      });

      test('Bold and Italic paragraph', () {
        final html = '<em><strong>Hello World!</em></strong>';
        final doc = ParchmentDocument.fromJson([
          {
            'insert': 'Hello World!',
            'attributes': {'i': true, 'b': true}
          },
          {'insert': '\n'},
        ]);

        expect(codec.decode(html).toDelta(), doc.toDelta());
      });

      test('tangled inline tags', () {
        final html = 'AAA<strong>BB<del>B</del></strong><del>CCC</del>';
        final doc = ParchmentDocument.fromJson([
          {'insert': 'AAA'},
          {
            'insert': 'BB',
            'attributes': {'b': true}
          },
          {
            'insert': 'B',
            'attributes': {'b': true, 's': true}
          },
          {
            'insert': 'CCC',
            'attributes': {'s': true}
          },
          {'insert': '\n'}
        ]);
        expect(codec.decode(html).toDelta(), doc.toDelta());
      });

      test('embedded inline attributes text', () {
        final html =
            '<p><u><a href="https://wikipedia.org">Something </a><em>in the way</em> mmmm...</u></p>';
        final doc = ParchmentDocument.fromJson([
          {
            'insert': 'Something ',
            'attributes': {'a': 'https://wikipedia.org', 'u': true}
          },
          {
            'insert': 'in the way',
            'attributes': {'i': true, 'u': true}
          },
          {
            'insert': ' mmmm...',
            'attributes': {'u': true}
          },
          {'insert': '\n'}
        ]);
        expect(codec.decode(html).toDelta(), doc.toDelta());
      });
    });

    group('Headings', () {
      test('1', () {
        final html = '<h1>Hello World!</h1>';
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'heading': 1}
          },
        ]);

        expect(codec.decode(html).toDelta(), doc.toDelta());
      });

      test('2', () {
        final html = '<h2>Hello World!</h2>';
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'heading': 2}
          }
        ]);

        expect(codec.decode(html).toDelta(), doc.toDelta());
      });

      test('3', () {
        final html = '<h3>Hello World!</h3>';
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'heading': 3}
          }
        ]);

        expect(codec.decode(html).toDelta(), doc.toDelta());
      });

      test('4', () {
        final html = '<h4>Hello World!</h4>';
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'heading': 4}
          }
        ]);

        expect(codec.decode(html).toDelta(), doc.toDelta());
      });

      test('5', () {
        final html = '<h5>Hello World!</h5>';
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'heading': 5}
          }
        ]);

        expect(codec.decode(html).toDelta(), doc.toDelta());
      });

      test('6', () {
        final html = '<h6>Hello World!</h6>';
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'heading': 6}
          }
        ]);

        expect(codec.decode(html).toDelta(), doc.toDelta());
      });
    });

    group('Blocks', () {
      group('Paragraph', () {
        test('simple', () {
          final html = '<p>Hello World!</p>';
          final doc = ParchmentDocument.fromJson([
            {
              'insert': 'Hello World!\n',
            }
          ]);
          expect(codec.decode(html).toDelta(), doc.toDelta());
        });

        test('with indentation', () {
          final html = '<p style=padding-left:32px>Hello World!</p>';
          final doc = ParchmentHtmlCodec().decode(html);
          expect(
              doc.toDelta(),
              Delta()
                ..insert('Hello World!')
                ..insert('\n', {'indent': 1}));
        });

        test('Paragraph with link', () {
          final html =
              '<p>Hello World!<a href="http://fake.link">Hello World!</a> Another hello world!</p>';
          final doc = ParchmentDocument.fromJson([
            {
              'insert': 'Hello World!',
            },
            {
              'insert': 'Hello World!',
              'attributes': {'a': 'http://fake.link'},
            },
            {
              'insert': ' Another hello world!\n',
            }
          ]);

          expect(codec.decode(html).toDelta(), doc.toDelta());
        });

        test('Multiples paragraphs', () {
          final html =
              '<p>Hello World!<a href="http://fake.link">Hello World!</a> Another hello world!</p><p>Hello World!<a href="http://fake.link">Hello World!</a> Another hello world!</p>';
          final doc = ParchmentDocument.fromJson([
            {
              'insert': 'Hello World!',
            },
            {
              'insert': 'Hello World!',
              'attributes': {'a': 'http://fake.link'},
            },
            {
              'insert': ' Another hello world!\n',
            },
            {
              'insert': 'Hello World!',
            },
            {
              'insert': 'Hello World!',
              'attributes': {'a': 'http://fake.link'},
            },
            {
              'insert': ' Another hello world!\n',
            }
          ]);

          expect(codec.decode(html).toDelta(), doc.toDelta());
        });
      });

      test('Quote', () {
        final html = '<blockquote>Hello World!</blockquote><br><br>';
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'block': 'quote'}
          }
        ]);

        expect(codec.decode(html).toDelta(), doc.toDelta());
      });
      test('Code', () {
        final html = '<pre>'
            '<code>void main() {</code>'
            '<code>  print("Hello world!");</code>'
            '<code>}</code>'
            '</pre>';
        final doc = ParchmentDocument.fromJson([
          {'insert': 'void main() {'},
          {
            'insert': '\n',
            'attributes': {'block': 'code'}
          },
          {'insert': '  print("Hello world!");'},
          {
            'insert': '\n',
            'attributes': {'block': 'code'}
          },
          {'insert': '}'},
          {
            'insert': '\n',
            'attributes': {'block': 'code'}
          }
        ]);

        expect(codec.decode(html).toDelta(), doc.toDelta());
      });

      test('Code then paragraph', () {
        final html = '<pre><code>some code</code></pre>'
            '<p>Hello world</p>';
        final doc = ParchmentDocument.fromJson([
          {'insert': 'some code'},
          {
            'insert': '\n',
            'attributes': {'block': 'code'}
          },
          {'insert': 'Hello world\n'},
        ]);
        expect(codec.decode(html).toDelta(), doc.toDelta());
      });

      test('Paragraphs then quote', () {
        final html = '<p>Hello world</p>'
            '<p><strong>Another</strong> one</p>'
            '<blockquote>some <strong>quote</strong></blockquote>';
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Hello world\n'},
          {
            'insert': 'Another',
            'attributes': {'b': true}
          },
          {'insert': ' one\n'},
          {'insert': 'some '},
          {
            'insert': 'quote',
            'attributes': {'b': true}
          },
          {
            'insert': '\n',
            'attributes': {'block': 'quote'}
          },
        ]);
        expect(codec.decode(html).toDelta(), doc.toDelta());
      });

      test('Ordered list', () {
        final html = '<ol><li>an item</li><li>another item</li></ol>';
        final doc = ParchmentDocument.fromJson([
          {'insert': 'an item'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol'}
          },
          {'insert': 'another item'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol'}
          }
        ]);

        expect(codec.decode(html).toDelta(), doc.toDelta());
      });
      test('List with bold', () {
        final html = '<ol><li><strong>Hello World!</strong></li></ol><br><br>';
        final doc = ParchmentDocument.fromJson([
          {
            'insert': 'Hello World!',
            'attributes': {'b': true}
          },
          {
            'insert': '\n',
            'attributes': {'block': 'ol'}
          }
        ]);

        expect(codec.decode(html).toDelta(), doc.toDelta());
      });
      test('Unordered list', () {
        final html =
            '<ul><li>Hello World!</li><li>Hello World!</li></ul><br><br>';
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'block': 'ul'}
          },
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'block': 'ul'}
          }
        ]);

        expect(codec.decode(html).toDelta(), doc.toDelta());
      });
    });

    group('Alignment', () {
      test('center', () {
        final html = '<p style="text-align:center;">Hello World!</p>';
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'alignment': 'center'}
          }
        ]);
        expect(codec.decode(html).toDelta(), doc.toDelta());
      });

      test('all paragraph alignments', () {
        final html = '<p>Hello World!</p>'
            '<p style="text-align:right;">Hello World!</p>'
            '<p style="text-align:center;">Hello World!</p>'
            '<p style="text-align:justify;">Hello World!</p>';
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Hello World!\nHello World!'},
          {
            'insert': '\n',
            'attributes': {'alignment': 'right'}
          },
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'alignment': 'center'}
          },
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'alignment': 'justify'}
          }
        ]);
        expect(codec.decode(html).toDelta(), doc.toDelta());
      });

      test('all list alignments', () {
        final html = '<ol>'
            '<li>Hello World!</li>'
            '<li style="text-align:right;">Hello World!</li>'
            '<li style="text-align:center;">Hello World!</li>'
            '<li style="text-align:justify;">Hello World!</li>'
            '</ol>';
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol'}
          },
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol', 'alignment': 'right'}
          },
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol', 'alignment': 'center'}
          },
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol', 'alignment': 'justify'}
          }
        ]);
        expect(codec.decode(html).toDelta(), doc.toDelta());
      });
    });

    group('Indentation', () {
      test('Nested lists', () {
        final html = '<ol>'
            '<li>item</li>'
            '<ul>'
            '<li>sub-item</li>'
            '<ol>'
            '<li>sub-sub-item</li>'
            '<li>sub-sub-item</li>'
            '</ol>'
            '<li>sub-item</li>'
            '</ul>'
            '<li>item</li>'
            '<ul>'
            '<li>sub-item</li>'
            '<ul>'
            '<li>sub-sub-item</li>'
            '<ol>'
            '<li>sub-sub-sub-item</li>'
            '<li>sub-sub-sub-item</li>'
            '</ol>'
            '<li>sub-sub-item</li>'
            '</ul>'
            '<li>sub-item</li>'
            '</ul>'
            '</ol>';
        final doc = ParchmentDocument.fromJson([
          {'insert': 'item'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol'}
          },
          {'insert': 'sub-item'},
          {
            'insert': '\n',
            'attributes': {'block': 'ul', 'indent': 1}
          },
          {'insert': 'sub-sub-item'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol', 'indent': 2}
          },
          {'insert': 'sub-sub-item'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol', 'indent': 2}
          },
          {'insert': 'sub-item'},
          {
            'insert': '\n',
            'attributes': {'block': 'ul', 'indent': 1}
          },
          {'insert': 'item'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol'}
          },
          {'insert': 'sub-item'},
          {
            'insert': '\n',
            'attributes': {'block': 'ul', 'indent': 1}
          },
          {'insert': 'sub-sub-item'},
          {
            'insert': '\n',
            'attributes': {'block': 'ul', 'indent': 2}
          },
          {'insert': 'sub-sub-sub-item'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol', 'indent': 3}
          },
          {'insert': 'sub-sub-sub-item'},
          {
            'insert': '\n',
            'attributes': {'block': 'ol', 'indent': 3}
          },
          {'insert': 'sub-sub-item'},
          {
            'insert': '\n',
            'attributes': {'block': 'ul', 'indent': 2}
          },
          {'insert': 'sub-item'},
          {
            'insert': '\n',
            'attributes': {'block': 'ul', 'indent': 1}
          },
        ]);
        expect(codec.decode(html).toDelta(), doc.toDelta());
      });
    });

    group('Embeds', () {
      test('Block embeds special treatment', () {
        String html = '<p><hr><p><img src="http://fake.link/image.png"></p>'
            '<img src="http://another.fake.link/image.png"></p><p>a</p>';
        final doc = ParchmentDocument.fromJson([
          {'insert': '\n'}
        ]);
        doc.insert(0, 'a');
        doc.insert(0, BlockEmbed.image('http://another.fake.link/image.png'));
        doc.insert(0, BlockEmbed.image('http://fake.link/image.png'));
        doc.insert(0, BlockEmbed.horizontalRule);
        expect(codec.decode(html).toDelta(), doc.toDelta());
      });

      test('Image', () {
        final html = '<img src="http://fake.link/image.png">';
        final doc = ParchmentDocument.fromJson([
          {'insert': '\n'}
        ]);
        doc.insert(0, BlockEmbed.image('http://fake.link/image.png'));

        expect(codec.decode(html).toDelta(), doc.toDelta());
      });

      test('Line', () {
        final html = '<hr>';
        final doc = ParchmentDocument.fromJson([
          {'insert': '\n'}
        ]);
        doc.insert(0, BlockEmbed.horizontalRule);

        expect(codec.decode(html).toDelta(), doc.toDelta());
      });
    });

    group('Links', () {
      test('Plain', () {
        final html = '<a href="http://fake.link">Hello World!</a><br><br>';
        final doc = ParchmentDocument.fromJson([
          {
            'insert': 'Hello World!',
            'attributes': {'a': 'http://fake.link'},
          },
          {'insert': '\n'}
        ]);

        expect(codec.decode(html).toDelta(), doc.toDelta());
      });

      test('Italic', () {
        final html =
            '<a href="http://fake.link"><em>Hello World!</em></a><br><br>';
        final doc = ParchmentDocument.fromJson([
          {
            'insert': 'Hello World!',
            'attributes': {'a': 'http://fake.link', 'i': true},
          },
          {'insert': '\n'}
        ]);

        expect(codec.decode(html).toDelta(), doc.toDelta());
      });

      test('In list', () {
        final html =
            '<ul><li><a href="http://fake.link">Hello World!</a></li></ul>';
        final doc = ParchmentDocument.fromJson([
          {
            'insert': 'Hello World!',
            'attributes': {'a': 'http://fake.link'},
          },
          {
            'insert': '\n',
            'attributes': {'block': 'ul'},
          }
        ]);

        expect(codec.decode(html).toDelta(), doc.toDelta());
      });
    });
  });
}

final doc = [
  {'insert': 'Fleather'},
  {
    'insert': '\n',
    'attributes': {'heading': 1}
  },
  {
    'insert': 'Soft and gentle rich text editing for Flutter applications.',
    'attributes': {'i': true}
  },
  {'insert': '\nFleather is an '},
  {
    'insert': 'early preview',
    'attributes': {'b': true, 'fg': 0xFFFF0000}
  },
  {'insert': ' open source library.\nDocumentation'},
  {
    'insert': '\n',
    'attributes': {'heading': 3}
  },
  {'insert': 'Quick Start'},
  {
    'insert': '\n',
    'attributes': {'block': 'ul'}
  },
  {'insert': 'Data format and Document Model'},
  {
    'insert': '\n',
    'attributes': {'block': 'ul'}
  },
  {'insert': 'Style attributes'},
  {
    'insert': '\n',
    'attributes': {'block': 'ul'}
  },
  {'insert': 'Heuristic rules'},
  {
    'insert': '\n',
    'attributes': {'block': 'ul'}
  },
  {'insert': 'Clean and modern look'},
  {
    'insert': '\n',
    'attributes': {'heading': 2}
  },
  {'insert': 'Fleather’s rich text editor is built with '},
  {
    'insert': 'simplicity and flexibility',
    'attributes': {'i': true}
  },
  {
    'insert':
        ' in mind. It provides clean interface for distraction-free editing. Think '
  },
  {
    'insert': 'Medium.com',
    'attributes': {'c': true}
  },
  // {'insert': '-like experience.\n'},
  {'insert': '-like experience.\nimport ‘package:flutter/material.dart’;'},
  {
    'insert': '\n',
    'attributes': {'block': 'code'}
  },
  {'insert': 'import ‘package:parchment/parchment.dart’;'},
  {
    'insert': '\n\n',
    'attributes': {'block': 'code'}
  },
  {'insert': 'void main() {'},
  {
    'insert': '\n',
    'attributes': {'block': 'code'}
  },
  {'insert': ' print(“Hello world!”);'},
  {
    'insert': '\n',
    'attributes': {'block': 'code'}
  },
  {'insert': '}'},
  {
    'insert': '\n',
    'attributes': {'block': 'code'}
  }
];
final delta = Delta.fromJson(doc);
final htmlDoc = '<h1>Fleather</h1>'
    '<p><em>Soft and gentle rich text editing for Flutter applications.</em></p>'
    '<p>Fleather is an <strong><span style="color: rgba(255,0,0,1.0)">early preview</span></strong> open source library.</p>'
    '<h3>Documentation</h3>'
    '<ul>'
    '<li>Quick Start</li>'
    '<li>Data format and Document Model</li>'
    '<li>Style attributes</li>'
    '<li>Heuristic rules</li>'
    '</ul>'
    '<h2>Clean and modern look</h2>'
    '<p>Fleather’s rich text editor is built with <em>simplicity and flexibility</em> in mind. It provides clean interface for distraction-free editing. Think <code>Medium.com</code>-like experience.</p>'
    '<pre><code>import ‘package:flutter/material.dart’;\n'
    'import ‘package:parchment/parchment.dart’;\n'
    '\n'
    'void main() {\n'
    ' print(“Hello world!”);\n'
    '}\n'
    '</code></pre>';
