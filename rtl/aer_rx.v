//=============================================================================
// Module: aer_rx
// Description: Address-Event Representation (AER) Neural Receiver
// Protocol: 4-phase asynchronous handshake with synchronous FIFO capture
// Converts asynchronous neural spike events into clock-synchronized packets.
//=============================================================================

`timescale 1ns / 1ps

module aer_rx #(
    parameter ADDR_WIDTH = 8,
    parameter FIFO_DEPTH = 16
)(
    input  wire                  clk,
    input  wire                  rst_n,
    
    // Asynchronous AER Port (From Neural Sensor / ECoG Array)
    input  wire                  aer_req,
    output reg                   aer_ack,
    input  wire [ADDR_WIDTH-1:0] aer_addr,
    
    // Synchronous Pipeline Interface
    output wire                  event_valid,
    output wire [ADDR_WIDTH-1:0] event_addr,
    input  wire                  event_ready
);

    // Double-flop synchronizer for asynchronous REQ line
    reg [2:0] req_sync;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) req_sync <= 3'b000;
        else        req_sync <= {req_sync[1:0], aer_req};
    end

    wire req_rising  = (req_sync[2:1] == 2'b01);
    wire req_falling = (req_sync[2:1] == 2'b10);
    wire req_active  = req_sync[1];

    // Four-Phase Handshake FSM
    localparam IDLE    = 2'b00;
    localparam CAPTURE = 2'b01;
    localparam WAIT_DN = 2'b10;

    reg [1:0] state;
    reg [ADDR_WIDTH-1:0] captured_addr;
    reg push_fifo;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= IDLE;
            aer_ack       <= 1'b0;
            captured_addr <= {ADDR_WIDTH{1'b0}};
            push_fifo     <= 1'b0;
        end else begin
            push_fifo <= 1'b0;
            case (state)
                IDLE: begin
                    aer_ack <= 1'b0;
                    if (req_rising) begin
                        captured_addr <= aer_addr;
                        push_fifo     <= 1'b1;
                        aer_ack       <= 1'b1;
                        state         <= WAIT_DN;
                    end
                end

                WAIT_DN: begin
                    // Wait for sender to drop req line
                    if (!req_active) begin
                        aer_ack <= 1'b0;
                        state   <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Small synchronous FIFO for decoupling burst spike rates
    reg [ADDR_WIDTH-1:0] fifo_mem [0:FIFO_DEPTH-1];
    reg [$clog2(FIFO_DEPTH):0] wr_ptr, rd_ptr;
    wire fifo_empty = (wr_ptr == rd_ptr);
    wire fifo_full  = ((wr_ptr[$clog2(FIFO_DEPTH)-1:0] == rd_ptr[$clog2(FIFO_DEPTH)-1:0]) &&
                       (wr_ptr[$clog2(FIFO_DEPTH)] != rd_ptr[$clog2(FIFO_DEPTH)]));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
        end else begin
            if (push_fifo && !fifo_full) begin
                fifo_mem[wr_ptr[$clog2(FIFO_DEPTH)-1:0]] <= captured_addr;
                wr_ptr <= wr_ptr + 1'b1;
            end
            if (event_ready && !fifo_empty) begin
                rd_ptr <= rd_ptr + 1'b1;
            end
        end
    end

    assign event_valid = !fifo_empty;
    assign event_addr  = fifo_mem[rd_ptr[$clog2(FIFO_DEPTH)-1:0]];

endmodule
