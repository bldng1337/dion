import 'dart:async';

import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/data/entry/entry_detailed.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/extension.dart';
import 'package:dionysos/data/settings/extension_setting.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/utils/version.dart';
import 'package:dionysos/widgets/dynamic_grid.dart';
import 'package:flutter/widgets.dart' show ChangeNotifier;
import 'package:pub_semver/pub_semver.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

// ignore: avoid_implementing_value_types
class MockExtension with ChangeNotifier implements Extension {
  /// Stable identifier of the mock extension. Also used as the bound
  /// extension id of every placeholder [Entry] it produces.
  static const String mockId = 'dion.mock.debug';

  MockExtension() : _meta = const ExtensionMetaData(mockId, true);

  ExtensionMetaData _meta;

  /// Placeholder metadata. Non-const because `extensionType` holds a
  /// freezed value with custom equality, which cannot live in a const set.
  static final rust.ExtensionData _data = rust.ExtensionData(
    id: mockId,
    name: 'Mock',
    url: 'https://www.example.com',
    icon: 'https://loremflickr.com/200/200?random=1',
    desc:
        'Inbuilt debug/test mock extension. Returns placeholder entries '
        'across all media types. Only present in debug builds.',
    author: const ['dion-debug'],
    tags: const ['mock', 'debug', 'test'],
    lang: const ['en'],
    nsfw: false,
    mediaType: const {
      rust.MediaType.video,
      rust.MediaType.comic,
      rust.MediaType.audio,
      rust.MediaType.book,
    },
    extensionType: {const rust.ExtensionType.entryProvider(hasSearch: true)},
    version: '1.0.0',
    license: 'MIT',
    compatible: true,
  );

  @override
  rust.ExtensionData get data => _data;

  @override
  ExtensionMetaData get meta => _meta;

  @override
  set meta(ExtensionMetaData value) {
    // The real extension persists this to the DB; the mock is not persisted.
    _meta = value;
    notifyListeners();
  }

  @override
  bool isenabled = true;

  @override
  bool loading = false;

  @override
  List<Account> get accounts => const [];

  @override
  Map<
    rust.SettingKind,
    List<Setting<dynamic, ExtensionSettingMetaData<dynamic>>>
  >
  get settings => _settings;

  static final Map<
    rust.SettingKind,
    List<Setting<dynamic, ExtensionSettingMetaData<dynamic>>>
  >
  _settings = {for (final kind in rust.SettingKind.values) kind: const []};

  @override
  String get id => data.id;

  @override
  String get name => 'Mock';

  @override
  bool get searchEnabled => _meta.searchEnabled;

  @override
  set searchEnabled(bool value) {
    if (_meta.searchEnabled != value) {
      meta = _meta.copyWith(searchEnabled: value);
    }
  }

  @override
  Version get version => parseVersion(data.version);

  // -- Data-producing methods -------------------------------------------------

  /// All placeholder entries served by the mock, shared by [browse] and
  /// [search]. Deterministic so demos and tests are reproducible.
  static final List<EntryImpl> _entries = _buildEntries();

  @override
  DataSource<Entry> browse({rust.CancelToken? token}) {
    return PageAsyncSource((page) async {
      if (page != 0) return Page.last(const []);
      return Page.last(_entries);
    })..name = name;
  }

  @override
  DataSource<Entry> search(String filter, {rust.CancelToken? token}) {
    final lower = filter.toLowerCase();
    return PageAsyncSource((page) async {
      if (page != 1) return Page.last(const []);
      final hits = _entries
          .where((e) => e.title.toLowerCase().contains(lower))
          .toList(growable: false);
      return Page.last(hits);
    })..name = name;
  }

  @override
  Future<EntryDetailed> detail(Entry e, {rust.CancelToken? token}) {
    if (e.boundExtensionId != id) {
      throw Exception(
        'Extension mismatch: expected $id, got ${e.boundExtensionId}',
      );
    }
    return Future.value(_buildDetailed(e));
  }

  @override
  Future<SourcePath> source(EpisodePath ep, {rust.CancelToken? token}) {
    final source = switch (ep.entry.mediaType) {
      rust.MediaType.book => _bookSource(ep),
      rust.MediaType.comic => _comicSource(ep),
      rust.MediaType.video => _videoSource(),
      rust.MediaType.audio => _audioSource(),
      _ => _bookSource(ep),
    };
    return Future.value(SourcePath(ep, source));
  }

  // -- Proxy-touching methods (safe no-ops) ----------------------------------

  @override
  Future<void> enable() async {
    if (isenabled || loading) return;
    loading = true;
    notifyListeners();
    isenabled = true;
    loading = false;
    notifyListeners();
  }

  @override
  Future<void> disable() async {
    if (!isenabled || loading) return;
    loading = true;
    notifyListeners();
    isenabled = false;
    loading = false;
    notifyListeners();
  }

  @override
  Future<void> toggle() async {
    if (isenabled) {
      await disable();
    } else {
      await enable();
    }
  }

  @override
  Future<void> save() async {}

  @override
  Future<List<rust.Permission>> getPermissions() async => const [];

  @override
  Future<void> removePermission(rust.Permission permission) async {}

  @override
  Future<rust.EventResult?> event({
    required rust.EventData event,
    rust.CancelToken? token,
  }) async => null;

  @override
  Future<bool> handleUrl(String url, {rust.CancelToken? token}) async => false;

  @override
  Future<void> onEntryActivity(
    rust.EntryActivity activity,
    EntryDetailed entry,
    Map<String, rust.Setting> settings, {
    rust.CancelToken? token,
  }) async {}

  @override
  Future<void> runAction(rust.Action action, {rust.CancelToken? token}) async {}

  @override
  Future<EntrySaved> refreshEntryExtension(
    EntrySaved e,
    Extension extension, {
    rust.CancelToken? token,
  }) async => e;

  @override
  T getExtensionType<T extends rust.ExtensionType>() {
    final extType = getExtensionTypeOrNull<T>();
    if (extType == null) {
      throw Exception('Extension type $T not found for extension $id');
    }
    return extType;
  }

  @override
  T? getExtensionTypeOrNull<T extends rust.ExtensionType>() {
    return data.extensionType.whereType<T>().firstOrNull;
  }

  @override
  void dispose() {
    // The real extension disposes its rust proxy here; the mock has none.
    super.dispose();
  }

  // -- Placeholder content ----------------------------------------------------

  static rust.Source _bookSource(EpisodePath ep) {
    final chapter = ep.episodenumber + 1;
    return rust.Source.paragraphlist(
      paragraphs: [
        rust.Paragraph.text(
          content: 'Chapter $chapter — Mock Content',
          style: const rust.TextStyle(bold: true, fontSize: 22),
        ),
        const rust.Paragraph.text(
          content:
              'This is placeholder paragraph content generated by the mock '
              'extension. It exercises the paragraph reader (and TTS) without '
              'requiring a real source extension to be installed.',
        ),
        const rust.Paragraph.text(
          content:
              'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed '
              'do eiusmod tempor incididunt ut labore et dolore magna aliqua. '
              'Ut enim ad minim veniam, quis nostrud exercitation ullamco '
              'laboris nisi ut aliquip ex ea commodo consequat.',
        ),
        const rust.Paragraph.text(
          content:
              'Duis aute irure dolor in reprehenderit in voluptate velit '
              'esse cillum dolore eu fugiat nulla pariatur. Excepteur sint '
              'occaecat cupidatat non proident, sunt in culpa qui officia '
              'deserunt mollit anim id est laborum.',
          style: rust.TextStyle(italic: true),
        ),
      ],
    );
  }

  static rust.Source _comicSource(EpisodePath ep) {
    final page = ep.episodenumber + 1;
    return rust.Source.imagelist(
      links: [
        for (var i = 1; i <= 3; i++)
          rust.Link(
            url:
                'https://placehold.co/800x1200/2A2A2A/FFFFFF/png'
                '?text=Mock+Comic+$page.$i',
          ),
      ],
    );
  }

  static const _sampleVideo =
      'https://commondatastorage.googleapis.com/'
      'gtv-videos-bucket/sample/BigBuckBunny.mp4';

  static rust.Source _videoSource() {
    return const rust.Source.video(
      sources: [
        rust.StreamSource(
          name: 'Mock Stream',
          lang: 'en',
          url: rust.Link(url: _sampleVideo),
        ),
      ],
      sub: [],
    );
  }

  static const _sampleAudio =
      'https://actions.google.com/sounds/viral/ambient-music-1.ogg';

  static rust.Source _audioSource() {
    return const rust.Source.audio(
      sources: [
        rust.StreamSource(
          name: 'Mock Audio',
          lang: 'en',
          url: rust.Link(url: _sampleAudio),
        ),
      ],
    );
  }

  EntryDetailed _buildDetailed(Entry e) {
    final episodeCount = _episodeCountFor(e.mediaType);
    return EntryDetailedImpl(
      rust.EntryDetailed(
        id: e.id,
        url: e.url,
        titles: [e.title],
        author: e.author,
        mediaType: e.mediaType,
        status: rust.ReleaseStatus.unknown,
        description:
            'Mock placeholder entry generated by the debug mock extension '
            '(${e.mediaType.name}). Useful for demos and for testing the '
            '${_readerName(e.mediaType)} reader end-to-end.',
        language: 'en',
        cover: e.cover,
        episodes: [
          for (var i = 1; i <= episodeCount; i++)
            rust.Episode(
              id: rust.EpisodeId(uid: '${e.id.uid}-ep-$i'),
              name: _episodeName(e.mediaType, i),
              description: 'Mock episode $i',
              url: '${e.url}/episode/$i',
            ),
        ],
        genres: ['mock', 'debug', e.mediaType.name],
        rating: e.rating,
        views: e.views,
        length: e.length,
      ),
      id,
      const {},
    );
  }

  static String _readerName(rust.MediaType type) => switch (type) {
    rust.MediaType.book => 'paragraph',
    rust.MediaType.comic => 'image list',
    rust.MediaType.video => 'video',
    rust.MediaType.audio => 'audio',
    rust.MediaType.unknown => 'unknown',
  };

  static int _episodeCountFor(rust.MediaType type) => switch (type) {
    rust.MediaType.book => 5,
    rust.MediaType.comic => 4,
    rust.MediaType.video => 3,
    _ => 3,
  };

  static String _episodeName(rust.MediaType type, int i) => switch (type) {
    rust.MediaType.book => 'Chapter $i',
    rust.MediaType.comic => 'Issue #$i',
    _ => 'Episode $i',
  };

  static List<EntryImpl> _buildEntries() {
    const specs = <_EntrySpec>[
      _EntrySpec(
        uid: 'mock-book-1',
        title: 'The Mock Manifesto',
        type: rust.MediaType.book,
        rating: 4.8,
        views: 12345,
      ),
      _EntrySpec(
        uid: 'mock-book-2',
        title: 'Debug Days',
        type: rust.MediaType.book,
        rating: 4.2,
        views: 9876,
      ),
      _EntrySpec(
        uid: 'mock-book-3',
        title: 'Null Pointer Nights',
        type: rust.MediaType.book,
        rating: 3.9,
        views: 5432,
      ),
      _EntrySpec(
        uid: 'mock-comic-1',
        title: 'Captain Placeholder',
        type: rust.MediaType.comic,
        rating: 4.5,
        views: 7654,
      ),
      _EntrySpec(
        uid: 'mock-comic-2',
        title: 'The Assertive Avenger',
        type: rust.MediaType.comic,
        rating: 4.1,
        views: 4321,
      ),
      _EntrySpec(
        uid: 'mock-comic-3',
        title: 'Stack Trace Sally',
        type: rust.MediaType.comic,
        rating: 4.7,
        views: 8901,
      ),
      _EntrySpec(
        uid: 'mock-video-1',
        title: 'Big Buck Mock',
        type: rust.MediaType.video,
        rating: 4.0,
        views: 2024,
      ),
      _EntrySpec(
        uid: 'mock-video-2',
        title: 'Render Royale',
        type: rust.MediaType.video,
        rating: 3.5,
        views: 1492,
      ),
      _EntrySpec(
        uid: 'mock-audio-1',
        title: 'Ambient Mockwave',
        type: rust.MediaType.audio,
        rating: 4.3,
        views: 3344,
      ),
      _EntrySpec(
        uid: 'mock-audio-2',
        title: 'The Lo-Fi Logfile',
        type: rust.MediaType.audio,
        rating: 4.6,
        views: 6789,
      ),
      _EntrySpec(
        uid: 'mock-book-4',
        title: 'Garbage Collected',
        type: rust.MediaType.book,
        rating: 4.9,
        views: 11223,
      ),
      _EntrySpec(
        uid: 'mock-comic-4',
        title: 'The Hot Reloader',
        type: rust.MediaType.comic,
        rating: 4.4,
        views: 5566,
      ),
    ];

    return [
      for (final s in specs)
        EntryImpl(
          rust.Entry(
            id: rust.EntryId(uid: s.uid),
            url: 'https://www.example.com',
            title: s.title,
            mediaType: s.type,
            cover: rust.Link(
              url:
                  'https://placehold.co/300x450/1F1F1F/FFFFFF/png?text=${Uri.encodeComponent(s.title)}',
            ),
            author: const ['Mock Author'],
            rating: s.rating,
            views: s.views,
            length: _episodeCountFor(s.type),
          ),
          mockId,
        ),
    ];
  }
}

class _EntrySpec {
  final String uid;
  final String title;
  final rust.MediaType type;
  final double rating;
  final double views;
  const _EntrySpec({
    required this.uid,
    required this.title,
    required this.type,
    required this.rating,
    required this.views,
  });
}
