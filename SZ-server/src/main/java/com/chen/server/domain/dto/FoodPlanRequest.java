package com.chen.server.domain.dto;

@Data
public class FoodPlanRequest {
    private String date;
    private Long foodId;
    private String mealType;
    private String notes;

    public FoodPlanRequest() {
    }

    public FoodPlanRequest(String date, Long foodId, String mealType, String notes) {
        this.date = date;
        this.foodId = foodId;
        this.mealType = mealType;
        this.notes = notes;
    }
}