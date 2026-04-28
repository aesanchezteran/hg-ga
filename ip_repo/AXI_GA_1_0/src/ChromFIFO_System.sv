`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/11/2026 01:05:04 PM
// Design Name: 
// Module Name: ChromFIFO_System
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


module ChromFIFO_System #(
    parameter NTASKS = 64,
    parameter TASK_W = 6,
    parameter PROC_W = 3
)(
    input  logic clk,
    input  logic rst,
    input  logic ff_en,

    input  logic pipeline_enable,
    input  logic ctrl_select,
    input  logic [$clog2(NTASKS)-1:0] ctrl_sel_idx,

    // read control
    input  logic fifo_read_en,
    input  logic fifo_read_two,
    input  logic [TASK_W-1:0] fifo_task_in [6],
    input  logic [PROC_W-1:0] fifo_proc_in [6],

    // FIFO outputs
    output logic [TASK_W-1:0] fifo_task_out1,
    output logic [PROC_W-1:0] fifo_proc_out1,

    output logic  write_en,
    output logic [TASK_W-1:0] fifo_task_out2,
    output logic [PROC_W-1:0] fifo_proc_out2
);

    // --------------------------------------------------
    // FIFO count (2 ? 4 ? 6 chromosomes)
    // --------------------------------------------------

    logic [3:0] FIFO_count;
    FIFOFillCount FIFO_FILL_COUNT ( .clk(clk), .rst(rst), .ff_en(ff_en),
        .pipeline_enable(pipeline_enable), .ctrl_select(ctrl_select),
        .FIFO_count(FIFO_count));

    logic fifo_write_en;
    logic [2:0] fifo_n_write;                 // 2,4,6 chromosomes arriving
    assign fifo_n_write = FIFO_count;
    logic [$clog2(NTASKS)-1:0] fifo_sel_idx;  // gene index
    


    always_ff @(posedge clk) begin
        if(rst) begin
        write_en <= 1'b0;
        end if (ff_en) begin
            if (ctrl_select) begin
            write_en <= 1'b1;    
            end else if (ctrl_sel_idx == NTASKS-1)begin
            write_en <= 1'b0;    
            end
        end
    end

    assign fifo_sel_idx = ctrl_sel_idx;
    assign fifo_write_en = write_en;
    
    
    ChromFIFO #(
        .NTASKS   (NTASKS),
        .DEPTH    (6),
        .TASK_W   (TASK_W),
        .PROC_W   (PROC_W),
        .MAX_WRITE(6)
    ) u_chrom_fifo (
    
        .clk       (clk),
        .rst       (rst),
        .ff_en     (ff_en),
    
        // write interface
        .write_en  (fifo_write_en),
        .n_write   (fifo_n_write),
        .sel_idx   (fifo_sel_idx),
    
        .task_in   (fifo_task_in),
        .proc_in   (fifo_proc_in),
    
        // read control
        .read_en   (fifo_read_en),
        .read_two  (fifo_read_two),
    
        // outputs
        .task_out1 (fifo_task_out1),
        .proc_out1 (fifo_proc_out1),
    
        .task_out2 (fifo_task_out2),
        .proc_out2 (fifo_proc_out2)
    );
    
endmodule