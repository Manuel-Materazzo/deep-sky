import 'dart:convert';
import 'dart:typed_data';

import 'package:deep_sky/data/couple_api_client.dart';
import 'package:deep_sky/data/pairing_and_sync_repository.dart';
import 'package:deep_sky/data/secure_key_store.dart';
import 'package:deep_sky/domain/crypto/e2ee_models.dart';
import 'package:deep_sky/domain/crypto/recovery_key_codec.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Interactive M1 prototype screen for SP-02:
/// pairing with SAS verification, 24-word/QR recovery, new-device enrollment,
/// device revocation, E2EE envelopes, and server visibility inspection.
class Sp02PrototypePage extends StatefulWidget {
  const Sp02PrototypePage({super.key, this.repository});

  final PairingAndSyncRepository? repository;

  @override
  State<Sp02PrototypePage> createState() => _Sp02PrototypePageState();
}

class _Sp02PrototypePageState extends State<Sp02PrototypePage> {
  late final PairingAndSyncRepository _repo;

  final TextEditingController _serverUrlController = TextEditingController(
    text: 'https://deepsky.vectevo.com',
  );
  final TextEditingController _deviceLabelController = TextEditingController(
    text: 'Telefono di prova',
  );
  final TextEditingController _inviteTokenController = TextEditingController();
  final TextEditingController _recoveryInputController =
      TextEditingController();
  final TextEditingController _messageController = TextEditingController(
    text: 'Ti penso adesso',
  );

  LocalDeviceIdentity? _identity;
  CreateInviteResponse? _activeInvite;
  InviteStatusResponse? _inviteStatus;
  String? _initiatorSas;
  PendingJoinSession? _pendingJoin;

  List<DecryptedEventRecord> _events = const <DecryptedEventRecord>[];
  List<DeviceSummary> _devices = const <DeviceSummary>[];
  Map<String, Object?>? _visibilityAudit;

  bool _busy = false;
  bool _recoveryCheckbox = false;
  String _selectedEventType = 'thinking_of_you';
  String? _statusMessage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repo =
        widget.repository ??
        PairingAndSyncRepository(keyStore: FlutterSecureKeyStore());
    _loadInitialState();
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _deviceLabelController.dispose();
    _inviteTokenController.dispose();
    _recoveryInputController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialState() async {
    final LocalDeviceIdentity? loaded = await _repo.loadIdentity();
    if (!mounted) {
      return;
    }
    setState(() {
      _identity = loaded;
      if (loaded != null) {
        _serverUrlController.text = loaded.serverUrl;
        _deviceLabelController.text = loaded.deviceLabel;
      }
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _errorMessage = null;
      _statusMessage = null;
    });
    try {
      await action();
    } catch (err) {
      if (mounted) {
        setState(() => _errorMessage = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _extractToken(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.startsWith('deepsky://')) {
      final Uri? uri = Uri.tryParse(trimmed);
      final String? token = uri?.queryParameters['token'];
      if (token != null && token.isNotEmpty) {
        return token;
      }
    }
    return trimmed;
  }

  Future<void> _createInitialInvite() => _runAction(() async {
    final res = await _repo.createInitialInvite(
      serverUrl: _serverUrlController.text.trim(),
      deviceLabel: _deviceLabelController.text.trim(),
    );
    setState(() {
      _identity = res.identity;
      _activeInvite = res.invite;
      _inviteStatus = null;
      _initiatorSas = null;
      _statusMessage =
          'Invito creato. Condividi il link o il codice QR con il tuo partner.';
    });
  });

  Future<void> _checkInviteAndSas() => _runAction(() async {
    if (_activeInvite == null) {
      return;
    }
    final res = await _repo.checkInviteAndSas(_activeInvite!.inviteToken);
    setState(() {
      _inviteStatus = res.status;
      _initiatorSas = res.sasCode;
      _statusMessage = res.status.accepted
          ? 'Partner unito! Confrontate insieme il codice: ${res.sasCode}'
          : 'In attesa che il partner accetti l’invito...';
    });
  });

  Future<void> _confirmSasAndDeliverKey() => _runAction(() async {
    final InviteStatusResponse? st = _inviteStatus;
    if (st == null ||
        !st.accepted ||
        st.acceptedDeviceId == null ||
        st.acceptedKemPublicKey == null) {
      return;
    }
    await _repo.confirmSasAndDeliverRootKey(
      targetDeviceId: st.acceptedDeviceId!,
      targetKemPublicKey: st.acceptedKemPublicKey!,
    );
    setState(() {
      _activeInvite = null;
      _inviteStatus = null;
      _initiatorSas = null;
      _statusMessage = 'Chiave condivisa inviata in modo cifrato al dispositivo del partner.';
    });
  });

  Future<void> _acceptInvite() => _runAction(() async {
    final String token = _extractToken(_inviteTokenController.text);
    final PendingJoinSession session = await _repo.acceptInvite(
      serverUrl: _serverUrlController.text.trim(),
      inviteToken: token,
      deviceLabel: _deviceLabelController.text.trim(),
    );
    setState(() {
      _identity = session.identity;
      _pendingJoin = session;
      _statusMessage =
          'Collegato a ${session.peerLabel}. Confrontate il codice di verifica: ${session.sasCode}';
    });
  });

  Future<void> _completeKeyDelivery() => _runAction(() async {
    if (_pendingJoin == null) {
      return;
    }
    final LocalDeviceIdentity completed = await _repo.completeKeyDelivery(
      session: _pendingJoin!,
    );
    setState(() {
      _identity = completed;
      _pendingJoin = null;
      _statusMessage =
          'Abbinamento completato! Salva ora la chiave di recupero.';
    });
  });

  Future<void> _confirmRecoverySaved() => _runAction(() async {
    final LocalDeviceIdentity updated = await _repo.confirmRecoveryKeySaved();
    setState(() {
      _identity = updated;
      _statusMessage = 'Conferma salvataggio registrata.';
    });
  });

  Future<void> _recoverWithKey() => _runAction(() async {
    final LocalDeviceIdentity recovered = await _repo.recoverWithRecoveryKey(
      serverUrl: _serverUrlController.text.trim(),
      recoveryInput: _recoveryInputController.text,
      deviceLabel: _deviceLabelController.text.trim(),
    );
    final List<DecryptedEventRecord> events = await _repo
        .fetchAndDecryptEvents();
    setState(() {
      _identity = recovered;
      _events = events;
      _statusMessage =
          'Casa recuperata senza altro telefono! Decifrati ${events.length} eventi.';
    });
  });

  Future<void> _sendTestEvent() => _runAction(() async {
    final Map<String, Object?> body = switch (_selectedEventType) {
      'time_capsule' => <String, Object?>{
        'title': 'Capsula di prova',
        'text': _messageController.text.trim(),
        'unlockAt': DateTime.now()
            .toUtc()
            .add(const Duration(days: 30))
            .toIso8601String(),
      },
      'mood' => <String, Object?>{
        'mood': 'sereno',
        'note': _messageController.text.trim(),
      },
      _ => <String, Object?>{'text': _messageController.text.trim()},
    };
    await _repo.sendEncryptedEvent(eventType: _selectedEventType, body: body);
    final List<DecryptedEventRecord> events = await _repo
        .fetchAndDecryptEvents();
    setState(() {
      _events = events;
      _statusMessage = 'Busta cifrata inviata e sincronizzata.';
    });
  });

  Future<void> _refreshSyncAndDevices() => _runAction(() async {
    final List<DecryptedEventRecord> events = await _repo
        .fetchAndDecryptEvents();
    final List<DeviceSummary> devices = await _repo.listDevices();
    setState(() {
      _events = events;
      _devices = devices;
      _statusMessage =
          'Sincronizzati ${events.length} eventi e ${devices.length} dispositivi.';
    });
  });

  Future<void> _createEnrollmentInvite() => _runAction(() async {
    final CreateInviteResponse invite = await _repo.createEnrollmentInvite();
    setState(() {
      _activeInvite = invite;
      _inviteStatus = null;
      _initiatorSas = null;
      _statusMessage = 'Invito di arruolamento pronto per il nuovo telefono.';
    });
  });

  Future<void> _revokeDevice(String deviceId) => _runAction(() async {
    await _repo.revokeDevice(deviceId);
    final List<DeviceSummary> devices = await _repo.listDevices();
    setState(() {
      _devices = devices;
      _statusMessage = 'Dispositivo $deviceId revocato.';
    });
  });

  Future<void> _fetchVisibilityAudit() => _runAction(() async {
    final Map<String, Object?> audit = await _repo.fetchVisibilityAudit();
    setState(() {
      _visibilityAudit = audit;
      _statusMessage = 'Ispezione del server aggiornata (SP02-07).';
    });
  });

  Future<void> _resetLocalState() => _runAction(() async {
    await _repo.clearIdentity();
    setState(() {
      _identity = null;
      _activeInvite = null;
      _inviteStatus = null;
      _initiatorSas = null;
      _pendingJoin = null;
      _events = const <DecryptedEventRecord>[];
      _devices = const <DeviceSummary>[];
      _visibilityAudit = null;
      _recoveryCheckbox = false;
      _statusMessage = 'Stato locale azzerato.';
    });
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deep Sky · SP-02 E2EE'),
        actions: <Widget>[
          if (_identity != null)
            IconButton(
              tooltip: 'Azzera stato locale',
              onPressed: _busy ? null : _resetLocalState,
              icon: const Icon(Icons.restart_alt),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            if (_busy) const LinearProgressIndicator(),
            if (_errorMessage != null)
              _BannerCard(
                color: theme.colorScheme.errorContainer,
                textColor: theme.colorScheme.onErrorContainer,
                text: _errorMessage!,
              ),
            if (_statusMessage != null)
              _BannerCard(
                color: theme.colorScheme.secondaryContainer,
                textColor: theme.colorScheme.onSecondaryContainer,
                text: _statusMessage!,
              ),
            _buildConfigCard(),
            const SizedBox(height: 12),
            if (_identity == null) ...<Widget>[
              _buildCreateInviteCard(),
              const SizedBox(height: 12),
              _buildAcceptInviteCard(),
              const SizedBox(height: 12),
              _buildRecoveryCard(),
            ] else ...<Widget>[
              _buildIdentitySummaryCard(_identity!),
              if (_pendingJoin != null) ...<Widget>[
                const SizedBox(height: 12),
                _buildJoinSasCard(_pendingJoin!),
              ],
              if (_activeInvite != null) ...<Widget>[
                const SizedBox(height: 12),
                _buildActiveInviteCard(_activeInvite!),
              ],
              if (_identity!.hasCoupleRoot) ...<Widget>[
                const SizedBox(height: 12),
                _buildRecoveryBackupCard(_identity!),
                const SizedBox(height: 12),
                _buildEventsCard(),
                const SizedBox(height: 12),
                _buildDevicesCard(),
                const SizedBox(height: 12),
                _buildVisibilityAuditCard(),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConfigCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Connessione al server',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _serverUrlController,
              enabled: _identity == null && !_busy,
              decoration: const InputDecoration(
                labelText: 'URL server',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _deviceLabelController,
              enabled: _identity == null && !_busy,
              decoration: const InputDecoration(
                labelText: 'Nome di questo telefono',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateInviteCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '1. Crea la nostra casa',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Genera la chiave privata su questo telefono e prepara un invito per il partner.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _createInitialInvite,
              icon: const Icon(Icons.home_outlined),
              label: const Text('Crea invito di abbinamento'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcceptInviteCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '2. Ho ricevuto un invito',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _inviteTokenController,
              decoration: const InputDecoration(
                labelText: 'Link o codice invito',
                hintText: 'deepsky://pair?token=... oppure token',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _busy ? null : _acceptInvite,
              icon: const Icon(Icons.link),
              label: const Text('Unisciti con invito'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecoveryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '3. Recupera da chiave salvata (nuovo telefono)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Inserisci le 24 parole oppure il codice QR di recupero senza bisogno dell’altro telefono.',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _recoveryInputController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '24 parole o payload QR (deepsky-rk:v1:...)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _busy ? null : _recoverWithKey,
              icon: const Icon(Icons.key),
              label: const Text('Recupera la casa'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentitySummaryCard(LocalDeviceIdentity id) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Dispositivo abbinato: ${id.deviceLabel}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            SelectableText('Couple ID: ${id.coupleId}'),
            SelectableText('Device ID: ${id.deviceId}'),
            Text(
              id.hasCoupleRoot
                  ? 'Chiave radice E2EE: presente in Keystore locale'
                  : 'Chiave radice E2EE: in attesa di consegna dal partner',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveInviteCard(CreateInviteResponse invite) {
    final String link = 'deepsky://pair?token=${invite.inviteToken}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Invito attivo',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Center(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                child: QrImageView(data: link, size: 160),
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(link),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: <Widget>[
                OutlinedButton(
                  onPressed: _busy ? null : _checkInviteAndSas,
                  child: const Text('Controlla stato / codice'),
                ),
                if (_initiatorSas != null)
                  FilledButton(
                    onPressed: _busy ? null : _confirmSasAndDeliverKey,
                    child: Text('Codice $_initiatorSas OK · Invia chiave'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinSasCard(PendingJoinSession session) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Verifica di sicurezza con ${session.peerLabel}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Confrontate questo codice insieme: ${session.sasCode}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Quando il partner ha confermato il codice sul suo telefono, premi qui per completare.',
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _completeKeyDelivery,
              child: const Text('Completa ricezione chiave'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecoveryBackupCard(LocalDeviceIdentity id) {
    final Uint8List seed = id.recoverySeed!;
    final String sentence = RecoveryKeyCodec.toSentence(seed);
    final String qrPayload = RecoveryKeyCodec.toQrPayload(seed);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              id.recoverySavedConfirmed
                  ? 'Chiave di recupero salvata'
                  : 'Salva la tua chiave di recupero',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'I dati sono recuperabili finché esiste l’altro telefono oppure questa chiave salvata. Il server non può recuperarli al posto tuo.',
            ),
            const SizedBox(height: 8),
            SelectableText(
              sentence,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            const SizedBox(height: 8),
            Center(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                child: QrImageView(data: qrPayload, size: 140),
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              qrPayload,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            if (!id.recoverySavedConfirmed) ...<Widget>[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _recoveryCheckbox,
                onChanged: (bool? v) =>
                    setState(() => _recoveryCheckbox = v ?? false),
                title: const Text(
                  'Ho salvato le 24 parole o il QR in un luogo sicuro',
                ),
              ),
              FilledButton(
                onPressed: (!_busy && _recoveryCheckbox)
                    ? _confirmRecoverySaved
                    : null,
                child: const Text('Conferma salvataggio'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEventsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Buste cifrate E2EE',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedEventType,
              decoration: const InputDecoration(
                labelText: 'Tipo evento (solo dentro la busta cifrata)',
                border: OutlineInputBorder(),
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(
                  value: 'thinking_of_you',
                  child: Text('Thinking of you'),
                ),
                DropdownMenuItem(value: 'mood', child: Text('Mood del giorno')),
                DropdownMenuItem(
                  value: 'time_capsule',
                  child: Text('Time capsule (con data di apertura)'),
                ),
              ],
              onChanged: (String? v) {
                if (v != null) {
                  setState(() => _selectedEventType = v);
                }
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Testo di prova',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: <Widget>[
                FilledButton(
                  onPressed: _busy ? null : _sendTestEvent,
                  child: const Text('Invia busta cifrata'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _refreshSyncAndDevices,
                  child: const Text('Aggiorna'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final DecryptedEventRecord rec in _events)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('#${rec.envelope.seq} · ${rec.payload.eventType}'),
                subtitle: Text(jsonEncode(rec.payload.body)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDevicesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Dispositivi e arruolamento (F-20, SP02-06)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: <Widget>[
                OutlinedButton(
                  onPressed: _busy ? null : _createEnrollmentInvite,
                  child: const Text('Arruola nuovo telefono'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _refreshSyncAndDevices,
                  child: const Text('Ricarica dispositivi'),
                ),
              ],
            ),
            for (final DeviceSummary d in _devices)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${d.label} (${d.enrolledVia})'),
                subtitle: Text(
                  d.revokedAt == null
                      ? 'Attivo · ${d.deviceId}'
                      : 'Revocato · ${d.revokedAt!.toIso8601String()}',
                ),
                trailing: d.revokedAt == null
                    ? TextButton(
                        onPressed: _busy
                            ? null
                            : () => _revokeDevice(d.deviceId),
                        child: const Text('Revoca'),
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisibilityAuditCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Cosa vede il server (SP02-07)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _fetchVisibilityAudit,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Estrai dati grezzi dal server'),
            ),
            if (_visibilityAudit != null) ...<Widget>[
              const SizedBox(height: 8),
              SelectableText(
                const JsonEncoder.withIndent('  ').convert(_visibilityAudit),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.color,
    required this.textColor,
    required this.text,
  });

  final Color color;
  final Color textColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: TextStyle(color: textColor)),
    );
  }
}
