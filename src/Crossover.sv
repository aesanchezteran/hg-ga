`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/27/2026 01:41:29 PM
// Design Name: 
// Module Name: Crossover
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


module Crossover #(
    parameter int PROC_W = 3,
    parameter int TASK_W = 6
)(
    // Parent pairs (inputs)
    input  logic [PROC_W-1:0] proc_id_1,
    input  logic [TASK_W-1:0] task_id_1,

    input  logic [PROC_W-1:0] proc_id_2,
    input  logic [TASK_W-1:0] task_id_2,
    input  logic cross_enable,

    // Outputs: parents (pass-through)
    output logic [PROC_W-1:0] proc_p1,
    output logic [TASK_W-1:0] task_p1,
    output logic [PROC_W-1:0] proc_p2,
    output logic [TASK_W-1:0] task_p2,

    // Outputs: crossed children
    output logic [PROC_W-1:0] proc_c12,
    output logic [TASK_W-1:0] task_c12,
    output logic [PROC_W-1:0] proc_c21,
    output logic [TASK_W-1:0] task_c21
);

    // Parents unchanged
    assign proc_p1 = proc_id_1;
    assign task_p1 = task_id_1;

    assign proc_p2 = proc_id_2;
    assign task_p2 = task_id_2;

    // Children: swap TASK only (your example)
    assign proc_c12 = proc_id_1;
    assign task_c12 = cross_enable ? task_id_2 : task_id_1;

    assign proc_c21 = proc_id_2;
    assign task_c21 = cross_enable ? task_id_1 : task_id_2;

endmodule

