package com.chen.server.domain.entity;

import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.time.LocalDateTime;
@TableName("user_account")
@Data
public class User {
    private Long userId;
    private String username;
    private String password;
    private String token;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;


    public User() {
    }

    public User(Long userId, String username, String password) {
        this.userId = userId;
        this.username = username;
        this.password = password;
    }
}