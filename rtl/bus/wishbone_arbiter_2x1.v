/**
 * @file wishbone_arbiter_2x1.v
 * @brief 2-to-1 Wishbone Arbiter with Fixed Priority
 *
 * This module arbitrates between two Wishbone masters competing for a single
 * Wishbone slave. It uses fixed-priority arbitration.
 *
 * Priority: Master 0 > Master 1
 *
 * Master 0 is intended for the CPU's Instruction Bus (IBus).
 * Master 1 is intended for the CPU's Data Bus (DBus).
 *
 * This ensures that instruction fetches are never blocked by data accesses,
 * preventing CPU stalls.
 */
module wishbone_arbiter_2x1 (
    input  wire        clk,
    input  wire        rst_n,

    // Slaves (from CPU IBus and DBus)
    input  wire [31:0] s0_wb_addr,
    input  wire [31:0] s0_wb_dat_i,
    output wire [31:0] s0_wb_dat_o,
    input  wire        s0_wb_we,
    input  wire [3:0]  s0_wb_sel,
    input  wire        s0_wb_stb,
    input  wire        s0_wb_cyc,
    output wire        s0_wb_ack,
    output wire        s0_wb_err,

    input  wire [31:0] s1_wb_addr,
    input  wire [31:0] s1_wb_dat_i,
    output wire [31:0] s1_wb_dat_o,
    input  wire        s1_wb_we,
    input  wire [3:0]  s1_wb_sel,
    input  wire        s1_wb_stb,
    input  wire        s1_wb_cyc,
    output wire        s1_wb_ack,
    output wire        s1_wb_err,

    // Master (to Bus Interconnect)
    output wire [31:0] m_wb_addr,
    output wire [31:0] m_wb_dat_o,
    input  wire [31:0] m_wb_dat_i,
    output wire        m_wb_we,
    output wire [3:0]  m_wb_sel,
    output wire        m_wb_stb,
    output wire        m_wb_cyc,
    input  wire        m_wb_ack,
    input  wire        m_wb_err
);

    reg grant; // 0 for slave 0, 1 for slave 1

    localparam S0_SELECT = 1'b0;
    localparam S1_SELECT = 1'b1;

    wire s0_request = s0_wb_stb && s0_wb_cyc;
    wire s1_request = s1_wb_stb && s1_wb_cyc;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            grant <= S0_SELECT;
        end else begin
            // Fixed priority: S0 has priority.
            // A master keeps the grant until its cycle (cyc) is complete.
            // If S0 requests, it gets the grant.
            // If S0 is not requesting, S1 can get the grant.
            if (grant == S0_SELECT) begin
                if (!s0_wb_cyc && s1_request) begin
                    grant <= S1_SELECT;
                end
            end else begin // grant == S1_SELECT
                if (s0_request) begin
                    grant <= S0_SELECT;
                end else if (!s1_wb_cyc) begin
                    grant <= S0_SELECT;
                end
            end
        end
    end

    // Mux master outputs based on grant
    assign m_wb_addr  = (grant == S0_SELECT) ? s0_wb_addr   : s1_wb_addr;
    assign m_wb_dat_o = (grant == S0_SELECT) ? s0_wb_dat_i  : s1_wb_dat_i;
    assign m_wb_we    = (grant == S0_SELECT) ? s0_wb_we     : s1_wb_we;
    assign m_wb_sel   = (grant == S0_SELECT) ? s0_wb_sel    : s1_wb_sel;
    assign m_wb_stb   = (grant == S0_SELECT) ? s0_wb_stb    : s1_wb_stb;
    assign m_wb_cyc   = (grant == S0_SELECT) ? s0_wb_cyc    : s1_wb_cyc;

    // Route master inputs back to the granted slave
    assign s0_wb_dat_o = (grant == S0_SELECT) ? m_wb_dat_i : 32'h0;
    assign s0_wb_ack   = (grant == S0_SELECT) ? m_wb_ack   : 1'b0;
    assign s0_wb_err   = (grant == S0_SELECT) ? m_wb_err   : 1'b0;

    assign s1_wb_dat_o = (grant == S1_SELECT) ? m_wb_dat_i : 32'h0;
    assign s1_wb_ack   = (grant == S1_SELECT) ? m_wb_ack   : 1'b0;
    assign s1_wb_err   = (grant == S1_SELECT) ? m_wb_err   : 1'b0;

endmodule
