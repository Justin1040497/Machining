package org.dromara.framelean.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.dromara.framelean.domain.FrameleanDtos.DownloadTicketCreateResponse;
import org.dromara.framelean.domain.FrameleanDtos.DownloadTicketResponse;
import org.dromara.framelean.domain.FrameleanDtos.ReleaseInfo;
import org.dromara.framelean.domain.FrameleanDtos.ReleaseNotesListItem;
import org.dromara.framelean.domain.FrameleanDtos.UpdateCheckResponse;
import org.dromara.framelean.domain.FrameleanModels.Release;
import org.dromara.framelean.domain.FrameleanModels.ReleasePackage;
import org.dromara.framelean.exception.FrameleanApiException;
import org.dromara.framelean.repository.FrameleanRepository;
import org.dromara.framelean.storage.ReleaseArtifactStorage;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.net.URI;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class UpdateService implements SparkleUpdateService {
    public static final Duration TICKET_TTL = Duration.ofMinutes(10);
    public static final Duration DOWNLOAD_URL_TTL = Duration.ofMinutes(30);
    private static final Duration LATEST_CACHE_TTL = Duration.ofMinutes(2);
    private static final String MACOS_PLATFORM = "macos-universal2";

    private final ReleaseService releaseService;
    private final AdminAuditService adminAuditService;
    private final FrameleanRepository repository;
    private final ReleaseArtifactStorage storage;
    private final StringRedisTemplate redisTemplate;
    private final ObjectMapper objectMapper;

    public UpdateCheckResponse checkForUpdate(String currentVersion, int currentBuild, String platform, String channel, String installId, String ipAddress, String userAgent) {
        if (adminAuditService.isIpBlocked(ipAddress)) {
            adminAuditService.recordUpdateCheck(null, currentVersion, currentBuild, platform, channel, installId, ipAddress, userAgent, false, true);
            adminAuditService.ensureIpAllowed(ipAddress);
        }

        Release release = findLatestPublishedCached(channel, currentBuild, platform);
        if (release == null) {
            adminAuditService.recordUpdateCheck(null, currentVersion, currentBuild, platform, channel, installId, ipAddress, userAgent, false, false);
            return new UpdateCheckResponse(false);
        }

        ReleasePackage pkg = releaseService.findPackage(release.id(), platform).orElse(null);
        boolean hasExternalLink = hasText(release.githubDownloadUrl())
            || hasText(release.giteeDownloadUrl())
            || hasText(release.backupDownloadUrl());

        // If neither a package nor external links are available, no update is offered.
        if (pkg == null && !hasExternalLink) {
            adminAuditService.recordUpdateCheck(release.id(), currentVersion, currentBuild, platform, channel, installId, ipAddress, userAgent, false, false);
            return new UpdateCheckResponse(false);
        }

        adminAuditService.recordUpdateCheck(release.id(), currentVersion, currentBuild, platform, channel, installId, ipAddress, userAgent, true, false);

        // Package fields are optionally populated; external-link-only releases use
        // placeholder values. The client uses githubDownloadUrl / giteeDownloadUrl /
        // backupDownloadUrl when present instead of attempting to download a self-hosted package.
        return new UpdateCheckResponse(true, new ReleaseInfo(
            release.version(),
            release.buildNumber(),
            release.channel(),
            release.mandatory(),
            release.minSupportedBuild(),
            "/api/v1/releases/" + release.version() + "/notes",
            pkg != null ? pkg.fileName() : "",
            pkg != null ? pkg.size() : 0,
            pkg != null ? pkg.sha256() : "",
            pkg != null ? pkg.ed25519Signature() : null,
            release.githubDownloadUrl(),
            release.giteeDownloadUrl(),
            release.backupDownloadUrl()
        ));
    }

    public String getReleaseNotes(String version) {
        Release release = releaseService.findByVersion(version);
        if (!"published".equals(release.status())) {
            throw FrameleanApiException.notFound("Release not found: " + version);
        }
        return resolveReleaseNotes(release);
    }

    public List<ReleaseNotesListItem> listReleaseNotes(String channel) {
        return releaseService.listPublished(channel).stream().map(release -> {
            String notes = resolveReleaseNotes(release);
            return new ReleaseNotesListItem(
                release.version(),
                release.buildNumber(),
                release.channel(),
                string(release.publishedAt()),
                notes,
                summarizeNotes(notes)
            );
        }).toList();
    }

    @Override
    public String buildSparkleAppcast(String channel, String baseUrl) {
        String items = releaseService.listPublished(channel).stream()
            .map(release -> sparkleItem(release, channel, baseUrl))
            .filter(item -> item != null && !item.isBlank())
            .reduce("", (left, right) -> left + "\n" + right);
        return """
            <?xml version="1.0" encoding="utf-8"?>
            <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
              <channel>
                <title>FrameLean Updates</title>
                <link>%s</link>
                <description>FrameLean release appcast</description>
                %s
              </channel>
            </rss>
            """.formatted(xml(baseUrl), items).trim();
    }

    @Transactional
    @Override
    public URI createSparkleDownloadRedirect(String version, String channel, String ipAddress) {
        adminAuditService.ensureIpAllowed(ipAddress);
        Release release = releaseService.findByVersion(version);
        if (!"published".equals(release.status()) || !channel.equals(release.channel())) {
            throw FrameleanApiException.notFound("Release not found: " + version);
        }
        ReleasePackage pkg = releaseService.findPackage(release.id(), MACOS_PLATFORM)
            .orElseThrow(() -> FrameleanApiException.notFound("Package not found: " + version + " platform=" + MACOS_PLATFORM));
        ReleaseArtifactStorage.PresignedUrl presigned = storage.presignDownload(pkg.objectKey(), pkg.fileName(), DOWNLOAD_URL_TTL);
        repository.insertDownloadEvent(release.id(), pkg.platform(), pkg.arch(), null, ipAddress);
        return presigned.url();
    }

    @Transactional
    public DownloadTicketResponse createLegacyDownloadTicket(String version, String platform, String installId, String ipAddress) {
        DownloadTicketCreateResponse ticket = createDownloadTicket(version, platform, installId, ipAddress);
        return resolveDownloadTicket(ticket.ticketId());
    }

    public DownloadTicketCreateResponse createDownloadTicket(String version, String platform, String installId, String ipAddress) {
        adminAuditService.ensureIpAllowed(ipAddress);
        Release release = releaseService.findByVersion(version);
        if (!"published".equals(release.status())) {
            throw FrameleanApiException.notFound("Release not found: " + version);
        }
        ReleasePackage pkg = releaseService.findPackage(release.id(), platform)
            .orElseThrow(() -> FrameleanApiException.notFound("Package not found: " + version + " platform=" + platform));
        String ticketId = UUID.randomUUID().toString();
        Instant expiresAt = Instant.now().plus(TICKET_TTL);
        DownloadTicketPayload payload = new DownloadTicketPayload(
            release.id(), platform, pkg.arch(), pkg.objectKey(), pkg.fileName(), pkg.size(), pkg.sha256(), pkg.ed25519Signature(), installId, ipAddress
        );
        try {
            redisTemplate.opsForValue().set(ticketKey(ticketId), objectMapper.writeValueAsString(payload), TICKET_TTL);
        } catch (JsonProcessingException ex) {
            throw new IllegalStateException("failed to serialize download ticket", ex);
        }
        return new DownloadTicketCreateResponse(ticketId, DateTimeFormatter.ISO_INSTANT.format(expiresAt), pkg.fileName(), pkg.size(), pkg.sha256(), pkg.ed25519Signature());
    }

    @Transactional
    public DownloadTicketResponse resolveDownloadTicket(String ticketId) {
        String payloadJson = redisTemplate.opsForValue().get(ticketKey(ticketId));
        if (payloadJson == null) {
            throw new FrameleanApiException("ticket_not_found", org.springframework.http.HttpStatus.NOT_FOUND, "Ticket not found: " + ticketId);
        }
        DownloadTicketPayload payload;
        try {
            payload = objectMapper.readValue(payloadJson, DownloadTicketPayload.class);
        } catch (JsonProcessingException ex) {
            throw new IllegalStateException("failed to deserialize download ticket", ex);
        }
        ReleaseArtifactStorage.PresignedUrl presigned = storage.presignDownload(payload.objectKey(), payload.fileName(), DOWNLOAD_URL_TTL);
        repository.insertDownloadEvent(payload.releaseId(), payload.platform(), payload.arch(), payload.installId(), payload.ipAddress());
        return new DownloadTicketResponse(
            presigned.url().toString(),
            DateTimeFormatter.ISO_INSTANT.format(presigned.expiresAt()),
            payload.fileName(),
            payload.size(),
            payload.sha256(),
            payload.ed25519Signature()
        );
    }

    public long countDownloads(long releaseId) {
        return repository.countDownloads(releaseId);
    }

    public long totalDownloads() {
        return repository.countTotalDownloads();
    }

    public void clearLatestCache() {
        try {
            var keys = redisTemplate.keys("update:latest:*");
            if (keys != null && !keys.isEmpty()) {
                redisTemplate.delete(keys);
            }
        } catch (Exception ignored) {
            // Cache invalidation must not fail a validated publish.
        }
    }

    private Release findLatestPublishedCached(String channel, int currentBuild, String platform) {
        String key = "update:latest:" + platform + ":" + channel + ":" + currentBuild;
        try {
            String cached = redisTemplate.opsForValue().get(key);
            if (cached != null) {
                return releaseService.findById(Long.parseLong(cached));
            }
            Release release = releaseService.findPublishedLatest(channel, currentBuild, platform).orElse(null);
            if (release != null) {
                redisTemplate.opsForValue().set(key, Long.toString(release.id()), LATEST_CACHE_TTL);
            }
            return release;
        } catch (Exception ignored) {
            return releaseService.findPublishedLatest(channel, currentBuild, platform).orElse(null);
        }
    }

    private String sparkleItem(Release release, String channel, String baseUrl) {
        ReleasePackage pkg = releaseService.findPackages(release.id()).stream()
            .filter(item -> MACOS_PLATFORM.equals(item.platform()) && item.clientVisible())
            .findFirst()
            .orElse(null);
        if (pkg == null || pkg.ed25519Signature() == null || pkg.ed25519Signature().isBlank()) {
            return null;
        }
        Instant publishedAt = release.publishedAt() != null ? release.publishedAt() : (release.updatedAt() != null ? release.updatedAt() : Instant.now());
        String notesUrl = baseUrl + "/api/v1/releases/" + urlEncode(release.version()) + "/notes";
        String downloadUrl = baseUrl + "/api/v1/sparkle/download/" + urlEncode(release.version()) + "?channel=" + urlEncode(channel);
        return """
            <item>
              <title>Version %s</title>
              <sparkle:version>%d</sparkle:version>
              <sparkle:shortVersionString>%s</sparkle:shortVersionString>
              <sparkle:minimumSystemVersion>10.15</sparkle:minimumSystemVersion>
              <sparkle:releaseNotesLink>%s</sparkle:releaseNotesLink>
              <pubDate>%s</pubDate>
              <enclosure url="%s" sparkle:edSignature="%s" length="%d" type="application/x-apple-diskimage" />
            </item>
            """.formatted(
            xml(release.version()),
            release.buildNumber(),
            xml(release.version()),
            xml(notesUrl),
            DateTimeFormatter.RFC_1123_DATE_TIME.format(publishedAt.atOffset(ZoneOffset.UTC)),
            xml(downloadUrl),
            xml(pkg.ed25519Signature().trim()),
            pkg.size()
        ).trim();
    }

    private String resolveReleaseNotes(Release release) {
        if (hasText(release.notes())) {
            return release.notes();
        }
        if (!hasText(release.notesObjectKey())) {
            return "";
        }
        String objectKey = release.notesObjectKey().trim();
        try {
            String notes = storage.readTextObject(objectKey);
            if (notes == null) {
                throw FrameleanApiException.notFound("Release notes file not found: " + objectKey);
            }
            return notes;
        } catch (FrameleanApiException ex) {
            throw ex;
        } catch (Exception ex) {
            throw new FrameleanApiException(
                "release_notes_unavailable",
                org.springframework.http.HttpStatus.BAD_GATEWAY,
                "Release notes file could not be read: " + objectKey
            );
        }
    }

    private String summarizeNotes(String notes) {
        return notes.lines()
            .map(String::trim)
            .filter(line -> !line.isEmpty() && !line.startsWith("#"))
            .findFirst()
            .map(line -> {
                String normalized = line.replaceFirst("^[-*]\\s*", "");
                return normalized.length() <= 72 ? normalized : normalized.substring(0, 72) + "...";
            })
            .orElse("查看版本日志了解本次更新内容。");
    }

    private boolean hasText(String value) {
        return value != null && !value.isBlank();
    }

    private String ticketKey(String ticketId) {
        return "update:ticket:" + ticketId;
    }

    private String urlEncode(String value) {
        return URLEncoder.encode(value, StandardCharsets.UTF_8).replace("+", "%20");
    }

    private String xml(String value) {
        return value
            .replace("&", "&amp;")
            .replace("\"", "&quot;")
            .replace("<", "&lt;")
            .replace(">", "&gt;");
    }

    private String string(Instant instant) {
        return instant == null ? null : instant.toString();
    }

    private record DownloadTicketPayload(
        long releaseId,
        String platform,
        String arch,
        String objectKey,
        String fileName,
        long size,
        String sha256,
        String ed25519Signature,
        String installId,
        String ipAddress
    ) {
    }
}
