package com.chen.server.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.chen.server.domain.Vo.FoodPlanListResponse;
import com.chen.server.domain.Vo.FoodPlanResponse;
import com.chen.server.domain.dto.FoodPlanQueryRequest;
import com.chen.server.domain.dto.FoodPlanRequest;
import com.chen.server.domain.dto.FoodPlanUpdateRequest;
import com.chen.server.domain.entity.FoodOption;
import com.chen.server.domain.entity.FoodPlan;
import com.chen.server.enums.AppHttpCodeEnum;
import com.chen.server.mapper.FoodOptionMapper;
import com.chen.server.mapper.FoodPlanMapper;
import com.chen.server.service.FoodPlanService;
import org.springframework.beans.BeanUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
public class FoodPlanServiceImpl implements FoodPlanService {

    @Autowired
    private FoodPlanMapper foodPlanMapper;

    @Autowired
    private FoodOptionMapper foodOptionMapper;

    @Override
    public FoodPlanListResponse getFoodPlans(Long userId, FoodPlanQueryRequest queryRequest) {
        LambdaQueryWrapper<FoodPlan> queryWrapper = new LambdaQueryWrapper<>();
        queryWrapper.eq(FoodPlan::getUserId, userId);
        
        if (queryRequest.getStartDate() != null && !queryRequest.getStartDate().isEmpty()) {
            queryWrapper.ge(FoodPlan::getDate, queryRequest.getStartDate());
        }
        
        if (queryRequest.getEndDate() != null && !queryRequest.getEndDate().isEmpty()) {
            queryWrapper.le(FoodPlan::getDate, queryRequest.getEndDate());
        }
        
        queryWrapper.orderByAsc(FoodPlan::getDate, FoodPlan::getMealType);
        
        List<FoodPlan> foodPlans = foodPlanMapper.selectList(queryWrapper);
        
        List<FoodPlanResponse> responseList = foodPlans.stream()
            .map(this::convertToResponse)
            .collect(Collectors.toList());
        
        return new FoodPlanListResponse(responseList);
    }

    @Override
    @Transactional
    public FoodPlanResponse createFoodPlan(Long userId, FoodPlanRequest request) {
        FoodOption foodOption = foodOptionMapper.selectById(request.getFoodId());
        
        if (foodOption == null) {
            throw new RuntimeException(AppHttpCodeEnum.FOOD_NOT_FOUND.getMsg());
        }
        
        FoodPlan foodPlan = new FoodPlan();
        foodPlan.setUserId(userId);
        foodPlan.setDate(request.getDate());
        foodPlan.setFoodId(request.getFoodId());
        foodPlan.setName(foodOption.getName());
        foodPlan.setDescription(foodOption.getDescription());
        foodPlan.setCalories(foodOption.getCalories());
        foodPlan.setServing(foodOption.getServing());
        foodPlan.setMealType(request.getMealType());
        foodPlan.setImage(foodOption.getImage());
        foodPlan.setNotes(request.getNotes());
        foodPlan.setAccentColor(foodOption.getAccentColor());
        
        foodPlanMapper.insert(foodPlan);
        
        return convertToResponse(foodPlan);
    }

    @Override
    @Transactional
    public FoodPlanResponse updateFoodPlan(Long userId, Long planId, FoodPlanUpdateRequest request) {
        FoodPlan existingPlan = foodPlanMapper.selectById(planId);
        
        if (existingPlan == null) {
            throw new RuntimeException(AppHttpCodeEnum.FOOD_PLAN_NOT_FOUND.getMsg());
        }
        
        if (!userId.equals(existingPlan.getUserId())) {
            throw new RuntimeException(AppHttpCodeEnum.FOOD_PERMISSION_DENIED.getMsg());
        }
        
        if (request.getMealType() != null) {
            existingPlan.setMealType(request.getMealType());
        }
        
        if (request.getNotes() != null) {
            existingPlan.setNotes(request.getNotes());
        }
        
        foodPlanMapper.updateById(existingPlan);
        
        return convertToResponse(existingPlan);
    }

    @Override
    @Transactional
    public void deleteFoodPlan(Long userId, Long planId) {
        FoodPlan existingPlan = foodPlanMapper.selectById(planId);
        
        if (existingPlan == null) {
            throw new RuntimeException(AppHttpCodeEnum.FOOD_PLAN_NOT_FOUND.getMsg());
        }
        
        if (!userId.equals(existingPlan.getUserId())) {
            throw new RuntimeException(AppHttpCodeEnum.FOOD_PERMISSION_DENIED.getMsg());
        }
        
        foodPlanMapper.deleteById(planId);
    }

    private FoodPlanResponse convertToResponse(FoodPlan foodPlan) {
        FoodPlanResponse response = new FoodPlanResponse();
        BeanUtils.copyProperties(foodPlan, response);
        return response;
    }
}