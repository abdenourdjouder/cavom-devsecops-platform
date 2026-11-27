package com.cavom.repository;

import com.cavom.domain.Contribution;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ContributionRepository extends JpaRepository<Contribution, Long> {
    List<Contribution> findByMemberIdOrderByContributedOnDescCreatedAtDesc(Long memberId);
}
