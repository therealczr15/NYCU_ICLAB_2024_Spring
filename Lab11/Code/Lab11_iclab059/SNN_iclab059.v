// synopsys translate_off
`ifdef RTL
	`include "GATED_OR.v"
`else
	`include "Netlist/GATED_OR_SYN.v"
`endif
// synopsys translate_on

module SNN(
	// Input signals
	clk,
	rst_n,
	cg_en,
	in_valid,
	img,
	ker,
	weight,

	// Output signals
	out_valid,
	out_data
);

input clk;
input rst_n;
input in_valid;
input cg_en;
input [7:0] img;
input [7:0] ker;
input [7:0] weight;

output reg out_valid;
output reg [9:0] out_data;

//==============================================//
//            REG & WIRE DECLARATION            //
//==============================================//

// COUNTER
reg  [6:0] cnt, cnt_comb;
wire [6:0] cntAddOne;

// IMAGE
reg  [7:0] image[0:35], image_comb[0:35];
wire sleep_image_ctrl[0:35], clk_gated_image[0:35];

// KERNEL
reg  [7:0] knl[0:8], knl_comb[0:8];
wire sleep_knl_ctrl[0:8], clk_gated_knl[0:8];

// WEIGHT
reg  [7:0] wgt[0:3], wgt_comb[0:3];
wire sleep_wgt_ctrl[0:3], clk_gated_wgt[0:3];

// CONVOLUTION
reg  [7:0]  mul_a[0:8];
reg  [7:0]  mul_b[0:8];
wire [15:0] mul_z[0:8];
wire [19:0] conv_comb;
reg  [19:0] conv;
wire sleep_conv_ctrl, clk_gated_conv;

// DIVIDER
reg  [19:0] div_a;
reg  [11:0] div_b;
wire [7:0]  div_z;

// QUANTIZATION 4x4
reg  [7:0] quan_4x4[0:15], quan_4x4_comb[0:15];
wire sleep_quan_4x4_ctrl[0:15], clk_gated_quan_4x4[0:15];

// MAX-POOLING
reg  [7:0] cmp_a[0:2], cmp_b[0:2], cmp_c;
reg  [7:0] max_pool[0:3], max_pool_comb[0:3];
wire sleep_max_pool_ctrl[0:3], clk_gated_max_pool[0:3];

// FULLY CONNECTED
reg  [16:0] fc[0:3], fc_comb[0:3];
wire sleep_fc_ctrl[0:3], clk_gated_fc[0:3];

// QUANTIZATION 4x1
reg  [7:0] quan_4x1_1[0:3], quan_4x1_1_comb[0:3], quan_4x1_2[0:3], quan_4x1_2_comb[0:3];
wire sleep_quan_4x1_1_ctrl[0:3], clk_gated_quan_4x1_1[0:3], sleep_quan_4x1_2_ctrl[0:3], clk_gated_quan_4x1_2[0:3];

// L1 DISTANCE
reg  [7:0] sub_a[0:3], sub_b[0:3];
wire [7:0] sub_z[0:3];
reg  [9:0] l1_dis;

// OUTPUT
reg  out_valid_comb;
reg  [9:0] out_data_comb;
wire sleep_out_ctrl, clk_gated_out;

//==============================================//
//                   COUNTER                    //
//==============================================//

assign cntAddOne = cnt + 1;

always @(*) begin
    if(cnt == 0 && (~in_valid))
    	cnt_comb = 0;
    else if(cnt == 78)
    	cnt_comb = 0;
    else 
        cnt_comb = cntAddOne;
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

genvar i;
generate
	for(i=0;i<36;i=i+1) begin
        always @(*) begin
    		if(cnt == i || cnt == i + 36)
    			image_comb[i] = img;
    		else
    			image_comb[i] = image[i];	
        end
    end
endgenerate

genvar i;
generate
    for(i=0;i<36;i=i+1) begin
        always @(posedge clk_gated_image[i]) begin
            image[i] <= image_comb[i];
        end
    end
endgenerate

// clock gated
genvar i;
generate
    for(i=0;i<36;i=i+1) begin
        assign sleep_image_ctrl[i] = cg_en && (cnt != i && cnt != i + 36);
    end
endgenerate

genvar i;
generate
    for(i=0;i<36;i=i+1) begin
        GATED_OR GATED_IMAGE (.CLOCK(clk), .SLEEP_CTRL(sleep_image_ctrl[i]), .RST_N(rst_n), .CLOCK_GATED(clk_gated_image[i]));
    end
endgenerate


//==============================================//
//                    KERNEL                    //
//==============================================//

genvar i;
generate
	for(i=0;i<9;i=i+1) begin
        always @(*) begin        	
    		if(cnt == i)
    			knl_comb[i] = ker;
    		else
    			knl_comb[i] = knl[i];
        end
    end
endgenerate

genvar i;
generate
    for(i=0;i<9;i=i+1) begin
        always @(posedge clk_gated_knl[i]) begin
            knl[i] <= knl_comb[i];
        end
    end
endgenerate

// clock gated
genvar i;
generate
    for(i=0;i<9;i=i+1) begin
        assign sleep_knl_ctrl[i] = cg_en && (cnt != i);
    end
endgenerate

genvar i;
generate
    for(i=0;i<9;i=i+1) begin
        GATED_OR GATED_KERNEL (.CLOCK(clk), .SLEEP_CTRL(sleep_knl_ctrl[i]), .RST_N(rst_n), .CLOCK_GATED(clk_gated_knl[i]));
    end
endgenerate

//==============================================//
//                    WEIGHT                    //
//==============================================//

genvar i;
generate
	for(i=0;i<4;i=i+1) begin
        always @(*) begin        	
    		if(cnt == i)
    			wgt_comb[i] = weight;
    		else
    			wgt_comb[i] = wgt[i];
        end
    end
endgenerate

genvar i;
generate
    for(i=0;i<4;i=i+1) begin
        always @(posedge clk_gated_wgt[i]) begin
            wgt[i] <= wgt_comb[i];
        end
    end
endgenerate

// clock gated
genvar i;
generate
    for(i=0;i<4;i=i+1) begin
        assign sleep_wgt_ctrl[i] = cg_en && (cnt != i);
    end
endgenerate

genvar i;
generate
    for(i=0;i<4;i=i+1) begin
        GATED_OR GATED_WEIGHT (.CLOCK(clk), .SLEEP_CTRL(sleep_wgt_ctrl[i]), .RST_N(rst_n), .CLOCK_GATED(clk_gated_wgt[i]));
    end
endgenerate

//==============================================//
//                 CONVOLUTION                  //
//==============================================//

always @(*) begin
	case(cnt)
		21, 57: mul_a[0] = image[0];
		22, 58: mul_a[0] = image[1];
		23, 59: mul_a[0] = image[2];
		24, 60: mul_a[0] = image[3];
		25, 61: mul_a[0] = image[6];
		26, 62: mul_a[0] = image[7];
		27, 63: mul_a[0] = image[8];
		28, 64: mul_a[0] = image[9];
		29, 65: mul_a[0] = image[12];
		30, 66: mul_a[0] = image[13];
		31, 67: mul_a[0] = image[14];
		32, 68: mul_a[0] = image[15];
		33, 69: mul_a[0] = image[18];
		34, 70: mul_a[0] = image[19];
		35, 71: mul_a[0] = image[20];
		36, 72: mul_a[0] = image[21];
		37, 73: mul_a[0] = max_pool[0];
		39, 75: mul_a[0] = max_pool[2];
		default: mul_a[0] = 0;
	endcase
end

always @(*) begin
	case(cnt)
		21, 57: mul_a[1] = image[1];
		22, 58: mul_a[1] = image[2];
		23, 59: mul_a[1] = image[3];
		24, 60: mul_a[1] = image[4];
		25, 61: mul_a[1] = image[7];
		26, 62: mul_a[1] = image[8];
		27, 63: mul_a[1] = image[9];
		28, 64: mul_a[1] = image[10];
		29, 65: mul_a[1] = image[13];
		30, 66: mul_a[1] = image[14];
		31, 67: mul_a[1] = image[15];
		32, 68: mul_a[1] = image[16];
		33, 69: mul_a[1] = image[19];
		34, 70: mul_a[1] = image[20];
		35, 71: mul_a[1] = image[21];
		36, 72: mul_a[1] = image[22];
		37, 73: mul_a[1] = max_pool[1];
		39, 75: mul_a[1] = max_pool[3];
		default: mul_a[1] = 0;
	endcase
end

always @(*) begin
	case(cnt)
		21, 57: mul_a[2] = image[2];
		22, 58: mul_a[2] = image[3];
		23, 59: mul_a[2] = image[4];
		24, 60: mul_a[2] = image[5];
		25, 61: mul_a[2] = image[8];
		26, 62: mul_a[2] = image[9];
		27, 63: mul_a[2] = image[10];
		28, 64: mul_a[2] = image[11];
		29, 65: mul_a[2] = image[14];
		30, 66: mul_a[2] = image[15];
		31, 67: mul_a[2] = image[16];
		32, 68: mul_a[2] = image[17];
		33, 69: mul_a[2] = image[20];
		34, 70: mul_a[2] = image[21];
		35, 71: mul_a[2] = image[22];
		36, 72: mul_a[2] = image[23];
		37, 73: mul_a[2] = max_pool[0];
		39, 75: mul_a[2] = max_pool[2];
		default: mul_a[2] = 0;
	endcase
end

always @(*) begin
	case(cnt)
		21, 57: mul_a[3] = image[6];
		22, 58: mul_a[3] = image[7];
		23, 59: mul_a[3] = image[8];
		24, 60: mul_a[3] = image[9];
		25, 61: mul_a[3] = image[12];
		26, 62: mul_a[3] = image[13];
		27, 63: mul_a[3] = image[14];
		28, 64: mul_a[3] = image[15];
		29, 65: mul_a[3] = image[18];
		30, 66: mul_a[3] = image[19];
		31, 67: mul_a[3] = image[20];
		32, 68: mul_a[3] = image[21];
		33, 69: mul_a[3] = image[24];
		34, 70: mul_a[3] = image[25];
		35, 71: mul_a[3] = image[26];
		36, 72: mul_a[3] = image[27];
		37, 73: mul_a[3] = max_pool[1];
		39, 75: mul_a[3] = max_pool[3];
		default: mul_a[3] = 0;
	endcase
end

always @(*) begin
	case(cnt)
		21, 57: mul_a[4] = image[7];
		22, 58: mul_a[4] = image[8];
		23, 59: mul_a[4] = image[9];
		24, 60: mul_a[4] = image[10];
		25, 61: mul_a[4] = image[13];
		26, 62: mul_a[4] = image[14];
		27, 63: mul_a[4] = image[15];
		28, 64: mul_a[4] = image[16];
		29, 65: mul_a[4] = image[19];
		30, 66: mul_a[4] = image[20];
		31, 67: mul_a[4] = image[21];
		32, 68: mul_a[4] = image[22];
		33, 69: mul_a[4] = image[25];
		34, 70: mul_a[4] = image[26];
		35, 71: mul_a[4] = image[27];
		36, 72: mul_a[4] = image[28];
		default: mul_a[4] = 0;
	endcase
end

always @(*) begin
	case(cnt)
		21, 57: mul_a[5] = image[8];
		22, 58: mul_a[5] = image[9];
		23, 59: mul_a[5] = image[10];
		24, 60: mul_a[5] = image[11];
		25, 61: mul_a[5] = image[14];
		26, 62: mul_a[5] = image[15];
		27, 63: mul_a[5] = image[16];
		28, 64: mul_a[5] = image[17];
		29, 65: mul_a[5] = image[20];
		30, 66: mul_a[5] = image[21];
		31, 67: mul_a[5] = image[22];
		32, 68: mul_a[5] = image[23];
		33, 69: mul_a[5] = image[26];
		34, 70: mul_a[5] = image[27];
		35, 71: mul_a[5] = image[28];
		36, 72: mul_a[5] = image[29];
		default: mul_a[5] = 0;
	endcase
end

always @(*) begin
	case(cnt)
		21, 57: mul_a[6] = image[12];
		22, 58: mul_a[6] = image[13];
		23, 59: mul_a[6] = image[14];
		24, 60: mul_a[6] = image[15];
		25, 61: mul_a[6] = image[18];
		26, 62: mul_a[6] = image[19];
		27, 63: mul_a[6] = image[20];
		28, 64: mul_a[6] = image[21];
		29, 65: mul_a[6] = image[24];
		30, 66: mul_a[6] = image[25];
		31, 67: mul_a[6] = image[26];
		32, 68: mul_a[6] = image[27];
		33, 69: mul_a[6] = image[30];
		34, 70: mul_a[6] = image[31];
		35, 71: mul_a[6] = image[32];
		36, 72: mul_a[6] = image[33];
		default: mul_a[6] = 0;
	endcase
end

always @(*) begin
	case(cnt)
		21, 57: mul_a[7] = image[13];
		22, 58: mul_a[7] = image[14];
		23, 59: mul_a[7] = image[15];
		24, 60: mul_a[7] = image[16];
		25, 61: mul_a[7] = image[19];
		26, 62: mul_a[7] = image[20];
		27, 63: mul_a[7] = image[21];
		28, 64: mul_a[7] = image[22];
		29, 65: mul_a[7] = image[25];
		30, 66: mul_a[7] = image[26];
		31, 67: mul_a[7] = image[27];
		32, 68: mul_a[7] = image[28];
		33, 69: mul_a[7] = image[31];
		34, 70: mul_a[7] = image[32];
		35, 71: mul_a[7] = image[33];
		36, 72: mul_a[7] = image[34];
		default: mul_a[7] = 0;
	endcase
end

always @(*) begin
	case(cnt)
		21, 57: mul_a[8] = image[14];
		22, 58: mul_a[8] = image[15];
		23, 59: mul_a[8] = image[16];
		24, 60: mul_a[8] = image[17];
		25, 61: mul_a[8] = image[20];
		26, 62: mul_a[8] = image[21];
		27, 63: mul_a[8] = image[22];
		28, 64: mul_a[8] = image[23];
		29, 65: mul_a[8] = image[26];
		30, 66: mul_a[8] = image[27];
		31, 67: mul_a[8] = image[28];
		32, 68: mul_a[8] = image[29];
		33, 69: mul_a[8] = image[32];
		34, 70: mul_a[8] = image[33];
		35, 71: mul_a[8] = image[34];
		36, 72: mul_a[8] = image[35];
		default: mul_a[8] = 0;
	endcase
end

always @(*) begin
	if(cnt == 37 || cnt == 39 || cnt == 73 || cnt == 75)
		mul_b[0] = wgt[0];
	else
		mul_b[0] = knl[0];
end

always @(*) begin
	if(cnt == 37 || cnt == 39 || cnt == 73 || cnt == 75)
		mul_b[1] = wgt[2];
	else
		mul_b[1] = knl[1];
end

always @(*) begin
	if(cnt == 37 || cnt == 39 || cnt == 73 || cnt == 75)
		mul_b[2] = wgt[1];
	else
		mul_b[2] = knl[2];
end

always @(*) begin
	if(cnt == 37 || cnt == 39 || cnt == 73 || cnt == 75)
		mul_b[3] = wgt[3];
	else
		mul_b[3] = knl[3];
end

genvar i;
generate
    for(i=4;i<9;i=i+1) begin
    	assign mul_b[i] = knl[i];
    end
endgenerate

genvar i;
generate
    for(i=0;i<9;i=i+1) begin
    	assign mul_z[i] = mul_a[i] * mul_b[i];
    end
endgenerate

assign conv_comb = (mul_z[0] + mul_z[1]) + (mul_z[2] + mul_z[3]) + (mul_z[4] + mul_z[5]) + (mul_z[6] + mul_z[7]) + mul_z[8];

always @(posedge clk_gated_conv) begin
    conv <= conv_comb;
end

// clock gated
assign sleep_conv_ctrl = cg_en && ((cnt > 0 && cnt < 21) || (cnt > 37 && cnt < 57) || (cnt > 73));
GATED_OR GATED_CONV (.CLOCK(clk), .SLEEP_CTRL(sleep_conv_ctrl), .RST_N(rst_n), .CLOCK_GATED(clk_gated_conv));

//==============================================//
//                   DIVIDER                    //
//==============================================//

always @(*) begin
	if(cnt == 38 || cnt == 74)
		div_a = fc[0];
	else if(cnt == 39 || cnt == 75)
		div_a = fc[1];
	else if(cnt == 40 || cnt == 76)
		div_a = fc[2];
	else if(cnt == 41 || cnt == 77)
		div_a = fc[3];
	else		
		div_a = conv;
end

always @(*) begin
	if( (cnt >= 22 && cnt <= 37) || (cnt >= 58 && cnt <= 73) ) 
		div_b = 2295;
	else
		div_b = 510;
end

assign div_z = div_a / div_b;

//==============================================//
//               QUANTIZATION 4x4               //
//==============================================//

genvar i;
generate
    for(i=0;i<16;i=i+1) begin
        always @(*) begin
			if(cnt == i + 22 || cnt == i + 58)
				quan_4x4_comb[i] = div_z;
			else
				quan_4x4_comb[i] = quan_4x4[i];
        end
    end
endgenerate

genvar i;
generate
    for(i=0;i<16;i=i+1) begin
        always @(posedge clk_gated_quan_4x4[i]) begin
            quan_4x4[i] <= quan_4x4_comb[i];
        end
    end
endgenerate

// clock gated
genvar i;
generate
    for(i=0;i<16;i=i+1) begin
        assign sleep_quan_4x4_ctrl[i] = cg_en && (cnt != i + 22 && cnt != i + 58);
    end
endgenerate

genvar i;
generate
    for(i=0;i<16;i=i+1) begin
        GATED_OR GATED_QUAN_4x4 (.CLOCK(clk), .SLEEP_CTRL(sleep_quan_4x4_ctrl[i]), .RST_N(rst_n), .CLOCK_GATED(clk_gated_quan_4x4[i]));
    end
endgenerate

//==============================================//
//                 MAX-POOLING                  //
//==============================================//

// comparator
always @(*) begin
	case(cnt)
		28, 64: cmp_a[0] = quan_4x4[0];
		30, 66: cmp_a[0] = quan_4x4[2];
		36, 72: cmp_a[0] = quan_4x4[8];
		38, 74: cmp_a[0] = quan_4x4[10];
		default: cmp_a[0] = 0;
	endcase
end

always @(*) begin
	case(cnt)
		28, 64: cmp_b[0] = quan_4x4[1];
		30, 66: cmp_b[0] = quan_4x4[3];
		36, 72: cmp_b[0] = quan_4x4[9];
		38, 74: cmp_b[0] = quan_4x4[11];
		default: cmp_b[0] = 0;
	endcase
end

always @(*) begin
	case(cnt)
		28, 64: cmp_a[1] = quan_4x4[4];
		30, 66: cmp_a[1] = quan_4x4[6];
		36, 72: cmp_a[1] = quan_4x4[12];
		38, 74: cmp_a[1] = quan_4x4[14];
		default: cmp_a[1] = 0;
	endcase
end

always @(*) begin
	case(cnt)
		28, 64: cmp_b[1] = quan_4x4[5];
		30, 66: cmp_b[1] = quan_4x4[7];
		36, 72: cmp_b[1] = quan_4x4[13];
		38, 74: cmp_b[1] = quan_4x4[15];
		default: cmp_b[1] = 0;
	endcase
end

always @(*) begin
	if(cmp_a[0] > cmp_b[0])
		cmp_a[2] = cmp_a[0];
	else
		cmp_a[2] = cmp_b[0];
end

always @(*) begin
	if(cmp_a[1] > cmp_b[1])
		cmp_b[2] = cmp_a[1];
	else
		cmp_b[2] = cmp_b[1];
end

always @(*) begin
	if(cmp_a[2] > cmp_b[2])
		cmp_c = cmp_a[2];
	else
		cmp_c = cmp_b[2];
end

// max_pool
always @(*) begin
    if(cnt == 28 || cnt == 64)
    	max_pool_comb[0] = cmp_c;
    else
    	max_pool_comb[0] = max_pool[0];
end

always @(*) begin
    if(cnt == 30 || cnt == 66)
    	max_pool_comb[1] = cmp_c;
    else
    	max_pool_comb[1] = max_pool[1];
end

always @(*) begin
    if(cnt == 36 || cnt == 72)
    	max_pool_comb[2] = cmp_c;
    else
    	max_pool_comb[2] = max_pool[2];
end

always @(*) begin
    if(cnt == 38 || cnt == 74)
    	max_pool_comb[3] = cmp_c;
    else
    	max_pool_comb[3] = max_pool[3];
end

genvar i;
generate
    for(i=0;i<4;i=i+1) begin
        always @(posedge clk_gated_max_pool[i]) begin
            max_pool[i] <= max_pool_comb[i];
        end
    end
endgenerate

// clock gated
assign sleep_max_pool_ctrl[0] = cg_en && (cnt != 28 && cnt != 64);
assign sleep_max_pool_ctrl[1] = cg_en && (cnt != 30 && cnt != 66);
assign sleep_max_pool_ctrl[2] = cg_en && (cnt != 36 && cnt != 72);
assign sleep_max_pool_ctrl[3] = cg_en && (cnt != 38 && cnt != 74);

genvar i;
generate
    for(i=0;i<4;i=i+1) begin
        GATED_OR GATED_MAXPOOL (.CLOCK(clk), .SLEEP_CTRL(sleep_max_pool_ctrl[i]), .RST_N(rst_n), .CLOCK_GATED(clk_gated_max_pool[i]));
    end
endgenerate

//==============================================//
//               FULLY CONNECTED                //
//==============================================//

always @(*) begin
    if(cnt == 37 || cnt == 73)
    	fc_comb[0] = mul_z[0] + mul_z[1];
    else
    	fc_comb[0] = fc[0];
end

always @(*) begin
    if(cnt == 37 || cnt == 73)
    	fc_comb[1] = mul_z[2] + mul_z[3];
    else
    	fc_comb[1] = fc[1];
end

always @(*) begin
    if(cnt == 39 || cnt == 75)
    	fc_comb[2] = mul_z[0] + mul_z[1];
    else
    	fc_comb[2] = fc[2];
end

always @(*) begin
    if(cnt == 39 || cnt == 75)
    	fc_comb[3] = mul_z[2] + mul_z[3];
    else
    	fc_comb[3] = fc[3];
end

genvar i;
generate
    for(i=0;i<4;i=i+1) begin
        always @(posedge clk_gated_fc[i]) begin
            fc[i] <= fc_comb[i];
        end
    end
endgenerate

// clock gated
assign sleep_fc_ctrl[0] = cg_en && (cnt != 37 && cnt != 73);
assign sleep_fc_ctrl[1] = cg_en && (cnt != 37 && cnt != 73);
assign sleep_fc_ctrl[2] = cg_en && (cnt != 39 && cnt != 75);
assign sleep_fc_ctrl[3] = cg_en && (cnt != 39 && cnt != 75);

genvar i;
generate
    for(i=0;i<4;i=i+1) begin
        GATED_OR GATED_FC (.CLOCK(clk), .SLEEP_CTRL(sleep_fc_ctrl[i]), .RST_N(rst_n), .CLOCK_GATED(clk_gated_fc[i]));
    end
endgenerate

//==============================================//
//               QUANTIZATION 4x1               //
//==============================================//

genvar i;
generate
    for(i=0;i<4;i=i+1) begin
        always @(*) begin
			if(cnt == i + 38)
				quan_4x1_1_comb[i] = div_z;
			else
				quan_4x1_1_comb[i] = quan_4x1_1[i];
        end
    end
endgenerate

genvar i;
generate
    for(i=0;i<4;i=i+1) begin
        always @(posedge clk_gated_quan_4x1_1[i]) begin
            quan_4x1_1[i] <= quan_4x1_1_comb[i];
        end
    end
endgenerate

// clock gated
genvar i;
generate
    for(i=0;i<4;i=i+1) begin
        assign sleep_quan_4x1_1_ctrl[i] = cg_en && (cnt != i + 38);
    end
endgenerate

genvar i;
generate
    for(i=0;i<4;i=i+1) begin
        GATED_OR GATED_QUAN_4x1_1 (.CLOCK(clk), .SLEEP_CTRL(sleep_quan_4x1_1_ctrl[i]), .RST_N(rst_n), .CLOCK_GATED(clk_gated_quan_4x1_1[i]));
    end
endgenerate


genvar i;
generate
    for(i=0;i<4;i=i+1) begin
        always @(*) begin
			if(cnt == i + 74)
				quan_4x1_2_comb[i] = div_z;
			else
				quan_4x1_2_comb[i] = quan_4x1_2[i];
        end
    end
endgenerate

genvar i;
generate
    for(i=0;i<4;i=i+1) begin
        always @(posedge clk_gated_quan_4x1_2[i]) begin
            quan_4x1_2[i] <= quan_4x1_2_comb[i];
        end
    end
endgenerate

// clock gated
genvar i;
generate
    for(i=0;i<4;i=i+1) begin
        assign sleep_quan_4x1_2_ctrl[i] = cg_en && (cnt != i + 74);
    end
endgenerate

genvar i;
generate
    for(i=0;i<4;i=i+1) begin
        GATED_OR GATED_QUAN_4x1_2 (.CLOCK(clk), .SLEEP_CTRL(sleep_quan_4x1_2_ctrl[i]), .RST_N(rst_n), .CLOCK_GATED(clk_gated_quan_4x1_2[i]));
    end
endgenerate

//==============================================//
//                 L1 DISTANCE                  //
//==============================================//

// substractor
genvar i;
generate
    for(i=0;i<4;i=i+1) begin
        assign sub_a[i] = (quan_4x1_1[i] > quan_4x1_2[i]) ? quan_4x1_1[i] : quan_4x1_2[i];
    end
endgenerate

genvar i;
generate
    for(i=0;i<4;i=i+1) begin
        assign sub_b[i] = (quan_4x1_1[i] > quan_4x1_2[i]) ? quan_4x1_2[i] : quan_4x1_1[i];
    end
endgenerate

genvar i;
generate
    for(i=0;i<4;i=i+1) begin
        assign sub_z[i] = sub_a[i] - sub_b[i];
    end
endgenerate

// L1 Distance
always @(*) begin 
	if(cnt == 78)
		l1_dis = (sub_z[0] + sub_z[1]) + (sub_z[2] + sub_z[3]);
	else
		l1_dis = 0;
end

//==============================================//
//                    OUTPUT                     //
//==============================================//

// out_valid
always @(*) begin 
	if(cnt == 78)
		out_valid_comb = 1;
	else
		out_valid_comb = 0;
end

always @(posedge clk_gated_out or negedge rst_n) begin
    if(!rst_n)
        out_valid <= 0;
    else
        out_valid <= out_valid_comb;
end

// out_data
always @(*) begin 
	if(cnt == 78)
		out_data_comb = (l1_dis >= 16) ? l1_dis : 0;
	else
		out_data_comb = 0;
end

always @(posedge clk_gated_out or negedge rst_n) begin
    if(!rst_n)
        out_data <= 0;
    else
        out_data <= out_data_comb;
end

// clock gated
assign sleep_out_ctrl = cg_en && (cnt != 78 && cnt != 0);
GATED_OR GATED_OUT (.CLOCK(clk), .SLEEP_CTRL(sleep_out_ctrl), .RST_N(rst_n), .CLOCK_GATED(clk_gated_out));

endmodule