package com.chen.server.config;

import com.chen.server.filter.JwtAuthenticationTokenFilter;
import jakarta.annotation.Resource;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.Arrays;

/**
 * Spring Security 核心配置类
 * 适配 Spring Security 6.0+ 版本，移除了过时的 WebSecurityConfigurerAdapter 继承
 */
@Configuration
@EnableMethodSecurity(prePostEnabled = true)
@EnableWebSecurity // 启用 Web 安全配置（6.0+ 版本推荐显式添加）
public class SecurityConfig {
    @Resource
    private AccessDeniedHandler accessDeniedHandler;
    @Resource
    private AuthenticationEntryPoint authenticationEntryPoint;
    @Autowired
    private JwtAuthenticationTokenFilter jwtAuthenticationTokenFilter;
    @Autowired
    private AuthenticationConfiguration authenticationConfiguration;

    /**
     * 密码加密器
     * BCrypt 算法会自动生成盐值，安全性高，推荐用于生产环境
     */
    @Bean
    public BCryptPasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    /**
     * 认证管理器
     * 用于处理认证请求（如用户名密码登录）
     */
    @Bean
    public AuthenticationManager authenticationManager() throws Exception {
        // 由Spring内部处理依赖，避免手动创建导致的循环
        return authenticationConfiguration.getAuthenticationManager();
    }

    /**
     * 核心安全过滤器链配置
     * 定义 URL 访问规则、CSRF、CORS 等安全策略
     */

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                        .requestMatchers("/user/login", "/user/register").permitAll()
                        .requestMatchers("/article/**","/category/**","/link/**","/comment/**").permitAll()
                        .requestMatchers("/swagger-ui/**", "/v3/api-docs/**").permitAll()
                        .anyRequest().authenticated()
                )
                .csrf(csrf -> csrf.disable())
                .cors(cors -> cors.configurationSource(corsConfigurationSource()))
                .addFilterBefore(jwtAuthenticationTokenFilter, UsernamePasswordAuthenticationFilter.class)
                .exceptionHandling(ex -> ex
                        .authenticationEntryPoint(authenticationEntryPoint)
                        .accessDeniedHandler(accessDeniedHandler)
                )
                .logout(logout -> logout.disable());

        return http.build();
    }
    /**
     * 跨域配置
     * 解决前后端分离架构下的跨域资源访问问题
     */
    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();
        // 关键：指定前端实际域名（必须精确匹配，不能用*）
        config.setAllowedOrigins(Arrays.asList("http://localhost:81"));
        // 允许所有HTTP方法（包含预检请求的OPTIONS）
        config.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "DELETE", "OPTIONS"));
        // 允许前端传递的所有头（特别是你项目中用的"token"头）
        config.setAllowedHeaders(Arrays.asList("istoken","token", "Content-Type", "Authorization"));
        // 允许携带凭证（如Cookie、Token）
        config.setAllowCredentials(true);
        // 预检请求缓存时间（减少重复验证）
        config.setMaxAge(3600L);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }
}
