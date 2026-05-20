package com.chen.server.domain.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import lombok.Data;

import java.time.LocalDate;

@Data
public class WorkoutPlan {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long userId;
    private LocalDate date;
    private String title;
    private String summary;
    private String notes;
    private String draftText;
    private Long savedWorkoutId;
    private String accentColor;

    public WorkoutPlan() {
    }

    public WorkoutPlan(Long id, Long userId, LocalDate date, String title, String summary, 
                      String notes, String draftText, Long savedWorkoutId, String accentColor) {
        this.id = id;
        this.userId = userId;
        this.date = date;
        this.title = title;
        this.summary = summary;
        this.notes = notes;
        this.draftText = draftText;
        this.savedWorkoutId = savedWorkoutId;
        this.accentColor = accentColor;
    }
}