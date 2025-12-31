import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/main.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/container/container.dart';
import 'package:dionysos/widgets/dialog.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:flutter/material.dart';

/// Dialog for requesting permission from the user for an extension
class PermissionRequestDialog extends StatelessWidget {
  final ExtensionData extensionData;
  final Permission permission;
  final String? message;

  const PermissionRequestDialog({
    super.key,
    required this.extensionData,
    required this.permission,
    this.message,
  });

  String _getPermissionTitle() {
    return switch (permission) {
      Permission_Storage() => 'Storage Access',
      Permission_Network() => 'Network Access',
      Permission_ActionPopup() => 'Action Popup',
      Permission_ArbitraryNetwork() => 'Unrestricted Network Access',
    };
  }

  IconData _getPermissionIcon() {
    return switch (permission) {
      Permission_Storage() => Icons.folder,
      Permission_Network() => Icons.wifi,
      Permission_ActionPopup() => Icons.web_asset,
      Permission_ArbitraryNetwork() => Icons.public,
    };
  }

  Widget _buildPermissionDetails(BuildContext context) {
    return switch (permission) {
      Permission_Storage(:final path, :final write) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Path: $path', style: context.bodyMedium),
          Text(
            'Access: ${write ? 'Read & Write' : 'Read Only'}',
            style: context.bodyMedium,
          ),
        ],
      ),
      Permission_Network(:final domains) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Domains:', style: context.bodyMedium),
          ...domains.map(
            (domain) => Text('  • $domain', style: context.bodySmall),
          ),
        ],
      ),
      Permission_ActionPopup() => Text(
        'This extension wants to display action popups.',
        style: context.bodyMedium,
      ),
      Permission_ArbitraryNetwork() => Text(
        'This extension wants unrestricted network access to any domain.',
        style: context.bodyMedium?.copyWith(color: Colors.orange),
      ),
    };
  }

  String _getExtensionName() {
    return extensionData.name.replaceAll('-', ' ').capitalize;
  }

  @override
  Widget build(BuildContext context) {
    return DionAlertDialog(
      title: Row(
        children: [
          Icon(_getPermissionIcon(), size: 24),
          const SizedBox(width: 8),
          Text('Permission Request', style: context.titleLarge),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Extension info
            DionContainer(
              type: ContainerType.outlined,
              child: Row(
                children: [
                  DionImage(
                    imageUrl: extensionData.icon,
                    width: 48,
                    height: 48,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getExtensionName(),
                          style: context.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'v${extensionData.version}',
                          style: context.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ).paddingAll(12),
            ),
            const SizedBox(height: 16),

            // Permission type
            Text(
              _getPermissionTitle(),
              style: context.titleMedium?.copyWith(
                color: context.theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),

            // Permission details
            _buildPermissionDetails(context),

            // Optional message from extension
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 16),
              DionContainer(
                type: ContainerType.filled,
                color: context.theme.colorScheme.surfaceContainerHighest,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        message!,
                        style: context.bodyMedium?.copyWith(
                          color: context.theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ).paddingAll(12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        DionTextbutton(
          type: ButtonType.ghost,
          onPressed: () {
            Navigator.of(context).pop(false);
          },
          child: const Text('Deny'),
        ),
        DionTextbutton(
          onPressed: () {
            Navigator.of(context).pop(true);
          },
          child: const Text('Allow'),
        ),
      ],
    );
  }
}

/// Shows a permission request dialog and returns whether the user granted permission.
/// Uses the global navigatorKey to show the dialog.
Future<bool> requestPermissionFromUser({
  required ExtensionData extensionData,
  required Permission permission,
  String? message,
}) async {
  final context = navigatorKey.currentContext;
  if (context == null) {
    return false;
  }

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PermissionRequestDialog(
      extensionData: extensionData,
      permission: permission,
      message: message,
    ),
  );
  return result ?? false;
}
