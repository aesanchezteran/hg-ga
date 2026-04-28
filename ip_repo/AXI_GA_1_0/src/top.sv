`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/27/2026 10:46:10 AM
// Design Name: 
// Module Name: top
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

module Multiprocessor_GA_System#(
  parameter int NPROCS   = 16,
  parameter int NTASKS   = 64,
  parameter int EXEC_W   = 8,
  parameter int DEAD_W   = 8,
  parameter int TASK_W   = $clog2(NTASKS),
  parameter int PROC_W   = $clog2(NPROCS),
  parameter int TIME_W   = 12,
  parameter int SUM_W    = 18,
  parameter int FIT_W = 23
)(
        input logic sysclk, sysrst, start, 
        input  logic [EXEC_W*NTASKS-1:0] exec_reg_flat,
        input  logic [DEAD_W*NTASKS-1:0] deadline_reg_flat,
    
        output logic [FIT_W-1:0] elite_best_fit,
        output logic [TASK_W*NTASKS-1:0] elite_best_task_flat,
        output logic [PROC_W*NTASKS-1:0] elite_best_proc_flat
        );
    
    logic [EXEC_W-1:0] exec_reg     [0:NTASKS-1];
    logic [DEAD_W-1:0] deadline_reg [0:NTASKS-1];
    logic [31:0] exec_regs32     [0:15];
    logic [31:0] deadline_regs32 [0:15];
    logic [TASK_W-1:0] elite_best_task [0:NTASKS-1];
    logic [PROC_W-1:0] elite_best_proc [0:NTASKS-1];
    logic rst;
    
    genvar i;
    generate
        for (i = 0; i < NTASKS; i++) begin : UNPACK_INPUTS
            assign exec_reg[i]     = exec_reg_flat[i*EXEC_W +: EXEC_W];
            assign deadline_reg[i] = deadline_reg_flat[i*DEAD_W +: DEAD_W];
        end
    endgenerate
    
    genvar j;
    generate
        for (j = 0; j < 16; j++) begin : PACK_REGS_32
            assign exec_regs32[j] = {
                exec_reg[j*4 + 3],
                exec_reg[j*4 + 2],
                exec_reg[j*4 + 1],
                exec_reg[j*4 + 0]
            };
    
            assign deadline_regs32[j] = {
                deadline_reg[j*4 + 3],
                deadline_reg[j*4 + 2],
                deadline_reg[j*4 + 1],
                deadline_reg[j*4 + 0]
            };
        end
    endgenerate
    
    generate
        for (i = 0; i < NTASKS; i++) begin : PACK_OUTPUTS
            assign elite_best_task_flat[i*TASK_W +: TASK_W] = elite_best_task[i];
            assign elite_best_proc_flat[i*PROC_W +: PROC_W] = elite_best_proc[i];
        end
    endgenerate
    
    logic pipeline_enable_ctrl;
    logic [6:0] count;
    logic restart;
        
    always_ff @(posedge sysclk) begin
        if (sysrst) begin
        pipeline_enable_ctrl<= 1'b0;
        count <= 'd0;
        end else if (start && (count <'d72)) begin
            count <= count + 1;
                
        end else if (start && (count== 'd72)) begin
            count <= 'd72;
            pipeline_enable_ctrl = 1'b1;
        end else if (~start) begin 
            count <= 'd0;
            pipeline_enable_ctrl = 1'b0;
        end
    end
    
    assign restart = (count == 'd1) ;
    
    logic   ff_en;
    assign  ff_en = 1'b1;
    logic   clk;
    assign  clk = sysclk;
    assign rst = sysrst | restart;
    
     // ----------------------------
    // BRAM ports
    // ----------------------------
    logic                 w_en_ctrl;
    logic [TASK_W-1:0]    w_addr_ctrl;
    logic [EXEC_W-1:0]    w_exec_time_ctrl;
    logic [DEAD_W-1:0]    w_deadline_ctrl;

    Multiprocessor_GA #(
        .NPROCS (NPROCS),
        .NTASKS (NTASKS),
        .EXEC_W (EXEC_W),
        .DEAD_W (DEAD_W),
        .TASK_W (TASK_W),
        .PROC_W (PROC_W),
        .TIME_W (TIME_W),
        .SUM_W  (SUM_W),
        .FIT_W(FIT_W)
    ) dut (
        .clk(clk),
        .rst(rst),
        .ff_en(ff_en),
        .w_en(w_en_ctrl),
        .w_addr(w_addr_ctrl),
        .w_exec_time(w_exec_time_ctrl),
        .w_deadline(w_deadline_ctrl),
        .pipeline_enable(pipeline_enable_ctrl),
        .elite_best_fit  (elite_best_fit),
        .elite_best_task (elite_best_task),
        .elite_best_proc (elite_best_proc)
    );
    // Interfaz BRAM exec
    logic done;
    logic        exec_bram_en;
    logic        exec_bram_we;
    logic [5:0]  exec_bram_addr;
    logic [7:0]  exec_bram_din;
    
    // Interfaz BRAM deadline
    logic        dead_bram_en;
    logic        dead_bram_we;
    logic [5:0]  dead_bram_addr;
    logic [7:0]  dead_bram_din;
    
    TaskParamBRAMWriter #(
        .NREGS          (16),
        .VALUES_PER_REG (4),
        .EXEC_W         (EXEC_W),
        .DEAD_W         (DEAD_W),
        .NTASKS         (NTASKS),
        .LSB_FIRST      (1'b1)
    ) BRAM_writer (
        .clk            (clk),
        .rst            (rst),
        .start          (start),
        .done           (done),
    
        .exec_reg       (exec_regs32),
        .deadline_reg   (deadline_regs32),
    
        .exec_bram_en   (exec_bram_en),
        .exec_bram_we   (exec_bram_we),
        .exec_bram_addr (exec_bram_addr),
        .exec_bram_din  (exec_bram_din),
    
        .dead_bram_en   (dead_bram_en),
        .dead_bram_we   (dead_bram_we),
        .dead_bram_addr (dead_bram_addr),
        .dead_bram_din  (dead_bram_din)
    );
    
    always_comb begin
        w_en_ctrl = dead_bram_we;
        w_addr_ctrl = dead_bram_addr;
        w_exec_time_ctrl = exec_bram_din;
        w_deadline_ctrl = dead_bram_din;
    end

endmodule
