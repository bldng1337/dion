import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dionysos/utils/internetfile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InternetFile.fromURI endings', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('dion_internetfile_test_');
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('appends the url ending, ignoring query parameters', () {
      final file = InternetFile.fromURI(
        'https://example.com/a/image0.jpg?token=x',
        dir,
        filename: 'image0',
      );
      expect(file.uri.pathSegments.last, 'image0.jpg');
    });

    test('an explicit ending overrides the url-derived one', () {
      final file = InternetFile.fromURI(
        'https://example.com/download/12345.zip',
        dir,
        filename: 'data',
        ending: '.epub',
      );
      expect(file.uri.pathSegments.last, 'data.epub');
    });

    test('extension-less urls get the explicit ending', () {
      final file = InternetFile.fromURI(
        'https://example.com/download/12345',
        dir,
        filename: 'data',
        ending: '.pdf',
      );
      expect(file.uri.pathSegments.last, 'data.pdf');
    });

    test('extension-less urls without an override stay nameless', () {
      final file = InternetFile.fromURI(
        'https://example.com/vod/12345',
        dir,
        filename: 'video',
      );
      expect(file.uri.pathSegments.last, 'video');
    });
  });

  group('InternetFile.looksLikeM3u8', () {
    test('detects the tag with trailing lines', () {
      expect(
        InternetFile.looksLikeM3u8(
          looksLikeM3u8Bytes('#EXTM3U\n#EXT-X-TARGETDURATION:10\nseg0.ts'),
        ),
        isTrue,
      );
    });

    test('detects the tag after a BOM', () {
      expect(
        InternetFile.looksLikeM3u8(
          looksLikeM3u8Bytes('\uFEFF#EXTM3U\nseg0.ts'),
        ),
        isTrue,
      );
    });

    test('rejects other text and binary content', () {
      expect(
        InternetFile.looksLikeM3u8(looksLikeM3u8Bytes('#EXT-X-VERSION:3')),
        isFalse,
      );
      expect(
        InternetFile.looksLikeM3u8(looksLikeM3u8Bytes('#extend')),
        isFalse,
      );
      expect(InternetFile.looksLikeM3u8(looksLikeM3u8Bytes('')), isFalse);
      expect(InternetFile.looksLikeM3u8(Uint8List(512)), isFalse);
    });
  });
}

Uint8List looksLikeM3u8Bytes(String content) {
  return Uint8List.fromList(utf8.encode(content));
}
