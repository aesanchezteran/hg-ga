`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/22/2026 07:35:36 PM
// Design Name: 
// Module Name: Register
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


module Register #(
    parameter int WIDTH = 8  // Default width is 8 bits
)(
    input  logic clk,              // Clock input
    input  logic rst,              // Active-high synchronous reset
    input logic en,
    input  logic [WIDTH-1:0] d,    // Data input
    output logic [WIDTH-1:0] q     // Data output (stored value)
);

    always_ff @(posedge clk) begin
        if (rst) begin
            q <= '0; 
        end else if (en) begin
            q <= d;   
        end
    end

endmodule

module Buffer #(
    parameter int WIDTH = 8  // Default data width
)(
    input  logic [WIDTH-1:0]   data_in,  // Input data
    output logic [WIDTH-1:0]   data_out  // Output data
);

    always_comb begin
            data_out = data_in;
    end

endmodule
