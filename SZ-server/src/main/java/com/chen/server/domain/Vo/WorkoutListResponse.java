package com.chen.server.domain.Vo;

import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@Data
public class WorkoutListResponse {
    private List<WorkoutRecordVO> records;
    private Long total;

    public WorkoutListResponse() {
    }

    public WorkoutListResponse(List<WorkoutRecordVO> records, Long total) {
        this.records = records;
        this.total = total;
    }
}