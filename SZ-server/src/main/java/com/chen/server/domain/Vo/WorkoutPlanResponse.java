package com.chen.server.domain.Vo;

import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.Data;

import java.time.LocalDate;

@Data
public class WorkoutPlanResponse {
    private String id;

    @JsonFormat(pattern = "yyyy-MM-dd")
    private LocalDate date;
    private String title;
    private String summary;
    private String notes;
    private String draftText;
    private String savedWorkoutId;
    private String accentColor;

    public WorkoutPlanResponse() {
    }

    public WorkoutPlanResponse(String id, LocalDate date, String title, String summary, 
                              String notes, String draftText, String savedWorkoutId, String accentColor) {
        this.id = id;
        this.date = date;
        this.title = title;
        this.summary = summary;
        this.notes = notes;
        this.draftText = draftText;
        this.savedWorkoutId = savedWorkoutId;
        this.accentColor = accentColor;
    }
}