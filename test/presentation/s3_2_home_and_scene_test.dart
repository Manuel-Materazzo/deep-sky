import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:deep_sky/data/content_pack_service.dart';
import 'package:deep_sky/data/encrypted_local_cache.dart';
import 'package:deep_sky/data/secure_key_store.dart';
import 'package:deep_sky/domain/crypto/deep_sky_crypto.dart';
import 'package:deep_sky/domain/crypto/e2ee_models.dart';
import 'package:deep_sky/domain/platform_capabilities.dart';
import 'package:deep_sky/presentation/deep_sky_app.dart';
import 'package:deep_sky/presentation/deep_sky_controller.dart';
import 'package:deep_sky/scene/local_scene_view_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';

/// S3-2 QA test suite covering real v1.1.0 Home, wall-backdrop time bands,
/// dual-state `< 6h` "Ti penso" card, welcome-back notice, TalkBack semantics,
/// 200% text scaling, hot graphics reload, and S3-1 -> S3-2 `PD-19` compatibility
/// (`S2-QA-01`, `ADR-0007`, `V-07`, `PD-19`).
void main() {
  final String v1ManifestRaw = File('content/packs/v1/manifest.json')
      .readAsStringSync();

  const PlatformCapabilities testCaps = PlatformCapabilities(
    packageName: 'com.vectevo.deep_sky',
    androidApiLevel: 35,
    versionName: '1.1.0',
    versionCode: 2,
    supportsRequestInstallPackages: false,
  );

  Future<InMemorySecureKeyStore> buildPairedStore({
    DateTime? previousOpenedAt,
    List<CachedEventEntry> cachedEvents = const <CachedEventEntry>[],
    bool nameSetupCompleted = true,
  }) async {
    final InMemorySecureKeyStore store = InMemorySecureKeyStore();
    final DeepSkyCrypto crypto = DeepSkyCrypto();
    final authKp = await crypto.generateDeviceAuthKeyPair();
    final kemKp = await crypto.generateDeviceKemKeyPair();
    final Uint8List seed = Uint8List.fromList(
      List<int>.generate(32, (int i) => i + 11),
    );
    final LocalDeviceIdentity id = LocalDeviceIdentity(
      serverUrl: 'https://couple.example.test',
      coupleId: 'couple-s32',
      deviceId: 'dev-me',
      deviceLabel: 'Luca',
      authPrivateKeySeed: Uint8List.fromList(
        await authKp.extractPrivateKeyBytes(),
      ),
      authPublicKey: Uint8List.fromList(
        (await authKp.extractPublicKey()).bytes,
      ),
      kemPrivateKey: Uint8List.fromList(await kemKp.extractPrivateKeyBytes()),
      kemPublicKey: Uint8List.fromList((await kemKp.extractPublicKey()).bytes),
      recoverySeed: seed,
      pairingCompleted: true,
      nameSetupCompleted: nameSetupCompleted,
      recoverySavedConfirmed: true,
    );
    await store.write('deep_sky.device_identity.v1', jsonEncode(id.toJson()));

    if (previousOpenedAt != null) {
      await LocalSceneViewStateStore(store)
          .save(LocalSceneViewState(lastOpenedAtLocal: previousOpenedAt));
    }
    if (cachedEvents.isNotEmpty) {
      final Uint8List rootKey = await crypto.deriveCoupleRootKey(seed);
      await EncryptedLocalCache(keyStore: store).saveEvents(
        coupleRootKey: rootKey,
        coupleId: id.coupleId,
        entries: cachedEvents,
      );
    }
    return store;
  }

  MockClient buildMockServer({
    List<Map<String, Object?>> envelopes = const <Map<String, Object?>>[],
    String partnerLabel = 'Anna',
    bool offline = false,
  }) {
    return MockClient((http.Request req) async {
      if (offline) {
        throw const SocketException('Offline');
      }
      if (req.url.path == '/api/v1/system/compatibility') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'minClientVersionCode': 1,
            'minProtocolVersion': 1,
            'minPackVersion': '1.0.0',
          }),
          200,
        );
      }
      if (req.url.path == '/api/v1/sync/envelopes' && req.method == 'GET') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'items': envelopes,
            'nextAfterSeq': envelopes.length,
            'hasMore': false,
            'coupleKeyEpoch': 1,
          }),
          200,
        );
      }
      if (req.url.path == '/api/v1/sync/envelopes' && req.method == 'POST') {
        final Map<String, Object?> body =
            jsonDecode(req.body) as Map<String, Object?>;
        return http.Response(
          jsonEncode(<String, Object?>{
            ...body,
            'seq': envelopes.length + 1,
            'createdAtServer': DateTime.now().toUtc().toIso8601String(),
          }),
          201,
        );
      }
      if (req.url.path == '/api/v1/pairing/devices') {
        return http.Response(
          jsonEncode(<Map<String, Object?>>[
            <String, Object?>{
              'deviceId': 'dev-me',
              'label': 'Luca',
              'enrolledVia': 'PAIRING_INVITER',
              'createdAt': '2026-11-15T10:00:00Z',
              'revokedAt': null,
            },
            <String, Object?>{
              'deviceId': 'dev-partner',
              'label': partnerLabel,
              'enrolledVia': 'PAIRING_JOINER',
              'createdAt': '2026-11-15T10:05:00Z',
              'revokedAt': null,
            },
          ]),
          200,
        );
      }
      if (req.url.path == '/api/v1/push/config') {
        return http.Response('{"enabled":false}', 200);
      }
      if (req.url.path.startsWith('/api/v1/content/pack/')) {
        return http.Response('not found', 404);
      }
      return http.Response('{}', 200);
    });
  }

  test('SkyPeriod resolves fixed local time bands without GPS and updates across midnight', () {
    expect(
      SkyPeriod.fromLocalTime(DateTime(2026, 11, 21, 5, 59)),
      SkyPeriod.night,
    );
    expect(
      SkyPeriod.fromLocalTime(DateTime(2026, 11, 21, 6, 0)),
      SkyPeriod.day,
    );
    expect(
      SkyPeriod.fromLocalTime(DateTime(2026, 11, 21, 17, 59)),
      SkyPeriod.day,
    );
    expect(
      SkyPeriod.fromLocalTime(DateTime(2026, 11, 21, 18, 0)),
      SkyPeriod.twilight,
    );
    expect(
      SkyPeriod.fromLocalTime(DateTime(2026, 11, 21, 20, 59)),
      SkyPeriod.twilight,
    );
    expect(
      SkyPeriod.fromLocalTime(DateTime(2026, 11, 21, 21, 0)),
      SkyPeriod.night,
    );
    expect(
      SkyPeriod.fromLocalTime(DateTime(2026, 11, 22, 0, 1)),
      SkyPeriod.night,
    );
  });

  for (final ({
        String label,
        Size size,
        double textScale,
        bool dark,
        String lang,
        DateTime localNow,
      })
      scenario
      in <
        ({
          String label,
          Size size,
          double textScale,
          bool dark,
          String lang,
          DateTime localNow,
        })
      >[
        (
          label: '9:16 dark night IT',
          size: const Size(390, 693),
          textScale: 1.0,
          dark: true,
          lang: 'it',
          localNow: DateTime(2026, 11, 21, 22, 15),
        ),
        (
          label: '9:20 light day EN 200% text scale',
          size: const Size(360, 800),
          textScale: 2.0,
          dark: false,
          lang: 'en',
          localNow: DateTime(2026, 11, 21, 11, 0),
        ),
        (
          label: '16:10 split-screen twilight IT',
          size: const Size(800, 500),
          textScale: 1.0,
          dark: true,
          lang: 'it',
          localNow: DateTime(2026, 11, 21, 19, 10),
        ),
      ]) {
    testWidgets(
      'S3-2 Home renders v1.1.0 scene, 2 tabs, single Settings button without overflow (${scenario.label})',
      (WidgetTester tester) async {
        tester.view.physicalSize = scenario.size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final InMemorySecureKeyStore store = await buildPairedStore(
          previousOpenedAt: DateTime.utc(
            2026,
            11,
            16,
            10,
            0,
          ), // > 3 days ago -> welcome-back
        );
        final DeepSkyController controller = DeepSkyController(
          keyStore: store,
          httpClient: buildMockServer(),
          loadAssetString: (_) async => v1ManifestRaw,
          loadCapabilities: () async => testCaps,
          defaultServerUrl: 'https://couple.example.test',
          enableSkyRefreshTimer: false,
          clockUtc: () => DateTime.utc(2026, 11, 21, 18, 0),
          clockLocal: () => scenario.localNow,
        );
        controller.reduceMotion = true;
        controller.isNight = scenario.dark;
        controller.languageCode = scenario.lang;

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: scenario.size,
              textScaler: TextScaler.linear(scenario.textScale),
            ),
            child: DeepSkyApp(controller: controller),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('home-shell-page')), findsOneWidget);
        expect(find.byKey(const Key('home-wall-backdrop')), findsOneWidget);
        expect(find.byKey(const Key('open-settings-button')), findsOneWidget);
        expect(find.byKey(const Key('ds2-scene-canvas')), findsOneWidget);
        expect(find.byKey(const Key('welcome-back-card')), findsOneWidget);

        // Exactly 2 tabs in S3-2 (`Casa`, `Noi` / `Home`, `Us`)
        final NavigationBar navBar = tester.widget<NavigationBar>(
          find.byKey(const Key('ds2-bottom-nav')),
        );
        expect(navBar.destinations.length, 2);

        // Header has ONLY ONE action button (Impostazioni / Settings)
        final AppBar appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.actions?.length, 1);

        // Window, rug, couch, and floor_lamp slots exist; floor is non-interactive
        expect(find.byKey(const Key('scene-slot-window')), findsOneWidget);
        expect(find.byKey(const Key('scene-slot-rug')), findsOneWidget);
        expect(find.byKey(const Key('scene-slot-couch')), findsOneWidget);
        expect(find.byKey(const Key('scene-slot-floor_lamp')), findsOneWidget);
        expect(find.byKey(const Key('scene-slot-floor')), findsNothing);

        // Welcome-back banner dismisses cleanly
        await tester.ensureVisible(
          find.byKey(const Key('dismiss-welcome-back-button')),
        );
        await tester.tap(find.byKey(const Key('dismiss-welcome-back-button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('welcome-back-card')), findsNothing);
      },
    );
  }

  testWidgets(
    'Paired boot on a non-Home page (space setup) does not leave packBootAttempts pending and never triggers a false rollback',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final Directory tempPackRoot = Directory.systemTemp.createTempSync(
        'deepsky_bootcounter_',
      );
      addTearDown(() {
        PaintingBinding.instance.imageCache.clear();
        try {
          tempPackRoot.deleteSync(recursive: true);
        } catch (_) {}
      });

      // Active external pack v1.3.0 (copy of the bundled v1 assets) with one failed boot recorded.
      final Directory activeDir = Directory(
        '${tempPackRoot.path}/active/1.3.0/assets',
      )..createSync(recursive: true);
      for (final FileSystemEntity f in Directory(
        'content/packs/v1/assets',
      ).listSync()) {
        if (f is File) {
          f.copySync('${activeDir.path}/${f.uri.pathSegments.last}');
        }
      }
      File('${tempPackRoot.path}/active/1.3.0/manifest.json').writeAsStringSync(
        v1ManifestRaw.replaceFirst(
          '"packVersion": "1.2.0"',
          '"packVersion": "1.3.0"',
        ),
      );

      final InMemorySecureKeyStore store = await buildPairedStore(
        nameSetupCompleted: false,
      );
      const String metaKey = 'deepsky.content_pack.meta.v1';
      await store.write(
        metaKey,
        jsonEncode(<String, Object?>{
          'activeVersion': '1.3.0',
          'maxSeenVersion': '1.3.0',
          'packBootAttempts': 1,
        }),
      );

      final MockClient httpClient = buildMockServer();
      final ContentPackService packService = ContentPackService(
        keyStore: store,
        trustedPublicKeys: const <String, SimplePublicKey>{},
        httpClient: httpClient,
        resolveStorageRootDir: () async => tempPackRoot.path,
        isConnectionUnmetered: () async => false,
      );
      final DeepSkyController controller = DeepSkyController(
        keyStore: store,
        httpClient: httpClient,
        contentPackService: packService,
        loadAssetString: (_) async => v1ManifestRaw,
        loadCapabilities: () async => testCaps,
        defaultServerUrl: 'https://couple.example.test',
        enableSkyRefreshTimer: false,
      );
      controller.reduceMotion = true;

      await tester.pumpWidget(
        DeepSkyApp(controller: controller, autoInitialize: false),
      );
      await tester.runAsync(controller.initialize);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();

      expect(find.byKey(const Key('space-setup-page')), findsOneWidget);
      expect(controller.activePackVersion, '1.3.0');
      final Map<String, Object?> meta =
          jsonDecode((await store.read(metaKey))!) as Map<String, Object?>;
      expect(meta['packBootAttempts'], 0);
    },
  );

  // IR-03: the rollback guard must reset only after the active pack layers actually decoded.
  for (final ({String label, bool corrupt}) scenario
      in <({String label, bool corrupt})>[
        (
          label: 'valid file-system pack resets packBootAttempts once layers decoded',
          corrupt: false,
        ),
        (
          label: 'undecodable PNG layer in a file-system pack does NOT reset packBootAttempts',
          corrupt: true,
        ),
      ]) {
    testWidgets('IR-03: ${scenario.label}', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final Directory tempPackRoot = Directory.systemTemp.createTempSync(
        'deepsky_ir03_',
      );
      addTearDown(() {
        PaintingBinding.instance.imageCache.clear();
        try {
          tempPackRoot.deleteSync(recursive: true);
        } catch (_) {}
      });

      final Directory activeAssets = Directory(
        '${tempPackRoot.path}/active/1.3.0/assets',
      )..createSync(recursive: true);
      for (final FileSystemEntity f in Directory(
        'content/packs/v1/assets',
      ).listSync()) {
        if (f is File) {
          f.copySync('${activeAssets.path}/${f.uri.pathSegments.last}');
        }
      }
      if (scenario.corrupt) {
        // Same path/size class as a real asset, but not a decodable image.
        File('${activeAssets.path}/floor.png')
            .writeAsBytesSync(List<int>.filled(64, 7));
      }
      File('${tempPackRoot.path}/active/1.3.0/manifest.json').writeAsStringSync(
        v1ManifestRaw.replaceFirst(
          '"packVersion": "1.2.0"',
          '"packVersion": "1.3.0"',
        ),
      );

      final InMemorySecureKeyStore store = await buildPairedStore();
      const String metaKey = 'deepsky.content_pack.meta.v1';
      await store.write(
        metaKey,
        jsonEncode(<String, Object?>{
          'activeVersion': '1.3.0',
          'maxSeenVersion': '1.3.0',
          'packBootAttempts': 1,
        }),
      );

      final MockClient httpClient = buildMockServer();
      final ContentPackService packService = ContentPackService(
        keyStore: store,
        trustedPublicKeys: const <String, SimplePublicKey>{},
        httpClient: httpClient,
        resolveStorageRootDir: () async => tempPackRoot.path,
        isConnectionUnmetered: () async => false,
      );
      final DeepSkyController controller = DeepSkyController(
        keyStore: store,
        httpClient: httpClient,
        contentPackService: packService,
        loadAssetString: (_) async => v1ManifestRaw,
        loadCapabilities: () async => testCaps,
        defaultServerUrl: 'https://couple.example.test',
        enableSkyRefreshTimer: false,
      );
      controller.reduceMotion = true;

      await tester.pumpWidget(
        DeepSkyApp(controller: controller, autoInitialize: false),
      );
      await tester.runAsync(controller.initialize);
      for (int i = 0; i < 20; i++) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
      }
      await tester.pump();

      expect(controller.activePackIsFileSystem, isTrue);
      expect(find.byKey(const Key('ds2-scene-canvas')), findsOneWidget);
      if (scenario.corrupt) {
        // Decode failures are reported through FlutterError (expected here).
        while (tester.takeException() != null) {}
      }
      final Map<String, Object?> meta =
          jsonDecode((await store.read(metaKey))!) as Map<String, Object?>;
      // Startup incremented 1 -> 2; a decode failure must leave it pending (not reset to 0).
      expect(meta['packBootAttempts'], scenario.corrupt ? 2 : 0);
    });
  }

  testWidgets(
    'Dual-state "Ti penso" card shows "<Partner> ti ha pensato" + Ricambia for unseen <6h thought and switches to quick-send after reply',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final DateTime nowUtc = DateTime.utc(2026, 11, 21, 20, 0);
      final CachedEventEntry recentPartnerThought = CachedEventEntry(
        envelopeId: 'env-p-1',
        coupleId: 'couple-s32',
        senderDeviceId: 'dev-partner',
        channel: EnvelopeChannel.event,
        keyEpoch: 1,
        seq: 5,
        createdAtServer: nowUtc.subtract(const Duration(hours: 1)),
        payload: DecryptedEnvelopePayload(
          schemaVersion: 1,
          eventType: 'thinking_of_you',
          createdAtClient: nowUtc.subtract(const Duration(hours: 1)),
          authorDeviceId: 'dev-partner',
          body: const <String, Object?>{'note': 'Buona serata amore'},
        ),
      );

      // Simulate offline cache containing partner's S3-1 thought (`PD-19` n-1 compatibility)
      final InMemorySecureKeyStore store = await buildPairedStore(
        cachedEvents: <CachedEventEntry>[recentPartnerThought],
      );

      final DeepSkyController controller = DeepSkyController(
        keyStore: store,
        httpClient: buildMockServer(offline: true),
        loadAssetString: (_) async => v1ManifestRaw,
        loadCapabilities: () async => testCaps,
        defaultServerUrl: 'https://couple.example.test',
        enableSkyRefreshTimer: false,
        clockUtc: () => nowUtc,
        clockLocal: () => DateTime(2026, 11, 21, 21, 0),
      );
      controller.reduceMotion = true;

      await tester.pumpWidget(DeepSkyApp(controller: controller));
      await tester.pumpAndSettle();

      // Offline read-only banner visible, cached partner thought rendered, Ricambia disabled offline
      expect(find.byKey(const Key('offline-readonly-banner')), findsOneWidget);
      expect(find.textContaining('ti ha pensato'), findsOneWidget);
      expect(find.textContaining('Buona serata amore'), findsOneWidget);
      expect(find.byKey(const Key('reply-thought-button')), findsOneWidget);
      expect(controller.sceneState.floorLampLit, isTrue);
      expect(find.byKey(const Key('floor-lamp-ambient-glow')), findsOneWidget);

      final FilledButton offlineReply = tester.widget<FilledButton>(
        find.byKey(const Key('reply-thought-button')),
      );
      expect(offlineReply.onPressed, isNull);

      // Marking seen locally clears the received banner & lights down floor_lamp to calm
      await controller.markLatestPartnerThoughtSeen();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reply-thought-button')), findsNothing);
      expect(find.byKey(const Key('send-thought-button')), findsOneWidget);
      expect(controller.sceneState.floorLampLit, isFalse);
      expect(find.byKey(const Key('floor-lamp-ambient-glow')), findsNothing);
    },
  );

  testWidgets(
    'Sending a thought replaces composer with "Pensiero inviato" banner temporarily, and reciprocating supports an optional message',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final DateTime nowUtc = DateTime.utc(2026, 11, 21, 20, 0);
      final List<Map<String, Object?>> serverEnvelopes =
          <Map<String, Object?>>[];

      final MockClient mockServer = MockClient((http.Request req) async {
        if (req.url.path == '/api/v1/system/compatibility') {
          return http.Response(
            '{"minClientVersionCode":1,"minProtocolVersion":1,"minPackVersion":"1.0.0"}',
            200,
          );
        }
        if (req.url.path == '/api/v1/sync/envelopes' && req.method == 'GET') {
          return http.Response(
            jsonEncode(<String, Object?>{
              'items': serverEnvelopes,
              'nextAfterSeq': serverEnvelopes.length,
              'hasMore': false,
              'coupleKeyEpoch': 1,
            }),
            200,
          );
        }
        if (req.url.path == '/api/v1/sync/envelopes' && req.method == 'POST') {
          final Map<String, Object?> body =
              jsonDecode(req.body) as Map<String, Object?>;
          final Map<String, Object?> stored = <String, Object?>{
            ...body,
            'coupleId': 'couple-s32',
            'senderDeviceId': req.headers['X-Device-Id'] ?? 'dev-me',
            'seq': serverEnvelopes.length + 1,
            'createdAtServer': nowUtc.toIso8601String(),
          };
          serverEnvelopes.add(stored);
          return http.Response(jsonEncode(stored), 201);
        }
        if (req.url.path == '/api/v1/pairing/devices') {
          return http.Response(
            jsonEncode(<Map<String, Object?>>[
              <String, Object?>{
                'deviceId': 'dev-me',
                'label': 'Luca',
                'enrolledVia': 'PAIRING_INVITER',
                'createdAt': '2026-11-15T10:00:00Z',
                'revokedAt': null,
              },
              <String, Object?>{
                'deviceId': 'dev-partner',
                'label': 'Anna',
                'enrolledVia': 'PAIRING_JOINER',
                'createdAt': '2026-11-15T10:05:00Z',
                'revokedAt': null,
              },
            ]),
            200,
          );
        }
        if (req.url.path == '/api/v1/push/config') {
          return http.Response('{"enabled":false}', 200);
        }
        return http.Response('not found', 404);
      });

      // Seed an encrypted partner thought on the mock server
      final DeepSkyCrypto crypto = DeepSkyCrypto();
      final Uint8List seed = Uint8List.fromList(
        List<int>.generate(32, (int i) => i + 11),
      );
      final Uint8List coupleRootKey = await crypto.deriveCoupleRootKey(seed);
      final EncryptedEnvelope partnerEnv = await crypto.encryptEnvelope(
        rootKey: coupleRootKey,
        coupleId: 'couple-s32',
        senderDeviceId: 'dev-partner',
        envelopeId: 'env-partner-1',
        channel: EnvelopeChannel.event,
        keyEpoch: 1,
        payload: DecryptedEnvelopePayload(
          schemaVersion: 1,
          eventType: 'thinking_of_you',
          createdAtClient: nowUtc.subtract(const Duration(minutes: 15)),
          authorDeviceId: 'dev-partner',
          body: const <String, Object?>{'note': 'Ti penso tanto'},
        ),
      );
      serverEnvelopes.add(<String, Object?>{
        ...partnerEnv.toUploadJson(),
        'coupleId': 'couple-s32',
        'senderDeviceId': 'dev-partner',
        'seq': 1,
        'createdAtServer': nowUtc
            .subtract(const Duration(minutes: 15))
            .toIso8601String(),
      });

      final InMemorySecureKeyStore store = await buildPairedStore();
      final DeepSkyController controller = DeepSkyController(
        keyStore: store,
        httpClient: mockServer,
        loadAssetString: (_) async => v1ManifestRaw,
        loadCapabilities: () async => testCaps,
        defaultServerUrl: 'https://couple.example.test',
        enableSkyRefreshTimer: false,
        thoughtSentBannerDuration: const Duration(seconds: 6),
        clockUtc: () => nowUtc,
        clockLocal: () => DateTime(2026, 11, 21, 21, 0),
      );
      controller.reduceMotion = true;

      await tester.pumpWidget(DeepSkyApp(controller: controller));
      await tester.pumpAndSettle();

      // 1) Incoming partner thought shows optional reply note field + Ricambia button
      expect(find.textContaining('Anna ti ha pensato'), findsOneWidget);
      expect(find.textContaining('Ti penso tanto'), findsOneWidget);
      expect(find.byKey(const Key('reply-thought-note-field')), findsOneWidget);
      expect(find.byKey(const Key('reply-thought-button')), findsOneWidget);

      // Type a reply message and tap Ricambia
      await tester.enterText(
        find.byKey(const Key('reply-thought-note-field')),
        'Anche io amore!',
      );
      await tester.tap(find.byKey(const Key('reply-thought-button')));
      await tester.pumpAndSettle();

      // Reply event persisted with the typed note and partner thought marked seen
      expect(controller.events.length, 2);
      expect(controller.events.last.payload.body['note'], 'Anche io amore!');
      expect(controller.sceneState.floorLampLit, isFalse);

      // 2) Composer is replaced by the "Pensiero inviato" banner (not a tiny confirmation text under it)
      expect(find.byKey(const Key('thought-sent-banner')), findsOneWidget);
      expect(find.text('Pensiero inviato'), findsOneWidget);
      expect(find.textContaining('Anche io amore!'), findsOneWidget);
      expect(find.byKey(const Key('ds2-thought-action-card')), findsNothing);
      expect(find.text('Pensiero inviato in modo cifrato.'), findsNothing);

      // 3) After banner duration elapses, it automatically returns to "Lascia un pensiero"
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('thought-sent-banner')), findsNothing);
      expect(find.byKey(const Key('ds2-thought-action-card')), findsOneWidget);

      // 4) Sending from quick composer also shows the banner and can be dismissed early
      await tester.enterText(
        find.byKey(const Key('thought-note-field')),
        'Buonanotte',
      );
      await tester.tap(find.byKey(const Key('send-thought-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('thought-sent-banner')), findsOneWidget);
      expect(find.textContaining('Buonanotte'), findsOneWidget);
      expect(find.byKey(const Key('ds2-thought-action-card')), findsNothing);

      await tester.tap(find.byKey(const Key('dismiss-thought-sent-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('thought-sent-banner')), findsNothing);
      expect(find.byKey(const Key('ds2-thought-action-card')), findsOneWidget);

      // 5) Tapping floor_lamp while calm focuses the quick-send composer
      final Finder lampSlot = find.byKey(const Key('scene-slot-floor_lamp'));
      expect(lampSlot, findsOneWidget);
      await tester.ensureVisible(lampSlot);
      await tester.tap(lampSlot);
      await tester.pumpAndSettle();
      final EditableText noteEditable = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('thought-note-field')),
          matching: find.byType(EditableText),
        ),
      );
      expect(noteEditable.focusNode.hasFocus, isTrue);
    },
  );

  testWidgets(
    'Settings "Aggiorna grafiche" hot-reloads signed v1.3.0 pack live without restarting app',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final Directory tempPackRoot = Directory.systemTemp.createTempSync(
        'deepsky_hotreload_',
      );
      addTearDown(() {
        PaintingBinding.instance.imageCache.clear();
        try {
          tempPackRoot.deleteSync(recursive: true);
        } catch (_) {}
      });

      final Ed25519 ed = Ed25519();
      final SimpleKeyPair kp = await ed.newKeyPair();
      final SimplePublicKey pub = await kp.extractPublicKey();

      final Uint8List floorBytes = File('content/packs/v1/assets/floor.png')
          .readAsBytesSync();
      final Uint8List rugBytes = File('content/packs/v1/assets/rug.png')
          .readAsBytesSync();

      final String v13Manifest = jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'packId': 'deep-sky-home-v1',
        'packVersion': '1.3.0',
        'minAppProtocol': 1,
        'name': <String, String>{'it': 'Casa v1.3', 'en': 'Home v1.3'},
        'scene': <String, Object?>{
          'aspectRatio': '4:3',
          'bleed': <String, double>{
            'top': 0,
            'bottom': 0,
            'left': 0,
            'right': 0,
          },
          'background': <String, Object?>{'dayAsset': null, 'nightAsset': null},
        },
        'slots': <Object?>[
          <String, Object?>{
            'id': 'floor',
            'description': 'Floor',
            'zIndex': 5,
            'replaceable': false,
            'anchor': <String, double>{'x': 0.5, 'y': 0.56},
            'bounds': <String, double>{
              'x': 0.0,
              'y': 0.56,
              'width': 1.0,
              'height': 0.44,
            },
            'touchArea': <String, double>{
              'x': 0.0,
              'y': 0.56,
              'width': 1.0,
              'height': 0.44,
            },
            'accessibilityLabel': <String, String>{
              'it': 'Pavimento',
              'en': 'Floor',
            },
            'defaultState': 'default',
            'states': <String, Object?>{
              'default': <String, Object?>{
                'layers': <Object?>[
                  <String, Object?>{
                    'id': 'parquet',
                    'asset': 'assets/floor.png',
                    'zOffset': 0,
                  },
                ],
              },
            },
            'animations': <Object?>[],
          },
          <String, Object?>{
            'id': 'pet_sleeping',
            'description': 'Sleeping puppy',
            'zIndex': 45,
            'replaceable': true,
            'anchor': <String, double>{'x': 0.62, 'y': 0.78},
            'bounds': <String, double>{
              'x': 0.52,
              'y': 0.68,
              'width': 0.20,
              'height': 0.16,
            },
            'touchArea': <String, double>{
              'x': 0.50,
              'y': 0.66,
              'width': 0.24,
              'height': 0.20,
            },
            'accessibilityLabel': <String, String>{
              'it': 'Cagnolino che dorme sul tappeto',
              'en': 'Sleeping puppy on the rug',
            },
            'defaultState': 'sleeping',
            'states': <String, Object?>{
              'sleeping': <String, Object?>{
                'layers': <Object?>[
                  <String, Object?>{
                    'id': 'pet',
                    'asset': 'assets/rug.png',
                    'zOffset': 0,
                  },
                ],
              },
            },
            'animations': <Object?>[],
          },
        ],
      });

      final Map<String, List<int>> files = <String, List<int>>{
        'manifest.json': utf8.encode(v13Manifest),
        'assets/floor.png': floorBytes,
        'assets/rug.png': rugBytes,
      };
      final Map<String, Object?> fileMeta = <String, Object?>{};
      for (final MapEntry<String, List<int>> e in files.entries) {
        final Hash h = await Sha256().hash(e.value);
        fileMeta[e.key] = <String, Object?>{
          'sha256': h.bytes
              .map((int b) => b.toRadixString(16).padLeft(2, '0'))
              .join(),
          'sizeBytes': e.value.length,
        };
      }
      final Uint8List checksumsBytes = Uint8List.fromList(
        utf8.encode(
          jsonEncode(<String, Object?>{
            'schemaVersion': 1,
            'keyId': 'v1',
            'packId': 'deep-sky-home-v1',
            'packVersion': '1.3.0',
            'minAppProtocol': 1,
            'files': fileMeta,
          }),
        ),
      );
      final Signature sig = await ed.sign(checksumsBytes, keyPair: kp);
      final Uint8List sigBytes = Uint8List.fromList(
        utf8.encode('v1:${base64Encode(sig.bytes)}\n'),
      );

      final MockClient httpClient = MockClient((http.Request req) async {
        if (req.url.path == '/api/v1/system/compatibility') {
          return http.Response(
            '{"minClientVersionCode":1,"minProtocolVersion":1,"minPackVersion":"1.0.0"}',
            200,
          );
        }
        if (req.url.path == '/api/v1/sync/envelopes') {
          return http.Response(
            '{"items":[],"nextAfterSeq":0,"hasMore":false,"coupleKeyEpoch":1}',
            200,
          );
        }
        if (req.url.path == '/api/v1/pairing/devices') {
          return http.Response('[]', 200);
        }
        if (req.url.path == '/api/v1/push/config') {
          return http.Response('{"enabled":false}', 200);
        }
        if (req.url.path == '/api/v1/content/pack/checksums') {
          return http.Response.bytes(checksumsBytes, 200);
        }
        if (req.url.path == '/api/v1/content/pack/checksums.sig') {
          return http.Response.bytes(sigBytes, 200);
        }
        const String prefix = '/api/v1/content/pack/blobs/';
        if (req.url.path.startsWith(prefix)) {
          final String hash = req.url.path.substring(prefix.length);
          for (final MapEntry<String, List<int>> f in files.entries) {
            final Hash h = await Sha256().hash(f.value);
            final String fileHash = h.bytes
                .map((int b) => b.toRadixString(16).padLeft(2, '0'))
                .join();
            if (fileHash == hash) {
              return http.Response.bytes(f.value, 200);
            }
          }
        }
        return http.Response('not found', 404);
      });

      final InMemorySecureKeyStore store = await buildPairedStore();
      final ContentPackService packService = ContentPackService(
        keyStore: store,
        trustedPublicKeys: <String, SimplePublicKey>{'v1': pub},
        httpClient: httpClient,
        resolveStorageRootDir: () async => tempPackRoot.path,
        isConnectionUnmetered: () async =>
            false, // Metered: manual button must still work!
      );

      final DeepSkyController controller = DeepSkyController(
        keyStore: store,
        httpClient: httpClient,
        contentPackService: packService,
        loadAssetString: (_) async => v1ManifestRaw,
        loadCapabilities: () async => testCaps,
        defaultServerUrl: 'https://couple.example.test',
        enableSkyRefreshTimer: false,
      );
      controller.reduceMotion = true;

      await tester.pumpWidget(DeepSkyApp(controller: controller));
      await tester.pumpAndSettle();

      expect(controller.activePackVersion, '1.2.0');

      // Open Settings via single top-right button
      await tester.tap(find.byKey(const Key('open-settings-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings-page')), findsOneWidget);
      expect(find.textContaining('v1.2.0'), findsOneWidget);

      // Tap explicit "Aggiorna grafiche" button
      final Finder updateBtn = find.byKey(
        const Key('force-update-graphics-button'),
      );
      final Finder settingsScroll = find
          .descendant(
            of: find.byKey(const Key('settings-page')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        updateBtn,
        200,
        scrollable: settingsScroll,
      );
      await tester.ensureVisible(updateBtn);
      await tester.pumpAndSettle();
      await tester.tap(updateBtn);
      await tester.pump();
      for (int i = 0; i < 100 && controller.contentPackUpdating; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(controller.activePackVersion, '1.3.0');
      expect(controller.activePackIsFileSystem, isTrue);
      expect(find.textContaining('v1.3.0'), findsWidgets);

      // Pop back to Home and verify the updated v1.3.0 pet_sleeping slot is live!
      await tester.tap(find.byKey(const Key('settings-back-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('scene-slot-pet_sleeping')), findsOneWidget);
    },
  );

  testWidgets(
    'Thinking of you card omits old sub-header and opens ThoughtHistorySheet (empty & populated, IT/EN, 200% text scale)',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final DateTime nowLocal = DateTime(2026, 11, 22, 14, 30);
      final DateTime nowUtc = nowLocal.toUtc();

      final InMemorySecureKeyStore emptyStore = await buildPairedStore();
      final DeepSkyController emptyCtrl = DeepSkyController(
        keyStore: emptyStore,
        httpClient: buildMockServer(offline: false),
        loadAssetString: (_) async => v1ManifestRaw,
        loadCapabilities: () async => testCaps,
        defaultServerUrl: 'https://couple.example.test',
        enableSkyRefreshTimer: false,
        clockUtc: () => nowUtc,
        clockLocal: () => nowLocal,
      );
      emptyCtrl.reduceMotion = true;

      await tester.pumpWidget(DeepSkyApp(controller: emptyCtrl));
      await tester.pumpAndSettle();

      // Old sub-header must be gone
      expect(
        find.text('Accende una luce gentile nella vostra casa.'),
        findsNothing,
      );
      expect(
        find.text('Lights a gentle glow in your shared home.'),
        findsNothing,
      );

      // Small history button is present and opens the empty history sheet
      final Finder historyBtn = find.byKey(
        const Key('open-thought-history-button'),
      );
      expect(historyBtn, findsOneWidget);
      await tester.tap(historyBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('thought-history-sheet')), findsOneWidget);
      expect(find.textContaining('0 pensieri'), findsOneWidget);
      expect(find.byKey(const Key('thought-history-empty')), findsOneWidget);

      await tester.tap(find.byKey(const Key('close-thought-history-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('thought-history-sheet')), findsNothing);

      // Populated history with today, yesterday, older, and silent tap (offline cache + 200% text scale)
      final List<CachedEventEntry> sampleEvents = <CachedEventEntry>[
        CachedEventEntry(
          envelopeId: 'env-1',
          coupleId: 'couple-s32',
          senderDeviceId: 'dev-partner',
          channel: EnvelopeChannel.event,
          keyEpoch: 1,
          seq: 1,
          createdAtServer: nowLocal.subtract(const Duration(days: 3)).toUtc(),
          payload: DecryptedEnvelopePayload(
            schemaVersion: 1,
            eventType: 'thinking_of_you',
            createdAtClient: DateTime(2026, 11, 19, 10, 15).toUtc(),
            authorDeviceId: 'dev-partner',
            body: const <String, Object?>{'note': 'Buongiorno'},
          ),
        ),
        CachedEventEntry(
          envelopeId: 'env-2',
          coupleId: 'couple-s32',
          senderDeviceId: 'dev-me',
          channel: EnvelopeChannel.event,
          keyEpoch: 1,
          seq: 2,
          createdAtServer: DateTime(2026, 11, 21, 14, 5).toUtc(),
          payload: DecryptedEnvelopePayload(
            schemaVersion: 1,
            eventType: 'thinking_of_you',
            createdAtClient: DateTime(2026, 11, 21, 14, 5).toUtc(),
            authorDeviceId: 'dev-me',
            body: const <String, Object?>{},
          ),
        ),
        CachedEventEntry(
          envelopeId: 'env-3',
          coupleId: 'couple-s32',
          senderDeviceId: 'dev-partner',
          channel: EnvelopeChannel.event,
          keyEpoch: 1,
          seq: 3,
          createdAtServer: DateTime(2026, 11, 22, 12, 40).toUtc(),
          payload: DecryptedEnvelopePayload(
            schemaVersion: 1,
            eventType: 'thinking_of_you',
            createdAtClient: DateTime(2026, 11, 22, 12, 40).toUtc(),
            authorDeviceId: 'dev-partner',
            body: const <String, Object?>{'note': 'Un bacio tra una lezione'},
          ),
        ),
      ];

      final InMemorySecureKeyStore populatedStore = await buildPairedStore(
        cachedEvents: sampleEvents,
      );
      final DeepSkyController populatedCtrl = DeepSkyController(
        keyStore: populatedStore,
        httpClient: buildMockServer(offline: true),
        loadAssetString: (_) async => v1ManifestRaw,
        loadCapabilities: () async => testCaps,
        defaultServerUrl: 'https://couple.example.test',
        enableSkyRefreshTimer: false,
        clockUtc: () => nowUtc,
        clockLocal: () => nowLocal,
      );
      populatedCtrl.reduceMotion = true;

      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        DeepSkyApp(
          key: const ValueKey<String>('populated-app'),
          controller: populatedCtrl,
        ),
      );
      await tester.pumpAndSettle();
      expect(populatedCtrl.events.length, 3);

      // Also visible in received-thought state
      expect(
        find.byKey(const Key('open-thought-history-button')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('open-thought-history-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('thought-history-sheet')), findsOneWidget);
      expect(find.textContaining('3 pensieri'), findsOneWidget);
      expect(find.text('OGGI'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('thought-history-sheet')),
          matching: find.textContaining('Un bacio tra una lezione'),
        ),
        findsOneWidget,
      );

      final Finder historyScroll = find
          .descendant(
            of: find.byKey(const Key('thought-history-list')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('IERI'),
        150,
        scrollable: historyScroll,
      );
      expect(find.text('IERI'), findsOneWidget);
      expect(find.text('Pensiero silenzioso'), findsOneWidget);
      expect(find.textContaining('Tu (Luca)'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('19 nov'),
        150,
        scrollable: historyScroll,
      );
      expect(find.text('19 nov'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
