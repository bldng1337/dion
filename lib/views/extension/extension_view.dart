import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/container/badge.dart';
import 'package:dionysos/widgets/container/container.dart';
import 'package:dionysos/widgets/container/listtile.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:dionysos/widgets/foldabletext.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/dion_runtime.dart';
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
  List<Permission>? permissions;
  bool loadingPermissions = false;

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
      _loadPermissions();
    } catch (e) {
      error = e;
    }
  }

  Future<void> _loadPermissions() async {
    if (extension == null) return;
    setState(() {
      loadingPermissions = true;
    });
    try {
      final perms = await extension!.getPermissions();
      if (mounted) {
        setState(() {
          permissions = perms;
          loadingPermissions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loadingPermissions = false;
        });
      }
    }
  }

  Future<void> _revokePermission(Permission permission) async {
    if (extension == null) return;
    await extension!.removePermission(permission);
    await _loadPermissions();
  }

  String _getPermissionTitle(Permission permission) {
    return switch (permission) {
      Permission_Storage() => 'Storage Access',
      Permission_Network() => 'Network Access',
      Permission_ActionPopup() => 'Action Popup',
      Permission_ArbitraryNetwork() => 'Unrestricted Network Access',
    };
  }

  IconData _getPermissionIcon(Permission permission) {
    return switch (permission) {
      Permission_Storage() => Icons.folder,
      Permission_Network() => Icons.wifi,
      Permission_ActionPopup() => Icons.web_asset,
      Permission_ArbitraryNetwork() => Icons.public,
    };
  }

  String _getPermissionDescription(Permission permission) {
    return switch (permission) {
      Permission_Storage(:final path, :final write) =>
        'Path: $path (${write ? 'Read & Write' : 'Read Only'})',
      Permission_Network(:final domains) => 'Domains: ${domains.join(', ')}',
      Permission_ActionPopup() => 'Can display action popups',
      Permission_ArbitraryNetwork() => 'Can access any network domain',
    };
  }

  Widget _buildPermissionsSection(BuildContext context) {
    if (loadingPermissions) {
      return const DionProgressBar().paddingAll(16);
    }

    if (permissions == null || permissions!.isEmpty) {
      return DionContainer(
        type: ContainerType.outlined,
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 20,
              color: context.theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'No permissions granted',
              style: context.bodyMedium?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ).paddingAll(12),
      ).paddingSymmetric(horizontal: 16, vertical: 8);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Granted Permissions',
          style: context.titleMedium?.copyWith(
            color: context.theme.colorScheme.primary,
          ),
        ).paddingSymmetric(horizontal: 16, vertical: 8),
        ...permissions!.map(
          (permission) => DionContainer(
            type: ContainerType.outlined,
            child: DionListTile(
              leading: Icon(
                _getPermissionIcon(permission),
                color: context.theme.colorScheme.primary,
              ),
              title: Text(
                _getPermissionTitle(permission),
                style: context.bodyMedium,
              ),
              subtitle: Text(
                _getPermissionDescription(permission),
                style: context.bodySmall?.copyWith(
                  color: context.theme.colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: DionIconbutton(
                tooltip: 'Revoke permission',
                icon: Icon(
                  Icons.delete_outline,
                  color: context.theme.colorScheme.error,
                ),
                onPressed: () => _revokePermission(permission),
              ),
            ),
          ).paddingSymmetric(horizontal: 16, vertical: 4),
        ),
      ],
    );
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
                  _buildPermissionsSection(context),
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
