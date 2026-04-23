package com.chen.server.service;

import com.chen.server.domain.Vo.FoodOptionListResponse;
import com.chen.server.domain.Vo.FoodOptionResponse;
import com.chen.server.domain.dto.FoodOptionRequest;
import com.chen.server.domain.dto.FoodQueryRequest;
import org.springframework.stereotype.Service;

@Service
public interface FoodOptionService {
    
    FoodOptionListResponse getFoodOptions(Long userId, FoodQueryRequest queryRequest);
    
    FoodOptionResponse createCustomFood(Long userId, FoodOptionRequest request);
    
    FoodOptionResponse updateCustomFood(Long userId, Long foodId, FoodOptionRequest request);
    
    void deleteCustomFood(Long userId, Long foodId);
}