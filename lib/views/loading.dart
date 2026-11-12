import 'dart:async';

import 'package:dionysos/service/applinks.dart';
import 'package:dionysos/service/backup.dart';
import 'package:dionysos/service/cache.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/directoryprovider.dart';
import 'package:dionysos/service/downloads.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/service/extension_updates.dart';
import 'package:dionysos/service/image_store.dart';
import 'package:dionysos/service/lansync/lansync_service.dart';
import 'package:dionysos/service/network.dart';
import 'package:dionysos/service/notification.dart';
import 'package:dionysos/service/periodic_service.dart';
import 'package:dionysos/service/player.dart';
import 'package:dionysos/service/task.dart';
import 'package:dionysos/utils/restart.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/update.dart';
import 'package:dionysos/views/dialog/pairing.dart';
import 'package:dionysos/widgets/app_loader.dart';
import 'package:dionysos/widgets/dialog.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppLoader(
      actions: [
        const ErrorAction(label: 'Restart', onTap: restartApp),
        ErrorAction(
          label: 'Delete Data',
          onTap: () async {
            final confirmed = await showConfirmDialog(
              context,
              title: 'Delete All Data',
              message:
                  'Permanently delete your library, downloads, extensions and '
                  'settings? This cannot be undone.',
              confirmLabel: 'Delete',
              destructive: true,
            );
            if (!confirmed) return;
            final dir = await locateAsync<DirectoryProvider>();
            await dir.clear();
            await restartApp();
          },
        ),
      ],
      tasks: [
        (
          'Database',
          () async {
            await Database.ensureInitialized();
          },
        ),
        (
          'TaskManager',
          () async {
            await TaskManager.ensureInitialized();
          },
        ),
        (
          'DownloadService',
          () async {
            await DownloadService.ensureInitialized();
          },
        ),
        (
          'LAN sync',
          () async {
            await LanSyncService.ensureInitialized();
            registerPairingDialog();
          },
        ),
        (
          'SourceExtension',
          () async {
            await ExtensionService.ensureInitialized();
          },
        ),
        (
          'DirectoryProvider',
          () async {
            await DirectoryProvider.ensureInitialized();
          },
        ),
        (
          'CacheService',
          () async {
            await CacheService.ensureInitialized();
          },
        ),
        (
          'ImageStoreService',
          () async {
            await ImageStoreService.ensureInitialized();
          },
        ),
        (
          'MediaKit',
          () async {
            MediaKit.ensureInitialized();
          },
        ),
        (
          'NetworkService',
          () async {
            await NetworkService.ensureInitialized();
          },
        ),
        (
          'PlayerService',
          () async {
            await PlayerService.ensureInitialized();
          },
        ),
        (
          'AppLinksService',
          () async {
            await AppLinksService.ensureInitialized();
          },
        ),
        (
          'NotificationService',
          () async {
            await NotificationService.ensureInitialized();
          },
        ),
        (
          'ExtensionUpdateService',
          () async {
            await ExtensionUpdateService.ensureInitialized();
          },
        ),
        (
          'PeriodicService',
          () async {
            await PeriodicService.ensureInitialized();
          },
        ),
        (
          'BackupService',
          () async {
            await BackupService.ensureInitialized();
          },
        ),
      ],
      onComplete: (context) async {
        await Future.delayed(const Duration(milliseconds: 1));
        if (context.mounted) {
          context.go('/library');
        }
        // Apply the link the app was launched with now that every service it
        // might need is up; a view it opens replaces the library, a link
        // that cannot be handled leaves it.
        final pending = locate<AppLinksService>().takePendingLink();
        if (pending != null) {
          await locate<AppLinksService>().handleLink(pending, coldStart: true);
        }
        unawaited(checkVersion());
      },
    );
  }
}
