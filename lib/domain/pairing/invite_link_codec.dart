/// Generates and parses Deep Sky invite links and normalizes server URLs.
///
/// Invite links place the server URL (when custom) and the one-time invite
/// token in the URI fragment (`#...`) so browser previews never send the
/// secret token to the static hosting server (`S1-INF-01`).
class InviteLinkCodec {
  const InviteLinkCodec._();

  static const String officialServerUrl = 'https://deepsky.vectevo.com';

  /// Builds the shareable HTTPS invite URL encoded in the QR code and copy/share actions.
  static String buildInviteUri({
    required String serverUrl,
    required String inviteToken,
    String defaultServerUrl = officialServerUrl,
  }) {
    final String normalizedServer = _trimTrailingSlashes(serverUrl.trim());
    final String normalizedDefault = _trimTrailingSlashes(
      defaultServerUrl.trim(),
    );
    final String cleanToken = inviteToken.trim();

    final String fragment =
        normalizedServer.isEmpty || normalizedServer == normalizedDefault
        ? 'token=${Uri.encodeQueryComponent(cleanToken)}'
        : 'server=${Uri.encodeQueryComponent(normalizedServer)}&token=${Uri.encodeQueryComponent(cleanToken)}';

    return '$normalizedDefault/join#$fragment';
  }

  /// Formats a compact human-friendly link string for the copy bar without the `https://` prefix.
  static String formatCompactDisplayLink({
    required String serverUrl,
    required String inviteToken,
    String defaultServerUrl = officialServerUrl,
  }) {
    final String full = buildInviteUri(
      serverUrl: serverUrl,
      inviteToken: inviteToken,
      defaultServerUrl: defaultServerUrl,
    );
    return full.replaceFirst(RegExp(r'^https?://'), '');
  }

  /// Extracts an invite token and optional server URL from a raw token,
  /// `https://.../join#...` link, `deepsky://pair?...` link, or `/c/<token>` path.
  static ({String? serverUrl, String inviteToken}) parseInviteInput(
    String rawInput,
  ) {
    final String trimmed = rawInput.trim();
    if (trimmed.isEmpty) {
      return (serverUrl: null, inviteToken: '');
    }

    final Uri? uri = _tryParseLink(trimmed);
    if (uri != null) {
      if (uri.fragment.isNotEmpty) {
        final Map<String, String> fragParams = _parseKeyValueFragment(
          uri.fragment,
        );
        final String? fragToken = fragParams['token']?.trim();
        if (fragToken != null && fragToken.isNotEmpty) {
          final String? fragServer = _cleanOptionalServer(fragParams['server']);
          return (serverUrl: fragServer, inviteToken: fragToken);
        }
      }

      final String? queryToken = uri.queryParameters['token']?.trim();
      if (queryToken != null && queryToken.isNotEmpty) {
        final String? queryServer = _cleanOptionalServer(
          uri.queryParameters['server'],
        );
        return (serverUrl: queryServer, inviteToken: queryToken);
      }

      if (uri.pathSegments.length >= 2 && uri.pathSegments.first == 'c') {
        final String pathToken = uri.pathSegments[1].trim();
        if (pathToken.isNotEmpty) {
          final String origin = '${uri.scheme}://${uri.authority}';
          return (serverUrl: origin, inviteToken: pathToken);
        }
      }
    }

    return (serverUrl: null, inviteToken: trimmed);
  }

  /// Normalizes user-entered server addresses (e.g., `casa.mioserver.it` or `192.168.1.100:8080`).
  ///
  /// Throws [FormatException] when empty or malformed.
  static String normalizeServerUrl(String rawInput) {
    final String trimmed = _trimTrailingSlashes(rawInput.trim());
    if (trimmed.isEmpty) {
      throw const FormatException('Empty server address.');
    }

    final String withScheme;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      withScheme = trimmed;
    } else {
      final String hostPart = trimmed.split('/').first.split(':').first;
      final String scheme = _isLocalOrPrivateHost(hostPart) ? 'http' : 'https';
      withScheme = '$scheme://$trimmed';
    }

    final Uri? parsed = Uri.tryParse(withScheme);
    if (parsed == null ||
        !parsed.hasScheme ||
        !parsed.hasAuthority ||
        parsed.host.isEmpty ||
        (parsed.scheme != 'http' && parsed.scheme != 'https')) {
      throw const FormatException('Invalid server URL.');
    }
    return _trimTrailingSlashes(parsed.toString());
  }

  /// Extracts a compact host label (e.g. `deepsky.vectevo.com` or `192.168.1.100:8080`).
  static String displayHost(String serverUrl) {
    final Uri? uri = Uri.tryParse(serverUrl.trim());
    if (uri == null || uri.host.isEmpty) {
      return serverUrl.trim();
    }
    return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
  }

  static Uri? _tryParseLink(String raw) {
    final Uri? direct = Uri.tryParse(raw);
    if (direct != null && direct.hasScheme && direct.authority.isNotEmpty) {
      return direct;
    }
    if (!raw.contains(' ') &&
        (raw.contains('.com/') ||
            raw.contains('.it/') ||
            raw.contains('/join#') ||
            raw.contains('/c/'))) {
      return Uri.tryParse('https://$raw');
    }
    return null;
  }

  static Map<String, String> _parseKeyValueFragment(String fragment) {
    if (!fragment.contains('=')) {
      return const <String, String>{};
    }
    try {
      return Uri.splitQueryString(fragment);
    } catch (_) {
      return const <String, String>{};
    }
  }

  static String? _cleanOptionalServer(String? rawServer) {
    if (rawServer == null || rawServer.trim().isEmpty) {
      return null;
    }
    try {
      return normalizeServerUrl(rawServer);
    } on FormatException {
      return null;
    }
  }

  static String _trimTrailingSlashes(String value) {
    return value.replaceAll(RegExp(r'/+$'), '');
  }

  static bool _isLocalOrPrivateHost(String host) {
    final String lower = host.toLowerCase();
    if (lower == 'localhost' || lower == '127.0.0.1' || lower == '10.0.2.2') {
      return true;
    }
    if (lower.startsWith('192.168.') || lower.startsWith('10.')) {
      return true;
    }
    final RegExp rfc172 = RegExp(r'^172\.(1[6-9]|2\d|3[0-1])\.');
    return rfc172.hasMatch(lower);
  }
}
