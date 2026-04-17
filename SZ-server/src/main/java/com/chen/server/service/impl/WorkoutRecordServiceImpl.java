package com.chen.server.service.impl;


import cn.hutool.json.JSONUtil;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.chen.server.domain.Vo.DailySummaryResponse;
import com.chen.server.domain.Vo.WorkoutListResponse;
import com.chen.server.domain.Vo.WorkoutRecordVO;
import com.chen.server.domain.dto.WorkoutQueryRequest;
import com.chen.server.domain.dto.WorkoutRequest;
import com.chen.server.domain.entity.WorkoutRecord;
import com.chen.server.domain.Vo.WorkoutResponse;
import com.chen.server.mapper.WorkoutRecordMapper;
import com.chen.server.service.WorkoutRecordService;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import tools.jackson.core.util.JsonRecyclerPools;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class WorkoutRecordServiceImpl implements WorkoutRecordService {

    @Autowired
    private WorkoutRecordMapper workoutRecordMapper;


    private static final DateTimeFormatter DATE_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd");
    @Override
    public WorkoutResponse saveWorkout(Long userId, WorkoutRequest request) {
        WorkoutRecord record = new WorkoutRecord();
        record.setUserId(userId);
        record.setDate(request.getDate());
        record.setExerciseId(request.getExerciseId());
        record.setName(request.getName());
        record.setCalories(request.getCalories());
        record.setDurationSeconds(request.getDurationSeconds());
        record.setPlanId(request.getPlanId());

        if (request.getConfigSnapshot() != null) {
            try {
                String configJson = JSONUtil.toJsonStr(request.getConfigSnapshot());
                record.setConfigSnapshot(configJson);
            } catch (Exception e) {
                record.setConfigSnapshot("{}");
            }
        }

        workoutRecordMapper.insert(record);

        WorkoutResponse response = new WorkoutResponse();
        response.setId(String.valueOf(record.getId()));
        response.setDate(record.getDate());
        response.setExerciseId(record.getExerciseId());
        response.setName(record.getName());
        response.setCalories(record.getCalories());
        response.setDurationSeconds(record.getDurationSeconds());

        return response;
    }


    @Override
    public WorkoutListResponse queryWorkoutRecords(Long userId, WorkoutQueryRequest queryRequest) {
        LambdaQueryWrapper<WorkoutRecord> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WorkoutRecord::getUserId, userId);

        if (StringUtils.hasText(queryRequest.getStartDate())) {
            LocalDate startDate = LocalDate.parse(queryRequest.getStartDate(), DATE_FORMATTER);
            wrapper.ge(WorkoutRecord::getDate, startDate);
        }

        if (StringUtils.hasText(queryRequest.getEndDate())) {
            LocalDate endDate = LocalDate.parse(queryRequest.getEndDate(), DATE_FORMATTER);
            wrapper.le(WorkoutRecord::getDate, endDate);
        }

        wrapper.orderByDesc(WorkoutRecord::getDate)
                .orderByDesc(WorkoutRecord::getId);

        Page<WorkoutRecord> page = new Page<>(queryRequest.getPageNo(), queryRequest.getPageSize());
        Page<WorkoutRecord> resultPage = workoutRecordMapper.selectPage(page, wrapper);

        List<WorkoutRecordVO> records = resultPage.getRecords().stream()
                .map(record -> new WorkoutRecordVO(
                        String.valueOf(record.getId()),
                        record.getDate(),
                        record.getExerciseId(),
                        record.getName(),
                        record.getCalories(),
                        record.getDurationSeconds()
                ))
                .collect(Collectors.toList());

        return new WorkoutListResponse(records, resultPage.getTotal());
    }

    @Override
    public DailySummaryResponse getDailySummary(Long userId, String date) {
        LocalDate targetDate = LocalDate.parse(date, DATE_FORMATTER);

        LambdaQueryWrapper<WorkoutRecord> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WorkoutRecord::getUserId, userId)
                .eq(WorkoutRecord::getDate, targetDate);

        List<WorkoutRecord> records = workoutRecordMapper.selectList(wrapper);

        int workoutCount = records.size();
        BigDecimal totalCalories = records.stream()
                .map(WorkoutRecord::getCalories)
                .filter(c -> c != null)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        int totalDurationSeconds = records.stream()
                .mapToInt(record -> record.getDurationSeconds() != null ? record.getDurationSeconds() : 0)
                .sum();

        return new DailySummaryResponse(targetDate, workoutCount, totalCalories, totalDurationSeconds);
    }
}