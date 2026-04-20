package com.chen.server.enums;

public enum Task {
    CHAT("chat", "普通问答"),
    ANALYZE_WEIGHT("analyze_weight", "体重趋势分析"),
    GENERATE_PLAN("generate_plan", "生成训练计划草案");

    private final String code;
    private final String description;

    Task(String code, String description) {
        this.code = code;
        this.description = description;
    }

    public String getCode() {
        return code;
    }

    public String getDescription() {
        return description;
    }

    public static Task fromCode(String code) {
        for (Task task : values()) {
            if (task.getCode().equals(code)) {
                return task;
            }
        }
        throw new IllegalArgumentException("Unknown task: " + code);
    }
}