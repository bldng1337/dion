import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dionysos/data/backup/foreign.dart';
import 'package:dionysos/data/backup/lnreader.dart';
import 'package:dionysos/data/backup/tachiyomi.dart';
import 'package:dionysos/service/backup_import.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rdion_runtime/rdion_runtime.dart' show MediaType, ReleaseStatus;

/// Writes protobuf the way kotlinx-serialization does: unpacked repeated
/// fields and plain (non-zigzag) varints.
class _Proto {
  final _out = BytesBuilder();

  void _varint(int value) {
    var v = value;
    while (true) {
      final byte = v & 0x7f;
      v >>>= 7;
      if (v == 0) {
        _out.addByte(byte);
        return;
      }
      _out.addByte(byte | 0x80);
    }
  }

  _Proto int64(int field, int value) {
    _varint(field << 3);
    _varint(value);
    return this;
  }

  _Proto boolean(int field, {required bool value}) =>
      int64(field, value ? 1 : 0);

  _Proto bytes(int field, List<int> value) {
    _varint(field << 3 | 2);
    _varint(value.length);
    _out.add(value);
    return this;
  }

  _Proto string(int field, String value) => bytes(field, utf8.encode(value));

  _Proto message(int field, _Proto value) => bytes(field, value.build());

  _Proto float(int field, double value) {
    _varint(field << 3 | 5);
    _out.add(
      (ByteData(4)..setFloat32(0, value, Endian.little)).buffer.asUint8List(),
    );
    return this;
  }

  Uint8List build() => _out.toBytes();
}

Uint8List _gzip(Uint8List bytes) =>
    Uint8List.fromList(const GZipEncoder().encodeBytes(bytes));

_Proto _chapter(
  String url,
  int sourceOrder, {
  bool read = false,
  int page = 0,
}) => _Proto()
    .string(1, url)
    .string(2, 'Chapter $url')
    .boolean(4, value: read)
    .int64(6, page)
    .int64(8, 1700000000000)
    .float(9, 1.5)
    .int64(10, sourceOrder);

void main() {
  group('Mihon', () {
    test('converts library entries, chapters and categories', () {
      final backup = _Proto()
          .message(
            1,
            _Proto()
                .int64(1, 2499283573021220255)
                .string(2, '/manga/slug')
                .string(3, 'Title')
                .string(4, 'Artist')
                .string(5, 'Author')
                .string(6, 'Description')
                .string(7, 'Action')
                .string(7, 'Drama')
                .int64(8, 2)
                .string(9, 'https://example.com/cover.jpg')
                // Listed newest first, as sources return them.
                .message(16, _chapter('/c/3', 0, page: 4))
                .message(16, _chapter('/c/2', 1, read: true))
                .message(16, _chapter('/c/1', 2, read: true))
                .int64(17, 5)
                .message(
                  104,
                  _Proto()
                      .string(1, '/c/2')
                      .int64(2, 1700000000000)
                      .int64(3, 60000),
                )
                .string(110, 'my note'),
          )
          .message(
            1,
            _Proto()
                .int64(1, 1)
                .string(2, '/manga/not-in-library')
                .boolean(100, value: false),
          )
          .message(2, _Proto().string(1, 'Reading').int64(2, 5))
          .message(2, _Proto().string(1, 'Later').int64(2, 7))
          .message(
            101,
            _Proto().string(1, 'Example Source').int64(2, 2499283573021220255),
          )
          .build();

      final parsed = parseTachiyomiBackup(_gzip(backup));

      expect(parsed.app, 'Mihon');
      expect(parsed.categories.map((c) => c.name), ['Reading', 'Later']);
      expect(parsed.entries, hasLength(1));
      final entry = parsed.entries.single;
      final source = entry.source as TachiyomiSource;
      expect(source.id, 2499283573021220255);
      expect(source.name, 'Example Source');
      expect(mihonExtensionId(source.id), 'mihon:2499283573021220255');
      expect(entry.url, '/manga/slug');
      expect(entry.mediaType, MediaType.comic);
      expect(entry.status, ReleaseStatus.complete);
      expect(entry.authors, ['Author', 'Artist']);
      expect(entry.genres, ['Action', 'Drama']);
      expect(entry.categories, ['Reading']);
      expect(entry.note, 'my note');
      expect(entry.chapters.map((c) => c.url), ['/c/1', '/c/2', '/c/3']);
      expect(entry.chapters.map((c) => c.finished), [true, true, false]);
      expect(entry.chapters.last.progress, '4');
      expect(
        entry.chapters.first.uploaded,
        DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
      );
      expect(entry.history.single.chapterUrl, '/c/2');
      expect(entry.history.single.duration, const Duration(minutes: 1));
    });

    test('reads uncompressed backups and packed category lists', () {
      final backup = _Proto()
          .message(1, _Proto().int64(1, 7).string(2, '/m').bytes(17, [1, 2]))
          .message(2, _Proto().string(1, 'A').int64(2, 1))
          .message(2, _Proto().string(1, 'B').int64(2, 2))
          .build();

      final entry = parseTachiyomiBackup(backup).entries.single;

      expect(entry.categories, ['A', 'B']);
    });
  });

  test('Aniyomi anime use milliseconds as video progress, both layouts', () {
    _Proto anime(String url) => _Proto()
        .int64(1, 42)
        .string(2, url)
        .string(3, 'Anime')
        .string(500, 'https://example.com/bg.jpg')
        .message(
          16,
          _Proto()
              .string(1, '/e/1')
              .string(2, 'Episode 1')
              .int64(6, 90000)
              .string(503, 'https://example.com/preview.jpg'),
        )
        .int64(17, 0);
    final backup = _Proto()
        .message(3, anime('/legacy'))
        .message(4, _Proto().string(1, 'Watching'))
        .boolean(500, value: false)
        .message(501, anime('/current'))
        .message(502, _Proto().string(1, 'Watching'))
        .build();

    final parsed = parseTachiyomiBackup(_gzip(backup));

    expect(parsed.app, 'Aniyomi');
    expect(parsed.entries.map((e) => e.url), ['/legacy', '/current']);
    for (final entry in parsed.entries) {
      expect(entry.mediaType, MediaType.video);
      expect(entry.poster, 'https://example.com/bg.jpg');
      expect(entry.categories, ['Watching']);
      expect(entry.chapters.single.progress, '0:90000');
      expect(entry.chapters.single.cover, 'https://example.com/preview.jpg');
    }
  });

  test('Tsundoku novels become books without scroll progress', () {
    final backup = _Proto()
        .message(
          1,
          _Proto()
              .int64(1, 9)
              .string(2, '/novel')
              .string(3, 'Novel')
              .message(16, _chapter('/n/1', 0, page: 55))
              .boolean(8000, value: true)
              .string(8001, 'Alt'),
        )
        .build();

    final parsed = parseTachiyomiBackup(_gzip(backup));

    expect(parsed.app, 'Tsundoku');
    final entry = parsed.entries.single;
    expect(entry.mediaType, MediaType.book);
    expect(entry.altTitles, ['Alt']);
    expect(entry.chapters.single.progress, isNull);
  });

  group('LNReader', () {
    Archive archive(Map<String, Object> files) {
      final archive = Archive();
      for (final MapEntry(:key, :value) in files.entries) {
        archive.addFile(ArchiveFile.string(key, json.encode(value)));
      }
      return archive;
    }

    final novel = {
      'id': 10,
      'path': 'novel/slug/',
      'pluginId': 'royalroad',
      'name': 'Novel',
      'cover': 'https://example.com/c.png',
      'author': 'A, B',
      'status': 'Ongoing',
      'genres': 'Fantasy, Action',
      'inLibrary': 1,
      'isLocal': 0,
      'chapters': [
        {
          'id': 3,
          'path': 'p2/c1',
          'name': 'Page 2',
          'page': '2',
          'unread': true,
        },
        {
          'id': 2,
          'path': 'c2',
          'name': 'Two',
          'page': '1',
          'position': 1,
          'unread': false,
          'bookmark': 1,
          'readTime': '2024-01-02 03:04:05',
          'timeSpent': 5000,
        },
        {'id': 1, 'path': 'c1', 'name': 'One', 'page': '1', 'position': 0},
      ],
    };

    test('converts library novels, categories and history', () {
      final backup = archive({
        'Version.json': {'version': '2.0.0'},
        'Category.json': [
          {
            'id': 1,
            'name': 'Default',
            'sort': 1,
            'novelIds': [10],
          },
          {
            'id': 3,
            'name': 'Favourites',
            'sort': 3,
            'novelIds': [10],
          },
        ],
        'NovelAndChapters/10.json': novel,
        'NovelAndChapters/11.json': {
          ...novel,
          'id': 11,
          'path': 'browsed',
          'inLibrary': false,
        },
        'NovelAndChapters/12.json': {
          ...novel,
          'id': 12,
          'name': 'Local',
          'pluginId': 'local',
        },
      });

      expect(isLnReaderBackup(backup), isTrue);
      final parsed = parseLnReaderBackup(backup);

      expect(parsed.app, 'LNReader');
      expect(parsed.categories.map((c) => c.name), ['Favourites']);
      expect(parsed.skipped, hasLength(1));
      final entry = parsed.entries.single;
      final source = entry.source as LnReaderSource;
      expect(lnReaderExtensionId(source.pluginId), 'lnreader.royalroad');
      expect(entry.mediaType, MediaType.book);
      expect(entry.status, ReleaseStatus.releasing);
      expect(entry.authors, ['A', 'B']);
      expect(entry.genres, ['Fantasy', 'Action']);
      expect(entry.categories, ['Favourites']);
      expect(entry.chapters.map((c) => c.url), ['c1', 'c2', 'p2/c1']);
      expect(entry.chapters.map((c) => c.finished), [false, true, false]);
      expect(entry.chapters[1].bookmark, isTrue);
      expect(entry.history.single.chapterUrl, 'c2');
      expect(entry.history.single.duration, const Duration(seconds: 5));
    });

    test('reads the nested data archive of cloud backups', () {
      final inner = archive({'NovelAndChapters/10.json': novel});
      final outer = Archive()
        ..addFile(
          ArchiveFile.bytes('data.zip', ZipEncoder().encodeBytes(inner)),
        );

      expect(isLnReaderBackup(outer), isTrue);
      expect(parseLnReaderBackup(outer).entries.single.url, 'novel/slug/');
    });
  });

  group('extension ids', () {
    test('LNReader ids match the runtime adapter', () {
      expect(lnReaderExtensionId('royalroad'), 'lnreader.royalroad');
      expect(lnReaderExtensionId('FWN.com'), 'lnreader.FWN.com');
      expect(lnReaderExtensionId('a/b:c'), 'lnreader.a_b_c');
      expect(lnReaderExtensionId('a..b'), 'lnreader.a_b');
      expect(lnReaderDisplayName('ArNovel[madara]'), 'ArNovel');
      expect(lnReaderDisplayName('Royal Road'), 'Royal Road');
    });

    test('recognises Tsundoku JS plugin source ids', () {
      int javaHash(String value) {
        var hash = 0;
        for (final unit in value.codeUnits) {
          hash = (31 * hash + unit).toSigned(32);
        }
        return hash;
      }

      // Pins the Java String.hashCode port against a known value.
      expect(javaHash('hello'), 99162322);
      final id = javaHash('royal road/English/js') & 0x7fffffffffffffff;
      expect(isTsundokuJsSource(id, 'Royal Road'), isTrue);
      expect(isTsundokuJsSource(id + 1, 'Royal Road'), isFalse);
      // A negative Int keeps its sign-extended high bits in Kotlin.
      final negative = List.generate(
        100,
        (i) => 'Source $i',
      ).firstWhere((name) => javaHash('${name.toLowerCase()}/English/js') < 0);
      final negativeId =
          javaHash('${negative.toLowerCase()}/English/js') & 0x7fffffffffffffff;
      expect(negativeId, greaterThan(0xffffffff));
      expect(isTsundokuJsSource(negativeId, negative), isTrue);
    });
  });
}
