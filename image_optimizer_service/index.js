require("dotenv").config();
const express = require("express");
const multer = require("multer");
const sharp = require("sharp");
const { initializeApp, cert } = require("firebase-admin/app");
const { getStorage } = require("firebase-admin/storage");
const crypto = require("crypto");
const path = require("path");

// ─── Firebase Admin Setup ────────────────────────────────────────────
// In production, set GOOGLE_APPLICATION_CREDENTIALS env var to the path
// of your service-account JSON, or provide the key inline via env vars.
initializeApp({
  credential: cert(
    JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON || "{}")
  ),
  storageBucket: process.env.FIREBASE_STORAGE_BUCKET || "synq-task-app.firebasestorage.app",
});

const bucket = getStorage().bucket();

// ─── Express + Multer Setup ─────────────────────────────────────────
const app = express();
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB cap
});

// ─── Health Check ───────────────────────────────────────────────────
app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

// ─── Upload + Optimize Endpoint ─────────────────────────────────────
app.post("/upload", upload.single("image"), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: "No image file provided." });
    }

    const inputBuffer = req.file.buffer;
    const image = sharp(inputBuffer);
    const meta = await image.metadata();

    let optimizedBuffer;
    let outputContentType = req.file.mimetype;
    let outputExtension = path.extname(req.file.originalname) || ".jpg";

    // ── Format-specific lossless optimization ──
    if (meta.format === "png") {
      optimizedBuffer = await image
        .png({ compressionLevel: 9, effort: 10 })
        .withMetadata(false) // strip EXIF
        .toBuffer();
      outputContentType = "image/png";
      outputExtension = ".png";
    } else if (meta.format === "jpeg" || meta.format === "jpg") {
      optimizedBuffer = await image
        .jpeg({ quality: 100, mozjpeg: true })
        .withMetadata(false)
        .toBuffer();
      outputContentType = "image/jpeg";
      outputExtension = ".jpg";
    } else if (["bmp", "tiff"].includes(meta.format)) {
      // Convert wasteful formats to lossless WebP
      optimizedBuffer = await image
        .webp({ lossless: true, effort: 6 })
        .withMetadata(false)
        .toBuffer();
      outputContentType = "image/webp";
      outputExtension = ".webp";
    } else {
      // WebP, GIF, etc. — just strip metadata
      optimizedBuffer = await image.withMetadata(false).toBuffer();
    }

    // ── Upload to Firebase Storage ──
    const filename = `attachments/${crypto.randomUUID()}${outputExtension}`;
    const file = bucket.file(filename);

    await file.save(optimizedBuffer, {
      metadata: {
        contentType: outputContentType,
        metadata: {
          optimized: "true",
          originalSize: inputBuffer.length.toString(),
          optimizedSize: optimizedBuffer.length.toString(),
        },
      },
    });

    // Make the file publicly readable (or use signed URLs if you prefer)
    await file.makePublic();

    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${filename}`;

    const savingsPercent = (
      (1 - optimizedBuffer.length / inputBuffer.length) *
      100
    ).toFixed(1);

    console.log(
      `✓ Optimized ${req.file.originalname}: ${inputBuffer.length} → ${optimizedBuffer.length} bytes (${savingsPercent}% saved)`
    );

    return res.json({
      status: "success",
      url: publicUrl,
      filename,
      originalSize: inputBuffer.length,
      optimizedSize: optimizedBuffer.length,
      savingsPercent: parseFloat(savingsPercent),
    });
  } catch (err) {
    console.error("Upload error:", err);
    return res.status(500).json({ error: "Failed to process image." });
  }
});

// ─── Start Server ───────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🖼️  Image Optimizer Service running on port ${PORT}`);
});
