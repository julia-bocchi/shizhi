package com.chen.server.service.impl;


import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.chen.server.domain.entity.LoginUser;
import com.chen.server.domain.entity.User;
import com.chen.server.mapper.UserMapper;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

@Service
public class UserDetailServiceImpl implements UserDetailsService {
    @Autowired
    private UserMapper usermapper;
    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {

        //查询用户信息
        User user = usermapper.selectOne(new QueryWrapper<User>().eq("username",username));

        //查询为空
        if(Objects.isNull(user)){
            throw new RuntimeException("用户名/密码错误,用户名不存在");
        }

        return new LoginUser(user);
    }
}
