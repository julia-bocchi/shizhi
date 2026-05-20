package com.chen.server.controller;

import com.chen.server.domain.ResponseResult;
import com.chen.server.domain.Vo.WorkoutPlanListResponse;
import com.chen.server.domain.Vo.WorkoutPlanResponse;
import com.chen.server.domain.dto.WorkoutPlanQueryRequest;
import com.chen.server.domain.dto.WorkoutPlanRequest;
import com.chen.server.service.WorkoutPlanService;
import com.chen.server.utils.SecurityUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;

@RestController
@RequestMapping("/api/v1/workout-plans")
public class WorkoutPlanController {

    @Autowired
    private WorkoutPlanService workoutPlanService;

    @GetMapping
    public ResponseResult queryWorkoutPlans(
            @RequestParam(required = false) @DateTimeFormat(pattern = "yyyy-MM-dd") LocalDate startDate,
            @RequestParam(required = false) @DateTimeFormat(pattern = "yyyy-MM-dd") LocalDate endDate) {
        Long userId = getCurrentUserId();

        WorkoutPlanQueryRequest queryRequest = new WorkoutPlanQueryRequest();
        if (startDate != null) {
            queryRequest.setStartDate(startDate.toString());
        }
        if (endDate != null) {
            queryRequest.setEndDate(endDate.toString());
        }

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
        return SecurityUtils.getUserId();
    }
}