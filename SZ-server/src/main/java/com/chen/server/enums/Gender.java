package com.chen.server.enums;

public enum Gender {
    MALE("男", "male", "男"),
    FEMALE("女", "female", "女"),
    UNKNOWN("未填写", "unknown", "未填写");

    private final String chineseValue;
    private final String englishValue;
    private final String description;

    Gender(String chineseValue, String englishValue, String description) {
        this.chineseValue = chineseValue;
        this.englishValue = englishValue;
        this.description = description;
    }

    public String getChineseValue() {
        return chineseValue;
    }

    public String getEnglishValue() {
        return englishValue;
    }

    public String getDescription() {
        return description;
    }

    public static Gender fromChineseValue(String chineseValue) {
        for (Gender gender : values()) {
            if (gender.getChineseValue().equals(chineseValue)) {
                return gender;
            }
        }
        throw new IllegalArgumentException("Unknown gender (Chinese): " + chineseValue);
    }

    public static Gender fromEnglishValue(String englishValue) {
        for (Gender gender : values()) {
            if (gender.getEnglishValue().equals(englishValue)) {
                return gender;
            }
        }
        throw new IllegalArgumentException("Unknown gender (English): " + englishValue);
    }

    public static Gender fromValue(String value) {
        for (Gender gender : values()) {
            if (gender.getChineseValue().equals(value) || gender.getEnglishValue().equals(value)) {
                return gender;
            }
        }
        throw new IllegalArgumentException("Unknown gender value: " + value);
    }
}