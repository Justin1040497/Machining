package org.dromara.framelean.service;

import java.net.URI;

public interface SparkleUpdateService {
    String buildSparkleAppcast(String channel, String baseUrl);

    URI createSparkleDownloadRedirect(String version, String channel, String ipAddress);
}
