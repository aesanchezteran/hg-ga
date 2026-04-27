`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/10/2026 04:14:51 PM
// Design Name: 
// Module Name: ChromFIFO
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


module ChromFIFO #(
    parameter NTASKS   = 64,
    parameter DEPTH    = 64,
    parameter TASK_W   = 6,
    parameter PROC_W   = 3,
    parameter MAX_WRITE = 6
)(
    input  logic clk,
    input  logic rst,
    input  logic ff_en,

    // write interface
    input  logic write_en,
    input  logic [2:0] n_write,              // 2 / 4 / 6 chromosomes arriving
    input  logic [$clog2(NTASKS)-1:0] sel_idx,

    input  logic [TASK_W-1:0] task_in [MAX_WRITE],
    input  logic [PROC_W-1:0] proc_in [MAX_WRITE],

    // read control
    input  logic read_en,
    input  logic read_two,                   // 0 = read 1 chrom, 1 = read 2

    // outputs
    output logic [TASK_W-1:0] task_out1,
    output logic [PROC_W-1:0] proc_out1,

    output logic [TASK_W-1:0] task_out2,
    output logic [PROC_W-1:0] proc_out2
);

    // ------------------------------------------------
    // memory
    // ------------------------------------------------

    logic [TASK_W-1:0] task_mem [DEPTH][NTASKS];
    logic [PROC_W-1:0] proc_mem [DEPTH][NTASKS];

    // ------------------------------------------------
    // FIFO pointers
    // ------------------------------------------------

    logic [$clog2(DEPTH)-1:0] write_ptr;
    logic [$clog2(DEPTH)-1:0] read_ptr;

    logic [$clog2(NTASKS)-1:0] gene_read_ptr;

    // ------------------------------------------------
    // WRITE + RESET
    // ------------------------------------------------

    always_ff @(posedge clk) begin

        if (rst) begin
            write_ptr     <= 0;

            for (int c = 0; c < DEPTH; c++) begin
                for (int g = 0; g < NTASKS; g++) begin
                    task_mem[c][g] <= '0;
                    proc_mem[c][g] <= '0;
                end
            end

        end
        else if (write_en && ff_en) begin

            for (int i = 0; i < MAX_WRITE; i++) begin
                if (i < n_write) begin

                    task_mem[(write_ptr)  + i][sel_idx] <= task_in[i];
                    proc_mem[(write_ptr) + i][sel_idx] <= proc_in[i];

                end
            end

            if (sel_idx == NTASKS-1)
                write_ptr <= ((write_ptr + n_write) % DEPTH);

        end
    end


    // ------------------------------------------------
    // READ
    // ------------------------------------------------

    always_ff @(posedge clk) begin
        if (rst) begin
            read_ptr      <= 0;
            gene_read_ptr <= 0;
        end
        else if (read_en && ff_en) begin

            gene_read_ptr <= gene_read_ptr + 1;

            if (gene_read_ptr == NTASKS-1) begin

                gene_read_ptr <= 0;

                if (read_two)
                    read_ptr <= (read_ptr + 2) % DEPTH;
                else
                    read_ptr <= (read_ptr + 1) % DEPTH;

            end

        end
    end


    // ------------------------------------------------
    // OUTPUTS
    // ------------------------------------------------

    assign task_out1 = task_mem[read_ptr][gene_read_ptr];
    assign proc_out1 = proc_mem[read_ptr][gene_read_ptr];

    assign task_out2 = task_mem[(read_ptr+1) % DEPTH][gene_read_ptr];
    assign proc_out2 = proc_mem[(read_ptr+1) % DEPTH][gene_read_ptr];

endmodule