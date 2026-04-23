package com.chen.server.controller;

import com.chen.server.domain.ResponseResult;
import com.chen.server.domain.Vo.DailySummaryResponse;
import com.chen.server.domain.Vo.WorkoutListResponse;
import com.chen.server.domain.Vo.WorkoutResponse;
import com.chen.server.domain.dto.WorkoutQueryRequest;
import com.chen.server.domain.dto.WorkoutRequest;
import com.chen.server.service.WorkoutRecordService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/workout-records")
public class WorkoutController {
    @Autowired
    private WorkoutRecordService workoutRecordService;
    @PostMapping
    public ResponseResult saveWorkout(@RequestBody WorkoutRequest request) {
        Long userId = getCurrentUserId();

        WorkoutResponse response = workoutRecordService.saveWorkout(userId, request);

        return ResponseResult.okResult(response);
    }
    @GetMapping
    public ResponseResult queryWorkoutRecords(WorkoutQueryRequest queryRequest) {
        Long userId = getCurrentUserId();
        WorkoutListResponse response = workoutRecordService.queryWorkoutRecords(userId, queryRequest);
        return ResponseResult.okResult(response);
    }

    @GetMapping("/api/v1/workout-records/daily-summary")
    public ResponseResult getDailySummary(@RequestParam String date) {
        Long userId = getCurrentUserId();
        DailySummaryResponse response = workoutRecordService.getDailySummary(userId, date);
        return ResponseResult.okResult(response);
    }
    private Long getCurrentUserId() {
        return 1L;
    }
}
