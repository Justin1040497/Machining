package org.dromara.framelean.config;

import com.qcloud.cos.COSClient;
import com.qcloud.cos.ClientConfig;
import com.qcloud.cos.auth.BasicCOSCredentials;
import com.qcloud.cos.region.Region;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class CosConfig {

    @Bean
    public COSClient cosClient(FrameleanProperties properties) {
        FrameleanProperties.Cos cos = properties.getCos();
        BasicCOSCredentials credentials = new BasicCOSCredentials(cos.getSecretId(), cos.getSecretKey());
        ClientConfig config = new ClientConfig(new Region(cos.getRegion()));
        return new COSClient(credentials, config);
    }
}
