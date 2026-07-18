package org.dromara.framelean.storage;

import com.qcloud.cos.COSClient;
import com.qcloud.cos.exception.CosServiceException;
import com.qcloud.cos.http.HttpMethodName;
import com.qcloud.cos.model.AbortMultipartUploadRequest;
import com.qcloud.cos.model.CompleteMultipartUploadRequest;
import com.qcloud.cos.model.COSObject;
import com.qcloud.cos.model.GeneratePresignedUrlRequest;
import com.qcloud.cos.model.InitiateMultipartUploadRequest;
import com.qcloud.cos.model.ListPartsRequest;
import com.qcloud.cos.model.ObjectMetadata;
import com.qcloud.cos.model.PartETag;
import com.qcloud.cos.model.ResponseHeaderOverrides;
import lombok.RequiredArgsConstructor;
import org.dromara.framelean.config.FrameleanProperties;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.io.InputStream;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Comparator;
import java.util.Date;
import java.util.List;
import java.util.stream.Collectors;

@Component
@RequiredArgsConstructor
public class CosReleaseArtifactStorage implements ReleaseArtifactStorage {
    private final COSClient cosClient;
    private final FrameleanProperties properties;

    @Override
    public StoredObjectMetadata statObject(String objectKey) {
        try {
            ObjectMetadata metadata = cosClient.getObjectMetadata(properties.getCos().getBucket(), objectKey);
            return new StoredObjectMetadata(metadata.getContentLength(), metadata.getContentType());
        } catch (CosServiceException ex) {
            if (ex.getStatusCode() == 404) {
                return null;
            }
            throw ex;
        }
    }

    @Override
    public PresignedUrl presignDownload(String objectKey, String fileName, Duration expiresIn) {
        Date expiration = Date.from(Instant.now().plus(expiresIn));
        GeneratePresignedUrlRequest request = new GeneratePresignedUrlRequest(
            properties.getCos().getBucket(), objectKey, HttpMethodName.GET
        );
        request.setExpiration(expiration);
        ResponseHeaderOverrides headers = new ResponseHeaderOverrides();
        headers.setContentDisposition("attachment; filename=\"" + fileName + "\"");
        request.setResponseHeaders(headers);
        return new PresignedUrl(URI.create(cosClient.generatePresignedUrl(request).toString()), expiration.toInstant());
    }

    @Override
    public PresignedUrl presignUpload(String objectKey, Duration expiresIn) {
        Date expiration = Date.from(Instant.now().plus(expiresIn));
        GeneratePresignedUrlRequest request = new GeneratePresignedUrlRequest(
            properties.getCos().getBucket(), objectKey, HttpMethodName.PUT
        );
        request.setExpiration(expiration);
        return new PresignedUrl(URI.create(cosClient.generatePresignedUrl(request).toString()), expiration.toInstant());
    }

    @Override
    public String readTextObject(String objectKey) {
        try {
            COSObject object = cosClient.getObject(properties.getCos().getBucket(), objectKey);
            try (InputStream inputStream = object.getObjectContent()) {
                return new String(inputStream.readAllBytes(), StandardCharsets.UTF_8);
            }
        } catch (CosServiceException ex) {
            if (ex.getStatusCode() == 404) {
                return null;
            }
            throw ex;
        } catch (IOException ex) {
            throw new IllegalStateException("failed to read COS object: " + objectKey, ex);
        }
    }

    @Override
    public MultipartUploadSession initiateMultipartUpload(String objectKey, long partSize, String contentType) {
        ObjectMetadata metadata = new ObjectMetadata();
        if (contentType != null && !contentType.isBlank()) {
            metadata.setContentType(contentType);
        }
        var result = cosClient.initiateMultipartUpload(new InitiateMultipartUploadRequest(
            properties.getCos().getBucket(), objectKey, metadata
        ));
        return new MultipartUploadSession(objectKey, result.getUploadId(), partSize);
    }

    @Override
    public PresignedUrl presignUploadPart(String objectKey, String uploadId, int partNumber, Duration expiresIn) {
        Date expiration = Date.from(Instant.now().plus(expiresIn));
        GeneratePresignedUrlRequest request = new GeneratePresignedUrlRequest(
            properties.getCos().getBucket(), objectKey, HttpMethodName.PUT
        );
        request.setExpiration(expiration);
        request.addRequestParameter("partNumber", Integer.toString(partNumber));
        request.addRequestParameter("uploadId", uploadId);
        return new PresignedUrl(URI.create(cosClient.generatePresignedUrl(request).toString()), expiration.toInstant());
    }

    @Override
    public List<UploadedPart> listUploadedParts(String objectKey, String uploadId) {
        java.util.ArrayList<UploadedPart> parts = new java.util.ArrayList<>();
        Integer marker = null;
        boolean truncated;
        do {
            ListPartsRequest request = new ListPartsRequest(properties.getCos().getBucket(), objectKey, uploadId);
            request.setMaxParts(1000);
            if (marker != null) {
                request.setPartNumberMarker(marker);
            }
            var listing = cosClient.listParts(request);
            listing.getParts().forEach(part -> parts.add(new UploadedPart(part.getPartNumber(), part.getETag(), part.getSize())));
            marker = listing.getNextPartNumberMarker();
            truncated = listing.isTruncated();
        } while (truncated);
        parts.sort(Comparator.comparingInt(UploadedPart::partNumber));
        return parts;
    }

    @Override
    public CompletedMultipartUpload completeMultipartUpload(String objectKey, String uploadId, List<UploadedPart> parts) {
        List<PartETag> etags = parts.stream()
            .sorted(Comparator.comparingInt(UploadedPart::partNumber))
            .map(part -> new PartETag(part.partNumber(), part.eTag()))
            .collect(Collectors.toList());
        var result = cosClient.completeMultipartUpload(new CompleteMultipartUploadRequest(
            properties.getCos().getBucket(), objectKey, uploadId, etags
        ));
        return new CompletedMultipartUpload(objectKey, result.getETag());
    }

    @Override
    public void abortMultipartUpload(String objectKey, String uploadId) {
        cosClient.abortMultipartUpload(new AbortMultipartUploadRequest(properties.getCos().getBucket(), objectKey, uploadId));
    }

    @Override
    public void deleteObject(String objectKey) {
        cosClient.deleteObject(properties.getCos().getBucket(), objectKey);
    }
}
