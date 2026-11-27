package com.cavom.service;

import com.cavom.domain.Contribution;
import com.cavom.dto.ContributionResponse;
import com.cavom.dto.CreateContributionRequest;
import com.cavom.repository.ContributionRepository;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class ContributionService {
    private final ContributionRepository contributions;
    private final MemberService memberService;

    public ContributionService(ContributionRepository contributions, MemberService memberService) {
        this.contributions = contributions;
        this.memberService = memberService;
    }

    public List<ContributionResponse> list(Long memberId) {
        memberService.require(memberId);
        return contributions.findByMemberIdOrderByContributedOnDescCreatedAtDesc(memberId)
                .stream().map(ContributionResponse::from).toList();
    }

    @Transactional
    public ContributionResponse create(Long memberId, CreateContributionRequest request) {
        Contribution contribution = contributions.save(new Contribution(
                memberService.require(memberId), request.amount(), request.description().trim(),
                request.contributedOn()));
        return ContributionResponse.from(contribution);
    }
}
