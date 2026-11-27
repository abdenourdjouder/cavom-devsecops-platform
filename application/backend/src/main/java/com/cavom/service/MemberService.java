package com.cavom.service;

import com.cavom.domain.Member;
import com.cavom.dto.CreateMemberRequest;
import com.cavom.dto.MemberResponse;
import com.cavom.exception.ConflictException;
import com.cavom.exception.NotFoundException;
import com.cavom.repository.MemberRepository;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class MemberService {
    private final MemberRepository members;

    public MemberService(MemberRepository members) {
        this.members = members;
    }

    public List<MemberResponse> list() {
        return members.findAll().stream().map(MemberResponse::from).toList();
    }

    public MemberResponse get(Long id) {
        return MemberResponse.from(require(id));
    }

    @Transactional
    public MemberResponse create(CreateMemberRequest request) {
        String email = request.email().trim().toLowerCase(java.util.Locale.ROOT);
        if (members.existsByEmailIgnoreCase(email)) {
            throw new ConflictException("A member with this email already exists");
        }
        return MemberResponse.from(members.save(new Member(request.name().trim(), email)));
    }

    public Member require(Long id) {
        return members.findById(id).orElseThrow(() -> new NotFoundException("Member not found"));
    }
}
