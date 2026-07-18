package org.dromara.framelean.service;

import lombok.RequiredArgsConstructor;
import org.dromara.framelean.domain.FrameleanDtos.ArtifactRequirementDto;
import org.dromara.framelean.domain.FrameleanDtos.CreatePackageRequest;
import org.dromara.framelean.domain.FrameleanModels.ArtifactRequirement;
import org.dromara.framelean.domain.FrameleanModels.Release;
import org.dromara.framelean.domain.FrameleanModels.ReleaseDeletionPlan;
import org.dromara.framelean.domain.FrameleanModels.ReleasePackage;
import org.dromara.framelean.exception.FrameleanApiException;
import org.dromara.framelean.repository.FrameleanRepository;
import org.dromara.framelean.storage.ReleaseArtifactStorage;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.net.URI;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.regex.Pattern;

@Service
@RequiredArgsConstructor
public class ReleaseService {
    private static final int ED25519_SIGNATURE_BYTES = 64;
    private static final Pattern SHA256 = Pattern.compile("^[a-fA-F0-9]{64}$");
    private static final Pattern WINDOWS_KEY_ID = Pattern.compile("^[A-Za-z0-9._-]+$");
    private static final String DRAFT_STATUS = "draft";
    private static final String PUBLISHED_STATUS = "published";

    private static final Map<String, ArtifactSpec> ARTIFACT_SPECS = new LinkedHashMap<>();

    static {
        ARTIFACT_SPECS.put("windows-x64", new ArtifactSpec("windows-x64", "x64", false, false, ".zip", SignatureKind.NONE));
        ARTIFACT_SPECS.put("windows-installer", new ArtifactSpec("windows-installer", "x64", false, true, ".exe", SignatureKind.WINDOWS));
        ARTIFACT_SPECS.put("macos-universal2", new ArtifactSpec("macos-universal2", "universal2", false, true, ".dmg", SignatureKind.OPTIONAL_SPARKLE));
    }

    private final FrameleanRepository repository;
    private final ReleaseArtifactStorage artifactStorage;

    public Optional<Release> findPublishedLatest(String channel, int currentBuild, String platform) {
        return repository.findLatestPublished(channel, currentBuild, platform);
    }

    public Release findById(long id) {
        return repository.findReleaseById(id).orElseThrow(() -> FrameleanApiException.notFound("Release not found: id=" + id));
    }

    public Release findByVersion(String version) {
        return repository.findLatestReleaseByVersion(version).orElseThrow(() -> FrameleanApiException.notFound("Release not found: " + version));
    }

    public List<Release> listAll() {
        return repository.listReleases();
    }

    public List<Release> listPublished(String channel) {
        return repository.listPublishedReleases(channel);
    }

    @Transactional
    public Release createRelease(
        String version,
        int buildNumber,
        String channel,
        boolean mandatory,
        int minSupportedBuild,
        String notes,
        String notesObjectKey,
        List<ArtifactRequirementDto> requiredArtifacts,
        List<CreatePackageRequest> packages,
        String githubDownloadUrl,
        String giteeDownloadUrl,
        String backupDownloadUrl
    ) {
        if (repository.findLatestReleaseByVersion(version).isPresent()) {
            throw FrameleanApiException.conflict("Release already exists: " + version);
        }
        Release release = repository.insertRelease(
            version,
            buildNumber,
            channel,
            mandatory,
            minSupportedBuild,
            notes,
            notesObjectKey,
            cleanDownloadUrl(githubDownloadUrl),
            cleanDownloadUrl(giteeDownloadUrl),
            cleanDownloadUrl(backupDownloadUrl)
        );
        replaceRequirements(release.id());
        for (CreatePackageRequest pkg : packages) {
            upsertPackage(
                release.id(),
                pkg.platform(),
                pkg.arch(),
                pkg.fileName(),
                pkg.objectKey(),
                pkg.size(),
                pkg.sha256(),
                pkg.ed25519Signature(),
                pkg.clientVisible()
            );
        }
        return release;
    }

    @Transactional
    public Release publish(String version) {
        Release release = findByVersion(version);
        if (PUBLISHED_STATUS.equals(release.status())) {
            throw FrameleanApiException.conflict("Release already published: " + version);
        }
        ensureDraft(release);
        validateReleaseCanPublish(release);
        return repository.updateReleaseStatus(release.id(), PUBLISHED_STATUS, Instant.now());
    }

    @Transactional
    public Release updateBuildNumber(String version, int buildNumber) {
        Release release = findByVersion(version);
        ensureDraft(release);
        return repository.updateBuildNumber(release.id(), buildNumber);
    }

    @Transactional
    public Release updateDraftNotes(String version, String notes, String notesObjectKey) {
        Release release = findByVersion(version);
        ensureDraft(release);
        return repository.updateNotes(release.id(), notes, notesObjectKey);
    }

    @Transactional
    public Release updateDraftDownloadUrls(String version, String githubDownloadUrl, String giteeDownloadUrl, String backupDownloadUrl) {
        Release release = findByVersion(version);
        ensureDraft(release);
        return repository.updateDownloadUrls(
            release.id(),
            cleanDownloadUrl(githubDownloadUrl),
            cleanDownloadUrl(giteeDownloadUrl),
            cleanDownloadUrl(backupDownloadUrl)
        );
    }

    public Optional<ReleasePackage> findPackage(long releaseId, String platform) {
        return repository.findClientPackage(releaseId, platform);
    }

    public List<ReleasePackage> findPackages(long releaseId) {
        return repository.listPackages(releaseId);
    }

    public List<ArtifactRequirement> findRequirements(long releaseId) {
        return repository.listRequirements(releaseId);
    }

    @Transactional
    public List<ArtifactRequirement> updateRequirements(String version, List<ArtifactRequirementDto> ignored) {
        Release release = findByVersion(version);
        ensureDraft(release);
        replaceRequirements(release.id());
        return findRequirements(release.id());
    }

    @Transactional
    public ReleasePackage addPackage(long releaseId, String platform, String arch, String fileName, String objectKey, long size, String sha256, String signature, boolean clientVisible) {
        Release release = findById(releaseId);
        ensureDraft(release);
        return upsertPackage(releaseId, platform, arch, fileName, objectKey, size, sha256, signature, clientVisible);
    }

    public ReleasePackage requirePackage(long releaseId, String platform) {
        return findPackage(releaseId, platform).orElseThrow(() -> FrameleanApiException.notFound("Package not found: releaseId=" + releaseId + " platform=" + platform));
    }

    public ReleaseDeletionPlan planDeletion(String version) {
        Release release = findByVersion(version);
        List<String> keys = new ArrayList<>();
        for (ReleasePackage pkg : findPackages(release.id())) {
            addObjectKey(keys, pkg.objectKey());
        }
        addObjectKey(keys, release.notesObjectKey());
        return new ReleaseDeletionPlan(release.id(), release.version(), keys);
    }

    @Transactional
    public ReleaseDeletionPlan deleteRelease(String version) {
        ReleaseDeletionPlan plan = planDeletion(version);
        repository.deleteDownloadsByRelease(plan.releaseId());
        repository.deletePackagesByRelease(plan.releaseId());
        repository.deleteRequirementsByRelease(plan.releaseId());
        repository.deleteRelease(plan.releaseId());
        return plan;
    }

    private ReleasePackage upsertPackage(long releaseId, String platform, String arch, String fileName, String objectKey, long size, String sha256, String signature, boolean clientVisible) {
        ArtifactSpec spec = ARTIFACT_SPECS.get(platform);
        if (spec == null) {
            throw FrameleanApiException.badRequest("bad_request", "unsupported release package platform: " + platform);
        }
        boolean normalizedVisible = spec.clientVisible();
        String normalizedArch = spec.arch();
        Optional<ReleasePackage> existing = repository.findPackageTarget(releaseId, platform, normalizedArch);
        return existing
            .map(pkg -> repository.updatePackage(pkg.id(), fileName, objectKey, size, sha256, signature, normalizedVisible))
            .orElseGet(() -> repository.insertPackage(releaseId, platform, normalizedArch, fileName, objectKey, size, sha256, signature, normalizedVisible));
    }

    private void replaceRequirements(long releaseId) {
        repository.deleteRequirementsByRelease(releaseId);
        for (ArtifactSpec spec : ARTIFACT_SPECS.values()) {
            repository.insertRequirement(releaseId, spec.platform(), spec.arch(), spec.required());
        }
    }

    private void validateReleaseCanPublish(Release release) {
        List<String> errors = new ArrayList<>();
        if (!hasText(release.notes()) && !hasText(release.notesObjectKey())) {
            errors.add("release notes (text or file) are required");
        }
        if (!hasText(release.notes()) && hasText(release.notesObjectKey())) {
            validateNotesObject(errors, release.notesObjectKey());
        }
        boolean hasExternalLink = hasText(release.githubDownloadUrl())
            || hasText(release.giteeDownloadUrl())
            || hasText(release.backupDownloadUrl());
        List<ReleasePackage> packages = findPackages(release.id());
        if (packages.isEmpty()) {
            if (!hasExternalLink) {
                errors.add("at least one download url is required when no release package is registered");
            }
            if (!errors.isEmpty()) {
                throw FrameleanApiException.badRequest("invalid_release", String.join("; ", errors));
            }
            return;
        }
        for (ArtifactSpec required : ARTIFACT_SPECS.values().stream().filter(ArtifactSpec::required).toList()) {
            boolean exists = packages.stream().anyMatch(pkg ->
                pkg.platform().equals(required.platform()) &&
                    pkg.arch().equals(required.arch()) &&
                    pkg.clientVisible() == required.clientVisible()
            );
            if (!exists) {
                errors.add("required package is missing for platform=" + required.platform() + " arch=" + required.arch());
            }
        }
        for (ReleasePackage pkg : packages) {
            validatePackage(errors, pkg);
        }
        if (!errors.isEmpty()) {
            throw FrameleanApiException.badRequest("invalid_release", String.join("; ", errors));
        }
    }

    private void validateNotesObject(List<String> errors, String objectKey) {
        ReleaseArtifactStorage.StoredObjectMetadata stored;
        try {
            stored = artifactStorage.statObject(objectKey.trim());
        } catch (Exception ex) {
            errors.add("release notes file metadata could not be read: " + ex.getMessage());
            return;
        }
        if (stored == null) {
            errors.add("release notes file does not exist: " + objectKey.trim());
        } else if (stored.size() <= 0) {
            errors.add("release notes file is empty: " + objectKey.trim());
        }
    }

    private void validatePackage(List<String> errors, ReleasePackage pkg) {
        ArtifactSpec spec = ARTIFACT_SPECS.get(pkg.platform());
        if (spec == null) {
            errors.add("package " + pkg.id() + " platform is unsupported: " + pkg.platform());
            return;
        }
        if (!pkg.arch().equals(spec.arch())) {
            errors.add("package " + pkg.id() + " arch must be " + spec.arch());
        }
        if (pkg.clientVisible() != spec.clientVisible()) {
            errors.add("package " + pkg.id() + " clientVisible must be " + spec.clientVisible());
        }
        if (pkg.fileName() == null || pkg.fileName().isBlank()) {
            errors.add("package " + pkg.id() + " fileName is required");
        } else if (!pkg.fileName().toLowerCase().endsWith(spec.extension())) {
            errors.add("package " + pkg.id() + " fileName must end with " + spec.extension());
        }
        if (pkg.objectKey() == null || pkg.objectKey().isBlank()) {
            errors.add("package " + pkg.id() + " objectKey is required");
        }
        if (pkg.size() <= 0) {
            errors.add("package " + pkg.id() + " size must be positive");
        }
        if (pkg.sha256() == null || !SHA256.matcher(pkg.sha256()).matches()) {
            errors.add("package " + pkg.id() + " sha256 must be 64 hex chars");
        }
        validateSignature(errors, pkg, spec);
        ReleaseArtifactStorage.StoredObjectMetadata stored;
        try {
            stored = artifactStorage.statObject(pkg.objectKey());
        } catch (Exception ex) {
            errors.add("package " + pkg.id() + " object metadata could not be read: " + ex.getMessage());
            stored = null;
        }
        if (stored == null) {
            errors.add("package " + pkg.id() + " object does not exist");
        } else if (stored.size() != pkg.size()) {
            errors.add("package " + pkg.id() + " object size mismatch: " + stored.size() + " != " + pkg.size());
        }
    }

    private void validateSignature(List<String> errors, ReleasePackage pkg, ArtifactSpec spec) {
        switch (spec.signatureKind()) {
            case NONE -> {
            }
            case WINDOWS -> {
                if (!isValidWindowsSignature(pkg.ed25519Signature())) {
                    errors.add("package " + pkg.id() + " Windows Ed25519 signature must be keyId:base64");
                }
            }
            case OPTIONAL_SPARKLE -> {
                if (pkg.ed25519Signature() != null && !pkg.ed25519Signature().isBlank() && !isValidEd25519Signature(pkg.ed25519Signature())) {
                    errors.add("package " + pkg.id() + " Sparkle EdDSA signature must be base64");
                }
            }
        }
    }

    private boolean isValidWindowsSignature(String value) {
        if (value == null) {
            return false;
        }
        String signature = value.trim();
        int separator = signature.indexOf(':');
        if (separator <= 0 || separator == signature.length() - 1) {
            return false;
        }
        return WINDOWS_KEY_ID.matcher(signature.substring(0, separator)).matches()
            && isValidEd25519Signature(signature.substring(separator + 1));
    }

    private boolean isValidEd25519Signature(String value) {
        if (value == null || value.isBlank()) {
            return false;
        }
        try {
            return Base64.getDecoder().decode(value.trim()).length == ED25519_SIGNATURE_BYTES;
        } catch (IllegalArgumentException ex) {
            return false;
        }
    }

    private String cleanDownloadUrl(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        String trimmed = value.trim();
        URI uri;
        try {
            uri = URI.create(trimmed);
        } catch (IllegalArgumentException ex) {
            throw FrameleanApiException.badRequest("invalid_url", "invalid download url: " + trimmed);
        }
        String scheme = uri.getScheme();
        if (!"http".equalsIgnoreCase(scheme) && !"https".equalsIgnoreCase(scheme)) {
            throw FrameleanApiException.badRequest("invalid_url", "download url must start with http or https");
        }
        if (uri.getHost() == null || uri.getHost().isBlank()) {
            throw FrameleanApiException.badRequest("invalid_url", "download url host is required");
        }
        return trimmed;
    }

    private boolean hasText(String value) {
        return value != null && !value.isBlank();
    }

    private void ensureDraft(Release release) {
        if (!DRAFT_STATUS.equals(release.status())) {
            throw new FrameleanApiException(
                "release_conflict",
                HttpStatus.CONFLICT,
                "Release is not editable because status is " + release.status() + ": " + release.version()
            );
        }
    }

    private void addObjectKey(List<String> keys, String objectKey) {
        if (objectKey == null || objectKey.isBlank()) {
            return;
        }
        String normalized = objectKey.trim();
        if (!keys.contains(normalized)) {
            keys.add(normalized);
        }
    }

    private record ArtifactSpec(String platform, String arch, boolean required, boolean clientVisible, String extension, SignatureKind signatureKind) {
    }

    private enum SignatureKind {
        NONE,
        WINDOWS,
        OPTIONAL_SPARKLE
    }
}
