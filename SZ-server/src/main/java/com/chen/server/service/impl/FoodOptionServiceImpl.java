package com.chen.server.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.chen.server.domain.Vo.FoodOptionListResponse;
import com.chen.server.domain.Vo.FoodOptionResponse;
import com.chen.server.domain.dto.FoodOptionRequest;
import com.chen.server.domain.dto.FoodQueryRequest;
import com.chen.server.domain.entity.FoodOption;
import com.chen.server.enums.AppHttpCodeEnum;
import com.chen.server.mapper.FoodOptionMapper;
import com.chen.server.service.FoodOptionService;
import org.springframework.beans.BeanUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class FoodOptionServiceImpl implements FoodOptionService {

    @Autowired
    private FoodOptionMapper foodOptionMapper;

    @Override
    public FoodOptionListResponse getFoodOptions(Long userId, FoodQueryRequest queryRequest) {
        LambdaQueryWrapper<FoodOption> queryWrapper = new LambdaQueryWrapper<>();
        
        boolean includePreset = queryRequest.getIncludePreset() != null && queryRequest.getIncludePreset();
        boolean includeCustom = queryRequest.getIncludeCustom() != null && queryRequest.getIncludeCustom();
        
        if (includePreset && includeCustom) {
            queryWrapper.and(wrapper -> 
                wrapper.eq(FoodOption::getSource, "preset")
                    .or()
                    .eq(FoodOption::getUserId, userId)
            );
        } else if (includePreset) {
            queryWrapper.eq(FoodOption::getSource, "preset");
        } else if (includeCustom) {
            queryWrapper.eq(FoodOption::getUserId, userId);
        } else {
            return new FoodOptionListResponse(new ArrayList<>());
        }
        
        queryWrapper.orderByAsc(FoodOption::getSource, FoodOption::getName);
        
        List<FoodOption> foodOptions = foodOptionMapper.selectList(queryWrapper);
        
        List<FoodOptionResponse> responseList = foodOptions.stream()
            .map(this::convertToResponse)
            .collect(Collectors.toList());
        
        return new FoodOptionListResponse(responseList);
    }

    @Override
    @Transactional
    public FoodOptionResponse createCustomFood(Long userId, FoodOptionRequest request) {
        FoodOption foodOption = new FoodOption();
        BeanUtils.copyProperties(request, foodOption);
        foodOption.setUserId(userId);
        foodOption.setSource("custom");
        
        foodOptionMapper.insert(foodOption);
        
        return convertToResponse(foodOption);
    }

    @Override
    @Transactional
    public FoodOptionResponse updateCustomFood(Long userId, Long foodId, FoodOptionRequest request) {
        FoodOption existingFood = foodOptionMapper.selectById(foodId);
        
        if (existingFood == null) {
            throw new RuntimeException(AppHttpCodeEnum.FOOD_NOT_FOUND.getMsg());
        }
        
        if (!"custom".equals(existingFood.getSource()) || !userId.equals(existingFood.getUserId())) {
            throw new RuntimeException(AppHttpCodeEnum.FOOD_PERMISSION_DENIED.getMsg());
        }
        
        BeanUtils.copyProperties(request, existingFood);
        existingFood.setUserId(userId);
        existingFood.setSource("custom");
        
        foodOptionMapper.updateById(existingFood);
        
        return convertToResponse(existingFood);
    }

    @Override
    @Transactional
    public void deleteCustomFood(Long userId, Long foodId) {
        FoodOption existingFood = foodOptionMapper.selectById(foodId);
        
        if (existingFood == null) {
            throw new RuntimeException(AppHttpCodeEnum.FOOD_NOT_FOUND.getMsg());
        }
        
        if (!"custom".equals(existingFood.getSource()) || !userId.equals(existingFood.getUserId())) {
            throw new RuntimeException(AppHttpCodeEnum.FOOD_PERMISSION_DENIED.getMsg());
        }
        
        foodOptionMapper.deleteById(foodId);
    }

    private FoodOptionResponse convertToResponse(FoodOption foodOption) {
        FoodOptionResponse response = new FoodOptionResponse();
        BeanUtils.copyProperties(foodOption, response);
        return response;
    }
}