`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/10/2026 03:44:21 PM
// Design Name: 
// Module Name: SelectionStage
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


module SelectionStage #(
    parameter int NTASKS      = 64,
    parameter int TASK_W      = 6,
    parameter int POOL_DEPTH  = 12,
    parameter int CP_RD_PORTS = 6,
    parameter int TIME_W      = 12,
    parameter int FIT_W       = 23
)(
    input  logic clk,
    input  logic rst,
    input  logic ff_en,

    input  logic gene_last,
    input  logic pipeline_enable,
    input  logic write_en,

    input  logic [FIT_W-1 +9:0] pool_fit_all [0:POOL_DEPTH-1],

    output logic ctrl_select,
    output logic sel_out,
    output logic ctrl_clr_upper_fit,
    output logic [$clog2(NTASKS)-1:0] ctrl_sel_idx,

    output logic [$clog2(POOL_DEPTH)-1:0] read_addrs [0:CP_RD_PORTS-1]
);

    Select_Control #(
        .NTASKS (NTASKS),
        .TASK_W (TASK_W)
    ) u_select_ctrl (
        .clk             (clk),
        .rst             (rst),
        .ff_en           (ff_en),
        .gene_last       (gene_last),
        .pipeline_enable (pipeline_enable),
        .sel_idx         (ctrl_sel_idx),
        .select_out      (ctrl_select),
        .sel_out         (sel_out),
        .clr_upper_fit   (ctrl_clr_upper_fit)
    );

    // ------------------------------------------------------------
    // Pool fill FSM (0 ? 4 ? 8 ? 12)
    // ------------------------------------------------------------

    logic [$clog2(POOL_DEPTH+1)-1:0] pool_count;

    SelectFillFSM u_pool_fsm (
        .clk(clk),
        .rst(rst),
        .ff_en(ff_en),
        .pipeline_enable(pipeline_enable),
        .ctrl_select(ctrl_select),
        .pool_count(pool_count)
    );

    localparam int RNG_W       = 32;
    localparam int N_RNG       = 6;
    
    logic [RNG_W-1:0] base_rand;
    logic [RNG_W-1:0] mixed_rand [0:N_RNG-1];
    
    RandGen #(
        .WIDTH(7),
        .NUM_CHANNELS(6),
        .WIDTH_OUT(RNG_W)
    ) RNG_i (
        .clk      (clk),
        .rst      (rst),
        .en       (ff_en),
        .rand_out (base_rand)
    );
    
    always_comb begin
        mixed_rand[0] = base_rand ^ 32'h9E3779B9;
        mixed_rand[1] = {base_rand[15:0], base_rand[31:16]} ^ 32'h3C6EF372;
        mixed_rand[2] = {base_rand[7:0],  base_rand[31:8]}  ^ 32'hDAA66D2B;
        mixed_rand[3] = ((base_rand << 5) | (base_rand >> 27)) ^ 32'h78DDE6E4;
        mixed_rand[4] = ((base_rand << 13) | (base_rand >> 19)) + 32'h1715609D;
        mixed_rand[5] = ((base_rand << 21) | (base_rand >> 11)) ^ 32'hB54CDA56;
    end
    
        logic [FIT_W-1 +9 :0] accum_fit;
        logic accum_nonzero;
        
        logic [FIT_W-1 +9 :0] read_fit  [0:POOL_DEPTH-1];
        logic [FIT_W-1 +9 :0] rand_nums [0:CP_RD_PORTS-1];
        logic [FIT_W-1 +9 :0] rand_nums_REG [0:CP_RD_PORTS-1];
        
    
    always_comb begin
        read_fit = pool_fit_all;
    
        accum_fit     = read_fit[pool_count-1];
//        accum_nonzero = (accum_fit != '0);
        accum_nonzero = 1'b1;
    
        rand_nums[0] = write_en ? rand_nums_REG[0] % accum_fit : '0;
        rand_nums[1] = write_en ? rand_nums_REG[1] % accum_fit : '0;
        rand_nums[2] = write_en ? rand_nums_REG[2] % accum_fit : '0;
        rand_nums[3] = write_en ? rand_nums_REG[3] % accum_fit : '0;
        rand_nums[4] = write_en ? rand_nums_REG[4] % accum_fit : '0;
        rand_nums[5] = write_en ? rand_nums_REG[5] % accum_fit : '0;
    end

    Register #(
        .WIDTH(6*(32))
    ) RAND_PIPELINE (
        .clk(clk),
        .rst(rst),
        .en(ctrl_select && ff_en),
    
        .d({
            mixed_rand[5], mixed_rand[4],
            mixed_rand[3], mixed_rand[2],
            mixed_rand[1],  mixed_rand[0]
        }),
    
        .q({
            rand_nums_REG[5], rand_nums_REG[4],
            rand_nums_REG[3], rand_nums_REG[2],
            rand_nums_REG[1],  rand_nums_REG[0]
        })
    );
    // ------------------------------------------------------------
    // Roulette selection
    // ------------------------------------------------------------

    RouletteMultiSelect #(
        .DEPTH      (POOL_DEPTH),
        .NUM_SELECT (CP_RD_PORTS),
        .FIT_WIDTH  (FIT_W-1 +10)
    ) u_roulette_multi_select (
        .Sel_enable (1'b1),
        .read_fit   (read_fit),
        .rand_nums  (rand_nums),
        .pool_count (pool_count),
        .read_addrs (read_addrs)
    );

endmodule
