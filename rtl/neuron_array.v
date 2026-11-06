//=============================================================================
// Module: neuron_array
// Description: Parallel Array of N Leaky Integrate-and-Fire Neurons
// Features:
//   - Fully parallel concurrent membrane updates
//   - Parameterized neuron count and data precision
//   - Broadcast leak enable strobe
//   - Bit-vector parallel spike output bus
//=============================================================================

`timescale 1ns / 1ps

module neuron_array #(
    parameter N_NEURONS   = 8,
    parameter DATA_WIDTH  = 16,
    parameter WEIGHT_BITS = 8,
    parameter LEAK_SHIFT  = 3,
    parameter REFR_WIDTH  = 4
)(
    input  wire                                  clk,
    input  wire                                  rst_n,
    
    // Global Neuron Parameters
    input  wire                                  leak_en,
    input  wire signed [DATA_WIDTH-1:0]          v_threshold,
    input  wire signed [DATA_WIDTH-1:0]          v_reset,
    input  wire [REFR_WIDTH-1:0]                 refr_period,
    
    // Synaptic Inputs from Crossbar
    input  wire [N_NEURONS-1:0]                  syn_valid,
    input  wire signed [N_NEURONS*WEIGHT_BITS-1:0] syn_weights,
    
    // Parallel Spike Outputs
    output wire [N_NEURONS-1:0]                  spikes_out,
    output wire signed [N_NEURONS*DATA_WIDTH-1:0] v_membrane_bus
);

    genvar i;
    generate
        for (i = 0; i < N_NEURONS; i = i + 1) begin : GEN_LIF_NEURONS
            wire signed [WEIGHT_BITS-1:0] w_in = syn_weights[(i+1)*WEIGHT_BITS-1 : i*WEIGHT_BITS];
            wire signed [DATA_WIDTH-1:0] syn_curr = {{ (DATA_WIDTH-WEIGHT_BITS){w_in[WEIGHT_BITS-1]} }, w_in};
            wire signed [DATA_WIDTH-1:0] v_mem;

            lif_neuron #(
                .DATA_WIDTH(DATA_WIDTH),
                .LEAK_SHIFT(LEAK_SHIFT),
                .REFR_WIDTH(REFR_WIDTH)
            ) u_neuron (
                .clk         (clk),
                .rst_n       (rst_n),
                .leak_en     (leak_en),
                .v_threshold (v_threshold),
                .v_reset     (v_reset),
                .refr_period (refr_period),
                .syn_valid   (syn_valid[i]),
                .syn_current (syn_curr),
                .spike_out   (spikes_out[i]),
                .v_membrane  (v_mem)
            );

            assign v_membrane_bus[(i+1)*DATA_WIDTH-1 : i*DATA_WIDTH] = v_mem;
        end
    endgenerate

endmodule
