package com.chen.server.domain.dto;

import lombok.Data;

@Data
public class FoodPlanQueryRequest {
    private String startDate;
    private String endDate;

    public FoodPlanQueryRequest() {
    }

    public FoodPlanQueryRequest(String startDate, String endDate) {
        this.startDate = startDate;
        this.endDate = endDate;
    }
}