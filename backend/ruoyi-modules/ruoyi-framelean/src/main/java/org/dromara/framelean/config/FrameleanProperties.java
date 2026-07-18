package org.dromara.framelean.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

import java.net.URI;
import java.util.Set;

@Component
@ConfigurationProperties(prefix = "framelean")
public class FrameleanProperties {
    private String apiKey = "";
    private Update update = new Update();
    private Cos cos = new Cos();

    public String getApiKey() {
        return apiKey;
    }

    public void setApiKey(String apiKey) {
        this.apiKey = apiKey == null ? "" : apiKey;
    }

    public Update getUpdate() {
        return update;
    }

    public void setUpdate(Update update) {
        this.update = update == null ? new Update() : update;
    }

    public Cos getCos() {
        return cos;
    }

    public void setCos(Cos cos) {
        this.cos = cos == null ? new Cos() : cos;
    }

    public String normalizedPublicBaseUrl() {
        String value = update.publicBaseUrl == null ? "" : update.publicBaseUrl.trim().replaceAll("/+$", "");
        URI uri;
        try {
            uri = URI.create(value);
        } catch (IllegalArgumentException ex) {
            throw new IllegalStateException("FRAMELEAN_PUBLIC_BASE_URL is invalid", ex);
        }
        if (!Set.of("http", "https").contains(uri.getScheme()) || uri.getHost() == null || uri.getHost().isBlank()) {
            throw new IllegalStateException("FRAMELEAN_PUBLIC_BASE_URL must be an absolute HTTP(S) URL");
        }
        boolean loopback = Set.of("localhost", "127.0.0.1", "::1").contains(uri.getHost());
        if (!"https".equals(uri.getScheme()) && !loopback) {
            throw new IllegalStateException("FRAMELEAN_PUBLIC_BASE_URL must use HTTPS outside local development");
        }
        return value;
    }

    public boolean isApiKeyConfigured() {
        return apiKey != null && !apiKey.isBlank();
    }

    public static class Update {
        private String publicBaseUrl = "http://localhost:4918";

        public String getPublicBaseUrl() {
            return publicBaseUrl;
        }

        public void setPublicBaseUrl(String publicBaseUrl) {
            this.publicBaseUrl = publicBaseUrl;
        }
    }

    public static class Cos {
        private String secretId = "";
        private String secretKey = "";
        private String bucket = "";
        private String region = "ap-guangzhou";

        public String getSecretId() {
            return secretId;
        }

        public void setSecretId(String secretId) {
            this.secretId = secretId == null ? "" : secretId;
        }

        public String getSecretKey() {
            return secretKey;
        }

        public void setSecretKey(String secretKey) {
            this.secretKey = secretKey == null ? "" : secretKey;
        }

        public String getBucket() {
            return bucket;
        }

        public void setBucket(String bucket) {
            this.bucket = bucket == null ? "" : bucket;
        }

        public String getRegion() {
            return region;
        }

        public void setRegion(String region) {
            this.region = region == null ? "" : region;
        }

        public boolean isConfigured() {
            return !secretId.isBlank() && !secretKey.isBlank() && !bucket.isBlank() && !region.isBlank();
        }
    }
}
