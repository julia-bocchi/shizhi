package com.chen.server.controller;

import com.chen.server.domain.ResponseResult;
import com.chen.server.domain.Vo.FoodPlanListResponse;
import com.chen.server.domain.Vo.FoodPlanResponse;
import com.chen.server.domain.dto.FoodPlanQueryRequest;
import com.chen.server.domain.dto.FoodPlanRequest;
import com.chen.server.domain.dto.FoodPlanUpdateRequest;
import com.chen.server.service.FoodPlanService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/food-plans")
public class FoodPlanController {

    @Autowired
    private FoodPlanService foodPlanService;

    @GetMapping
    public ResponseResult getFoodPlans(
            @RequestParam(required = false) String startDate,
            @RequestParam(required = false) String endDate) {
        Long userId = getCurrentUserId();
        
        FoodPlanQueryRequest queryRequest = new FoodPlanQueryRequest();
        queryRequest.setStartDate(startDate);
        queryRequest.setEndDate(endDate);
        
        FoodPlanListResponse response = foodPlanService.getFoodPlans(userId, queryRequest);
        
        return ResponseResult.okResult(response);
    }

    @PostMapping
    public ResponseResult createFoodPlan(@RequestBody FoodPlanRequest request) {
        Long userId = getCurrentUserId();
        
        FoodPlanResponse response = foodPlanService.createFoodPlan(userId, request);
        
        return ResponseResult.okResult(response);
    }

    @PutMapping("/{planId}")
    public ResponseResult updateFoodPlan(@PathVariable Long planId, @RequestBody FoodPlanUpdateRequest request) {
        Long userId = getCurrentUserId();
        
        FoodPlanResponse response = foodPlanService.updateFoodPlan(userId, planId, request);
        
        return ResponseResult.okResult(response);
    }

    @DeleteMapping("/{planId}")
    public ResponseResult deleteFoodPlan(@PathVariable Long planId) {
        Long userId = getCurrentUserId();
        
        foodPlanService.deleteFoodPlan(userId, planId);
        
        return ResponseResult.okResult();
    }

    private Long getCurrentUserId() {
        return 1L;
    }
}