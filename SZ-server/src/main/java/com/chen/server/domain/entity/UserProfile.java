package com.chen.server.domain.entity;

import lombok.Data;

@Data
public class UserProfile {
    private Long id;
    private Long userId;
    private String nickname;
    private String heightCm;
    private String weightKg;
    private String age;
    private String gender;

    public UserProfile() {
    }

    public UserProfile(Long id, Long userId, String nickname, String heightCm, 
                      String weightKg, String age, String gender) {
        this.id = id;
        this.userId = userId;
        this.nickname = nickname;
        this.heightCm = heightCm;
        this.weightKg = weightKg;
        this.age = age;
        this.gender = gender;
    }
}