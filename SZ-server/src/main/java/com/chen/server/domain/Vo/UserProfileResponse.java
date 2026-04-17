package com.chen.server.domain.Vo;

import lombok.Data;

@Data
public class UserProfileResponse {
    private String nickname;
    private String heightCm;
    private String weightKg;
    private String age;
    private String gender;

    public UserProfileResponse() {
    }

    public UserProfileResponse(String nickname, String heightCm, String weightKg, 
                              String age, String gender) {
        this.nickname = nickname;
        this.heightCm = heightCm;
        this.weightKg = weightKg;
        this.age = age;
        this.gender = gender;
    }
}