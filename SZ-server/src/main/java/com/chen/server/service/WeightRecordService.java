package com.chen.server.service;

import com.chen.server.domain.Vo.WeightListResponse;
import com.chen.server.domain.Vo.WeightResponse;

import java.math.BigDecimal;
import java.time.LocalDate;

public interface WeightRecordService  {


    WeightResponse saveOrUpdateWeight(Long userId, LocalDate date, BigDecimal weight);

    WeightListResponse getWeightList(Long userId, LocalDate startDate, LocalDate endDate);
}
