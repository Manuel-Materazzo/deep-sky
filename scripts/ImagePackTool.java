import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.PriorityQueue;
import java.util.zip.CRC32;
import java.util.zip.Deflater;
import java.util.zip.DeflaterOutputStream;
import javax.imageio.ImageIO;

/**
 * Dependency-free high-quality RGBA PNG resizer and optimizer for Deep Sky content packs
 * (A-02, A-04, DD-10).
 *
 * <p>Uses premultiplied bicubic progressive downscaling to prevent alpha edge halos (A-04).
 * Encodes lossless 32-bit RGBA PNG first (with zeroed RGB on alpha=0 pixels and optimal Paeth
 * filtering at zlib level 9); if the file exceeds {@code --max-bytes}, encodes a crisp
 * 256-color RGBA indexed PNG (PNG8 with full {@code PLTE} + {@code tRNS} alpha table and
 * subtle RGB error diffusion) to stay well within DD-10 mobile budgets.
 */
public final class ImagePackTool {

    private ImagePackTool() {}

    public static void main(String[] args) throws Exception {
        if (args.length < 1) {
            printUsageAndExit();
        }
        switch (args[0]) {
            case "resize" -> handleResize(args);
            case "inspect" -> handleInspect(args);
            default -> {
                System.err.println("Unknown command: " + args[0]);
                printUsageAndExit();
            }
        }
    }

    private static void handleResize(String[] args) throws IOException {
        Path inPath = Path.of(requireArg(args, "--in"));
        Path outPath = Path.of(requireArg(args, "--out"));
        int targetW = Integer.parseInt(requireArg(args, "--width"));
        int targetH = Integer.parseInt(requireArg(args, "--height"));
        long maxBytes = parseOptionalLong(args, "--max-bytes", Long.MAX_VALUE);

        BufferedImage src = ImageIO.read(inPath.toFile());
        if (src == null) {
            throw new IOException("Unable to decode image: " + inPath);
        }

        BufferedImage premul = toPremultipliedArgb(src);
        BufferedImage scaled = progressiveScale(premul, targetW, targetH);
        BufferedImage outImg = toStraightArgb(scaled);

        byte[] losslessPng = encodeRgba32Png(outImg);
        byte[] chosen = losslessPng;
        String mode = "RGBA32";

        if (losslessPng.length > maxBytes) {
            float[] dithers = {0.55f, 0.25f, 0.0f};
            int[] colorCounts = {256, 192, 160};
            for (int i = 0; i < dithers.length; i++) {
                byte[] indexedPng = encodeIndexedRgba8Png(outImg, colorCounts[i], dithers[i]);
                if (indexedPng.length < chosen.length) {
                    chosen = indexedPng;
                    mode = "PNG8-RGBA(" + colorCounts[i] + ")";
                }
                if (chosen.length <= maxBytes) {
                    break;
                }
            }
        }

        Files.createDirectories(outPath.toAbsolutePath().getParent());
        Files.write(outPath, chosen);
        System.out.printf("Resized %s (%dx%d) -> %s (%dx%d, %s, %d bytes)%n",
                inPath.getFileName(), src.getWidth(), src.getHeight(),
                outPath.getFileName(), targetW, targetH, mode, chosen.length);
    }

    private static void handleInspect(String[] args) throws IOException {
        Path inPath = Path.of(requireArg(args, "--in"));
        BufferedImage img = ImageIO.read(inPath.toFile());
        if (img == null) {
            throw new IOException("Unable to decode image: " + inPath);
        }
        boolean hasAlpha = img.getColorModel().hasAlpha();
        int transparentPixels = 0;
        int totalPixels = img.getWidth() * img.getHeight();
        if (hasAlpha) {
            for (int y = 0; y < img.getHeight(); y++) {
                for (int x = 0; x < img.getWidth(); x++) {
                    if (((img.getRGB(x, y) >>> 24) & 0xFF) == 0) {
                        transparentPixels++;
                    }
                }
            }
        }
        double transparentPct = (transparentPixels * 100.0) / Math.max(1, totalPixels);
        System.out.printf("%s: %dx%d alpha=%s transparent=%.1f%% bytes=%d%n",
                inPath.getFileName(), img.getWidth(), img.getHeight(), hasAlpha, transparentPct, Files.size(inPath));
    }

    private static BufferedImage toPremultipliedArgb(BufferedImage src) {
        BufferedImage dst = new BufferedImage(src.getWidth(), src.getHeight(), BufferedImage.TYPE_INT_ARGB_PRE);
        Graphics2D g = dst.createGraphics();
        try {
            g.drawImage(src, 0, 0, null);
        } finally {
            g.dispose();
        }
        return dst;
    }

    private static BufferedImage toStraightArgb(BufferedImage src) {
        BufferedImage dst = new BufferedImage(src.getWidth(), src.getHeight(), BufferedImage.TYPE_INT_ARGB);
        Graphics2D g = dst.createGraphics();
        try {
            g.drawImage(src, 0, 0, null);
        } finally {
            g.dispose();
        }
        return dst;
    }

    private static BufferedImage progressiveScale(BufferedImage src, int targetW, int targetH) {
        BufferedImage current = src;
        int w = src.getWidth();
        int h = src.getHeight();
        while (w / 2 >= targetW && h / 2 >= targetH) {
            w = Math.max(targetW, w / 2);
            h = Math.max(targetH, h / 2);
            current = drawScaled(current, w, h);
        }
        if (current.getWidth() != targetW || current.getHeight() != targetH) {
            current = drawScaled(current, targetW, targetH);
        }
        return current;
    }

    private static BufferedImage drawScaled(BufferedImage src, int w, int h) {
        BufferedImage dst = new BufferedImage(w, h, BufferedImage.TYPE_INT_ARGB_PRE);
        Graphics2D g = dst.createGraphics();
        try {
            g.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BICUBIC);
            g.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
            g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
            g.setRenderingHint(RenderingHints.KEY_ALPHA_INTERPOLATION, RenderingHints.VALUE_ALPHA_INTERPOLATION_QUALITY);
            g.drawImage(src, 0, 0, w, h, null);
        } finally {
            g.dispose();
        }
        return dst;
    }

    /** Lossless 32-bit RGBA PNG with transparent-pixel RGB zeroing and Paeth scanline filtering. */
    private static byte[] encodeRgba32Png(BufferedImage img) throws IOException {
        int w = img.getWidth();
        int h = img.getHeight();
        int[] argb = img.getRGB(0, 0, w, h, null, 0, w);
        int stride = w * 4;
        byte[] raw = new byte[h * (1 + stride)];
        byte[] prevRow = new byte[stride];
        byte[] curRow = new byte[stride];
        int outPos = 0;

        for (int y = 0; y < h; y++) {
            int rowOff = y * w;
            for (int x = 0; x < w; x++) {
                int p = argb[rowOff + x];
                int a = (p >>> 24) & 0xFF;
                int base = x * 4;
                if (a == 0) {
                    curRow[base] = 0;
                    curRow[base + 1] = 0;
                    curRow[base + 2] = 0;
                    curRow[base + 3] = 0;
                } else {
                    curRow[base] = (byte) ((p >>> 16) & 0xFF);
                    curRow[base + 1] = (byte) ((p >>> 8) & 0xFF);
                    curRow[base + 2] = (byte) (p & 0xFF);
                    curRow[base + 3] = (byte) a;
                }
            }
            raw[outPos++] = 4; // Paeth
            for (int i = 0; i < stride; i++) {
                int a = i >= 4 ? (curRow[i - 4] & 0xFF) : 0;
                int b = prevRow[i] & 0xFF;
                int c = i >= 4 ? (prevRow[i - 4] & 0xFF) : 0;
                raw[outPos++] = (byte) ((curRow[i] & 0xFF) - paeth(a, b, c));
            }
            System.arraycopy(curRow, 0, prevRow, 0, stride);
        }

        byte[] ihdr = buildIhdr(w, h, 8, 6);
        return assemblePng(ihdr, null, null, zlibCompress(raw));
    }

    /** 256-color RGBA PNG8 (PLTE + tRNS) via median-cut quantization with configurable RGB error diffusion. */
    private static byte[] encodeIndexedRgba8Png(BufferedImage img, int maxColors, float ditherStrength) throws IOException {
        int w = img.getWidth();
        int h = img.getHeight();
        int[] argb = img.getRGB(0, 0, w, h, null, 0, w);

        // Build histogram quantized to 5-bit per channel (RGB5A5) for fast median-cut
        Map<Integer, Integer> hist = new HashMap<>(16384);
        boolean hasFullyTransparent = false;
        for (int p : argb) {
            int a = (p >>> 24) & 0xFF;
            if (a == 0) {
                hasFullyTransparent = true;
                continue;
            }
            int key = (((p >>> 19) & 0x1F) << 15)
                    | (((p >>> 11) & 0x1F) << 10)
                    | (((p >>> 3) & 0x1F) << 5)
                    | (a >>> 3);
            hist.merge(key, 1, Integer::sum);
        }

        int targetPalette = hasFullyTransparent ? maxColors - 1 : maxColors;
        List<int[]> colors = new ArrayList<>(hist.size());
        for (Map.Entry<Integer, Integer> e : hist.entrySet()) {
            int k = e.getKey();
            int r = ((k >>> 15) & 0x1F) * 255 / 31;
            int g = ((k >>> 10) & 0x1F) * 255 / 31;
            int b = ((k >>> 5) & 0x1F) * 255 / 31;
            int a = (k & 0x1F) * 255 / 31;
            colors.add(new int[] {r, g, b, a, e.getValue()});
        }

        List<int[]> palette = medianCut(colors, Math.max(1, targetPalette));
        if (hasFullyTransparent) {
            palette.add(0, new int[] {0, 0, 0, 0});
        }

        int palSize = palette.size();
        int[] pr = new int[palSize];
        int[] pg = new int[palSize];
        int[] pb = new int[palSize];
        int[] pa = new int[palSize];
        for (int i = 0; i < palSize; i++) {
            pr[i] = palette.get(i)[0];
            pg[i] = palette.get(i)[1];
            pb[i] = palette.get(i)[2];
            pa[i] = palette.get(i)[3];
        }

        // Map pixels with gentle Floyd-Steinberg error diffusion (damped 0.75 to avoid grain)
        float[] errR = new float[w * 2];
        float[] errG = new float[w * 2];
        float[] errB = new float[w * 2];
        byte[] indices = new byte[h * (1 + w)];
        int outPos = 0;

        for (int y = 0; y < h; y++) {
            indices[outPos++] = 0; // None filter works best on indexed scanlines
            int curRowOff = (y & 1) * w;
            int nextRowOff = ((y + 1) & 1) * w;
            Arrays.fill(errR, nextRowOff, nextRowOff + w, 0f);
            Arrays.fill(errG, nextRowOff, nextRowOff + w, 0f);
            Arrays.fill(errB, nextRowOff, nextRowOff + w, 0f);

            int rowPx = y * w;
            for (int x = 0; x < w; x++) {
                int p = argb[rowPx + x];
                int a = (p >>> 24) & 0xFF;
                if (a == 0 && hasFullyTransparent) {
                    indices[outPos++] = 0;
                    continue;
                }
                int r = clampByte(Math.round(((p >>> 16) & 0xFF) + errR[curRowOff + x]));
                int g = clampByte(Math.round(((p >>> 8) & 0xFF) + errG[curRowOff + x]));
                int b = clampByte(Math.round((p & 0xFF) + errB[curRowOff + x]));

                int bestIdx = hasFullyTransparent ? 1 : 0;
                int bestDist = Integer.MAX_VALUE;
                int start = hasFullyTransparent ? 1 : 0;
                for (int i = start; i < palSize; i++) {
                    int dr = r - pr[i];
                    int dg = g - pg[i];
                    int db = b - pb[i];
                    int da = a - pa[i];
                    int dist = dr * dr * 2 + dg * dg * 4 + db * db + da * da * 6;
                    if (dist < bestDist) {
                        bestDist = dist;
                        bestIdx = i;
                        if (dist == 0) {
                            break;
                        }
                    }
                }
                indices[outPos++] = (byte) bestIdx;

                if (a >= 240 && ditherStrength > 0f) {
                    float dr = (r - pr[bestIdx]) * ditherStrength;
                    float dg = (g - pg[bestIdx]) * ditherStrength;
                    float db = (b - pb[bestIdx]) * ditherStrength;
                    if (x + 1 < w) {
                        errR[curRowOff + x + 1] += dr * (7f / 16f);
                        errG[curRowOff + x + 1] += dg * (7f / 16f);
                        errB[curRowOff + x + 1] += db * (7f / 16f);
                    }
                    if (y + 1 < h) {
                        if (x > 0) {
                            errR[nextRowOff + x - 1] += dr * (3f / 16f);
                            errG[nextRowOff + x - 1] += dg * (3f / 16f);
                            errB[nextRowOff + x - 1] += db * (3f / 16f);
                        }
                        errR[nextRowOff + x] += dr * (5f / 16f);
                        errG[nextRowOff + x] += dg * (5f / 16f);
                        errB[nextRowOff + x] += db * (5f / 16f);
                        if (x + 1 < w) {
                            errR[nextRowOff + x + 1] += dr * (1f / 16f);
                            errG[nextRowOff + x + 1] += dg * (1f / 16f);
                            errB[nextRowOff + x + 1] += db * (1f / 16f);
                        }
                    }
                }
            }
        }

        byte[] plte = new byte[palSize * 3];
        int lastNonOpaque = -1;
        for (int i = 0; i < palSize; i++) {
            plte[i * 3] = (byte) pr[i];
            plte[i * 3 + 1] = (byte) pg[i];
            plte[i * 3 + 2] = (byte) pb[i];
            if (pa[i] < 255) {
                lastNonOpaque = i;
            }
        }
        byte[] trns = null;
        if (lastNonOpaque >= 0) {
            trns = new byte[lastNonOpaque + 1];
            for (int i = 0; i <= lastNonOpaque; i++) {
                trns[i] = (byte) pa[i];
            }
        }

        byte[] ihdr = buildIhdr(w, h, 8, 3);
        return assemblePng(ihdr, plte, trns, zlibCompress(indices));
    }

    private static List<int[]> medianCut(List<int[]> entries, int maxBoxes) {
        if (entries.isEmpty()) {
            return new ArrayList<>(List.of(new int[] {0, 0, 0, 255}));
        }
        PriorityQueue<ColorBox> pq = new PriorityQueue<>(
                Comparator.comparingLong(ColorBox::priority).reversed());
        pq.add(new ColorBox(entries));

        while (pq.size() < maxBoxes) {
            ColorBox box = pq.poll();
            if (box == null || box.entries.size() < 2 || box.maxRange() == 0) {
                if (box != null) {
                    pq.add(box);
                }
                break;
            }
            ColorBox[] split = box.split();
            pq.add(split[0]);
            pq.add(split[1]);
        }

        List<int[]> result = new ArrayList<>(pq.size());
        for (ColorBox box : pq) {
            result.add(box.weightedAverage());
        }
        return result;
    }

    private static final class ColorBox {
        final List<int[]> entries;
        final int[] min = {255, 255, 255, 255};
        final int[] max = {0, 0, 0, 0};
        final long totalWeight;

        ColorBox(List<int[]> entries) {
            this.entries = entries;
            long w = 0;
            for (int[] c : entries) {
                for (int ch = 0; ch < 4; ch++) {
                    if (c[ch] < min[ch]) min[ch] = c[ch];
                    if (c[ch] > max[ch]) max[ch] = c[ch];
                }
                w += c[4];
            }
            this.totalWeight = w;
        }

        int maxRangeChannel() {
            int bestCh = 0;
            int bestVal = -1;
            int[] weights = {2, 3, 1, 4};
            for (int ch = 0; ch < 4; ch++) {
                int span = (max[ch] - min[ch]) * weights[ch];
                if (span > bestVal) {
                    bestVal = span;
                    bestCh = ch;
                }
            }
            return bestCh;
        }

        int maxRange() {
            int ch = maxRangeChannel();
            return max[ch] - min[ch];
        }

        long priority() {
            if (entries.size() < 2) {
                return 0;
            }
            return totalWeight * Math.max(1, maxRange());
        }

        ColorBox[] split() {
            int ch = maxRangeChannel();
            entries.sort(Comparator.comparingInt(c -> c[ch]));
            long half = totalWeight / 2;
            long acc = 0;
            int splitIdx = 1;
            for (int i = 0; i < entries.size() - 1; i++) {
                acc += entries.get(i)[4];
                splitIdx = i + 1;
                if (acc >= half) {
                    break;
                }
            }
            return new ColorBox[] {
                    new ColorBox(new ArrayList<>(entries.subList(0, splitIdx))),
                    new ColorBox(new ArrayList<>(entries.subList(splitIdx, entries.size())))
            };
        }

        int[] weightedAverage() {
            long sr = 0, sg = 0, sb = 0, sa = 0, sw = 0;
            for (int[] c : entries) {
                long w = c[4];
                sr += c[0] * w;
                sg += c[1] * w;
                sb += c[2] * w;
                sa += c[3] * w;
                sw += w;
            }
            long denom = Math.max(1, sw);
            return new int[] {
                    clampByte((int) Math.round((double) sr / denom)),
                    clampByte((int) Math.round((double) sg / denom)),
                    clampByte((int) Math.round((double) sb / denom)),
                    clampByte((int) Math.round((double) sa / denom))
            };
        }
    }

    private static int clampByte(int v) {
        return Math.max(0, Math.min(255, v));
    }

    private static int paeth(int a, int b, int c) {
        int p = a + b - c;
        int pa = Math.abs(p - a);
        int pb = Math.abs(p - b);
        int pc = Math.abs(p - c);
        if (pa <= pb && pa <= pc) return a;
        if (pb <= pc) return b;
        return c;
    }

    private static byte[] buildIhdr(int w, int h, int bitDepth, int colorType) throws IOException {
        ByteArrayOutputStream baos = new ByteArrayOutputStream(13);
        DataOutputStream dos = new DataOutputStream(baos);
        dos.writeInt(w);
        dos.writeInt(h);
        dos.writeByte(bitDepth);
        dos.writeByte(colorType);
        dos.writeByte(0); // compression
        dos.writeByte(0); // filter
        dos.writeByte(0); // interlace
        return baos.toByteArray();
    }

    private static byte[] zlibCompress(byte[] raw) throws IOException {
        ByteArrayOutputStream baos = new ByteArrayOutputStream(raw.length / 2);
        Deflater deflater = new Deflater(Deflater.BEST_COMPRESSION);
        try (DeflaterOutputStream dos = new DeflaterOutputStream(baos, deflater)) {
            dos.write(raw);
        } finally {
            deflater.end();
        }
        return baos.toByteArray();
    }

    private static byte[] assemblePng(byte[] ihdr, byte[] plte, byte[] trns, byte[] idat) throws IOException {
        ByteArrayOutputStream baos = new ByteArrayOutputStream(idat.length + 1024);
        DataOutputStream dos = new DataOutputStream(baos);
        dos.write(new byte[] {(byte) 0x89, 'P', 'N', 'G', '\r', '\n', 0x1A, '\n'});
        writeChunk(dos, "IHDR", ihdr);
        if (plte != null) {
            writeChunk(dos, "PLTE", plte);
        }
        if (trns != null) {
            writeChunk(dos, "tRNS", trns);
        }
        writeChunk(dos, "IDAT", idat);
        writeChunk(dos, "IEND", new byte[0]);
        return baos.toByteArray();
    }

    private static void writeChunk(DataOutputStream dos, String type, byte[] data) throws IOException {
        byte[] typeBytes = type.getBytes(StandardCharsets.US_ASCII);
        dos.writeInt(data.length);
        dos.write(typeBytes);
        dos.write(data);
        CRC32 crc = new CRC32();
        crc.update(typeBytes);
        crc.update(data);
        dos.writeInt((int) crc.getValue());
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

    private static long parseOptionalLong(String[] args, String flag, long fallback) {
        for (int i = 1; i < args.length - 1; i++) {
            if (flag.equals(args[i])) {
                return Long.parseLong(args[i + 1]);
            }
        }
        return fallback;
    }

    private static void printUsageAndExit() {
        System.err.println("""
                Usage:
                  java scripts/ImagePackTool.java resize --in <src.png> --out <dst.png> --width <W> --height <H> [--max-bytes <N>]
                  java scripts/ImagePackTool.java inspect --in <img.png>""");
        System.exit(1);
    }
}
