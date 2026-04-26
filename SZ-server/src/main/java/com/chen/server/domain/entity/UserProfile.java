package com.chen.server.domain.entity;

import lombok.Data;
import java.time.LocalDateTime;

@Data
public class UserProfile {
    private Long userId;
    private String nickname;
    private String heightCm;
    private String weightKg;
    private String age;
    private String gender;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;


    public UserProfile() {
    }

    public UserProfile(Long userId, String nickname, String heightCm,
                       String weightKg, String age, String gender) {
        this.userId = userId;
        this.nickname = nickname;
        this.heightCm = heightCm;
        this.weightKg = weightKg;
        this.age = age;
        this.gender = gender;
    }
}
