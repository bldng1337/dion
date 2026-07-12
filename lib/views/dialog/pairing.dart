import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/main.dart';
import 'package:dionysos/service/lansync/lansync_service.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/dialog.dart';
import 'package:flutter/material.dart';

class PairingConfirmDialog extends StatelessWidget {
  final String peerName;
  final String peerFingerprint;
  final String sasCode;

  const PairingConfirmDialog({
    super.key,
    required this.peerName,
    required this.peerFingerprint,
    required this.sasCode,
  });

  @override
  Widget build(BuildContext context) {
    return DionAlertDialog(
      title: Row(
        children: [
          Icon(Icons.devices, color: context.theme.colorScheme.primary),
          const SizedBox(width: DionSpacing.sm),
          Text('Pair Device', style: context.titleLarge),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"$peerName" wants to pair with this device for library sync.',
              style: context.bodyMedium,
            ),
            const SizedBox(height: DionSpacing.lg),
            Text(
              'Verify the code matches on both devices:',
              style: context.bodySmall,
            ),
            const SizedBox(height: DionSpacing.sm),
            Center(
              child: Text(
                _formatSas(sasCode),
                style: context.displaySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 6,
                  color: context.theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: DionSpacing.lg),
            Text('Device fingerprint:', style: context.bodySmall),
            const SizedBox(height: DionSpacing.xs),
            Container(
              padding: const EdgeInsets.all(DionSpacing.sm),
              decoration: BoxDecoration(
                color: context.surfaceMuted,
                borderRadius: DionRadius.small,
                border: Border.all(color: context.borderColor),
              ),
              child: SelectableText(
                _formatFingerprint(peerFingerprint),
                style: context.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: context.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        DionTextbutton(
          type: ButtonType.ghost,
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Deny'),
        ),
        DionTextbutton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Accept'),
        ),
      ],
    );
  }

  static String _formatSas(String code) {
    if (code.length != 6) return code;
    return '${code.substring(0, 3)} ${code.substring(3)}';
  }

  static String _formatFingerprint(String fp) {
    if (fp.length < 16) return fp;
    final groups = <String>[];
    for (var i = 0; i + 1 < fp.length; i += 2) {
      groups.add(fp.substring(i, i + 2));
    }
    final joined = groups.join(':');
    // Show first and last groups with an ellipsis to keep it compact.
    if (joined.length > 40) {
      return '${joined.substring(0, 23)}…${joined.substring(joined.length - 16)}';
    }
    return joined;
  }
}

void registerPairingDialog() {
  LanSyncService.showPairingConfirm =
      ({
        required String peerName,
        required String peerFingerprint,
        required String sasCode,
      }) async {
        final context = navigatorKey.currentContext;
        if (context == null) return false;
        final result = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => PairingConfirmDialog(
            peerName: peerName,
            peerFingerprint: peerFingerprint,
            sasCode: sasCode,
          ),
        );
        return result ?? false;
      };
}
