`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/26/2026 02:56:44 PM
// Design Name: 
// Module Name: BRAM_writer
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


//module BRAM_writer#(
//  parameter int NPROCS   = 16,
//  parameter int NTASKS   = 64,
//  parameter int TASK_W   = $clog2(NTASKS),
//  parameter int PROC_W   = $clog2(NPROCS),
//  parameter int EXEC_W   = 8,
//  parameter int DEAD_W   = 8
//  )(
//    input logic clk, rst, start,
//    input logic [31:0] exec_reg [8],
//    input logic [31:0] deadline_reg [8],
//    input logic ff_en,
    
//    output logic                  w_en,
//    output  logic [TASK_W-1:0]    w_addr,
//    output  logic [EXEC_W-1:0]    w_exec_time,
//    output  logic [DEAD_W-1:0]    w_deadline,
//    output logic pipeline_enable
//    );
    
    
//    always_ff @(posedge clk) begin
//        if (rst)begin
//        w_en <= 1'b0;
//        w_addr <= 'd0;
//        w_exec_time <= 'd0;
//        w_deadline <= 'd0;
//        pipeline_enable <= 1'b0;
//        end if(ff_en) begin
//            if (start) begin
//                w_en <= 1'b1;
//                w_addr <= 'd0;
//                w_exec_time <= exec_reg [0] ;
//                w_deadline <= 'd0;
                
                
            
//            end
//        end                
    
    
//    end
    
//endmodule


module TaskParamBRAMWriter #(
    parameter int NREGS       = 16,   // 16 registros AXI
    parameter int VALUES_PER_REG = 4, // 4 valores por registro
    parameter int EXEC_W      = 8,    // ancho de cada exec_time dentro del registro
    parameter int DEAD_W      = 8,    // ancho de cada deadline dentro del registro
    parameter int NTASKS      = NREGS * VALUES_PER_REG,
    parameter bit LSB_FIRST   = 1'b1  // 1: valor 0 en [7:0], 0: valor 0 en [31:24]
)(
    input  logic clk,
    input  logic rst,

    input  logic start,   // se queda encendida
    output logic done,    // se mantiene encendida cuando ya terminó

    // Registros provenientes del empaquetamiento AXI
    input  logic [31:0] exec_reg     [NREGS],
    input  logic [31:0] deadline_reg [NREGS],

    // Interfaz de escritura hacia BRAM de exec
    output logic                    exec_bram_en,
    output logic                    exec_bram_we,
    output logic [$clog2(NTASKS)-1:0] exec_bram_addr,
    output logic [EXEC_W-1:0]       exec_bram_din,

    // Interfaz de escritura hacia BRAM de deadline
    output logic                    dead_bram_en,
    output logic                    dead_bram_we,
    output logic [$clog2(NTASKS)-1:0] dead_bram_addr,
    output logic [DEAD_W-1:0]       dead_bram_din
);

    typedef enum logic [1:0] {
        S_IDLE  = 2'd0,
        S_WRITE = 2'd1,
        S_DONE  = 2'd2
    } state_t;

    state_t state, state_next;

    logic [$clog2(NTASKS)-1:0] task_idx;
    logic [$clog2(NTASKS)-1:0] task_idx_next;

    logic [EXEC_W-1:0] exec_val;
    logic [DEAD_W-1:0] dead_val;

    logic [$clog2(NREGS)-1:0] reg_idx;
    logic [1:0]               sub_idx;

    // --------------------------------------------------
    // Índices de extracción
    // --------------------------------------------------
    assign reg_idx = task_idx / VALUES_PER_REG;
    assign sub_idx = task_idx % VALUES_PER_REG;

    // --------------------------------------------------
    // Desempaquetado de datos
    // LSB_FIRST = 1:
    //   valor0 -> [7:0]
    //   valor1 -> [15:8]
    //   valor2 -> [23:16]
    //   valor3 -> [31:24]
    //
    // LSB_FIRST = 0:
    //   valor0 -> [31:24]
    //   valor1 -> [23:16]
    //   valor2 -> [15:8]
    //   valor3 -> [7:0]
    // --------------------------------------------------
    always_comb begin
        exec_val = '0;
        dead_val = '0;

        if (LSB_FIRST) begin
            exec_val = exec_reg[reg_idx][sub_idx*EXEC_W +: EXEC_W];
            dead_val = deadline_reg[reg_idx][sub_idx*DEAD_W +: DEAD_W];
        end
        else begin
            exec_val = exec_reg[reg_idx][((VALUES_PER_REG-1-sub_idx)*EXEC_W) +: EXEC_W];
            dead_val = deadline_reg[reg_idx][((VALUES_PER_REG-1-sub_idx)*DEAD_W) +: DEAD_W];
        end
    end

    // --------------------------------------------------
    // Lógica secuencial
    // --------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state    <= S_IDLE;
            task_idx <= '0;
        end
        else begin
            state    <= state_next;
            task_idx <= task_idx_next;
        end
    end

    // --------------------------------------------------
    // FSM
    // --------------------------------------------------
    always_comb begin
        state_next    = state;
        task_idx_next = task_idx;

        // Defaults
        done = 1'b0;

        exec_bram_en   = 1'b0;
        exec_bram_we   = 1'b0;
        exec_bram_addr = task_idx;
        exec_bram_din  = exec_val;

        dead_bram_en   = 1'b0;
        dead_bram_we   = 1'b0;
        dead_bram_addr = task_idx;
        dead_bram_din  = dead_val;

        case (state)
            S_IDLE: begin
                task_idx_next = '0;
                if (start) begin
                    state_next = S_WRITE;
                end
            end

            S_WRITE: begin
                // escribe una tarea por ciclo
                exec_bram_en   = 1'b1;
                exec_bram_we   = 1'b1;
                exec_bram_addr = task_idx;
                exec_bram_din  = exec_val;

                dead_bram_en   = 1'b1;
                dead_bram_we   = 1'b1;
                dead_bram_addr = task_idx;
                dead_bram_din  = dead_val;

                if (task_idx == NTASKS-1) begin
                    state_next = S_DONE;
                end
                else begin
                    task_idx_next = task_idx + 1'b1;
                end
            end

            S_DONE: begin
                done = 1'b1;

                // permanece aquí mientras start siga alto
                // cuando start baje, queda listo para una nueva carga
                if (!start) begin
                    state_next    = S_IDLE;
                    task_idx_next = '0;
                end
            end

            default: begin
                state_next    = S_IDLE;
                task_idx_next = '0;
            end
        endcase
    end

endmodule