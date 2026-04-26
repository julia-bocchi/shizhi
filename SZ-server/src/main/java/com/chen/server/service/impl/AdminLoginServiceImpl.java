package com.chen.server.service.impl;

import cn.hutool.json.JSONUtil;
import com.chen.server.domain.ResponseResult;
import com.chen.server.domain.entity.User;
import com.chen.server.service.AdminLoginService;
import jakarta.annotation.Resource;

import org.springframework.data.redis.core.StringRedisTemplate;

import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.List;
import java.util.Objects;

@Service
public class AdminLoginServiceImpl implements AdminLoginService {
    @Resource
    private StringRedisTemplate stringRedisTemplate;
//    @Resource
//    private AuthenticationManager authenticationManager;
//    @Resource
//    private Usermapper usermapper;
    @Override
    public ResponseResult login(User user) {
//        UsernamePasswordAuthenticationToken usernamePasswordAuthenticationToken=new UsernamePasswordAuthenticationToken(user.getUserName(),user.getPassword());
//        Authentication authentication=authenticationManager.authenticate(usernamePasswordAuthenticationToken);
//        //判断是否认证通过
//        if(Objects.isNull(authentication)){
//
//            throw  new RuntimeException("用户名/密码错误");
//        }
//        //获取userId
//        LoginUser loginUser = (LoginUser) authentication.getPrincipal();
//        String id = loginUser.getUser().getId().toString();
//        String token = JwtUtils.createJWTByUserId(id);
        //存入Redis
//        stringRedisTemplate.opsForValue().set("adminlogin:"+id, JSONUtil.toJsonStr(loginUser));
//
//
//        HashMap<String,String> map=new HashMap<>();
//        map.put("token",token);

//        return ResponseResult.okResult(map);
        return  ResponseResult.okResult();
    }

    @Override
    public ResponseResult logout() {
        //获取当前登录user的Id
//        Long userId = SecurityUtils.getUserId();
        //删除redis中的zhi
//        stringRedisTemplate.delete("adminlogin"+userId);


        return ResponseResult.okResult();
    }

    @Override
    public ResponseResult getUserInfo() {
//        LoginUser loginUser = SecurityUtils.getLoginUser();
//        //获取当前用户ID
//        Long id = loginUser.getUser().getId();
//        //根据用户ID查询权限信息
//        List<String> perms =menuService.selectPermsKeyById(id);
//        //根据用户ID查询角色
//        Role role = roleService.selectRoleKeyById(id);
//        User user = loginUser.getUser();
//        UserInfoVo userInfovo = BeanCopyUtils.copyBean(user, UserInfoVo.class);
//        //封装数据返回
//        AdminUserInfoVo adminUserInfoVo =new AdminUserInfoVo();
//        adminUserInfoVo.setUser(userInfovo);
//        adminUserInfoVo.setPermissions(perms);
//        adminUserInfoVo.setRoles(role.getRoleKey());
//        return ResponseResult.okResult(adminUserInfoVo);
        return ResponseResult.okResult();
    }

    @Override
    public ResponseResult getRouters() {
//        LoginUser loginUser = SecurityUtils.getLoginUser();
//        //获取当前用户ID
//        Long id = loginUser.getUser().getId();
//        List<Menu> menus=menuService.selectRouterMenuTreeById(id);
//
//        return ResponseResult.okResult(new RoutersVo(menus));
        return ResponseResult.okResult();
    }
}
