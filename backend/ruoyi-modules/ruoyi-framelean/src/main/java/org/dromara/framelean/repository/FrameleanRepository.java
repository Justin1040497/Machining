package org.dromara.framelean.repository;

import org.dromara.framelean.domain.FrameleanModels.ArtifactRequirement;
import org.dromara.framelean.domain.FrameleanModels.DownloadEvent;
import org.dromara.framelean.domain.FrameleanModels.IpBlockRule;
import org.dromara.framelean.domain.FrameleanModels.Release;
import org.dromara.framelean.domain.FrameleanModels.ReleasePackage;
import org.dromara.framelean.domain.FrameleanModels.UpdateCheckEvent;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

@Repository
public class FrameleanRepository {
    private final NamedParameterJdbcTemplate jdbc;

    public FrameleanRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public Optional<Release> findLatestPublished(String channel, int currentBuild, String platform) {
        return queryOne("""
            SELECT * FROM releases r
            WHERE r.channel = :channel
              AND r.status = 'published'
              AND r.build_number > :currentBuild
              AND (
                EXISTS (
                  SELECT 1 FROM release_packages
                  WHERE release_packages.release_id = r.id
                    AND release_packages.platform = :platform
                    AND release_packages.client_visible = TRUE
                )
                OR (
                  -- External download links (GitHub / Gitee / backup) are platform-agnostic.
                  NULLIF(r.github_download_url, '') IS NOT NULL
                  OR NULLIF(r.gitee_download_url, '') IS NOT NULL
                  OR NULLIF(r.backup_download_url, '') IS NOT NULL
                )
              )
            ORDER BY r.build_number DESC
            LIMIT 1
            """, params()
            .addValue("channel", channel)
            .addValue("currentBuild", currentBuild)
            .addValue("platform", platform), releaseMapper());
    }

    public Optional<Release> findReleaseById(long id) {
        return queryOne("SELECT * FROM releases WHERE id = :id", params().addValue("id", id), releaseMapper());
    }

    public Optional<Release> findLatestReleaseByVersion(String version) {
        return queryOne("""
            SELECT * FROM releases
            WHERE version = :version
            ORDER BY build_number DESC
            LIMIT 1
            """, params().addValue("version", version), releaseMapper());
    }

    public List<Release> listReleases() {
        return jdbc.query("SELECT * FROM releases ORDER BY build_number DESC", params(), releaseMapper());
    }

    public List<Release> listPublishedReleases(String channel) {
        return jdbc.query("""
            SELECT * FROM releases
            WHERE channel = :channel AND status = 'published'
            ORDER BY build_number DESC
            """, params().addValue("channel", channel), releaseMapper());
    }

    public Release insertRelease(String version, int buildNumber, String channel, boolean mandatory, int minSupportedBuild, String notes, String notesObjectKey, String githubDownloadUrl, String giteeDownloadUrl, String backupDownloadUrl) {
        return jdbc.queryForObject("""
            INSERT INTO releases (version, build_number, channel, mandatory, min_supported_build, notes, notes_object_key, status, github_download_url, gitee_download_url, backup_download_url)
            VALUES (:version, :buildNumber, :channel, :mandatory, :minSupportedBuild, :notes, :notesObjectKey, 'draft', :githubDownloadUrl, :giteeDownloadUrl, :backupDownloadUrl)
            RETURNING *
            """, params()
            .addValue("version", version)
            .addValue("buildNumber", buildNumber)
            .addValue("channel", channel)
            .addValue("mandatory", mandatory)
            .addValue("minSupportedBuild", minSupportedBuild)
            .addValue("notes", notes)
            .addValue("notesObjectKey", notesObjectKey)
            .addValue("githubDownloadUrl", githubDownloadUrl)
            .addValue("giteeDownloadUrl", giteeDownloadUrl)
            .addValue("backupDownloadUrl", backupDownloadUrl), releaseMapper());
    }

    public Release updateReleaseStatus(long id, String status, Instant publishedAt) {
        return jdbc.queryForObject("""
            UPDATE releases
            SET status = :status, published_at = :publishedAt, updated_at = now()
            WHERE id = :id
            RETURNING *
            """, params()
            .addValue("id", id)
            .addValue("status", status)
            .addValue("publishedAt", Timestamp.from(publishedAt)), releaseMapper());
    }

    public Release updateBuildNumber(long id, int buildNumber) {
        return jdbc.queryForObject("""
            UPDATE releases
            SET build_number = :buildNumber, updated_at = now()
            WHERE id = :id
            RETURNING *
            """, params().addValue("id", id).addValue("buildNumber", buildNumber), releaseMapper());
    }

    public Release updateNotes(long id, String notes, String notesObjectKey) {
        return jdbc.queryForObject("""
            UPDATE releases
            SET notes = :notes, notes_object_key = :notesObjectKey, updated_at = now()
            WHERE id = :id
            RETURNING *
            """, params().addValue("id", id).addValue("notes", notes).addValue("notesObjectKey", notesObjectKey), releaseMapper());
    }

    public Release updateDownloadUrls(long id, String githubDownloadUrl, String giteeDownloadUrl, String backupDownloadUrl) {
        return jdbc.queryForObject("""
            UPDATE releases
            SET github_download_url = :githubDownloadUrl,
                gitee_download_url = :giteeDownloadUrl,
                backup_download_url = :backupDownloadUrl,
                updated_at = now()
            WHERE id = :id
            RETURNING *
            """, params()
            .addValue("id", id)
            .addValue("githubDownloadUrl", githubDownloadUrl)
            .addValue("giteeDownloadUrl", giteeDownloadUrl)
            .addValue("backupDownloadUrl", backupDownloadUrl), releaseMapper());
    }

    public void deleteRelease(long id) {
        jdbc.update("DELETE FROM releases WHERE id = :id", params().addValue("id", id));
    }

    public List<ReleasePackage> listPackages(long releaseId) {
        return jdbc.query("""
            SELECT * FROM release_packages
            WHERE release_id = :releaseId
            ORDER BY created_at ASC, id ASC
            """, params().addValue("releaseId", releaseId), packageMapper());
    }

    public Optional<ReleasePackage> findClientPackage(long releaseId, String platform) {
        return queryOne("""
            SELECT * FROM release_packages
            WHERE release_id = :releaseId AND platform = :platform AND client_visible = TRUE
            LIMIT 1
            """, params().addValue("releaseId", releaseId).addValue("platform", platform), packageMapper());
    }

    public Optional<ReleasePackage> findPackageTarget(long releaseId, String platform, String arch) {
        return queryOne("""
            SELECT * FROM release_packages
            WHERE release_id = :releaseId AND platform = :platform AND arch = :arch
            LIMIT 1
            """, params().addValue("releaseId", releaseId).addValue("platform", platform).addValue("arch", arch), packageMapper());
    }

    public ReleasePackage insertPackage(long releaseId, String platform, String arch, String fileName, String objectKey, long size, String sha256, String signature, boolean clientVisible) {
        return jdbc.queryForObject("""
            INSERT INTO release_packages (release_id, platform, arch, file_name, object_key, size, sha256, ed25519_signature, client_visible)
            VALUES (:releaseId, :platform, :arch, :fileName, :objectKey, :size, :sha256, :signature, :clientVisible)
            RETURNING *
            """, packageParams(releaseId, platform, arch, fileName, objectKey, size, sha256, signature, clientVisible), packageMapper());
    }

    public ReleasePackage updatePackage(long id, String fileName, String objectKey, long size, String sha256, String signature, boolean clientVisible) {
        return jdbc.queryForObject("""
            UPDATE release_packages
            SET file_name = :fileName,
                object_key = :objectKey,
                size = :size,
                sha256 = :sha256,
                ed25519_signature = :signature,
                client_visible = :clientVisible
            WHERE id = :id
            RETURNING *
            """, params()
            .addValue("id", id)
            .addValue("fileName", fileName)
            .addValue("objectKey", objectKey)
            .addValue("size", size)
            .addValue("sha256", sha256)
            .addValue("signature", signature)
            .addValue("clientVisible", clientVisible), packageMapper());
    }

    public void deletePackagesByRelease(long releaseId) {
        jdbc.update("DELETE FROM release_packages WHERE release_id = :releaseId", params().addValue("releaseId", releaseId));
    }

    public List<ArtifactRequirement> listRequirements(long releaseId) {
        return jdbc.query("""
            SELECT * FROM release_artifact_requirements
            WHERE release_id = :releaseId
            ORDER BY id ASC
            """, params().addValue("releaseId", releaseId), requirementMapper());
    }

    public ArtifactRequirement insertRequirement(long releaseId, String platform, String arch, boolean required) {
        return jdbc.queryForObject("""
            INSERT INTO release_artifact_requirements (release_id, platform, arch, required)
            VALUES (:releaseId, :platform, :arch, :required)
            RETURNING *
            """, params()
            .addValue("releaseId", releaseId)
            .addValue("platform", platform)
            .addValue("arch", arch)
            .addValue("required", required), requirementMapper());
    }

    public void deleteRequirementsByRelease(long releaseId) {
        jdbc.update("DELETE FROM release_artifact_requirements WHERE release_id = :releaseId", params().addValue("releaseId", releaseId));
    }

    public void insertDownloadEvent(long releaseId, String platform, String arch, String installId, String ipAddress) {
        jdbc.update("""
            INSERT INTO download_events (release_id, platform, arch, install_id, ip_address)
            VALUES (:releaseId, :platform, :arch, :installId, :ipAddress)
            """, params()
            .addValue("releaseId", releaseId)
            .addValue("platform", platform)
            .addValue("arch", arch)
            .addValue("installId", installId)
            .addValue("ipAddress", ipAddress));
    }

    public void deleteDownloadsByRelease(long releaseId) {
        jdbc.update("DELETE FROM download_events WHERE release_id = :releaseId", params().addValue("releaseId", releaseId));
    }

    public long countDownloads(long releaseId) {
        return count("SELECT COUNT(*) FROM download_events WHERE release_id = :releaseId", params().addValue("releaseId", releaseId));
    }

    public long countTotalDownloads() {
        return count("SELECT COUNT(*) FROM download_events", params());
    }

    public long countDistinctDownloadIps() {
        return count("SELECT COUNT(DISTINCT ip_address) FROM download_events WHERE ip_address IS NOT NULL AND ip_address <> ''", params());
    }

    public void insertUpdateCheck(Long releaseId, String currentVersion, int currentBuild, String platform, String channel, String installId, String ipAddress, String userAgent, boolean updateAvailable, boolean blocked) {
        jdbc.update("""
            INSERT INTO update_check_events (
              release_id, current_version, current_build, platform, channel, install_id, ip_address, user_agent, update_available, blocked
            ) VALUES (
              :releaseId, :currentVersion, :currentBuild, :platform, :channel, :installId, :ipAddress, :userAgent, :updateAvailable, :blocked
            )
            """, params()
            .addValue("releaseId", releaseId)
            .addValue("currentVersion", currentVersion)
            .addValue("currentBuild", currentBuild)
            .addValue("platform", platform)
            .addValue("channel", channel)
            .addValue("installId", installId)
            .addValue("ipAddress", ipAddress)
            .addValue("userAgent", userAgent)
            .addValue("updateAvailable", updateAvailable)
            .addValue("blocked", blocked));
    }

    public long countTotalUpdateChecks() {
        return count("SELECT COUNT(*) FROM update_check_events", params());
    }

    public long countDistinctCheckIps() {
        return count("SELECT COUNT(DISTINCT ip_address) FROM update_check_events WHERE ip_address IS NOT NULL AND ip_address <> ''", params());
    }

    public List<UpdateCheckEvent> listUpdateChecks(String ipAddress, String platform, Boolean blocked, int limit, int offset) {
        QueryParts query = updateCheckFilter(ipAddress, platform, blocked);
        return jdbc.query("SELECT * FROM update_check_events " + query.where + " ORDER BY created_at DESC LIMIT :limit OFFSET :offset",
            query.params.addValue("limit", limit).addValue("offset", offset), updateCheckMapper());
    }

    public long countUpdateChecks(String ipAddress, String platform, Boolean blocked) {
        QueryParts query = updateCheckFilter(ipAddress, platform, blocked);
        return count("SELECT COUNT(*) FROM update_check_events " + query.where, query.params);
    }

    public List<DownloadEvent> listDownloadEvents(String ipAddress, String platform, Long releaseId, int limit, int offset) {
        QueryParts query = downloadFilter(ipAddress, platform, releaseId);
        return jdbc.query("SELECT * FROM download_events " + query.where + " ORDER BY created_at DESC LIMIT :limit OFFSET :offset",
            query.params.addValue("limit", limit).addValue("offset", offset), downloadMapper());
    }

    public long countDownloadEvents(String ipAddress, String platform, Long releaseId) {
        QueryParts query = downloadFilter(ipAddress, platform, releaseId);
        return count("SELECT COUNT(*) FROM download_events " + query.where, query.params);
    }

    public Optional<IpBlockRule> findActiveIpBlock(String ipAddress) {
        return queryOne("""
            SELECT * FROM ip_block_rules
            WHERE ip_address = :ipAddress
              AND enabled = TRUE
              AND (expires_at IS NULL OR expires_at > now())
            ORDER BY created_at DESC
            LIMIT 1
            """, params().addValue("ipAddress", ipAddress), ipBlockMapper());
    }

    public long countActiveIpBlocks() {
        return count("SELECT COUNT(*) FROM ip_block_rules WHERE enabled = TRUE AND (expires_at IS NULL OR expires_at > now())", params());
    }

    public IpBlockRule insertIpBlock(String ipAddress, String reason) {
        return jdbc.queryForObject("""
            INSERT INTO ip_block_rules (ip_address, reason, enabled)
            VALUES (:ipAddress, :reason, TRUE)
            RETURNING *
            """, params().addValue("ipAddress", ipAddress).addValue("reason", reason), ipBlockMapper());
    }

    public List<IpBlockRule> listIpBlocks(String ipAddress, int limit, int offset) {
        QueryParts query = ipBlockFilter(ipAddress);
        return jdbc.query("SELECT * FROM ip_block_rules " + query.where + " ORDER BY created_at DESC LIMIT :limit OFFSET :offset",
            query.params.addValue("limit", limit).addValue("offset", offset), ipBlockMapper());
    }

    public long countIpBlocks(String ipAddress) {
        QueryParts query = ipBlockFilter(ipAddress);
        return count("SELECT COUNT(*) FROM ip_block_rules " + query.where, query.params);
    }

    public void disableIpBlock(long id) {
        jdbc.update("UPDATE ip_block_rules SET enabled = FALSE, updated_at = now() WHERE id = :id", params().addValue("id", id));
    }

    private QueryParts updateCheckFilter(String ipAddress, String platform, Boolean blocked) {
        List<String> conditions = new ArrayList<>();
        MapSqlParameterSource params = params();
        if (ipAddress != null && !ipAddress.isBlank()) {
            conditions.add("ip_address = :ipAddress");
            params.addValue("ipAddress", ipAddress);
        }
        if (platform != null && !platform.isBlank()) {
            conditions.add("platform = :platform");
            params.addValue("platform", platform);
        }
        if (blocked != null) {
            conditions.add("blocked = :blocked");
            params.addValue("blocked", blocked);
        }
        return new QueryParts(where(conditions), params);
    }

    private QueryParts downloadFilter(String ipAddress, String platform, Long releaseId) {
        List<String> conditions = new ArrayList<>();
        MapSqlParameterSource params = params();
        if (ipAddress != null && !ipAddress.isBlank()) {
            conditions.add("ip_address = :ipAddress");
            params.addValue("ipAddress", ipAddress);
        }
        if (platform != null && !platform.isBlank()) {
            conditions.add("platform = :platform");
            params.addValue("platform", platform);
        }
        if (releaseId != null) {
            conditions.add("release_id = :releaseId");
            params.addValue("releaseId", releaseId);
        }
        return new QueryParts(where(conditions), params);
    }

    private QueryParts ipBlockFilter(String ipAddress) {
        List<String> conditions = new ArrayList<>();
        MapSqlParameterSource params = params();
        if (ipAddress != null && !ipAddress.isBlank()) {
            conditions.add("ip_address = :ipAddress");
            params.addValue("ipAddress", ipAddress);
        }
        return new QueryParts(where(conditions), params);
    }

    private String where(List<String> conditions) {
        return conditions.isEmpty() ? "" : "WHERE " + String.join(" AND ", conditions);
    }

    private long count(String sql, MapSqlParameterSource params) {
        Long value = jdbc.queryForObject(sql, params, Long.class);
        return value == null ? 0L : value;
    }

    private <T> Optional<T> queryOne(String sql, MapSqlParameterSource params, RowMapper<T> mapper) {
        try {
            return Optional.ofNullable(jdbc.queryForObject(sql, params, mapper));
        } catch (EmptyResultDataAccessException ex) {
            return Optional.empty();
        }
    }

    private MapSqlParameterSource params() {
        return new MapSqlParameterSource();
    }

    private MapSqlParameterSource packageParams(long releaseId, String platform, String arch, String fileName, String objectKey, long size, String sha256, String signature, boolean clientVisible) {
        return params()
            .addValue("releaseId", releaseId)
            .addValue("platform", platform)
            .addValue("arch", arch)
            .addValue("fileName", fileName)
            .addValue("objectKey", objectKey)
            .addValue("size", size)
            .addValue("sha256", sha256)
            .addValue("signature", signature)
            .addValue("clientVisible", clientVisible);
    }

    private RowMapper<Release> releaseMapper() {
        return (rs, rowNum) -> new Release(
            rs.getLong("id"),
            rs.getString("version"),
            rs.getInt("build_number"),
            rs.getString("channel"),
            rs.getBoolean("mandatory"),
            rs.getInt("min_supported_build"),
            rs.getString("notes"),
            rs.getString("notes_object_key"),
            rs.getString("status"),
            instant(rs, "created_at"),
            instant(rs, "published_at"),
            instant(rs, "updated_at"),
            rs.getString("github_download_url"),
            rs.getString("gitee_download_url"),
            rs.getString("backup_download_url")
        );
    }

    private RowMapper<ReleasePackage> packageMapper() {
        return (rs, rowNum) -> new ReleasePackage(
            rs.getLong("id"),
            rs.getLong("release_id"),
            rs.getString("platform"),
            rs.getString("arch"),
            rs.getString("file_name"),
            rs.getString("object_key"),
            rs.getLong("size"),
            rs.getString("sha256"),
            rs.getString("ed25519_signature"),
            rs.getBoolean("client_visible"),
            instant(rs, "created_at")
        );
    }

    private RowMapper<ArtifactRequirement> requirementMapper() {
        return (rs, rowNum) -> new ArtifactRequirement(
            rs.getLong("id"),
            rs.getLong("release_id"),
            rs.getString("platform"),
            rs.getString("arch"),
            rs.getBoolean("required"),
            instant(rs, "created_at")
        );
    }

    private RowMapper<DownloadEvent> downloadMapper() {
        return (rs, rowNum) -> new DownloadEvent(
            rs.getLong("id"),
            rs.getLong("release_id"),
            rs.getString("platform"),
            rs.getString("arch"),
            rs.getString("install_id"),
            rs.getString("ip_address"),
            instant(rs, "created_at")
        );
    }

    private RowMapper<UpdateCheckEvent> updateCheckMapper() {
        return (rs, rowNum) -> {
            long releaseId = rs.getLong("release_id");
            return new UpdateCheckEvent(
                rs.getLong("id"),
                rs.wasNull() ? null : releaseId,
                rs.getString("current_version"),
                rs.getInt("current_build"),
                rs.getString("platform"),
                rs.getString("channel"),
                rs.getString("install_id"),
                rs.getString("ip_address"),
                rs.getString("user_agent"),
                rs.getBoolean("update_available"),
                rs.getBoolean("blocked"),
                instant(rs, "created_at")
            );
        };
    }

    private RowMapper<IpBlockRule> ipBlockMapper() {
        return (rs, rowNum) -> new IpBlockRule(
            rs.getLong("id"),
            rs.getString("ip_address"),
            rs.getString("reason"),
            rs.getBoolean("enabled"),
            instant(rs, "expires_at"),
            instant(rs, "created_at"),
            instant(rs, "updated_at")
        );
    }

    private Instant instant(ResultSet rs, String column) throws SQLException {
        Timestamp timestamp = rs.getTimestamp(column);
        return timestamp == null ? null : timestamp.toInstant();
    }

    private record QueryParts(String where, MapSqlParameterSource params) {
    }
}
