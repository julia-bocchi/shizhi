package com.chen.server.filter;

import cn.hutool.json.JSONUtil;
import com.chen.server.domain.ResponseResult;
import com.chen.server.domain.entity.LoginUser;
import com.chen.server.enums.AppHttpCodeEnum;
import com.chen.server.utils.JwtUtils;
import com.chen.server.utils.WebUtils;
import io.jsonwebtoken.Claims;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Objects;

@Component
public class JwtAuthenticationTokenFilter extends OncePerRequestFilter {
    @Autowired
    private StringRedisTemplate stringRedisTemplate;
    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain) throws ServletException, IOException {
        //获取Token
        String token = request.getHeader("token");
        if (!StringUtils.hasText(token)) {
            //放行
            filterChain.doFilter(request, response);
            return;
        }
        //解析token
        String s;
        try {
            Claims claims = JwtUtils.parseJWT(token);
            s = claims.getSubject();
        } catch (Exception e) {
            ResponseResult responseResult = ResponseResult.errorResult(AppHttpCodeEnum.NEED_LOGIN);
            WebUtils.renderString(response,JSONUtil.toJsonStr(responseResult));
            return;

        }
        // 过滤器中修正
        String redisKey = "adminlogin:" + s;

        //从Redis获取LoginUser
        String JsonString= stringRedisTemplate.opsForValue().get(redisKey);
        LoginUser loginUser = JSONUtil.toBean(JsonString, LoginUser.class);
        System.out.println(loginUser);
        //存入SecurityHolder
        if (Objects.isNull(loginUser)) {
            ResponseResult responseResult = ResponseResult.errorResult(AppHttpCodeEnum.NEED_LOGIN);
            WebUtils.renderString(response,JSONUtil.toJsonStr(responseResult));
            return;
        }
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(loginUser, null, loginUser.getAuthorities()));

        //放行
        filterChain.doFilter(request, response);

    }
}
