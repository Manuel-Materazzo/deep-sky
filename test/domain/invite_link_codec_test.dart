import 'package:deep_sky/domain/pairing/invite_link_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InviteLinkCodec', () {
    test('buildInviteUri uses fragment-only token and sas for official server', () {
      final String uri = InviteLinkCodec.buildInviteUri(
        serverUrl: 'https://deepsky.vectevo.com/',
        inviteToken: 'tok_abc123',
        sasSecret: 'sas_oob_secret',
      );
      expect(
        uri,
        'https://deepsky.vectevo.com/join#token=tok_abc123&sas=sas_oob_secret',
      );
    });

    test(
      'buildInviteUri encodes custom server and sas inside URI fragment',
      () {
        final String uri = InviteLinkCodec.buildInviteUri(
          serverUrl: 'http://192.168.1.100:8080/',
          inviteToken: 'tok_xyz',
          sasSecret: 'sas_xyz',
        );
        expect(
          uri,
          'https://deepsky.vectevo.com/join#server=http%3A%2F%2F192.168.1.100%3A8080&token=tok_xyz&sas=sas_xyz',
        );
      },
    );

    test('formatCompactDisplayLink strips scheme prefix', () {
      final String compact = InviteLinkCodec.formatCompactDisplayLink(
        serverUrl: 'https://deepsky.vectevo.com',
        inviteToken: 'tok_123',
        sasSecret: 'sas_123',
      );
      expect(compact, 'deepsky.vectevo.com/join#token=tok_123&sas=sas_123');
    });

    test('formatManualPairingCode and parseInviteInput handle token.sas', () {
      final String code = InviteLinkCodec.formatManualPairingCode(
        inviteToken: 'tok_manual',
        sasSecret: 'sas_secret_part',
      );
      expect(code, 'tok_manual.sas_secret_part');
      final parsed = InviteLinkCodec.parseInviteInput(code);
      expect(parsed.serverUrl, isNull);
      expect(parsed.inviteToken, 'tok_manual');
      expect(parsed.sasSecret, 'sas_secret_part');
    });

    test(
      'parseInviteInput decodes fragment token and sas with official default',
      () {
        final parsed = InviteLinkCodec.parseInviteInput(
          'https://deepsky.vectevo.com/join#token=tok_official&sas=sas_frag_1',
        );
        expect(parsed.serverUrl, isNull);
        expect(parsed.inviteToken, 'tok_official');
        expect(parsed.sasSecret, 'sas_frag_1');
      },
    );

    test(
      'parseInviteInput decodes fragment custom server and compact link',
      () {
        final parsedFull = InviteLinkCodec.parseInviteInput(
          'https://deepsky.vectevo.com/join#server=https%3A%2F%2Fcasa.mioserver.it&token=tok_custom&sas=sas_custom',
        );
        expect(parsedFull.serverUrl, 'https://casa.mioserver.it');
        expect(parsedFull.inviteToken, 'tok_custom');
        expect(parsedFull.sasSecret, 'sas_custom');

        final parsedCompact = InviteLinkCodec.parseInviteInput(
          'deepsky.vectevo.com/join#token=tok_compact',
        );
        expect(parsedCompact.serverUrl, isNull);
        expect(parsedCompact.inviteToken, 'tok_compact');
        expect(parsedCompact.sasSecret, isNull);
      },
    );

    test('parseInviteInput supports legacy deepsky://pair and /c/<token>', () {
      final legacyScheme = InviteLinkCodec.parseInviteInput(
        'deepsky://pair?server=https%3A%2F%2Fcustom.example&token=tok_legacy&sas=sas_legacy',
      );
      expect(legacyScheme.serverUrl, 'https://custom.example');
      expect(legacyScheme.inviteToken, 'tok_legacy');
      expect(legacyScheme.sasSecret, 'sas_legacy');

      final legacyPath = InviteLinkCodec.parseInviteInput(
        'https://casa.example/c/tok_path',
      );
      expect(legacyPath.serverUrl, 'https://casa.example');
      expect(legacyPath.inviteToken, 'tok_path');
      expect(legacyPath.sasSecret, isNull);
    });

    test('parseInviteInput preserves raw token input with null sasSecret', () {
      final raw = InviteLinkCodec.parseInviteInput('  tok_raw_123  ');
      expect(raw.serverUrl, isNull);
      expect(raw.inviteToken, 'tok_raw_123');
      expect(raw.sasSecret, isNull);
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
        expect(
          () => InviteLinkCodec.normalizeServerUrl('http://evil.example.com'),
          throwsFormatException,
        );
        expect(
          InviteLinkCodec.normalizeServerUrl('http://172.16.10.4:8080/'),
          'http://172.16.10.4:8080',
        );
      },
    );

    test('parseInviteInputChecked rejects insecure http:// non-local server in link', () {
      final checked = InviteLinkCodec.parseInviteInputChecked(
        'deepsky://pair#server=http%3A%2F%2Fevil.example&token=tok_evil',
      );
      expect(checked.serverUrl, isNull);
      expect(checked.inviteToken, 'tok_evil');
      expect(checked.rejectedServerError, isNotNull);

      expect(
        InviteLinkCodec.isOfficialServer('https://deepsky.vectevo.com/'),
        isTrue,
      );
      expect(
        InviteLinkCodec.isOfficialServer('https://casa.mioserver.it'),
        isFalse,
      );
    });

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
