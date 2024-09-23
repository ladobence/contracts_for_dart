import 'dart:io';

import 'package:source_span/source_span.dart';

const int _eol = 10;

class SourceSpanParser {
  SourceSpanParser(this.uri);

  Uri uri;

  Iterable<SourceSpan> parseFile() sync* {
    var wordStart = 0;
    var inWhiteSpace = true;
    final file = File(uri.path.substring(1));
    final contents = file.readAsStringSync();
    final sourceFile = SourceFile.fromString(contents, url: uri);

    for (var i = 0; i < contents.length; i++) {
      final codeUnit = contents.codeUnitAt(i);

      if (codeUnit == _eol) {
        if (!inWhiteSpace) {
          inWhiteSpace = true;

          // emit a word
          yield sourceFile.span(wordStart, i);
        }
      } else {
        if (inWhiteSpace) {
          inWhiteSpace = false;

          wordStart = i;
        }
      }
    }

    if (!inWhiteSpace) {
      // emit a word
      yield sourceFile.span(wordStart, contents.length);
    }
  }
}
