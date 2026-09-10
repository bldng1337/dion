import 'dart:async';
import 'dart:io';

import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/service/cache.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/directoryprovider.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/utils/debounce.dart';
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/internetfile.dart';
import 'package:dionysos/utils/keyed_mutex.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

/// What an image is stored for; selects the enabling setting.
enum ImageStoreKind { entryCover, quoteImage, extensionIcon }

class ImageStoreService {
  final Directory dir;
  final _stored = <String>{};
  final _mutex = KeyedMutex();

  /// Urls whose download failed; suppressed until restart so recurring saves
  /// do not retry dead links endlessly.
  final _failed = <String>{};

  /// Last seen image-hash signature per entry, so a cover/poster/quote image
  /// change on refresh or edit can schedule a prune of the replaced files.
  final _entrySignatures = <String, String>{};

  late final _pruneDebouncer = Debouncer(
    duration: const Duration(seconds: 5),
    action: () => unawaited(prune()),
  );

  ImageStoreService(this.dir);

  static Future<void> ensureInitialized() async {
    final dir = (await locateAsync<DirectoryProvider>()).imagepath;
    await dir.create(recursive: true);
    final store = ImageStoreService(dir);
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final hash = fileNameToHash(entity.filename);
      if (hash != null) {
        store._stored.add(hash);
      }
    }
    logger.i(
      'ImageStoreService initialized with ${store._stored.length} images',
    );
    register<ImageStoreService>(store);
    // Self-heal orphans from entries/extensions removed while the app was
    // closed (e.g. via device sync), which never hit the event hooks.
    store.schedulePrune();
  }

  /// The local copy of [url], or null when the service is not up or the url
  /// is not stored. Safe to call from anywhere.
  static File? maybeStored(String url) {
    if (!has<ImageStoreService>()) return null;
    return locate<ImageStoreService>().storedFile(url);
  }

  /// Only http(s) urls are downloadable; file links (used by some extension
  /// adapters) are already local and mihon:/data: schemes are not fetched.
  static bool downloadable(String? url) {
    if (url == null || url.isEmpty) return false;
    if (isFileUrl(url)) return false;
    if (url.startsWith('mihon:')) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  Setting<bool, dynamic> _settingFor(ImageStoreKind kind) {
    return switch (kind) {
      ImageStoreKind.entryCover => settings.autoDownload.entryCovers,
      ImageStoreKind.quoteImage => settings.autoDownload.quoteImages,
      ImageStoreKind.extensionIcon => settings.autoDownload.extensionIcons,
    };
  }

  /// The local copy of [url], or null when it is not stored.
  File? storedFile(String url) {
    if (!_stored.contains(hashUrl(url))) return null;
    return targetFile(url);
  }

  bool isStored(String url) => _stored.contains(hashUrl(url));

  /// Stores [url] permanently unless disabled by setting, already stored,
  /// not downloadable, or known to have failed before. Never throws.
  ///
  /// Returns the stored file, or null when nothing was (or had to be) stored.
  Future<File?> store(
    ImageStoreKind kind,
    String url, {
    Map<String, String>? headers,
  }) async {
    try {
      if (!downloadable(url)) return null;
      if (!_settingFor(kind).value) return null;
      final existing = storedFile(url);
      if (existing != null && existing.existsSync()) return existing;
      final hash = hashUrl(url);
      if (_failed.contains(hash)) return null;
      return await _mutex.run(hash, () => _store(url, headers));
    } catch (e, stack) {
      logger.w('Failed to store image $url', error: e, stackTrace: stack);
      return null;
    }
  }

  /// Convenience for [rust.Link]-shaped images (covers, quote images).
  Future<void> storeLink(ImageStoreKind kind, rust.Link? link) async {
    if (link == null) return;
    await store(kind, link.url, headers: link.header);
  }

  /// Tracks the entry's stored-image footprint; schedules a prune when it
  /// changed (cover/poster swapped on refresh, quote image removed) so the
  /// replaced files get collected.
  void noteEntryImages(EntrySaved entry) {
    final signature = imageSignature(entryImageHashes(entry));
    final dbId = entry.dbId.toString();
    final previous = _entrySignatures[dbId];
    _entrySignatures[dbId] = signature;
    if (previous != null && previous != signature) {
      schedulePrune();
    }
  }

  /// The entry is gone; its images become prune candidates.
  void forgetEntry(EntrySaved entry) {
    _entrySignatures.remove(entry.dbId.toString());
    schedulePrune();
  }

  /// Schedules a [prune], coalescing bursts (bulk deletes, migrations).
  void schedulePrune() => _pruneDebouncer.run();

  /// Deletes every stored file that no saved entry or installed extension
  /// references anymore.
  Future<void> prune() async {
    await _mutex.run('prune', () async {
      try {
        final referenced = await _collectReferences();
        await for (final entity in dir.list()) {
          if (entity is! File) continue;
          final hash = fileNameToHash(entity.filename);
          // Not created by this store; leave it alone.
          if (hash == null || referenced.contains(hash)) continue;
          try {
            await entity.delete();
            _stored.remove(hash);
          } catch (e, stack) {
            logger.w(
              'Failed to delete orphaned image ${entity.path}',
              error: e,
              stackTrace: stack,
            );
          }
        }
      } catch (e, stack) {
        logger.w('Image store prune failed', error: e, stackTrace: stack);
      }
    });
  }

  Future<Set<String>> _collectReferences() async {
    final hashes = <String>{};
    if (!has<Database>() || !has<ExtensionService>()) return hashes;
    final db = locate<Database>();
    final seenEntries = <String>{};
    var page = 0;
    while (true) {
      var any = false;
      await for (final entry in db.getEntries(page, 100)) {
        any = true;
        final dbId = entry.dbId.toString();
        seenEntries.add(dbId);
        final entryHashes = entryImageHashes(entry);
        hashes.addAll(entryHashes);
        // Keeps the change-detection signatures exact, and drops signatures
        // of entries removed without going through forgetEntry (e.g. remote
        // sync deletions).
        _entrySignatures[dbId] = imageSignature(entryHashes);
      }
      if (!any) break;
      page++;
    }
    _entrySignatures.removeWhere((dbId, _) => !seenEntries.contains(dbId));
    for (final ext in locate<ExtensionService>().getExtensions()) {
      hashes.add(hashUrl(ext.data.icon));
    }
    return hashes;
  }

  /// Urls of an entry that may have a stored copy.
  static Iterable<String?> entryImageUrls(EntrySaved entry) {
    return [
      entry.cover?.url,
      entry.poster?.url,
      for (final data in entry.episodedata)
        for (final image in data.images) image.url,
    ];
  }

  static Set<String> entryImageHashes(EntrySaved entry) =>
      imageHashes(entryImageUrls(entry));

  static Set<String> imageHashes(Iterable<String?> urls) => {
    for (final url in urls)
      if (url != null && url.isNotEmpty) hashUrl(url),
  };

  /// Order-independent fingerprint of an image set.
  static String imageSignature(Set<String> hashes) =>
      (hashes.toList()..sort()).join(',');

  Future<File?> _store(String url, Map<String, String>? headers) async {
    final target = targetFile(url);
    if (await target.exists() && await target.length() > 0) {
      _stored.add(hashUrl(url));
      return target;
    }

    // Prefer copying out of the image cache: if the image was displayed
    // before, this stores it without a second network download.
    if (has<CacheService>()) {
      try {
        final cached = await locate<CacheService>()
            .imgcache
            .getFileFromCache(url)
            .then((info) => info?.file);
        if (cached != null &&
            await cached.exists() &&
            await cached.length() > 0) {
          await cached.copy(target.path);
          _stored.add(hashUrl(url));
          return target;
        }
      } catch (e, stack) {
        logger.w(
          'Failed to reuse cached image for $url',
          error: e,
          stackTrace: stack,
        );
      }
    }

    try {
      await InternetFile.streamToFile(url, target, headers: headers);
      _stored.add(hashUrl(url));
      return target;
    } catch (e, stack) {
      _failed.add(hashUrl(url));
      if (await target.exists()) {
        await target.delete();
      }
      logger.w('Failed to download image $url', error: e, stackTrace: stack);
      return null;
    }
  }

  File targetFile(String url) {
    return InternetFile.fromURI(url, dir, filename: hashUrl(url));
  }

  /// FNV-1a 64; deterministic and stable across restarts, which plain
  /// [String.hashCode] is not. Masked to 62 bits so the hex form is always
  /// positive and exactly 16 characters long.
  static String hashUrl(String url) {
    var hash = 0xcbf29ce484222325;
    for (final code in url.codeUnits) {
      hash ^= code;
      hash = (hash * 0x100000001b3) & 0x3FFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  /// Inverse of [targetFile] naming: extracts the hash prefix from a file
  /// name, or null when the name was not created by this service.
  static String? fileNameToHash(String filename) {
    final base = filename.split('.').first;
    if (base.length != 16) return null;
    return base;
  }
}
