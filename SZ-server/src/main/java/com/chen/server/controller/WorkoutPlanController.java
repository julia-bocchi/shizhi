package com.chen.server.controller;

import com.chen.server.domain.ResponseResult;
import com.chen.server.domain.Vo.WorkoutPlanListResponse;
import com.chen.server.domain.Vo.WorkoutPlanResponse;
import com.chen.server.domain.dto.WorkoutPlanQueryRequest;
import com.chen.server.domain.dto.WorkoutPlanRequest;
import com.chen.server.service.WorkoutPlanService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/workout-plans")
public class WorkoutPlanController {

    @Autowired
    private WorkoutPlanService workoutPlanService;

    @GetMapping
    public ResponseResult queryWorkoutPlans(WorkoutPlanQueryRequest queryRequest) {
        Long userId = getCurrentUserId();
        WorkoutPlanListResponse response = workoutPlanService.queryWorkoutPlans(userId, queryRequest);
        return ResponseResult.okResult(response);
    }

    @PostMapping
    public ResponseResult createWorkoutPlan(@RequestBody WorkoutPlanRequest request) {
        Long userId = getCurrentUserId();
        WorkoutPlanResponse response = workoutPlanService.createWorkoutPlan(userId, request);
        return ResponseResult.okResult(response);
    }

    @DeleteMapping("/{planId}")
    public ResponseResult deleteWorkoutPlan(@PathVariable String planId) {
        Long userId = getCurrentUserId();
        Boolean result = workoutPlanService.deleteWorkoutPlan(userId, planId);
        return ResponseResult.okResult(result);
    }

    private Long getCurrentUserId() {
        return 1L;
    }
}