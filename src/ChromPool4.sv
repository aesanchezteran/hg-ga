`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/03/2026 02:55:59 PM
// Design Name: 
// Module Name: ChromPool4
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

module ChromPool4 #(
  parameter int DEPTH    = 12,   // total chromosomes stored (must be multiple of 4)
  parameter int NGENES   = 64,   // genes per chromosome (tasks)
  parameter int PROC_W   = 3,
  parameter int TASK_W   = 6,
  parameter int FIT_W    = 16,
  parameter int RD_PORTS = 6     // <-- NEW: number of combinational read ports
)(
  input  logic clk,
  input  logic rst,
  input  logic ff_en,

  input  logic en,
  input  logic clr,              // clears pool + pointers

  // -------------------------
  // Streaming gene input (4 lanes)
  // -------------------------
  input  logic                 gene_valid,
  input  logic                 gene_last,     
  input  logic                  select,
  input logic                   clr_upper_fit,
  input  logic [TASK_W-1:0]    task_in [4],
  input  logic [PROC_W-1:0]    proc_in [4],

  // -------------------------
  // Fitness input (once per chromosome)
  // -------------------------
  input  logic                 fit_valid,
  input  logic [FIT_W-1:0]     fit_in  [4],

  // -------------------------
  // Read interface (combinational)
  // 6 ports: each chooses a chromosome via rd_sel[p]
  // all ports read the SAME gene index rd_gene_idx
  // -------------------------
  input  logic [$clog2(DEPTH)-1:0]  rd_sel     [RD_PORTS],
  input  logic [$clog2(DEPTH)-1:0]  rd_sel_elite,
  input  logic [$clog2(NGENES)-1:0] rd_gene_idx,

  output logic [TASK_W-1:0] task_out [RD_PORTS],
  output logic [PROC_W-1:0] proc_out [RD_PORTS],
  output logic [TASK_W-1:0] task_out_elite,
  output logic [PROC_W-1:0] proc_out_elite,
  output logic [FIT_W-1:0]  fit_out  [RD_PORTS],
  output logic [FIT_W-1:0]  fit_out_elite,
  
  // NEW: export whole fitness array
  output logic [FIT_W-1:0]  fit_all  [DEPTH],
  output logic [FIT_W-1:0]  fit_all_decoded  [DEPTH],
  output logic [$clog2(DEPTH)-1:0]  chrom_count,

  output logic full          // pool cannot accept more chromosomes (wr_base at end)
);

  localparam int GENE_W = PROC_W + TASK_W;

  // gene_mem[chromosome_index][gene_index] = packed gene
  logic [GENE_W-1:0] gene_mem [0:DEPTH-1][0:NGENES-1];
  logic [FIT_W-1:0]  fit_mem  [0:DEPTH-1];
  logic [FIT_W-1:0]  fit_mem_Naccum  [0:DEPTH-1];


  // write pointers
  logic [$clog2(DEPTH)-1:0]   wr_base;       // base chromosome index for current 4-lane group
  logic [$clog2(NGENES)-1:0]  wr_gene_idx;   // current gene index within chromosome

  // NEW: remembers the base of the last completed 4-chrom group (for fitness writeback)
  logic [$clog2(DEPTH)-1:0]   last_group_base;

  // convenience
  function automatic logic [GENE_W-1:0] pack_gene(
    input logic [PROC_W-1:0] p,
    input logic [TASK_W-1:0] t
  );
    pack_gene = {p, t};
  endfunction

  // pool full when no room for next group of 4
  always_comb begin
    full = (wr_base > (DEPTH-4));
  end

  integer c, g;

  // -------------------------
  // Write logic
  // -------------------------
  always_ff @(posedge clk) begin
    if (rst) begin
      wr_base         <= '0;
      wr_gene_idx     <= '0;
      last_group_base <= '0;

      // optional clear memories on reset
      for (c = 0; c < DEPTH; c++) begin
        fit_mem[c] <= '0;
        fit_mem_Naccum[c] <= '0;
        for (g = 0; g < NGENES; g++) begin
          gene_mem[c][g] <= '0;
        end
      end
    chrom_count = 'd0;
    
    end else if (en) begin
      if (clr) begin
      chrom_count = 'd0;
        wr_base         <= '0;
        wr_gene_idx     <= '0;
        last_group_base <= '0;

        for (c = 0; c < DEPTH; c++) begin
          fit_mem[c] <= '0;
          fit_mem_Naccum[c] <= '0;
          for (g = 0; g < NGENES; g++) begin
            gene_mem[c][g] <= '0;
          end
        end

      end else begin
        // Write 4 genes in parallel (one gene per chrom)
        if (gene_valid && !full) begin
          gene_mem[wr_base + 0][wr_gene_idx] <= pack_gene(proc_in[0], task_in[0]);
          gene_mem[wr_base + 1][wr_gene_idx] <= pack_gene(proc_in[1], task_in[1]);
          gene_mem[wr_base + 2][wr_gene_idx] <= pack_gene(proc_in[2], task_in[2]);
          gene_mem[wr_base + 3][wr_gene_idx] <= pack_gene(proc_in[3], task_in[3]);

          // advance gene pointer
          if (gene_last) begin
            wr_gene_idx <= '0;
            if (select) begin
            wr_base     <= 'd0;
            end else begin
            wr_base     <= wr_base + 4;
            end
          end else begin
            wr_gene_idx <= wr_gene_idx + 1;
          end
        end

        // Store fitness (once per chromosome)
        // Writes into last completed group (safe if fit_valid comes after gene_last)
        if (fit_valid) begin
          if (clr_upper_fit || (wr_base == 'd0)) begin
          fit_mem[0] <= fit_in[0];
          fit_mem[1] <= fit_in[0] + fit_in[1];
          fit_mem[2] <= fit_in[0] + fit_in[1] + fit_in[2];
          fit_mem[3] <= fit_in[0] + fit_in[1] + fit_in[2] + fit_in[3];
          fit_mem_Naccum[0] <= fit_in[0];
          fit_mem_Naccum[1] <= fit_in[1];
          fit_mem_Naccum[2] <= fit_in[2];
          fit_mem_Naccum[3] <= fit_in[3];          
          for (c = 4; c < DEPTH; c++) begin
              fit_mem_Naccum[c] <= '0;
              fit_mem[c] <= '0;
          end
          chrom_count = 4;
          end else begin
          fit_mem[wr_base + 0] <= fit_mem[wr_base - 1 ] + fit_in[0];
          fit_mem[wr_base + 1] <= fit_mem[wr_base - 1 ] + fit_in[0] + fit_in[1];
          fit_mem[wr_base + 2] <= fit_mem[wr_base - 1 ] + fit_in[0] + fit_in[1] + fit_in[2];
          fit_mem[wr_base + 3] <= fit_mem[wr_base - 1 ] + fit_in[0] + fit_in[1] + fit_in[2] + fit_in[3];
          fit_mem_Naccum[wr_base + 0] <= fit_in[0];
          fit_mem_Naccum[wr_base + 1] <= fit_in[1];
          fit_mem_Naccum[wr_base + 2] <= fit_in[2];
          fit_mem_Naccum[wr_base + 3] <= fit_in[3];   
          chrom_count = chrom_count + 4;
          end
        end
      end
    end
  end

  // -------------------------
  // Combinational read (RD_PORTS outputs)
  // -------------------------
      logic [GENE_W-1:0] tmp_2;
  always_comb begin
    for (int p = 0; p < RD_PORTS; p++) begin
      logic [GENE_W-1:0] tmp;
      tmp = gene_mem[rd_sel[p]][rd_gene_idx];
      proc_out[p] = tmp[GENE_W-1 -: PROC_W];
      task_out[p] = tmp[TASK_W-1:0];
      fit_out[p]  = fit_mem[rd_sel[p]];
    end
    

    tmp_2 = gene_mem[rd_sel_elite][rd_gene_idx];
    proc_out_elite = tmp_2[GENE_W-1 -: PROC_W];
    task_out_elite = tmp_2[TASK_W-1:0];
    fit_out_elite = fit_mem[rd_sel_elite];
      
    // export whole fitness memory
    for (int i = 0; i < DEPTH; i++) begin
      fit_all[i] = fit_mem[i];
      fit_all_decoded [i] = fit_mem_Naccum[i];
    end
  end

endmodule
