package org.dromara.framelean.controller;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.dromara.framelean.config.FrameleanProperties;
import org.dromara.framelean.domain.FrameleanDtos.AbortMultipartUploadResponse;
import org.dromara.framelean.domain.FrameleanDtos.AdminDashboardResponse;
import org.dromara.framelean.domain.FrameleanDtos.ArtifactRequirementDto;
import org.dromara.framelean.domain.FrameleanDtos.CompleteMultipartUploadRequest;
import org.dromara.framelean.domain.FrameleanDtos.CompleteMultipartUploadResponse;
import org.dromara.framelean.domain.FrameleanDtos.CreateIpBlockRequest;
import org.dromara.framelean.domain.FrameleanDtos.CreatePackageRequest;
import org.dromara.framelean.domain.FrameleanDtos.CreateReleaseRequest;
import org.dromara.framelean.domain.FrameleanDtos.CreateReleaseResponse;
import org.dromara.framelean.domain.FrameleanDtos.DeleteReleaseResponse;
import org.dromara.framelean.domain.FrameleanDtos.DiagnosticsResponse;
import org.dromara.framelean.domain.FrameleanDtos.DisableIpBlockResponse;
import org.dromara.framelean.domain.FrameleanDtos.DownloadEventRecordResponse;
import org.dromara.framelean.domain.FrameleanDtos.DownloadStatsResponse;
import org.dromara.framelean.domain.FrameleanDtos.InitiateMultipartUploadRequest;
import org.dromara.framelean.domain.FrameleanDtos.IpBlockRuleResponse;
import org.dromara.framelean.domain.FrameleanDtos.MultipartUploadSessionResponse;
import org.dromara.framelean.domain.FrameleanDtos.PageResponse;
import org.dromara.framelean.domain.FrameleanDtos.PresignUploadPartRequest;
import org.dromara.framelean.domain.FrameleanDtos.PresignedUploadPartResponse;
import org.dromara.framelean.domain.FrameleanDtos.PublishReleaseRequest;
import org.dromara.framelean.domain.FrameleanDtos.ReleaseDetailResponse;
import org.dromara.framelean.domain.FrameleanDtos.ReleaseListResponse;
import org.dromara.framelean.domain.FrameleanDtos.ReleasePackageDto;
import org.dromara.framelean.domain.FrameleanDtos.ReleaseSummary;
import org.dromara.framelean.domain.FrameleanDtos.UpdateBuildNumberRequest;
import org.dromara.framelean.domain.FrameleanDtos.UpdateCheckRecordResponse;
import org.dromara.framelean.domain.FrameleanDtos.UpdateReleaseDownloadUrlsRequest;
import org.dromara.framelean.domain.FrameleanDtos.UpdateReleaseNotesRequest;
import org.dromara.framelean.domain.FrameleanDtos.UpdateRequirementsRequest;
import org.dromara.framelean.domain.FrameleanDtos.UploadUrlResponse;
import org.dromara.framelean.domain.FrameleanDtos.UploadedPartResponse;
import org.dromara.framelean.domain.FrameleanModels.ArtifactRequirement;
import org.dromara.framelean.domain.FrameleanModels.Release;
import org.dromara.framelean.domain.FrameleanModels.ReleaseDeletionPlan;
import org.dromara.framelean.domain.FrameleanModels.ReleasePackage;
import org.dromara.framelean.service.AdminAuditService;
import org.dromara.framelean.service.ReleaseService;
import org.dromara.framelean.service.UpdateService;
import org.dromara.framelean.storage.ReleaseArtifactStorage;
import org.dromara.common.log.annotation.Log;
import org.dromara.common.log.enums.BusinessType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.net.URI;
import java.time.Duration;
import java.time.format.DateTimeFormatter;
import java.util.List;

@RestController
@RequestMapping("/api/v1/admin")
@RequiredArgsConstructor
public class AdminReleaseController {
    private static final long MIN_PART_SIZE = 1024L * 1024L;
    private static final long MAX_PART_SIZE = 64L * 1024L * 1024L;
    private static final int MAX_PART_COUNT = 10_000;

    private final ReleaseService releaseService;
    private final UpdateService updateService;
    private final AdminAuditService adminAuditService;
    private final ReleaseArtifactStorage storage;
    private final FrameleanProperties properties;

    @GetMapping("/releases")
    public ReleaseListResponse listReleases() {
        List<ReleaseSummary> releases = releaseService.listAll().stream()
            .map(release -> new ReleaseSummary(
                release.id(),
                release.version(),
                release.buildNumber(),
                release.channel(),
                release.status(),
                updateService.countDownloads(release.id()),
                string(release.createdAt()),
                string(release.publishedAt())
            ))
            .toList();
        return new ReleaseListResponse(releases);
    }

    @GetMapping("/stats")
    public DownloadStatsResponse stats() {
        return new DownloadStatsResponse(updateService.totalDownloads());
    }

    @GetMapping("/dashboard")
    public AdminDashboardResponse dashboard() {
        return adminAuditService.dashboard();
    }

    @Log(title = "FrameLean 发布版本", businessType = BusinessType.INSERT)
    @PostMapping("/releases")
    public ResponseEntity<CreateReleaseResponse> createRelease(@Valid @RequestBody CreateReleaseRequest body) {
        Release release = releaseService.createRelease(
            body.version(),
            body.buildNumber(),
            body.channel(),
            body.mandatory(),
            body.minSupportedBuild(),
            body.notes(),
            body.notesObjectKey(),
            body.requiredArtifacts(),
            body.packages(),
            body.githubDownloadUrl(),
            body.giteeDownloadUrl(),
            body.backupDownloadUrl()
        );
        return ResponseEntity.created(URI.create("/api/v1/admin/releases/" + release.version()))
            .body(new CreateReleaseResponse(release.id(), release.version(), release.status()));
    }

    @GetMapping("/releases/{version}")
    public ReleaseDetailResponse releaseDetail(@PathVariable String version) {
        return toDetail(releaseService.findByVersion(version));
    }

    @Log(title = "FrameLean 发布制品", businessType = BusinessType.INSERT)
    @PostMapping("/releases/{version}/packages")
    public ResponseEntity<ReleasePackageDto> addPackage(@PathVariable String version, @Valid @RequestBody CreatePackageRequest body) {
        Release release = releaseService.findByVersion(version);
        ReleasePackage pkg = releaseService.addPackage(
            release.id(),
            body.platform(),
            body.arch(),
            body.fileName(),
            body.objectKey(),
            body.size(),
            body.sha256(),
            body.ed25519Signature(),
            body.clientVisible()
        );
        return ResponseEntity.created(URI.create("/api/v1/admin/releases/" + version + "/packages/" + pkg.id())).body(toPackageDto(pkg));
    }

    @Log(title = "FrameLean 发布日志", businessType = BusinessType.UPDATE)
    @PutMapping("/releases/{version}/notes")
    public ReleaseDetailResponse updateNotes(@PathVariable String version, @RequestBody UpdateReleaseNotesRequest body) {
        return toDetail(releaseService.updateDraftNotes(version, body.notes(), body.notesObjectKey()));
    }

    @Log(title = "FrameLean 下载地址", businessType = BusinessType.UPDATE)
    @PutMapping("/releases/{version}/download-urls")
    public ReleaseDetailResponse updateDownloadUrls(@PathVariable String version, @RequestBody UpdateReleaseDownloadUrlsRequest body) {
        Release release = releaseService.updateDraftDownloadUrls(
            version,
            body.githubDownloadUrl(),
            body.giteeDownloadUrl(),
            body.backupDownloadUrl()
        );
        updateService.clearLatestCache();
        return toDetail(release);
    }

    @Log(title = "FrameLean 发布要求", businessType = BusinessType.UPDATE)
    @PutMapping("/releases/{version}/requirements")
    public List<ArtifactRequirementDto> updateRequirements(@PathVariable String version, @Valid @RequestBody UpdateRequirementsRequest body) {
        return releaseService.updateRequirements(version, body.requiredArtifacts()).stream().map(this::toRequirementDto).toList();
    }

    @Log(title = "FrameLean 发布版本", businessType = BusinessType.UPDATE)
    @PatchMapping("/releases/{version}")
    public ReleaseDetailResponse publish(@PathVariable String version, @Valid @RequestBody PublishReleaseRequest body) {
        if (!"published".equals(body.status())) {
            throw new IllegalArgumentException("Only 'published' status is supported via this endpoint");
        }
        Release release = releaseService.publish(version);
        updateService.clearLatestCache();
        return toDetail(release);
    }

    @Log(title = "FrameLean 构建号", businessType = BusinessType.UPDATE)
    @PatchMapping("/releases/{version}/build-number")
    public ReleaseDetailResponse updateBuildNumber(@PathVariable String version, @Valid @RequestBody UpdateBuildNumberRequest body) {
        Release release = releaseService.updateBuildNumber(version, body.buildNumber());
        updateService.clearLatestCache();
        return toDetail(release);
    }

    @Log(title = "FrameLean 发布版本", businessType = BusinessType.DELETE)
    @DeleteMapping("/releases/{version}")
    public DeleteReleaseResponse deleteRelease(@PathVariable String version) {
        ReleaseDeletionPlan deletion = releaseService.planDeletion(version);
        deletion.objectKeys().forEach(this::validateReleaseObjectKey);
        deletion.objectKeys().forEach(storage::deleteObject);
        ReleaseDeletionPlan deleted = releaseService.deleteRelease(version);
        updateService.clearLatestCache();
        return new DeleteReleaseResponse(deleted.version(), true, deleted.objectKeys());
    }

    @GetMapping("/upload-url")
    public UploadUrlResponse getUploadUrl(@RequestParam("key") String objectKey) {
        validateReleaseObjectKey(objectKey);
        ReleaseArtifactStorage.PresignedUrl presigned = storage.presignUpload(objectKey, Duration.ofMinutes(10));
        return new UploadUrlResponse(presigned.url().toString(), DateTimeFormatter.ISO_INSTANT.format(presigned.expiresAt()));
    }

    @PostMapping("/uploads/multipart/initiate")
    public ResponseEntity<MultipartUploadSessionResponse> initiateMultipartUpload(@Valid @RequestBody InitiateMultipartUploadRequest body) {
        validateReleaseObjectKey(body.objectKey());
        if (body.partSize() < MIN_PART_SIZE || body.partSize() > MAX_PART_SIZE) {
            throw new IllegalArgumentException("partSize must be between " + MIN_PART_SIZE + " and " + MAX_PART_SIZE);
        }
        ReleaseArtifactStorage.MultipartUploadSession session = storage.initiateMultipartUpload(body.objectKey(), body.partSize(), body.contentType());
        return ResponseEntity.created(URI.create("/api/v1/admin/uploads/multipart/" + session.uploadId()))
            .body(new MultipartUploadSessionResponse(session.objectKey(), session.uploadId(), session.partSize()));
    }

    @PostMapping("/uploads/multipart/part-url")
    public PresignedUploadPartResponse presignMultipartUploadPart(@Valid @RequestBody PresignUploadPartRequest body) {
        validateReleaseObjectKey(body.objectKey());
        if (body.partNumber() < 1 || body.partNumber() > MAX_PART_COUNT) {
            throw new IllegalArgumentException("partNumber must be between 1 and " + MAX_PART_COUNT);
        }
        ReleaseArtifactStorage.PresignedUrl presigned = storage.presignUploadPart(body.objectKey(), body.uploadId(), body.partNumber(), Duration.ofMinutes(30));
        return new PresignedUploadPartResponse(presigned.url().toString(), DateTimeFormatter.ISO_INSTANT.format(presigned.expiresAt()));
    }

    @GetMapping("/uploads/multipart/parts")
    public List<UploadedPartResponse> listMultipartUploadedParts(@RequestParam("objectKey") String objectKey, @RequestParam("uploadId") String uploadId) {
        validateReleaseObjectKey(objectKey);
        return storage.listUploadedParts(objectKey, uploadId).stream()
            .map(part -> new UploadedPartResponse(part.partNumber(), part.eTag(), part.size()))
            .toList();
    }

    @PostMapping("/uploads/multipart/complete")
    public CompleteMultipartUploadResponse completeMultipartUpload(@Valid @RequestBody CompleteMultipartUploadRequest body) {
        validateReleaseObjectKey(body.objectKey());
        List<ReleaseArtifactStorage.UploadedPart> parts = storage.listUploadedParts(body.objectKey(), body.uploadId());
        if (!body.expectedPartNumbers().isEmpty()) {
            List<Integer> uploaded = parts.stream().map(ReleaseArtifactStorage.UploadedPart::partNumber).toList();
            List<Integer> missing = body.expectedPartNumbers().stream().filter(part -> !uploaded.contains(part)).toList();
            if (!missing.isEmpty()) {
                throw new IllegalArgumentException("multipart upload is missing parts: " + missing);
            }
        }
        if (parts.isEmpty()) {
            throw new IllegalArgumentException("multipart upload has no parts");
        }
        ReleaseArtifactStorage.CompletedMultipartUpload completed = storage.completeMultipartUpload(body.objectKey(), body.uploadId(), parts);
        return new CompleteMultipartUploadResponse(completed.objectKey(), completed.eTag());
    }

    @DeleteMapping("/uploads/multipart/{uploadId}")
    public AbortMultipartUploadResponse abortMultipartUpload(@PathVariable String uploadId, @RequestParam("objectKey") String objectKey) {
        validateReleaseObjectKey(objectKey);
        storage.abortMultipartUpload(objectKey, uploadId);
        return new AbortMultipartUploadResponse(true);
    }

    @GetMapping("/update-checks")
    public PageResponse<UpdateCheckRecordResponse> updateChecks(
        @RequestParam(required = false) String ipAddress,
        @RequestParam(required = false) String platform,
        @RequestParam(required = false) Boolean blocked,
        @RequestParam(defaultValue = "1") int page,
        @RequestParam(defaultValue = "20") int pageSize
    ) {
        return adminAuditService.updateChecks(ipAddress, platform, blocked, page, pageSize);
    }

    @GetMapping("/download-events")
    public PageResponse<DownloadEventRecordResponse> downloads(
        @RequestParam(required = false) String ipAddress,
        @RequestParam(required = false) String platform,
        @RequestParam(required = false) Long releaseId,
        @RequestParam(defaultValue = "1") int page,
        @RequestParam(defaultValue = "20") int pageSize
    ) {
        return adminAuditService.downloads(ipAddress, platform, releaseId, page, pageSize);
    }

    @GetMapping("/ip-blocks")
    public PageResponse<IpBlockRuleResponse> ipBlocks(
        @RequestParam(required = false) String ipAddress,
        @RequestParam(defaultValue = "1") int page,
        @RequestParam(defaultValue = "20") int pageSize
    ) {
        return adminAuditService.ipBlocks(ipAddress, page, pageSize);
    }

    @Log(title = "FrameLean IP 封禁", businessType = BusinessType.INSERT)
    @PostMapping("/ip-blocks")
    public ResponseEntity<IpBlockRuleResponse> createIpBlock(@Valid @RequestBody CreateIpBlockRequest body) {
        IpBlockRuleResponse rule = adminAuditService.createIpBlock(body.ipAddress(), body.reason());
        return ResponseEntity.created(URI.create("/api/v1/admin/ip-blocks/" + rule.id())).body(rule);
    }

    @Log(title = "FrameLean IP 封禁", businessType = BusinessType.UPDATE)
    @PostMapping("/ip-blocks/{id}/disable")
    public DisableIpBlockResponse disableIpBlock(@PathVariable long id) {
        adminAuditService.disableIpBlock(id);
        return new DisableIpBlockResponse(id, false);
    }

    @GetMapping("/diagnostics")
    public DiagnosticsResponse diagnostics() {
        return new DiagnosticsResponse(
            properties.normalizedPublicBaseUrl(),
            properties.getCos().isConfigured(),
            true,
            properties.isApiKeyConfigured(),
            UpdateService.TICKET_TTL.toString(),
            UpdateService.DOWNLOAD_URL_TTL.toString()
        );
    }

    private ReleaseDetailResponse toDetail(Release release) {
        return new ReleaseDetailResponse(
            release.id(),
            release.version(),
            release.buildNumber(),
            release.channel(),
            release.mandatory(),
            release.minSupportedBuild(),
            release.notes(),
            release.notesObjectKey(),
            release.status(),
            string(release.createdAt()),
            string(release.publishedAt()),
            releaseService.findRequirements(release.id()).stream().map(this::toRequirementDto).toList(),
            releaseService.findPackages(release.id()).stream().map(this::toPackageDto).toList(),
            release.githubDownloadUrl(),
            release.giteeDownloadUrl(),
            release.backupDownloadUrl()
        );
    }

    private ReleasePackageDto toPackageDto(ReleasePackage pkg) {
        return new ReleasePackageDto(
            pkg.id(),
            pkg.releaseId(),
            pkg.platform(),
            pkg.arch(),
            pkg.fileName(),
            pkg.objectKey(),
            pkg.size(),
            pkg.sha256(),
            pkg.ed25519Signature(),
            pkg.clientVisible(),
            string(pkg.createdAt())
        );
    }

    private ArtifactRequirementDto toRequirementDto(ArtifactRequirement requirement) {
        return new ArtifactRequirementDto(requirement.platform(), requirement.arch(), requirement.required());
    }

    private void validateReleaseObjectKey(String objectKey) {
        if (objectKey == null || !objectKey.startsWith("releases/")) {
            throw new IllegalArgumentException("objectKey must start with releases/");
        }
        if (objectKey.startsWith("/") || objectKey.contains("..") || objectKey.contains("\\")) {
            throw new IllegalArgumentException("objectKey contains unsafe path segments");
        }
    }

    private String string(java.time.Instant instant) {
        return instant == null ? null : instant.toString();
    }
}
