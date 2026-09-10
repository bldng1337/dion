import 'dart:io';

import 'package:dionysos/service/image_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImageStoreService.downloadable', () {
    test('accepts http(s) urls', () {
      expect(ImageStoreService.downloadable('http://example.com/a.jpg'), true);
      expect(
        ImageStoreService.downloadable('https://example.com/a.jpg?x=1'),
        true,
      );
    });

    test('rejects file links used by some extension adapters', () {
      expect(ImageStoreService.downloadable('file:///C:/data/img.jpg'), false);
      expect(ImageStoreService.downloadable('file:///storage/0/a.png'), false);
    });

    test('rejects other schemes and empty urls', () {
      expect(ImageStoreService.downloadable('mihon:12345'), false);
      expect(
        ImageStoreService.downloadable('data:image/png;base64,AAAA'),
        false,
      );
      expect(ImageStoreService.downloadable('ftp://example.com/a.jpg'), false);
      expect(ImageStoreService.downloadable(''), false);
      expect(ImageStoreService.downloadable(null), false);
    });
  });

  group('ImageStoreService hash and file naming', () {
    test('hash is 16 lowercase hex characters', () {
      final hash = ImageStoreService.hashUrl('https://example.com/cover.jpg');
      expect(hash, matches(RegExp(r'^[0-9a-f]{16}$')));
    });

    test('hash is deterministic and collision-free for distinct urls', () {
      final a1 = ImageStoreService.hashUrl('https://example.com/a.jpg');
      final a2 = ImageStoreService.hashUrl('https://example.com/a.jpg');
      final b = ImageStoreService.hashUrl('https://example.com/b.jpg');
      expect(a1, a2);
      expect(a1, isNot(b));
    });

    test('targetFile derives the same file for the same url', () {
      withTempDir((dir) {
        final store = ImageStoreService(dir);
        const url = 'https://example.com/pics/cover.jpg?size=large';
        final file = store.targetFile(url);
        expect(
          file.path,
          '${dir.path}${Platform.pathSeparator}'
          '${ImageStoreService.hashUrl(url)}.jpg',
        );
        expect(store.targetFile(url).path, file.path);
      });
    });

    test('fileNameToHash round-trips and rejects foreign names', () {
      final hash = ImageStoreService.hashUrl('https://example.com/a.jpg');
      expect(ImageStoreService.fileNameToHash('$hash.jpg'), hash);
      expect(ImageStoreService.fileNameToHash(hash), hash);
      expect(ImageStoreService.fileNameToHash('randomfile.jpg'), isNull);
      expect(ImageStoreService.fileNameToHash('short.jpg'), isNull);
    });
  });

  group('reference helpers', () {
    test('imageHashes skips null/empty urls and dedups', () {
      final hashes = ImageStoreService.imageHashes([
        'https://example.com/a.jpg',
        'https://example.com/a.jpg',
        null,
        '',
      ]);
      expect(hashes.length, 1);
      expect(
        hashes,
        contains(ImageStoreService.hashUrl('https://example.com/a.jpg')),
      );
    });

    test('imageSignature is order-independent and change-sensitive', () {
      final a = ImageStoreService.imageHashes(['https://a', 'https://b']);
      final b = ImageStoreService.imageHashes(['https://b', 'https://a']);
      expect(
        ImageStoreService.imageSignature(a),
        ImageStoreService.imageSignature(b),
      );
      final c = ImageStoreService.imageHashes(['https://a']);
      expect(
        ImageStoreService.imageSignature(a),
        isNot(ImageStoreService.imageSignature(c)),
      );
    });
  });
}

void withTempDir(void Function(Directory dir) body) {
  final dir = Directory.systemTemp.createTempSync('dion_image_store_test_');
  try {
    body(dir);
  } finally {
    dir.deleteSync(recursive: true);
  }
}
