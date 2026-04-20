package com.chen.server.domain.Vo;

import lombok.Data;

@Data
public class FoodOptionResponse {
    private Long id;
    private String source;
    private String name;
    private String description;
    private Integer calories;
    private String serving;
    private String mealSuggestion;
    private String image;
    private String accentColor;

    public FoodOptionResponse() {
    }

    public FoodOptionResponse(Long id, String source, String name, String description,
                              Integer calories, String serving, String mealSuggestion,
                              String image, String accentColor) {
        this.id = id;
        this.source = source;
        this.name = name;
        this.description = description;
        this.calories = calories;
        this.serving = serving;
        this.mealSuggestion = mealSuggestion;
        this.image = image;
        this.accentColor = accentColor;
    }
}