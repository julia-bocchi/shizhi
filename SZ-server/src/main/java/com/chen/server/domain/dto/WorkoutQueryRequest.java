package com.chen.server.domain.dto;

import lombok.Data;

@Data
public class WorkoutQueryRequest {
    private String startDate;
    private String endDate;
    private Integer pageNo = 1;
    private Integer pageSize = 20;
}