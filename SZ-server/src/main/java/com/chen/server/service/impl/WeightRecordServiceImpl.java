package com.chen.server.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.chen.server.domain.Vo.WeightListResponse;
import com.chen.server.domain.Vo.WeightRecordVO;
import com.chen.server.domain.Vo.WeightResponse;
import com.chen.server.domain.Vo.WeightSummaryResponse;
import com.chen.server.domain.entity.WeightRecord;
import com.chen.server.mapper.WeightRecordMapper;
import com.chen.server.service.WeightRecordService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.List;
import java.util.stream.Collectors;
@Service
public class WeightRecordServiceImpl implements WeightRecordService {
    @Autowired
    private WeightRecordMapper weightRecordMapper;

    @Override
    public WeightResponse saveOrUpdateWeight(Long userId, LocalDate date, BigDecimal weight) {
        WeightRecord existingRecord = weightRecordMapper.selectOne(new QueryWrapper<WeightRecord>().eq("user_id", userId).eq("date", date));

        boolean isUpdated;
        WeightRecord record;

        if (existingRecord != null) {
            existingRecord.setWeight(weight);

            int i = weightRecordMapper.updateById(existingRecord);
            if (i > 0){
                isUpdated = true;
            }else {
                isUpdated = false;
            }
            record = existingRecord;
        } else {
            record = new WeightRecord();
            record.setUserId(userId);
            record.setDate(date);
            record.setWeight(weight);
            weightRecordMapper.insert(record);
            isUpdated = false;
        }

        WeightResponse response = new WeightResponse();
        response.setId(record.getId());
        response.setDate(record.getDate());
        response.setWeight(record.getWeight());
        response.setIsUpdated(isUpdated);

        return response;
    }

    @Override
    public WeightListResponse getWeightList(Long userId, LocalDate startDate, LocalDate endDate) {
        QueryWrapper<WeightRecord> queryWrapper = new QueryWrapper<>();
        queryWrapper.eq("user_id", userId);

        if (startDate != null) {
            queryWrapper.ge("date", startDate);
        }

        if (endDate != null) {
            queryWrapper.le("date", endDate);
        }

        queryWrapper.orderByAsc("date");

        List<WeightRecord> records = weightRecordMapper.selectList(queryWrapper);

        List<WeightRecordVO> voList = records.stream()
                .map(record -> new WeightRecordVO(record.getId(), record.getDate(), record.getWeight()))
                .collect(Collectors.toList());

        WeightListResponse response = new WeightListResponse();
        response.setRecords(voList);

        return response;

    }


    @Override
    public WeightSummaryResponse getWeightSummary(Long userId, Integer recentDays) {
        if (recentDays == null || recentDays <= 0) {
            recentDays = 7;
        }

        LocalDate endDate = LocalDate.now();
        LocalDate startDate = endDate.minusDays(recentDays - 1);

        QueryWrapper<WeightRecord> queryWrapper = new QueryWrapper<>();
        queryWrapper.eq("user_id", userId)
                .ge("date", startDate)
                .le("date", endDate)
                .orderByDesc("date");

        List<WeightRecord> recentRecords = weightRecordMapper.selectList(queryWrapper);

        WeightSummaryResponse summary = new WeightSummaryResponse();

        if (recentRecords.isEmpty()) {
            summary.setRecentCount(0);
            summary.setAverageWeight(BigDecimal.ZERO);
            summary.setChangeInRange(BigDecimal.ZERO);
            summary.setChangeFromPrevious(BigDecimal.ZERO);
            return summary;
        }

        int recordCount = recentRecords.size();
        summary.setRecentCount(recordCount);

        WeightRecord latestRecord = recentRecords.get(0);
        summary.setLatestRecord(new WeightSummaryResponse.WeightRecordInfo(
                latestRecord.getId(),
                latestRecord.getDate(),
                latestRecord.getWeight()
        ));

        if (recordCount > 1) {
            WeightRecord previousRecord = recentRecords.get(1);
            summary.setPreviousRecord(new WeightSummaryResponse.WeightRecordInfo(
                    previousRecord.getId(),
                    previousRecord.getDate(),
                    previousRecord.getWeight()
            ));

            BigDecimal changeFromPrevious = latestRecord.getWeight().subtract(previousRecord.getWeight());
            summary.setChangeFromPrevious(changeFromPrevious.setScale(1, RoundingMode.HALF_UP));
        }

        WeightRecord oldestRecord = recentRecords.get(recordCount - 1);
        BigDecimal changeInRange = latestRecord.getWeight().subtract(oldestRecord.getWeight());
        summary.setChangeInRange(changeInRange.setScale(1, RoundingMode.HALF_UP));

        BigDecimal totalWeight = recentRecords.stream()
                .map(WeightRecord::getWeight)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal averageWeight = totalWeight.divide(
                new BigDecimal(recordCount),
                1,
                RoundingMode.HALF_UP
        );
        summary.setAverageWeight(averageWeight);

        return summary;
    }
}
