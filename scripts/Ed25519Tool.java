import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.GeneralSecurityException;
import java.security.KeyFactory;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.MessageDigest;
import java.security.PrivateKey;
import java.security.PublicKey;
import java.security.Signature;
import java.security.spec.PKCS8EncodedKeySpec;
import java.security.spec.X509EncodedKeySpec;
import java.util.Base64;
import java.util.HexFormat;

/**
 * Dependency-free Ed25519 key generation, signing, and verification utility
 * for Deep Sky release and content manifests (SEC-03, SEC-04, CNT-01).
 */
public final class Ed25519Tool {

    private Ed25519Tool() {}

    public static void main(String[] args) throws Exception {
        if (args.length < 1) {
            printUsageAndExit();
        }
        String command = args[0];
        switch (command) {
            case "generate" -> handleGenerate(args);
            case "sign" -> handleSign(args);
            case "verify" -> handleVerify(args);
            default -> {
                System.err.println("Unknown command: " + command);
                printUsageAndExit();
            }
        }
    }

    private static void handleGenerate(String[] args) throws GeneralSecurityException, IOException {
        Path outDir = Path.of(requireArg(args, "--out-dir"));
        Files.createDirectories(outDir);

        KeyPairGenerator kpg = KeyPairGenerator.getInstance("Ed25519");
        KeyPair kp = kpg.generateKeyPair();

        byte[] privBytes = kp.getPrivate().getEncoded();
        byte[] pubBytes = kp.getPublic().getEncoded();

        String privB64 = Base64.getEncoder().encodeToString(privBytes);
        String pubB64 = Base64.getEncoder().encodeToString(pubBytes);
        String pubSha256 = HexFormat.of().formatHex(
                MessageDigest.getInstance("SHA-256").digest(pubBytes));

        Files.writeString(outDir.resolve("ed25519-private.pkcs8.b64"), privB64 + System.lineSeparator(), StandardCharsets.UTF_8);
        Files.writeString(outDir.resolve("ed25519-public.x509.b64"), pubB64 + System.lineSeparator(), StandardCharsets.UTF_8);
        Files.writeString(outDir.resolve("ed25519-public.sha256"), pubSha256 + System.lineSeparator(), StandardCharsets.UTF_8);

        System.out.println("Generated Ed25519 keypair in " + outDir.toAbsolutePath());
        System.out.println("Public key SHA-256: " + pubSha256);
    }

    private static void handleSign(String[] args) throws GeneralSecurityException, IOException {
        Path keyPath = Path.of(requireArg(args, "--key"));
        Path inPath = Path.of(requireArg(args, "--in"));
        Path outPath = Path.of(requireArg(args, "--out"));

        byte[] privBytes = Base64.getDecoder().decode(Files.readString(keyPath, StandardCharsets.UTF_8).trim());
        PrivateKey privateKey = KeyFactory.getInstance("Ed25519")
                .generatePrivate(new PKCS8EncodedKeySpec(privBytes));

        byte[] payload = Files.readAllBytes(inPath);
        Signature sig = Signature.getInstance("Ed25519");
        sig.initSign(privateKey);
        sig.update(payload);
        byte[] signature = sig.sign();

        Files.writeString(outPath, Base64.getEncoder().encodeToString(signature) + System.lineSeparator(), StandardCharsets.UTF_8);
        System.out.println("Signed " + inPath + " -> " + outPath);
    }

    private static void handleVerify(String[] args) throws GeneralSecurityException, IOException {
        Path pubPath = Path.of(requireArg(args, "--pub"));
        Path inPath = Path.of(requireArg(args, "--in"));
        Path sigPath = Path.of(requireArg(args, "--sig"));

        byte[] pubBytes = Base64.getDecoder().decode(Files.readString(pubPath, StandardCharsets.UTF_8).trim());
        PublicKey publicKey = KeyFactory.getInstance("Ed25519")
                .generatePublic(new X509EncodedKeySpec(pubBytes));

        byte[] payload = Files.readAllBytes(inPath);
        byte[] signature = Base64.getDecoder().decode(Files.readString(sigPath, StandardCharsets.UTF_8).trim());

        Signature verifier = Signature.getInstance("Ed25519");
        verifier.initVerify(publicKey);
        verifier.update(payload);
        if (!verifier.verify(signature)) {
            System.err.println("Signature verification FAILED for " + inPath);
            System.exit(2);
        }
        System.out.println("Signature verification OK for " + inPath);
    }

    private static String requireArg(String[] args, String flag) {
        for (int i = 1; i < args.length - 1; i++) {
            if (flag.equals(args[i])) {
                return args[i + 1];
            }
        }
        System.err.println("Missing required argument: " + flag);
        printUsageAndExit();
        return "";
    }

    private static void printUsageAndExit() {
        System.err.println("""
                Usage:
                  java scripts/Ed25519Tool.java generate --out-dir <dir>
                  java scripts/Ed25519Tool.java sign --key <private.b64> --in <file> --out <file.sig>
                  java scripts/Ed25519Tool.java verify --pub <public.b64> --in <file> --sig <file.sig>""");
        System.exit(1);
    }
}
