import 'dart:convert';
import 'dart:typed_data';

import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:cryptography/dart.dart';

/// Encodes and decodes 256-bit Deep Sky recovery seeds as 24 BIP-39 words
/// or a checksummed QR payload (`SP02-05`, `S-06`, `F-20`).
class RecoveryKeyCodec {
  const RecoveryKeyCodec._();

  static const String qrPrefix = 'deepsky-rk:v1:';
  static const int seedLengthBytes = 32;

  /// Encodes a 32-byte recovery seed as 24 English BIP-39 words.
  static List<String> toWords(Uint8List recoverySeed) {
    _requireSeedLength(recoverySeed);
    final Mnemonic mnemonic = Mnemonic(recoverySeed, Language.english);
    return List<String>.unmodifiable(mnemonic.words);
  }

  /// Encodes a 32-byte recovery seed as a space-separated 24-word sentence.
  static String toSentence(Uint8List recoverySeed) =>
      toWords(recoverySeed).join(' ');

  /// Decodes and checksum-validates a 24-word mnemonic sentence.
  static Uint8List fromSentence(String sentence) {
    final String normalized = sentence
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((String w) => w.isNotEmpty)
        .join(' ');
    if (normalized.isEmpty) {
      throw const FormatException('Recovery phrase cannot be empty.');
    }
    try {
      final Mnemonic mnemonic = Mnemonic.fromSentence(
        normalized,
        Language.english,
      );
      if (mnemonic.entropy.length != seedLengthBytes) {
        throw const FormatException('Recovery phrase must contain 24 words.');
      }
      return Uint8List.fromList(mnemonic.entropy);
    } on MnemonicException catch (err) {
      throw FormatException('Invalid recovery phrase: $err');
    }
  }

  /// Encodes a 32-byte recovery seed as a checksummed QR payload.
  static String toQrPayload(Uint8List recoverySeed) {
    _requireSeedLength(recoverySeed);
    final List<int> digest = const DartSha256().hashSync(recoverySeed).bytes;
    final Uint8List combined = Uint8List(seedLengthBytes + 4)
      ..setRange(0, seedLengthBytes, recoverySeed)
      ..setRange(seedLengthBytes, seedLengthBytes + 4, digest.sublist(0, 4));
    return '$qrPrefix${base64UrlEncode(combined)}';
  }

  /// Decodes and checksum-validates a recovery QR payload.
  static Uint8List fromQrPayload(String payload) {
    final String trimmed = payload.trim();
    if (!trimmed.startsWith(qrPrefix)) {
      throw const FormatException('Unrecognized recovery QR prefix.');
    }
    final String encoded = trimmed.substring(qrPrefix.length);
    final Uint8List raw = Uint8List.fromList(
      base64Url.decode(_padB64(encoded)),
    );
    if (raw.length != seedLengthBytes + 4) {
      throw const FormatException('Invalid recovery QR payload length.');
    }
    final Uint8List seed = Uint8List.sublistView(raw, 0, seedLengthBytes);
    final Uint8List actualChecksum = Uint8List.sublistView(
      raw,
      seedLengthBytes,
      seedLengthBytes + 4,
    );
    final List<int> expectedDigest = const DartSha256().hashSync(seed).bytes;
    for (int i = 0; i < 4; i++) {
      if (actualChecksum[i] != expectedDigest[i]) {
        throw const FormatException('Recovery QR checksum mismatch.');
      }
    }
    return Uint8List.fromList(seed);
  }

  /// Splits raw user recovery phrase text into normalized lowercase tokens.
  static List<String> tokenizeWords(String rawInput) {
    final String cleaned = rawInput.trim().toLowerCase();
    if (cleaned.isEmpty) {
      return const <String>[];
    }
    return cleaned
        .split(RegExp(r'\s+'))
        .where((String w) => w.isNotEmpty)
        .toList(growable: false);
  }

  /// Checks whether [word] belongs to the official BIP-39 English wordlist.
  static bool isValidWord(String word) {
    final String normalized = word.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    return Language.english.isValid(normalized);
  }

  /// Auto-detects QR payload or 24-word mnemonic input and returns the 32-byte seed.
  static Uint8List parseUserInput(String input) {
    final String trimmed = input.trim();
    if (trimmed.startsWith(qrPrefix)) {
      return fromQrPayload(trimmed);
    }
    return fromSentence(trimmed);
  }

  static void _requireSeedLength(Uint8List seed) {
    if (seed.length != seedLengthBytes) {
      throw ArgumentError.value(
        seed.length,
        'recoverySeed.length',
        'Recovery seed must be exactly $seedLengthBytes bytes.',
      );
    }
  }

  static String _padB64(String input) {
    final int rem = input.length % 4;
    return rem == 0 ? input : input.padRight(input.length + (4 - rem), '=');
  }
}
