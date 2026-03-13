package com.nexusmidplane;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.boot.web.servlet.support.SpringBootServletInitializer;

@SpringBootApplication
public class NexusMidplaneApplication extends SpringBootServletInitializer {

    @Override
    protected SpringApplicationBuilder configure(SpringApplicationBuilder application) {
        // Enable WAR deployment to external servlet container (WildFly)
        return application.sources(NexusMidplaneApplication.class);
    }

    public static void main(String[] args) {
        SpringApplication.run(NexusMidplaneApplication.class, args);
    }
}
