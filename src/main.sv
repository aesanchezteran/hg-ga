`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/21/2026 10:46:48 AM
// Design Name: 
// Module Name: main
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
// FitnessWithTaskBRAM_min
// Wrapper with ONLY:
//   - TaskParamBRAM
//   - FitnessAccum
//
// NO FSM / NO internal control.
// The TB (or top-level) must drive:
//   - bram_r_en / bram_r_addr
//   - fit_in_valid / fit_proc_id / fit_exec_time / fit_deadline
//
// This is ideal for your current bring-up / debug flow.
//------------------------------------------------------------------------------

module Multiprocessor_GA #(
  parameter int NPROCS   = 16,
  parameter int NTASKS   = 64,
  parameter int EXEC_W   = 8,
  parameter int DEAD_W   = 8,
  parameter int TASK_W   = $clog2(NTASKS),
  parameter int PROC_W   = $clog2(NPROCS),
  parameter int TIME_W   = 12,
  parameter int SUM_W    = 18,
  parameter int WIDTH = 7,
  parameter int NUM_CHANNELS = 6,
  parameter int WIDTH_OUT = 32,
  parameter int FIT_W = 23
)(
    input  logic                 clk,
    input  logic                 rst,     // synchronous reset
    input logic                  ff_en,
    
    // -------------------------
    // BRAM write port (PS/config)
//    // -------------------------
    input  logic                 w_en,
    input  logic [TASK_W-1:0]    w_addr,
    input  logic [EXEC_W-1:0]    w_exec_time,
    input  logic [DEAD_W-1:0]    w_deadline,

    input  logic                 pipeline_enable,

    output logic [FIT_W-1:0] elite_best_fit,
    output logic [TASK_W-1:0] elite_best_task [NTASKS],
    output logic [PROC_W-1:0] elite_best_proc [NTASKS]
);


    // Chromosomes input
    logic [$clog2(NTASKS+1)-1:0] task_count;
    logic [TASK_W-1:0] task_id_rom_1, task_id_rom_2;
    logic [WIDTH_OUT-1 : 0] rand1;
    logic [PROC_W-1: 0] proc_id_1, proc_id_2;
    
    logic [TASK_W-1:0] gene_idx;
    logic [3:0] ctrl_chrom_sel_1, ctrl_chrom_sel_2;
    logic [PROC_W-1:0] mux_proc_out, mux_proc_out_2;
    logic [TASK_W-1:0] mux_task_out, mux_task_out_2;
    logic gene_valid;
    
    
    logic Ctrl_clr_fit, Ctrl_bram_r_en, Ctrl_fit_in_ready, Ctrl_fifo_read_en, Ctrl_fifo_read_two;
    
    System_Control_FSM u_system_ctrl (
    .clk          (clk),
    .rst          (rst),
    .pipeline_enable(pipeline_enable),
    .ff_en (ff_en),

    .clr_fit      (Ctrl_clr_fit),
    .bram_r_en    (Ctrl_bram_r_en),
    .fit_in_ready (Ctrl_fit_in_ready),
    .fifo_read_en (Ctrl_fifo_read_en),
    .fifo_read_two(Ctrl_fifo_read_two)
    );
    
    logic    clear_fit; 
    logic    bram_r_en;
    logic    fit_in_ready;
    logic    fifo_read_en;
    logic    fifo_read_two; 
    
    always_comb begin
        clear_fit = Ctrl_clr_fit;
        bram_r_en = Ctrl_bram_r_en;
        fit_in_ready = Ctrl_fit_in_ready;
        fifo_read_en = Ctrl_fifo_read_en;
        fifo_read_two = Ctrl_fifo_read_two;
    end
    
    assign gene_valid = fit_in_ready;
       
        
    Input_Control #(
    .TASK_W(TASK_W)
    ) u_input_control (
        .clk(clk),
        .rst(rst),
        .en(ff_en),
        .pipeline_enable(pipeline_enable),
        .gene_idx(gene_idx),
        .chrom_sel_1(ctrl_chrom_sel_1),
        .chrom_sel_2(ctrl_chrom_sel_2)
    );
    
    task_perm_rom  u_task_perm_rom (
      .clk       (clk),
      .ff_en     (ff_en),
      .chrom_sel (ctrl_chrom_sel_1),
      .gene_idx  (gene_idx),
      .task_id   (task_id_rom_1)
    );
    
    task_perm_rom  u_task_perm_rom_2 (
      .clk       (clk),
      .ff_en     (ff_en),
      .chrom_sel (ctrl_chrom_sel_2),
      .gene_idx  (gene_idx),
      .task_id   (task_id_rom_2)
    );
    
    RandGen #(
        .WIDTH(WIDTH),
        .NUM_CHANNELS(NUM_CHANNELS),
        .WIDTH_OUT(WIDTH_OUT)
    ) RNG0 (
        .clk(clk),
        .rst(rst),
        .en((pipeline_enable && ff_en)),
        .rand_out(rand1)
    );
    
    assign proc_id_1 = rand1[PROC_W-1: 0];
    assign proc_id_2 = rand1[PROC_W+PROC_W-1: PROC_W];
    
    
    logic [PROC_W-1: 0] proc_id_1_cross, proc_id_2_cross;
    logic [TASK_W-1:0] task_id_rom_1_cross, task_id_rom_2_cross;
        
    Register #(
    .WIDTH((2*PROC_W)+(2*TASK_W))
    ) Pipeline_Stage_1 (
        .clk(clk),
        .rst(rst),
        .en((pipeline_enable && ff_en)),
        .d({mux_proc_out_2, mux_proc_out, mux_task_out_2, mux_task_out}),
        .q({proc_id_2_cross, proc_id_1_cross, task_id_rom_2_cross, task_id_rom_1_cross})
    );
    
    // Crossover Modules
    
    // Parent 1 (unchanged)
    logic [PROC_W-1:0] proc_p1;
    logic [TASK_W-1:0] task_p1;
    
    // Parent 2 (unchanged)
    logic [PROC_W-1:0] proc_p2;
    logic [TASK_W-1:0] task_p2;
    
    // Child 1-2 (P1 + T2)
    logic [PROC_W-1:0] proc_c12;
    logic [TASK_W-1:0] task_c12;
    
    // Child 2-1 (P2 + T1)
    logic [PROC_W-1:0] proc_c21;
    logic [TASK_W-1:0] task_c21;
    logic cross_enable, rand_cross_enable;
    logic [15:0] rand_mut, rand_cross;
    logic [15:0] mut_rate, cross_rate;
    
//    assign cross_rate = 'd58981;   // Maximo 65535 // 90% ='d58981
////    assign mut_rate = 'd6553;   // Maximo 65535 // 90% ='d58981
//    assign mut_rate = 'd58981;   // Maximo 65535 // 90% ='d58981
    
    
//    CrossEnableCtrl u_cross_enable_ctrl (
//        .clk(clk),
//        .rst(rst),
//        .pipeline_enable(pipeline_enable),
//        .rand_cross_enable(rand_cross_enable)
//    );
    
//    RandGen #(
//        .WIDTH(WIDTH),
//        .NUM_CHANNELS(NUM_CHANNELS),
//        .WIDTH_OUT(WIDTH_OUT)
//    ) RNG_cross_mut (
//        .clk(clk),
//        .rst(rst),
//        .en(rand_cross_enable),
//        .rand_out({rand_cross})
//    );
    
//    assign cross_enable = (rand_cross <= cross_rate) ? 1'b1 : 1'b0;
    assign cross_enable = 1'b1;

    Crossover #(
    .PROC_W(PROC_W),
    .TASK_W(TASK_W)
    ) u_crossover (
        // Parent 1 (from pipeline stage 1)
        .proc_id_1 (proc_id_1_cross),
        .task_id_1 (task_id_rom_1_cross),
    
        // Parent 2 (from pipeline stage 1)
        .proc_id_2 (proc_id_2_cross),
        .task_id_2 (task_id_rom_2_cross),
        .cross_enable(cross_enable),
    
        // Parents (pass-through)
        .proc_p1   (proc_p1),
        .task_p1   (task_p1),
        .proc_p2   (proc_p2),
        .task_p2   (task_p2),
    
        // Crossed children
        .proc_c12  (proc_c12),
        .task_c12  (task_c12),
        .proc_c21  (proc_c21),
        .task_c21  (task_c21)
    );

    // Parents (registered)
    logic [PROC_W-1:0] proc_p1_mut;
    logic [TASK_W-1:0] task_p1_mut;
    
    logic [PROC_W-1:0] proc_p2_mut;
    logic [TASK_W-1:0] task_p2_mut;
    
    // Children (registered)
    logic [PROC_W-1:0] proc_c12_mut;
    logic [TASK_W-1:0] task_c12_mut;
    
    logic [PROC_W-1:0] proc_c21_mut;
    logic [TASK_W-1:0] task_c21_mut;
    
    Register #(
        .WIDTH(4*(PROC_W + TASK_W))
    ) pipeline_stage_2 (
        .clk(clk),
        .rst(rst),
        .en(pipeline_enable && ff_en),
    
        .d({
            proc_c21, task_c21,   // child 2–1
            proc_c12, task_c12,   // child 1–2
            proc_p2,  task_p2,    // parent 2
            proc_p1,  task_p1     // parent 1
        }),
    
        .q({
            proc_c21_mut, task_c21_mut,
            proc_c12_mut, task_c12_mut,
            proc_p2_mut,  task_p2_mut,
            proc_p1_mut,  task_p1_mut
        })
    );
    
    // Mutation Module

    logic [TASK_W-1:0] rand_task1, rand_task2, rand_task3, rand_task4;
    logic mut_enable, rand_mut_enable;

    MutEnableCtrl u_mut_enable_ctrl (
        .clk(clk),
        .rst(rst),
        .ff_en(ff_en),
        .pipeline_enable(pipeline_enable),
        .mut_enable(rand_mut_enable)
    );
    
    RandGen #(
        .WIDTH(WIDTH),
        .NUM_CHANNELS(NUM_CHANNELS),
        .WIDTH_OUT(WIDTH_OUT)
    ) RNG1 (
        .clk(clk),
        .rst(rst),
        .en(rand_mut_enable && ff_en),
        .rand_out({rand_task1, rand_task2, rand_task3, rand_task4})
    );
    
//    assign rand_mut = {rand_task2, rand_task3, rand_task4};
//    assign mut_enable = (rand_mut <= mut_rate) ? 1'b1 : 1'b0;
    assign mut_enable = 1'b1;
    
    logic [TASK_W-1:0] task_c21_mut_d, task_c12_mut_d;

    Mutation #(
        .TASK_W(TASK_W)
    ) u_mutation (
        .rand_task1     (rand_task1),
        .rand_task2     (rand_task2),
        .rand_task3     (rand_task3),
        .rand_task4     (rand_task4),
        .mut_enable(mut_enable),
        .task_c21_mut   (task_c21_mut),
        .task_c12_mut   (task_c12_mut),
        .task_c21_mut_d (task_c21_mut_d),
        .task_c12_mut_d (task_c12_mut_d)
    );
    
    // Parents (registered)
    logic [PROC_W-1:0] proc_p1_dead;
    logic [TASK_W-1:0] task_p1_dead;
    
    logic [PROC_W-1:0] proc_p2_dead;
    logic [TASK_W-1:0] task_p2_dead;
    
    // Children (registered)
    logic [PROC_W-1:0] proc_c12_dead;
    logic [TASK_W-1:0] task_c12_dead;
    
    logic [PROC_W-1:0] proc_c21_dead;
    logic [TASK_W-1:0] task_c21_dead;
    
    Register #(
        .WIDTH(4*(PROC_W + TASK_W))
    ) pipeline_stage_3 (
        .clk(clk),
        .rst(rst),
        .en(pipeline_enable && ff_en),
    
        .d({
            proc_c21_mut, task_c21_mut_d,   // child 2-1
            proc_c12_mut, task_c12_mut_d,   // child 1-2
            proc_p2_mut,  task_p2_mut,    // parent 2
            proc_p1_mut,  task_p1_mut     // parent 1
        }),
    
        .q({
            proc_c21_dead, task_c21_dead,
            proc_c12_dead, task_c12_dead,
            proc_p2_dead,  task_p2_dead,
            proc_p1_dead,  task_p1_dead
        })
    );
    
    // Parents (registered)
    logic [PROC_W-1:0] proc_p1_fit;
    logic [TASK_W-1:0] task_p1_fit;
    
    logic [PROC_W-1:0] proc_p2_fit;
    logic [TASK_W-1:0] task_p2_fit;
    
    // Children (registered)
    logic [PROC_W-1:0] proc_c12_fit;
    logic [TASK_W-1:0] task_c12_fit;
    
    logic [PROC_W-1:0] proc_c21_fit;
    logic [TASK_W-1:0] task_c21_fit;
    
    
    Register #(
        .WIDTH(4*(PROC_W + TASK_W))
    ) pipeline_stage_4 (
        .clk(clk),
        .rst(rst),
        .en(pipeline_enable && ff_en),
    
        .d({
            proc_c21_dead, task_c21_dead,
            proc_c12_dead, task_c12_dead,
            proc_p2_dead,  task_p2_dead,
            proc_p1_dead,  task_p1_dead
        }),
    
        .q({
            proc_c21_fit, task_c21_fit,
            proc_c12_fit, task_c12_fit,
            proc_p2_fit,  task_p2_fit,
            proc_p1_fit,  task_p1_fit
        })
    );
    
    
    // ---------------------------------------------------------------------------
    // 4-lane Task parameter BRAM replication (same contents, shared write)
    // ---------------------------------------------------------------------------

    
    // Per-lane read address + read data
    logic [TASK_W-1:0] bram_r_addr   [4];
    logic [EXEC_W-1:0] bram_r_exec   [4];
    logic [DEAD_W-1:0] bram_r_dead   [4];
    logic [FIT_W-1:0] fits   [4];
 
    always_comb begin
      bram_r_addr[0] = task_c21_mut_d;
      bram_r_addr[1] = task_c12_mut_d;
      bram_r_addr[2] = task_p2_mut;
      bram_r_addr[3] = task_p1_mut;
    end
    
    // ---------------------------------------------------------------------------
    // Instantiate 4 identical BRAMs
    // ---------------------------------------------------------------------------
    genvar i;
    generate
      for (i = 0; i < 4; i++) begin : g_task_bram
        TaskParamBRAM #(
          .NTASKS (NTASKS),
          .EXEC_W (EXEC_W),
          .DEAD_W (DEAD_W),
          .ADDR_W (TASK_W)
        ) u_bram (
          .clk         (clk),
          .rst         (rst),
          .ff_en       (ff_en),
    
          // shared write port (all BRAMs get the same updates)
          .w_en        (w_en),
          .w_addr      (w_addr),
          .w_exec_time (w_exec_time),
          .w_deadline  (w_deadline),
    
          // shared read enable, but per-lane address/data
          .r_en        (bram_r_en),
          .r_addr      (bram_r_addr[i]),
          .r_exec_time (bram_r_exec[i]),
          .r_deadline  (bram_r_dead[i])
        );
      end
    endgenerate
    
FitnessAccum #(
  .NPROCS (NPROCS),
  .NTASKS (NTASKS),
  .EXEC_W (EXEC_W),
  .DEAD_W (DEAD_W),
  .PROC_W (PROC_W),
  .TIME_W (TIME_W),
  .SUM_W  (SUM_W),
  .FIT_W  (FIT_W)
) u_fit_c21 (
  .clk          (clk),
  .rst          (rst),
  .ff_en        (ff_en),
  .clear_fit    (clear_fit),

  .in_ready     (fit_in_ready),
  .in_proc_id   (proc_c21_fit),
  .in_exec_time (bram_r_exec[0]),
  .in_deadline  (bram_r_dead[0]),
  .fitness(fits[0])

);

FitnessAccum #(
  .NPROCS (NPROCS),
  .NTASKS (NTASKS),
  .EXEC_W (EXEC_W),
  .DEAD_W (DEAD_W),
  .PROC_W (PROC_W),
  .TIME_W (TIME_W),
  .SUM_W  (SUM_W),
  .FIT_W  (FIT_W)
) u_fit_c12 (
  .clk          (clk),
  .rst          (rst),
  .ff_en        (ff_en),
  .clear_fit    (clear_fit),

  .in_ready     (fit_in_ready),
  .in_proc_id   (proc_c12_fit),
  .in_exec_time (bram_r_exec[1]),
  .in_deadline  (bram_r_dead[1]),
  .fitness(fits[1])

);

FitnessAccum #(
  .NPROCS (NPROCS),
  .NTASKS (NTASKS),
  .EXEC_W (EXEC_W),
  .DEAD_W (DEAD_W),
  .PROC_W (PROC_W),
  .TIME_W (TIME_W),
  .SUM_W  (SUM_W),
  .FIT_W  (FIT_W)
) u_fit_p2 (
  .clk          (clk),
  .rst          (rst),
  .ff_en        (ff_en),
  .clear_fit    (clear_fit),

  .in_ready     (fit_in_ready),
  .in_proc_id   (proc_p2_fit),
  .in_exec_time (bram_r_exec[2]),
  .in_deadline  (bram_r_dead[2]),
  .fitness(fits[2])

);

FitnessAccum #(
  .NPROCS (NPROCS),
  .NTASKS (NTASKS),
  .EXEC_W (EXEC_W),
  .DEAD_W (DEAD_W),
  .PROC_W (PROC_W),
  .TIME_W (TIME_W),
  .SUM_W  (SUM_W),
  .FIT_W  (FIT_W)
) u_fit_p1 (
  .clk          (clk),
  .rst          (rst),
  .ff_en        (ff_en),
  .clear_fit    (clear_fit),

  .in_ready     (fit_in_ready),
  .in_proc_id   (proc_p1_fit),
  .in_exec_time (bram_r_exec[3]),
  .in_deadline  (bram_r_dead[3]),
  .fitness(fits[3]),
  .task_count(task_count)

);
         
// -------------------------
// ChromPool input lane arrays (match your ordering)
// lane0 = c21, lane1 = c12, lane2 = p2, lane3 = p1
// -------------------------
logic [TASK_W-1:0] cp_task_in [4];
logic [PROC_W-1:0] cp_proc_in [4];
logic [FIT_W-1+9:0] cp_fit_in  [4];

always_comb begin
  cp_task_in[0] = task_c21_fit;
  cp_task_in[1] = task_c12_fit;
  cp_task_in[2] = task_p2_fit;
  cp_task_in[3] = task_p1_fit;

  cp_proc_in[0] = proc_c21_fit;
  cp_proc_in[1] = proc_c12_fit;
  cp_proc_in[2] = proc_p2_fit;
  cp_proc_in[3] = proc_p1_fit;

  cp_fit_in[0]  = fits[0];
  cp_fit_in[1]  = fits[1];
  cp_fit_in[2]  = fits[2];
  cp_fit_in[3]  = fits[3];
end

logic gene_last;
assign gene_last  = (task_count == NTASKS-1);
logic fit_valid;
assign fit_valid  = gene_valid && gene_last;

// -------------------------
// ChromPool 
// -------------------------

localparam int POOL_DEPTH = 12;
localparam int CP_RD_PORTS = 6;

logic [TASK_W-1:0] pool_task_out [CP_RD_PORTS];
logic [PROC_W-1:0] pool_proc_out [CP_RD_PORTS];
logic [FIT_W-1 + 9:0] pool_fit_out  [CP_RD_PORTS];

logic [FIT_W-1 + 9:0] pool_fit_all  [POOL_DEPTH];
logic pool_full;
logic [$clog2(POOL_DEPTH)-1:0] read_addrs [0:CP_RD_PORTS-1];
logic [$clog2(POOL_DEPTH)-1:0] read_addrs_mixed [0:CP_RD_PORTS-1];

logic sel_out;

logic ctrl_select, ctrl_clr_upper_fit;
logic [$clog2(NTASKS)-1:0] ctrl_sel_idx;
logic [TASK_W-1:0] fifo_task_out1;
logic [PROC_W-1:0] fifo_proc_out1;

logic [TASK_W-1:0] fifo_task_out2;
logic [PROC_W-1:0] fifo_proc_out2;

logic [$clog2(POOL_DEPTH)-1:0] elite_rd_sel;    
logic [TASK_W-1:0] task_out_elite;
logic [PROC_W-1:0] proc_out_elite;

logic [FIT_W-1+9:0] fit_array [POOL_DEPTH];
    ChromPool4 #(
      .DEPTH    (POOL_DEPTH),
      .NGENES   (NTASKS),
      .PROC_W   (PROC_W),
      .TASK_W   (TASK_W),
      .FIT_W    (FIT_W-1 +10),
      .RD_PORTS (CP_RD_PORTS)
    ) u_chrom_pool (
      .clk            (clk),
      .rst            (rst),
      .en             (ff_en),        
      .clr            (clear_fit),
    
      // streaming in
      .gene_valid     (gene_valid),
      .gene_last      (gene_last),
      .select         (ctrl_select),
      .clr_upper_fit  (ctrl_clr_upper_fit),
      .task_in        (cp_task_in),
      .proc_in        (cp_proc_in),
    
      // fitness in (once per chromosome)
      .fit_valid      (fit_valid),
      .fit_in         (cp_fit_in),
    
      // read out (6 puertos)
      .rd_sel         (read_addrs_mixed),
      .rd_gene_idx    (ctrl_sel_idx),
      .task_out       (pool_task_out),
      .proc_out       (pool_proc_out),
      .fit_out        (pool_fit_out),
    
      .task_out_elite (task_out_elite),
      .proc_out_elite (proc_out_elite),
      .rd_sel_elite(elite_rd_sel),
      .fit_out_elite(),
      // arreglo completo de fitness
      .fit_all        (pool_fit_all),
      .fit_all_decoded (fit_array),
    
      .full           (pool_full)
    );

//FitArrayDecode #(
//    .POOL_DEPTH(POOL_DEPTH),
//    .FIT_W     (FIT_W)
//) u_fit_decode (
//    .pool_fit_all(pool_fit_all),
//    .fit_array   (fit_array)
//);
    
    logic elite_start;;
    logic write_en;
    assign elite_start = write_en;
    logic [TASK_W-1:0] cap_idx;
    assign cap_idx = ctrl_sel_idx;
    
    EliteKeeperFromPool #(
        .POOL_DEPTH(POOL_DEPTH),
        .NTASKS    (NTASKS),
        .TASK_W    (TASK_W),
        .PROC_W    (PROC_W),
        .FIT_W     (FIT_W+9)
    ) u_elite_keeper (
        .clk          (clk),
        .rst          (rst),
        .ff_en        (ff_en),
        .select_start (elite_start),
        .cap_idx(cap_idx),
        
        .fit_array    (fit_array),
    
        .rd_task_in   (task_out_elite),
        .rd_proc_in   (proc_out_elite),
    
        .rd_sel_out   (elite_rd_sel),
        .best_fit     (elite_best_fit),
        .best_task_out(elite_best_task),
        .best_proc_out(elite_best_proc)
    );
   

    SelectionStage #(
        .NTASKS      (NTASKS),
        .TASK_W      (TASK_W),
        .POOL_DEPTH  (POOL_DEPTH),
        .CP_RD_PORTS (CP_RD_PORTS),
        .TIME_W      (TIME_W),
        .FIT_W       (FIT_W)
    ) u_selection_stage (
        .clk             (clk),
        .rst             (rst),
        .ff_en           (ff_en),
    
        .gene_last       (gene_last),
        .pipeline_enable (pipeline_enable),
        .pool_fit_all    (pool_fit_all),
    
        .write_en (write_en),
        .ctrl_select     (ctrl_select),
        .sel_out        (sel_out),
        .ctrl_clr_upper_fit (ctrl_clr_upper_fit),
        .ctrl_sel_idx    (ctrl_sel_idx),
    
        .read_addrs      (read_addrs)
    );

    assign read_addrs_mixed [0] = elite_rd_sel;
    assign read_addrs_mixed [1] = read_addrs[1];
    assign read_addrs_mixed [2] = read_addrs[2];
    assign read_addrs_mixed [3] = read_addrs[3];
    assign read_addrs_mixed [4] = read_addrs[4];
    assign read_addrs_mixed [5] = read_addrs[5];    

    logic [TASK_W-1:0] fifo_task_in [6];
    logic [PROC_W-1:0] fifo_proc_in [6];
    assign fifo_task_in = pool_task_out;
    assign fifo_proc_in = pool_proc_out;

    ChromFIFO_System #(
        .NTASKS(NTASKS),
        .TASK_W(TASK_W),
        .PROC_W(PROC_W)
    ) u_fifo_system (
    
        .clk(clk),
        .rst(rst),
        .ff_en(ff_en),
    
        .pipeline_enable(pipeline_enable),
        .ctrl_select(ctrl_select),
        .ctrl_sel_idx(ctrl_sel_idx),
    
        .fifo_read_en(fifo_read_en),
        .fifo_read_two(fifo_read_two),
        .fifo_task_in   (fifo_task_in),
        .fifo_proc_in   (fifo_proc_in),
            
        .fifo_task_out1(fifo_task_out1),
        .fifo_proc_out1(fifo_proc_out1),
        
        .write_en(write_en),
        
        .fifo_task_out2(fifo_task_out2),
        .fifo_proc_out2(fifo_proc_out2)
    );
    
    logic [PROC_W + TASK_W -1 :0] data_in, data_in_2;
    logic [PROC_W + TASK_W -1 :0] data_fb, data_fb_2;
    logic [PROC_W + TASK_W -1 :0] data_out, data_out_2;
    logic        fb_sel, fb_sel_2;

    assign fb_sel = fifo_read_en;
    assign fb_sel_2 = fifo_read_two;
    assign data_in = {task_id_rom_1, (gene_idx[3:0]) };
//    assign data_in = {task_id_rom_1, proc_id_1 };    
    assign data_in_2 = {task_id_rom_2, proc_id_2};
//    assign data_in_2 = {task_id_rom_2, proc_id_2};

    assign data_fb = {fifo_task_out1, fifo_proc_out1};
    assign data_fb_2 = {fifo_task_out2, fifo_proc_out2};

    FeedbackMux #(
        .WIDTH(PROC_W + TASK_W)
    ) u_feedback_mux (
        .in_data  (data_in),
        .feedback (data_fb),
        .sel      (fb_sel),
        .out_data ({mux_task_out, mux_proc_out})
    );
    
    FeedbackMux #(
        .WIDTH(PROC_W + TASK_W)
    ) u_feedback_mux_2 (
        .in_data  (data_in_2),
        .feedback (data_fb_2),
        .sel      (fb_sel_2),
        .out_data ({mux_task_out_2, mux_proc_out_2})
    );
endmodule







