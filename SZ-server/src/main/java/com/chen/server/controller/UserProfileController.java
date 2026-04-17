package com.chen.server.controller;

import com.chen.server.domain.ResponseResult;
import com.chen.server.domain.Vo.UserProfileResponse;
import com.chen.server.domain.dto.UserProfileRequest;
import com.chen.server.service.UserProfileService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/user-profile")
public class UserProfileController {

    @Autowired
    private UserProfileService userProfileService;

    /**
     * 获取用户资料
     * GET /api/v1/user-profile
     * 
     * 说明：
     * - 首次使用时可能返回空对象，前端应引导用户填写
     * - BMI计算和建议文案依赖这些基础数据
     */
    @GetMapping
    public ResponseResult getUserProfile() {
        Long userId = getCurrentUserId();
        UserProfileResponse response = userProfileService.getUserProfile(userId);
        return ResponseResult.okResult(response);
    }

    /**
     * 保存/更新用户资料
     * PUT /api/v1/user-profile
     * 
     * 说明：
     * - 支持部分字段更新（只传需要更新的字段）
     * - weightKg是训练热量估算的必要字段，建议必填
     * - 所有字段使用字符串类型，降低前端联调成本
     * - 后端会进行基本的范围和格式校验
     */
    @PutMapping
    public ResponseResult saveUserProfile(@RequestBody UserProfileRequest request) {
        Long userId = getCurrentUserId();
        
        try {
            UserProfileResponse response = userProfileService.saveUserProfile(userId, request);
            return ResponseResult.okResult(response);
        } catch (IllegalArgumentException e) {
            // 参数校验失败，返回400错误
            return ResponseResult.errorResult(400, e.getMessage());
        }
    }

    private Long getCurrentUserId() {
        return 1L;
    }
}