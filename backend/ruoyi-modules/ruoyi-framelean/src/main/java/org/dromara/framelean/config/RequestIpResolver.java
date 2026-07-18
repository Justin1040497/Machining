package org.dromara.framelean.config;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.stereotype.Component;

@Component
public class RequestIpResolver {
    public String resolve(HttpServletRequest request) {
        String forwarded = firstKnown(request.getHeader("X-Forwarded-For"));
        if (forwarded != null) {
            return forwarded;
        }
        String realIp = firstKnown(request.getHeader("X-Real-IP"));
        return realIp != null ? realIp : request.getRemoteAddr();
    }

    private String firstKnown(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        String candidate = value.split(",")[0].trim();
        return candidate.isBlank() || "unknown".equalsIgnoreCase(candidate) ? null : candidate;
    }
}
