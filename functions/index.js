const { onObjectFinalized } = require("firebase-functions/v2/storage");
const { getStorage } = require("firebase-admin/storage");
const admin = require("firebase-admin");
const sharp = require("sharp");

admin.initializeApp();

exports.optimizeImage = onObjectFinalized(
  {
    // Configure function resources (sharp needs some memory)
    memory: "1GiB",
    timeoutSeconds: 120
  },
  async (event) => {
    const fileBucket = event.data.bucket;
    const filePath = event.data.name;
    const contentType = event.data.contentType;
    const metadata = event.data.metadata;

    // Don't process if it's already optimized
    if (metadata && metadata.optimized === "true") {
      console.log(`File ${filePath} is already optimized. Skipping.`);
      return;
    }

    // Only process images
    if (!contentType || !contentType.startsWith("image/")) {
      console.log(`File ${filePath} is not an image (${contentType}). Skipping.`);
      return;
    }

    const bucket = getStorage().bucket(fileBucket);
    const file = bucket.file(filePath);

    try {
      // Download the image into memory
      console.log(`Downloading ${filePath} for optimization...`);
      const [buffer] = await file.download();
      
      const image = sharp(buffer);
      const meta = await image.metadata();
      
      let optimizedBuffer;
      let newContentType = contentType;

      // Apply format-specific lossless optimization
      if (meta.format === "png") {
        optimizedBuffer = await image
          .png({ compressionLevel: 9, effort: 10 })
          .withMetadata(false)
          .toBuffer();
      } else if (meta.format === "jpeg" || meta.format === "jpg") {
        optimizedBuffer = await image
          .jpeg({ quality: 100, mozjpeg: true })
          .withMetadata(false)
          .toBuffer();
      } else if (["bmp", "tiff"].includes(meta.format)) {
        optimizedBuffer = await image
          .webp({ lossless: true, effort: 6 })
          .withMetadata(false)
          .toBuffer();
        newContentType = "image/webp";
      } else {
        // Fallback for WebP, GIF, etc. - just strip metadata
        optimizedBuffer = await image
          .withMetadata(false)
          .toBuffer();
      }

      console.log(`Uploading optimized version of ${filePath}...`);
      
      // Upload the optimized image back, overwriting the original
      await file.save(optimizedBuffer, {
        metadata: {
          contentType: newContentType,
          metadata: {
            optimized: "true",
            originalSize: buffer.length.toString(),
            optimizedSize: optimizedBuffer.length.toString()
          }
        }
      });
      
      const savings = ((1 - (optimizedBuffer.length / buffer.length)) * 100).toFixed(1);
      console.log(`Successfully optimized ${filePath}. Saved ${savings}%.`);
      
    } catch (error) {
      console.error(`Error optimizing ${filePath}:`, error);
    }
  }
);
