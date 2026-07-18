package org.dromara.framelean.controller;

import org.dromara.framelean.domain.FrameleanDtos.HealthResponse;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HealthController {

    @GetMapping("/api/v1/health")
    public HealthResponse health() {
        return new HealthResponse("ok");
    }
}
