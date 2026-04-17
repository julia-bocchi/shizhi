package com.chen.server.domain.dto;

import lombok.Data;

import java.time.LocalDate;

@Data
public class WorkoutPlanRequest {
    private LocalDate date;
    private String title;
    private String notes;
    private String savedWorkoutId;
    private String draftText;

    public WorkoutPlanRequest() {
    }

    public WorkoutPlanRequest(LocalDate date, String title, String notes, 
                             String savedWorkoutId, String draftText) {
        this.date = date;
        this.title = title;
        this.notes = notes;
        this.savedWorkoutId = savedWorkoutId;
        this.draftText = draftText;
    }
}