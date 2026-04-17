package com.chen.server.domain.dto;


import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Map;

@Data
public class WorkoutRequest {


    private LocalDate date;

    private String exerciseId;


    private String name;


    private BigDecimal calories;


    private Integer durationSeconds;

    private String planId;

    private Map<String, Object> configSnapshot;

    public WorkoutRequest() {
    }

    public WorkoutRequest(LocalDate date, String exerciseId, String name, BigDecimal calories, 
                         Integer durationSeconds, String planId, Map<String, Object> configSnapshot) {
        this.date = date;
        this.exerciseId = exerciseId;
        this.name = name;
        this.calories = calories;
        this.durationSeconds = durationSeconds;
        this.planId = planId;
        this.configSnapshot = configSnapshot;
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

    public String getPlanId() {
        return planId;
    }

    public void setPlanId(String planId) {
        this.planId = planId;
    }

    public Map<String, Object> getConfigSnapshot() {
        return configSnapshot;
    }

    public void setConfigSnapshot(Map<String, Object> configSnapshot) {
        this.configSnapshot = configSnapshot;
    }
}