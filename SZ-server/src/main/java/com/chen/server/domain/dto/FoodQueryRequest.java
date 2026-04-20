package com.chen.server.domain.dto;

import lombok.Data;

@Data
public class FoodQueryRequest {
    private Boolean includePreset;
    private Boolean includeCustom;

    public FoodQueryRequest() {
    }

    public FoodQueryRequest(Boolean includePreset, Boolean includeCustom) {
        this.includePreset = includePreset;
        this.includeCustom = includeCustom;
    }
}