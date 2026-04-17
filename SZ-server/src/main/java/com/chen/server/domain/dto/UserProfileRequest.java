package com.chen.server.domain.dto;

import lombok.Data;

@Data
public class UserProfileRequest {
    private String nickname;
    private String heightCm;
    private String weightKg;
    private String age;
    private String gender;

    public UserProfileRequest() {
    }

    public UserProfileRequest(String nickname, String heightCm, String weightKg, 
                             String age, String gender) {
        this.nickname = nickname;
        this.heightCm = heightCm;
        this.weightKg = weightKg;
        this.age = age;
        this.gender = gender;
    }
}