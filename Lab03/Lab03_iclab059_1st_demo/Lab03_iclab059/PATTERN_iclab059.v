`ifdef RTL
    `define CYCLE_TIME 40.0
`endif
`ifdef GATE
    `define CYCLE_TIME 40.0
`endif

`include "../00_TESTBED/pseudo_DRAM.v"
`include "../00_TESTBED/pseudo_SD.v"

module PATTERN(
    // Input Signals
    clk,
    rst_n,
    in_valid,
    direction,
    addr_dram,
    addr_sd,
    // Output Signals
    out_valid,
    out_data,
    // DRAM Signals
    AR_VALID, AR_ADDR, R_READY, AW_VALID, AW_ADDR, W_VALID, W_DATA, B_READY,
    AR_READY, R_VALID, R_RESP, R_DATA, AW_READY, W_READY, B_VALID, B_RESP,
    // SD Signals
    MISO,
    MOSI
);

// ===============================================================
// Input to design
// ===============================================================
output reg        clk, rst_n;
output reg        in_valid;
output reg        direction;
output reg [13:0] addr_dram;
output reg [15:0] addr_sd;

// ===============================================================
// Output to pattern
// ===============================================================
input        out_valid;
input  [7:0] out_data; 

// ===============================================================
// DRAM Signals
// ===============================================================

// write address channel
input [31:0] AW_ADDR;
input AW_VALID;
output AW_READY;

// write data channel
input W_VALID;
input [63:0] W_DATA;
output W_READY;

// write response channel
output B_VALID;
output [1:0] B_RESP;
input B_READY;

// read address channel
input [31:0] AR_ADDR;
input AR_VALID;
output AR_READY;

// read data channel
output [63:0] R_DATA;
output R_VALID;
output [1:0] R_RESP;
input R_READY;

// ===============================================================
// SD Signals
// ===============================================================
output MISO;
input MOSI;

// ===============================================================
// Parameter and Integer
// ===============================================================
parameter CYCLE_DELAY = 10000;
real CYCLE = `CYCLE_TIME;

integer pat_read;
integer PAT_NUM;
integer total_latency, latency;
integer i_pat;
integer f;

// INPUT
reg send_dir;
reg [12:0] dr_addr;
reg [15:0] sd_addr;

// OUTPUT
integer out_cycle;
reg [7:0]  golden[0:7];
reg [63:0] golden_dram[0:8191];
reg [63:0] golden_sd[0:65535];

// ===============================================================
// Clock Cycle
// ===============================================================
initial clk = 0;
always #(CYCLE/2.0) clk = ~clk;

// ===============================================================
// Main function
// ===============================================================
initial begin
    pat_read = $fopen("../00_TESTBED/Input.txt", "r"); 
    $readmemh("../00_TESTBED/DRAM_init.dat", golden_dram);
    $readmemh("../00_TESTBED/SD_init.dat", golden_sd);
    reset_signal_task;
    i_pat = 0;
    total_latency = 0;
    f = $fscanf(pat_read, "%d", PAT_NUM); 
    for (i_pat = 1; i_pat <= PAT_NUM; i_pat = i_pat + 1) begin
        input_task;
        wait_out_valid_task;
        check_ans_task;
        total_latency = total_latency + latency;
        $display("\033[0;32mPASS PATTERN NO.%4d\033[m", i_pat);
    end
    $fclose(pat_read);

    $writememh("../00_TESTBED/DRAM_final.dat", u_DRAM.DRAM); //Write down your DRAM Final State
    $writememh("../00_TESTBED/SD_final.dat", u_SD.SD);       //Write down your SD CARD Final State
    YOU_PASS_task;
end

//////////////////////////////////////////////////////////////////////
// Write your own task here
//////////////////////////////////////////////////////////////////////

task reset_signal_task; begin 
    rst_n      = 1'b1;
    in_valid   = 1'b0;
    direction  = 1'bx;
    addr_dram  = 13'bx;
    addr_sd    = 16'bx;

    total_latency = 0;

    force clk = 1'b0;

    #CYCLE;       rst_n = 1'b0; 
    #(CYCLE * 2); rst_n = 1'b1;
    
    if(out_valid !== 1'b0 || out_data !== 'b0 || AW_ADDR !== 'b0 || AW_VALID !== 1'b0 || W_VALID !== 1'b0 || W_DATA !== 'b0 || B_READY !== 1'b0 || AR_ADDR !== 'b0 || AR_VALID !== 1'b0 || R_READY !== 1'b0 || MOSI !== 1'b1) begin
        $display("SPEC MAIN-1 FAIL");
        $display("\033[0;32;31m---------------------------------------------------------------------------------------\033[m");
        $display("\033[0;32;31m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                                    \033[m");
        $display("\033[0;32;31m    ▄▀            ▀▄      ▄▄                                                           \033[m");
        $display("\033[0;32;31m    █  ▀   ▀       ▀▄▄   █  █      FAIL !                                              \033[m");
        $display("\033[0;32;31m    █   ▀▀            ▀▀▀   ▀▄  ╭  All output signal should be reset after RESET at %8t\033[m", $time);
        $display("\033[0;32;31m    █  ▄▀▀▀▄                 █  ╭                                                      \033[m");
        $display("\033[0;32;31m    ▀▄                       █                                                         \033[m");
        $display("\033[0;32;31m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                                          \033[m");
        $display("\033[0;32;31m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                                           \033[m");
        $display("\033[0;32;31m---------------------------------------------------------------------------------------\033[m");
        $finish;
    end

    #CYCLE; release clk;

end endtask

task input_task; begin

    // ===== Initialize ===== //
    f = $fscanf(pat_read, "%d ", send_dir);
    f = $fscanf(pat_read, "%d ", dr_addr);
    f = $fscanf(pat_read, "%d ", sd_addr);
    
    // ===== Random delay for 2 ~ 5 cycle ===== //
    repeat($random() % 2 + 2) @(negedge clk);

    // ===== Assign input signals ===== //
    in_valid  = 1'b1;
    direction = send_dir;
    addr_dram = dr_addr;
    addr_sd   = sd_addr;

    if(send_dir === 1'b1)
        golden_dram[dr_addr] = golden_sd[sd_addr]; 
    else if(send_dir === 1'b0)
        golden_sd[sd_addr] = golden_dram[dr_addr]; 

    @(negedge clk);
    in_valid  = 1'b0 ;   
    direction = 1'bx ;   
    addr_dram = 13'bx ;
    addr_sd   = 16'bx ;
    
end endtask 

task wait_out_valid_task; begin
    latency = 0;
    while(out_valid !== 1'b1) begin
        latency = latency + 1;
        if(latency == CYCLE_DELAY) begin
            $display("SPEC MAIN-3 FAIL");
            $display("\033[0;32;31m-----------------------------------------------------------------------------\033[m");
            $display("\033[0;32;31m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                          \033[m");
            $display("\033[0;32;31m    ▄▀            ▀▄      ▄▄                                                 \033[m");
            $display("\033[0;32;31m    █  ▀   ▀       ▀▄▄   █  █      FAIL !                                    \033[m");
            $display("\033[0;32;31m    █   ▀▀            ▀▀▀   ▀▄  ╭  The execution latency is over cycles  %3d\033[m", CYCLE_DELAY);
            $display("\033[0;32;31m    █  ▄▀▀▀▄                 █  ╭                                            \033[m");
            $display("\033[0;32;31m    ▀▄                       █                                               \033[m");
            $display("\033[0;32;31m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                                \033[m");
            $display("\033[0;32;31m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                                 \033[m");
            $display("\033[0;32;31m-----------------------------------------------------------------------------\033[m");
            $finish;
        end
        @(negedge clk);
    end
    total_latency = total_latency + latency;
end endtask

task get_golden_task; begin
    if(send_dir === 1'b0 && out_valid === 1'b1) begin
        golden[0] = golden_dram[dr_addr][63:56];
        golden[1] = golden_dram[dr_addr][55:48];
        golden[2] = golden_dram[dr_addr][47:40];
        golden[3] = golden_dram[dr_addr][39:32];
        golden[4] = golden_dram[dr_addr][31:24];
        golden[5] = golden_dram[dr_addr][23:16];
        golden[6] = golden_dram[dr_addr][15:8];
        golden[7] = golden_dram[dr_addr][7:0];
    end else if(send_dir === 1'b1 && out_valid === 1'b1) begin
        golden[0] = golden_sd[sd_addr][63:56];
        golden[1] = golden_sd[sd_addr][55:48];
        golden[2] = golden_sd[sd_addr][47:40];
        golden[3] = golden_sd[sd_addr][39:32];
        golden[4] = golden_sd[sd_addr][31:24];
        golden[5] = golden_sd[sd_addr][23:16];
        golden[6] = golden_sd[sd_addr][15:8];
        golden[7] = golden_sd[sd_addr][7:0];
    end
end endtask

task check_ans_task; begin
    out_cycle = 0;
    get_golden_task;
    while (out_valid === 1'b1) begin   
        for(int i=0;i<=8191;i++) begin
            if(u_DRAM.DRAM[i] !== golden_dram[i]) begin
                $display("SPEC MAIN-6 FAIL");
                $display("\033[0;32;31m-----------------------------------------------------------------------\033[m");
                $display("\033[0;32;31m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                    \033[m");
                $display("\033[0;32;31m    ▄▀            ▀▄      ▄▄                                           \033[m");
                $display("\033[0;32;31m    █  ▀   ▀       ▀▄▄   █  █      FAIL !                              \033[m");
                $display("\033[0;32;31m    █   ▀▀            ▀▀▀   ▀▄  ╭  The data in the DRAM is not correct \033[m");
                $display("\033[0;32;31m    █  ▄▀▀▀▄                 █  ╭  Your DRAM[%4d] = %h, Golden = %h    \033[m", i, u_DRAM.DRAM[i], golden_dram[i]);
                $display("\033[0;32;31m    ▀▄                       █                                         \033[m");
                $display("\033[0;32;31m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                          \033[m");
                $display("\033[0;32;31m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                           \033[m");
                $display("\033[0;32;31m-----------------------------------------------------------------------\033[m");
                $finish;
            end 
        end
        for(int i=0;i<=65535;i++) begin
            if(u_SD.SD[i] !== golden_sd[i]) begin
                $display("SPEC MAIN-6 FAIL");
                $display("\033[0;32;31m---------------------------------------------------------------------\033[m");
                $display("\033[0;32;31m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                  \033[m");
                $display("\033[0;32;31m    ▄▀            ▀▄      ▄▄                                         \033[m");
                $display("\033[0;32;31m    █  ▀   ▀       ▀▄▄   █  █      FAIL !                            \033[m");
                $display("\033[0;32;31m    █   ▀▀            ▀▀▀   ▀▄  ╭  The data in the SD is not correct \033[m");
                $display("\033[0;32;31m    █  ▄▀▀▀▄                 █  ╭  Your SD[%4d] = %h, Golden = %h    \033[m", i, u_SD.SD[i], golden_sd[i]);
                $display("\033[0;32;31m    ▀▄                       █                                       \033[m");
                $display("\033[0;32;31m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                        \033[m");
                $display("\033[0;32;31m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                         \033[m");
                $display("\033[0;32;31m---------------------------------------------------------------------\033[m");
                $finish;
            end 
        end
        if (out_cycle + 1 > 8) begin 
            $display("SPEC MAIN-4 FAIL");
            $display("\033[0;32;31m----------------------------------------------------------------------------\033[m");
            $display("\033[0;32;31m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                         \033[m");
            $display("\033[0;32;31m    ▄▀            ▀▄      ▄▄                                                \033[m");
            $display("\033[0;32;31m    █  ▀   ▀       ▀▄▄   █  █      FAIL !                                   \033[m");
            $display("\033[0;32;31m    █   ▀▀            ▀▀▀   ▀▄  ╭  The out_valid pulled up cycles are over 8\033[m");
            $display("\033[0;32;31m    █  ▄▀▀▀▄                 █  ╭                                           \033[m");
            $display("\033[0;32;31m    ▀▄                       █                                              \033[m");
            $display("\033[0;32;31m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                               \033[m");
            $display("\033[0;32;31m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                                \033[m");
            $display("\033[0;32;31m----------------------------------------------------------------------------\033[m");
            $finish;
        end else begin
            if(out_data !== golden[out_cycle])begin
                $display("SPEC MAIN-5 FAIL");
                $display("\033[0;32;31m--------------------------------------------------------------------\033[m");
                $display("\033[0;32;31m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                 \033[m");
                $display("\033[0;32;31m    ▄▀            ▀▄      ▄▄                                        \033[m");
                $display("\033[0;32;31m    █  ▀   ▀       ▀▄▄   █  █      FAIL at cycle %1d                \033[m", out_cycle);
                $display("\033[0;32;31m    █   ▀▀            ▀▀▀   ▀▄  ╭  Your out_data = %h, Golden = %h  \033[m", out_data, golden[out_cycle]);
                $display("\033[0;32;31m    █  ▄▀▀▀▄                 █  ╭                                   \033[m");
                $display("\033[0;32;31m    ▀▄                       █                                      \033[m");
                $display("\033[0;32;31m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                       \033[m");
                $display("\033[0;32;31m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                        \033[m");
                $display("\033[0;32;31m--------------------------------------------------------------------\033[m");
                $finish;   
            end     
        end
        @(negedge clk);
        out_cycle = out_cycle + 1;
    end 
    if (out_cycle < 8) begin 
        $display("SPEC MAIN-4 FAIL");
        $display("\033[0;32;31m---------------------------------------------------------------------------------\033[m");
        $display("\033[0;32;31m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                              \033[m");
        $display("\033[0;32;31m    ▄▀            ▀▄      ▄▄                                                     \033[m");
        $display("\033[0;32;31m    █  ▀   ▀       ▀▄▄   █  █      FAIL !                                        \033[m");
        $display("\033[0;32;31m    █   ▀▀            ▀▀▀   ▀▄  ╭  The out_valid pulled up cycles are less than 8\033[m");
        $display("\033[0;32;31m    █  ▄▀▀▀▄                 █  ╭                                                \033[m");
        $display("\033[0;32;31m    ▀▄                       █                                                   \033[m");
        $display("\033[0;32;31m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                                    \033[m");
        $display("\033[0;32;31m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                                     \033[m");
        $display("\033[0;32;31m---------------------------------------------------------------------------------\033[m");
        $finish;    
    end
end endtask

// ===============================================================
// Output signal spec check
// ===============================================================

always @(*)begin
    @(negedge clk);
    if(~out_valid && out_data !== 0)begin
        $display("SPEC MAIN-2 FAIL");
        $display("\033[0;32;31m---------------------------------------------------------------------------------\033[m");
        $display("\033[0;32;31m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                              \033[m");
        $display("\033[0;32;31m    ▄▀            ▀▄      ▄▄                                                     \033[m");
        $display("\033[0;32;31m    █  ▀   ▀       ▀▄▄   █  █      FAIL !                                        \033[m");
        $display("\033[0;32;31m    █   ▀▀            ▀▀▀   ▀▄  ╭  The out_data should be 0 when out_valid is low\033[m");
        $display("\033[0;32;31m    █  ▄▀▀▀▄                 █  ╭                                                \033[m");
        $display("\033[0;32;31m    ▀▄                       █                                                   \033[m");
        $display("\033[0;32;31m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                                    \033[m");
        $display("\033[0;32;31m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                                     \033[m");
        $display("\033[0;32;31m---------------------------------------------------------------------------------\033[m");
        $finish;            
    end 
end

//////////////////////////////////////////////////////////////////////


task YOU_PASS_task; begin
    $display("*************************************************************************");
    $display("*                         Congratulations!                              *");
    $display("*                Your execution cycles = %5d cycles                  *", total_latency);
    $display("*                Your clock period = %.1f ns                            *", CYCLE);
    $display("*                Total Latency = %.1f ns                          *", total_latency*CYCLE);
    $display("*************************************************************************");
    $finish;
end endtask

task YOU_FAIL_task; begin
    $display("*                              FAIL!                                    *");
    $display("*                    Error message from PATTERN.v                       *");
end endtask

pseudo_DRAM u_DRAM (
    .clk(clk),
    .rst_n(rst_n),
    // write address channel
    .AW_ADDR(AW_ADDR),
    .AW_VALID(AW_VALID),
    .AW_READY(AW_READY),
    // write data channel
    .W_VALID(W_VALID),
    .W_DATA(W_DATA),
    .W_READY(W_READY),
    // write response channel
    .B_VALID(B_VALID),
    .B_RESP(B_RESP),
    .B_READY(B_READY),
    // read address channel
    .AR_ADDR(AR_ADDR),
    .AR_VALID(AR_VALID),
    .AR_READY(AR_READY),
    // read data channel
    .R_DATA(R_DATA),
    .R_VALID(R_VALID),
    .R_RESP(R_RESP),
    .R_READY(R_READY)
);

pseudo_SD u_SD (
    .clk(clk),
    .MOSI(MOSI),
    .MISO(MISO)
);

endmodule