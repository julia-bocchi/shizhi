package com.chen.server.service;

import com.chen.server.domain.ResponseResult;
import com.chen.server.domain.entity.User;

import org.springframework.stereotype.Service;

@Service
public interface AdminLoginService {
    ResponseResult login(User user);

    ResponseResult logout();

    ResponseResult getUserInfo();

    ResponseResult getRouters();
}
