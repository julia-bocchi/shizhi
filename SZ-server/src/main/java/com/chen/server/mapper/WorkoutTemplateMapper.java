package com.chen.server.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.chen.server.domain.entity.WorkoutTemplate;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

@Mapper
public interface WorkoutTemplateMapper extends BaseMapper<WorkoutTemplate> {
    
    /**
     * 查询同一用户下是否存在相同名称的模板（排除指定ID）
     * 用于更新时检查名称唯一性
     */
    @Select("SELECT COUNT(*) FROM workout_template WHERE user_id = #{userId} AND name = #{name} AND id != #{excludeId}")
    int countByNameExcludingId(@Param("userId") Long userId, @Param("name") String name, @Param("excludeId") Long excludeId);
    
    /**
     * 查询同一用户下是否存在相同名称的模板
     * 用于新增时检查名称唯一性
     */
    @Select("SELECT COUNT(*) FROM workout_template WHERE user_id = #{userId} AND name = #{name}")
    int countByName(@Param("userId") Long userId, @Param("name") String name);
}