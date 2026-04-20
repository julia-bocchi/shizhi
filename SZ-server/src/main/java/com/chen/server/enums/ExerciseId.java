package com.chen.server.enums;

public enum ExerciseId {
    HIIT("hiit", "HIIT 间歇"),
    RUNNING("running", "跑步"),
    CYCLING("cycling", "骑行"),
    JUMP_ROPE("jump_rope", "跳绳"),
    YOGA("yoga", "瑜伽"),
    STRENGTH("strength", "力量循环"),
    CUSTOM("custom", "自定义运动");

    private final String code;
    private final String description;

    ExerciseId(String code, String description) {
        this.code = code;
        this.description = description;
    }

    public String getCode() {
        return code;
    }

    public String getDescription() {
        return description;
    }

    public static ExerciseId fromCode(String code) {
        for (ExerciseId exerciseId : values()) {
            if (exerciseId.getCode().equals(code)) {
                return exerciseId;
            }
        }
        throw new IllegalArgumentException("Unknown exerciseId: " + code);
    }
}