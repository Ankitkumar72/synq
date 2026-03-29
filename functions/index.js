const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

/**
 * Trigger: On Note Creation
 * Logic: Increments the user's storage_used_bytes by the size of the note body.
 */
exports.onNoteCreate = functions.firestore
    .document('users/{userId}/notes/{noteId}')
    .onCreate(async (snap, context) => {
        const userId = context.params.userId;
        const noteData = snap.data();
        
        // Calculate size of body (approx bytes)
        const bodySize = Buffer.byteLength(noteData.body || '', 'utf8');
        
        const userRef = admin.firestore().collection('users').doc(userId);
        return userRef.update({
            storage_used_bytes: admin.firestore.FieldValue.increment(bodySize)
        });
    });

/**
 * Trigger: On Note Deletion
 * Logic: 
 * 1. Subtracts the note body size from storage_used_bytes.
 * 2. Deletes all associated image attachments from Firebase Storage to prevent orphans.
 */
exports.onNoteDelete = functions.firestore
    .document('users/{userId}/notes/{noteId}')
    .onDelete(async (snap, context) => {
        const userId = context.params.userId;
        const noteData = snap.data();
        
        // 1. Quota cleanup
        const bodySize = Buffer.byteLength(noteData.body || '', 'utf8');
        const userRef = admin.firestore().collection('users').doc(userId);
        await userRef.update({
            storage_used_bytes: admin.firestore.FieldValue.increment(-bodySize)
        });

        // 2. Orphan file cleanup
        const attachments = noteData.attachments || [];
        const bucket = admin.storage().bucket();
        
        const deletePromises = attachments.map(async (url) => {
            if (url.startsWith('http')) {
                try {
                    // Extract path from download URL or use a structured approach
                    // Download URLs: https://firebasestorage.googleapis.com/v0/b/.../o/attachments%2F...
                    const decodedUrl = decodeURIComponent(url);
                    const pathPart = decodedUrl.split('/o/')[1].split('?')[0];
                    return bucket.file(pathPart).delete();
                } catch (e) {
                    console.error(`Failed to delete orphaned file: ${url}`, e);
                }
            }
            return Promise.resolve();
        });

        return Promise.all(deletePromises);
    });
