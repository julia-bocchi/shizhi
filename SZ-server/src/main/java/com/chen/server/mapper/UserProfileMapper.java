package com.chen.server.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.chen.server.domain.entity.UserProfile;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

@Mapper
public interface UserProfileMapper extends BaseMapper<UserProfile> {
    
    /**
     * 根据userId查询用户资料
     */
    @Select("SELECT * FROM user_profile WHERE user_id = #{userId}")
    UserProfile selectByUserId(@Param("userId") Long userId);
}