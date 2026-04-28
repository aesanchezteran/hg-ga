`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/16/2026 04:43:12 PM
// Design Name: 
// Module Name: FeedbackMux
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


module FeedbackMux #(
    parameter WIDTH = 32
)(
    input  logic [WIDTH-1:0] in_data,
    input  logic [WIDTH-1:0] feedback,
    input  logic             sel,
    output logic [WIDTH-1:0] out_data
);

    assign out_data = sel ? feedback : in_data;

endmodule
