package com.cavom.dto;

import com.cavom.domain.Member;
import java.time.Instant;

public record MemberResponse(Long id, String name, String email, Instant createdAt) {
    public static MemberResponse from(Member member) {
        return new MemberResponse(member.getId(), member.getName(), member.getEmail(), member.getCreatedAt());
    }
}
