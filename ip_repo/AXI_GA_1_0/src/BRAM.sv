`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/21/2026 10:42:47 AM
// Design Name: 
// Module Name: BRAM
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


//------------------------------------------------------------------------------
// Task parameter BRAMs (Execution Time + Deadline)
// - Depth: 64
// - Exec time width: 4
// - Deadline width : 8
// - Simple dual-port behavior: write on port A, read on port B
// - Synchronous read (registered outputs) -> 1-cycle latency
//------------------------------------------------------------------------------
//
// Read latency:
//   cycle k:    r_en=1, r_addr = task_id
//   cycle k+1:  r_exec_time, r_deadline valid
//
//------------------------------------------------------------------------------

module TaskParamBRAM #(
  parameter int NTASKS     = 64,
  parameter int EXEC_W     = 4,
  parameter int DEAD_W     = 8,
  parameter int ADDR_W     = $clog2(NTASKS)
)(
  input  logic              clk,
  input  logic              rst,
  input  logic              ff_en,

  // -------------------------
  // Write port (PS/config)
  // -------------------------
  input  logic              w_en,
  input  logic [ADDR_W-1:0] w_addr,
  input  logic [EXEC_W-1:0] w_exec_time,
  input  logic [DEAD_W-1:0] w_deadline,

  // -------------------------
  // Read port (fitness)
  // -------------------------
  input  logic              r_en,
  input  logic [ADDR_W-1:0] r_addr,
  output logic [EXEC_W-1:0] r_exec_time,
  output logic [DEAD_W-1:0] r_deadline
);

  // Inference hints for Xilinx BRAM
  (* ram_style = "block" *) logic [EXEC_W-1:0] exec_mem [0:NTASKS-1];
  (* ram_style = "block" *) logic [DEAD_W-1:0] dead_mem [0:NTASKS-1];

  // Optional: registered address for synchronous read
  logic [ADDR_W-1:0] r_addr_q;
  logic              r_en_q;

  integer i;

  always_ff @(posedge clk) begin
    if (rst) begin
      r_addr_q   <= '0;
      r_en_q     <= 1'b0;
      r_exec_time <= '0;
      r_deadline  <= '0;
    end else if (ff_en) begin
      // Write (port A)
      if (w_en) begin
        exec_mem[w_addr] <= w_exec_time;
        dead_mem[w_addr] <= w_deadline;
      end

      // Latch read request (port B)
      r_addr_q <= r_addr;
      r_en_q   <= r_en;

      // Registered read data (1-cycle latency after r_en)
      if (r_en_q) begin
        r_exec_time <= exec_mem[r_addr_q];
        r_deadline  <= dead_mem[r_addr_q];
      end
    end
  end

endmodule
