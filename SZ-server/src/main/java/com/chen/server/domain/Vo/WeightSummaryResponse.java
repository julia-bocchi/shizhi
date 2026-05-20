package com.chen.server.domain.Vo;



import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;

@Data
public class WeightSummaryResponse {
    
    private WeightRecordInfo latestRecord;
    
    private WeightRecordInfo previousRecord;
    
    private Integer recentCount;
    
    private BigDecimal averageWeight;
    
    private BigDecimal changeInRange;
    
    private BigDecimal changeFromPrevious;
    
    @Data
    public static class WeightRecordInfo {
        private Long id;
        
        @JsonFormat(pattern = "yyyy-MM-dd")
        private LocalDate date;
        
        private BigDecimal weight;
        
        public WeightRecordInfo() {
        }
        
        public WeightRecordInfo(Long id, LocalDate date, BigDecimal weight) {
            this.id = id;
            this.date = date;
            this.weight = weight;
        }
    }
}
