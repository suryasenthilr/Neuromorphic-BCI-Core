//=============================================================================
// Module: synaptic_crossbar
// Description: Parallel Synaptic Crossbar & Weight Storage Matrix
// Features:
//   - Programmable N_INPUTS x N_NEURONS synaptic weight matrix
//   - Single-cycle parallel fan-out distribution to all output neurons
//   - Zero-weight sparsity gating (prevents redundant neuron integration)
//   - Memory configuration port for loading pre-trained BCI neural weights
//=============================================================================

`timescale 1ns / 1ps

module synaptic_crossbar #(
    parameter N_INPUTS    = 16,
    parameter N_NEURONS   = 8,
    parameter WEIGHT_BITS = 8
)(
    input  wire                                  clk,
    input  wire                                  rst_n,
    
    // Weight Configuration Port (Host Write Interface)
    input  wire                                  cfg_we,
    input  wire [$clog2(N_INPUTS)-1:0]           cfg_in_addr,
    input  wire [$clog2(N_NEURONS)-1:0]          cfg_neuron_addr,
    input  wire signed [WEIGHT_BITS-1:0]         cfg_weight,
    
    // Incoming Spike Event
    input  wire                                  event_valid,
    input  wire [$clog2(N_INPUTS)-1:0]           event_addr,
    output wire                                  event_ready,
    
    // Parallel Outputs to Neuron Array
    output reg  [N_NEURONS-1:0]                  post_syn_valid,
    output wire signed [N_NEURONS*WEIGHT_BITS-1:0] post_syn_weights
);

    // 2D Weight Memory: [in_idx][neuron_idx]
    reg signed [WEIGHT_BITS-1:0] weight_matrix [0:N_INPUTS-1][0:N_NEURONS-1];

    assign event_ready = 1'b1; // Single-cycle processing

    // Host Weight Configuration
    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < N_INPUTS; i = i + 1) begin
                for (j = 0; j < N_NEURONS; j = j + 1) begin
                    weight_matrix[i][j] <= {WEIGHT_BITS{1'b0}};
                end
            end
        end else if (cfg_we) begin
            weight_matrix[cfg_in_addr][cfg_neuron_addr] <= cfg_weight;
        end
    end

    // Parallel Weight Extraction & Sparsity Gating
    reg signed [WEIGHT_BITS-1:0] current_weights [0:N_NEURONS-1];

    always @(*) begin
        for (j = 0; j < N_NEURONS; j = j + 1) begin
            if (event_valid) begin
                current_weights[j] = weight_matrix[event_addr][j];
                // Sparsity gating: Only assert valid if weight is non-zero
                post_syn_valid[j]  = (weight_matrix[event_addr][j] != 0);
            end else begin
                current_weights[j] = {WEIGHT_BITS{1'b0}};
                post_syn_valid[j]  = 1'b0;
            end
        end
    end

    // Flatten unpacked array to packed output bus
    genvar g;
    generate
        for (g = 0; g < N_NEURONS; g = g + 1) begin : GEN_PACK_WEIGHTS
            assign post_syn_weights[(g+1)*WEIGHT_BITS-1 : g*WEIGHT_BITS] = current_weights[g];
        end
    endgenerate

endmodule
