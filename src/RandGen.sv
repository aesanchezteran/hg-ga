`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/22/2026 07:34:23 PM
// Design Name: 
// Module Name: RandGen
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


`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/09/2025 12:25:39 PM
// Design Name: 
// Module Name: RandGen
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 8 bit Uniform Random number generator
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module RandGen #(
    parameter int WIDTH = 7,
    parameter int NUM_CHANNELS = 6,
    parameter int WIDTH_OUT = 32 
)(
    input  logic clk,
    input  logic rst,
    input  logic en,
    output logic [WIDTH_OUT-1:0] rand_out
);

  
//    localparam int MODULI[NUM_CHANNELS] = '{3, 5, 17};  // M = 255
      localparam int MODULI[NUM_CHANNELS] = '{3, 43, 47, 67, 97, 109};
      localparam int PRIMITIVE_ROOTS[NUM_CHANNELS] = '{2, 3, 5, 2, 5, 6}; // Valid primitive roots
//    localparam int PRIMITIVE_ROOTS[NUM_CHANNELS] = '{1, 1, 1, 1, 1, 1}; // Valid primitive roots

    
    // Internal signals
    logic [WIDTH-1:0] r_outputs [NUM_CHANNELS];   // Channel outputs
    logic [WIDTH-1:0] total_sum;
    logic [WIDTH-1:0] sum_excl_self [NUM_CHANNELS];
    
    logic [WIDTH-1:0] orex [NUM_CHANNELS];

    // Shared total sum adder
    prev_OREX #(
        .WIDTH(WIDTH),
        .NUM_CHANNELS(NUM_CHANNELS)
    ) shared_orex (
        .r_curr(r_outputs),
        .orex(orex)
    );

    // Channels with subtract-from-total logic
    genvar i;
    generate
        for (i = 0; i < NUM_CHANNELS; i++) begin : gen_channels

            channel #(
                .WIDTH(WIDTH),
                .MODULUS(MODULI[i]),
                .G(PRIMITIVE_ROOTS[i]),
                .ID(i),
                .NUM_CHANNELS(NUM_CHANNELS)
            ) ch_inst (
                .clk(clk),
                .rst(rst),
                .en(en),
                .prev(orex[i]),
                .r_curr(r_outputs[i])
            );

        end
    endgenerate

    RNS_to_Binary #(
    .WIDTH        (WIDTH),
    .NUM_CHANNELS (NUM_CHANNELS),
    .WIDTH_OUT    (WIDTH_OUT)
) rns2bin (
    .residues     (r_outputs),
    .binary_out   (rand_out)
);
    
    
endmodule

module prev_OREX #(
    parameter int WIDTH = 4,
    parameter int NUM_CHANNELS = 3
)(
    input  logic [WIDTH-1:0] r_curr [NUM_CHANNELS],
    output logic [WIDTH-1:0] orex    [NUM_CHANNELS]
);

    integer i, j;
    always_comb begin
        for (i = 0; i < NUM_CHANNELS; i++) begin
            orex[i] = '0;  // Initialize to zero
            for (j = 0; j < NUM_CHANNELS; j++) begin
                if (j != i) begin
                    orex[i] ^= r_curr[j];  // XOR all other channels
                end
            end
        end
    end

endmodule


module channel #(
    parameter int WIDTH = 7,              // bit-width of residue values
    parameter int MODULUS = 5,            // m_j
    parameter int G = 2,                  // primitive root g_j
    parameter int ID = 0,                 // index j of this channel
    parameter int NUM_CHANNELS = 6        // total number of channels
)(
    input  logic clk,
    input  logic rst,
    input  logic en,
    input  logic [WIDTH-1:0] prev,      // Sum of previous residues
    output logic [WIDTH-1:0] r_curr         // Output: r(j, i)
);

// State registers
    logic [WIDTH-1:0] r_prev, r_prev2;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            r_prev  <= ID + 1; // simple initial seeds per channel
            r_prev2 <= ID + 2;
            r_curr  <= 0;
        end else if (en) begin
           // --- Final output: r(j, i) = (g*r_prev2 + b_j) mod m_j ---
            r_curr <= ((r_prev2*G) + prev) % MODULUS;
            // --- Update internal pipeline ---
            r_prev2 <= r_prev;
            r_prev  <= r_curr;
        end
    end
endmodule

module RNS_to_Binary #(
    parameter int WIDTH       = 4,
    parameter int NUM_CHANNELS= 6,
    // precomputed for {3,43,47,67,97,109}:
    parameter logic [63:0] M = 64'd4294974633,
    parameter logic [63:0] Mj[NUM_CHANNELS] = '{
        64'd1431658211,  // M/3
        64'd99883131,    // M/43
        64'd91382439,    // M/47
        64'd64104099,    // M/67
        64'd44278089,    // M/97
        64'd39403437     // M/109
    },
    parameter logic [63:0] invMj[NUM_CHANNELS] = '{
        64'd2,           // (M/3)^-1 mod 3
        64'd2,           // (M/43)^-1 mod 43
        64'd33,          // ... mod 47
        64'd62,          // ... mod 67
        64'd7,           // ... mod 97
        64'd64           // ... mod 109
    },
    parameter int WIDTH_OUT = 32
)(
    input  logic [WIDTH-1:0] residues [NUM_CHANNELS],
    output logic [WIDTH_OUT-1:0] binary_out
);

    logic [63:0] temp_sum;

    always_comb begin
        temp_sum = 0;
        for (int j = 0; j < NUM_CHANNELS; j++) begin
            temp_sum += residues[j] * Mj[j] * invMj[j];
        end
        // final CRT reduction modulo constant M
        binary_out = temp_sum % M;
    end

endmodule

