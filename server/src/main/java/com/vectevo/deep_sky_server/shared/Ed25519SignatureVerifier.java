package com.vectevo.deep_sky_server.shared;

import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.KeyFactory;
import java.security.MessageDigest;
import java.security.PublicKey;
import java.security.Signature;
import java.security.spec.X509EncodedKeySpec;
import java.util.Base64;
import java.util.HexFormat;

/**
 * Standard JDK 25 Ed25519 signature and SHA-256 verification helpers (`AD-02`, `SP02-03`).
 */
public final class Ed25519SignatureVerifier {

	// RFC 8410 ASN.1 SubjectPublicKeyInfo prefix for a 32-byte raw Ed25519 public key.
	private static final byte[] ED25519_SPKI_PREFIX = HexFormat.of().parseHex("302a300506032b6570032100");
	private static final Base64.Decoder B64_URL_DECODER = Base64.getUrlDecoder();
	private static final Base64.Encoder B64_URL_ENCODER = Base64.getUrlEncoder();

	private Ed25519SignatureVerifier() {}

	public static byte[] decodeBase64Url(String value, int expectedBytes, String fieldName) {
		if (value == null || value.isBlank()) {
			throw new IllegalArgumentException(fieldName + " must not be blank");
		}
		final byte[] decoded;
		try {
			decoded = B64_URL_DECODER.decode(value.trim());
		} catch (IllegalArgumentException ex) {
			throw new IllegalArgumentException(fieldName + " is not valid base64url", ex);
		}
		if (expectedBytes > 0 && decoded.length != expectedBytes) {
			throw new IllegalArgumentException(
					fieldName + " must be " + expectedBytes + " bytes, got " + decoded.length);
		}
		return decoded;
	}

	public static byte[] decodeBase64UrlVariable(String value, String fieldName) {
		return decodeBase64Url(value, -1, fieldName);
	}

	public static String encodeBase64Url(byte[] bytes) {
		return B64_URL_ENCODER.encodeToString(bytes);
	}

	public static byte[] sha256(byte[] input) {
		try {
			return MessageDigest.getInstance("SHA-256").digest(input);
		} catch (GeneralSecurityException ex) {
			throw new IllegalStateException("SHA-256 unavailable", ex);
		}
	}

	public static String sha256Hex(byte[] input) {
		return HexFormat.of().formatHex(sha256(input));
	}

	public static boolean verify(byte[] rawPublicKey32, String messageUtf8, byte[] signature64) {
		if (rawPublicKey32 == null || rawPublicKey32.length != 32
				|| signature64 == null || signature64.length != 64) {
			return false;
		}
		try {
			byte[] spki = new byte[ED25519_SPKI_PREFIX.length + 32];
			System.arraycopy(ED25519_SPKI_PREFIX, 0, spki, 0, ED25519_SPKI_PREFIX.length);
			System.arraycopy(rawPublicKey32, 0, spki, ED25519_SPKI_PREFIX.length, 32);
			PublicKey publicKey = KeyFactory.getInstance("Ed25519").generatePublic(new X509EncodedKeySpec(spki));
			Signature verifier = Signature.getInstance("Ed25519");
			verifier.initVerify(publicKey);
			verifier.update(messageUtf8.getBytes(StandardCharsets.UTF_8));
			return verifier.verify(signature64);
		} catch (GeneralSecurityException ex) {
			return false;
		}
	}
}
