import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/service/directoryprovider.dart';
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/storage.dart';
import 'package:dionysos/widgets/container/badge.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:dionysos/widgets/foldabletext.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/dion_runtime.dart';
import 'package:dionysos/views/extension/account_view.dart';
import 'package:dionysos/views/extension/permission_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';

class ExtensionView extends StatefulWidget {
  const ExtensionView({super.key});

  @override
  _ExtensionViewState createState() => _ExtensionViewState();
}

class _ExtensionViewState extends State<ExtensionView>
    with StateDisposeScopeMixin {
  Extension? extension;
  Object? error;
  int? _extensionSize;

  @override
  void initState() {
    scope.addDispose(() async {
      await extension?.save();
    });
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final ext = locate<ExtensionService>().getExtension(
        GoRouterState.of(context).pathParameters['id']!,
      );
      setState(() {
        extension = ext;
      });
      _calculateExtensionSize();
    } catch (e) {
      error = e;
    }
  }

  Future<void> _calculateExtensionSize() async {
    if (extension == null) return;
    try {
      final dirProvider = await locateAsync<DirectoryProvider>();
      final extensionPath = dirProvider.extensionpath.sub('dion_extensions').sub('data').sub(extension!.id);
      final size = await getDirectorySize(extensionPath);
      if (mounted) {
        setState(() {
          _extensionSize = size;
        });
      }
    } catch (e) {
      logger.w('Failed to calculate extension size', error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return NavScaff(
        title: Text('Error Loading ${extension?.name ?? ''}'),
        child: Center(child: ErrorDisplay(e: error)),
      );
    }
    if (extension == null) {
      return const NavScaff(
        title: Text('Loading ...'),
        child: Center(child: DionProgressBar()),
      );
    }
    return NavScaff(
      child: Column(
        children: [
          Row(
            children: [
              DionImage(
                imageUrl: extension!.data.icon,
                width: 100,
                height: 100,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(extension!.name, style: context.titleLarge),
                      DionBadge(
                        child: Text(
                          extension!.data.version,
                          style: context.bodyMedium,
                        ),
                      ).paddingAll(5),
                    ],
                  ),
                  if (extension!.data.author.isNotEmpty)
                    Text(
                      'by ${extension!.data.author}',
                      style: context.bodyMedium,
                    ),
                  if (_extensionSize != null)
                    Text(
                      'Storage: ${formatBytes(_extensionSize!)}',
                      style: context.bodySmall,
                    ),
                ],
              ).paddingAll(10),
            ],
          ).paddingAll(30),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (extension!.data.desc != null &&
                      extension!.data.desc!.isNotEmpty) ...[
                    Foldabletext(
                      extension!.data.desc ?? '',
                      style: context.bodyMedium,
                    ),
                    const Divider(),
                  ],
                  // Permissions section
                  PermissionView(extension: extension!),
                  const Divider(),
                  // Accounts section
                  AccountsView(extension: extension!),
                  const Divider(),
                  // Settings section
                  for (final e in extension!.settings[SettingKind.extension_]!)
                    DionRuntimeSettingView(setting: e),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
