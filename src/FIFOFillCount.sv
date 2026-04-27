`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/10/2026 05:32:22 PM
// Design Name: 
// Module Name: FIFOFillCount
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

module FIFOFillCount #(
    parameter int MAX_DEPTH = 12
)(
    input  logic clk,
    input  logic rst,
    input  logic ff_en,
    input  logic pipeline_enable,
    input  logic ctrl_select,

    output logic [3:0] FIFO_count   // outputs 0,4,8,12
);

always_ff @(posedge clk) begin
    if (rst || !pipeline_enable) begin
        FIFO_count <= 4'd0;
    end
    else if (ctrl_select && ff_en) begin
        case (FIFO_count)
            4'd0  : FIFO_count <= 4'd2;
            4'd2  : FIFO_count <= 4'd4;
            4'd4  : FIFO_count <= 4'd6;
            4'd6  : FIFO_count <= 4'd6;
            default: FIFO_count <= 4'd0;
        endcase
    end
end

endmodule
