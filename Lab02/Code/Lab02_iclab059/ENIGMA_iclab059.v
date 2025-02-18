//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2024 Spring
//   Lab02 Exercise		: Enigma
//   Author     		: Yi-Xuan, Ran
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : ENIGMA.v
//   Module Name : ENIGMA
//   Release version : V1.0 (Release Date: 2024-02)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################
// 136083.026161
module ENIGMA(
	// Input Ports
	clk, 
	rst_n, 
	in_valid, 
	in_valid_2, 
	crypt_mode, 
	code_in, 

	// Output Ports
	out_code, 
	out_valid
);

// ===============================================================
// Input & Output Declaration
// ===============================================================
input clk;              // clock input
input rst_n;            // asynchronous reset (active low)
input in_valid;         // code_in valid signal for rotor (level sensitive). 0/1: inactive/active
input in_valid_2;       // code_in valid signal for code  (level sensitive). 0/1: inactive/active
input crypt_mode;       // 0: encrypt; 1:decrypt; only valid for 1 cycle when in_valid is active

input [6-1:0] code_in;	// When in_valid   is active, then code_in is input of rotors. 
						// When in_valid_2 is active, then code_in is input of code words.
							
output reg out_valid;       	// 0: out_code is not valid; 1: out_code is valid
output reg [6-1:0] out_code;	// encrypted/decrypted code word

reg [6:0] cnt_comb, cnt; 
reg in_valid_reg, in_valid_2_reg;
reg decrypt_comb, decrypt;
reg [5:0] code_in_reg;
reg [5:0] rotorA[0:63], rotorA_comb[0:63], rotorB[0:63], rotorB_comb[0:63];
wire [5:0] a_eq_idx[0:63], b_eq_idx[0:63];
reg [5:0] outA, outB;
reg [5:0] outInvB, outInvA;
reg [5:0] outR;

wire [1:0] a;
wire [2:0] b;
// ===============================================================
// Design
// ===============================================================

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) 
		in_valid_reg <= 0;
	else
		in_valid_reg <= in_valid;
end

always @(posedge clk) begin
	in_valid_2_reg <= in_valid_2;
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) 
		code_in_reg <= 0;
	else
		code_in_reg <= code_in;
end

// cnt
// ===============================================================
always @(*) begin
	if(in_valid)
		cnt_comb = cnt + 1;
	else
		cnt_comb = 0;
end 

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) 
		cnt <= 0;
	else
		cnt <= cnt_comb;
end

// decrypt
// ===============================================================
always @(*) begin
	if(in_valid && !in_valid_reg)
		decrypt_comb = crypt_mode;
	else
		decrypt_comb = decrypt;
end

always @(posedge clk) begin	
	decrypt <= decrypt_comb;
end

assign a = (decrypt_comb) ? outInvB[1:0] : outA[1:0];
assign b = (decrypt_comb) ? outR[2:0] : outB[2:0];

// rotorA, rotorB
// ===============================================================
always @(*) begin
	if(in_valid && !cnt[6]) 
		rotorA_comb = {rotorA[1:63],code_in};
	else if(in_valid_2_reg) begin
		case (a)
			2'd0: rotorA_comb = rotorA;
			2'd1: rotorA_comb = {rotorA[63],rotorA[0:62]};	
			2'd2: rotorA_comb = {rotorA[62:63],rotorA[0:61]};	
			2'd3: rotorA_comb = {rotorA[61:63],rotorA[0:60]};
		endcase
	end else
		rotorA_comb = rotorA;
end

always @(*) begin
	if(in_valid && cnt[6]) 
		rotorB_comb = {rotorB[1:63],code_in};
	else if(in_valid_2_reg) begin
		case (b)
			3'd0: rotorB_comb= rotorB;
			3'd1: begin
				for(int i=0;i<64;i=i+8) begin
					rotorB_comb[i]   = rotorB[i+1];
					rotorB_comb[i+1] = rotorB[i];
					rotorB_comb[i+2] = rotorB[i+3];
					rotorB_comb[i+3] = rotorB[i+2];
					rotorB_comb[i+4] = rotorB[i+5];
					rotorB_comb[i+5] = rotorB[i+4];
					rotorB_comb[i+6] = rotorB[i+7];
					rotorB_comb[i+7] = rotorB[i+6];
				end
			end
			3'd2: begin
				for(int i=0;i<64;i=i+8) begin
					rotorB_comb[i]   = rotorB[i+2];
					rotorB_comb[i+1] = rotorB[i+3];
					rotorB_comb[i+2] = rotorB[i];
					rotorB_comb[i+3] = rotorB[i+1];
					rotorB_comb[i+4] = rotorB[i+6];
					rotorB_comb[i+5] = rotorB[i+7];
					rotorB_comb[i+6] = rotorB[i+4];
					rotorB_comb[i+7] = rotorB[i+5];
				end
			end
			3'd3: begin
				for(int i=0;i<64;i=i+8) begin
					rotorB_comb[i]   = rotorB[i];
					rotorB_comb[i+1] = rotorB[i+4];
					rotorB_comb[i+2] = rotorB[i+5];
					rotorB_comb[i+3] = rotorB[i+6];
					rotorB_comb[i+4] = rotorB[i+1];
					rotorB_comb[i+5] = rotorB[i+2];
					rotorB_comb[i+6] = rotorB[i+3];
					rotorB_comb[i+7] = rotorB[i+7];
				end
			end
			3'd4: begin
				for(int i=0;i<64;i=i+8) begin
					rotorB_comb[i]   = rotorB[i+4];
					rotorB_comb[i+1] = rotorB[i+5];
					rotorB_comb[i+2] = rotorB[i+6];
					rotorB_comb[i+3] = rotorB[i+7];
					rotorB_comb[i+4] = rotorB[i];
					rotorB_comb[i+5] = rotorB[i+1];
					rotorB_comb[i+6] = rotorB[i+2];
					rotorB_comb[i+7] = rotorB[i+3];
				end
			end
			3'd5: begin
				for(int i=0;i<64;i=i+8) begin
					rotorB_comb[i]   = rotorB[i+5];
					rotorB_comb[i+1] = rotorB[i+6];
					rotorB_comb[i+2] = rotorB[i+7];
					rotorB_comb[i+3] = rotorB[i+3];
					rotorB_comb[i+4] = rotorB[i+4];
					rotorB_comb[i+5] = rotorB[i+0];
					rotorB_comb[i+6] = rotorB[i+1];
					rotorB_comb[i+7] = rotorB[i+2];
				end
			end
			3'd6: begin
				for(int i=0;i<64;i=i+8) begin
					rotorB_comb[i]   = rotorB[i+6];
					rotorB_comb[i+1] = rotorB[i+7];
					rotorB_comb[i+2] = rotorB[i+3];
					rotorB_comb[i+3] = rotorB[i+2];
					rotorB_comb[i+4] = rotorB[i+5];
					rotorB_comb[i+5] = rotorB[i+4];
					rotorB_comb[i+6] = rotorB[i];
					rotorB_comb[i+7] = rotorB[i+1];
				end
			end
			3'd7: begin
				for(int i=0;i<64;i=i+8) begin
					rotorB_comb[i]   = rotorB[i+7];
					rotorB_comb[i+1] = rotorB[i+6];
					rotorB_comb[i+2] = rotorB[i+5];
					rotorB_comb[i+3] = rotorB[i+4];
					rotorB_comb[i+4] = rotorB[i+3];
					rotorB_comb[i+5] = rotorB[i+2];
					rotorB_comb[i+6] = rotorB[i+1];
					rotorB_comb[i+7] = rotorB[i];
				end
			end
		endcase
	end else
		rotorB_comb = rotorB;
end

genvar i;
generate
for(i=0;i<=63;i=i+1) begin
	always @(posedge clk) begin
		rotorA[i] <= rotorA_comb[i];
		rotorB[i] <= rotorB_comb[i];
	end
end
endgenerate

// a_eq_idx, b_eq_idx
// ===============================================================
genvar idx;
generate
for(idx=0;idx<=63;idx=idx+1) begin
	assign a_eq_idx[idx] = (rotorA[idx] == outInvB) ? idx : 0;
	assign b_eq_idx[idx] = (rotorB[idx] == outR) ? idx : 0;
end
endgenerate

// outA, outB, outR, outInvA, outInvB
// ===============================================================
assign outA = rotorA[code_in_reg];
assign outB = rotorB[outA];
assign outR = ~outB;
assign outInvB = b_eq_idx[1]  | b_eq_idx[2]  | b_eq_idx[3]  | b_eq_idx[4]  | b_eq_idx[5]  | b_eq_idx[6]  | b_eq_idx[7]  | 
				 b_eq_idx[8]  | b_eq_idx[9]  | b_eq_idx[10] | b_eq_idx[11] | b_eq_idx[12] | b_eq_idx[13] | b_eq_idx[14] | b_eq_idx[15] | 
				 b_eq_idx[16] | b_eq_idx[17] | b_eq_idx[18] | b_eq_idx[19] | b_eq_idx[20] | b_eq_idx[21] | b_eq_idx[22] | b_eq_idx[23] | 
				 b_eq_idx[24] | b_eq_idx[25] | b_eq_idx[26] | b_eq_idx[27] | b_eq_idx[28] | b_eq_idx[29] | b_eq_idx[30] | b_eq_idx[31] | 
				 b_eq_idx[32] | b_eq_idx[33] | b_eq_idx[34] | b_eq_idx[35] | b_eq_idx[36] | b_eq_idx[37] | b_eq_idx[38] | b_eq_idx[39] |
				 b_eq_idx[40] | b_eq_idx[41] | b_eq_idx[42] | b_eq_idx[43] | b_eq_idx[44] | b_eq_idx[45] | b_eq_idx[46] | b_eq_idx[47] | 
				 b_eq_idx[48] | b_eq_idx[49] | b_eq_idx[50] | b_eq_idx[51] | b_eq_idx[52] | b_eq_idx[53] | b_eq_idx[54] | b_eq_idx[55] | 
				 b_eq_idx[56] | b_eq_idx[57] | b_eq_idx[58] | b_eq_idx[59] | b_eq_idx[60] | b_eq_idx[61] | b_eq_idx[62] | b_eq_idx[63];

assign outInvA = (in_valid_2_reg) ? 
				(a_eq_idx[1]  | a_eq_idx[2]  | a_eq_idx[3]  | a_eq_idx[4]  | a_eq_idx[5]  | a_eq_idx[6]  | a_eq_idx[7]  | 
				 a_eq_idx[8]  | a_eq_idx[9]  | a_eq_idx[10] | a_eq_idx[11] | a_eq_idx[12] | a_eq_idx[13] | a_eq_idx[14] | a_eq_idx[15] | 
				 a_eq_idx[16] | a_eq_idx[17] | a_eq_idx[18] | a_eq_idx[19] | a_eq_idx[20] | a_eq_idx[21] | a_eq_idx[22] | a_eq_idx[23] | 
				 a_eq_idx[24] | a_eq_idx[25] | a_eq_idx[26] | a_eq_idx[27] | a_eq_idx[28] | a_eq_idx[29] | a_eq_idx[30] | a_eq_idx[31] | 
				 a_eq_idx[32] | a_eq_idx[33] | a_eq_idx[34] | a_eq_idx[35] | a_eq_idx[36] | a_eq_idx[37] | a_eq_idx[38] | a_eq_idx[39] |
				 a_eq_idx[40] | a_eq_idx[41] | a_eq_idx[42] | a_eq_idx[43] | a_eq_idx[44] | a_eq_idx[45] | a_eq_idx[46] | a_eq_idx[47] | 
				 a_eq_idx[48] | a_eq_idx[49] | a_eq_idx[50] | a_eq_idx[51] | a_eq_idx[52] | a_eq_idx[53] | a_eq_idx[54] | a_eq_idx[55] | 
				 a_eq_idx[56] | a_eq_idx[57] | a_eq_idx[58] | a_eq_idx[59] | a_eq_idx[60] | a_eq_idx[61] | a_eq_idx[62] | a_eq_idx[63] ) : 0;

// out_valid
// ===============================================================
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) 
		out_valid <= 0;
	else
		out_valid <= in_valid_2_reg;
end

// out_code
// ===============================================================
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) 
		out_code <= 0;
	else 
		out_code <= outInvA;
end

endmodule