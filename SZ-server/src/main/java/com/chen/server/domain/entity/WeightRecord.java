package com.chen.server.domain.entity;

import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;
@Data
public class WeightRecord {
  private Long id;
  private Long userId;
  private LocalDate date;
  private BigDecimal weight;
  private Boolean isUpdated;

  public WeightRecord() {
  }

  public WeightRecord(Long id, Long userId, LocalDate date, BigDecimal weight, Boolean isUpdated) {
    this.id = id;
    this.userId = userId;
    this.date = date;
    this.weight = weight;
    this.isUpdated = isUpdated;
  }

  public Long getId() {
    return id;
  }

  public void setId(Long id) {
    this.id = id;
  }

  public Long getUserId() {
    return userId;
  }

  public void setUserId(Long userId) {
    this.userId = userId;
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

  public Boolean getIsUpdated() {
    return isUpdated;
  }

  public void setIsUpdated(Boolean isUpdated) {
    this.isUpdated = isUpdated;
  }
}
