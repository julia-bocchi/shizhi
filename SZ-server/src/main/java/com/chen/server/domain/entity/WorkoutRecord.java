package com.chen.server.domain.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;

@Data
public class WorkoutRecord {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long userId;
    private LocalDate date;
    private String exerciseId;
    private String name;
    private BigDecimal calories;
    private Integer durationSeconds;
    private Long planId;
    private String configSnapshot;

    public WorkoutRecord() {
    }

    public WorkoutRecord(Long id, Long userId, LocalDate date, String exerciseId, String name,
                        BigDecimal calories, Integer durationSeconds, Long planId, String configSnapshot) {
        this.id = id;
        this.userId = userId;
        this.date = date;
        this.exerciseId = exerciseId;
        this.name = name;
        this.calories = calories;
        this.durationSeconds = durationSeconds;
        this.planId = planId;
        this.configSnapshot = configSnapshot;
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Long getUserId() {
        return userId;
    }

    public void setUserId(Long userId) {
        this.userId = userId;
    }

    public LocalDate getDate() {
        return date;
    }

    public void setDate(LocalDate date) {
        this.date = date;
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


    public String getConfigSnapshot() {
        return configSnapshot;
    }

    public void setConfigSnapshot(String configSnapshot) {
        this.configSnapshot = configSnapshot;
    }
}