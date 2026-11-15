import 'package:deep_sky/domain/pairing/invite_link_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InviteLinkCodec', () {
    test('buildInviteUri uses fragment-only token for official server', () {
      final String uri = InviteLinkCodec.buildInviteUri(
        serverUrl: 'https://deepsky.vectevo.com/',
        inviteToken: 'tok_abc123',
      );
      expect(uri, 'https://deepsky.vectevo.com/join#token=tok_abc123');
    });

    test('buildInviteUri encodes custom server inside URI fragment', () {
      final String uri = InviteLinkCodec.buildInviteUri(
        serverUrl: 'http://192.168.1.100:8080/',
        inviteToken: 'tok_xyz',
      );
      expect(
        uri,
        'https://deepsky.vectevo.com/join#server=http%3A%2F%2F192.168.1.100%3A8080&token=tok_xyz',
      );
    });

    test('formatCompactDisplayLink strips scheme prefix', () {
      final String compact = InviteLinkCodec.formatCompactDisplayLink(
        serverUrl: 'https://deepsky.vectevo.com',
        inviteToken: 'tok_123',
      );
      expect(compact, 'deepsky.vectevo.com/join#token=tok_123');
    });

    test('parseInviteInput decodes fragment token with official default', () {
      final parsed = InviteLinkCodec.parseInviteInput(
        'https://deepsky.vectevo.com/join#token=tok_official',
      );
      expect(parsed.serverUrl, isNull);
      expect(parsed.inviteToken, 'tok_official');
    });

    test(
      'parseInviteInput decodes fragment custom server and compact link',
      () {
        final parsedFull = InviteLinkCodec.parseInviteInput(
          'https://deepsky.vectevo.com/join#server=https%3A%2F%2Fcasa.mioserver.it&token=tok_custom',
        );
        expect(parsedFull.serverUrl, 'https://casa.mioserver.it');
        expect(parsedFull.inviteToken, 'tok_custom');

        final parsedCompact = InviteLinkCodec.parseInviteInput(
          'deepsky.vectevo.com/join#token=tok_compact',
        );
        expect(parsedCompact.serverUrl, isNull);
        expect(parsedCompact.inviteToken, 'tok_compact');
      },
    );

    test('parseInviteInput supports legacy deepsky://pair and /c/<token>', () {
      final legacyScheme = InviteLinkCodec.parseInviteInput(
        'deepsky://pair?server=https%3A%2F%2Fcustom.example&token=tok_legacy',
      );
      expect(legacyScheme.serverUrl, 'https://custom.example');
      expect(legacyScheme.inviteToken, 'tok_legacy');

      final legacyPath = InviteLinkCodec.parseInviteInput(
        'https://casa.example/c/tok_path',
      );
      expect(legacyPath.serverUrl, 'https://casa.example');
      expect(legacyPath.inviteToken, 'tok_path');
    });

    test('parseInviteInput preserves raw token input', () {
      final raw = InviteLinkCodec.parseInviteInput('  tok_raw_123  ');
      expect(raw.serverUrl, isNull);
      expect(raw.inviteToken, 'tok_raw_123');
    });

    test(
      'normalizeServerUrl infers https for domains and http for LAN hosts',
      () {
        expect(
          InviteLinkCodec.normalizeServerUrl('casa.mioserver.it/'),
          'https://casa.mioserver.it',
        );
        expect(
          InviteLinkCodec.normalizeServerUrl('192.168.1.100:8080'),
          'http://192.168.1.100:8080',
        );
        expect(
          InviteLinkCodec.normalizeServerUrl('10.0.2.2:8080/'),
          'http://10.0.2.2:8080',
        );
        expect(
          InviteLinkCodec.normalizeServerUrl('localhost:8080'),
          'http://localhost:8080',
        );
        expect(
          () => InviteLinkCodec.normalizeServerUrl('   '),
          throwsFormatException,
        );
      },
    );

    test('displayHost extracts host and optional port', () {
      expect(
        InviteLinkCodec.displayHost('https://deepsky.vectevo.com'),
        'deepsky.vectevo.com',
      );
      expect(
        InviteLinkCodec.displayHost('http://192.168.1.100:8080'),
        '192.168.1.100:8080',
      );
    });
  });
}
