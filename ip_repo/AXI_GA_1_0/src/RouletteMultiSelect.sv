`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/10/2026 12:48:14 PM
// Design Name: 
// Module Name: RouletteMultiSelect
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


//module RouletteMultiSelect #(
//    parameter int DEPTH      = 12,
//    parameter int NUM_SELECT = 6,
//    parameter int FIT_WIDTH  = 12
//)(
//    input  logic                             Sel_enable,
//    input  logic [FIT_WIDTH-1:0]             read_fit   [DEPTH],
//    input  logic [FIT_WIDTH-1:0]             rand_nums  [NUM_SELECT],
//    output logic [$clog2(DEPTH)-1:0]         read_addrs [NUM_SELECT]);

// logic [FIT_WIDTH-1:0] selected_idx [0:DEPTH-1];
// logic [$clog2(DEPTH)-1:0] selected_addr [0:DEPTH-1];
// integer i, j;

//always_comb begin
//    if (Sel_enable) begin
//        // Initialize all selected_idx and selected_addr
//        for (i = 0; i < DEPTH; i++) begin
//            selected_idx[i] = '0;
//            selected_addr[i] = '0;

//            // Build selection range
//            if (read_fit[DEPTH-1] > rand_nums[i]) begin
//                selected_idx[i][0] = 1;
//            end else begin
//                for (j = 1; j < DEPTH; j++) begin
//                    if (read_fit[DEPTH - j] <= rand_nums[i] && rand_nums[i] < read_fit[DEPTH-1 - j]) begin
//                        selected_idx[i][j] = 1;
//                    end
//                end
//            end

//            // Priority encoder: set selected_addr[i] = index of first '1' in selected_idx[i]
//            for (j = 0; j < DEPTH; j++) begin
//                if (selected_idx[i][j]) begin
//                    selected_addr[i] = j;
//                end
//            end
//        end
//    end else begin
//        // Reset all values when not enabled
//        for (i = 0; i < DEPTH; i++) begin
//            selected_idx[i] = '0;
//            selected_addr[i] = '0;
//        end
//    end

//    // Assign output
//    read_addrs = selected_addr;
//    end

//endmodule

//module RouletteMultiSelect #(
//    parameter int DEPTH      = 12,
//    parameter int NUM_SELECT = 6,
//    parameter int FIT_WIDTH  = 12
//)(
//    input  logic                             Sel_enable,
//    input  logic [FIT_WIDTH-1:0] read_fit   [0:DEPTH-1],
//    input  logic [FIT_WIDTH-1:0] rand_nums  [0:NUM_SELECT-1],
//    output logic [$clog2(DEPTH)-1:0] read_addrs [0:NUM_SELECT-1]);
    
//    integer i, j;
//    always_comb begin
//        // Default outputs
//        for (i = 0; i < NUM_SELECT; i++) begin
//            read_addrs[i] = '0;
//        end

//        if (Sel_enable) begin
//            for (i = 0; i < NUM_SELECT; i++) begin
//                // Default in case no interval matches
//                read_addrs[i] = '0;

//                // First interval: rand < read_fit[DEPTH-1]
//                if (rand_nums[i] < read_fit[DEPTH-1]) begin
//                    read_addrs[i] = 0;
//                end
//                else begin
//                    // Remaining intervals
//                    for (j = 1; j < DEPTH; j++) begin
//                        if ((read_fit[DEPTH-j] <= rand_nums[i]) &&
//                            (rand_nums[i] < read_fit[DEPTH-1-j])) begin
//                            read_addrs[i] = j[$clog2(DEPTH)-1:0];
//                        end
//                    end
//                end
//            end
//        end
//    end

//endmodule



module RouletteMultiSelect #(
    parameter int DEPTH      = 12,
    parameter int NUM_SELECT = 6,
    parameter int FIT_WIDTH  = 12
)(
    input  logic                               Sel_enable,

    input  logic [FIT_WIDTH-1:0]                read_fit   [0:DEPTH-1],
    input  logic [FIT_WIDTH-1:0]                rand_nums  [0:NUM_SELECT-1],

    input  logic [$clog2(DEPTH+1)-1:0]          pool_count,

    output logic [$clog2(DEPTH)-1:0]            read_addrs [0:NUM_SELECT-1]
);

always_comb begin

    for (int i = 0; i < NUM_SELECT; i++) begin

        read_addrs[i] = '0;

        if (Sel_enable && pool_count != 0) begin

            logic found;
            found = 1'b0;

            for (int j = 0; j < DEPTH; j++) begin

                if (!found && (j < pool_count)) begin

                    if (rand_nums[i] < read_fit[j]) begin
                        read_addrs[i] = j[$clog2(DEPTH)-1:0];
                        found = 1'b1;
                    end

                end

            end

        end

    end

end

endmodule