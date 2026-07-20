package com.octocat.supply;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class ApiEndpointsTest {
    @Autowired
    private MockMvc mockMvc;

    @Test
    void suppliersListReturnsSeededData() throws Exception {
        mockMvc.perform(get("/api/suppliers"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$[0].supplierId").value(1))
            .andExpect(jsonPath("$[0].name").value("PurrTech Innovations"));
    }

    @Test
    void supplierStatusEndpointReturnsApproved() throws Exception {
        mockMvc.perform(get("/api/suppliers/1/status"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.status").value("APPROVED"));
    }

    @Test
    void creatingSupplierWithoutNameReturnsValidationError() throws Exception {
        mockMvc.perform(post("/api/suppliers")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{}"))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"))
            .andExpect(jsonPath("$.error.message").value("name is required"));
    }

    @Test
    void headquartersMetricsAndLabelAreExposed() throws Exception {
        mockMvc.perform(get("/api/headquarters/1/metrics"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.score").isNumber())
            .andExpect(jsonPath("$.average").isNumber())
            .andExpect(jsonPath("$.display").isString());

        mockMvc.perform(get("/api/headquarters/1/label"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.label").value("Location:CatTech Global HQCity:Country:"));
    }
}
