`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/06/2026 05:31:43 PM
// Design Name: 
// Module Name: Input_Control
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


module Input_Control #(
    parameter int TASK_W = 6
)(
    input logic clk,
    input logic rst,
    input logic en,
    input logic pipeline_enable,
    output logic [TASK_W-1:0] gene_idx,
    output logic [3:0] chrom_sel_1,
    output logic [3:0] chrom_sel_2
    );
    
    logic count_en;
    logic [TASK_W-1:0] count;
    
    typedef enum logic [2:0] {
        IDLE,    
        CHROM_1_2,  
        CHROM_3_4,  
        CHROM_5_6,  
        CHROM_7_8,  
        CHROM_9_10, 
        CHROM_11_12,
        STOP
    } state_t;
    
    state_t state, next_state;
    
        // State register (sequential logic)
    always_ff @(posedge clk) begin
        if (rst)
            state <= IDLE;
        else if (en)
            state <= next_state;
    end
    
     // Next state logic
    always_comb begin
        // Default assignment to hold state
        next_state = state;

        case (state)
            IDLE: begin
                if (pipeline_enable)
                    next_state = CHROM_1_2;
            end
            CHROM_1_2: begin
                if (pipeline_enable && (count == 'd63))
                    next_state = CHROM_3_4;
            end
            CHROM_3_4: begin
                if (pipeline_enable && (count == 'd63))
                    next_state = CHROM_5_6;
            end
            CHROM_5_6: begin
                if (pipeline_enable && (count == 'd63))
                    next_state = CHROM_7_8;
            end
            CHROM_7_8: begin
                if (pipeline_enable && (count == 'd63))
                    next_state = CHROM_9_10;
            end
            CHROM_9_10: begin
                if (pipeline_enable && (count == 'd63))
                    next_state = CHROM_11_12;
            end
            CHROM_11_12: begin
                if (pipeline_enable && (count == 'd63))
                    next_state = STOP;
            end
            STOP: begin
                next_state = STOP;
            end

            default: next_state = IDLE; // Safety fallback
        endcase
    end
    
    always_comb begin
           count_en = 1'b0;
           gene_idx = count;
           chrom_sel_1 = 'd0;
           chrom_sel_2 = 'd0;
           
//        case (state)
//           IDLE: begin  
//           end
//           CHROM_1_2: begin  
//               chrom_sel_1 = 'd0;
//               chrom_sel_2 = 'd1;
//               count_en = 1'b1;
//           end
//           CHROM_3_4: begin  
//               chrom_sel_1 = 'd2;
//               chrom_sel_2 = 'd3;
//               count_en = 1'b1;
//           end
//           CHROM_5_6: begin  
//               chrom_sel_1 = 'd4;
//               chrom_sel_2 = 'd5;
//               count_en = 1'b1;
//           end
//           CHROM_7_8: begin  
//               chrom_sel_1 = 'd10;
//               chrom_sel_2 = 'd11;
//               count_en = 1'b1;
//           end
//           CHROM_9_10: begin  
//               chrom_sel_1 = 'd9;
//               chrom_sel_2 = 'd8;
//               count_en = 1'b1;
//           end
//           CHROM_11_12: begin  
//               chrom_sel_1 = 'd7;
//               chrom_sel_2 = 'd6;
//               count_en = 1'b1;
//           end
//           STOP: begin  
//               chrom_sel_1 = 'd0;
//               chrom_sel_2 = 'd0;
//               count_en = 1'b0;
//           end
//        endcase
        
        
        case (state)
           IDLE: begin  
           end
           CHROM_1_2: begin  
               chrom_sel_1 = 'd11;
               chrom_sel_2 = 'd10;
               count_en = 1'b1;
           end
           CHROM_3_4: begin  
               chrom_sel_1 = 'd9;
               chrom_sel_2 = 'd8;
               count_en = 1'b1;
           end
           CHROM_5_6: begin  
               chrom_sel_1 = 'd7;
               chrom_sel_2 = 'd0;
               count_en = 1'b1;
           end
           CHROM_7_8: begin  
               chrom_sel_1 = 'd6;
               chrom_sel_2 = 'd11;
               count_en = 1'b1;
           end
           CHROM_9_10: begin  
               chrom_sel_1 = 'd7;
               chrom_sel_2 = 'd8;
               count_en = 1'b1;
           end
           CHROM_11_12: begin  
               chrom_sel_1 = 'd8;
               chrom_sel_2 = 'd6;
               count_en = 1'b1;
           end
           STOP: begin  
               chrom_sel_1 = 'd0;
               chrom_sel_2 = 'd0;
               count_en = 1'b0;
           end
        endcase
        
    end
    
    
    counter #(
    .WIDTH(TASK_W)
    ) gene_counter (
        .clk(clk),
        .rst(rst),
        .en((count_en & en)),
        .count(count)
    );
    
endmodule
