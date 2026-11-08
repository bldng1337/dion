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

  group('InternetFile.formatRelativeURI', () {
    const manifest = 'https://cdn.example.com/a/b/index.m3u8?t=1/2';

    test('resolves against the manifest directory, ignoring its query', () {
      expect(
        InternetFile.formatRelativeURI('seg.ts', manifest),
        'https://cdn.example.com/a/b/seg.ts',
      );
    });

    test('resolves root-relative and protocol-relative links', () {
      expect(
        InternetFile.formatRelativeURI('/x/seg.ts', manifest),
        'https://cdn.example.com/x/seg.ts',
      );
      expect(
        InternetFile.formatRelativeURI('//other.example.com/seg.ts', manifest),
        'https://other.example.com/seg.ts',
      );
    });

    test('keeps absolute links', () {
      expect(
        InternetFile.formatRelativeURI('https://x.example/seg.ts', manifest),
        'https://x.example/seg.ts',
      );
    });
  });

  group('InternetFile.selectBestVariant', () {
    test('keeps only the highest bandwidth variant and its renditions', () {
      expect(
        InternetFile.selectBestVariant([
          '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="low",URI="low.m3u8"',
          '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="high",URI="high.m3u8"',
          '#EXT-X-STREAM-INF:AVERAGE-BANDWIDTH=9,BANDWIDTH=100,AUDIO="low"',
          '360.m3u8',
          '#EXT-X-STREAM-INF:BANDWIDTH=900,AUDIO="high"',
          '1080.m3u8?token=x',
          '#EXT-X-I-FRAME-STREAM-INF:BANDWIDTH=50,URI="iframe.m3u8"',
        ]),
        [
          '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="high",URI="high.m3u8"',
          '#EXT-X-STREAM-INF:BANDWIDTH=900,AUDIO="high"',
          '1080.m3u8?token=x',
        ],
      );
    });

    test('leaves media playlists untouched', () {
      const lines = ['#EXTINF:4,', 'seg0.ts', '#EXT-X-ENDLIST'];
      expect(InternetFile.selectBestVariant(lines), lines);
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
