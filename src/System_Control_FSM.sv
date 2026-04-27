`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/16/2026 05:17:01 PM
// Design Name: 
// Module Name: System_Control_FSM
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


module System_Control_FSM (
    input  logic clk,
    input  logic rst,
    input  logic pipeline_enable,
    input logic ff_en,

    output logic clr_fit,
    output logic bram_r_en,
    output logic fit_in_ready,
    output logic fifo_read_en,
    output logic fifo_read_two
);

    typedef enum logic [1:0] {
        IDLE = 2'b00,
        RUN  = 2'b01,
        SAT  = 2'b10
    } state_t;

    state_t state, next_state;

    // Contador de ciclos dentro de RUN
    logic [10:0] cycle_cnt;

    // ------------------------------------------------------------
    // Lógica secuencial
    // ------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= IDLE;
            cycle_cnt <= 10'd0;
        end else if (ff_en) begin
            state <= next_state;

            case (state)
                IDLE: begin
                    cycle_cnt <= 10'd0;
                end

                RUN: begin
                    if (!pipeline_enable) begin
                        cycle_cnt <= 10'd0;
                    end else begin
                        cycle_cnt <= cycle_cnt + 10'd1;
                    end
                end
                
                SAT: begin
                    if (!pipeline_enable) begin
                        cycle_cnt <= 10'd0;
                    end else begin
                        cycle_cnt <= 10'd500;
                    end
                end

                default: begin
                    cycle_cnt <= 10'd0;
                end
            endcase
        end
    end


    // ------------------------------------------------------------
    // Próximo estado
    // ------------------------------------------------------------
    always_comb begin
        next_state = state;

        case (state)
            IDLE: begin
                if (pipeline_enable)
                    next_state = RUN;
            end

            RUN: begin
                if (pipeline_enable && fifo_read_two)
                    next_state = SAT;
            end
            
            SAT: begin
                if (!pipeline_enable)
                    next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // ------------------------------------------------------------
    // Salidas
    // ------------------------------------------------------------
    always_comb begin
        // por defecto en 0
        clr_fit       = 1'b0;
        bram_r_en     = 1'b0;
        fit_in_ready  = 1'b0;
        fifo_read_en  = 1'b0;
        fifo_read_two = 1'b0;

        if (state == RUN || state == SAT) begin
            // "en el siguiente ciclo" después de pipeline_enable
            if (cycle_cnt == 10'd0)
                clr_fit = 1'b1;

            // 2 ciclos después de clr_fit  -> ciclo 2
            if (cycle_cnt >= 10'd2)
                bram_r_en = 1'b1;

            // 3 ciclos después de bram_r_en -> ciclo 5
            if (cycle_cnt >= 10'd5)
                fit_in_ready = 1'b1;

            // después de 124 ciclos
            if (cycle_cnt > 10'd128)
                fifo_read_en = 1'b1;

            // después de 225 ciclos
            if (cycle_cnt > 10'd384)
                fifo_read_two = 1'b1;
        end
    end

endmodule