package com.chen.server.service;

import com.chen.server.domain.Vo.UserProfileResponse;
import com.chen.server.domain.dto.UserProfileRequest;

public interface UserProfileService {

    /**
     * 获取用户资料
     * 如果用户不存在，返回默认值或null
     */
    UserProfileResponse getUserProfile(Long userId);

    /**
     * 保存/更新用户资料
     * 如果用户已存在则更新，否则创建
     */
    UserProfileResponse saveUserProfile(Long userId, UserProfileRequest request);
}