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
    String? sasSecret,
    String defaultServerUrl = officialServerUrl,
  }) {
    final String normalizedServer = _trimTrailingSlashes(serverUrl.trim());
    final String normalizedDefault = _trimTrailingSlashes(
      defaultServerUrl.trim(),
    );
    final String cleanToken = inviteToken.trim();
    final String? cleanSas = sasSecret?.trim();

    final List<String> params = <String>[
      if (normalizedServer.isNotEmpty && normalizedServer != normalizedDefault)
        'server=${Uri.encodeQueryComponent(normalizedServer)}',
      'token=${Uri.encodeQueryComponent(cleanToken)}',
      if (cleanSas != null && cleanSas.isNotEmpty)
        'sas=${Uri.encodeQueryComponent(cleanSas)}',
    ];

    return '$normalizedDefault/join#${params.join('&')}';
  }

  /// Formats a compact human-friendly link string for the copy bar without the `https://` prefix.
  static String formatCompactDisplayLink({
    required String serverUrl,
    required String inviteToken,
    String? sasSecret,
    String defaultServerUrl = officialServerUrl,
  }) {
    final String full = buildInviteUri(
      serverUrl: serverUrl,
      inviteToken: inviteToken,
      sasSecret: sasSecret,
      defaultServerUrl: defaultServerUrl,
    );
    return full.replaceFirst(RegExp(r'^https?://'), '');
  }

  /// Formats the compact manual pairing code `<inviteToken>.<sasSecret>` (`CA-01`).
  static String formatManualPairingCode({
    required String inviteToken,
    String? sasSecret,
  }) {
    final String cleanToken = inviteToken.trim();
    final String? cleanSas = sasSecret?.trim();
    if (cleanSas != null && cleanSas.isNotEmpty) {
      return '$cleanToken.$cleanSas';
    }
    return cleanToken;
  }

  /// Extracts an invite token, optional out-of-band `sasSecret`, and optional
  /// server URL from a raw token, `<token>.<sas>` manual code, `https://.../join#...`,
  /// `deepsky://pair?...`, or `/c/<token>` path.
  static ({String? serverUrl, String inviteToken, String? sasSecret})
  parseInviteInput(String rawInput) {
    final checked = parseInviteInputChecked(rawInput);
    return (
      serverUrl: checked.serverUrl,
      inviteToken: checked.inviteToken,
      sasSecret: checked.sasSecret,
    );
  }

  /// Same as [parseInviteInput], but also reports when a `server=` parameter
  /// or origin was rejected (for example non-local plain `http://` URLs).
  static ({
    String? serverUrl,
    String inviteToken,
    String? sasSecret,
    String? rejectedServerError,
  })
  parseInviteInputChecked(String rawInput) {
    final String trimmed = rawInput.trim();
    if (trimmed.isEmpty) {
      return (
        serverUrl: null,
        inviteToken: '',
        sasSecret: null,
        rejectedServerError: null,
      );
    }

    final Uri? uri = _tryParseLink(trimmed);
    if (uri != null) {
      if (uri.fragment.isNotEmpty) {
        final Map<String, String> fragParams = _parseKeyValueFragment(
          uri.fragment,
        );
        final String? fragToken = fragParams['token']?.trim();
        if (fragToken != null && fragToken.isNotEmpty) {
          final serverRes = _cleanOptionalServerChecked(fragParams['server']);
          final String? fragSas = _cleanOptionalNonEmpty(fragParams['sas']);
          return (
            serverUrl: serverRes.serverUrl,
            inviteToken: fragToken,
            sasSecret: fragSas,
            rejectedServerError: serverRes.error,
          );
        }
      }

      final String? queryToken = uri.queryParameters['token']?.trim();
      if (queryToken != null && queryToken.isNotEmpty) {
        final serverRes = _cleanOptionalServerChecked(
          uri.queryParameters['server'],
        );
        final String? querySas = _cleanOptionalNonEmpty(
          uri.queryParameters['sas'],
        );
        return (
          serverUrl: serverRes.serverUrl,
          inviteToken: queryToken,
          sasSecret: querySas,
          rejectedServerError: serverRes.error,
        );
      }

      if (uri.pathSegments.length >= 2 && uri.pathSegments.first == 'c') {
        final String pathToken = uri.pathSegments[1].trim();
        if (pathToken.isNotEmpty) {
          final String origin = '${uri.scheme}://${uri.authority}';
          final serverRes = _cleanOptionalServerChecked(origin);
          return (
            serverUrl: serverRes.serverUrl,
            inviteToken: pathToken,
            sasSecret: null,
            rejectedServerError: serverRes.error,
          );
        }
      }
    }

    if (uri == null && !RegExp(r'\s').hasMatch(trimmed)) {
      final List<String> dotParts = trimmed.split('.');
      if (dotParts.length == 2 &&
          dotParts[0].isNotEmpty &&
          dotParts[1].isNotEmpty) {
        return (
          serverUrl: null,
          inviteToken: dotParts[0],
          sasSecret: dotParts[1],
          rejectedServerError: null,
        );
      }
    }

    return (
      serverUrl: null,
      inviteToken: trimmed,
      sasSecret: null,
      rejectedServerError: null,
    );
  }

  static String? _cleanOptionalNonEmpty(String? raw) {
    final String? trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  /// Normalizes user-entered server addresses (e.g., `casa.mioserver.it` or `192.168.1.100:8080`).
  ///
  /// Requires `https` for non-local/non-private addresses.
  /// Throws [FormatException] when empty, malformed, or insecure HTTP on a public host.
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
    if (parsed.scheme == 'http' && !_isLocalOrPrivateHost(parsed.host)) {
      throw const FormatException(
        'HTTPS is required for non-local server addresses.',
      );
    }
    return _trimTrailingSlashes(parsed.toString());
  }

  /// Returns whether [serverUrl] matches [defaultServerUrl] (the official server).
  static bool isOfficialServer(
    String serverUrl, {
    String defaultServerUrl = officialServerUrl,
  }) {
    try {
      final String normalizedCandidate = normalizeServerUrl(serverUrl)
          .toLowerCase();
      final String normalizedDefault = normalizeServerUrl(defaultServerUrl)
          .toLowerCase();
      return normalizedCandidate == normalizedDefault;
    } on FormatException {
      return false;
    }
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

  static ({String? serverUrl, String? error}) _cleanOptionalServerChecked(
    String? rawServer,
  ) {
    if (rawServer == null || rawServer.trim().isEmpty) {
      return (serverUrl: null, error: null);
    }
    try {
      return (serverUrl: normalizeServerUrl(rawServer), error: null);
    } on FormatException catch (ex) {
      return (serverUrl: null, error: ex.message);
    }
  }

  static String _trimTrailingSlashes(String value) {
    return value.replaceAll(RegExp(r'/+$'), '');
  }

  static bool _isLocalOrPrivateHost(String host) {
    final String lower = host.toLowerCase();
    if (lower == 'localhost' ||
        lower == '127.0.0.1' ||
        lower == '10.0.2.2' ||
        lower == '::1' ||
        lower == '[::1]') {
      return true;
    }
    if (lower.startsWith('192.168.') || lower.startsWith('10.')) {
      return true;
    }
    final RegExp rfc172 = RegExp(r'^172\.(1[6-9]|2\d|3[0-1])\.');
    return rfc172.hasMatch(lower);
  }
}
