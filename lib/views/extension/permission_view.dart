import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/container/container.dart';
import 'package:dionysos/widgets/container/listtile.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';

class PermissionView extends StatefulWidget {
  const PermissionView({super.key, required this.extension});

  final Extension extension;

  @override
  State<PermissionView> createState() => _PermissionViewState();
}

class _PermissionViewState extends State<PermissionView>
    with StateDisposeScopeMixin {
  List<Permission>? permissions;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  @override
  void didUpdateWidget(covariant PermissionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.extension.id != widget.extension.id) {
      _loadPermissions();
    }
  }

  Future<void> _loadPermissions() async {
    setState(() {
      loading = true;
    });
    try {
      final perms = await widget.extension.getPermissions();
      if (mounted) {
        setState(() {
          permissions = perms;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _revokePermission(Permission permission) async {
    await widget.extension.removePermission(permission);
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

  @override
  Widget build(BuildContext context) {
    if (loading) {
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
}
