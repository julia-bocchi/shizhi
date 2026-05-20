package com.chen.server.controller;

import com.chen.server.domain.ResponseResult;
import com.chen.server.domain.Vo.WeightListResponse;
import com.chen.server.domain.Vo.WeightResponse;
import com.chen.server.domain.Vo.WeightSummaryResponse;
import com.chen.server.domain.dto.WeightRequest;
import com.chen.server.service.WeightRecordService;
import com.chen.server.utils.SecurityUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;

@RestController
@RequestMapping("/api/v1/weight-records")
public class WeightController {


    @Autowired
    private WeightRecordService weightRecordService;

    @PutMapping("/{date}")
    public ResponseResult saveOrUpdateWeight(
            @PathVariable @DateTimeFormat(pattern = "yyyy-MM-dd") LocalDate date,
             @RequestBody WeightRequest request) {

        Long userId = getCurrentUserId();

        WeightResponse response = weightRecordService.saveOrUpdateWeight(userId, date, request.getWeight());

        return ResponseResult.okResult(response);
    }

    private Long getCurrentUserId() {
        return SecurityUtils.getUserId();
    }


    @GetMapping
    public ResponseResult getWeightList(
            @RequestParam(required = false) @DateTimeFormat(pattern = "yyyy-MM-dd") LocalDate startDate,
            @RequestParam(required = false) @DateTimeFormat(pattern = "yyyy-MM-dd") LocalDate endDate) {

        Long  userId = getCurrentUserId();


        WeightListResponse response = weightRecordService.getWeightList(userId, startDate, endDate);

        return ResponseResult.okResult(response);
    }


    @GetMapping("/summary")
    public ResponseResult getWeightSummary(
            @RequestParam(required = false, defaultValue = "7") Integer recentDays) {

        Long userId = getCurrentUserId();

        WeightSummaryResponse response = weightRecordService.getWeightSummary(userId, recentDays);

        return ResponseResult.okResult(response);
    }
}
