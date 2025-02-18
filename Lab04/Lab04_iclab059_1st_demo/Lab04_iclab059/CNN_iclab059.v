//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2023 Fall
//   Lab04 Exercise     : Convolution Neural Network 
//   Author             : Cheng-Te Chang (chengdez.ee12@nycu.edu.tw)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : CNN.v
//   Module Name : CNN
//   Release version : V1.0 (Release Date: 2024-02)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module CNN(
    //Input Port
    clk,
    rst_n,
    in_valid,
    Img,
    Kernel,
    Weight,
    Opt,

    //Output Port
    out_valid,
    out
    );

//==============================================//
//                  PARAMETER                   //
//==============================================//

// IEEE floating point parameter
parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 0;
parameter inst_arch_type = 0;
parameter inst_arch = 0;
parameter inst_faithful_round = 0;

//==============================================//
//                   I/O PORT                   //
//==============================================//

input rst_n, clk, in_valid;
input [inst_sig_width+inst_exp_width:0] Img, Kernel, Weight;
input [1:0] Opt;

output reg out_valid;
output reg [inst_sig_width+inst_exp_width:0] out;

//==============================================//
//            REG & WIRE DECLARATION            //
//==============================================//

parameter   S_IDLE          =   3'd0;
parameter   S_INPUT1        =   3'd1;
parameter   S_INPUT2        =   3'd3;
parameter   S_INPUT3        =   3'd2;
parameter   S_CONV          =   3'd6;
parameter   S_POOL          =   3'd7;
parameter   S_FIND_MAX_MIN  =   3'd5;
parameter   S_NORM          =   3'd4;

// FSM
reg [2:0] cur_state, nxt_state;

// COUNTER
reg  [3:0] cnt, cnt_comb;
wire [3:0] cntAddOne;

// IMAGE
reg  [inst_sig_width+inst_exp_width:0] img[0:15], img_comb[0:15];

// KERNEL
reg  [inst_sig_width+inst_exp_width:0] knl[0:17], knl_comb[0:17];

// WEIGHT
reg  [inst_sig_width+inst_exp_width:0] wgt[0:3], wgt_comb[0:3];

// OPT
reg  [1:0] opt, opt_comb;

// PADDING
reg  [inst_sig_width+inst_exp_width:0] pad[0:35], pad_comb[0:35];

// MAC
wire [inst_sig_width+inst_exp_width:0] mac_a[0:15], mac_b[0:15], mac_c[0:15], m_z[0:15], mac_z[0:15];

// PE(STORE CONVOLUTION RESULT)
reg  [inst_sig_width+inst_exp_width:0] pe[0:15], pe_comb[0:15];

// POOLING
reg  [inst_sig_width+inst_exp_width:0] pool[0:3], pool_comb[0:3];
reg  [inst_sig_width+inst_exp_width:0] cmpa[0:3], cmpb[0:3], max[0:5], min[0:2], max_min, norm_min, max_min_comb, norm_min_comb;

// FC
reg  [inst_sig_width+inst_exp_width:0] fc[0:3], fc_comb[0:3];

// NORMALIZATION
reg  [inst_sig_width+inst_exp_width:0] norm[0:3], norm_comb[0:3];
wire [inst_sig_width+inst_exp_width:0] adder_a, adder_b, adder_z;
wire [inst_sig_width+inst_exp_width:0] norm_scaled_comb;
reg  [inst_sig_width+inst_exp_width:0] norm_scaled, norm_scaled_store;

// EXP
wire [inst_sig_width+inst_exp_width:0] exp_out;
wire [inst_exp_width-1:0] two_z;
reg  [inst_sig_width+inst_exp_width:0] exp_in;

// ACT
reg [inst_sig_width+inst_exp_width:0] act_comb[0:3], act[0:3];

// RECIPROCAL
reg [inst_sig_width+inst_exp_width:0] deno;

// LN
wire [inst_sig_width+inst_exp_width:0] ln_out;

// OUTPUT
reg [inst_sig_width+inst_exp_width:0] out_comb;
reg out_valid_comb;

//==============================================//
//                     FSM                      //
//==============================================//

always @(*) begin
    case(cur_state)
        S_IDLE: begin
            if(in_valid)
                nxt_state = S_INPUT1;
            else
                nxt_state = S_IDLE;
        end
        S_INPUT1: begin
            if(&cnt)
                nxt_state = S_INPUT2;
            else
                nxt_state = S_INPUT1;
        end
        S_INPUT2: begin
            if(&cnt)
                nxt_state = S_INPUT3;
            else
                nxt_state = S_INPUT2;
        end
        S_INPUT3: begin
            if(&cnt)
                nxt_state = S_CONV;
            else
                nxt_state = S_INPUT3;
        end
        S_CONV: begin
            if(cnt[3])
                nxt_state = S_POOL;
            else
                nxt_state = S_CONV;
        end
        S_POOL: begin
            if(cnt[1])
                nxt_state = S_FIND_MAX_MIN;
            else
                nxt_state = S_POOL;
        end
        S_FIND_MAX_MIN: nxt_state = S_NORM;
        S_NORM: begin
            case(opt)
                2'd0: begin
                    if(cnt[2])
                        nxt_state = S_IDLE;
                    else
                        nxt_state = S_NORM;
                end
                2'd1: begin
                    if(cnt[3])
                        nxt_state = S_IDLE;
                    else
                        nxt_state = S_NORM;
                end
                default: begin
                    if(&cnt[2:0])
                        nxt_state = S_IDLE;
                    else
                        nxt_state = S_NORM;
                end
            endcase
        end
        default: nxt_state = cur_state;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        cur_state <= 0;
    else 
        cur_state <= nxt_state;
end

//==============================================//
//                   COUNTER                    //
//==============================================//

assign cntAddOne = cnt + 1;

always @(*) begin
    case(cur_state)
        S_IDLE: cnt_comb = 0;
        S_INPUT1: cnt_comb = cntAddOne;
        S_INPUT2: cnt_comb = cntAddOne;
        S_INPUT3: cnt_comb = cntAddOne;
        S_CONV: cnt_comb = (cnt[3]) ? 0 : cntAddOne;
        S_POOL: cnt_comb = (cnt[1]) ? 0 : cntAddOne;
        S_FIND_MAX_MIN: cnt_comb = 0;
        S_NORM: begin
            case(opt)
                2'd0: begin
                    if(cnt[2])
                        cnt_comb = 0;
                    else
                        cnt_comb = cntAddOne;
                end
                2'd1: begin
                    if(cnt[3])
                        cnt_comb = 0;
                    else
                        cnt_comb = cntAddOne;
                end
                default: begin
                    if(&cnt[2:0])
                        cnt_comb = 0;
                    else
                        cnt_comb = cntAddOne;
                end
            endcase
        end
        default: cnt_comb = 0;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        cnt <= 0;
    else
        cnt <= cnt_comb;
end

//==============================================//
//                    IMAGE                     //
//==============================================//

always @(*) begin
    if(in_valid)
        img_comb = {img[1:15],Img};
    else
        img_comb = img;
end

genvar i;
generate
    for(i=0;i<16;i=i+1) begin
        always @(posedge clk) begin
            img[i] <= img_comb[i];
        end
    end
endgenerate
        
//==============================================//
//                    KERNEL                    //
//==============================================//

always @(*) begin
    case(cur_state)
        S_IDLE: knl_comb = {knl[1:16],Kernel,32'd0};
        S_INPUT1: knl_comb = {knl[1:16],Kernel,32'd0};
        S_INPUT2: begin
            if(cnt < 9) 
                knl_comb = {knl[1:16],Kernel,32'd0};
            else if(cnt == 9) 
                knl_comb = {knl[0:16],Kernel};
            else 
                knl_comb = knl;
        end
        S_INPUT3: begin
            if(cnt < 9)
                knl_comb = {knl[1:17],32'd0};
            else 
                knl_comb = knl;
        end
        S_CONV: knl_comb = {knl[1:17],32'd0};
        default: knl_comb = knl;
    endcase
end

genvar i;
generate
    for(i=0;i<18;i=i+1) begin
        always @(posedge clk) begin
            knl[i] <= knl_comb[i];
        end
    end
endgenerate

//==============================================//
//                    WEIGHT                    //
//==============================================//

always @(*) begin
    case(cur_state)
        S_IDLE: wgt_comb = {wgt[1:3],Weight};
        S_INPUT1: begin
            if(cnt < 3) 
                wgt_comb = {wgt[1:3],Weight};
            else 
                wgt_comb = wgt;
        end
        S_POOL: wgt_comb = {wgt[2:3],wgt[0:1]};
        default: wgt_comb = wgt;
    endcase
end
            
genvar i;
generate
    for(i=0;i<4;i=i+1) begin
        always @(posedge clk) begin
            wgt[i] <= wgt_comb[i];
        end
    end
endgenerate

//==============================================//
//                     OPT                      //
//==============================================//

always @(*) begin
    if(in_valid && cur_state == S_IDLE)
        opt_comb = Opt;
    else
        opt_comb = opt;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        opt <= 0;
    else
        opt <= opt_comb;
end

//==============================================//
//                   PADDING                    //
//==============================================//

always @(*) begin
    if(&cnt && opt[1]) begin
        pad_comb[0]  = img[0] ; pad_comb[1]  = img[0] ; pad_comb[2]  = img[1] ; pad_comb[3]  = img[2] ; pad_comb[4]  = img[3] ; pad_comb[5]  = img[3] ;
        pad_comb[6]  = img[0] ; pad_comb[7]  = img[0] ; pad_comb[8]  = img[1] ; pad_comb[9]  = img[2] ; pad_comb[10] = img[3] ; pad_comb[11] = img[3] ;
        pad_comb[12] = img[4] ; pad_comb[13] = img[4] ; pad_comb[14] = img[5] ; pad_comb[15] = img[6] ; pad_comb[16] = img[7] ; pad_comb[17] = img[7] ;
        pad_comb[18] = img[8] ; pad_comb[19] = img[8] ; pad_comb[20] = img[9] ; pad_comb[21] = img[10]; pad_comb[22] = img[11]; pad_comb[23] = img[11];
        pad_comb[24] = img[12]; pad_comb[25] = img[12]; pad_comb[26] = img[13]; pad_comb[27] = img[14]; pad_comb[28] = img[15]; pad_comb[29] = img[15];
        pad_comb[30] = img[12]; pad_comb[31] = img[12]; pad_comb[32] = img[13]; pad_comb[33] = img[14]; pad_comb[34] = img[15]; pad_comb[35] = img[15];
    end else if(&cnt && !opt[1]) begin
        pad_comb[0]  = 0; pad_comb[1]  = 0      ; pad_comb[2]  = 0      ; pad_comb[3]  = 0      ; pad_comb[4]  = 0      ; pad_comb[5]  = 0;
        pad_comb[6]  = 0; pad_comb[7]  = img[0] ; pad_comb[8]  = img[1] ; pad_comb[9]  = img[2] ; pad_comb[10] = img[3] ; pad_comb[11] = 0;
        pad_comb[12] = 0; pad_comb[13] = img[4] ; pad_comb[14] = img[5] ; pad_comb[15] = img[6] ; pad_comb[16] = img[7] ; pad_comb[17] = 0;
        pad_comb[18] = 0; pad_comb[19] = img[8] ; pad_comb[20] = img[9] ; pad_comb[21] = img[10]; pad_comb[22] = img[11]; pad_comb[23] = 0;
        pad_comb[24] = 0; pad_comb[25] = img[12]; pad_comb[26] = img[13]; pad_comb[27] = img[14]; pad_comb[28] = img[15]; pad_comb[29] = 0;
        pad_comb[30] = 0; pad_comb[31] = 0      ; pad_comb[32] = 0      ; pad_comb[33] = 0      ; pad_comb[34] = 0      ; pad_comb[35] = 0;
    end else if(cnt == 2 || cnt == 5) begin
        pad_comb = {pad[4:35],pad[0:3]};
    end else begin
        pad_comb = {pad[1:35],pad[0]};
    end
end

genvar i;
generate
    for(i=0;i<36;i=i+1) begin
        always @(posedge clk) begin
            pad[i] <= pad_comb[i]; 
        end
    end
endgenerate

//==============================================//
//                 CONVOLUTION                  //
//==============================================//

always @(*) begin
    case(cur_state) 
        S_IDLE: begin
            for(int j=0;j<16;j=j+1) begin
                pe_comb[j] = 0;
            end
        end     
        S_INPUT2: begin
            if(cnt < 9) 
                pe_comb = mac_z;
            else 
                pe_comb = pe;
        end
        S_INPUT3: begin
            if(cnt < 9) 
                pe_comb = mac_z;
            else 
                pe_comb = pe;
        end
        S_CONV: pe_comb = mac_z;
        S_POOL: pe_comb = {pe[2:15],pe[0:1]};
        default:pe_comb = pe;
    endcase
end

genvar i;
generate
    for(i=0;i<16;i=i+1) begin
        always @(posedge clk) begin
            pe[i] <= pe_comb[i]; 
        end
    end
endgenerate

//==============================================//
//                   POOLING                    //
//==============================================//

assign pool_comb = {pool[2:3],max[4],max[5]};

genvar i;
generate
    for(i=0;i<4;i=i+1) begin
        always @(posedge clk) begin
            pool[i] <= pool_comb[i]; 
        end
    end
endgenerate

//==============================================//
//               FULLY CONNECTED                //
//==============================================//

always @(*) begin
    case (cur_state)
        S_IDLE: begin
            fc_comb[0] = 0;
            fc_comb[1] = 0;
            fc_comb[2] = 0;
            fc_comb[3] = 0;
        end
        S_POOL: begin
            if(cnt >= 1) 
                fc_comb = mac_z[0:3];
            else 
                fc_comb = fc;
        end
        S_NORM: fc_comb = {fc[1:3],fc[0]};
        default: fc_comb = fc;
    endcase       
end

genvar i;
generate
    for(i=0;i<4;i=i+1) begin
        always @(posedge clk) begin
            fc[i] <= fc_comb[i]; 
        end
    end
endgenerate

//==============================================//
//    MAC(DO CONVOLUTION & FULLY CONNECTED)     //
//==============================================//

assign mac_a[0]  = (cur_state == S_POOL) ? pool[2] : pad[0];
assign mac_a[1]  = (cur_state == S_POOL) ? pool[2] : pad[1];
assign mac_a[2]  = (cur_state == S_POOL) ? pool[3] : pad[2];
assign mac_a[3]  = (cur_state == S_POOL) ? pool[3] : pad[3];
assign mac_a[4]  = pad[6];
assign mac_a[5]  = (cur_state == S_NORM) ? act[3] : pad[7];
assign mac_a[6]  = (cur_state == S_NORM) ? norm[3] : pad[8];
assign mac_a[7]  = (cur_state == S_NORM) ? fc[0] : pad[9];
assign mac_a[8]  = (cur_state == S_NORM) ? act[1] : pad[12];
assign mac_a[9]  = pad[13];
assign mac_a[10] = pad[14];
assign mac_a[11] = pad[15];
assign mac_a[12] = pad[18];
assign mac_a[13] = pad[19];
assign mac_a[14] = pad[20];
assign mac_a[15] = pad[21];

assign mac_b[0]  = (cur_state == S_POOL) ? wgt[2] : knl[0];
assign mac_b[1]  = (cur_state == S_POOL) ? wgt[3] : knl[0];
assign mac_b[2]  = (cur_state == S_POOL) ? wgt[2] : knl[0];
assign mac_b[3]  = (cur_state == S_POOL) ? wgt[3] : knl[0]; 
assign mac_b[4]  = knl[0];
assign mac_b[5]  = (cur_state == S_NORM) ? 32'h3F800000 : knl[0];
assign mac_b[6]  = (cur_state == S_NORM) ? norm_scaled : knl[0];
assign mac_b[7]  = (cur_state == S_NORM) ? 32'h3F800000 : knl[0];
assign mac_b[8]  = (cur_state == S_NORM) ? 32'hC0000000 : knl[0];
assign mac_b[9]  = knl[0];
assign mac_b[10] = knl[0];
assign mac_b[11] = knl[0];
assign mac_b[12] = knl[0];
assign mac_b[13] = knl[0];
assign mac_b[14] = knl[0];
assign mac_b[15] = knl[0];

assign mac_c[0]  = (cur_state == S_POOL) ? fc[0] : pe[0];
assign mac_c[1]  = (cur_state == S_POOL) ? fc[1] : pe[1];
assign mac_c[2]  = (cur_state == S_POOL) ? fc[2] : pe[2];
assign mac_c[3]  = (cur_state == S_POOL) ? fc[3] : pe[3];
assign mac_c[4]  = pe[4];
assign mac_c[5]  = (cur_state == S_NORM) ? 32'h3F800000 : pe[5];
assign mac_c[6]  = (cur_state == S_NORM) ? 32'd0 : pe[6];
assign mac_c[7]  = (cur_state == S_NORM) ? {~norm_min[inst_sig_width+inst_exp_width],norm_min[inst_sig_width+inst_exp_width-1:0]} : pe[7];
assign mac_c[8]  = (cur_state == S_NORM) ? 32'h3F800000 : pe[8];
assign mac_c[9]  = pe[9];
assign mac_c[10] = pe[10];
assign mac_c[11] = pe[11];
assign mac_c[12] = pe[12];
assign mac_c[13] = pe[13];
assign mac_c[14] = pe[14];
assign mac_c[15] = pe[15];

//==============================================//
//    COMPARATOR(DO POOLING & NORMALIZATION)    //
//==============================================//

assign cmpa[0] = (cur_state == S_FIND_MAX_MIN) ? fc[0] : pe[0];
assign cmpb[0] = (cur_state == S_FIND_MAX_MIN) ? fc[1] : pe[1];
assign cmpa[1] = (cur_state == S_FIND_MAX_MIN) ? fc[2] : pe[4];
assign cmpb[1] = (cur_state == S_FIND_MAX_MIN) ? fc[3] : pe[5];

assign cmpa[2] = (cur_state == S_FIND_MAX_MIN) ? min[0] : pe[8];
assign cmpb[2] = (cur_state == S_FIND_MAX_MIN) ? min[1] : pe[9];
assign cmpa[3] = pe[12];
assign cmpb[3] = pe[13];

DW_fp_cmp #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
CMP0 ( .a(cmpa[0]), .b(cmpb[0]), .zctr(1'b1),.z0(max[0]), .z1(min[0]));

DW_fp_cmp #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
CMP1 ( .a(cmpa[1]), .b(cmpb[1]), .zctr(1'b1),.z0(max[1]), .z1(min[1]));

DW_fp_cmp #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
CMP2 ( .a(max[0]), .b(max[1]), .zctr(1'b1),.z0(max[4]));

DW_fp_cmp #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
CMP3 ( .a(cmpa[2]), .b(cmpb[2]), .zctr(1'b1),.z0(max[2]), .z1(min[2]));

DW_fp_cmp #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
CMP4 ( .a(cmpa[3]), .b(cmpb[3]), .zctr(1'b1),.z0(max[3]));

DW_fp_cmp #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
CMP5 ( .a(max[2]), .b(max[3]), .zctr(1'b1),.z0(max[5]));

//==============================================//
//                FIND MAX & MIN                //
//==============================================//

// FIND MIN, MAX & CALCULATE MAX - MIN
DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance) 
A17(.a(max[4]), .b({~min[2][inst_sig_width+inst_exp_width],min[2][inst_sig_width+inst_exp_width-1:0]}), .rnd(3'b000), .z(adder_z));

assign max_min_comb  = (cur_state == S_FIND_MAX_MIN) ? adder_z : max_min;
assign norm_min_comb = (cur_state == S_FIND_MAX_MIN) ? min[2] : norm_min;

always @(posedge clk) begin
    max_min <= max_min_comb; 
end

always @(posedge clk) begin
    norm_min <= norm_min_comb; 
end

//==============================================//
//                NORMALIZATION                 //
//==============================================//

always @(*) begin
    if(cnt == 0)
        deno = max_min;
    else
        deno = act[2];
end

DW_fp_recip #(inst_sig_width, inst_exp_width, inst_ieee_compliance,inst_faithful_round) 
R1 (.a(deno),.rnd(3'b000),.z(norm_scaled_comb));

always @(*) begin
    case(cur_state)
        S_NORM: begin
            if(cnt == 0)
                norm_scaled_store = norm_scaled_comb;
            else
                norm_scaled_store = norm_scaled;
        end
        default: norm_scaled_store = norm_scaled;
    endcase
end

always @(posedge clk) begin
    norm_scaled <= norm_scaled_store; 
end

always @(*) begin
    case(cur_state)
        S_NORM: norm_comb = {norm[1:2],mac_z[6],mac_z[7]};
        default: norm_comb = norm;
    endcase
end

genvar i;
generate
    for(i=0;i<4;i=i+1) begin
        always @(posedge clk) begin
            norm[i] <= norm_comb[i]; 
        end
    end
endgenerate

//==============================================//
//              ACTIVATED FUNCTION              //
//==============================================//

assign two_z = (norm[2] == 0) ? 0 : norm[2][inst_sig_width+inst_exp_width-1:inst_sig_width] + 1;

always @(*) begin
    case(opt)
        2'd1: exp_in = {norm[2][inst_sig_width+inst_exp_width],two_z,norm[2][inst_sig_width-1:0]};
        2'd2: exp_in = {~norm[2][inst_sig_width+inst_exp_width],norm[2][inst_sig_width+inst_exp_width-1:0]};   
        2'd3: exp_in = norm[2];
        default: exp_in = 0;
    endcase;
end

DW_fp_exp #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch) 
E1 (.a(exp_in), .z(exp_out));

DW_fp_ln #(inst_sig_width, inst_exp_width, inst_ieee_compliance, 0, inst_arch) 
L1 (.a(act[2]), .z(ln_out));

always @(*) begin
    case (opt)
        2'd1: act_comb = {mac_z[8],norm_scaled_comb,mac_z[5],exp_out};
        2'd2: act_comb = {act[1],norm_scaled_comb,mac_z[5],exp_out};
        2'd3: act_comb = {act[1],ln_out,mac_z[5],exp_out};
        default:  begin
            act_comb[0] = 0;
            act_comb[1] = 0;
            act_comb[2] = 0;
            act_comb[3] = 0;
        end
    endcase
end

genvar i;
generate
    for(i=0;i<4;i=i+1) begin
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n)
                act[i] <= 0;
            else
                act[i] <= act_comb[i]; 
        end
    end
endgenerate

//==============================================//
//                    OUTPUT                    //
//==============================================//

always @(*) begin
    case(opt)
        2'd0: begin
            if(cur_state == S_NORM && cnt >= 1 && cnt <= 4)
                out_valid_comb = 1;
            else
                out_valid_comb = 0;
        end
        2'd1: begin
            if(cur_state == S_NORM && cnt >= 5 && cnt <= 8)
                out_valid_comb = 1;
            else
                out_valid_comb = 0;
        end
        default begin
            if(cur_state == S_NORM && cnt >= 4 && cnt <= 7)
                out_valid_comb = 1;
            else
                out_valid_comb = 0;
        end
    endcase        
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        out_valid <= 0;
    else
        out_valid <= out_valid_comb;
end

always @(*) begin
    case(opt)
        2'd0: begin
            if(cur_state == S_NORM && cnt >= 1 && cnt <= 4)
                out_comb = mac_z[6];
            else
                out_comb = 0;
        end
        2'd1: begin
            if(cur_state == S_NORM && cnt >= 5 && cnt <= 8)
                out_comb = mac_z[8];
            else
                out_comb = 0;
        end
        2'd3: begin
            if(cur_state == S_NORM && cnt >= 4 && cnt <= 7)
                out_comb = ln_out;
            else
                out_comb = 0;
        end
        default begin
            if(cur_state == S_NORM && cnt >= 4 && cnt <= 7)
                out_comb = norm_scaled_comb;
            else
                out_comb = 0;
        end
    endcase         
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        out <= 0;
    else
        out <= out_comb;
end

//==============================================//
//                      IP                      //
//==============================================//

// Mac0 
DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
M0(.a(mac_a[0]), .b(mac_b[0]), .rnd(3'b000), .z(m_z[0]));

DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance) 
A0(.a(m_z[0]), .b(mac_c[0]), .rnd(3'b000), .z(mac_z[0]));

// Mac1 
DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
M1(.a(mac_a[1]), .b(mac_b[1]), .rnd(3'b000), .z(m_z[1]));

DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance) 
A1(.a(m_z[1]), .b(mac_c[1]), .rnd(3'b000), .z(mac_z[1]));

// Mac2
DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
M2(.a(mac_a[2]), .b(mac_b[2]), .rnd(3'b000), .z(m_z[2]));

DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance) 
A2(.a(m_z[2]), .b(mac_c[2]), .rnd(3'b000), .z(mac_z[2]));

// Mac3 
DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
M3(.a(mac_a[3]), .b(mac_b[3]), .rnd(3'b000), .z(m_z[3]));

DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance) 
A3(.a(m_z[3]), .b(mac_c[3]), .rnd(3'b000), .z(mac_z[3]));

// Mac4 
DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
M4(.a(mac_a[4]), .b(mac_b[4]), .rnd(3'b000), .z(m_z[4]));

DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance) 
A4(.a(m_z[4]), .b(mac_c[4]), .rnd(3'b000), .z(mac_z[4]));

// Mac5
DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
M5(.a(mac_a[5]), .b(mac_b[5]), .rnd(3'b000), .z(m_z[5]));

DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance) 
A5(.a(m_z[5]), .b(mac_c[5]), .rnd(3'b000), .z(mac_z[5]));

// Mac6
DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
M6(.a(mac_a[6]), .b(mac_b[6]), .rnd(3'b000), .z(m_z[6]));

DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance) 
A6(.a(m_z[6]), .b(mac_c[6]), .rnd(3'b000), .z(mac_z[6]));

// Mac7 
DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
M7(.a(mac_a[7]), .b(mac_b[7]), .rnd(3'b000), .z(m_z[7]));

DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance) 
A7(.a(m_z[7]), .b(mac_c[7]), .rnd(3'b000), .z(mac_z[7]));

// Mac8 
DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
M8(.a(mac_a[8]), .b(mac_b[8]), .rnd(3'b000), .z(m_z[8]));

DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance) 
A8(.a(m_z[8]), .b(mac_c[8]), .rnd(3'b000), .z(mac_z[8]));

// Mac9 
DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
M9(.a(mac_a[9]), .b(mac_b[9]), .rnd(3'b000), .z(m_z[9]));

DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance) 
A9(.a(m_z[9]), .b(mac_c[9]), .rnd(3'b000), .z(mac_z[9]));

// Mac10 
DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
M10(.a(mac_a[10]), .b(mac_b[10]), .rnd(3'b000), .z(m_z[10]));

DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance) 
A10(.a(m_z[10]), .b(mac_c[10]), .rnd(3'b000), .z(mac_z[10]));

// Mac11
DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
M11(.a(mac_a[11]), .b(mac_b[11]), .rnd(3'b000), .z(m_z[11]));

DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance) 
A11(.a(m_z[11]), .b(mac_c[11]), .rnd(3'b000), .z(mac_z[11]));

// Mac12 
DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
M12(.a(mac_a[12]), .b(mac_b[12]), .rnd(3'b000), .z(m_z[12]));

DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance) 
A12(.a(m_z[12]), .b(mac_c[12]), .rnd(3'b000), .z(mac_z[12]));

// Mac13 
DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
M13(.a(mac_a[13]), .b(mac_b[13]), .rnd(3'b000), .z(m_z[13]));

DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance) 
A13(.a(m_z[13]), .b(mac_c[13]), .rnd(3'b000), .z(mac_z[13]));

// Mac14 
DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
M14(.a(mac_a[14]), .b(mac_b[14]), .rnd(3'b000), .z(m_z[14]));

DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance) 
A14(.a(m_z[14]), .b(mac_c[14]), .rnd(3'b000), .z(mac_z[14]));

// Mac15 
DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
M15(.a(mac_a[15]), .b(mac_b[15]), .rnd(3'b000), .z(m_z[15]));

DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance) 
A15(.a(m_z[15]), .b(mac_c[15]), .rnd(3'b000), .z(mac_z[15]));

endmodule
