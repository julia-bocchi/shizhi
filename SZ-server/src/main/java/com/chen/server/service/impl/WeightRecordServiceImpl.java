package com.chen.server.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.chen.server.domain.Vo.WeightListResponse;
import com.chen.server.domain.Vo.WeightRecordVO;
import com.chen.server.domain.Vo.WeightResponse;
import com.chen.server.domain.entity.WeightRecord;
import com.chen.server.mapper.WeightRecordMapper;
import com.chen.server.service.WeightRecordService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
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
}
