`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/10/2026 03:41:55 PM
// Design Name: 
// Module Name: SelectFillFSM
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


module SelectFillFSM #(
    parameter int MAX_DEPTH = 12
)(
    input  logic clk,
    input  logic rst,
    input  logic ff_en,
    input  logic pipeline_enable,
    input  logic ctrl_select,

    output logic [3:0] pool_count   // outputs 0,4,8,12
);

always_ff @(posedge clk) begin
    if (rst || !pipeline_enable) begin
        pool_count <= 4'd0;
    end
    else if (ctrl_select && ff_en) begin
        case (pool_count)
            4'd0  : pool_count <= 4'd4;
            4'd4  : pool_count <= 4'd8;
            4'd8  : pool_count <= 4'd12;
            4'd12 : pool_count <= 4'd12;
            default: pool_count <= 4'd0;
        endcase
    end
end

endmodule
