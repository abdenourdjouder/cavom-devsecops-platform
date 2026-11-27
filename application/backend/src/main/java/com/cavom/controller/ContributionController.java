package com.cavom.controller;

import com.cavom.dto.ContributionResponse;
import com.cavom.dto.CreateContributionRequest;
import com.cavom.service.ContributionService;
import jakarta.validation.Valid;
import java.net.URI;
import java.util.List;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/members/{memberId}/contributions")
public class ContributionController {
    private final ContributionService service;

    public ContributionController(ContributionService service) {
        this.service = service;
    }

    @GetMapping
    public List<ContributionResponse> list(@PathVariable Long memberId) {
        return service.list(memberId);
    }

    @PostMapping
    public ResponseEntity<ContributionResponse> create(
            @PathVariable Long memberId,
            @Valid @RequestBody CreateContributionRequest request) {
        ContributionResponse contribution = service.create(memberId, request);
        return ResponseEntity.created(URI.create(
                "/api/members/" + memberId + "/contributions/" + contribution.id())).body(contribution);
    }
}
