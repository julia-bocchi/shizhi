package com.chen.server.enums;

public enum CustomMode {
    DURATION("duration", "按时长"),
    SET_TIMER("set_timer", "按组计时"),
    DISTANCE_PACE("distance_pace", "配速 + 路程"),
    DISTANCE_SPEED("distance_speed", "均速 + 路程"),
    COUNT_RATE("count_rate", "次数 + 节奏");

    private final String code;
    private final String description;

    CustomMode(String code, String description) {
        this.code = code;
        this.description = description;
    }

    public String getCode() {
        return code;
    }

    public String getDescription() {
        return description;
    }

    public static CustomMode fromCode(String code) {
        for (CustomMode mode : values()) {
            if (mode.getCode().equals(code)) {
                return mode;
            }
        }
        throw new IllegalArgumentException("Unknown customMode: " + code);
    }
}