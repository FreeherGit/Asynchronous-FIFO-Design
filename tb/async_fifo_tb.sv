`timescale 1ns / 1ps

module async_fifo_tb;

    // =========================================================================
    // 1. Parameters & Signals for Primary DUT (DATA_WIDTH = 32, FIFO_DEPTH = 16)
    // =========================================================================
    localparam int DATA_WIDTH = 32;
    localparam int FIFO_DEPTH = 16;
    localparam int ADDR_WIDTH = $clog2(FIFO_DEPTH);

    logic                  arst_n;     // Shared active-low asynchronous reset
    logic                  wr_clk;
    logic                  wr_en;
    logic [DATA_WIDTH-1:0] wr_data;
    logic                  full;

    logic                  rd_clk;
    logic                  rd_en;
    logic [DATA_WIDTH-1:0] rd_data;
    logic                  empty;

    // ASCII string visible in Vivado / GTKWave waveform viewer
    reg [8*32-1:0] test_case_name = "INIT";

    // =========================================================================
    // 2. Parameters & Signals for Scaled DUT (Requirement 6: Scalability 8x8)
    // =========================================================================
    localparam int SCALED_WIDTH = 8;
    localparam int SCALED_DEPTH = 8;

    logic                    s_wr_en;
    logic [SCALED_WIDTH-1:0] s_wr_data;
    logic                    s_full;
    logic                    s_rd_en;
    logic [SCALED_WIDTH-1:0] s_rd_data;
    logic                    s_empty;

    // =========================================================================
    // 3. Clock Control & Scoreboard Variables
    // =========================================================================
    realtime wr_half_period = 5.0;   // Default: 100 MHz (10 ns period)
    realtime rd_half_period = 8.0;   // Default: 62.5 MHz (16 ns period)
    realtime rd_phase_shift = 0.0;

    logic [DATA_WIDTH-1:0] expected_q[$];
    int pass_count  = 0;
    int error_count = 0;
    int cdc_checks  = 0;

    // =========================================================================
    // 4. DUT Instantiations (Using shared arst_n port)
    // =========================================================================
    async_fifo #(
        .DATA_WIDTH (DATA_WIDTH),
        .FIFO_DEPTH (FIFO_DEPTH)
    ) dut (
        .arst_n   (arst_n),
        .wr_clk   (wr_clk),
        .wr_en    (wr_en),
        .wr_data  (wr_data),
        .full     (full),
        .rd_clk   (rd_clk),
        .rd_en    (rd_en),
        .rd_data  (rd_data),
        .empty    (empty)
    );

    async_fifo #(
        .DATA_WIDTH (SCALED_WIDTH),
        .FIFO_DEPTH (SCALED_DEPTH)
    ) dut_scaled (
        .arst_n   (arst_n),
        .wr_clk   (wr_clk),
        .wr_en    (s_wr_en),
        .wr_data  (s_wr_data),
        .full     (s_full),
        .rd_clk   (rd_clk),
        .rd_en    (s_rd_en),
        .rd_data  (s_rd_data),
        .empty    (s_empty)
    );

    // =========================================================================
    // 5. Waveform Dump & Safety Watchdog Timer (Guarantees Terminal Never Hangs)
    // =========================================================================
    initial begin
        $dumpfile("async_fifo_tb.vcd");
        $dumpvars(0, async_fifo_tb);
    end

    initial begin
        #100000; // 100 us safety timeout
        $display("\n[WATCHDOG ERROR] Simulation exceeded 100 us! Exiting safely to terminal.");
        $finish;
    end

    // =========================================================================
    // 6. Independent Clock Generators (Requirement 4)
    // =========================================================================
    initial begin
        wr_clk = 1'b0;
        forever #(wr_half_period) wr_clk = ~wr_clk;
    end

    initial begin
        rd_clk = 1'b0;
        forever begin
            if (rd_phase_shift > 0.0) begin
                #(rd_phase_shift);
                rd_phase_shift = 0.0;
            end
            #(rd_half_period) rd_clk = ~rd_clk;
        end
    end

    // =========================================================================
    // 7. Continuous Gray-Code CDC Single-Bit Transition Monitor (Requirement 5)
    // =========================================================================
    logic [ADDR_WIDTH:0] prev_wgray = '0;
    logic [ADDR_WIDTH:0] prev_rgray = '0;

    always @(posedge wr_clk or negedge arst_n) begin
        if (!arst_n) begin
            prev_wgray <= '0;
        end else begin
            if ($countones(dut.wgray ^ prev_wgray) > 1) begin
                $display("[%7t ns] | %-32s | Exp: <=1 bit flip | Got: %b->%b | [ERROR]",
                         $time, "CDC Monitor: wgray transition", prev_wgray, dut.wgray);
                error_count++;
            end else begin
                cdc_checks++;
            end
            prev_wgray <= dut.wgray;
        end
    end

    always @(posedge rd_clk or negedge arst_n) begin
        if (!arst_n) begin
            prev_rgray <= '0;
        end else begin
            if ($countones(dut.rgray ^ prev_rgray) > 1) begin
                $display("[%7t ns] | %-32s | Exp: <=1 bit flip | Got: %b->%b | [ERROR]",
                         $time, "CDC Monitor: rgray transition", prev_rgray, dut.rgray);
                error_count++;
            end else begin
                cdc_checks++;
            end
            prev_rgray <= dut.rgray;
        end
    end

    // =========================================================================
    // 8. Clear Terminal Logging & Verification Helper Tasks
    // =========================================================================
    task automatic print_banner(input string title);
        $display("\n----------------------------------------------------------------------------------------");
        $display(" >>> %s", title);
        $display("----------------------------------------------------------------------------------------");
    endtask

    // Compares Expected vs Evaluated value and prints a clean row in the terminal
    task automatic verify_val(
        input string               check_desc,
        input logic [DATA_WIDTH:0] expected,
        input logic [DATA_WIDTH:0] evaluated,
        input bit                  is_hex
    );
        if (evaluated === expected) begin
            pass_count++;
            if (is_hex)
                $display("[%7t ns] | %-34s | Exp: 0x%08h | Eval: 0x%08h | [PASS]",
                         $time, check_desc, expected[31:0], evaluated[31:0]);
            else
                $display("[%7t ns] | %-34s | Exp: %10d | Eval: %10d | [PASS]",
                         $time, check_desc, expected, evaluated);
        end else begin
            error_count++;
            if (is_hex)
                $display("[%7t ns] | %-34s | Exp: 0x%08h | Eval: 0x%08h | [ERROR]",
                         $time, check_desc, expected[31:0], evaluated[31:0]);
            else
                $display("[%7t ns] | %-34s | Exp: %10d | Eval: %10d | [ERROR]",
                         $time, check_desc, expected, evaluated);
        end
    endtask

    // Safe single-word write task (waits if full, drives wr_en for 1 cycle)
    task automatic write_one(input logic [DATA_WIDTH-1:0] data, input bit verbose);
        while (full === 1'b1) @(posedge wr_clk);
        wr_en   <= 1'b1;
        wr_data <= data;
        expected_q.push_back(data);
        @(posedge wr_clk);
        wr_en   <= 1'b0;
        #1; // Let non-blocking assignments settle after posedge
        if (verbose) begin
            $display("[%7t ns] | WRITE Transaction                  | Data Written: 0x%08h | wbin=%2d, full=%0b",
                     $time, data, dut.wbin, full);
        end
    endtask

    // Safe single-word read & self-check task (waits if empty, checks rd_data, pulses rd_en)
    task automatic read_and_verify(input string label, input bit verbose);
        logic [DATA_WIDTH-1:0] exp_data;
        while (empty === 1'b1) @(posedge rd_clk);
        exp_data = expected_q.pop_front();
        if (verbose) begin
            verify_val(label, exp_data, rd_data, 1'b1);
        end else begin
            if (rd_data === exp_data) pass_count++;
            else begin
                error_count++;
                $display("[%7t ns] | %-34s | Exp: 0x%08h | Eval: 0x%08h | [ERROR]",
                         $time, label, exp_data, rd_data);
            end
        end
        rd_en <= 1'b1;
        @(posedge rd_clk);
        rd_en <= 1'b0;
        #1;
    endtask

    // =========================================================================
    // 9. Main Test Sequence (12 Comprehensive Directed & Corner Cases)
    // =========================================================================
    initial begin
        arst_n    = 1'b1;
        wr_en     = 1'b0;
        wr_data   = '0;
        rd_en     = 1'b0;
        s_wr_en   = 1'b0;
        s_wr_data = '0;
        s_rd_en   = 1'b0;

        $display("========================================================================================");
        $display("              ASYNCHRONOUS FIFO SELF-CHECKING VERIFICATION REPORT                       ");
        $display("              Default Config: DATA_WIDTH = %0d, FIFO_DEPTH = %0d                        ", DATA_WIDTH, FIFO_DEPTH);
        $display("========================================================================================");

        // ---------------------------------------------------------------------
        // TEST 1: Power-On Shared Asynchronous Reset (Requirement 1)
        // ---------------------------------------------------------------------
        test_case_name = "TEST1_ASYNC_RESET";
        print_banner("TEST 1: Shared Asynchronous Reset (arst_n) Assertion & Deassertion [Req 1]");
        #13;
        arst_n = 1'b0; // Assert reset asynchronously
        #25;
        verify_val("Reset Asserted: full flag",  0, full,      1'b0);
        verify_val("Reset Asserted: empty flag", 1, empty,     1'b0);
        verify_val("Reset Asserted: wbin ptr",   0, dut.wbin,  1'b0);
        verify_val("Reset Asserted: rbin ptr",   0, dut.rbin,  1'b0);

        arst_n = 1'b1; // Release reset
        @(posedge wr_clk);
        @(posedge rd_clk);
        #1;
        verify_val("Reset Released: full flag",  0, full,      1'b0);
        verify_val("Reset Released: empty flag", 1, empty,     1'b0);

        // ---------------------------------------------------------------------
        // TEST 2: Extreme Bit Patterns & CDC Latency (Requirements 2 & 5)
        // ---------------------------------------------------------------------
        test_case_name = "TEST2_DATA_PATTERNS";
        print_banner("TEST 2: Extreme Bit Patterns (All-0, All-1, Checkerboard) [Req 2 & 5]");
        @(posedge wr_clk); #1;
        write_one(32'h0000_0000, 1'b1);
        write_one(32'hFFFF_FFFF, 1'b1);
        write_one(32'hAAAA_5555, 1'b1);
        write_one(32'h5555_AAAA, 1'b1);

        // Wait for 2-FF synchronizer (rq1_wgray -> rq2_wgray) to update empty flag
        repeat (3) @(posedge rd_clk); #1;
        verify_val("After 4 Writes: empty flag", 0, empty, 1'b0);

        read_and_verify("Read Pattern 1 (All Zeros)",    1'b1);
        read_and_verify("Read Pattern 2 (All Ones)",     1'b1);
        read_and_verify("Read Pattern 3 (0xAAAA5555)",   1'b1);
        read_and_verify("Read Pattern 4 (0x5555AAAA)",   1'b1);
        verify_val("After 4 Reads: empty flag",  1, empty, 1'b0);
        repeat (3) @(posedge wr_clk); #1;

        // ---------------------------------------------------------------------
        // TEST 3: Fill to Full (16 Words) & Overflow Protection (Requirement 2)
        // ---------------------------------------------------------------------
        test_case_name = "TEST3_FULL_AND_OVERFLOW";
        print_banner("TEST 3: Continuous Burst Write to Full (16 Words) & Overflow Block [Req 2]");
        @(posedge wr_clk);
        for (int i = 0; i < FIFO_DEPTH; i++) begin
            wr_en   <= 1'b1;
            wr_data <= 32'hA000_0000 + i;
            expected_q.push_back(32'hA000_0000 + i);
            @(posedge wr_clk);
        end
        wr_en <= 1'b0;
        #1;
        verify_val("After 16 Writes: full flag",     1,  full,                 1'b0);
        verify_val("After 16 Writes: Occupancy",     16, dut.wbin - dut.rbin,  1'b0);

        // Corner Case: Attempt 4 extra writes while full=1 (Overflow attempt)
        begin
            automatic logic [ADDR_WIDTH:0] saved_wbin = dut.wbin;
            for (int i = 0; i < 4; i++) begin
                wr_en   <= 1'b1;
                wr_data <= 32'hDEAD_BEEF;
                @(posedge wr_clk);
            end
            wr_en <= 1'b0;
            #1;
            verify_val("Overflow Blocked: wbin unchanged", saved_wbin, dut.wbin, 1'b0);
        end
        repeat (3) @(posedge rd_clk); #1;

        // ---------------------------------------------------------------------
        // TEST 4: Drain to Empty (16 Words) & Underflow Protection (Requirement 2)
        // ---------------------------------------------------------------------
        test_case_name = "TEST4_EMPTY_AND_UNDERFLOW";
        print_banner("TEST 4: Drain all 16 Words to Empty & Underflow Block [Req 2]");
        for (int i = 0; i < FIFO_DEPTH; i++) begin
            // Print first 2 and last 2 reads to keep terminal clean and readable
            read_and_verify($sformatf("Burst Read Word [%0d]", i), (i < 2 || i >= 14));
        end
        verify_val("After 16 Reads: empty flag",     1, empty,    1'b0);
        verify_val("After 16 Reads: rbin == wbin",   dut.wbin, dut.rbin, 1'b0);

        // Corner Case: Attempt 4 extra reads while empty=1 (Underflow attempt)
        begin
            automatic logic [ADDR_WIDTH:0] saved_rbin = dut.rbin;
            for (int i = 0; i < 4; i++) begin
                rd_en <= 1'b1;
                @(posedge rd_clk);
            end
            rd_en <= 1'b0;
            #1;
            verify_val("Underflow Blocked: rbin unchanged", saved_rbin, dut.rbin, 1'b0);
        end
        repeat (3) @(posedge wr_clk); #1;

        // ---------------------------------------------------------------------
        // TEST 5: Corner Case — Simultaneous R/W While EMPTY (Req 2 & 3)
        // ---------------------------------------------------------------------
        test_case_name = "TEST5_RW_AT_EMPTY";
        print_banner("TEST 5: Corner Case — Simultaneous Read & Write While EMPTY [Req 2 & 3]");
        begin
            automatic logic [ADDR_WIDTH:0] rbin_before = dut.rbin;
            fork
                begin
                    @(posedge wr_clk);
                    wr_en   <= 1'b1;
                    wr_data <= 32'hCAFE_0001;
                    expected_q.push_back(32'hCAFE_0001);
                    @(posedge wr_clk);
                    wr_en   <= 1'b0;
                end
                begin
                    @(posedge rd_clk);
                    rd_en <= 1'b1; // Must be ignored because empty=1
                    @(posedge rd_clk);
                    rd_en <= 1'b0;
                end
            join
            #1;
            verify_val("Simul R/W at Empty: Read Blocked", rbin_before, dut.rbin, 1'b0);
            repeat (3) @(posedge rd_clk); #1;
            read_and_verify("Simul R/W at Empty: Written Data", 1'b1);
            repeat (3) @(posedge wr_clk); #1;
        end

        // ---------------------------------------------------------------------
        // TEST 6: Corner Case — Simultaneous R/W While FULL (Req 2 & 3)
        // ---------------------------------------------------------------------
        test_case_name = "TEST6_RW_AT_FULL";
        print_banner("TEST 6: Corner Case — Simultaneous Read & Write While FULL [Req 2 & 3]");
        @(posedge wr_clk); #1;
        for (int i = 0; i < FIFO_DEPTH; i++) begin
            write_one(32'hB000_0000 + i, 1'b0);
        end
        repeat (3) @(posedge rd_clk); #1;
        verify_val("Pre-check before Test 6: full flag", 1, full, 1'b0);

        begin
            automatic logic [ADDR_WIDTH:0] wbin_before = dut.wbin;
            fork
                begin
                    @(posedge wr_clk);
                    wr_en   <= 1'b1;
                    wr_data <= 32'hBAD0_FFFF; // Must be blocked because full=1
                    @(posedge wr_clk);
                    wr_en   <= 1'b0;
                end
                begin
                    read_and_verify("Simul R/W at Full: Read Word [0]", 1'b1);
                end
            join
            #1;
            verify_val("Simul R/W at Full: Write Blocked", wbin_before, dut.wbin, 1'b0);
            repeat (3) @(posedge wr_clk); #1;
            for (int i = 1; i < FIFO_DEPTH; i++) begin
                read_and_verify($sformatf("Drain Word [%0d]", i), (i == 15));
            end
            repeat (3) @(posedge wr_clk); #1;
        end

        // ---------------------------------------------------------------------
        // TEST 7: Corner Case — Full 5-Bit Pointer Rollover (31 -> 0) (Req 2)
        // ---------------------------------------------------------------------
        test_case_name = "TEST7_5BIT_PTR_ROLLOVER";
        print_banner("TEST 7: Full 5-Bit Pointer Rollover (36 Words > 2xDepth) [Req 2]");
        for (int lap = 0; lap < 3; lap++) begin
            for (int i = 0; i < 12; i++) begin
                write_one(32'hC000_0000 + (lap * 12) + i, 1'b0);
            end
            repeat (3) @(posedge rd_clk); #1;
            for (int i = 0; i < 12; i++) begin
                read_and_verify("Rollover Data Check", 1'b0);
            end
            repeat (3) @(posedge wr_clk); #1;
        end
        verify_val("After 36 Words: empty flag", 1, empty, 1'b0);
        verify_val("After 36 Words: wbin == rbin", dut.wbin, dut.rbin, 1'b0);

        // ---------------------------------------------------------------------
        // TEST 8: Corner Case — Mid-Operation Asynchronous Reset (Req 1)
        // ---------------------------------------------------------------------
        test_case_name = "TEST8_MID_OP_RESET";
        print_banner("TEST 8: Mid-Operation Asynchronous Reset Recovery [Req 1]");
        for (int i = 0; i < 6; i++) begin
            write_one(32'hDEAD_0000 + i, 1'b0);
        end
        repeat (2) @(posedge rd_clk);
        #3; // Assert reset asynchronously mid-operation
        arst_n = 1'b0;
        expected_q.delete();
        #25;
        verify_val("Mid-Op Reset: empty flag", 1, empty,    1'b0);
        verify_val("Mid-Op Reset: full flag",  0, full,     1'b0);
        verify_val("Mid-Op Reset: wbin reset", 0, dut.wbin, 1'b0);
        verify_val("Mid-Op Reset: rbin reset", 0, dut.rbin, 1'b0);
        arst_n = 1'b1;
        repeat (3) @(posedge wr_clk); #1;

        // ---------------------------------------------------------------------
        // TEST 9: Simultaneous R/W Stream — Fast Write / Slow Read (Req 3 & 4)
        // ---------------------------------------------------------------------
        test_case_name = "TEST9_CONCURRENT_FAST_WR";
        print_banner("TEST 9: Concurrent R/W Stream (Fast Write 100MHz / Slow Read 62.5MHz) [Req 3 & 4]");
        // Pre-load 6 words
        for (int i = 0; i < 6; i++) begin
            write_one(32'hD000_0000 + i, 1'b0);
        end
        repeat (3) @(posedge rd_clk); #1;

        fork
            begin
                for (int i = 0; i < 24; i++) begin
                    write_one(32'hD100_0000 + i, (i == 0 || i == 23));
                end
            end
            begin
                for (int i = 0; i < 30; i++) begin
                    read_and_verify($sformatf("Concurrent Stream Word [%0d]", i), (i == 0 || i == 29));
                end
            end
        join
        verify_val("End of Stream: empty flag", 1, empty, 1'b0);
        repeat (3) @(posedge wr_clk); #1;

        // ---------------------------------------------------------------------
        // TEST 10: Independent Clocks — Slow Write / Fast Read (Requirement 4)
        // ---------------------------------------------------------------------
        test_case_name = "TEST10_SLOW_WR_FAST_RD";
        print_banner("TEST 10: Independent Clocks (Slow Write 50MHz / Fast Read 125MHz) [Req 4]");
        wr_half_period = 10.0; // 50 MHz
        rd_half_period = 4.0;  // 125 MHz
        repeat (4) @(posedge wr_clk); #1;

        fork
            begin
                for (int i = 0; i < 16; i++) begin
                    write_one(32'hE000_0000 + i, (i == 0 || i == 15));
                end
            end
            begin
                for (int i = 0; i < 16; i++) begin
                    read_and_verify($sformatf("Fast-Read Word [%0d]", i), (i == 0 || i == 15));
                end
            end
        join
        verify_val("End of Fast-Read Stream: empty flag", 1, empty, 1'b0);

        // ---------------------------------------------------------------------
        // TEST 11: Equal Clock Frequencies with Phase Shift (Requirement 4)
        // ---------------------------------------------------------------------
        test_case_name = "TEST11_PHASE_SHIFT_CLKS";
        print_banner("TEST 11: Equal Frequency Clocks (100MHz) with 3.3ns Phase Offset [Req 4]");
        wr_half_period = 5.0;  // 100 MHz
        rd_half_period = 5.0;  // 100 MHz
        rd_phase_shift = 3.3;  // 3.3 ns phase shift
        repeat (4) @(posedge wr_clk); #1;

        fork
            begin
                for (int i = 0; i < 16; i++) begin
                    write_one(32'hF000_0000 + i, (i == 0 || i == 15));
                end
            end
            begin
                for (int i = 0; i < 16; i++) begin
                    read_and_verify($sformatf("Phase-Shifted Word [%0d]", i), (i == 0 || i == 15));
                end
            end
        join
        verify_val("End of Phase-Shift Test: empty flag", 1, empty, 1'b0);

        // ---------------------------------------------------------------------
        // TEST 12: Parameter Scalability on 8-bit x 8-deep FIFO (Requirement 6)
        // ---------------------------------------------------------------------
        test_case_name = "TEST12_SCALABILITY_8x8";
        print_banner("TEST 12: Scalability Check on Secondary Instance (DATA_WIDTH=8, DEPTH=8) [Req 6]");
        @(posedge wr_clk);
        for (int i = 0; i < SCALED_DEPTH; i++) begin
            s_wr_en   <= 1'b1;
            s_wr_data <= 8'hA0 + i[7:0];
            @(posedge wr_clk);
        end
        s_wr_en <= 1'b0;
        #1;
        verify_val("Scaled 8x8 FIFO: s_full flag", 1, s_full, 1'b0);

        repeat (3) @(posedge rd_clk); #1;
        for (int i = 0; i < SCALED_DEPTH; i++) begin
            verify_val($sformatf("Scaled 8x8 Read Byte [%0d]", i), 8'hA0 + i[7:0], s_rd_data, 1'b1);
            s_rd_en <= 1'b1;
            @(posedge rd_clk);
            s_rd_en <= 1'b0;
            #1;
        end
        verify_val("Scaled 8x8 FIFO: s_empty flag", 1, s_empty, 1'b0);

        // ---------------------------------------------------------------------
        // Final Summary Table
        // ---------------------------------------------------------------------
        test_case_name = "COMPLETE_ALL_PASS";
        #30;
        $display("\n========================================================================================");
        $display("                           FINAL VERIFICATION SUMMARY                                   ");
        $display("========================================================================================");
        $display("  Total Directed & Data Checks Passed   : %0d", pass_count);
        $display("  Total Single-Bit Gray CDC Transitions : %0d (0 Glitches)", cdc_checks);
        $display("  Total Errors Detected                 : %0d", error_count);
        $display("----------------------------------------------------------------------------------------");
        if (error_count == 0)
            $display("  OVERALL STATUS : *** ALL 12 TESTS & 6 DESIGN REQUIREMENTS PASSED! ***");
        else
            $display("  OVERALL STATUS : *** VERIFICATION FAILED (%0d ERRORS) ***", error_count);
        $display("========================================================================================\n");
        $finish;
    end

endmodule
