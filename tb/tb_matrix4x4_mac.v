`timescale 1ns/1ps
module tb_matrix4x4_mac;

reg        clk, reset, start;
reg  [7:0] A, B;
reg        load_a, load_b;
reg  [3:0] load_addr;
wire [15:0] C;
wire [1:0]  C_row, C_column;
wire        C_valid, done, ready;

matrix4x4_mac DUT (
    .clk(clk), .reset(reset), .start(start),
    .A(A), .B(B),
    .load_a(load_a), .load_b(load_b),
    .load_addr(load_addr),
    .C(C), .C_row(C_row), .C_column(C_column),
    .C_valid(C_valid), .done(done), .ready(ready)
);

initial clk = 0;
always #5 clk = ~clk;

reg [7:0]  mat_a  [0:3][0:3];
reg [7:0]  mat_b  [0:3][0:3];
reg [15:0] golden [0:15];
integer pass_count, fail_count;

// ============================================
// Load matrix A into MAC registers
// ============================================
task load_matrix_a;
    integer r, c;
    begin
        for (r=0; r<4; r=r+1)
            for (c=0; c<4; c=c+1) begin
                @(negedge clk);
                A         = mat_a[r][c];
                load_a    = 1;
                load_addr = r*4 + c;
                @(negedge clk);
                load_a = 0;
            end
    end
endtask

// ============================================
// Load matrix B into MAC registers
// ============================================
task load_matrix_b;
    integer r, c;
    begin
        for (r=0; r<4; r=r+1)
            for (c=0; c<4; c=c+1) begin
                @(negedge clk);
                B         = mat_b[r][c];
                load_b    = 1;
                load_addr = r*4 + c;
                @(negedge clk);
                load_b = 0;
            end
    end
endtask

// ============================================
// Golden Reference
// ============================================
task compute_golden;
    begin : gold_block
        integer ri, ci, ki;
        reg [31:0] sum;
        for (ri=0; ri<4; ri=ri+1)
            for (ci=0; ci<4; ci=ci+1) begin
                sum = 0;
                for (ki=0; ki<4; ki=ki+1)
                    sum = sum + (mat_a[ri][ki] * mat_b[ki][ci]);
                golden[ri*4+ci] = sum[15:0];
            end
    end
endtask

// ============================================
// Run Hardware
// ============================================
task run_hardware;
    begin : run_block
        reset=1; start=0; load_a=0; load_b=0;
        A=0; B=0; load_addr=0;
        @(posedge clk);
        @(posedge clk);
        reset=0;
        @(posedge clk);

        load_matrix_a;
        load_matrix_b;

        @(posedge clk); #1; start=1;
        @(posedge clk); #1; start=0;

        wait(done==1);
        @(posedge clk);
        @(posedge clk);
    end
endtask

// ============================================
// Print Matrices
// ============================================
task print_matrices;
    begin : print_block
        integer ri;
        $display("  Matrix A:");
        for (ri=0; ri<4; ri=ri+1)
            $display("    [%3d %3d %3d %3d]",
                     mat_a[ri][0], mat_a[ri][1],
                     mat_a[ri][2], mat_a[ri][3]);
        $display("  Matrix B:");
        for (ri=0; ri<4; ri=ri+1)
            $display("    [%3d %3d %3d %3d]",
                     mat_b[ri][0], mat_b[ri][1],
                     mat_b[ri][2], mat_b[ri][3]);
        $display("  Golden C:");
        for (ri=0; ri<4; ri=ri+1)
            $display("    [%5d %5d %5d %5d]",
                     golden[ri*4+0], golden[ri*4+1],
                     golden[ri*4+2], golden[ri*4+3]);
    end
endtask

// ============================================
// Compare Results
// ============================================
task compare_results;
    input integer test_id;
    begin : cmp_block
        integer ri, ci;
        integer test_failed;
        test_failed = 0;
        $display("--- Test %0d Comparison ---", test_id);
        for (ri=0; ri<4; ri=ri+1)
            for (ci=0; ci<4; ci=ci+1) begin
                if (DUT.mat_c[ri*4+ci] === golden[ri*4+ci]) begin
                    $display("  C[%0d][%0d] Got=%-6d Expected=%-6d PASS",
                              ri, ci,
                              DUT.mat_c[ri*4+ci],
                              golden[ri*4+ci]);
                end else begin
                    $display("  C[%0d][%0d] Got=%-6d Expected=%-6d FAIL",
                              ri, ci,
                              DUT.mat_c[ri*4+ci],
                              golden[ri*4+ci]);
                    test_failed = 1;
                    fail_count = fail_count + 1;
                end
            end
        if (!test_failed) begin
            $display("  >> Test %0d PASSED!", test_id);
            pass_count = pass_count + 1;
        end else
            $display("  >> Test %0d FAILED!", test_id);
        $display("");
    end
endtask

// ============================================
// Monitor
// ============================================
always @(posedge clk) begin
    if (C_valid)
        $display("  >> C[%0d][%0d] = %0d", C_row, C_column, C);
end

// ============================================
// MAIN
// ============================================
initial begin
    pass_count = 0;
    fail_count = 0;

    begin : random_tests
        integer test_num;
        integer ri, ci;

        for (test_num=1; test_num<=2; test_num=test_num+1) begin
            $display("========================================");
            $display("TEST %0d: Random Matrices", test_num);
            $display("========================================");

            for (ri=0; ri<4; ri=ri+1)
                for (ci=0; ci<4; ci=ci+1) begin
                    mat_a[ri][ci] = $random % 16;
                    mat_b[ri][ci] = $random % 16;
                end

            compute_golden;
            print_matrices;
            run_hardware;
            compare_results(test_num);
        end
    end

    $display("========================================");
    $display("FINAL SUMMARY");
    $display("========================================");
    $display("Total Tests : %0d", pass_count + fail_count);
    $display("Passed      : %0d", pass_count);
    $display("Failed      : %0d", fail_count);
    if (fail_count == 0)
        $display("ALL TESTS PASSED!");
    else
        $display("SOME TESTS FAILED");
    $display("========================================");
    $stop;
end

endmodule