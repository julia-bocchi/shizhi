package com.chen.server.domain.dto;

import lombok.Data;

@Data
public class WorkoutPlanQueryRequest {
    private String startDate;
    private String endDate;

    public WorkoutPlanQueryRequest() {
    }

    public WorkoutPlanQueryRequest(String startDate, String endDate) {
        this.startDate = startDate;
        this.endDate = endDate;
    }
}