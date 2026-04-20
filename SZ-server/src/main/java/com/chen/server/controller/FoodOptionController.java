package com.chen.server.controller;

import com.chen.server.domain.ResponseResult;
import com.chen.server.domain.Vo.FoodOptionListResponse;
import com.chen.server.domain.Vo.FoodOptionResponse;
import com.chen.server.domain.dto.FoodOptionRequest;
import com.chen.server.domain.dto.FoodQueryRequest;
import com.chen.server.service.FoodOptionService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/food-options")
public class FoodOptionController {

    @Autowired
    private FoodOptionService foodOptionService;

    @GetMapping
    public ResponseResult getFoodOptions(
            @RequestParam(required = false, defaultValue = "true") Boolean includePreset,
            @RequestParam(required = false, defaultValue = "true") Boolean includeCustom) {
        Long userId = getCurrentUserId();
        
        FoodQueryRequest queryRequest = new FoodQueryRequest();
        queryRequest.setIncludePreset(includePreset);
        queryRequest.setIncludeCustom(includeCustom);
        
        FoodOptionListResponse response = foodOptionService.getFoodOptions(userId, queryRequest);
        
        return ResponseResult.okResult(response);
    }

    @PostMapping("/custom")
    public ResponseResult createCustomFood(@RequestBody FoodOptionRequest request) {
        Long userId = getCurrentUserId();
        
        FoodOptionResponse response = foodOptionService.createCustomFood(userId, request);
        
        return ResponseResult.okResult(response);
    }

    @PutMapping("/custom/{foodId}")
    public ResponseResult updateCustomFood(@PathVariable Long foodId, @RequestBody FoodOptionRequest request) {
        Long userId = getCurrentUserId();
        
        FoodOptionResponse response = foodOptionService.updateCustomFood(userId, foodId, request);
        
        return ResponseResult.okResult(response);
    }

    @DeleteMapping("/custom/{foodId}")
    public ResponseResult deleteCustomFood(@PathVariable Long foodId) {
        Long userId = getCurrentUserId();
        
        foodOptionService.deleteCustomFood(userId, foodId);
        
        return ResponseResult.okResult();
    }

    private Long getCurrentUserId() {
        return 1L;
    }
}