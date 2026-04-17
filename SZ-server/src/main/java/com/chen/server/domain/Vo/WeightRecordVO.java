package com.chen.server.domain.Vo;

import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;
@Data
public class WeightRecordVO {
    private Long id;

    @JsonFormat(pattern = "yyyy-MM-dd")
    private LocalDate date;
    private BigDecimal weight;

    public WeightRecordVO() {
    }

    public WeightRecordVO(Long id, LocalDate date, BigDecimal weight) {
        this.id = id;
        this.date = date;
        this.weight = weight;
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public LocalDate getDate() {
        return date;
    }

    public void setDate(LocalDate date) {
        this.date = date;
    }

    public BigDecimal getWeight() {
        return weight;
    }

    public void setWeight(BigDecimal weight) {
        this.weight = weight;
    }
}