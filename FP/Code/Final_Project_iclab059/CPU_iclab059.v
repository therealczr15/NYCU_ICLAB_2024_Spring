//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2021 Final Project: Customized ISA Processor 
//   Author              : Hsi-Hao Huang
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : CPU.v
//   Module Name : CPU.v
//   Release version : V1.0 (Release Date: 2021-May)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module CPU(

        clk,
        rst_n,
  
       IO_stall,

         awid_m_inf,
       awaddr_m_inf,
       awsize_m_inf,
      awburst_m_inf,
        awlen_m_inf,
      awvalid_m_inf,
      awready_m_inf,
                    
        wdata_m_inf,
        wlast_m_inf,
       wvalid_m_inf,
       wready_m_inf,
                    
          bid_m_inf,
        bresp_m_inf,
       bvalid_m_inf,
       bready_m_inf,
                    
         arid_m_inf,
       araddr_m_inf,
        arlen_m_inf,
       arsize_m_inf,
      arburst_m_inf,
      arvalid_m_inf,
                    
      arready_m_inf, 
          rid_m_inf,
        rdata_m_inf,
        rresp_m_inf,
        rlast_m_inf,
       rvalid_m_inf,
       rready_m_inf 

);
// Input port
input  wire clk, rst_n;
// Output port
output reg  IO_stall;

parameter ID_WIDTH = 4 , ADDR_WIDTH = 32, DATA_WIDTH = 16, DRAM_NUMBER=2, WRIT_NUMBER=1;

// AXI Interface wire connecttion for pseudo DRAM read/write
/* Hint:
  your AXI-4 interface could be designed as convertor in submodule(which used reg for output signal),
  therefore I declared output of AXI as wire in CPU
*/



// axi write address channel 
output  wire [WRIT_NUMBER * ID_WIDTH-1:0]        awid_m_inf;
output  wire [WRIT_NUMBER * ADDR_WIDTH-1:0]    awaddr_m_inf;
output  wire [WRIT_NUMBER * 3 -1:0]            awsize_m_inf;
output  wire [WRIT_NUMBER * 2 -1:0]           awburst_m_inf;
output  wire [WRIT_NUMBER * 7 -1:0]             awlen_m_inf;
output  wire [WRIT_NUMBER-1:0]                awvalid_m_inf;
input   wire [WRIT_NUMBER-1:0]                awready_m_inf;
// axi write data channel 
output  wire [WRIT_NUMBER * DATA_WIDTH-1:0]     wdata_m_inf;
output  wire [WRIT_NUMBER-1:0]                  wlast_m_inf;
output  wire [WRIT_NUMBER-1:0]                 wvalid_m_inf;
input   wire [WRIT_NUMBER-1:0]                 wready_m_inf;
// axi write response channel
input   wire [WRIT_NUMBER * ID_WIDTH-1:0]         bid_m_inf;
input   wire [WRIT_NUMBER * 2 -1:0]             bresp_m_inf;
input   wire [WRIT_NUMBER-1:0]                 bvalid_m_inf;
output  wire [WRIT_NUMBER-1:0]                 bready_m_inf;
// -----------------------------
// axi read address channel 
output  wire [DRAM_NUMBER * ID_WIDTH-1:0]       arid_m_inf;
output  wire [DRAM_NUMBER * ADDR_WIDTH-1:0]   araddr_m_inf;
output  wire [DRAM_NUMBER * 7 -1:0]            arlen_m_inf;
output  wire [DRAM_NUMBER * 3 -1:0]           arsize_m_inf;
output  wire [DRAM_NUMBER * 2 -1:0]          arburst_m_inf;
output  wire [DRAM_NUMBER-1:0]               arvalid_m_inf;
input   wire [DRAM_NUMBER-1:0]               arready_m_inf;
// -----------------------------
// axi read data channel 
input   wire [DRAM_NUMBER * ID_WIDTH-1:0]         rid_m_inf;
input   wire [DRAM_NUMBER * DATA_WIDTH-1:0]     rdata_m_inf;
input   wire [DRAM_NUMBER * 2 -1:0]             rresp_m_inf;
input   wire [DRAM_NUMBER-1:0]                  rlast_m_inf;
input   wire [DRAM_NUMBER-1:0]                 rvalid_m_inf;
output  wire [DRAM_NUMBER-1:0]                 rready_m_inf;
// -----------------------------

//
//
// 
/* Register in each core:
  There are sixteen registers in your CPU. You should not change the name of those registers.
  TA will check the value in each register when your core is not busy.
  If you change the name of registers below, you must get the fail in this lab.
*/

reg signed [15:0] core_r0 , core_r1 , core_r2 , core_r3 ;
reg signed [15:0] core_r4 , core_r5 , core_r6 , core_r7 ;
reg signed [15:0] core_r8 , core_r9 , core_r10, core_r11;
reg signed [15:0] core_r12, core_r13, core_r14, core_r15;

//==============================================//
//                  REG & WIRE                  //
//==============================================//

// DRAM FSM
reg  [2:0] cur_dram, nxt_dram;

// AXI4 READ ADDR CHANNEL
reg  arvalid_inst, arvalid_data;
reg  [ADDR_WIDTH-1:0] araddr_inst, araddr_data;

// AXI4 READ DATA CHANNEL
reg  rready_inst, rready_data;
reg  [6:0] cnt_read, cnt_read_comb;
wire [6:0] cnt_readAddOne;
reg  [DRAM_NUMBER * DATA_WIDTH-1:0] rdata;
reg  [DRAM_NUMBER-1:0] rvalid;
reg  [DRAM_NUMBER-1:0] rlast;

// AXI4 WRITE ADDR CHANNEL
reg  [WRIT_NUMBER-1:0]              awvalid;
reg  [WRIT_NUMBER * ADDR_WIDTH-1:0]  awaddr;

// AXI4 WRITE DATA CHANNEL
reg                    wvalid;
reg                     wlast;
reg  [DATA_WIDTH-1:0]   wdata;

// AXI4 WRITE DATA CHANNEL
reg                    bready;

// FSM
reg  [2:0] cur_state, nxt_state;

// PC
reg signed [12:0] pc;
reg signed [12:0] pc_comb;
reg  [11:0] pc_l_bound, pc_u_bound;
wire [11:0] pc_addOne;
reg  [11:0] pc_l_bound_comb, pc_u_bound_comb;

wire lowerbound, upperbound;

// INSTRUCTION (IF)
reg  [15:0] inst, inst_comb;
wire [2:0]  opcode;
wire [3:0]  rs_idx, rt_idx, rd_idx;
wire func;
wire signed [4:0] imm;
wire [3:0] coef_a;
wire [8:0] coef_b;

// ALU (EXE)
reg signed [15:0] ALU_out, ALU_out_comb, ALU_in1, ALU_in2, rt;

reg  [4:0] cnt_exe, cnt_exe_comb;
wire [4:0] cnt_exeAddOne;

reg  signed [16:0] mul1, mul2, mul3, mul4;
wire signed [33:0] mul_out1, mul_out2;
wire signed [67:0] mul_out3;

reg  signed [73:0] add_out, add_out_comb;

wire signed [73:0] det_shift;
wire signed [73:0] det;

// CORE
reg signed [15:0] core_r0_comb , core_r1_comb , core_r2_comb , core_r3_comb ;
reg signed [15:0] core_r4_comb , core_r5_comb , core_r6_comb , core_r7_comb ;
reg signed [15:0] core_r8_comb , core_r9_comb , core_r10_comb, core_r11_comb;
reg signed [15:0] core_r12_comb, core_r13_comb, core_r14_comb, core_r15_comb;

// IO_STALL
reg  IO_stall_comb;

// SRAM
reg  [6:0]  sram_addr;
reg  [15:0] sram_do, sram_di;
reg  sram_w;

//==============================================//
//              DRAM FSM PARAMETER              //
//==============================================//

parameter D_IDLE  = 3'd0;
parameter D_AR    = 3'd1;
parameter D_R     = 3'd2;
parameter D_AW    = 3'd3;
parameter D_W     = 3'd4;
parameter D_B     = 3'd5;

//==============================================//
//                FSM PARAMETER                 //
//==============================================//

parameter S_IF = 3'd0;
parameter S_IF_DRAM = 3'd1;
parameter S_ID = 3'd2;
parameter S_EXE = 3'd3;
parameter S_MEM_DRAM = 3'd4;
parameter S_WB = 3'd5;
parameter S_WB_DRAM = 3'd6;
parameter S_STALL = 3'd7;

//==============================================//
//                   DRAM FSM                   //
//==============================================//

always @(*) begin
  case(cur_dram)
    D_IDLE: begin
      if(cur_state == S_IF_DRAM || cur_state == S_MEM_DRAM) // 
        nxt_dram = D_AR;
      else if(cur_state == S_WB_DRAM)
        nxt_dram = D_AW;
      else
        nxt_dram = cur_dram;
    end
    D_AR: begin
      if((arready_m_inf[1] && cur_state == S_IF_DRAM) || (arready_m_inf[0] && cur_state == S_MEM_DRAM))
        nxt_dram = D_R;
      else
        nxt_dram = cur_dram;
    end
    D_R: begin
      if((rlast_m_inf[1] && cur_state == S_IF_DRAM) || (rlast_m_inf[0] && cur_state == S_MEM_DRAM))
        nxt_dram = D_IDLE;
      else
        nxt_dram = cur_dram;
    end
    D_AW: begin
      if(awready_m_inf)
        nxt_dram = D_W;
      else
        nxt_dram = cur_dram;
    end
    D_W: begin
      if(wready_m_inf)
        nxt_dram = D_B;
      else
        nxt_dram = cur_dram;
    end
    D_B: begin
      if(bvalid_m_inf)
        nxt_dram = D_IDLE;
      else
        nxt_dram = cur_dram;
    end
    default: nxt_dram = cur_dram;
  endcase 
end

always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    cur_dram <= D_IDLE;
  else
    cur_dram <= nxt_dram;
end

//==============================================//
//                 AXI4 CONTROL                 //
//==============================================//

// READ ADDR CHANNEL
assign    arid_m_inf = {4'd0,4'd0};
assign arburst_m_inf = {2'd1,2'd1};
assign  arsize_m_inf = {3'd1,3'd1};
assign   arlen_m_inf = {7'd127,7'd0};

always @(*) begin
  case(cur_dram)
    D_AR: begin
      if(cur_state == S_IF_DRAM)
        arvalid_inst = 1;
      else
        arvalid_inst = 0;
    end
    default: arvalid_inst = 0;
  endcase
end

always @(*) begin
  case(cur_dram)
    D_AR: begin
      if(cur_state == S_MEM_DRAM)
        arvalid_data = 1;
      else
        arvalid_data = 0;
    end
    default: arvalid_data = 0;
  endcase
end

assign arvalid_m_inf = {arvalid_inst,arvalid_data};

always @(*) begin
  case(cur_state)
    S_IF_DRAM: begin
      if(pc < 1920)
        araddr_inst = {20'h00001,pc[10:0],1'b0};
      else
        araddr_inst = {20'h00001,11'd1920,1'b0};
    end
    default: araddr_inst = 0;
  endcase
end

always @(*) begin
  case(cur_state)
    S_MEM_DRAM: araddr_data = {20'h00001,ALU_out[10:0],1'b0};
    default: araddr_data = 0;
  endcase
end

assign  araddr_m_inf = {araddr_inst,araddr_data};

// READ DATA CHANNEL
always @(*) begin
  case(cur_dram)
    D_R: begin
      if(cur_state == S_IF_DRAM)
        rready_inst = 1;
      else
        rready_inst = 0;
    end
    default: rready_inst = 0;
  endcase
end

always @(*) begin
  case(cur_dram)
    D_R: begin
      if(cur_state == S_MEM_DRAM)
        rready_data = 1;
      else
        rready_data = 0;
    end
    default: rready_data = 0;
  endcase
end

assign rready_m_inf = {rready_inst,rready_data};

always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    rdata <= 0;
  else
    rdata <= rdata_m_inf;
end

always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    rvalid <= 0;
  else
    rvalid <= rvalid_m_inf;
end

always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    rlast <= 0;
  else
    rlast <= rlast_m_inf;
end

assign cnt_readAddOne = cnt_read + 1;

always @(*) begin
  if(rvalid_m_inf[1])
    cnt_read_comb = cnt_readAddOne;
  else
    cnt_read_comb = 0;
end

always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    cnt_read <= 0;
  else
    cnt_read <= cnt_read_comb;
end



// WRITE ADDR CHANNEL
assign    awid_m_inf = 4'd0;
assign awburst_m_inf = 2'd1;
assign  awsize_m_inf = 3'd1;
assign   awlen_m_inf = 7'd0;

always @(*) begin
  case(cur_dram)
    D_AW: awvalid = 1;
    default: awvalid = 0;
  endcase
end

assign awvalid_m_inf = awvalid;

always @(*) begin
  case(cur_state)
    S_WB_DRAM: awaddr = {20'h00001,ALU_out[10:0],1'b0};
    default: awaddr = 0;
  endcase
end

assign  awaddr_m_inf = awaddr;

// WRITE DATA CHANNEL
always @(*) begin
  case(cur_dram)
    D_W: wvalid = 1;
    default: wvalid = 0;
  endcase
end

assign wvalid_m_inf = wvalid;

always @(*) begin
  case(cur_dram)
    D_W: wlast = 1;
    default: wlast = 0;
  endcase
end

assign  wlast_m_inf = wlast;

always @(*) begin
  case(cur_dram)
    D_W: wdata = rt;
    default: wdata = 0;
  endcase
end

assign  wdata_m_inf = wdata;

// WRITE RESP CHANNEL
always @(*) begin
  case(cur_dram)
    D_W: bready = 1;
    D_B: bready = 1;
    default: bready = 0;
  endcase
end

assign bready_m_inf = bready;

//==============================================//
//                     FSM                      //
//==============================================//

always @(*) begin
  case(cur_state)
    S_IF: begin
      if(upperbound | lowerbound)
        nxt_state = S_IF_DRAM;
      else
        nxt_state = S_ID;
    end
    S_IF_DRAM: begin
      if(rlast_m_inf[1])
        nxt_state = S_IF;
      else
        nxt_state = cur_state;
    end
    S_ID: nxt_state = S_EXE;
    S_EXE: begin
      case(inst[15:13])
        0: nxt_state = S_WB;
        1: nxt_state = S_WB;
        2: nxt_state = S_MEM_DRAM;
        3: nxt_state = S_WB_DRAM;
        4: nxt_state = S_WB;
        7: begin
          if(cnt_exe == 23)
            nxt_state = S_WB;
          else
            nxt_state = cur_state;
        end
        default: nxt_state = cur_state;
      endcase
    end
    S_MEM_DRAM: begin
      if(rlast_m_inf[0])
        nxt_state = S_WB;
      else
        nxt_state = cur_state;
    end
    S_WB: nxt_state = S_STALL;
    S_WB_DRAM: begin
      if(bvalid_m_inf)
        nxt_state = S_STALL;
      else
        nxt_state = cur_state;
    end
    S_STALL: nxt_state = S_IF;
    default: nxt_state = cur_state;
  endcase 
end

always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    cur_state <= S_IF;
  else
    cur_state <= nxt_state;
end

//==============================================//
//               PROGRAM COUNTER                //
//==============================================//

// pc
assign pc_addOne = pc + 1;

always @(*) begin
  case(cur_state)
    S_EXE: begin
      if(cnt_exe == 0)
        pc_comb = pc_addOne;
      else
        pc_comb = pc;
    end
    S_WB: begin
      if(inst[15:13] == 4 && ALU_out == 1)
        pc_comb = pc + imm;
      else
        pc_comb = pc;
    end
    default: pc_comb = pc;
  endcase 
end

always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    pc <= 0;
  else
    pc <= pc_comb;
end

// pc_l_bound
always @(*) begin
  case(cur_state)
    S_IF_DRAM: begin
      if(pc < 1920)
        pc_l_bound_comb = pc;
      else
        pc_l_bound_comb = 1920;
    end
    default: pc_l_bound_comb = pc_l_bound;
  endcase
end

always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    pc_l_bound <= 0;
  else
    pc_l_bound <= pc_l_bound_comb;
end

// pc_u_bound
always @(*) begin
  case(cur_state)
    S_IF_DRAM: begin
      if(pc < 1920)
        pc_u_bound_comb = pc + 128;
      else
        pc_u_bound_comb = 2048;
    end
    default: pc_u_bound_comb = pc_u_bound;
  endcase
end

always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    pc_u_bound <= 0;
  else
    pc_u_bound <= pc_u_bound_comb;
end

assign lowerbound = pc <  pc_l_bound;
assign upperbound = pc >= pc_u_bound;

//==============================================//
//                 INSTRUCTION                  //
//==============================================//

always @(*) begin
  case(cur_state)
    S_ID: inst_comb = sram_do;
    default: inst_comb = inst;
  endcase
end

always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    inst <= 0;
  else
    inst <= inst_comb;
end

assign opcode = inst[15:13];
assign rs_idx = inst[12:9];
assign rt_idx = inst[8:5];
assign rd_idx = inst[4:1];
assign func = inst[0];
assign imm = inst[4:0];
assign coef_a = inst[12:9];
assign coef_b = inst[8:0];

//==============================================//
//                  ALU (EXE)                   //
//==============================================//

// ALU_in1
always @(*) begin
  case(inst[12:9])
    0:  ALU_in1 = core_r0;
    1:  ALU_in1 = core_r1;
    2:  ALU_in1 = core_r2;
    3:  ALU_in1 = core_r3;
    4:  ALU_in1 = core_r4;
    5:  ALU_in1 = core_r5;
    6:  ALU_in1 = core_r6;
    7:  ALU_in1 = core_r7;
    8:  ALU_in1 = core_r8;
    9:  ALU_in1 = core_r9;
    10: ALU_in1 = core_r10;
    11: ALU_in1 = core_r11;
    12: ALU_in1 = core_r12;
    13: ALU_in1 = core_r13;
    14: ALU_in1 = core_r14;
    15: ALU_in1 = core_r15;
  endcase
end

// rt
always @(*) begin
  case(inst[8:5])
    0:  rt = core_r0;
    1:  rt = core_r1;
    2:  rt = core_r2;
    3:  rt = core_r3;
    4:  rt = core_r4;
    5:  rt = core_r5;
    6:  rt = core_r6;
    7:  rt = core_r7;
    8:  rt = core_r8;
    9:  rt = core_r9;
    10: rt = core_r10;
    11: rt = core_r11;
    12: rt = core_r12;
    13: rt = core_r13;
    14: rt = core_r14;
    15: rt = core_r15;
  endcase
end

// ALU_in2
always @(*) begin
  case(inst[15:13])
    0: ALU_in2 = rt;
    1: ALU_in2 = rt;
    2: ALU_in2 = imm;
    3: ALU_in2 = imm; 
    4: ALU_in2 = rt;
    default: ALU_in2 = 0;  
  endcase
end

// ALU_out
always @(*) begin
  case(opcode)
    3'b000: begin
      if(func)
        ALU_out_comb = ALU_in1 - ALU_in2;
      else
        ALU_out_comb = ALU_in1 + ALU_in2;
    end
    3'b001: begin
      if(func)
        ALU_out_comb = ALU_in1 * ALU_in2;
      else
        ALU_out_comb = (ALU_in1 < ALU_in2);
    end
    3'b010: ALU_out_comb = ALU_in1 + ALU_in2;
    3'b011: ALU_out_comb = ALU_in1 + ALU_in2;
    3'b100: ALU_out_comb = (ALU_in1 == ALU_in2);
    //3'b111: ALU_out_comb = 0;
    default: ALU_out_comb = 0;
  endcase
end

always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    ALU_out <= 0;
  else
    ALU_out <= ALU_out_comb;
end

// cnt_exe
always @(*) begin
  case(cur_state)
    S_EXE: cnt_exe_comb = cnt_exeAddOne;
    default: cnt_exe_comb = 0;
  endcase
end

assign cnt_exeAddOne = cnt_exe + 1;

always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    cnt_exe <= 0;
  else
    cnt_exe <= cnt_exe_comb;
end

// mul
// 3 4 5 6 7 8 15 16 17 18 19 20
always @(*) begin
  case(cnt_exe)
    0:  mul1 = core_r0;
    1:  mul1 = core_r0;
    2:  mul1 = core_r0;
    3:  mul1 = core_r0;
    4:  mul1 = core_r0;
    5:  mul1 = core_r0;
    6:  mul1 = core_r1;
    7:  mul1 = core_r2;
    8:  mul1 = core_r3;
    9:  mul1 = core_r3;
    10: mul1 = core_r2;
    11: mul1 = core_r1;
    12: mul1 = core_r1;
    13: mul1 = core_r2;
    14: mul1 = core_r3;
    15: mul1 = core_r3;
    16: mul1 = core_r2;
    17: mul1 = core_r1;
    18: mul1 = core_r1;
    19: mul1 = core_r2; 
    20: mul1 = core_r3;
    21: mul1 = core_r3;
    22: mul1 = core_r2;
    23: mul1 = core_r1;
    default: mul1 = 0;
  endcase
end

always @(*) begin
  case(cnt_exe)
    0:  mul2 = core_r5;
    1:  mul2 = core_r6;
    2:  mul2 = core_r7;
    3:  mul2 = core_r7;
    4:  mul2 = core_r6;
    5:  mul2 = core_r5;
    6:  mul2 = core_r4;
    7:  mul2 = core_r4;
    8:  mul2 = core_r4;
    9:  mul2 = core_r4;
    10: mul2 = core_r4;
    11: mul2 = core_r4;
    12: mul2 = core_r6;
    13: mul2 = core_r7;
    14: mul2 = core_r5;
    15: mul2 = core_r6;
    16: mul2 = core_r5;
    17: mul2 = core_r7;
    18: mul2 = core_r6;
    19: mul2 = core_r7; 
    20: mul2 = core_r5;
    21: mul2 = core_r6;
    22: mul2 = core_r5;
    23: mul2 = core_r7;
    default: mul2 = 0;
  endcase
end

always @(*) begin
  case(cnt_exe)
    0:  mul3 = core_r10;
    1:  mul3 = core_r11;
    2:  mul3 = core_r9;
    3:  mul3 = core_r10;
    4:  mul3 = core_r9;
    5:  mul3 = core_r11;
    6:  mul3 = core_r10;
    7:  mul3 = core_r11;
    8:  mul3 = core_r9;
    9:  mul3 = core_r10;
    10: mul3 = core_r9;
    11: mul3 = core_r11;
    12: mul3 = core_r8;
    13: mul3 = core_r8;
    14: mul3 = core_r8;
    15: mul3 = core_r8;
    16: mul3 = core_r8;
    17: mul3 = core_r8;
    18: mul3 = core_r11;
    19: mul3 = core_r9; 
    20: mul3 = core_r10;
    21: mul3 = core_r9;
    22: mul3 = core_r11;
    23: mul3 = core_r10;
    default: mul3 = 0;
  endcase
end

always @(*) begin
  case(cnt_exe)
    0:  mul4 = core_r15;
    1:  mul4 = core_r13;
    2:  mul4 = core_r14;
    3:  mul4 = core_r13;
    4:  mul4 = core_r15;
    5:  mul4 = core_r14;
    6:  mul4 = core_r15;
    7:  mul4 = core_r13;
    8:  mul4 = core_r14;
    9:  mul4 = core_r13;
    10: mul4 = core_r15;
    11: mul4 = core_r14;
    12: mul4 = core_r15;
    13: mul4 = core_r13;
    14: mul4 = core_r14;
    15: mul4 = core_r13;
    16: mul4 = core_r15;
    17: mul4 = core_r14;
    18: mul4 = core_r12;
    19: mul4 = core_r12; 
    20: mul4 = core_r12;
    21: mul4 = core_r12;
    22: mul4 = core_r12;
    23: mul4 = core_r12;
    default: mul4 = 0;
  endcase
end

assign mul_out1 = mul1 * mul2;
assign mul_out2 = mul3 * mul4;
assign mul_out3 = mul_out1 * mul_out2;

always @(*) begin
  case(cur_state)
    S_IF: add_out_comb = 0;
    S_EXE: begin
      case(cnt_exe)
        3, 4, 5, 6, 7, 8, 15, 16, 17, 18, 19, 20 : add_out_comb = add_out - mul_out3;
        default: add_out_comb = add_out + mul_out3;
      endcase
    end
    default: add_out_comb = add_out;
  endcase
end

always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    add_out <= 0;
  else
    add_out <= add_out_comb;
end

assign det_shift = (add_out >>> (2 * coef_a));
assign det       = det_shift  + coef_b;

//==============================================//
//                CORE REGISTER                 //
//==============================================//

always @(*) begin
  case(cur_state)
    S_WB: begin
      case(inst[15:13])
        0: begin
          if(inst[4:1] == 0)
            core_r0_comb = ALU_out;
          else
            core_r0_comb = core_r0;
        end
        1: begin
          if(inst[4:1] == 0)
            core_r0_comb = ALU_out;
          else
            core_r0_comb = core_r0;
        end
        2: begin
          if(inst[8:5] == 0)
            core_r0_comb = rdata;
          else
            core_r0_comb = core_r0;
        end
        7: begin
          if(det > 32767)
            core_r0_comb = 32767;
          else if(det < -32768)
            core_r0_comb = -32768;
          else
            core_r0_comb = det[15:0];
        end
        default: core_r0_comb = core_r0;
      endcase
    end
    default: core_r0_comb = core_r0;
  endcase
end

always @(*) begin
  case(cur_state)
    S_WB: begin
      case(inst[15:13])
        0: begin
          if(inst[4:1] == 1)
            core_r1_comb = ALU_out;
          else
            core_r1_comb = core_r1;
        end
        1: begin
          if(inst[4:1] == 1)
            core_r1_comb = ALU_out;
          else
            core_r1_comb = core_r1;
        end
        2: begin
          if(inst[8:5] == 1)
            core_r1_comb = rdata;
          else
            core_r1_comb = core_r1;
        end
        default: core_r1_comb = core_r1;
      endcase
    end
    default: core_r1_comb = core_r1;
  endcase
end

always @(*) begin
  case(cur_state)
    S_WB: begin
      case(inst[15:13])
        0: begin
          if(inst[4:1] == 2)
            core_r2_comb = ALU_out;
          else
            core_r2_comb = core_r2;
        end
        1: begin
          if(inst[4:1] == 2)
            core_r2_comb = ALU_out;
          else
            core_r2_comb = core_r2;
        end
        2: begin
          if(inst[8:5] == 2)
            core_r2_comb = rdata;
          else
            core_r2_comb = core_r2;
        end
        default: core_r2_comb = core_r2;
      endcase
    end
    default: core_r2_comb = core_r2;
  endcase
end

always @(*) begin
  case(cur_state)
    S_WB: begin
      case(inst[15:13])
        0: begin
          if(inst[4:1] == 3)
            core_r3_comb = ALU_out;
          else
            core_r3_comb = core_r3;
        end
        1: begin
          if(inst[4:1] == 3)
            core_r3_comb = ALU_out;
          else
            core_r3_comb = core_r3;
        end
        2: begin
          if(inst[8:5] == 3)
            core_r3_comb = rdata;
          else
            core_r3_comb = core_r3;
        end
        default: core_r3_comb = core_r3;
      endcase
    end
    default: core_r3_comb = core_r3;
  endcase
end

always @(*) begin
  case(cur_state)
    S_WB: begin
      case(inst[15:13])
        0: begin
          if(inst[4:1] == 4)
            core_r4_comb = ALU_out;
          else
            core_r4_comb = core_r4;
        end
        1: begin
          if(inst[4:1] == 4)
            core_r4_comb = ALU_out;
          else
            core_r4_comb = core_r4;
        end
        2: begin
          if(inst[8:5] == 4)
            core_r4_comb = rdata;
          else
            core_r4_comb = core_r4;
        end
        default: core_r4_comb = core_r4;
      endcase
    end
    default: core_r4_comb = core_r4;
  endcase
end

always @(*) begin
  case(cur_state)
    S_WB: begin
      case(inst[15:13])
        0: begin
          if(inst[4:1] == 5)
            core_r5_comb = ALU_out;
          else
            core_r5_comb = core_r5;
        end
        1: begin
          if(inst[4:1] == 5)
            core_r5_comb = ALU_out;
          else
            core_r5_comb = core_r5;
        end
        2: begin
          if(inst[8:5] == 5)
            core_r5_comb = rdata;
          else
            core_r5_comb = core_r5;
        end
        default: core_r5_comb = core_r5;
      endcase
    end
    default: core_r5_comb = core_r5;
  endcase
end

always @(*) begin
  case(cur_state)
    S_WB: begin
      case(inst[15:13])
        0: begin
          if(inst[4:1] == 6)
            core_r6_comb = ALU_out;
          else
            core_r6_comb = core_r6;
        end
        1: begin
          if(inst[4:1] == 6)
            core_r6_comb = ALU_out;
          else
            core_r6_comb = core_r6;
        end
        2: begin
          if(inst[8:5] == 6)
            core_r6_comb = rdata;
          else
            core_r6_comb = core_r6;
        end
        default: core_r6_comb = core_r6;
      endcase
    end
    default: core_r6_comb = core_r6;
  endcase
end

always @(*) begin
  case(cur_state)
    S_WB: begin
      case(inst[15:13])
        0: begin
          if(inst[4:1] == 7)
            core_r7_comb = ALU_out;
          else
            core_r7_comb = core_r7;
        end
        1: begin
          if(inst[4:1] == 7)
            core_r7_comb = ALU_out;
          else
            core_r7_comb = core_r7;
        end
        2: begin
          if(inst[8:5] == 7)
            core_r7_comb = rdata;
          else
            core_r7_comb = core_r7;
        end
        default: core_r7_comb = core_r7;
      endcase
    end
    default: core_r7_comb = core_r7;
  endcase
end

always @(*) begin
  case(cur_state)
    S_WB: begin
      case(inst[15:13])
        0: begin
          if(inst[4:1] == 8)
            core_r8_comb = ALU_out;
          else
            core_r8_comb = core_r8;
        end
        1: begin
          if(inst[4:1] == 8)
            core_r8_comb = ALU_out;
          else
            core_r8_comb = core_r8;
        end
        2: begin
          if(inst[8:5] == 8)
            core_r8_comb = rdata;
          else
            core_r8_comb = core_r8;
        end
        default: core_r8_comb = core_r8;
      endcase
    end
    default: core_r8_comb = core_r8;
  endcase
end

always @(*) begin
  case(cur_state)
    S_WB: begin
      case(inst[15:13])
        0: begin
          if(inst[4:1] == 9)
            core_r9_comb = ALU_out;
          else
            core_r9_comb = core_r9;
        end
        1: begin
          if(inst[4:1] == 9)
            core_r9_comb = ALU_out;
          else
            core_r9_comb = core_r9;
        end
        2: begin
          if(inst[8:5] == 9)
            core_r9_comb = rdata;
          else
            core_r9_comb = core_r9;
        end
        default: core_r9_comb = core_r9;
      endcase
    end
    default: core_r9_comb = core_r9;
  endcase
end

always @(*) begin
  case(cur_state)
    S_WB: begin
      case(inst[15:13])
        0: begin
          if(inst[4:1] == 10)
            core_r10_comb = ALU_out;
          else
            core_r10_comb = core_r10;
        end
        1: begin
          if(inst[4:1] == 10)
            core_r10_comb = ALU_out;
          else
            core_r10_comb = core_r10;
        end
        2: begin
          if(inst[8:5] == 10)
            core_r10_comb = rdata;
          else
            core_r10_comb = core_r10;
        end
        default: core_r10_comb = core_r10;
      endcase
    end
    default: core_r10_comb = core_r10;
  endcase
end

always @(*) begin
  case(cur_state)
    S_WB: begin
      case(inst[15:13])
        0: begin
          if(inst[4:1] == 11)
            core_r11_comb = ALU_out;
          else
            core_r11_comb = core_r11;
        end
        1: begin
          if(inst[4:1] == 11)
            core_r11_comb = ALU_out;
          else
            core_r11_comb = core_r11;
        end
        2: begin
          if(inst[8:5] == 11)
            core_r11_comb = rdata;
          else
            core_r11_comb = core_r11;
        end
        default: core_r11_comb = core_r11;
      endcase
    end
    default: core_r11_comb = core_r11;
  endcase
end

always @(*) begin
  case(cur_state)
    S_WB: begin
      case(inst[15:13])
        0: begin
          if(inst[4:1] == 12)
            core_r12_comb = ALU_out;
          else
            core_r12_comb = core_r12;
        end
        1: begin
          if(inst[4:1] == 12)
            core_r12_comb = ALU_out;
          else
            core_r12_comb = core_r12;
        end
        2: begin
          if(inst[8:5] == 12)
            core_r12_comb = rdata;
          else
            core_r12_comb = core_r12;
        end
        default: core_r12_comb = core_r12;
      endcase
    end
    default: core_r12_comb = core_r12;
  endcase
end

always @(*) begin
  case(cur_state)
    S_WB: begin
      case(inst[15:13])
        0: begin
          if(inst[4:1] == 13)
            core_r13_comb = ALU_out;
          else
            core_r13_comb = core_r13;
        end
        1: begin
          if(inst[4:1] == 13)
            core_r13_comb = ALU_out;
          else
            core_r13_comb = core_r13;
        end
        2: begin
          if(inst[8:5] == 13)
            core_r13_comb = rdata;
          else
            core_r13_comb = core_r13;
        end
        default: core_r13_comb = core_r13;
      endcase
    end
    default: core_r13_comb = core_r13;
  endcase
end

always @(*) begin
  case(cur_state)
    S_WB: begin
      case(inst[15:13])
        0: begin
          if(inst[4:1] == 14)
            core_r14_comb = ALU_out;
          else
            core_r14_comb = core_r14;
        end
        1: begin
          if(inst[4:1] == 14)
            core_r14_comb = ALU_out;
          else
            core_r14_comb = core_r14;
        end
        2: begin
          if(inst[8:5] == 14)
            core_r14_comb = rdata;
          else
            core_r14_comb = core_r14;
        end
        default: core_r14_comb = core_r14;
      endcase
    end
    default: core_r14_comb = core_r14;
  endcase
end

always @(*) begin
  case(cur_state)
    S_WB: begin
      case(inst[15:13])
        0: begin
          if(inst[4:1] == 15)
            core_r15_comb = ALU_out;
          else
            core_r15_comb = core_r15;
        end
        1: begin
          if(inst[4:1] == 15)
            core_r15_comb = ALU_out;
          else
            core_r15_comb = core_r15;
        end
        2: begin
          if(inst[8:5] == 15)
            core_r15_comb = rdata;
          else
            core_r15_comb = core_r15;
        end
        default: core_r15_comb = core_r15;
      endcase
    end
    default: core_r15_comb = core_r15;
  endcase
end



always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    core_r0 <= 0;
  else
    core_r0 <= core_r0_comb;
end

always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    core_r1 <= 0;
  else
    core_r1 <= core_r1_comb;
end

always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    core_r2 <= 0;
  else
    core_r2 <= core_r2_comb;
end

always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    core_r3 <= 0;
  else
    core_r3 <= core_r3_comb;
end

always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    core_r4 <= 0;
  else
    core_r4 <= core_r4_comb;
end

always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    core_r5 <= 0;
  else
    core_r5 <= core_r5_comb;
end

always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    core_r6 <= 0;
  else
    core_r6 <= core_r6_comb;
end

always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    core_r7 <= 0;
  else
    core_r7 <= core_r7_comb;
end

always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    core_r8 <= 0;
  else
    core_r8 <= core_r8_comb;
end

always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    core_r9 <= 0;
  else
    core_r9 <= core_r9_comb;
end

always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    core_r10 <= 0;
  else
    core_r10 <= core_r10_comb;
end

always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    core_r11 <= 0;
  else
    core_r11 <= core_r11_comb;
end

always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    core_r12 <= 0;
  else
    core_r12 <= core_r12_comb;
end

always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    core_r13 <= 0;
  else
    core_r13 <= core_r13_comb;
end

always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    core_r14 <= 0;
  else
    core_r14 <= core_r14_comb;
end

always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    core_r15 <= 0;
  else
    core_r15 <= core_r15_comb;
end

//==============================================//
//                     SRAM                     //
//==============================================// 

// SRAM adddress
always @(*) begin
  case(cur_state)
    S_IF: sram_addr = pc - pc_l_bound;
    S_IF_DRAM: sram_addr = cnt_read;
    default: sram_addr = 0;
  endcase
end

// SRAM write
always @(*) begin                                                   
  case(cur_state)
    S_IF_DRAM: sram_w = 0;
    default: sram_w = 1;
  endcase
end

// SRAM DI
always @(*) begin
  case(cur_state)
    S_IF_DRAM: sram_di = rdata_m_inf[31:16];
    default: sram_di = 0;
  endcase
end

// SRAM Module
Sram_128x16 S0 (
    .A0(sram_addr[0]),   .A1(sram_addr[1]),   .A2(sram_addr[2]),    .A3(sram_addr[3]),   .A4(sram_addr[4]),  .A5(sram_addr[5]),   .A6(sram_addr[6]),
    .DO0(sram_do[0]),    .DO1(sram_do[1]),    .DO2(sram_do[2]),     .DO3(sram_do[3]),    .DO4(sram_do[4]),   .DO5(sram_do[5]),    .DO6(sram_do[6]),   .DO7(sram_do[7]),  
    .DO8(sram_do[8]),    .DO9(sram_do[9]),    .DO10(sram_do[10]),   .DO11(sram_do[11]),  .DO12(sram_do[12]), .DO13(sram_do[13]),  .DO14(sram_do[14]), .DO15(sram_do[15]),
    .DI0(sram_di[0]),    .DI1(sram_di[1]),    .DI2(sram_di[2]),     .DI3(sram_di[3]),    .DI4(sram_di[4]),   .DI5(sram_di[5]),    .DI6(sram_di[6]),   .DI7(sram_di[7]),   
    .DI8(sram_di[8]),    .DI9(sram_di[9]),    .DI10(sram_di[10]),   .DI11(sram_di[11]),  .DI12(sram_di[12]), .DI13(sram_di[13]),  .DI14(sram_di[14]), .DI15(sram_di[15]),   
    .CK(clk), .WEB(sram_w),   .OE(1'b1), .CS(1'b1)
    );

//==============================================//
//                   IO_STALL                   //
//==============================================// 

always @(*) begin
  case(cur_state)
    S_STALL: IO_stall_comb = 0;
    default: IO_stall_comb = 1;
  endcase
end

always @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    IO_stall <= 1;
  else
    IO_stall <= IO_stall_comb;
end

endmodule
