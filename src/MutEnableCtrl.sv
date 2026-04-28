`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/11/2026 12:41:20 PM
// Design Name: 
// Module Name: MutEnableCtrl
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


module MutEnableCtrl #(
    parameter COUNT_MAX = 63
)(
    input  logic clk,
    input  logic rst,
    input  logic ff_en, 
    input  logic pipeline_enable,

    output logic mut_enable
);

    logic [5:0] counter;
    logic [1:0] start_delay;
    logic started;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            counter      <= 6'd0;
            start_delay  <= 2'd0;
            started      <= 1'b0;
            mut_enable   <= 1'b0;
        end 
        else if(ff_en) begin
            if (!pipeline_enable) begin
                counter      <= 6'd0;
                start_delay  <= 2'd0;
                started      <= 1'b0;
                mut_enable   <= 1'b0;
            end 
            else begin
                mut_enable <= 1'b0; // default
    
                // wait 2 cycles after pipeline_enable
                if (!started) begin
                    if (start_delay == 3) begin
                        mut_enable <= 1'b1;
                        started    <= 1'b1;
                        counter    <= 6'd0;
                    end
                    else begin
                        start_delay <= start_delay + 1'b1;
                    end
                end 
                else begin
                    if (counter == COUNT_MAX) begin
                        mut_enable <= 1'b1;
                        counter    <= 6'd0;
                    end
                    else begin
                        counter <= counter + 1'b1;
                    end
                end
            end
        end
    end

endmodule

//module CrossEnableCtrl #(
//    parameter COUNT_MAX = 63
//)(
//    input  logic clk,
//    input  logic rst,
//    input  logic pipeline_enable,

//    output logic rand_cross_enable
//);

//    logic [5:0] counter;
//    logic [1:0] start_delay;
//    logic started;

//    always_ff @(posedge clk or posedge rst) begin
//        if (rst) begin
//            counter      <= 6'd0;
//            start_delay  <= 2'd0;
//            started      <= 1'b0;
//            rand_cross_enable   <= 1'b0;
//        end 
//        else if (!pipeline_enable) begin
//            counter      <= 6'd0;
//            start_delay  <= 2'd0;
//            started      <= 1'b0;
//            rand_cross_enable   <= 1'b0;
//        end 
//        else begin
//            rand_cross_enable <= 1'b0; // default

//            // wait 2 cycles after pipeline_enable
//            if (!started) begin
//                if (start_delay == 1) begin
//                    rand_cross_enable <= 1'b1;
//                    started    <= 1'b1;
//                    counter    <= 6'd0;
//                end
//                else begin
//                    start_delay <= start_delay + 1'b1;
//                end
//            end 
//            else begin
//                if (counter == COUNT_MAX) begin
//                    rand_cross_enable <= 1'b1;
//                    counter    <= 6'd0;
//                end
//                else begin
//                    counter <= counter + 1'b1;
//                end
//            end
//        end
//    end

//endmodule