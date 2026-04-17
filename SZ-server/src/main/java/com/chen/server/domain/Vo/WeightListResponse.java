package com.chen.server.domain.Vo;

import java.util.List;

public class WeightListResponse {
    private List<WeightRecordVO> records;

    public WeightListResponse() {
    }

    public WeightListResponse(List<WeightRecordVO> records) {
        this.records = records;
    }

    public List<WeightRecordVO> getRecords() {
        return records;
    }

    public void setRecords(List<WeightRecordVO> records) {
        this.records = records;
    }
}