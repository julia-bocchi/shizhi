package com.chen.server.service;

import com.chen.server.domain.Vo.FoodPlanListResponse;
import com.chen.server.domain.Vo.FoodPlanResponse;
import com.chen.server.domain.dto.FoodPlanQueryRequest;
import com.chen.server.domain.dto.FoodPlanRequest;
import com.chen.server.domain.dto.FoodPlanUpdateRequest;
import org.springframework.stereotype.Service;

@Service
public interface FoodPlanService {
    
    FoodPlanListResponse getFoodPlans(Long userId, FoodPlanQueryRequest queryRequest);
    
    FoodPlanResponse createFoodPlan(Long userId, FoodPlanRequest request);
    
    FoodPlanResponse updateFoodPlan(Long userId, Long planId, FoodPlanUpdateRequest request);
    
    void deleteFoodPlan(Long userId, Long planId);
}