package com.chen.server;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
@MapperScan("com.chen.server.mapper")
public class SzFrameworkApplication {

    public static void main(String[] args) {
        SpringApplication.run(SzFrameworkApplication.class, args);

    }

}
