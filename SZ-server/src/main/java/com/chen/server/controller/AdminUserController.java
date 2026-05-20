package com.chen.server.controller;

import com.chen.server.domain.ResponseResult;
import com.chen.server.domain.entity.User;
import com.chen.server.enums.AppHttpCodeEnum;
import com.chen.server.execption.SystemException;
import com.chen.server.service.AdminLoginService;
import jakarta.annotation.Resource;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1")
public class AdminUserController {
    @Resource
    private StringRedisTemplate stringRedisTemplate;
    @Resource
    private AdminLoginService adminLoginService;

    @PostMapping("/auth/login")
    public ResponseResult login(@RequestBody User user) {
        if (!StringUtils.hasText(user.getUsername())){
            throw  new SystemException(AppHttpCodeEnum.REQUIRE_USERNAME);
        }
        return  adminLoginService.login(user);
    }
    @PostMapping("/auth/register")
    public  ResponseResult register(@RequestBody User user){
        if (!StringUtils.hasText(user.getUsername())){
            throw  new SystemException(AppHttpCodeEnum.REQUIRE_USERNAME);
        }
        return  adminLoginService.register(user);

    }
    @PostMapping("/auth/logout")
    public ResponseResult logout() {
       return adminLoginService.logout();
    }
}
