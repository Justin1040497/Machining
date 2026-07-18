package org.dromara.framelean.service;

import lombok.RequiredArgsConstructor;
import org.dromara.framelean.domain.FrameleanDtos.AdminDashboardResponse;
import org.dromara.framelean.domain.FrameleanDtos.DownloadEventRecordResponse;
import org.dromara.framelean.domain.FrameleanDtos.IpBlockRuleResponse;
import org.dromara.framelean.domain.FrameleanDtos.PageResponse;
import org.dromara.framelean.domain.FrameleanDtos.UpdateCheckRecordResponse;
import org.dromara.framelean.domain.FrameleanModels.DownloadEvent;
import org.dromara.framelean.domain.FrameleanModels.IpBlockRule;
import org.dromara.framelean.domain.FrameleanModels.UpdateCheckEvent;
import org.dromara.framelean.exception.FrameleanApiException;
import org.dromara.framelean.repository.FrameleanRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class AdminAuditService {
    private final FrameleanRepository repository;
    private final ReleaseService releaseService;

    public void ensureIpAllowed(String ipAddress) {
        if (isIpBlocked(ipAddress)) {
            throw FrameleanApiException.forbidden("ip_blocked", "IP blocked: " + ipAddress);
        }
    }

    public boolean isIpBlocked(String ipAddress) {
        return ipAddress != null && !ipAddress.isBlank() && repository.findActiveIpBlock(ipAddress).isPresent();
    }

    public void recordUpdateCheck(Long releaseId, String currentVersion, int currentBuild, String platform, String channel, String installId, String ipAddress, String userAgent, boolean updateAvailable, boolean blocked) {
        repository.insertUpdateCheck(releaseId, currentVersion, currentBuild, platform, channel, installId, ipAddress, userAgent, updateAvailable, blocked);
    }

    public AdminDashboardResponse dashboard() {
        return new AdminDashboardResponse(
            repository.countTotalDownloads(),
            repository.countTotalUpdateChecks(),
            repository.countDistinctDownloadIps(),
            repository.countDistinctCheckIps(),
            repository.countActiveIpBlocks()
        );
    }

    public PageResponse<UpdateCheckRecordResponse> updateChecks(String ipAddress, String platform, Boolean blocked, int page, int pageSize) {
        int safePage = Math.max(1, page);
        int safePageSize = Math.max(1, Math.min(100, pageSize));
        int offset = (safePage - 1) * safePageSize;
        List<UpdateCheckRecordResponse> items = repository.listUpdateChecks(ipAddress, platform, blocked, safePageSize, offset).stream()
            .map(this::toUpdateCheckResponse)
            .toList();
        return new PageResponse<>(items, repository.countUpdateChecks(ipAddress, platform, blocked), safePage, safePageSize);
    }

    public PageResponse<DownloadEventRecordResponse> downloads(String ipAddress, String platform, Long releaseId, int page, int pageSize) {
        int safePage = Math.max(1, page);
        int safePageSize = Math.max(1, Math.min(100, pageSize));
        int offset = (safePage - 1) * safePageSize;
        List<DownloadEventRecordResponse> items = repository.listDownloadEvents(ipAddress, platform, releaseId, safePageSize, offset).stream()
            .map(this::toDownloadResponse)
            .toList();
        return new PageResponse<>(items, repository.countDownloadEvents(ipAddress, platform, releaseId), safePage, safePageSize);
    }

    @Transactional
    public IpBlockRuleResponse createIpBlock(String ipAddress, String reason) {
        IpBlockRule rule = repository.insertIpBlock(ipAddress.trim(), reason == null || reason.isBlank() ? null : reason.trim());
        return toIpBlockResponse(rule);
    }

    public PageResponse<IpBlockRuleResponse> ipBlocks(String ipAddress, int page, int pageSize) {
        int safePage = Math.max(1, page);
        int safePageSize = Math.max(1, Math.min(100, pageSize));
        int offset = (safePage - 1) * safePageSize;
        List<IpBlockRuleResponse> items = repository.listIpBlocks(ipAddress, safePageSize, offset).stream()
            .map(this::toIpBlockResponse)
            .toList();
        return new PageResponse<>(items, repository.countIpBlocks(ipAddress), safePage, safePageSize);
    }

    public void disableIpBlock(long id) {
        repository.disableIpBlock(id);
    }

    private UpdateCheckRecordResponse toUpdateCheckResponse(UpdateCheckEvent event) {
        String releaseVersion = null;
        if (event.releaseId() != null) {
            releaseVersion = repository.findReleaseById(event.releaseId()).map(org.dromara.framelean.domain.FrameleanModels.Release::version).orElse(null);
        }
        return new UpdateCheckRecordResponse(
            event.id(),
            event.releaseId(),
            releaseVersion,
            event.currentVersion(),
            event.currentBuild(),
            event.platform(),
            event.channel(),
            event.installId(),
            event.ipAddress(),
            event.userAgent(),
            event.updateAvailable(),
            event.blocked(),
            string(event.createdAt())
        );
    }

    private DownloadEventRecordResponse toDownloadResponse(DownloadEvent event) {
        String releaseVersion = repository.findReleaseById(event.releaseId()).map(org.dromara.framelean.domain.FrameleanModels.Release::version).orElse(null);
        return new DownloadEventRecordResponse(
            event.id(),
            event.releaseId(),
            releaseVersion,
            event.platform(),
            event.arch(),
            event.installId(),
            event.ipAddress(),
            string(event.createdAt())
        );
    }

    private IpBlockRuleResponse toIpBlockResponse(IpBlockRule rule) {
        return new IpBlockRuleResponse(
            rule.id(),
            rule.ipAddress(),
            rule.reason(),
            rule.enabled(),
            string(rule.expiresAt()),
            string(rule.createdAt()),
            string(rule.updatedAt())
        );
    }

    private String string(java.time.Instant instant) {
        return instant == null ? null : instant.toString();
    }
}
