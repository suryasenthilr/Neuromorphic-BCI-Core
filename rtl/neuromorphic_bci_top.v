//=============================================================================
// Module: neuromorphic_bci_top
// Description: Complete Neuromorphic Brain-Computer Interface (BCI) Processor
// Top-level architecture integrating:
//   - 4-Phase Asynchronous Address-Event Representation (AER) Receiver
//   - Zero-overhead Sparse Synaptic Crossbar
//   - Parallel Leaky Integrate-and-Fire (LIF) Neural Processing Core
//   - Programmable Leak Strobe Generator
//   - Real-time Population-Coding Intent Classifier / Decoder
//   - Host Memory-Mapped Configuration Port
//=============================================================================

`timescale 1ns / 1ps

module neuromorphic_bci_top #(
    parameter N_INPUTS    = 16,
    parameter N_NEURONS   = 8,
    parameter DATA_WIDTH  = 16,
    parameter WEIGHT_BITS = 8,
    parameter WINDOW_BITS = 8
)(
    input  wire                                  clk,
    input  wire                                  rst_n,
    
    // Asynchronous AER Neural Input (from Brain Probe / Sensor)
    input  wire                                  aer_req,
    output wire                                  aer_ack,
    input  wire [$clog2(N_INPUTS)-1:0]           aer_addr,
    
    // Host Configuration Bus
    input  wire                                  cfg_we,
    input  wire [7:0]                            cfg_addr,
    input  wire [31:0]                           cfg_wdata,
    
    // Real-Time BCI Output Interface
    output wire [N_NEURONS-1:0]                  spikes_raw,
    output wire                                  decision_valid,
    output wire [$clog2(N_NEURONS)-1:0]          detected_class,
    output wire [WINDOW_BITS-1:0]                confidence_count
);

    // Configuration Registers
    reg signed [DATA_WIDTH-1:0] reg_v_threshold;
    reg signed [DATA_WIDTH-1:0] reg_v_reset;
    reg [3:0]                   reg_refr_period;
    reg [WINDOW_BITS-1:0]       reg_window_len;
    reg [7:0]                   reg_leak_prescale;
    
    // Crossbar configuration decode
    wire crossbar_cfg_we = cfg_we && (cfg_addr[7:6] == 2'b01);
    wire [$clog2(N_INPUTS)-1:0]  cfg_in_ch  = cfg_addr[5:3];
    wire [$clog2(N_NEURONS)-1:0] cfg_out_ch = cfg_addr[2:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_v_threshold   <= 16'sh0100; // Default threshold = 256
            reg_v_reset       <= 16'sh0000; // Default resting potential = 0
            reg_refr_period   <= 4'd2;      // 2-cycle refractory period
            reg_window_len    <= 8'd64;     // 64-cycle classification epoch
            reg_leak_prescale <= 8'd8;      // Leak pulse every 8 cycles
        end else if (cfg_we && (cfg_addr[7:6] == 2'b00)) begin
            case (cfg_addr[3:0])
                4'h0: reg_v_threshold   <= cfg_wdata[DATA_WIDTH-1:0];
                4'h1: reg_v_reset       <= cfg_wdata[DATA_WIDTH-1:0];
                4'h2: reg_refr_period   <= cfg_wdata[3:0];
                4'h3: reg_window_len    <= cfg_wdata[WINDOW_BITS-1:0];
                4'h4: reg_leak_prescale <= cfg_wdata[7:0];
            endcase
        end
    end

    // Programmable Leak Strobe Generator
    reg [7:0] leak_cnt;
    wire leak_tick = (leak_cnt == reg_leak_prescale);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            leak_cnt <= 8'd0;
        end else begin
            if (leak_tick) leak_cnt <= 8'd0;
            else           leak_cnt <= leak_cnt + 1'b1;
        end
    end

    // 1. AER Neural Event Receiver
    wire event_valid;
    wire [$clog2(N_INPUTS)-1:0] event_addr;
    wire event_ready;

    aer_rx #(
        .ADDR_WIDTH($clog2(N_INPUTS)),
        .FIFO_DEPTH(16)
    ) u_aer_rx (
        .clk         (clk),
        .rst_n       (rst_n),
        .aer_req     (aer_req),
        .aer_ack     (aer_ack),
        .aer_addr    (aer_addr),
        .event_valid (event_valid),
        .event_addr  (event_addr),
        .event_ready (event_ready)
    );

    // 2. Synaptic Crossbar
    wire [N_NEURONS-1:0]                    post_syn_valid;
    wire signed [N_NEURONS*WEIGHT_BITS-1:0] post_syn_weights;

    synaptic_crossbar #(
        .N_INPUTS    (N_INPUTS),
        .N_NEURONS   (N_NEURONS),
        .WEIGHT_BITS (WEIGHT_BITS)
    ) u_crossbar (
        .clk              (clk),
        .rst_n            (rst_n),
        .cfg_we           (crossbar_cfg_we),
        .cfg_in_addr      (cfg_in_ch),
        .cfg_neuron_addr  (cfg_out_ch),
        .cfg_weight       (cfg_wdata[WEIGHT_BITS-1:0]),
        .event_valid      (event_valid),
        .event_addr       (event_addr),
        .event_ready      (event_ready),
        .post_syn_valid   (post_syn_valid),
        .post_syn_weights (post_syn_weights)
    );

    // 3. Parallel LIF Neuron Array
    wire [N_NEURONS-1:0] spikes_internal;
    wire signed [N_NEURONS*DATA_WIDTH-1:0] v_membrane_bus;

    neuron_array #(
        .N_NEURONS   (N_NEURONS),
        .DATA_WIDTH  (DATA_WIDTH),
        .WEIGHT_BITS (WEIGHT_BITS),
        .LEAK_SHIFT  (3),
        .REFR_WIDTH  (4)
    ) u_neuron_array (
        .clk            (clk),
        .rst_n          (rst_n),
        .leak_en        (leak_tick),
        .v_threshold    (reg_v_threshold),
        .v_reset        (reg_v_reset),
        .refr_period    (reg_refr_period),
        .syn_valid      (post_syn_valid),
        .syn_weights    (post_syn_weights),
        .spikes_out     (spikes_internal),
        .v_membrane_bus (v_membrane_bus)
    );

    assign spikes_raw = spikes_internal;

    // 4. BCI Population Decoder & ArgMax Intent Classifier
    bci_decoder #(
        .N_CLASSES   (N_NEURONS),
        .WINDOW_BITS (WINDOW_BITS)
    ) u_bci_decoder (
        .clk              (clk),
        .rst_n            (rst_n),
        .spikes_in        (spikes_internal),
        .window_len       (reg_window_len),
        .decision_valid   (decision_valid),
        .detected_class   (detected_class),
        .confidence_count (confidence_count)
    );

endmodule
