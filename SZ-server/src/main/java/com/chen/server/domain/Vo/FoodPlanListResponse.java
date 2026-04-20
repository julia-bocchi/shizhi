package com.chen.server.domain.Vo;

import lombok.Data;

import java.util.List;

@Data
public class FoodPlanListResponse {
    private List<FoodPlanResponse> plans;

    public FoodPlanListResponse() {
    }

    public FoodPlanListResponse(List<FoodPlanResponse> plans) {
        this.plans = plans;
    }
}