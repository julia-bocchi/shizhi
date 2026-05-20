package com.chen.server.service.impl;

import cn.hutool.json.JSONUtil;
import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.chen.server.domain.ResponseResult;
import com.chen.server.domain.entity.LoginUser;
import com.chen.server.domain.entity.User;
import com.chen.server.enums.AppHttpCodeEnum;
import com.chen.server.mapper.UserMapper;
import com.chen.server.service.AdminLoginService;
import com.chen.server.utils.JwtUtils;
import jakarta.annotation.Resource;

import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;

import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.util.HashMap;
import java.util.List;
import java.util.Objects;

@Service
@Slf4j
public class AdminLoginServiceImpl implements AdminLoginService {
    @Resource
    private StringRedisTemplate stringRedisTemplate;
    @Resource
    private AuthenticationManager authenticationManager;
    @Resource
    private UserMapper usermapper;
    @Resource
    private BCryptPasswordEncoder bCryptPasswordEncoder;
    @Override
    public ResponseResult login(User user) {
        UsernamePasswordAuthenticationToken usernamePasswordAuthenticationToken=new UsernamePasswordAuthenticationToken(user.getUsername(),user.getPassword());

        Authentication authentication;
        try {
            authentication = authenticationManager.authenticate(usernamePasswordAuthenticationToken);
        } catch (Exception e) {
            log.error("登录认证失败: {}", e.getMessage());
            return ResponseResult.errorResult(AppHttpCodeEnum.LOGIN_ERROR);
        }

        //获取userId
        LoginUser loginUser = (LoginUser) authentication.getPrincipal();
        String id = loginUser.getUser().getUserId().toString();
        String token = JwtUtils.createJWTByUserId(id);
        //存入Redis
        stringRedisTemplate.opsForValue().set("admin:login:"+id, JSONUtil.toJsonStr(loginUser));


        HashMap<String,String> map=new HashMap<>();
        map.put("token",token);
        map.put("user_id",id);
        map.put("username",loginUser.getUsername());
        return ResponseResult.okResult(map);
    }

    @Override
    public ResponseResult logout() {
        try {
            Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
            if (authentication != null && authentication.getPrincipal() instanceof LoginUser) {
                LoginUser loginUser = (LoginUser) authentication.getPrincipal();
                String userId = loginUser.getUser().getUserId().toString();
                stringRedisTemplate.delete("admin:login:" + userId);
            }
        } catch (Exception e) {
            // 记录日志但不影响返回
        }

        return ResponseResult.okResult();
    }

    @Override
    public ResponseResult getUserInfo() {
        return null;
    }

    @Override
    public ResponseResult getRouters() {
        return null;
    }

    @Override
    public ResponseResult register(User user) {
        if (!StringUtils.hasText(user.getUsername()) || !StringUtils.hasText(user.getPassword())) {
            return ResponseResult.errorResult(AppHttpCodeEnum.LOGIN_ERROR);
        }

        User u = usermapper.selectOne(new QueryWrapper<User>().eq("username", user.getUsername()));
        if (u != null) {
            return ResponseResult.errorResult(AppHttpCodeEnum.USERNAME_EXIST);
        }

        String rawPassword = user.getPassword();
        String encode = bCryptPasswordEncoder.encode(user.getPassword());
        user.setPassword(encode);
        usermapper.insert(user);

        User loginUser = usermapper.selectOne(new QueryWrapper<User>().eq("username", user.getUsername()));
        if (loginUser != null) {
            User loginRequest = new User();
            loginRequest.setUsername(loginUser.getUsername());
            loginRequest.setPassword(rawPassword);
            return login(loginRequest);
        }

        return ResponseResult.errorResult(AppHttpCodeEnum.SYSTEM_ERROR);
    }

}
