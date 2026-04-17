package com.chen.server.service;

import com.chen.server.domain.Vo.DailySummaryResponse;
import com.chen.server.domain.Vo.WorkoutListResponse;
import com.chen.server.domain.Vo.WorkoutResponse;
import com.chen.server.domain.dto.WorkoutQueryRequest;
import com.chen.server.domain.dto.WorkoutRequest;

public interface WorkoutRecordService {

    WorkoutResponse saveWorkout(Long userId, WorkoutRequest request);

    WorkoutListResponse queryWorkoutRecords(Long userId, WorkoutQueryRequest queryRequest);

    DailySummaryResponse getDailySummary(Long userId, String date);
}