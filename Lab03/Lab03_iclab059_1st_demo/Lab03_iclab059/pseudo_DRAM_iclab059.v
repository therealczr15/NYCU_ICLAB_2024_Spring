//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   2023 ICLAB Fall Course
//   Lab03      : BRIDGE
//   Author     : Tzu-Yun Huang
//   Editor     : Ting-Yu Chang
//                
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : pseudo_DRAM.v
//   Module Name : pseudo_DRAM
//   Release version : v3.0 (Release Date: Sep-2023)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module pseudo_DRAM(
    clk, rst_n,
    AR_VALID, AR_ADDR, R_READY, AW_VALID, AW_ADDR, W_VALID, W_DATA, B_READY,
    AR_READY, R_VALID, R_RESP, R_DATA, AW_READY, W_READY, B_VALID, B_RESP
);

input clk, rst_n;
// write address channel
input [31:0] AW_ADDR;
input AW_VALID;
output reg AW_READY;
// write data channel
input W_VALID;
input [63:0] W_DATA;
output reg W_READY;
// write response channel
output reg B_VALID;
output reg [1:0] B_RESP;
input B_READY;
// read address channel
input [31:0] AR_ADDR;
input AR_VALID;
output reg AR_READY;
// read data channel
output reg [63:0] R_DATA;
output reg R_VALID;
output reg [1:0] R_RESP;
input R_READY;

//================================================================
// parameters & integer
//================================================================
parameter DRAM_p_r = "../00_TESTBED/DRAM_init.dat";
parameter CYCLE_DELAY = 101;
integer pat_read;
integer PAT_NUM;
integer j;
integer f;
integer lat1, lat2, lat3;

//================================================================
// wire & registers 
//================================================================
reg [63:0] DRAM[0:8191];

reg send_dir;
reg [12:0] dr_addr;
reg [15:0] sd_addr;

reg [31:0] aw_addr;
reg [31:0] ar_addr;
reg [63:0] w_data;

reg [31:0] ar_ad;
reg ar_v;
reg [31:0] aw_ad;
reg aw_v;

reg r_r;

reg w_v;
reg [63:0] w_d;

// ===============================================================
// Main function
// ===============================================================
initial begin
    pat_read = $fopen("../00_TESTBED/Input.txt", "r"); 
    $readmemh(DRAM_p_r, DRAM);
    reset_task;
    j = 0;
    f = $fscanf(pat_read, "%d", PAT_NUM); 
    for (j = 1; j <= PAT_NUM; j = j + 1) begin
        input_task;
        if(send_dir === 1'b1)
            wait_write_task;
        else if(send_dir === 1'b0)
            wait_read_task;
    end
    $fclose(pat_read);
end

// ===== SPEC DRAM-1 FAIL ===== //
always @(*) begin
    @(negedge clk);
    if(AR_VALID === 1'b0 && AR_ADDR !== 'b0) begin
        $display("SPEC DRAM-1 FAIL");
        $display("\033[0;32;31m--------------------------------------------------------------------------------\033[m");
        $display("\033[0;32;31m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                             \033[m");
        $display("\033[0;32;31m    ▄▀            ▀▄      ▄▄                                                    \033[m");
        $display("\033[0;32;31m    █  ▀   ▀       ▀▄▄   █  █      FAIL !                                       \033[m");
        $display("\033[0;32;31m    █   ▀▀            ▀▀▀   ▀▄  ╭  AR_ADDR should be reset when AR_VALID is low \033[m");
        $display("\033[0;32;31m    █  ▄▀▀▀▄                 █  ╭                                               \033[m");
        $display("\033[0;32;31m    ▀▄                       █                                                  \033[m");
        $display("\033[0;32;31m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                                   \033[m");
        $display("\033[0;32;31m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                                    \033[m");
        $display("\033[0;32;31m--------------------------------------------------------------------------------\033[m");
        $finish;
    end
end

always @(*) begin
    @(negedge clk);
    if(AW_VALID === 1'b0 && AW_ADDR !== 'b0) begin
        $display("SPEC DRAM-1 FAIL");
        $display("\033[0;32;31m--------------------------------------------------------------------------------\033[m");
        $display("\033[0;32;31m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                             \033[m");
        $display("\033[0;32;31m    ▄▀            ▀▄      ▄▄                                                    \033[m");
        $display("\033[0;32;31m    █  ▀   ▀       ▀▄▄   █  █      FAIL !                                       \033[m");
        $display("\033[0;32;31m    █   ▀▀            ▀▀▀   ▀▄  ╭  AW_ADDR should be reset when AW_VALID is low \033[m");
        $display("\033[0;32;31m    █  ▄▀▀▀▄                 █  ╭                                               \033[m");
        $display("\033[0;32;31m    ▀▄                       █                                                  \033[m");
        $display("\033[0;32;31m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                                   \033[m");
        $display("\033[0;32;31m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                                    \033[m");
        $display("\033[0;32;31m--------------------------------------------------------------------------------\033[m");
        $finish;
    end
end

always @(*) begin
    @(negedge clk);
    if(W_VALID === 1'b0 && W_DATA !== 'b0) begin
        $display("SPEC DRAM-1 FAIL");
        $display("\033[0;32;31m-----------------------------------------------------------------------------\033[m");
        $display("\033[0;32;31m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                          \033[m");
        $display("\033[0;32;31m    ▄▀            ▀▄      ▄▄                                                 \033[m");
        $display("\033[0;32;31m    █  ▀   ▀       ▀▄▄   █  █      FAIL !                                    \033[m");
        $display("\033[0;32;31m    █   ▀▀            ▀▀▀   ▀▄  ╭  W_DATA should be reset when W_VALID is low\033[m");
        $display("\033[0;32;31m    █  ▄▀▀▀▄                 █  ╭                                            \033[m");
        $display("\033[0;32;31m    ▀▄                       █                                               \033[m");
        $display("\033[0;32;31m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                                \033[m");
        $display("\033[0;32;31m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                                 \033[m");
        $display("\033[0;32;31m-----------------------------------------------------------------------------\033[m");
        $finish;
    end
end

// ===== SPEC DRAM-2 FAIL ===== //
always @(*) begin
    @(negedge clk);
    if(AR_ADDR < 0 || AW_ADDR < 0 || AR_ADDR > 8191 || AW_ADDR > 8191) begin
        $display("SPEC DRAM-2 FAIL");
        $display("\033[0;32;31m-----------------------------------------------------------------------------------------\033[m");
        $display("\033[0;32;31m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                                      \033[m");
        $display("\033[0;32;31m    ▄▀            ▀▄      ▄▄                                                             \033[m");
        $display("\033[0;32;31m    █  ▀   ▀       ▀▄▄   █  █      FAIL !                                                \033[m");
        $display("\033[0;32;31m    █   ▀▀            ▀▀▀   ▀▄  ╭  DRAM address should be within the legal range (0~8191)\033[m");
        $display("\033[0;32;31m    █  ▄▀▀▀▄                 █  ╭                                                        \033[m");
        $display("\033[0;32;31m    ▀▄                       █                                                           \033[m");
        $display("\033[0;32;31m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                                            \033[m");
        $display("\033[0;32;31m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                                             \033[m");
        $display("\033[0;32;31m-----------------------------------------------------------------------------------------\033[m");
        $finish;
    end
end

// ===== SPEC DRAM-3 FAIL ===== //
always @(*) begin
    @(negedge clk);
    if (AR_VALID === 1'b1 && AR_READY === 1'b0) begin
        ar_ad = AR_ADDR;
        ar_v  = AR_VALID;
        @(negedge clk);
        while(AR_READY === 1'b0) begin
            if(ar_ad !== AR_ADDR) begin
                $display("SPEC DRAM-3 FAIL");
                $display("\033[0;32;31m-----------------------------------------------------------------------------------------\033[m");
                $display("\033[0;32;31m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                                      \033[m");
                $display("\033[0;32;31m    ▄▀            ▀▄      ▄▄                                                             \033[m");
                $display("\033[0;32;31m    █  ▀   ▀       ▀▄▄   █  █      FAIL !                                                \033[m");
                $display("\033[0;32;31m    █   ▀▀            ▀▀▀   ▀▄  ╭  AR_ADDR should remain stable until AR_READY goes high \033[m");
                $display("\033[0;32;31m    █  ▄▀▀▀▄                 █  ╭                                                        \033[m");
                $display("\033[0;32;31m    ▀▄                       █                                                           \033[m");
                $display("\033[0;32;31m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                                            \033[m");
                $display("\033[0;32;31m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                                             \033[m");
                $display("\033[0;32;31m-----------------------------------------------------------------------------------------\033[m");
                $finish;
            end
            if(ar_v !== AR_VALID) begin
                $display("SPEC DRAM-3 FAIL");
                $display("\033[0;32;31m------------------------------------------------------------------------------------------\033[m");
                $display("\033[0;32;31m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                                       \033[m");
                $display("\033[0;32;31m    ▄▀            ▀▄      ▄▄                                                              \033[m");
                $display("\033[0;32;31m    █  ▀   ▀       ▀▄▄   █  █      FAIL !                                                 \033[m");
                $display("\033[0;32;31m    █   ▀▀            ▀▀▀   ▀▄  ╭  AR_VALID should remain stable until AR_READY goes high \033[m");
                $display("\033[0;32;31m    █  ▄▀▀▀▄                 █  ╭                                                         \033[m");
                $display("\033[0;32;31m    ▀▄                       █                                                            \033[m");
                $display("\033[0;32;31m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                                             \033[m");
                $display("\033[0;32;31m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                                              \033[m");
                $display("\033[0;32;31m------------------------------------------------------------------------------------------\033[m");
                $finish;
            end
            @(negedge clk);
        end
        if(AR_READY === 1'b1) begin
            if(ar_ad !== AR_ADDR) begin
                $display("SPEC DRAM-3 FAIL");
                $display("\033[0;32;31m-----------------------------------------------------------------------------------------\033[m");
                $display("\033[0;32;31m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                                      \033[m");
                $display("\033[0;32;31m    ▄▀            ▀▄      ▄▄                                                             \033[m");
                $display("\033[0;32;31m    █  ▀   ▀       ▀▄▄   █  █      FAIL !                                                \033[m");
                $display("\033[0;32;31m    █   ▀▀            ▀▀▀   ▀▄  ╭  AR_ADDR should remain stable until AR_READY goes high \033[m");
                $display("\033[0;32;31m    █  ▄▀▀▀▄                 █  ╭                                                        \033[m");
                $display("\033[0;32;31m    ▀▄                       █                                                           \033[m");
                $display("\033[0;32;31m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                                            \033[m");
                $display("\033[0;32;31m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                                             \033[m");
                $display("\033[0;32;31m-----------------------------------------------------------------------------------------\033[m");
                $finish;
            end
            if(ar_v !== AR_VALID) begin
                $display("SPEC DRAM-3 FAIL");
                $display("\033[0;32;31m------------------------------------------------------------------------------------------\033[m");
                $display("\033[0;32;31m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                                       \033[m");
                $display("\033[0;32;31m    ▄▀            ▀▄      ▄▄                                                              \033[m");
                $display("\033[0;32;31m    █  ▀   ▀       ▀▄▄   █  █      FAIL !                                                 \033[m");
                $display("\033[0;32;31m    █   ▀▀            ▀▀▀   ▀▄  ╭  AR_VALID should remain stable until AR_READY goes high \033[m");
                $display("\033[0;32;31m    █  ▄▀▀▀▄                 █  ╭                                                         \033[m");
                $display("\033[0;32;31m    ▀▄                       █                                                            \033[m");
                $display("\033[0;32;31m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                                             \033[m");
                $display("\033[0;32;31m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                                              \033[m");
                $display("\033[0;32;31m------------------------------------------------------------------------------------------\033[m");
                $finish;
            end
            @(negedge clk);
        end
    end
end

always @(*) begin
    @(negedge clk);
    if (AW_VALID === 1'b1 && AW_READY === 1'b0) begin
        aw_ad = AW_ADDR;
        aw_v  = AW_VALID;
        @(negedge clk);
        while(AW_READY === 1'b0) begin
            if(aw_ad !== AW_ADDR) begin
                $display("SPEC DRAM-3 FAIL");
                $display("\033[0;32;31m-----------------------------------------------------------------------------------------\033[m");
                $display("\033[0;32;31m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                                      \033[m");
                $display("\033[0;32;31m    ▄▀            ▀▄      ▄▄                                                             \033[m");
                $display("\033[0;32;31m    █  ▀   ▀       ▀▄▄   █  █      FAIL !                                                \033[m");
                $display("\033[0;32;31m    █   ▀▀            ▀▀▀   ▀▄  ╭  AW_ADDR should remain stable until AW_READY goes high \033[m");
                $display("\033[0;32;31m    █  ▄▀▀▀▄                 █  ╭                                                        \033[m");
                $display("\033[0;32;31m    ▀▄                       █                                                           \033[m");
                $display("\033[0;32;31m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                                            \033[m");
                $display("\033[0;32;31m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                                             \033[m");
                $display("\033[0;32;31m-----------------------------------------------------------------------------------------\033[m");
                $finish;
            end
            if(aw_v !== AW_VALID) begin
                $display("SPEC DRAM-3 FAIL");
                $display("\033[0;32;31m------------------------------------------------------------------------------------------\033[m");
                $display("\033[0;32;31m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                                       \033[m");
                $display("\033[0;32;31m    ▄▀            ▀▄      ▄▄                                                              \033[m");
                $display("\033[0;32;31m    █  ▀   ▀       ▀▄▄   █  █      FAIL !                                                 \033[m");
                $display("\033[0;32;31m    █   ▀▀            ▀▀▀   ▀▄  ╭  AW_VALID should remain stable until AW_READY goes high \033[m");
                $display("\033[0;32;31m    █  ▄▀▀▀▄                 █  ╭                                                         \033[m");
                $display("\033[0;32;31m    ▀▄                       █                                                            \033[m");
                $display("\033[0;32;31m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                                             \033[m");
                $display("\033[0;32;31m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                                              \033[m");
                $display("\033[0;32;31m------------------------------------------------------------------------------------------\033[m");
                $finish;
            end
            @(negedge clk);
        end
        if(AW_READY === 1'b1) begin
            if(aw_ad !== AW_ADDR) begin
                $display("SPEC DRAM-3 FAIL");
                $display("\033[0;32;31m-----------------------------------------------------------------------------------------\033[m");
                $display("\033[0;32;31m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                                      \033[m");
                $display("\033[0;32;31m    ▄▀            ▀▄      ▄▄                                                             \033[m");
                $display("\033[0;32;31m    █  ▀   ▀       ▀▄▄   █  █      FAIL !                                                \033[m");
                $display("\033[0;32;31m    █   ▀▀            ▀▀▀   ▀▄  ╭  AW_ADDR should remain stable until AW_READY goes high \033[m");
                $display("\033[0;32;31m    █  ▄▀▀▀▄                 █  ╭                                                        \033[m");
                $display("\033[0;32;31m    ▀▄                       █                                                           \033[m");
                $display("\033[0;32;31m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                                            \033[m");
                $display("\033[0;32;31m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                                             \033[m");
                $display("\033[0;32;31m-----------------------------------------------------------------------------------------\033[m");
                $finish;
            end
            if(aw_v !== AW_VALID) begin
                $display("SPEC DRAM-3 FAIL");
                $display("\033[0;32;31m------------------------------------------------------------------------------------------\033[m");
                $display("\033[0;32;31m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                                       \033[m");
                $display("\033[0;32;31m    ▄▀            ▀▄      ▄▄                                                              \033[m");
                $display("\033[0;32;31m    █  ▀   ▀       ▀▄▄   █  █      FAIL !                                                 \033[m");
                $display("\033[0;32;31m    █   ▀▀            ▀▀▀   ▀▄  ╭  AW_VALID should remain stable until AW_READY goes high \033[m");
                $display("\033[0;32;31m    █  ▄▀▀▀▄                 █  ╭                                                         \033[m");
                $display("\033[0;32;31m    ▀▄                       █                                                            \033[m");
                $display("\033[0;32;31m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                                             \033[m");
                $display("\033[0;32;31m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                                              \033[m");
                $display("\033[0;32;31m------------------------------------------------------------------------------------------\033[m");
                $finish;
            end
            @(negedge clk);
        end
    end
end

always @(*) begin
    @(negedge clk);
    if (R_READY === 1'b1 && R_VALID === 1'b0) begin
        r_r = R_READY;
        @(negedge clk);
        while(R_VALID === 1'b0) begin
            if(r_r !== R_READY) begin
                $display("SPEC DRAM-3 FAIL");
                $display("\033[0;32;31m----------------------------------------------------------------------------------------\033[m");
                $display("\033[0;32;31m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                                     \033[m");
                $display("\033[0;32;31m    ▄▀            ▀▄      ▄▄                                                            \033[m");
                $display("\033[0;32;31m    █  ▀   ▀       ▀▄▄   █  █      FAIL !                                               \033[m");
                $display("\033[0;32;31m    █   ▀▀            ▀▀▀   ▀▄  ╭  R_READY should remain stable until R_VALID goes high \033[m");
                $display("\033[0;32;31m    █  ▄▀▀▀▄                 █  ╭                                                       \033[m");
                $display("\033[0;32;31m    ▀▄                       █                                                          \033[m");
                $display("\033[0;32;31m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                                           \033[m");
                $display("\033[0;32;31m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                                            \033[m");
                $display("\033[0;32;31m----------------------------------------------------------------------------------------\033[m");
                $finish;
            end
            @(negedge clk);
        end
        if(R_VALID === 1'b1) begin
            if(r_r !== R_READY) begin
                $display("SPEC DRAM-3 FAIL");
                $display("\033[0;32;31m----------------------------------------------------------------------------------------\033[m");
                $display("\033[0;32;31m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                                     \033[m");
                $display("\033[0;32;31m    ▄▀            ▀▄      ▄▄                                                            \033[m");
                $display("\033[0;32;31m    █  ▀   ▀       ▀▄▄   █  █      FAIL !                                               \033[m");
                $display("\033[0;32;31m    █   ▀▀            ▀▀▀   ▀▄  ╭  R_READY should remain stable until R_VALID goes high \033[m");
                $display("\033[0;32;31m    █  ▄▀▀▀▄                 █  ╭                                                       \033[m");
                $display("\033[0;32;31m    ▀▄                       █                                                          \033[m");
                $display("\033[0;32;31m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                                           \033[m");
                $display("\033[0;32;31m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                                            \033[m");
                $display("\033[0;32;31m----------------------------------------------------------------------------------------\033[m");
                $finish;
            end
            @(negedge clk);
        end
    end
end

always @(*) begin
    @(negedge clk);
    if (W_VALID === 1'b1 && W_READY === 1'b0) begin
        w_d  = W_DATA;
        w_v  = W_VALID;
        @(negedge clk);
        while(W_READY === 1'b0) begin
            if(w_d !== W_DATA) begin
                $display("SPEC DRAM-3 FAIL");
                $display("\033[0;32;31m---------------------------------------------------------------------------------------\033[m");
                $display("\033[0;32;31m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                                    \033[m");
                $display("\033[0;32;31m    ▄▀            ▀▄      ▄▄                                                           \033[m");
                $display("\033[0;32;31m    █  ▀   ▀       ▀▄▄   █  █      FAIL !                                              \033[m");
                $display("\033[0;32;31m    █   ▀▀            ▀▀▀   ▀▄  ╭  W_DATA should remain stable until W_READY goes high \033[m");
                $display("\033[0;32;31m    █  ▄▀▀▀▄                 █  ╭                                                      \033[m");
                $display("\033[0;32;31m    ▀▄                       █                                                         \033[m");
                $display("\033[0;32;31m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                                          \033[m");
                $display("\033[0;32;31m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                                           \033[m");
                $display("\033[0;32;31m---------------------------------------------------------------------------------------\033[m");
                $finish;
            end
            if(w_v !== W_VALID) begin
                $display("SPEC DRAM-3 FAIL");
                $display("\033[0;32;31m----------------------------------------------------------------------------------------\033[m");
                $display("\033[0;32;31m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                                     \033[m");
                $display("\033[0;32;31m    ▄▀            ▀▄      ▄▄                                                            \033[m");
                $display("\033[0;32;31m    █  ▀   ▀       ▀▄▄   █  █      FAIL !                                               \033[m");
                $display("\033[0;32;31m    █   ▀▀            ▀▀▀   ▀▄  ╭  W_VALID should remain stable until W_READY goes high \033[m");
                $display("\033[0;32;31m    █  ▄▀▀▀▄                 █  ╭                                                       \033[m");
                $display("\033[0;32;31m    ▀▄                       █                                                          \033[m");
                $display("\033[0;32;31m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                                           \033[m");
                $display("\033[0;32;31m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                                            \033[m");
                $display("\033[0;32;31m----------------------------------------------------------------------------------------\033[m");
                $finish;
            end
            @(negedge clk);
        end
        if(W_READY === 1'b1) begin
            if(w_d !== W_DATA) begin
                $display("SPEC DRAM-3 FAIL");
                $display("\033[0;32;31m---------------------------------------------------------------------------------------\033[m");
                $display("\033[0;32;31m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                                    \033[m");
                $display("\033[0;32;31m    ▄▀            ▀▄      ▄▄                                                           \033[m");
                $display("\033[0;32;31m    █  ▀   ▀       ▀▄▄   █  █      FAIL !                                              \033[m");
                $display("\033[0;32;31m    █   ▀▀            ▀▀▀   ▀▄  ╭  W_DATA should remain stable until W_READY goes high \033[m");
                $display("\033[0;32;31m    █  ▄▀▀▀▄                 █  ╭                                                      \033[m");
                $display("\033[0;32;31m    ▀▄                       █                                                         \033[m");
                $display("\033[0;32;31m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                                          \033[m");
                $display("\033[0;32;31m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                                           \033[m");
                $display("\033[0;32;31m---------------------------------------------------------------------------------------\033[m");
                $finish;
            end
            if(w_v !== W_VALID) begin
                $display("SPEC DRAM-3 FAIL");
                $display("\033[0;32;31m----------------------------------------------------------------------------------------\033[m");
                $display("\033[0;32;31m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                                     \033[m");
                $display("\033[0;32;31m    ▄▀            ▀▄      ▄▄                                                            \033[m");
                $display("\033[0;32;31m    █  ▀   ▀       ▀▄▄   █  █      FAIL !                                               \033[m");
                $display("\033[0;32;31m    █   ▀▀            ▀▀▀   ▀▄  ╭  W_VALID should remain stable until W_READY goes high \033[m");
                $display("\033[0;32;31m    █  ▄▀▀▀▄                 █  ╭                                                       \033[m");
                $display("\033[0;32;31m    ▀▄                       █                                                          \033[m");
                $display("\033[0;32;31m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                                           \033[m");
                $display("\033[0;32;31m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                                            \033[m");
                $display("\033[0;32;31m----------------------------------------------------------------------------------------\033[m");
                $finish;
            end
            @(negedge clk);
        end
    end
end

// ===== SPEC DRAM-4 FAIL ===== //
always @(*) begin
    @(negedge clk);
    lat1 = 0;
    while(AR_READY === 1'b1) begin
        while(R_READY === 1'b0) begin
            lat1 = lat1 + 1;
            if(lat1 == CYCLE_DELAY) begin
                $display("SPEC DRAM-4 FAIL");
                $display("\033[0;32;31m--------------------------------------------------------------------------------------------------------\033[m");
                $display("\033[0;32;31m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                                                     \033[m");
                $display("\033[0;32;31m    ▄▀            ▀▄      ▄▄                                                                            \033[m");
                $display("\033[0;32;31m    █  ▀   ▀       ▀▄▄   █  █      FAIL !                                                               \033[m");
                $display("\033[0;32;31m    █   ▀▀            ▀▀▀   ▀▄  ╭  R_READY should be asserted within 100 cycles after AR_READY goes high\033[m");
                $display("\033[0;32;31m    █  ▄▀▀▀▄                 █  ╭                                                                       \033[m");
                $display("\033[0;32;31m    ▀▄                       █                                                                          \033[m");
                $display("\033[0;32;31m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                                                           \033[m");
                $display("\033[0;32;31m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                                                            \033[m");
                $display("\033[0;32;31m--------------------------------------------------------------------------------------------------------\033[m");
                $finish;
            end
            @(negedge clk);
        end 
        while(R_READY === 1'b1) begin
            lat1 = 0;
            @(negedge clk);
        end
    end
end

always @(*) begin
    @(negedge clk);
    lat2 = 0;
    while(AW_READY === 1'b1) begin
        while(W_VALID === 1'b0) begin
            lat2 = lat2 + 1;
            if(lat2 == CYCLE_DELAY) begin
                $display("SPEC DRAM-4 FAIL");
                $display("\033[0;32;31m--------------------------------------------------------------------------------------------------------\033[m");
                $display("\033[0;32;31m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                                                     \033[m");
                $display("\033[0;32;31m    ▄▀            ▀▄      ▄▄                                                                            \033[m");
                $display("\033[0;32;31m    █  ▀   ▀       ▀▄▄   █  █      FAIL !                                                               \033[m");
                $display("\033[0;32;31m    █   ▀▀            ▀▀▀   ▀▄  ╭  W_VALID should be asserted within 100 cycles after AW_READY goes high\033[m");
                $display("\033[0;32;31m    █  ▄▀▀▀▄                 █  ╭                                                                       \033[m");
                $display("\033[0;32;31m    ▀▄                       █                                                                          \033[m");
                $display("\033[0;32;31m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                                                           \033[m");
                $display("\033[0;32;31m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                                                            \033[m");
                $display("\033[0;32;31m--------------------------------------------------------------------------------------------------------\033[m");
                $finish;
            end
            @(negedge clk);
        end 
        while(W_VALID === 1'b1) begin
            lat2 = 0;
            @(negedge clk);
        end
    end
end

always @(*) begin
    @(negedge clk);
    lat3 = 0;
    while(B_VALID === 1'b1) begin
        while(B_READY === 1'b0) begin
            lat3 = lat3 + 1;
            if(lat3 == CYCLE_DELAY) begin
                $display("SPEC DRAM-4 FAIL");
                $display("\033[0;32;31m--------------------------------------------------------------------------------------------------------\033[m");
                $display("\033[0;32;31m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                                                     \033[m");
                $display("\033[0;32;31m    ▄▀            ▀▄      ▄▄                                                                            \033[m");
                $display("\033[0;32;31m    █  ▀   ▀       ▀▄▄   █  █      FAIL !                                                               \033[m");
                $display("\033[0;32;31m    █   ▀▀            ▀▀▀   ▀▄  ╭  B_READY should be asserted within 100 cycles after B_VALID goes high \033[m");
                $display("\033[0;32;31m    █  ▄▀▀▀▄                 █  ╭                                                                       \033[m");
                $display("\033[0;32;31m    ▀▄                       █                                                                          \033[m");
                $display("\033[0;32;31m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                                                           \033[m");
                $display("\033[0;32;31m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                                                            \033[m");
                $display("\033[0;32;31m--------------------------------------------------------------------------------------------------------\033[m");
                $finish;
            end
            @(negedge clk);
        end 
        while(B_READY === 1'b1) begin
            lat3 = 0;
            @(negedge clk);
        end       
    end
end

// ===== SPEC DRAM-5 FAIL ===== //
always @(*) begin
    @(negedge clk);
    if(AR_READY === 1'b1 || AR_VALID === 1'b1) begin
        if(R_READY === 1'b1) begin
            $display("SPEC DRAM-5 FAIL");
            $display("\033[0;32;31m---------------------------------------------------------------------------------------------------------\033[m");
            $display("\033[0;32;31m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                                                      \033[m");
            $display("\033[0;32;31m    ▄▀            ▀▄      ▄▄                                                                             \033[m");
            $display("\033[0;32;31m    █  ▀   ▀       ▀▄▄   █  █      FAIL !                                                                \033[m");
            $display("\033[0;32;31m    █   ▀▀            ▀▀▀   ▀▄  ╭  R_READY should not be pulled high when AR_READY or AR_VALID goes high \033[m");
            $display("\033[0;32;31m    █  ▄▀▀▀▄                 █  ╭                                                                        \033[m");
            $display("\033[0;32;31m    ▀▄                       █                                                                           \033[m");
            $display("\033[0;32;31m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                                                            \033[m");
            $display("\033[0;32;31m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                                                             \033[m");
            $display("\033[0;32;31m---------------------------------------------------------------------------------------------------------\033[m");
            $finish;
        end 
    end
end

always @(*) begin
    @(negedge clk);
    if(AW_READY === 1'b1 || AW_VALID === 1'b1) begin
        if(W_VALID === 1'b1) begin
            $display("SPEC DRAM-5 FAIL");
            $display("\033[0;32;31m---------------------------------------------------------------------------------------------------------\033[m");
            $display("\033[0;32;31m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                                                      \033[m");
            $display("\033[0;32;31m    ▄▀            ▀▄      ▄▄                                                                             \033[m");
            $display("\033[0;32;31m    █  ▀   ▀       ▀▄▄   █  █      FAIL !                                                                \033[m");
            $display("\033[0;32;31m    █   ▀▀            ▀▀▀   ▀▄  ╭  W_VALID should not be pulled high when AW_READY or AW_VALID goes high \033[m");
            $display("\033[0;32;31m    █  ▄▀▀▀▄                 █  ╭                                                                        \033[m");
            $display("\033[0;32;31m    ▀▄                       █                                                                           \033[m");
            $display("\033[0;32;31m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                                                            \033[m");
            $display("\033[0;32;31m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                                                             \033[m");
            $display("\033[0;32;31m---------------------------------------------------------------------------------------------------------\033[m");
            $finish;
        end 
    end
end

//////////////////////////////////////////////////////////////////////
// Write your own task here
//////////////////////////////////////////////////////////////////////

task reset_task; begin
    AW_READY = 'b0;
    W_READY  = 'b0;
    B_RESP   = 'b0;
    B_VALID  = 'b0;
    AR_READY = 'b0;
    R_DATA   = 'b0;
    R_RESP   = 'b0;
    R_VALID  = 'b0;
    w_data   = 'bx;
    @(negedge clk);
end endtask

task input_task; begin
    f = $fscanf(pat_read, "%d ", send_dir);
    f = $fscanf(pat_read, "%d ", dr_addr);
    f = $fscanf(pat_read, "%d ", sd_addr);
end endtask 

task wait_write_task; begin
    while(AW_VALID !== 1'b1)
        @(negedge clk);
    while(AW_VALID === 1'b1 && AW_READY === 1'b0) begin
        aw_addr = AW_ADDR;
        w_data  = 'bx;
        repeat($urandom() % 50 + 1) @(posedge clk);
        AW_READY = 1'b1;
        @(negedge clk);
    end 
    while(AW_VALID === 1'b1 && AW_READY === 1'b1) begin
        @(posedge clk);
        AW_READY = 1'b0;
        repeat($urandom() % 99) @(posedge clk);
        W_READY = 1'b1;
        @(negedge clk);
    end 
    while(W_VALID !== 1'b1)
        @(negedge clk);
    while(W_VALID === 1'b1 && W_READY === 1'b1) begin
        w_data = W_DATA;
        @(posedge clk);
        W_READY = 1'b0;
        repeat($urandom() % 99) @(posedge clk);
        B_VALID = 1'b1;
        @(negedge clk);
    end 
    while(B_READY !== 1'b1)
        @(negedge clk);
    while(B_VALID === 1'b1 && B_READY === 1'b1) begin
        DRAM[aw_addr] = w_data;
        @(posedge clk);
        B_VALID = 1'b0;
        @(negedge clk);
    end
end endtask

task wait_read_task; begin
    while(AR_VALID !== 1'b1)
        @(negedge clk);
    while(AR_VALID === 1'b1 && AR_READY === 1'b0) begin
        ar_addr = AR_ADDR;
        repeat($urandom() % 50 + 1) @(posedge clk);
        AR_READY = 1'b1;
        @(negedge clk);
    end 
    while(AR_VALID === 1'b1 && AR_READY === 1'b1) begin
        @(posedge clk);
        AR_READY = 1'b0;
        repeat($urandom() % 99) @(posedge clk);
        R_VALID = 1'b1;
        R_DATA  = DRAM[ar_addr];
        @(negedge clk);
    end
    while(R_READY !== 1'b1)
        @(negedge clk);
    while(R_VALID === 1'b1 && R_READY === 1'b1) begin
        @(posedge clk);
        R_VALID = 1'b0;
        R_DATA  = 'b0;
        @(negedge clk);
    end
end endtask

//////////////////////////////////////////////////////////////////////

task YOU_FAIL_task; begin
    $display("*                              FAIL!                                    *");
    $display("*                 Error message from pseudo_SD.v                        *");
end endtask

endmodule