package com.chen.server.utils;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtBuilder;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;

import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import java.util.Base64;
import java.util.Date;
import java.util.UUID;

/**
 * JWT工具类（支持单个UserId生成token）
 */
public class JwtUtils {

    // 有效期：默认1小时（60分钟 * 60秒 * 1000毫秒）
    public static final Long JWT_TTL = 60 * 60 * 1000L;

    // 注意：HS256算法要求密钥长度至少256位（32字节），此处示例仅为演示，生产环境需替换为32位以上的安全密钥
    public static final String JWT_KEY = "u5F56eUc8zL5+6QZ6e7g8h9i0j1k2l3m4n5o6p7q8r9s0t1u2v3w4x5y6z7a8b9c0d1e2f"; // 32位密钥（示例）

    /**
     * 简化方法：仅通过 UserId 生成 JWT（其他参数使用默认值）
     * @param userId 用户唯一标识（如数据库中的user_id）
     * @return JWT字符串
     */
    public static String createJWTByUserId(String userId) {
        // 生成唯一JWT ID（避免重复，用UUID）
        String jwtId = UUID.randomUUID().toString().replace("-", "");
        // 过期时间使用默认值（1小时）
        return createJWT(jwtId, userId, JWT_TTL);
    }

    /**
     * 基础方法：自定义参数生成JWT
     * @param id JWT唯一标识（如UUID）
     * @param subject 主题（通常存储UserId等核心标识）
     * @param ttlMillis 过期时间（毫秒）
     * @return JWT字符串
     */
    public static String createJWT(String id, String subject, Long ttlMillis) {
        // 签名算法：HS256（HMAC-SHA256）
        SignatureAlgorithm signatureAlgorithm = SignatureAlgorithm.HS256;
        long nowMillis = System.currentTimeMillis();
        Date now = new Date(nowMillis);

        // 处理过期时间（默认使用全局TTL）
        long expMillis = nowMillis + (ttlMillis == null ? JWT_TTL : ttlMillis);
        Date expDate = new Date(expMillis);

        // 获取签名密钥（确保符合HS256算法要求）
        SecretKey secretKey = generalKey();

        // 构建JWT
        JwtBuilder builder = Jwts.builder()
                .setId(id)                  // JWT唯一ID（用于标识token本身）
                .setSubject(subject)        // 主题（存储UserId，解析时可通过此获取用户）
                .setIssuer("system")        // 签发者（可选，标识系统名称）
                .setIssuedAt(now)           // 签发时间
                .signWith(secretKey, signatureAlgorithm) // 签名算法+密钥
                .setExpiration(expDate);    // 过期时间

        return builder.compact();
    }

    /**
     * 生成符合HS256算法的签名密钥
     * @return 加密后的SecretKey
     */
    public static SecretKey generalKey() {
        // 1. 对密钥进行Base64解码（如果原始密钥是明文，需确保长度足够）
        byte[] encodedKey = Base64.getDecoder().decode(JWT_KEY);
        // 2. 构建HS256专用密钥（指定算法为AES兼容HMAC-SHA256）
        return new SecretKeySpec(encodedKey, 0, encodedKey.length, "HmacSHA256");
    }

    public static Claims parseJWT(String jwt) throws Exception {
        SecretKey secretKey = generalKey();
        // 旧版本无需 build()，直接用 parser()
        return Jwts.parser()
                .setSigningKey(secretKey)
                .parseClaimsJws(jwt)
                .getBody();
    }

    /**
     * 从JWT中提取UserId（需与生成时的subject对应）
     * @param jwt JWT字符串
     * @return UserId
     * @throws Exception 解析失败时抛出
     */
    public static String getUserIdFromJWT(String jwt) throws Exception {
        Claims claims = parseJWT(jwt);
        return claims.getSubject(); // 因为生成时用UserId作为subject，此处直接获取
    }
}