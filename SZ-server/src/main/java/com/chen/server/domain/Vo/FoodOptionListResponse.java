package com.chen.server.domain.Vo;

import lombok.Data;

import java.util.List;

@Data
public class FoodOptionListResponse {
    private List<FoodOptionResponse> items;

    public FoodOptionListResponse() {
    }

    public FoodOptionListResponse(List<FoodOptionResponse> items) {
        this.items = items;
    }
}