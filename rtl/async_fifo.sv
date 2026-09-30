`timescale 1ns / 1ps

module async_fifo #(
    parameter int DATA_WIDTH = 32,
    parameter int FIFO_DEPTH = 16
)(// Shared Asynchronous Reset
    input  logic                  arst_n,
    // Write Interface
    input  logic                  wr_clk,
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    output logic                  full,

    // Read Interface
    input  logic                  rd_clk,
    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic                  empty
);


    // Internal domain reset nets driven by the shared arst_n input
    logic w_arst_n, r_arst_n;
    assign w_arst_n = arst_n;
    assign r_arst_n = arst_n;
    // Calculate address width automatically (16 depth -> 4 bits)
    localparam int ADDR_WIDTH = $clog2(FIFO_DEPTH);

    // Dual-port FIFO Memory Array
    logic [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];

    // Binary and Gray pointers (ADDR_WIDTH + 1 = 5 bits wide for wrap-around detection)
    logic [ADDR_WIDTH:0] wbin, wbin_next;
    logic [ADDR_WIDTH:0] wgray, wgray_next;
    logic [ADDR_WIDTH:0] rbin, rbin_next;
    logic [ADDR_WIDTH:0] rgray, rgray_next;

    // 2-Stage Flip-Flop Synchronizer Registers (Pure SystemVerilog)
    logic [ADDR_WIDTH:0] wq1_rgray, wq2_rgray;
    logic [ADDR_WIDTH:0] rq1_wgray, rq2_wgray;

    // -------------------------------------------------------------------------
    // 1. Dual-Port Memory Logic
    // -------------------------------------------------------------------------
    // Synchronous Write on wr_clk (guarded by !full)
    always_ff @(posedge wr_clk) begin
        if (wr_en && !full) begin
            mem[wbin[ADDR_WIDTH-1:0]] <= wr_data;
        end
    end

    // Combinational Read (valid data is immediately available on rd_data when !empty)
    assign rd_data = mem[rbin[ADDR_WIDTH-1:0]];

    // -------------------------------------------------------------------------
    // 2. Read-to-Write Synchronizer (Crosses rgray into wr_clk domain)
    // -------------------------------------------------------------------------
    always_ff @(posedge wr_clk or negedge w_arst_n) begin
        if (!w_arst_n) begin
            {wq2_rgray, wq1_rgray} <= '0;
        end else begin
            {wq2_rgray, wq1_rgray} <= {wq1_rgray, rgray};
        end
    end

    // -------------------------------------------------------------------------
    // 3. Write-to-Read Synchronizer (Crosses wgray into rd_clk domain)
    // -------------------------------------------------------------------------
    always_ff @(posedge rd_clk or negedge r_arst_n) begin
        if (!r_arst_n) begin
            {rq2_wgray, rq1_wgray} <= '0;
        end else begin
            {rq2_wgray, rq1_wgray} <= {rq1_wgray, wgray};
        end
    end

    // -------------------------------------------------------------------------
    // 4. Write Pointer & Full Flag Generation (wr_clk domain)
    // -------------------------------------------------------------------------
    assign wbin_next  = wbin + (wr_en & ~full);
    assign wgray_next = (wbin_next >> 1) ^ wbin_next;

    always_ff @(posedge wr_clk or negedge w_arst_n) begin
        if (!w_arst_n) begin
            wbin  <= '0;
            wgray <= '0;
            full  <= 1'b0;
        end else begin
            wbin  <= wbin_next;
            wgray <= wgray_next;
            // Full when top 2 MSBs are inverted and remaining LSBs are equal
            full  <= (wgray_next == {~wq2_rgray[ADDR_WIDTH:ADDR_WIDTH-1], wq2_rgray[ADDR_WIDTH-2:0]});
        end
    end

    // -------------------------------------------------------------------------
    // 5. Read Pointer & Empty Flag Generation (rd_clk domain)
    // -------------------------------------------------------------------------
    assign rbin_next  = rbin + (rd_en & ~empty);
    assign rgray_next = (rbin_next >> 1) ^ rbin_next;

    always_ff @(posedge rd_clk or negedge r_arst_n) begin
        if (!r_arst_n) begin
            rbin  <= '0;
            rgray <= '0;
            empty <= 1'b1;
        end else begin
            rbin  <= rbin_next;
            rgray <= rgray_next;
            // Empty when all bits of next read Gray pointer match synced write Gray pointer
            empty <= (rgray_next == rq2_wgray);
        end
    end

    endmodule
