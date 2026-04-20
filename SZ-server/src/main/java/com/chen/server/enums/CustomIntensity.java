package com.chen.server.enums;

public enum CustomIntensity {
    LIGHT("light", "轻松"),
    MODERATE("moderate", "中等"),
    INTENSE("intense", "高强");

    private final String code;
    private final String description;

    CustomIntensity(String code, String description) {
        this.code = code;
        this.description = description;
    }

    public String getCode() {
        return code;
    }

    public String getDescription() {
        return description;
    }

    public static CustomIntensity fromCode(String code) {
        for (CustomIntensity intensity : values()) {
            if (intensity.getCode().equals(code)) {
                return intensity;
            }
        }
        throw new IllegalArgumentException("Unknown customIntensity: " + code);
    }
}