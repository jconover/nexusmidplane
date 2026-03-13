package com.nexusmidplane.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.net.InetAddress;
import java.net.UnknownHostException;
import java.time.Instant;
import java.util.Map;

@RestController
public class HealthController {

    @GetMapping("/health")
    public Map<String, Object> health() {
        return Map.of(
            "status", "healthy",
            "service", "java-app",
            "timestamp", Instant.now().toString()
        );
    }

    @GetMapping("/hello")
    public Map<String, Object> hello() throws UnknownHostException {
        return Map.of(
            "message", "Hello from NexusMidplane Java tier",
            "runtime", "Java 17 + WildFly",
            "hostname", InetAddress.getLocalHost().getHostName()
        );
    }

    @GetMapping("/info")
    public Map<String, Object> info() {
        return Map.of(
            "service", "nexusmidplane-java",
            "version", "1.0.0",
            "server", "WildFly 30"
        );
    }
}
