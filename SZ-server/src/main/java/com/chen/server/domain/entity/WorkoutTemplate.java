package com.chen.server.domain.entity;

import lombok.Data;

@Data
public class WorkoutTemplate {
    private Long id;
    private Long userId;
    private String name;
    private String mode;
    private String intensity;
    private String durationMinutes;
    private String distanceKm;
    private String paceMinutes;
    private String speedKmH;
    private String count;
    private String cadencePerMinute;
    private String sets;
    private String workSeconds;
    private String restSeconds;

    public WorkoutTemplate() {
    }

    public WorkoutTemplate(Long id, Long userId, String name, String mode, String intensity,
                          String durationMinutes, String distanceKm, String paceMinutes,
                          String speedKmH, String count, String cadencePerMinute,
                          String sets, String workSeconds, String restSeconds) {
        this.id = id;
        this.userId = userId;
        this.name = name;
        this.mode = mode;
        this.intensity = intensity;
        this.durationMinutes = durationMinutes;
        this.distanceKm = distanceKm;
        this.paceMinutes = paceMinutes;
        this.speedKmH = speedKmH;
        this.count = count;
        this.cadencePerMinute = cadencePerMinute;
        this.sets = sets;
        this.workSeconds = workSeconds;
        this.restSeconds = restSeconds;
    }
}