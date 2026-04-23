package com.chen.server.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import org.springframework.web.filter.CorsFilter;

@Configuration
public class CorsConfig {
    @Bean
    public CorsFilter corsFilter() {
        // 1. 配置跨域
        CorsConfiguration config = new CorsConfiguration();
        // 允许的前端域名（必须精确到端口，不能用*）
        config.addAllowedOrigin("http://localhost:81");
        // 允许携带凭证（Cookie/Token）
        config.setAllowCredentials(true);
        // 允许所有请求方法（GET/POST/PUT/DELETE/OPTIONS）
        config.addAllowedMethod("*");
        // 允许所有请求头（包括自定义头如token）
        config.addAllowedHeader("*");
        // 预检请求缓存时间（3600秒，减少重复验证）
        config.setMaxAge(3600L);

        // 2. 应用到所有接口
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);

        // 3. 返回CorsFilter（优先级高于Security的cors配置）
        return new CorsFilter(source);
    }
}