import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/container/container.dart';
import 'package:dionysos/widgets/container/listtile.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:flutter/material.dart';
import 'package:dionysos/utils/log.dart';

class AccountsView extends StatelessWidget {
  const AccountsView({super.key, required this.extension});

  final Extension extension;

  @override
  Widget build(BuildContext context) {
    if (extension.accounts.isEmpty) {
      return DionContainer(
        type: ContainerType.outlined,
        child: Row(
          children: [
            Icon(
              Icons.person_outline,
              size: 20,
              color: context.theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'No accounts configured',
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
          'Accounts',
          style: context.titleMedium?.copyWith(
            color: context.theme.colorScheme.primary,
          ),
        ).paddingSymmetric(horizontal: 16, vertical: 8),
        ...extension.accounts.map((account) => _AccountTile(account: account)),
      ],
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account});

  final Account account;

  Future<void> _authenticateAccount(BuildContext context) async {
    try {
      await account.auth();
    } catch (e) {
      logger.e('Authentication failed for account ${account.domain}', error: e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication failed: $e'),
            backgroundColor: context.theme.colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _logoutAccount() async {
    await account.logout();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: account,
      builder: (context, _) {
        final isLoggedIn = account.isLoggedIn;
        return DionContainer(
          type: ContainerType.outlined,
          child: DionListTile(
            leading: account.cover != null
                ? DionImage(imageUrl: account.cover, width: 48, height: 48)
                : Icon(
                    Icons.account_circle,
                    size: 48,
                    color: context.theme.colorScheme.primary,
                  ),
            title: Text(
              account.userName ?? 'Unknown User',
              style: context.bodyMedium,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.domain,
                  style: context.bodySmall?.copyWith(
                    color: context.theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      isLoggedIn ? Icons.check_circle : Icons.pending,
                      size: 14,
                      color: isLoggedIn
                          ? context.theme.colorScheme.primary
                          : context.theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isLoggedIn ? 'Logged in' : 'Not logged in',
                      style: context.bodySmall?.copyWith(
                        color: context.theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: DionIconbutton(
              tooltip: isLoggedIn ? 'Logout' : 'Login',
              icon: Icon(
                isLoggedIn ? Icons.logout : Icons.login,
                color: context.theme.colorScheme.primary,
              ),
              onPressed: () =>
                  isLoggedIn ? _logoutAccount() : _authenticateAccount(context),
            ),
          ),
        ).paddingSymmetric(horizontal: 16, vertical: 4);
      },
    );
  }
}
