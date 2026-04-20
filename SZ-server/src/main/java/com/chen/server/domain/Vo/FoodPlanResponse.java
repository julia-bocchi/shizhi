package com.chen.server.domain.Vo;

import lombok.Data;

@Data
public class FoodPlanResponse {
    private Long id;
    private String date;
    private Long foodId;
    private String name;
    private String description;
    private Integer calories;
    private String serving;
    private String mealType;
    private String image;
    private String notes;
    private String accentColor;

    public FoodPlanResponse() {
    }

    public FoodPlanResponse(Long id, String date, Long foodId, String name,
                            String description, Integer calories, String serving,
                            String mealType, String image, String notes, String accentColor) {
        this.id = id;
        this.date = date;
        this.foodId = foodId;
        this.name = name;
        this.description = description;
        this.calories = calories;
        this.serving = serving;
        this.mealType = mealType;
        this.image = image;
        this.notes = notes;
        this.accentColor = accentColor;
    }
}