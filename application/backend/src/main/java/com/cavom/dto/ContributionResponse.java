package com.cavom.dto;

import com.cavom.domain.Contribution;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;

public record ContributionResponse(
        Long id, Long memberId, BigDecimal amount, String description,
        LocalDate contributedOn, Instant createdAt) {
    public static ContributionResponse from(Contribution contribution) {
        return new ContributionResponse(
                contribution.getId(), contribution.getMember().getId(), contribution.getAmount(),
                contribution.getDescription(), contribution.getContributedOn(), contribution.getCreatedAt());
    }
}
