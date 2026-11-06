//=============================================================================
// Module: lif_neuron
// Description: Synthesizable Leaky Integrate-and-Fire (LIF) Neuromorphic Neuron
// Features:
//   - Configurable membrane decay (shift-based exponential leak)
//   - Programmable threshold and resting potentials
//   - Configurable refractory period counter
//   - Zero-overhead event-driven spike generation
//=============================================================================

`timescale 1ns / 1ps

module lif_neuron #(
    parameter DATA_WIDTH  = 16,
    parameter LEAK_SHIFT  = 3,     // Leak factor: V = V - (V >>> LEAK_SHIFT)
    parameter REFR_WIDTH  = 4      // Up to 15 cycles refractory duration
)(
    input  wire                   clk,
    input  wire                   rst_n,
    
    // Control & Configuration
    input  wire                   leak_en,        // Periodic decay pulse
    input  wire signed [DATA_WIDTH-1:0] v_threshold, // Spike firing threshold
    input  wire signed [DATA_WIDTH-1:0] v_reset,     // Reset potential after spike
    input  wire [REFR_WIDTH-1:0]  refr_period,    // Refractory dead-time
    
    // Synaptic Inputs
    input  wire                   syn_valid,      // Input current pulse valid
    input  wire signed [DATA_WIDTH-1:0] syn_current, // Synaptic weight / current
    
    // Output
    output reg                    spike_out,      // Action potential output spike
    output reg signed [DATA_WIDTH-1:0] v_membrane  // Current membrane potential
);

    reg [REFR_WIDTH-1:0] refr_cnt;
    wire in_refractory = (refr_cnt != 0);

    // Membrane dynamics computation
    reg signed [DATA_WIDTH:0] next_v; // 1-bit extra for overflow protection

    always @(*) begin
        if (in_refractory) begin
            next_v = {v_reset[DATA_WIDTH-1], v_reset};
        end else begin
            next_v = {v_membrane[DATA_WIDTH-1], v_membrane};
            
            // 1. Apply Exponential Leakage Decay
            if (leak_en && (v_membrane > v_reset)) begin
                next_v = next_v - (next_v >>> LEAK_SHIFT);
            end
            
            // 2. Integrate Synaptic Input Current
            if (syn_valid) begin
                next_v = next_v + {{1{syn_current[DATA_WIDTH-1]}}, syn_current};
            end
        end
    end

    // Sequential State Update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v_membrane <= {DATA_WIDTH{1'b0}};
            spike_out  <= 1'b0;
            refr_cnt   <= {REFR_WIDTH{1'b0}};
        end else begin
            spike_out <= 1'b0;

            if (in_refractory) begin
                refr_cnt   <= refr_cnt - 1'b1;
                v_membrane <= v_reset;
            end else begin
                // Check for Threshold Crossing (Action Potential)
                if (next_v >= {{1{v_threshold[DATA_WIDTH-1]}}, v_threshold}) begin
                    spike_out  <= 1'b1;
                    v_membrane <= v_reset;
                    refr_cnt   <= refr_period;
                end else if (next_v < {{1{v_reset[DATA_WIDTH-1]}}, v_reset}) begin
                    // Clamp at resting potential to prevent negative drift
                    v_membrane <= v_reset;
                end else begin
                    v_membrane <= next_v[DATA_WIDTH-1:0];
                end
            end
        end
    end

endmodule
