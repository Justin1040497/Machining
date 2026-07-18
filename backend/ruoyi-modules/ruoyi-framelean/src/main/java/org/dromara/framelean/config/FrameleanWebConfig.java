package org.dromara.framelean.config;

import cn.dev33.satoken.stp.StpUtil;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Duration;

@Component
@RequiredArgsConstructor
public class FrameleanWebConfig implements WebMvcConfigurer {
    private final LegacyAdminAuthInterceptor legacyAdminAuthInterceptor;
    private final UpdateTicketRateLimitInterceptor updateTicketRateLimitInterceptor;

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(legacyAdminAuthInterceptor).addPathPatterns("/api/v1/admin/**");
        registry.addInterceptor(updateTicketRateLimitInterceptor).addPathPatterns(
            "/api/v1/releases/download-ticket/**",
            "/api/v1/releases/*/packages/*/ticket"
        );
    }

    @Component
    @RequiredArgsConstructor
    public static class LegacyAdminAuthInterceptor implements HandlerInterceptor {
        private final FrameleanProperties properties;

        @Override
        public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) throws Exception {
            if ("OPTIONS".equalsIgnoreCase(request.getMethod())) {
                return true;
            }
            if (hasValidApiKey(request) || isRuoYiLoggedIn()) {
                return true;
            }
            response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
            response.setContentType("application/json;charset=utf-8");
            response.getWriter().write("{\"error\":\"unauthorized\",\"message\":\"Admin authorization is required\"}");
            return false;
        }

        private boolean hasValidApiKey(HttpServletRequest request) {
            String expected = properties.getApiKey();
            String actual = request.getHeader("X-Api-Key");
            if (expected == null || expected.isBlank() || actual == null || actual.isBlank()) {
                return false;
            }
            byte[] left = expected.getBytes(StandardCharsets.UTF_8);
            byte[] right = actual.getBytes(StandardCharsets.UTF_8);
            return MessageDigest.isEqual(left, right);
        }

        private boolean isRuoYiLoggedIn() {
            try {
                return StpUtil.isLogin();
            } catch (Exception ignored) {
                return false;
            }
        }
    }

    @Slf4j
    @Component
    @RequiredArgsConstructor
    public static class UpdateTicketRateLimitInterceptor implements HandlerInterceptor {
        private static final Duration WINDOW = Duration.ofMinutes(1);
        private static final long MAX_REQUESTS_PER_WINDOW = 10L;

        private final StringRedisTemplate redisTemplate;
        private final RequestIpResolver requestIpResolver;

        @Override
        public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) throws Exception {
            String ip = requestIpResolver.resolve(request);
            long windowId = System.currentTimeMillis() / WINDOW.toMillis();
            String key = "rate:update-ticket:" + (ip == null ? "unknown" : ip) + ":" + windowId;
            try {
                Long count = redisTemplate.opsForValue().increment(key);
                if (count != null && count == 1L) {
                    redisTemplate.expire(key, WINDOW.plusSeconds(5));
                }
                if (count != null && count > MAX_REQUESTS_PER_WINDOW) {
                    response.setStatus(429);
                    response.setContentType("application/json;charset=utf-8");
                    response.getWriter().write("{\"error\":\"rate_limited\",\"message\":\"Too many requests. Please wait.\"}");
                    return false;
                }
            } catch (Exception ex) {
                log.warn("Redis rate limit unavailable, allowing request: {}", ex.getMessage());
            }
            return true;
        }
    }
}
