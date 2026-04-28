`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/10/2026 11:31:29 AM
// Design Name: 
// Module Name: Select_Control
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Select_Control#(
    parameter int NTASKS = 64,
    parameter int TASK_W = 6 
)(
    input  logic clk,
    input  logic rst,
    input  logic ff_en,

    input  logic gene_last,        // starts sequence, replaces first select pulse
    input  logic pipeline_enable,  // keep looping while high
    
    output logic [$clog2(NTASKS)-1:0] sel_idx,
    output logic select_out, sel_out,
    output logic clr_upper_fit
);
    
    logic sel, select;
    always_ff @(posedge clk) begin
        if(rst) begin
        sel = 1'b0;
        end if (gene_last && ff_en) begin
        sel = 1'b1;    
        end
    end
    

    Buffer #(.WIDTH(1)) buff (.data_in(sel), .data_out(sel_out));
    
    counter #(
        .WIDTH(TASK_W)
    ) gene_counter (
        .clk(clk),
        .rst(rst),
        .en(sel_out && ff_en),
        .count(sel_idx)
    );
    
    assign select_out = sel_out ? select : gene_last;
    
    
    typedef enum logic [3:0] {
        IDLE,
        WAIT_CLR1,
        PULSE_CLR1,
        WAIT_SEL2,
        PULSE_SEL2,
        WAIT_CLR2,
        PULSE_CLR2,
        WAIT_LOOP_SEL,
        PULSE_LOOP_SEL,
        WAIT_LOOP_CLR,
        PULSE_LOOP_CLR
    } state_t;

    state_t state;
    logic [6:0] cnt;

    always_ff @(posedge clk) begin
        if (rst) begin
            state         <= IDLE;
            cnt           <= 7'd0;
            select        <= 1'b0;
            clr_upper_fit <= 1'b0;
        end else if(ff_en) begin
            // default outputs: 1-cycle pulses
            select        <= 1'b0;
            clr_upper_fit <= 1'b0;

            case (state)

                // ----------------------------------------------------------
                // Wait for start
                // gene_last replaces the first select pulse from TB
                // ----------------------------------------------------------
                IDLE: begin
                    cnt <= 7'd0;
                    if (gene_last) begin
                        state <= WAIT_CLR1;
                    end
                end

                // repeat (63)
                WAIT_CLR1: begin
                    if (cnt == 7'd61) begin
                        cnt   <= 7'd0;
                        state <= PULSE_CLR1;
                    end else begin
                        cnt <= cnt + 7'd1;
                    end
                end

                // clr_upper_fit = 1 for 1 cycle
                PULSE_CLR1: begin
                    clr_upper_fit <= 1'b1;
                    cnt           <= 7'd0;
                    state         <= WAIT_SEL2;
                end

                // repeat (63)
                WAIT_SEL2: begin
                    if (cnt == 7'd62) begin
                        cnt   <= 7'd0;
                        state <= PULSE_SEL2;
                    end else begin
                        cnt <= cnt + 7'd1;
                    end
                end

                // select = 1 for 1 cycle
                PULSE_SEL2: begin
                    select <= 1'b1;
                    cnt    <= 7'd0;
                    state  <= WAIT_CLR2;
                end

                // repeat (63)
                WAIT_CLR2: begin
                    if (cnt == 7'd62) begin
                        cnt   <= 7'd0;
                        state <= PULSE_CLR2;
                    end else begin
                        cnt <= cnt + 7'd1;
                    end
                end

                // clr_upper_fit = 1 for 1 cycle
                PULSE_CLR2: begin
                    clr_upper_fit <= 1'b1;
                    cnt           <= 7'd0;

                    if (pipeline_enable)
                        state <= WAIT_LOOP_SEL;
                    else
                        state <= IDLE;
                end

                // ----------------------------------------------------------
                // Infinite loop while pipeline_enable == 1
                // repeat (127) -> select pulse
                // repeat (63)  -> clr_upper_fit pulse
                // ----------------------------------------------------------
                WAIT_LOOP_SEL: begin
                    if (!pipeline_enable) begin
                        state <= IDLE;
                        cnt   <= 7'd0;
                    end else if (cnt == 7'd126) begin
                        cnt   <= 7'd0;
                        state <= PULSE_LOOP_SEL;
                    end else begin
                        cnt <= cnt + 7'd1;
                    end
                end

                PULSE_LOOP_SEL: begin
                    if (!pipeline_enable) begin
                        state  <= IDLE;
                        cnt    <= 7'd0;
                        select <= 1'b0;
                    end else begin
                        select <= 1'b1;
                        cnt    <= 7'd0;
                        state  <= WAIT_LOOP_CLR;
                    end
                end

                WAIT_LOOP_CLR: begin
                    if (!pipeline_enable) begin
                        state <= IDLE;
                        cnt   <= 7'd0;
                    end else if (cnt == 7'd62) begin
                        cnt   <= 7'd0;
                        state <= PULSE_LOOP_CLR;
                    end else begin
                        cnt <= cnt + 7'd1;
                    end
                end

                PULSE_LOOP_CLR: begin
                    if (!pipeline_enable) begin
                        state         <= IDLE;
                        cnt           <= 7'd0;
                        clr_upper_fit <= 1'b0;
                    end else begin
                        clr_upper_fit <= 1'b1;
                        cnt           <= 7'd0;
                        state         <= WAIT_LOOP_SEL;
                    end
                end

                default: begin
                    state         <= IDLE;
                    cnt           <= 7'd0;
                    select        <= 1'b0;
                    clr_upper_fit <= 1'b0;
                end
            endcase
        end
    end

endmodule
