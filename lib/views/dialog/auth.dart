import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/service/applinks.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/service/network.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/dialog.dart';
import 'package:dionysos/widgets/dion_textbox.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:flutter/material.dart' show Icons, FocusNode, TextInputType;
import 'package:flutter/widgets.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;
import 'package:rhttp/rhttp.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';

/// Stateless router that displays the appropriate authentication dialog
/// based on the account's authentication data type.
class AuthDialog extends StatelessWidget {
  final Account account;
  const AuthDialog({super.key, required this.account});

  @override
  Widget build(BuildContext context) {
    return account.authData.when(
      cookie: (loginpage, logonpage) =>
          UnsupportedAuthDialog(account: account, authType: 'Cookie'),
      apiKey: () => ApiKeyAuthDialog(account: account),
      userPass: () => UserPassAuthDialog(account: account),
      oAuth: (authorizationUrl, tokenUrl, clientId, clientSecret, scope) =>
          OAuthAuthDialog(account: account),
    );
  }
}

/// Dialog for API key authentication.
class ApiKeyAuthDialog extends StatefulWidget {
  final Account account;
  const ApiKeyAuthDialog({super.key, required this.account});

  @override
  State<ApiKeyAuthDialog> createState() => _ApiKeyAuthDialogState();
}

class _ApiKeyAuthDialogState extends State<ApiKeyAuthDialog> {
  late final TextEditingController _apiKeyController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'API Key cannot be empty');
      return;
    }
    Navigator.of(context).pop(rust.AuthCreds.apiKey(key: key));
  }

  @override
  Widget build(BuildContext context) {
    return DionAlertDialog(
      title: Text('API Key Authentication', style: context.titleLarge),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your API key for ${widget.account.extension.name}',
              style: context.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text('Domain: ${widget.account.domain}', style: context.bodyMedium),
            const SizedBox(height: 16),
            DionTextbox(
              controller: _apiKeyController,
              autofocus: true,
              keyboardType: TextInputType.visiblePassword,
              onSubmitted: (_) => _handleSubmit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: context.bodySmall?.copyWith(
                  color: context.theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        DionTextbutton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(null),
        ),
        DionTextbutton(
          onPressed: _handleSubmit,
          child: const Text('Authenticate'),
        ),
      ],
    );
  }
}

/// Dialog for username/password authentication.
class UserPassAuthDialog extends StatefulWidget {
  final Account account;
  const UserPassAuthDialog({super.key, required this.account});

  @override
  State<UserPassAuthDialog> createState() => _UserPassAuthDialogState();
}

class _UserPassAuthDialogState extends State<UserPassAuthDialog> {
  late final TextEditingController _usernameController =
      TextEditingController();
  late final TextEditingController _passwordController =
      TextEditingController();
  late final FocusNode _passwordFocusNode = FocusNode();
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Username and password cannot be empty');
      return;
    }

    Navigator.of(
      context,
    ).pop(rust.AuthCreds.userPass(username: username, password: password));
  }

  @override
  Widget build(BuildContext context) {
    return DionAlertDialog(
      title: Text('Login', style: context.titleLarge),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Login to ${widget.account.extension.name}',
              style: context.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text('Domain: ${widget.account.domain}', style: context.bodyMedium),
            const SizedBox(height: 16),
            Text('Username', style: context.bodySmall),
            const SizedBox(height: 4),
            DionTextbox(
              controller: _usernameController,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              onSubmitted: (_) => _passwordFocusNode.requestFocus(),
            ),
            const SizedBox(height: 12),
            Text('Password', style: context.bodySmall),
            const SizedBox(height: 4),
            DionTextbox(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              obscureText: true,
              onSubmitted: (_) => _handleSubmit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: context.bodySmall?.copyWith(
                  color: context.theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        DionTextbutton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(null),
        ),
        DionTextbutton(onPressed: _handleSubmit, child: const Text('Login')),
      ],
    );
  }
}

/// Dialog for OAuth authentication.
class OAuthAuthDialog extends StatefulWidget {
  final Account account;
  const OAuthAuthDialog({super.key, required this.account});

  @override
  State<OAuthAuthDialog> createState() => _OAuthAuthDialogState();
}

class _OAuthAuthDialogState extends State<OAuthAuthDialog>
    with StateDisposeScopeMixin {
  bool _loading = false;
  String? _error;

  Future<void> _handleOAuth() async {
    final authData = widget.account.authData;
    if (authData is! rust.AuthData_OAuth) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final appLinks = locate<AppLinksService>();

      // Build callback URL
      final callbackUrl = Uri(
        scheme: AppLinksService.customScheme,
        host: widget.account.domain,
        path: '/oauth',
      );

      // Listen for OAuth callback
      appLinks.linkStream
          .listen((uri) async {
            if (uri.scheme == AppLinksService.customScheme &&
                uri.host == widget.account.domain &&
                uri.path == '/oauth') {
              if (authData.tokenUrl != null) {
                final network = locate<NetworkService>();
                // Exchange authorization code for access token
                final params = uri.queryParameters;
                final code = params['code'];
                if (code == null) {
                  setState(() {
                    _error = 'Authorization code not found in callback';
                    _loading = false;
                  });
                }
                final response = await network.client.post(
                  authData.tokenUrl!,
                  body: HttpBody.json({
                    'grant_type': 'authorization_code',
                    'client_id': authData.clientId,
                    'client_secret': authData.clientSecret,
                    'redirect_uri': callbackUrl.toString(),
                    'code': code,
                  }),
                  headers: const HttpHeaders.map({
                    HttpHeaderName.contentType: 'application/json',
                    HttpHeaderName.accept: 'application/json',
                  }),
                );
                final json = response.bodyToJson;
                final token = json['access_token'] as String?;
                if (token == null) {
                  setState(() {
                    _error =
                        'Failed to obtain access token from token endpoint';
                    _loading = false;
                  });
                  return;
                }
                if (!mounted) {
                  return;
                }
                Navigator.of(
                  context,
                ).pop(rust.AuthCreds.oAuth(accessToken: token));
                return;
              }
              // Extract access token from query parameters or fragment
              final params = uri.queryParameters;
              final accessToken =
                  params['access_token'] ??
                  (uri.fragment.isNotEmpty
                      ? Uri.splitQueryString(uri.fragment)['access_token']
                      : null);
              final refreshToken =
                  params['refresh_token'] ??
                  (uri.fragment.isNotEmpty
                      ? Uri.splitQueryString(uri.fragment)['refresh_token']
                      : null);
              final expiresIn =
                  params['expires_in'] ??
                  (uri.fragment.isNotEmpty
                      ? Uri.splitQueryString(uri.fragment)['expires_in']
                      : null);
              final expiresAt = expiresIn != null
                  ? int.tryParse(expiresIn)
                  : null;

              if (accessToken != null) {
                Navigator.of(context).pop(
                  rust.AuthCreds.oAuth(
                    accessToken: accessToken,
                    refreshToken: refreshToken,
                    expiresAt: expiresAt,
                  ),
                );
              } else {
                setState(() {
                  _error = 'Failed to extract access token from callback';
                  _loading = false;
                });
              }
            }
          })
          .disposedBy(scope);

      // Launch OAuth URL with callback URL
      final authUri = Uri.parse(authData.authorizationUrl);
      final authUriWithCallback = authUri.replace(
        queryParameters: {
          ...authUri.queryParameters,
          'redirect_uri': callbackUrl.toString(),
          'client_id': authData.clientId,
          'response_type': 'code',
        },
      );
      final success = await launchUrl(
        authUriWithCallback,
        mode: LaunchMode.externalApplication,
      );

      if (!success) {
        setState(() {
          _error = 'Failed to launch OAuth URL';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'OAuth error: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DionAlertDialog(
      title: Text('OAuth Authentication', style: context.titleLarge),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Authorize ${widget.account.extension.name}',
              style: context.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text('Domain: ${widget.account.domain}', style: context.bodyMedium),
            const SizedBox(height: 16),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: DionProgressBar(),
                ),
              )
            else if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: context.theme.colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: context.bodyMedium?.copyWith(
                          color: context.theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                'Click below to authorize this app via OAuth. You will be redirected to the provider\'s website.',
                style: context.bodyMedium,
              ),
          ],
        ),
      ),
      actions: _loading
          ? []
          : [
              DionTextbutton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(null),
              ),
              if (_error == null)
                DionTextbutton(
                  onPressed: _handleOAuth,
                  child: const Text('Authorize'),
                ),
            ],
    );
  }
}

/// Dialog for unsupported authentication types.
class UnsupportedAuthDialog extends StatelessWidget {
  final Account account;
  final String authType;
  const UnsupportedAuthDialog({
    super.key,
    required this.account,
    required this.authType,
  });

  @override
  Widget build(BuildContext context) {
    return DionAlertDialog(
      title: Text('Authentication Required', style: context.titleLarge),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Extension: ${account.extension.name}',
              style: context.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text('Domain: ${account.domain}', style: context.bodyMedium),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: context.theme.colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$authType authentication is not yet supported.',
                      style: context.bodyMedium?.copyWith(
                        color: context.theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        DionTextbutton(
          child: const Text('Close'),
          onPressed: () => Navigator.of(context).pop(null),
        ),
      ],
    );
  }
}
