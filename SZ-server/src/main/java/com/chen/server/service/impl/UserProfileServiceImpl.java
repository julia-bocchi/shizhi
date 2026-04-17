package com.chen.server.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.chen.server.domain.Vo.UserProfileResponse;
import com.chen.server.domain.dto.UserProfileRequest;
import com.chen.server.domain.entity.UserProfile;
import com.chen.server.mapper.UserProfileMapper;
import com.chen.server.service.UserProfileService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

@Service
public class UserProfileServiceImpl implements UserProfileService {

    @Autowired
    private UserProfileMapper userProfileMapper;

    @Override
    public UserProfileResponse getUserProfile(Long userId) {
        // 查询用户资料
        UserProfile profile = userProfileMapper.selectByUserId(userId);

        // 如果用户资料不存在，返回默认空对象
        // 前端可以根据需要显示占位符或引导用户填写
        if (profile == null) {
            return new UserProfileResponse();
        }

        return convertToResponse(profile);
    }

    @Override
    public UserProfileResponse saveUserProfile(Long userId, UserProfileRequest request) {
        // 查询是否已存在用户资料
        UserProfile existingProfile = userProfileMapper.selectByUserId(userId);

        UserProfile profile;
        if (existingProfile != null) {
            // 更新现有资料
            profile = existingProfile;
        } else {
            // 创建新资料
            profile = new UserProfile();
            profile.setUserId(userId);
        }

        // 设置字段值（允许为空，前端可能只更新部分字段）
        // 如果前端传入null或空字符串，保持原值不变
        if (StringUtils.hasText(request.getNickname())) {
            profile.setNickname(request.getNickname());
        }
        
        if (StringUtils.hasText(request.getHeightCm())) {
            // 可选：验证身高范围（如50-250cm）
            validateNumericField(request.getHeightCm(), "身高", 50, 250);
            profile.setHeightCm(request.getHeightCm());
        }
        
        if (StringUtils.hasText(request.getWeightKg())) {
            // 可选：验证体重范围（如20-300kg）
            // 体重是热量估算的关键字段，建议必填
            validateNumericField(request.getWeightKg(), "体重", 20, 300);
            profile.setWeightKg(request.getWeightKg());
        }
        
        if (StringUtils.hasText(request.getAge())) {
            // 可选：验证年龄范围（如10-120岁）
            validateNumericField(request.getAge(), "年龄", 10, 120);
            profile.setAge(request.getAge());
        }
        
        if (StringUtils.hasText(request.getGender())) {
            // 验证性别值：只能是"男"或"女"
            if (!"男".equals(request.getGender()) && !"女".equals(request.getGender())) {
                throw new IllegalArgumentException("性别只能为'男'或'女'");
            }
            profile.setGender(request.getGender());
        }

        // 保存或更新
        if (existingProfile != null) {
            userProfileMapper.updateById(profile);
        } else {
            userProfileMapper.insert(profile);
        }

        return convertToResponse(profile);
    }

    /**
     * 将实体转换为响应VO
     */
    private UserProfileResponse convertToResponse(UserProfile profile) {
        return new UserProfileResponse(
                profile.getNickname(),
                profile.getHeightCm(),
                profile.getWeightKg(),
                profile.getAge(),
                profile.getGender()
        );
    }

    /**
     * 验证数值字段是否在合理范围内
     * 
     * @param value 字符串数值
     * @param fieldName 字段名称（用于错误提示）
     * @param min 最小值
     * @param max 最大值
     */
    private void validateNumericField(String value, String fieldName, double min, double max) {
        try {
            double numValue = Double.parseDouble(value);
            if (numValue < min || numValue > max) {
                throw new IllegalArgumentException(
                    String.format("%s超出合理范围（%.0f-%.0f）", fieldName, min, max)
                );
            }
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException(fieldName + "格式不正确");
        }
    }
}