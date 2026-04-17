package com.chen.server.domain.Vo;

import lombok.Data;

import java.util.List;

@Data
public class WorkoutPlanListResponse {
    private List<WorkoutPlanResponse> plans;

    public WorkoutPlanListResponse() {
    }

    public WorkoutPlanListResponse(List<WorkoutPlanResponse> plans) {
        this.plans = plans;
    }
}