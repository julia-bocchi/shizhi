package com.chen.server.domain.Vo;

import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;

@Data
public class WorkoutResponse {
    private String id;

    @JsonFormat(pattern = "yyyy-MM-dd")
    private LocalDate date;
    private String exerciseId;
    private String name;
    private BigDecimal calories;
    private Integer durationSeconds;

    public WorkoutResponse() {
    }

    public WorkoutResponse(String id, LocalDate date, String exerciseId, String name, 
                          BigDecimal calories, Integer durationSeconds) {
        this.id = id;
        this.date = date;
        this.exerciseId = exerciseId;
        this.name = name;
        this.calories = calories;
        this.durationSeconds = durationSeconds;
    }

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public LocalDate getDate() {
        return date;
    }

    public void setDate(LocalDate date) {
        this.date = date;
    }

    public String getExerciseId() {
        return exerciseId;
    }

    public void setExerciseId(String exerciseId) {
        this.exerciseId = exerciseId;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public BigDecimal getCalories() {
        return calories;
    }

    public void setCalories(BigDecimal calories) {
        this.calories = calories;
    }

    public Integer getDurationSeconds() {
        return durationSeconds;
    }

    public void setDurationSeconds(Integer durationSeconds) {
        this.durationSeconds = durationSeconds;
    }
}