package com.chen.server.domain.Vo;

import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;

@Data
public class WorkoutRecordVO {
    private String id;

    @JsonFormat(pattern = "yyyy-MM-dd")
    private LocalDate date;

    private String exerciseId;
    private String name;
    private BigDecimal calories;
    private Integer durationSeconds;

    public WorkoutRecordVO() {
    }

    public WorkoutRecordVO(String id, LocalDate date, String exerciseId, String name, 
                          BigDecimal calories, Integer durationSeconds) {
        this.id = id;
        this.date = date;
        this.exerciseId = exerciseId;
        this.name = name;
        this.calories = calories;
        this.durationSeconds = durationSeconds;
    }
}