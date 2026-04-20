package com.chen.server.domain.dto;

import lombok.Data;

@Data
public class FoodOptionRequest {
    private String name;
    private String description;
    private Integer calories;
    private String serving;
    private String mealSuggestion;
    private String image;
    private String accentColor;

    public FoodOptionRequest() {
    }

    public FoodOptionRequest(String name, String description, Integer calories, 
                             String serving, String mealSuggestion, 
                             String image, String accentColor) {
        this.name = name;
        this.description = description;
        this.calories = calories;
        this.serving = serving;
        this.mealSuggestion = mealSuggestion;
        this.image = image;
        this.accentColor = accentColor;
    }
}