import 'package:dionysos/service/cache.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/directoryprovider.dart';
import 'package:dionysos/service/downloads.dart';
import 'package:dionysos/service/network.dart';
import 'package:dionysos/service/player.dart';
import 'package:dionysos/service/preference.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/service/task.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/update.dart';
import 'package:dionysos/widgets/app_loader.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:restart_app/restart_app.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppLoader(
      actions: [
        ErrorAction(label: 'Restart', onTap: () => Restart.restartApp()),
        ErrorAction(
          label: 'Delete Data',
          onTap: () async {
            final dir = await locateAsync<DirectoryProvider>();
            await dir.clear();
            Restart.restartApp();
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
          'PreferenceService',
          () async {
            await PreferenceService.ensureInitialized();
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
          'Checking for updates',
          () async {
            await checkVersion();
          },
        ),
      ],
      onComplete: (context) async {
        await Future.delayed(const Duration(milliseconds: 1));
        if (context.mounted) {
          context.go('/library');
        }
      },
    );
  }
}
