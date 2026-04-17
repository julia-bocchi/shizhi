package com.chen.server.domain.Vo;

import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;

@Data
public class DailySummaryResponse {
    @JsonFormat(pattern = "yyyy-MM-dd")
    private LocalDate date;
    private Integer workoutCount;
    private BigDecimal totalCalories;
    private Integer totalDurationSeconds;

    public DailySummaryResponse() {
    }

    public DailySummaryResponse(LocalDate date, Integer workoutCount, 
                               BigDecimal totalCalories, Integer totalDurationSeconds) {
        this.date = date;
        this.workoutCount = workoutCount;
        this.totalCalories = totalCalories;
        this.totalDurationSeconds = totalDurationSeconds;
    }
}