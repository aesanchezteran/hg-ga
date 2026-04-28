`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/27/2026 03:18:56 PM
// Design Name: 
// Module Name: Mutation
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


module Mutation #(
    parameter int TASK_W = 6
)(
    input  logic [TASK_W-1:0] rand_task1,
    input  logic [TASK_W-1:0] rand_task2,
    input  logic [TASK_W-1:0] rand_task3,
    input  logic [TASK_W-1:0] rand_task4,
    input logic mut_enable,

    input  logic [TASK_W-1:0] task_c21_mut,
    input  logic [TASK_W-1:0] task_c12_mut,

    output logic [TASK_W-1:0] task_c21_mut_d,
    output logic [TASK_W-1:0] task_c12_mut_d
);

    always_comb begin
        // defaults: pass-through
        task_c21_mut_d = task_c21_mut;
        task_c12_mut_d = task_c12_mut;
        if (mut_enable == 1'b1) begin
        // Only attempt "swap" if the two random tasks are different
        if (rand_task1 != rand_task2) begin
            if (rand_task1 == task_c21_mut)
                task_c21_mut_d = rand_task2;
            else if (rand_task2 == task_c21_mut)
                task_c21_mut_d = rand_task1;
        end

        if (rand_task3 != rand_task4) begin
            if (rand_task3 == task_c12_mut)
                task_c12_mut_d = rand_task4;
            else if (rand_task4 == task_c12_mut)
                task_c12_mut_d = rand_task3;
        end
        
        end
    end

endmodule
