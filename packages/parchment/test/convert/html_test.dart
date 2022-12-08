import 'package:parchment/parchment.dart';
import 'package:parchment/src/convert/html.dart';
import 'package:quill_delta/quill_delta.dart';
import 'package:test/test.dart';

void main() {
  final codec = ParchmentHtmlCodec();

  group('Encode', () {
    group('Basic text', () {
      test('only two lines', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': '\n\n'},
        ]);
        expect(codec.encode(doc.toDelta()), '<p></p><p></p>');
      });

      test('plain text', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Something in the way mmmm...\n'}
        ]);
        expect(codec.encode(doc.toDelta()), 'Something in the way mmmm...');
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
        expect(codec.encode(doc.toDelta()),
            'Something <strong>in the way</strong> mmmm...');
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
        expect(codec.encode(doc.toDelta()),
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
        expect(codec.encode(doc.toDelta()),
            '<u><a href="https://wikipedia.org">Something </a><em>in the way</em> mmmm...</u>');
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

        expect(codec.encode(doc.toDelta()), '<h1>Hello World!</h1>');
      });

      test('2', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'heading': 2}
          }
        ]);

        expect(codec.encode(doc.toDelta()), '<h2>Hello World!</h2>');
      });

      test('3', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Hello World!'},
          {
            'insert': '\n',
            'attributes': {'heading': 3}
          }
        ]);

        expect(codec.encode(doc.toDelta()), '<h3>Hello World!</h3>');
      });
    });

    group('Blocks', () {
      group('Paragraph', () {
        test('multiple', () {
          final doc = ParchmentDocument.fromJson([
            {'insert': 'Hello World!\nBye World!\n'},
          ]);
          expect(codec.encode(doc.toDelta()),
              '<p>Hello World!</p><p>Bye World!</p>');
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
          expect(codec.encode(doc.toDelta()),
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

          expect(codec.encode(doc.toDelta()),
              '<blockquote>Hello World!</blockquote>');
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
              codec.encode(doc.toDelta()),
              '<blockquote>Hello World!</blockquote>'
              '<blockquote>Hello World!</blockquote>');
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
              codec.encode(doc.toDelta()),
              '<blockquote>Hello World!</blockquote>'
              '<blockquote style="text-align:center;">Hello World!</blockquote>');
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
          codec.encode(doc.toDelta()),
          '<pre>'
          '<code>void main() {</code>'
          '<code></code>'
          '<code>  print("Hello World!");</code>'
          '<code>}</code>'
          '</pre>',
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
          codec.encode(doc.toDelta()),
          '<pre><code>some code</code></pre>'
          '<p>Hello world</p>',
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
          codec.encode(doc.toDelta()),
          '<p>Hello world</p>'
          '<p><strong>Another</strong> one</p>'
          '<blockquote>some <strong>quote</strong></blockquote>',
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
          codec.encode(doc.toDelta()),
          '<p>Hello world</p>'
          '<p>Hello world</p>'
          '<p>Hello world</p>'
          '<p>Hello world</p>'
          '<pre><code>some code</code></pre>'
          '<p>Hello world</p>'
          '<blockquote>some quote</blockquote>'
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

        expect(codec.encode(doc.toDelta()),
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

        expect(codec.encode(doc.toDelta()),
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

        expect(codec.encode(doc.toDelta()),
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
            codec.encode(doc.toDelta()),
            '<div class="checklist">'
            '<div class="checklist-item"><input type="checkbox" checked><label>item</label></div>'
            '<div class="checklist-item"><input type="checkbox"><label>item</label></div>'
            '</div>');
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

        expect(codec.encode(doc.toDelta()),
            '<a href="http://fake.link">Hello World!</a>');
      });

      test('Italic', () {
        final doc = ParchmentDocument.fromJson([
          {
            'insert': 'Hello World!',
            'attributes': {'a': 'http://fake.link', 'i': true},
          },
          {'insert': '\n'}
        ]);

        expect(codec.encode(doc.toDelta()),
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

        expect(codec.encode(doc.toDelta()),
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

        expect(codec.encode(doc.toDelta()),
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

        expect(codec.encode(doc.toDelta()),
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
        expect(codec.encode(doc.toDelta()),
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
          codec.encode(doc.toDelta()),
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
            codec.encode(doc.toDelta()),
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
            codec.encode(doc.toDelta()),
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
          codec.encode(doc.toDelta()),
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

      test('Paragraph with margin', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Something in the way...\nSomething in the way...'},
          {
            'insert': '\n',
            'attributes': {'indent': 1}
          },
        ]);
        expect(
            codec.encode(doc.toDelta()),
            '<p>Something in the way...</p>'
            '<p style="padding-left:32px;">Something in the way...</p>');
      });

      test('Quotes with margin', () {
        final doc = ParchmentDocument.fromJson([
          {'insert': 'Something in the way...\nSomething in the way...'},
          {
            'insert': '\n',
            'attributes': {'block': 'quote', 'indent': 1}
          },
        ]);
        expect(
            codec.encode(doc.toDelta()),
            '<p>Something in the way...</p>'
            '<blockquote style="padding-left:32px;">Something in the way...</blockquote>');
      });
    });

    group('Embeds', () {
      test('Image', () {
        final html = '<img src="http://fake.link/image.png">';
        final doc = ParchmentDocument.fromJson([
          {'insert': '\n'}
        ]);
        doc.insert(0, BlockEmbed.image('http://fake.link/image.png'));

        expect(codec.encode(doc.toDelta()), html);
      });

      test('Line', () {
        final html = '<hr>';
        final doc = ParchmentDocument.fromJson([
          {'insert': '\n'}
        ]);
        doc.insert(0, BlockEmbed.horizontalRule);

        expect(codec.encode(doc.toDelta()), html);
      });
    });

    test('Multiple styles', () {
      final act = codec.encode(delta);
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

        expect(codec.decode(html), doc.toDelta());
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

        expect(codec.decode(html), doc.toDelta());
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

        expect(codec.decode(html), doc.toDelta());
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

        expect(codec.decode(html), doc.toDelta());
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

        expect(codec.decode(html), doc.toDelta());
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

        expect(codec.decode(html), doc.toDelta());
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
        expect(codec.decode(html), doc.toDelta());
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

        expect(codec.decode(html), doc.toDelta());
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

        expect(codec.decode(html), doc.toDelta());
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

        expect(codec.decode(html), doc.toDelta());
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
          expect(codec.decode(html), doc.toDelta());
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

          expect(codec.decode(html), doc.toDelta());
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

          expect(codec.decode(html), doc.toDelta());
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

        expect(codec.decode(html), doc.toDelta());
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

        expect(codec.decode(html), doc.toDelta());
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
        expect(codec.decode(html), doc.toDelta());
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
        expect(codec.decode(html), doc.toDelta());
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

        expect(codec.decode(html), doc.toDelta());
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

        expect(codec.decode(html), doc.toDelta());
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

        expect(codec.decode(html), doc.toDelta());
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
        expect(codec.decode(html), doc.toDelta());
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
        expect(codec.decode(html), doc.toDelta());
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
        expect(codec.decode(html), doc.toDelta());
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
        expect(codec.decode(html), doc.toDelta());
      });
    });

    group('Embeds', () {
      test('Image', () {
        final html = '<img src="http://fake.link/image.png">';
        final doc = ParchmentDocument.fromJson([
          {'insert': '\n'}
        ]);
        doc.insert(0, BlockEmbed.image('http://fake.link/image.png'));

        expect(codec.decode(html), doc.toDelta());
      });

      test('Line', () {
        final html = '<hr>';
        final doc = ParchmentDocument.fromJson([
          {'insert': '\n'}
        ]);
        doc.insert(0, BlockEmbed.horizontalRule);

        expect(codec.decode(html), doc.toDelta());
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

        expect(codec.decode(html), doc.toDelta());
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

        expect(codec.decode(html), doc.toDelta());
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

        expect(codec.decode(html), doc.toDelta());
      });
    });
  }, skip: false);
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
    'attributes': {'b': true}
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
    '<p>Fleather is an <strong>early preview</strong> open source library.</p>'
    '<h3>Documentation</h3>'
    '<ul>'
    '<li>Quick Start</li>'
    '<li>Data format and Document Model</li>'
    '<li>Style attributes</li>'
    '<li>Heuristic rules</li>'
    '</ul>'
    '<h2>Clean and modern look</h2>'
    '<p>Fleather’s rich text editor is built with <em>simplicity and flexibility</em> in mind. It provides clean interface for distraction-free editing. Think <code>Medium.com</code>-like experience.</p>'
    '<pre>'
    '<code>import ‘package:flutter/material.dart’;</code>'
    '<code>import ‘package:parchment/parchment.dart’;</code>'
    '<code></code>'
    '<code>void main() {</code>'
    '<code> print(“Hello world!”);</code>'
    '<code>}</code>'
    '</pre>';
