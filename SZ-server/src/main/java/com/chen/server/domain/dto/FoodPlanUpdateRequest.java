package com.chen.server.domain.dto;

import lombok.Data;

@Data
public class FoodPlanUpdateRequest {
    private String mealType;
    private String notes;

    public FoodPlanUpdateRequest() {
    }

    public FoodPlanUpdateRequest(String mealType, String notes) {
        this.mealType = mealType;
        this.notes = notes;
    }
}