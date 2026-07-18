package org.dromara.framelean.controller;

import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.dromara.framelean.config.FrameleanProperties;
import org.dromara.framelean.config.RequestIpResolver;
import org.dromara.framelean.service.SparkleUpdateService;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/sparkle")
@RequiredArgsConstructor
public class SparkleController {
    private final SparkleUpdateService updateService;
    private final RequestIpResolver requestIpResolver;
    private final FrameleanProperties properties;

    @GetMapping(value = "/appcast", produces = "application/xml; charset=utf-8")
    public ResponseEntity<String> appcast(@RequestParam(defaultValue = "stable") String channel) {
        return ResponseEntity.ok()
            .contentType(MediaType.parseMediaType("application/xml; charset=utf-8"))
            .body(updateService.buildSparkleAppcast(channel, properties.normalizedPublicBaseUrl()));
    }

    @GetMapping("/download/{version}")
    public ResponseEntity<Void> download(
        @PathVariable String version,
        @RequestParam(defaultValue = "stable") String channel,
        HttpServletRequest request
    ) {
        return ResponseEntity.status(HttpStatus.FOUND)
            .header(HttpHeaders.LOCATION, updateService.createSparkleDownloadRedirect(version, channel, requestIpResolver.resolve(request)).toString())
            .build();
    }
}
