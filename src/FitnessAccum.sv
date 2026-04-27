`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/21/2026 10:59:05 AM
// Design Name: 
// Module Name: FitnessAccum
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
// FitnessAccum: schedule simulation accumulators for GA fitness metrics
//
// Assumptions (as you specified):
// - All tasks arrive at t=0
// - Execution time depends only on task (already provided as exec_time input)
// - You stream tasks as (proc_id, exec_time, deadline) in the desired order
//
// For each input task:
//   start  = proc_time[proc_id]
//   finish = start + exec_time
//   proc_time[proc_id] = finish
//   makespan = max(makespan, finish)
//   sum_RT  += start
//   sum_TAT += finish
//   dlm_count += (finish > deadline)
//   task_count++
//
// Outputs:
// - schedule_length = makespan
// - dlms            = deadline miss count
// - atat            = sum_TAT / 64  (>> 6)
// - art             = sum_RT  / 64  (>> 6)
// - done pulses when all 64 tasks have been consumed.
//
// Handshake:
// - in_valid / in_ready for the streamed task inputs
//------------------------------------------------------------------------------

module FitnessAccum #(
  parameter int NPROCS   = 16,
  parameter int NTASKS   = 64,
  parameter int EXEC_W   = 4,
  parameter int DEAD_W   = 8,
  parameter int PROC_W   = $clog2(NPROCS),

  // Time width sizing:
  // worst-case makespan = NTASKS * (2^EXEC_W - 1) = 64*15=960 -> needs 10 bits
  // add a bit or two for safety
  parameter int TIME_W   = 12,

  // Sum widths:
  // sum_TAT worst ~ NTASKS * makespan ~ 64*960=61440 -> 16 bits
  parameter int SUM_W    = 18,
  parameter int FIT_W    = 23
)(
  input  logic                 clk,
  input  logic                 rst,     // synchronous reset
  input  logic                 ff_en,
  input  logic                 clear_fit,  // start a new fitness calculation

  // Streamed inputs (from BRAM stage or other front-end)
  input logic                 in_ready,
  input  logic [PROC_W-1:0]    in_proc_id,
  input  logic [EXEC_W-1:0]    in_exec_time,
  input  logic [DEAD_W-1:0]    in_deadline,

  // Results
//  output logic                 done,              // 1-cycle pulse at end
//  output logic [TIME_W-1:0]    schedule_length,   // makespan
//  output logic [7:0]           dlms,              // up to 64 fits in 8 bits
//  output logic [TIME_W-1:0]    atat,              // avg turnaround = sum_tat >> 6
//  output logic [TIME_W-1:0]    art,               // avg response   = sum_rt  >> 6
  output logic [$clog2(NTASKS+1)-1:0] task_count,
  output logic [FIT_W-1 :0] fitness
);

  logic                 done;             // 1-cycle pulse at end
  logic [TIME_W-1:0]    schedule_length;   // makespan
  logic [7:0]           dlms;              // up to 64 fits in 8 bits
  logic [TIME_W-1:0]    atat;              // avg turnaround = sum_tat >> 6
  logic [TIME_W-1:0]    art;              // avg response   = sum_rt  >> 6

  logic [SUM_W-1:0]     sum_tat;
  logic [SUM_W-1:0]     sum_rt;
  
  // Per-processor running time (end time)
  logic [TIME_W-1:0] proc_time [0:NPROCS-1];

  // Internal regs
  logic [TIME_W-1:0] makespan_r;
  logic [7:0]        dlm_r;
  logic [SUM_W-1:0]  sum_tat_r, sum_rt_r;
  logic [$clog2(NTASKS+1)-1:0] count_r;

  // Combinational helpers for current input
  logic [TIME_W-1:0] start_t, finish_t;
  logic              miss_deadline;


//  assign fitness = 'd200 - atat - art - dlms - schedule_length;
//  assign fitness = 'd50 - atat - art - dlms;
  
    always_comb begin
    
      start_t       = proc_time[in_proc_id];
      finish_t      = start_t + {{(TIME_W-EXEC_W){1'b0}}, in_exec_time};
      miss_deadline = (finish_t > {{(TIME_W-DEAD_W){1'b0}}, in_deadline});
    
      // Outputs
      schedule_length = makespan_r;
      dlms            = miss_deadline ? dlm_r +1 : dlm_r;
      sum_tat         = sum_tat_r + {{(SUM_W-TIME_W){1'b0}}, finish_t};
      sum_rt          = sum_rt_r  + {{(SUM_W-TIME_W){1'b0}}, start_t};;
      task_count      = count_r;
    
      
      // Averages: since NTASKS=64, division is a right shift by 6
      // (If you later change NTASKS, update this logic accordingly.)
       atat = sum_tat[SUM_W-1:6]; // == sum_tat / 64
       
       art  = sum_rt [SUM_W-1:6]; // == sum_rt  / 64
    
    end

//    logic [TIME_W-1:0] inv_dlms, inv_sl, inv_art, inv_atat;
////    logic [4*TIME_W:0] fitness;
    
//    always_comb begin
//        inv_dlms = {TIME_W{1'b1}} - dlms;
//        inv_sl   = {TIME_W{1'b1}} - schedule_length;
//        inv_art  = {TIME_W{1'b1}} - art;
//        inv_atat = {TIME_W{1'b1}} - atat;
    
//        if (dlms == 0)
//            fitness = {1'b1, inv_sl, inv_art, inv_atat, {TIME_W{1'b1}}};
//        else
//            fitness = {1'b0, inv_dlms, inv_sl, inv_art, inv_atat};
//    end
    
    logic [3:0] dlms_q;
    logic [5:0] sl_q, art_q, atat_q;
    
    always_comb begin
        // Saturate / compress metrics into smaller fields
        dlms_q = (dlms > 15) ? 4'd15 : dlms[3:0];
    
        sl_q   = (schedule_length > 'd63) ? 6'd63 : schedule_length[5:0];
        art_q  = (art             > 'd63) ? 6'd63 : art[5:0];
        atat_q = (atat            > 'd63) ? 6'd63 : atat[5:0];
    
        if (dlms == 0)
            // best group: zero deadline misses
            fitness = {1'b1, ~sl_q, ~art_q, ~atat_q, 4'b1111};
        else
            // lower group: fewer misses first, then better timing metrics
            fitness = {1'b0, ~dlms_q, ~sl_q, ~art_q, ~atat_q};
    end
    
    
  // Control
  always_ff @(posedge clk) begin
    if (rst) begin
      done       <= 1'b0;
      makespan_r <= '0;
      dlm_r      <= '0;
      sum_tat_r  <= '0;
      sum_rt_r   <= '0;
      count_r    <= '0;
      for (int p = 0; p < NPROCS; p++) begin
        proc_time[p] <= '0;
      end
    end else if (ff_en) begin
      done <= 1'b0; // default

      // Start a new fitness accumulation
      if (clear_fit || (task_count == NTASKS-1)) begin
//      if ((task_count == NTASKS-1)) begin
        makespan_r <= '0;
        dlm_r      <= '0;
        sum_tat_r  <= '0;
        sum_rt_r   <= '0;
        count_r    <= '0;
        for (int p = 0; p < NPROCS; p++) begin
          proc_time[p] <= '0;
        end
      end else begin

      // Consume a task when valid & ready
      if (in_ready) begin
        // update per-processor time
        proc_time[in_proc_id] <= finish_t;

        // makespan
        if (finish_t > makespan_r)
          makespan_r <= finish_t;

        // sums for averages
        sum_rt_r  <= sum_rt;
        sum_tat_r <= sum_tat;

        dlm_r <= dlms;

        // count
        count_r <= count_r + 1;

        // Done condition (after consuming the last task)
        if (count_r == NTASKS - 1 ) begin
          done <= 1'b1; // pulse
          
          end
        end
      end
    end
  end

endmodule
