package com.chen.server.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.chen.server.domain.entity.FoodPlan;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface FoodPlanMapper extends BaseMapper<FoodPlan> {
}