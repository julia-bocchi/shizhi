package com.chen.server.service;

import com.chen.server.domain.Vo.WorkoutPlanListResponse;
import com.chen.server.domain.Vo.WorkoutPlanResponse;
import com.chen.server.domain.dto.WorkoutPlanQueryRequest;
import com.chen.server.domain.dto.WorkoutPlanRequest;

public interface WorkoutPlanService {

    WorkoutPlanListResponse queryWorkoutPlans(Long userId, WorkoutPlanQueryRequest queryRequest);

    WorkoutPlanResponse createWorkoutPlan(Long userId, WorkoutPlanRequest request);

    Boolean deleteWorkoutPlan(Long userId, String planId);
}