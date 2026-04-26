package com.chen.server.controller;

import com.chen.server.domain.ResponseResult;
import com.chen.server.domain.entity.User;
import com.chen.server.enums.AppHttpCodeEnum;
import com.chen.server.service.AdminLoginService;
import jakarta.annotation.Resource;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@RestController

public class AdminUserController {
    @Resource
    private StringRedisTemplate stringRedisTemplate;
    @Resource
    private AdminLoginService adminLoginService;
    @PostMapping("/user/login")
    public ResponseResult login(@RequestBody User user) {
//        if (!StringUtils.hasText(user.getUserName())){
//            throw  new SystemException(AppHttpCodeEnum.REQUIRE_USERNAME);
//        }
        return  adminLoginService.login(user);
    }
    @GetMapping("/getInfo")
    public ResponseResult getUserInfo() {
        return adminLoginService.getUserInfo();
    }
    @GetMapping("/getRouters")
    public ResponseResult getRouters() {
        return  adminLoginService.getRouters();
    }
    @PostMapping("/user/logout")
    public ResponseResult logout() {
       return adminLoginService.logout();
    }
}
