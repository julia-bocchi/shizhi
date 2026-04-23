package com.chen.server.service;

import com.chen.server.domain.Vo.WeightListResponse;
import com.chen.server.domain.Vo.WeightResponse;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDate;
@Service
public interface WeightRecordService  {


    WeightResponse saveOrUpdateWeight(Long userId, LocalDate date, BigDecimal weight);

    WeightListResponse getWeightList(Long userId, LocalDate startDate, LocalDate endDate);
}
