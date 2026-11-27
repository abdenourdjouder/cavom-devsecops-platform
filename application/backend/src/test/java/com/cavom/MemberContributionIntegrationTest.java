package com.cavom;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.csrf;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

@SpringBootTest
@AutoConfigureMockMvc
class MemberContributionIntegrationTest {
    @Autowired MockMvc mockMvc;
    @Autowired ObjectMapper objectMapper;

    @Test
    void createsMemberAndRecordsContribution() throws Exception {
        MvcResult memberResult = mockMvc.perform(post("/api/members")
                        .with(csrf())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"Jordan","email":"jordan@example.com"}
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.email").value("jordan@example.com"))
                .andReturn();
        JsonNode member = objectMapper.readTree(memberResult.getResponse().getContentAsString());
        long memberId = member.get("id").asLong();

        mockMvc.perform(post("/api/members/{id}/contributions", memberId)
                        .with(csrf())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"amount":125.50,"description":"Annual support","contributedOn":"2026-11-20"}
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.memberId").value(memberId));

        mockMvc.perform(get("/api/members/{id}/contributions", memberId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].amount").value(125.50));
    }

    @Test
    void rejectsDuplicateMemberAndInvalidContribution() throws Exception {
        String body = """
                {"name":"Sam","email":"sam@example.com"}
                """;
        mockMvc.perform(post("/api/members").with(csrf()).contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isCreated());
        mockMvc.perform(post("/api/members").with(csrf()).contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isConflict());
        mockMvc.perform(post("/api/members/1/contributions")
                        .with(csrf())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"amount":-1,"description":"","contributedOn":"not-a-date"}
                                """))
                .andExpect(status().isBadRequest());
    }
}
