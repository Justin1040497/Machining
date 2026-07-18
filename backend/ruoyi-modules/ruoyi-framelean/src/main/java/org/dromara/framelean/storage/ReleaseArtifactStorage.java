package org.dromara.framelean.storage;

import java.net.URI;
import java.time.Duration;
import java.time.Instant;
import java.util.List;

public interface ReleaseArtifactStorage {
    StoredObjectMetadata statObject(String objectKey);

    PresignedUrl presignDownload(String objectKey, String fileName, Duration expiresIn);

    PresignedUrl presignUpload(String objectKey, Duration expiresIn);

    String readTextObject(String objectKey);

    MultipartUploadSession initiateMultipartUpload(String objectKey, long partSize, String contentType);

    PresignedUrl presignUploadPart(String objectKey, String uploadId, int partNumber, Duration expiresIn);

    List<UploadedPart> listUploadedParts(String objectKey, String uploadId);

    CompletedMultipartUpload completeMultipartUpload(String objectKey, String uploadId, List<UploadedPart> parts);

    void abortMultipartUpload(String objectKey, String uploadId);

    void deleteObject(String objectKey);

    record StoredObjectMetadata(long size, String contentType) {
    }

    record PresignedUrl(URI url, Instant expiresAt) {
    }

    record MultipartUploadSession(String objectKey, String uploadId, long partSize) {
    }

    record UploadedPart(int partNumber, String eTag, long size) {
    }

    record CompletedMultipartUpload(String objectKey, String eTag) {
    }
}
