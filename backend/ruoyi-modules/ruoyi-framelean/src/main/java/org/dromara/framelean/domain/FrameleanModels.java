package org.dromara.framelean.domain;

import java.time.Instant;

public final class FrameleanModels {

    private FrameleanModels() {
    }

    public record Release(
        long id,
        String version,
        int buildNumber,
        String channel,
        boolean mandatory,
        int minSupportedBuild,
        String notes,
        String notesObjectKey,
        String status,
        Instant createdAt,
        Instant publishedAt,
        Instant updatedAt,
        String githubDownloadUrl,
        String giteeDownloadUrl,
        String backupDownloadUrl
    ) {
    }

    public record ReleasePackage(
        long id,
        long releaseId,
        String platform,
        String arch,
        String fileName,
        String objectKey,
        long size,
        String sha256,
        String ed25519Signature,
        boolean clientVisible,
        Instant createdAt
    ) {
    }

    public record ArtifactRequirement(long id, long releaseId, String platform, String arch, boolean required, Instant createdAt) {
    }

    public record DownloadEvent(long id, long releaseId, String platform, String arch, String installId, String ipAddress, Instant createdAt) {
    }

    public record UpdateCheckEvent(
        long id,
        Long releaseId,
        String currentVersion,
        int currentBuild,
        String platform,
        String channel,
        String installId,
        String ipAddress,
        String userAgent,
        boolean updateAvailable,
        boolean blocked,
        Instant createdAt
    ) {
    }

    public record IpBlockRule(
        long id,
        String ipAddress,
        String reason,
        boolean enabled,
        Instant expiresAt,
        Instant createdAt,
        Instant updatedAt
    ) {
    }

    public record ReleaseDeletionPlan(long releaseId, String version, java.util.List<String> objectKeys) {
    }
}
