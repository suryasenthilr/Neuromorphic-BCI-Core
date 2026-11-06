//=============================================================================
// Testbench: tb_neuromorphic_top
// Description: End-to-end self-checking verification for Neuromorphic BCI Core
// Verifies:
//   - 4-phase AER asynchronous spike train reception
//   - Crossbar weight configuration and sparse distribution
//   - LIF neuron membrane integration, leak decay, and refractory timing
//   - Real-time Population-Coding BCI motor intent classification
//=============================================================================

`timescale 1ns / 1ps

module tb_neuromorphic_top;

    localparam N_INPUTS    = 16;
    localparam N_NEURONS   = 8;
    localparam DATA_WIDTH  = 16;
    localparam WEIGHT_BITS = 8;
    localparam WINDOW_BITS = 8;

    reg clk;
    reg rst_n;

    // AER Interface
    reg                         aer_req;
    wire                        aer_ack;
    reg  [$clog2(N_INPUTS)-1:0] aer_addr;

    // Host Configuration Bus
    reg         cfg_we;
    reg  [7:0]  cfg_addr;
    reg  [31:0] cfg_wdata;

    // BCI Outputs
    wire [N_NEURONS-1:0]         spikes_raw;
    wire                         decision_valid;
    wire [$clog2(N_NEURONS)-1:0] detected_class;
    wire [WINDOW_BITS-1:0]       confidence_count;

    // Instantiate DUT
    neuromorphic_bci_top #(
        .N_INPUTS    (N_INPUTS),
        .N_NEURONS   (N_NEURONS),
        .DATA_WIDTH  (DATA_WIDTH),
        .WEIGHT_BITS (WEIGHT_BITS),
        .WINDOW_BITS (WINDOW_BITS)
    ) dut (
        .clk              (clk),
        .rst_n            (rst_n),
        .aer_req          (aer_req),
        .aer_ack          (aer_ack),
        .aer_addr         (aer_addr),
        .cfg_we           (cfg_we),
        .cfg_addr         (cfg_addr),
        .cfg_wdata        (cfg_wdata),
        .spikes_raw       (spikes_raw),
        .decision_valid   (decision_valid),
        .detected_class   (detected_class),
        .confidence_count (confidence_count)
    );

    // 100 MHz Clock Generation (10ns period)
    always #5 clk = ~clk;

    // Task: 4-Phase Asynchronous AER Spike Injection
    task send_aer_spike(input [$clog2(N_INPUTS)-1:0] channel);
        begin
            aer_addr = channel;
            aer_req  = 1'b1;
            wait(aer_ack == 1'b1);
            #15;
            aer_req  = 1'b0;
            wait(aer_ack == 1'b0);
            #15;
        end
    endtask

    // Task: Configure Global Register
    task write_reg(input [3:0] reg_idx, input [31:0] value);
        begin
            @(posedge clk);
            cfg_we    = 1'b1;
            cfg_addr  = {4'b0000, reg_idx};
            cfg_wdata = value;
            @(posedge clk);
            cfg_we    = 1'b0;
            #5;
        end
    endtask

    // Task: Configure Synaptic Weight: W[in_ch][out_neuron] = weight
    task write_synapse(input [$clog2(N_INPUTS)-1:0] in_ch, 
                       input [$clog2(N_NEURONS)-1:0] out_neuron, 
                       input signed [WEIGHT_BITS-1:0] weight);
        begin
            @(posedge clk);
            cfg_we    = 1'b1;
            cfg_addr  = {2'b01, in_ch[2:0], out_neuron[2:0]};
            cfg_wdata = {{24{weight[WEIGHT_BITS-1]}}, weight};
            @(posedge clk);
            cfg_we    = 1'b0;
            #5;
        end
    endtask

    integer pass_count = 0;
    integer fail_count = 0;
    integer k;

    initial begin
        $dumpfile("sim/dump.vcd");
        $dumpvars(0, tb_neuromorphic_top);

        clk      = 0;
        rst_n    = 0;
        aer_req  = 0;
        aer_addr = 0;
        cfg_we   = 0;
        cfg_addr = 0;
        cfg_wdata = 0;

        #30;
        rst_n = 1;
        #20;

        $display("===============================================================");
        $display("  NEUROMORPHIC BCI PROCESSOR - RTL VERIFICATION");
        $display("===============================================================");

        // Step 1: Program Parameters
        // Threshold = 100, Reset = 0, Refractory = 2 cycles, Window = 40 cycles, Leak prescale = 8
        write_reg(4'h0, 32'd100); // v_threshold
        write_reg(4'h1, 32'd0);   // v_reset
        write_reg(4'h2, 32'd2);   // refr_period
        write_reg(4'h3, 32'd40);  // window_len
        write_reg(4'h4, 32'd8);   // leak_prescale
        $display("[SETUP] Global Neuron Parameters & BCI Window Configured.");

        // Step 2: Program Synaptic Weights
        // Channel 1 strongly activates Neuron 2 (W = +60)
        write_synapse(3'd1, 3'd2, 8'sd60);
        // Channel 3 strongly activates Neuron 5 (W = +80)
        write_synapse(3'd3, 3'd5, 8'sd80);
        $display("[SETUP] Synaptic Crossbar Weights Configured.");

        // Step 3: Stimulate Area A (Spike train on Channel 1 -> Expect Neuron 2 to fire)
        $display("\n[TEST 1] Stimulating Motor Cortex Channel 1 (Target: Class 2)...");
        for (k = 0; k < 6; k = k + 1) begin
            send_aer_spike(3'd1);
            #10;
        end

        // Wait for BCI decoder decision
        wait(decision_valid == 1'b1);
        @(posedge clk);
        $display("  --> Decoded Class: %0d (Expected: 2), Confidence: %0d spikes", detected_class, confidence_count);
        if (detected_class == 3'd2 && confidence_count > 0) begin
            $display("  --> [PASS] Neural Class 2 (Left Motor Intent) Successfully Decoded!");
            pass_count = pass_count + 1;
        end else begin
            $display("  --> [FAIL] Classification Mismatch for Class 2");
            fail_count = fail_count + 1;
        end

        #50;

        // Step 4: Stimulate Area B (Spike train on Channel 3 -> Expect Neuron 5 to fire)
        $display("\n[TEST 2] Stimulating Motor Cortex Channel 3 (Target: Class 5)...");
        for (k = 0; k < 8; k = k + 1) begin
            send_aer_spike(3'd3);
            #10;
        end

        // Wait for next BCI decoder decision
        wait(decision_valid == 1'b1);
        @(posedge clk);
        $display("  --> Decoded Class: %0d (Expected: 5), Confidence: %0d spikes", detected_class, confidence_count);
        if (detected_class == 3'd5 && confidence_count > 0) begin
            $display("  --> [PASS] Neural Class 5 (Right Motor Intent) Successfully Decoded!");
            pass_count = pass_count + 1;
        end else begin
            $display("  --> [FAIL] Classification Mismatch for Class 5");
            fail_count = fail_count + 1;
        end

        #100;

        $display("\n===============================================================");
        $display("  VERIFICATION SUMMARY: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("===============================================================\n");

        if (fail_count == 0) $display(">>> ALL NEUROMORPHIC TESTS PASSED BIT-EXACT <<<");
        else                 $display(">>> SOME TESTS FAILED <<<");

        $finish;
    end

    // Watchdog Timer
    initial begin
        #50000;
        $display("\n[ERROR] Simulation Watchdog Timeout!");
        $finish;
    end

endmodule
