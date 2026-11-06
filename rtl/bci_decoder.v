//=============================================================================
// Module: bci_decoder
// Description: Real-time Neuromorphic BCI Spike Rate & Population Decoder
// Features:
//   - Sliding temporal window spike-rate integration
//   - Real-time Winner-Take-All (ArgMax) neural intent classification
//   - Outputs decoded class ID and confidence metric for neural prosthetics
//=============================================================================

`timescale 1ns / 1ps

module bci_decoder #(
    parameter N_CLASSES    = 8,
    parameter WINDOW_BITS  = 8   // 256-cycle integration window
)(
    input  wire                         clk,
    input  wire                         rst_n,
    
    // Neural Spike Inputs
    input  wire [N_CLASSES-1:0]         spikes_in,
    
    // Configuration
    input  wire [WINDOW_BITS-1:0]       window_len, // Integration epoch length
    
    // Classification Output
    output reg                          decision_valid,
    output reg  [$clog2(N_CLASSES)-1:0] detected_class,
    output reg  [WINDOW_BITS-1:0]       confidence_count
);

    reg [WINDOW_BITS-1:0] window_counter;
    reg [WINDOW_BITS-1:0] spike_counters [0:N_CLASSES-1];

    integer k;

    // ArgMax Calculation
    reg [$clog2(N_CLASSES)-1:0] max_idx;
    reg [WINDOW_BITS-1:0]       max_val;

    always @(*) begin
        max_idx = 0;
        max_val = spike_counters[0];
        for (k = 1; k < N_CLASSES; k = k + 1) begin
            if (spike_counters[k] > max_val) begin
                max_val = spike_counters[k];
                max_idx = k[$clog2(N_CLASSES)-1:0];
            end
        end
    end

    // Sequential Rate Integration and Intent Classification
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            window_counter   <= 0;
            decision_valid   <= 1'b0;
            detected_class   <= 0;
            confidence_count <= 0;
            for (k = 0; k < N_CLASSES; k = k + 1) begin
                spike_counters[k] <= 0;
            end
        end else begin
            decision_valid <= 1'b0;

            // Accumulate spikes in the current window
            for (k = 0; k < N_CLASSES; k = k + 1) begin
                if (spikes_in[k]) begin
                    spike_counters[k] <= spike_counters[k] + 1'b1;
                end
            end

            // Epoch complete: latch classified intent and reset counters
            if (window_counter >= window_len - 1'b1) begin
                window_counter   <= 0;
                decision_valid   <= 1'b1;
                detected_class   <= max_idx;
                confidence_count <= max_val;

                // Clear counters for next epoch
                for (k = 0; k < N_CLASSES; k = k + 1) begin
                    spike_counters[k] <= 0;
                end
            end else begin
                window_counter <= window_counter + 1'b1;
            end
        end
    end

endmodule
