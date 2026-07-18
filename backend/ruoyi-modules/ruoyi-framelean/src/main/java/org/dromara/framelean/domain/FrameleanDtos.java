package org.dromara.framelean.domain;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

import java.util.List;

public final class FrameleanDtos {

    private FrameleanDtos() {
    }

    public record ArtifactRequirementDto(
        @NotBlank @Pattern(regexp = "windows-x64|windows-installer|macos-universal2") String platform,
        @NotBlank String arch,
        boolean required
    ) {
    }

    public record CreateReleaseRequest(
        @NotBlank String version,
        @Min(0) Integer buildNumber,
        String channel,
        Boolean mandatory,
        @Min(0) Integer minSupportedBuild,
        String notes,
        String notesObjectKey,
        @Valid List<ArtifactRequirementDto> requiredArtifacts,
        @Valid List<CreatePackageRequest> packages,
        String githubDownloadUrl,
        String giteeDownloadUrl,
        String backupDownloadUrl
    ) {
        public CreateReleaseRequest {
            buildNumber = buildNumber == null ? 0 : buildNumber;
            channel = channel == null || channel.isBlank() ? "stable" : channel;
            mandatory = mandatory != null && mandatory;
            minSupportedBuild = minSupportedBuild == null ? 0 : minSupportedBuild;
            requiredArtifacts = requiredArtifacts == null ? List.of() : List.copyOf(requiredArtifacts);
            packages = packages == null ? List.of() : List.copyOf(packages);
        }
    }

    public record CreatePackageRequest(
        @NotBlank @Pattern(regexp = "windows-x64|windows-installer|macos-universal2") String platform,
        @NotBlank String arch,
        @NotBlank String fileName,
        @NotBlank String objectKey,
        @Min(1) long size,
        @NotBlank @Pattern(regexp = "^[a-fA-F0-9]{64}$") String sha256,
        String ed25519Signature,
        Boolean clientVisible
    ) {
        public CreatePackageRequest {
            clientVisible = clientVisible == null || clientVisible;
        }
    }

    public record ReleaseListResponse(List<ReleaseSummary> releases) {
    }

    public record ReleaseSummary(
        long id,
        String version,
        int buildNumber,
        String channel,
        String status,
        long downloadCount,
        String createdAt,
        String publishedAt
    ) {
    }

    public record ReleasePackageDto(
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
        String createdAt
    ) {
    }

    public record ReleaseDetailResponse(
        long id,
        String version,
        int buildNumber,
        String channel,
        boolean mandatory,
        int minSupportedBuild,
        String notes,
        String notesObjectKey,
        String status,
        String createdAt,
        String publishedAt,
        List<ArtifactRequirementDto> requirements,
        List<ReleasePackageDto> packages,
        String githubDownloadUrl,
        String giteeDownloadUrl,
        String backupDownloadUrl
    ) {
    }

    public record UpdateRequirementsRequest(@Valid List<ArtifactRequirementDto> requiredArtifacts) {
        public UpdateRequirementsRequest {
            requiredArtifacts = requiredArtifacts == null ? List.of() : List.copyOf(requiredArtifacts);
        }
    }

    public record UpdateReleaseNotesRequest(String notes, String notesObjectKey) {
    }

    public record UpdateReleaseDownloadUrlsRequest(
        String githubDownloadUrl,
        String giteeDownloadUrl,
        String backupDownloadUrl
    ) {
    }

    public record DownloadStatsResponse(long totalDownloads) {
    }

    public record AdminDashboardResponse(
        long totalDownloads,
        long totalUpdateChecks,
        long distinctDownloadIps,
        long distinctCheckIps,
        long activeBlockedIps
    ) {
    }

    public record PageResponse<T>(List<T> items, long total, int page, int pageSize) {
    }

    public record DownloadEventRecordResponse(
        long id,
        long releaseId,
        String releaseVersion,
        String platform,
        String arch,
        String installId,
        String ipAddress,
        String createdAt
    ) {
    }

    public record UpdateCheckRecordResponse(
        long id,
        Long releaseId,
        String releaseVersion,
        String currentVersion,
        int currentBuild,
        String platform,
        String channel,
        String installId,
        String ipAddress,
        String userAgent,
        boolean updateAvailable,
        boolean blocked,
        String createdAt
    ) {
    }

    public record CreateIpBlockRequest(@NotBlank String ipAddress, String reason) {
    }

    public record IpBlockRuleResponse(
        long id,
        String ipAddress,
        String reason,
        boolean enabled,
        String expiresAt,
        String createdAt,
        String updatedAt
    ) {
    }

    public record ReleaseNotesListItem(
        String version,
        int buildNumber,
        String channel,
        String publishedAt,
        String notes,
        String summary
    ) {
    }

    public record InitiateMultipartUploadRequest(@NotBlank String objectKey, @Min(1) long partSize, String contentType) {
    }

    public record MultipartUploadSessionResponse(String objectKey, String uploadId, long partSize) {
    }

    public record PresignUploadPartRequest(@NotBlank String objectKey, @NotBlank String uploadId, @Min(1) int partNumber) {
    }

    public record PresignedUploadPartResponse(String uploadUrl, String expiresAt) {
    }

    public record UploadedPartResponse(int partNumber, String eTag, long size) {
    }

    public record CompleteMultipartUploadRequest(@NotBlank String objectKey, @NotBlank String uploadId, List<Integer> expectedPartNumbers) {
        public CompleteMultipartUploadRequest {
            expectedPartNumbers = expectedPartNumbers == null ? List.of() : List.copyOf(expectedPartNumbers);
        }
    }

    public record CompleteMultipartUploadResponse(String objectKey, String eTag) {
    }

    public record CreateReleaseResponse(long id, String version, String status) {
    }

    public record DeleteReleaseResponse(String version, boolean deleted, List<String> deletedObjectKeys) {
    }

    public record PublishReleaseRequest(String status) {
        public PublishReleaseRequest {
            status = status == null ? "published" : status;
        }
    }

    public record UpdateBuildNumberRequest(@Min(0) int buildNumber) {
    }

    public record UploadUrlResponse(String uploadUrl, String expiresAt) {
    }

    public record AbortMultipartUploadResponse(boolean aborted) {
    }

    public record DisableIpBlockResponse(long id, boolean enabled) {
    }

    public record DownloadTicketRequest(String installId) {
    }

    public record CreateDownloadTicketRequest(
        @NotBlank String version,
        @NotBlank @Pattern(regexp = "windows-x64|windows-installer|macos-universal2") String platform,
        String installId
    ) {
    }

    public record DownloadTicketCreateResponse(
        String ticketId,
        String expiresAt,
        String fileName,
        long size,
        String sha256,
        String ed25519Signature
    ) {
    }

    public record DownloadTicketResponse(
        String downloadUrl,
        String expiresAt,
        String fileName,
        long size,
        String sha256,
        String ed25519Signature
    ) {
    }

    public record UpdateCheckRequest(
        @NotBlank String currentVersion,
        @Min(0) int currentBuild,
        @NotBlank @Pattern(regexp = "windows-x64|windows-installer|macos-universal2") String platform,
        String channel,
        String installId
    ) {
        public UpdateCheckRequest {
            channel = channel == null || channel.isBlank() ? "stable" : channel;
        }
    }

    public record UpdateCheckResponse(boolean updateAvailable, ReleaseInfo release) {
        public UpdateCheckResponse(boolean updateAvailable) {
            this(updateAvailable, null);
        }
    }

    public record ReleaseInfo(
        String version,
        int buildNumber,
        String channel,
        boolean mandatory,
        int minSupportedBuild,
        String notesUrl,
        String fileName,
        long size,
        String sha256,
        String ed25519Signature,
        String githubDownloadUrl,
        String giteeDownloadUrl,
        String backupDownloadUrl
    ) {
    }

    public record ErrorResponse(String error, String message) {
    }

    public record HealthResponse(String status) {
    }

    public record DiagnosticsResponse(
        String publicBaseUrl,
        boolean cosConfigured,
        boolean redisConfigured,
        boolean apiKeyConfigured,
        String updateTicketTtl,
        String downloadUrlTtl
    ) {
    }
}
