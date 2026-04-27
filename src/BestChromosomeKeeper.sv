`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/12/2026 11:23:22 AM
// Design Name: 
// Module Name: BestChromosomeKeeper
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

module EliteKeeperFromPool #(
    parameter int POOL_DEPTH = 12,
    parameter int NTASKS     = 16,
    parameter int TASK_W     = 6,
    parameter int PROC_W     = 3,
    parameter int FIT_W      = 16
)(
    input  logic clk,
    input  logic rst,
    input  logic ff_en,

    // Start selection/capture of best chromosome currently in pool
    input  logic select_start,
    input logic [TASK_W-1:0] cap_idx,

    // Accumulated fitness array from ChromPool
    input  logic [FIT_W-1:0] fit_array [POOL_DEPTH],

    // Stream coming back from ChromPool read port

    input  logic [TASK_W-1:0] rd_task_in,
    input  logic [PROC_W-1:0] rd_proc_in,

    // Address to drive into ChromPool read select
    output logic [$clog2(POOL_DEPTH)-1:0] rd_sel_out,

    // Stored best-so-far fitness
    output logic [FIT_W-1:0] best_fit,

    // Stored best-so-far chromosome
    output logic [TASK_W-1:0] best_task_out [NTASKS],
    output logic [PROC_W-1:0] best_proc_out [NTASKS]

);

    localparam int ADDR_W = (POOL_DEPTH > 1) ? $clog2(POOL_DEPTH) : 1;

    logic [FIT_W-1:0]  max_fit_comb;
    logic [ADDR_W-1:0] max_addr_comb;

    logic better_fit;
    // --------------------------------------------------
    // Argmax over fitness array from ChromPool
    // --------------------------------------------------
    always_comb begin
        max_fit_comb  = fit_array[0];
        max_addr_comb = '0;

        for (int k = 1; k < POOL_DEPTH; k++) begin
            if (fit_array[k] > max_fit_comb) begin
                max_fit_comb  = fit_array[k];
                max_addr_comb = k[ADDR_W-1:0];
            end
        end
        
        better_fit = max_fit_comb > best_fit;
        
    end
    assign rd_sel_out = max_addr_comb;
    
    integer i;
    // --------------------------------------------------
    // Main control
    // --------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            best_fit       <= '0;
            for (i = 0; i < NTASKS; i++) begin
                best_task_out[i] <= '0;
                best_proc_out[i] <= '0;
            end
        end else if (ff_en) begin
            if(select_start & better_fit) begin
                best_task_out[cap_idx] <= rd_task_in;
                best_proc_out[cap_idx] <= rd_proc_in;  
                if ( cap_idx == NTASKS -1) begin
                    best_fit <= max_fit_comb;      
                end
            end
       
        end
    end

endmodule