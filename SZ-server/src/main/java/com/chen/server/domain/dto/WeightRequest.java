package com.chen.server.domain.dto;




import lombok.Data;
import org.jetbrains.annotations.NotNull;

import java.math.BigDecimal;
@Data
public class WeightRequest {


    private BigDecimal weight;

    public WeightRequest() {
    }

    public WeightRequest(BigDecimal weight) {
        this.weight = weight;
    }

    public BigDecimal getWeight() {
        return weight;
    }

    public void setWeight(BigDecimal weight) {
        this.weight = weight;
    }
}
