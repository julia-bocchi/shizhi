package com.chen.server.domain.entity;

import lombok.Data;

@Data
public class FoodOption {
    private Long id;
    private Long userId;
    private String source;
    private String name;
    private String description;
    private Integer calories;
    private String serving;
    private String mealSuggestion;
    private String image;
    private String accentColor;

    public FoodOption() {
    }

    public FoodOption(Long id, Long userId, String source, String name, String description,
                      Integer calories, String serving, String mealSuggestion, 
                      String image, String accentColor) {
        this.id = id;
        this.userId = userId;
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