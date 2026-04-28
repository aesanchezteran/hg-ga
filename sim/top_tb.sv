`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/27/2026 10:50:08 AM
// Design Name: 
// Module Name: top_tb
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


module top_tb;
    
  `include "tasksets_500.svh"
  // ----------------------------
  // Parameters
  // ----------------------------
//  localparam int NTASKS = 64;
  localparam int NPROCS = 16;

//  localparam int EXEC_W = 8;
  localparam int DEAD_W = 8;

  localparam int TASK_W = $clog2(NTASKS); // 6
  localparam int PROC_W = $clog2(NPROCS); // 4

  localparam int TIME_W = 12;
  localparam int SUM_W  = 18;
  localparam FIT_W = 23;
  
  localparam int BENCHMARKS = 500;


  // ----------------------------
  // Clock / reset
  // ----------------------------
  logic clk, rst;

  initial clk = 1'b0;
  always #4 clk = ~clk;

// ------------------------------------------------------------------------------
    // Registros provenientes de AXI
    logic [31:0] exec_reg     [16];
    logic [31:0] deadline_reg [16];
    
//    logic [3:0]    ff_count;
//      logic ff_en;
//    counter #(
//        .WIDTH(4)
//    ) ff_divider (
//        .clk   (clk),
//        .rst   (rst),
//        .en    (1'b1),
//        .count (ff_count)
//    );
    
    assign ff_en = 1'b1;

    // ----------------------------
    // BRAM ports
    // ----------------------------
    logic                 w_en_ctrl;
    logic [TASK_W-1:0]    w_addr_ctrl;
    logic [EXEC_W-1:0]    w_exec_time_ctrl;
    logic [DEAD_W-1:0]    w_deadline_ctrl;
    logic pipeline_enable;
    logic [FIT_W-1:0] elite_best_fit;
    logic [TASK_W-1:0] elite_best_task [NTASKS];
    logic [PROC_W-1:0] elite_best_proc [NTASKS];
    logic [EXEC_W*NTASKS-1:0] exec_reg_flat;
    logic [DEAD_W*NTASKS-1:0] deadline_reg_flat;
    logic [TASK_W*NTASKS-1:0] elite_best_task_flat;
    logic [PROC_W*NTASKS-1:0] elite_best_proc_flat;
    
    logic start;
    
    
    Multiprocessor_GA_System #(
        .NPROCS (NPROCS),
        .NTASKS (NTASKS),
        .EXEC_W (EXEC_W),
        .DEAD_W (DEAD_W),
        .TASK_W (TASK_W),
        .PROC_W (PROC_W),
        .TIME_W (TIME_W),
        .SUM_W  (SUM_W)
    ) dut (
        .sysclk(clk),
        .sysrst(rst),
        .start(start),
        .exec_reg_flat(exec_reg_flat),
        .deadline_reg_flat(deadline_reg_flat),
        .elite_best_fit(elite_best_fit),
        .elite_best_task_flat (elite_best_task_flat),
        .elite_best_proc_flat (elite_best_proc_flat)
    );

    // --------------------------------------------------
    // Per-processor accumulated execution time
    // --------------------------------------------------
    integer proc_time [NPROCS];
    // --------------------------------------------------
    // Per-task metrics
    // --------------------------------------------------
    integer start_time     [NTASKS];
    integer finish_time    [NTASKS];
    integer response_time  [NTASKS];
    integer turnaround_time[NTASKS];
    integer missed_deadline[NTASKS];
    // --------------------------------------------------
    // Totals
    // --------------------------------------------------
    real total_rt;
    real total_tat;
    integer total_misses;
    real art, atat;
    integer atat_g, art_g;
    integer i, j, b, k;
    integer pid;
    integer tasks_per_proc [0:NPROCS-1];
    // --------------------------------------------------
    // Storage for benchmark results
    // --------------------------------------------------
    logic [TASK_W-1:0] sched_task_mem [BENCHMARKS][NTASKS];
    logic [PROC_W-1:0] sched_proc_mem [BENCHMARKS][NTASKS]; 
    integer            dlm_mem       [BENCHMARKS];
    real               art_mem       [BENCHMARKS];
    real               atat_mem      [BENCHMARKS];
    logic [TIME_W-1:0] best_fit_mem  [BENCHMARKS];
    integer fd_metrics;
    integer fd_sched;
    integer fd;
    logic [EXEC_W-1:0] exec_tbl [0:NTASKS-1];
    logic [DEAD_W-1:0] dead_tbl [0:NTASKS-1];
    // --------------------------------------------------
    // Storage for benchmark results
    // --------------------------------------------------
    logic [TASK_W-1:0] sched_task_mem [BENCHMARKS][NTASKS];
    logic [PROC_W-1:0] sched_proc_mem [BENCHMARKS][NTASKS];
    integer            dlm_mem      [BENCHMARKS];
    real               art_mem      [BENCHMARKS];
    real               atat_mem     [BENCHMARKS];
    logic [TIME_W-1:0] best_fit_mem [BENCHMARKS];
    integer start_time_mem  [BENCHMARKS][NTASKS];
    integer finish_time_mem [BENCHMARKS][NTASKS];
    
    always_comb begin
        for (i = 0; i < NTASKS; i++) begin
            elite_best_task[i] = elite_best_task_flat[i*TASK_W +: TASK_W];
            elite_best_proc[i] = elite_best_proc_flat[i*PROC_W +: PROC_W];
        end
    end


  initial begin
    // Defaults
    fd_metrics = $fopen("benchmark_metrics_9_test.csv", "w");
    fd_sched   = $fopen("benchmark_schedules_9_test.csv", "w");

    if (fd_metrics == 0) begin
        $error("Could not open benchmark_metrics.csv");
        $finish;
    end

    if (fd_sched == 0) begin
        $error("Could not open benchmark_schedules.csv");
        $finish;
    end
      
    // CSV headers
    $fdisplay(fd_metrics, "benchmark,art,atat,dlm,best_fit");
    $fdisplay(fd_sched,   "benchmark,position,task_id,proc_id,start_time,finish_time");
            
    rst = 1'b1;
    start =1'b0;
    pipeline_enable = 1'b0;
    // Reset
    repeat (4) @(posedge clk);
    rst = 1'b0;

    for (int k=0; k<10; k++) begin

        start =1'b0;
        
        load_taskset(k);
        load_taskset_regs(k);
        load_taskset_flat(k);
        
//        print_current_taskset_regs(k);
        verify_current_taskset_regs(k);
        
        repeat (5) @(negedge clk);
        start =1'b1;

        repeat (73) @(negedge clk);
    
        repeat (200000) @(posedge clk);    
        pipeline_enable = 1'b0;
        start = 1'b0;
//        unpack_elite_flat();
        repeat (100) @(posedge clk);    
    
        compute_schedule_metrics_from_elite();

//        print_tasks_per_processor();
//        print_elite_schedule_genes();
        check_elite_permutation();

        $display("========================================");
        $display("ELITE CHROMOSOME METRICS");
        $display("Benchmark        = %0d", k);
        $display("best_fit         = %0d", elite_best_fit[22:0]);
        $display("ART              = %0f", art);
        $display("ATAT             = %0f", atat);
        $display("Deadline misses  = %0d", total_misses);
        
        // -----------------------------
        // Store and dump CSV
        // -----------------------------
        store_results(k);
        dump_metrics_csv(fd_metrics, k);
        dump_schedule_csv(fd_sched, k);
        repeat (100) @(posedge clk);   
    end
    
    $fclose(fd_metrics);
    $fclose(fd_sched);
    $finish;
    
    end








////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////// TASKS ///////////////////////////////////////////////////
    task automatic check_elite_permutation;
        int i, j;
        int count [NTASKS];
        bit valid;
        begin
            valid = 1;
    
            for (i = 0; i < NTASKS; i++) begin
                count[i] = 0;
            end
    
            for (i = 0; i < NTASKS; i++) begin
                if (elite_best_task[i] < 0 || elite_best_task[i] >= NTASKS) begin
                    $display("ERROR: task out of range at gene %0d -> %0d", i, elite_best_task[i]);
                    valid = 0;
                end
                else begin
                    count[elite_best_task[i]]++;
                end
            end
    
            for (i = 0; i < NTASKS; i++) begin
                if (count[i] == 0) begin
                    $display("ERROR: missing task %0d", i);
                    valid = 0;
                end
                else if (count[i] > 1) begin
                    $display("ERROR: duplicated task %0d appears %0d times", i, count[i]);
                    valid = 0;
                end
            end
    
            if (valid)
                $display("Elite chromosome is a valid permutation.");
            else
                $display("Elite chromosome is NOT a valid permutation.");
        end
    endtask
    
    task automatic unpack_elite_flat;
        int i;
        begin
            for (i = 0; i < NTASKS; i++) begin
                elite_best_task[i] = elite_best_task_flat[i*TASK_W +: TASK_W];
                elite_best_proc[i] = elite_best_proc_flat[i*PROC_W +: PROC_W];
            end
        end
    endtask
    
    task automatic load_taskset_flat(input int idx);
        int i;
        begin
            if ((idx < 0) || (idx >= BENCHMARKS)) begin
                $error("load_taskset_flat: index %0d out of range [0:%0d]", idx, BENCHMARKS-1);
            end
            else begin
                for (i = 0; i < NTASKS; i++) begin
                    exec_reg_flat[i*EXEC_W +: EXEC_W]         = exec_sets[idx][i];
                    deadline_reg_flat[i*DEAD_W +: DEAD_W]    = dead_sets[idx][i];
                end
            end
        end
    endtask
    
    task automatic load_taskset(input int idx);
        int i;
        begin
            if ((idx < 0) || (idx >= BENCHMARKS)) begin
                $error("load_taskset: index %0d out of range [0:%0d]", idx, BENCHMARKS-1);
            end
            else begin
                for (i = 0; i < NTASKS; i++) begin
                    exec_tbl[i] = exec_sets[idx][i];
                    dead_tbl[i] = dead_sets[idx][i];
                end
            end
        end
    endtask
    
    task automatic load_taskset_regs(input int idx);
        int i;
        int base;
        begin
            if ((idx < 0) || (idx >= BENCHMARKS)) begin
                $error("load_taskset_regs: index %0d out of range [0:%0d]", idx, BENCHMARKS-1);
            end
            else begin
                for (i = 0; i < 16; i++) begin
                    base = i * 4;
    
                    exec_reg[i] = {
                        exec_sets[idx][base+3],
                        exec_sets[idx][base+2],
                        exec_sets[idx][base+1],
                        exec_sets[idx][base+0]
                    };
    
                    deadline_reg[i] = {
                        dead_sets[idx][base+3],
                        dead_sets[idx][base+2],
                        dead_sets[idx][base+1],
                        dead_sets[idx][base+0]
                    };
                end
            end
        end
    endtask

    task automatic print_current_taskset(input int idx);
        int i;
        begin
            $display("\n==============================");
            $display("Benchmark %0d", idx);
            $display("==============================");
            for (i = 0; i < NTASKS; i++) begin
                $display("Task %0d: exec=%0d deadline=%0d",
                         i, exec_tbl[i], dead_tbl[i]);
            end
        end
    endtask

    task automatic print_current_taskset_regs(input int idx);
        int i;
        int reg_idx;
        int sub_idx;
        logic [EXEC_W-1:0] exec_val;
        logic [DDL_W-1:0]  dead_val;
        begin
            $display("\n==============================");
            $display("Benchmark %0d from AXI regs", idx);
            $display("==============================");
    
            for (i = 0; i < NTASKS; i++) begin
                reg_idx = i / 4;
                sub_idx = i % 4;
    
                exec_val = exec_reg[reg_idx][sub_idx*EXEC_W +: EXEC_W];
                dead_val = deadline_reg[reg_idx][sub_idx*DDL_W +: DDL_W];
    
                $display("Task %0d: exec=%0d deadline=%0d",
                         i, exec_val, dead_val);
            end
        end
    endtask
    
    task automatic verify_current_taskset_regs(input int idx);
        int i;
        int reg_idx;
        int sub_idx;
        int err_count;
        logic [EXEC_W-1:0] exec_val;
        logic [DDL_W-1:0]  dead_val;
        begin
            err_count = 0;
    
            if ((idx < 0) || (idx >= BENCHMARKS)) begin
                $error("verify_current_taskset_regs: index %0d out of range [0:%0d]", idx, BENCHMARKS-1);
            end
            else begin
                for (i = 0; i < NTASKS; i++) begin
                    reg_idx = i / 4;
                    sub_idx = i % 4;
    
                    exec_val = exec_reg[reg_idx][sub_idx*EXEC_W +: EXEC_W];
                    dead_val = deadline_reg[reg_idx][sub_idx*DDL_W +: DDL_W];
    
                    if ((exec_val !== exec_sets[idx][i]) || (dead_val !== dead_sets[idx][i])) begin
                        err_count++;
                        $display("Mismatch Task %0d -> exec=%0d expected=%0d | deadline=%0d expected=%0d",
                                 i, exec_val, exec_sets[idx][i], dead_val, dead_sets[idx][i]);
                    end
                end
    
                if (err_count == 0) begin
                    $display("verify_current_taskset_regs: Benchmark %0d OK, all %0d tasks match.", idx, NTASKS);
                end
                else begin
                    $display("verify_current_taskset_regs: Benchmark %0d FAILED, mismatches=%0d.", idx, err_count);
                end
            end
        end
    endtask





    task automatic store_results(input int idx);
        int j;
        begin
            if ((idx < 0) || (idx >= BENCHMARKS)) begin
                $error("store_results: index %0d out of range [0:%0d]", idx, BENCHMARKS-1);
            end
            else begin
                for (j = 0; j < NTASKS; j++) begin
                    sched_task_mem[idx][j]  = elite_best_task[j];
                    sched_proc_mem[idx][j]  = elite_best_proc[j];
                    start_time_mem[idx][j]  = start_time[j];
                    finish_time_mem[idx][j] = finish_time[j];
                end
    
                art_mem[idx]      = art;
                atat_mem[idx]     = atat;
                dlm_mem[idx]      = total_misses;
                best_fit_mem[idx] = elite_best_fit;
            end
        end
    endtask
    
    task automatic print_stored_results(input int idx);
        int j;
        begin
            $display("========================================");
            $display("STORED RESULTS FOR BENCHMARK %0d", idx);
            $display("best_fit         = %0d", best_fit_mem[idx]);
            $display("ART              = %0f", art_mem[idx]);
            $display("ATAT             = %0f", atat_mem[idx]);
            $display("Deadline misses  = %0d", dlm_mem[idx]);
    
            $display("Schedule (task -> proc):");
            for (j = 0; j < NTASKS; j++) begin
                $display("  Pos %0d: task %0d -> proc %0d",
                         j, sched_task_mem[idx][j], sched_proc_mem[idx][j]);
            end
        end
    endtask
    
   task automatic dump_metrics_csv(input integer fd, input int idx);
        begin
            $fdisplay(fd, "%0d,%0f,%0f,%0d,%0d",
                      idx,
                      art_mem[idx],
                      atat_mem[idx],
                      dlm_mem[idx],
                      best_fit_mem[idx]);
        end
    endtask
    
    task automatic dump_schedule_csv(input integer fd, input int idx);
        int j;
        begin
            for (j = 0; j < NTASKS; j++) begin
                $fdisplay(fd, "%0d,%0d,%0d,%0d,%0d,%0d",
                          idx,                    // benchmark
                          j,                      // schedule position
                          sched_task_mem[idx][j], // task id
                          sched_proc_mem[idx][j], // proc id
                          start_time_mem[idx][j], // start time
                          finish_time_mem[idx][j] // finish time
                );
            end
        end
    endtask
    
    task automatic compute_schedule_metrics_from_elite;
        int i;
        int task_id;
        int proc_id;
        int exec_t;
        int ddl;
        int rel_t;
        begin
            // -----------------------------
            // Initialize
            // -----------------------------
            total_rt     = 0;
            total_tat    = 0;
            total_misses = 0;
    
            for (i = 0; i < NPROCS; i++) begin
                proc_time[i]      = 0;
                tasks_per_proc[i] = 0;
            end
    
            for (i = 0; i < NTASKS; i++) begin
                start_time[i]      = 0;
                finish_time[i]     = 0;
                response_time[i]   = 0;
                turnaround_time[i] = 0;
                missed_deadline[i] = 0;
            end
    
            // -----------------------------
            // Reconstruct schedule from elite chromosome
            // -----------------------------
            for (i = 0; i < NTASKS; i++) begin
                task_id = elite_best_task[i];
                proc_id = elite_best_proc[i];
    
                exec_t = exec_tbl[task_id];
                ddl    = dead_tbl[task_id];
                rel_t  = 0;   // assumed release time = 0 for all tasks
    
                start_time[i]  = proc_time[proc_id];
                finish_time[i] = start_time[i] + exec_t;
    
                response_time[i]   = start_time[i]  - rel_t;
                turnaround_time[i] = finish_time[i] - rel_t;
    
                if (finish_time[i] > ddl) begin
                    missed_deadline[i] = 1;
                    total_misses++;
                end
    
                proc_time[proc_id] = finish_time[i];
                tasks_per_proc[proc_id]++;
    
                total_rt  += response_time[i];
                total_tat += turnaround_time[i];
            end
    
            // -----------------------------
            // Averages
            // -----------------------------
            art  = total_rt  * 1.0 / NTASKS;
            atat = total_tat * 1.0 / NTASKS;
        end
    endtask
    
    task automatic print_tasks_per_processor;
        int i;
        begin
            for (i = 0; i < NPROCS; i++) begin
                $display("Processor %0d completed %0d tasks", i, tasks_per_proc[i]);
            end
            $display("========================================");
        end
    endtask
    
    task automatic print_elite_schedule_genes;
        int i;
        int task_id;
        int proc_id;
        int ddl;
        begin
            for (i = 0; i < NTASKS; i++) begin
                task_id = elite_best_task[i];
                proc_id = elite_best_proc[i];
                ddl     = dead_tbl[task_id];
    
                $display("gene %0d -> task=%0d proc=%0d start=%0d finish=%0d deadline=%0d miss=%0d",
                         i,
                         task_id,
                         proc_id,
                         start_time[i],
                         finish_time[i],
                         ddl,
                         missed_deadline[i]);
            end
            $display("========================================");
        end
    endtask



endmodule
