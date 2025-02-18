module CLK_1_MODULE (
    clk,
    rst_n,
    in_valid,
	in_matrix_A,
    in_matrix_B,
    out_idle,
    handshake_sready,
    handshake_din,

    flag_handshake_to_clk1,
    flag_clk1_to_handshake,

	fifo_empty,
    fifo_rdata,
    fifo_rinc,
    out_valid,
    out_matrix,

    flag_clk1_to_fifo,
    flag_fifo_to_clk1
);
input clk;
input rst_n;
input in_valid;
input [3:0] in_matrix_A;
input [3:0] in_matrix_B;
input out_idle;
output reg handshake_sready;
output reg [7:0] handshake_din;
// You can use the the custom flag ports for your design
input  flag_handshake_to_clk1;
output flag_clk1_to_handshake;

input fifo_empty;
input [7:0] fifo_rdata;
output fifo_rinc;
output reg out_valid;
output reg [7:0] out_matrix;
// You can use the the custom flag ports for your design
output flag_clk1_to_fifo;
input flag_fifo_to_clk1;

integer i;

// TRANSFER DATA TO ANOTHER DOMAIN
reg  [1:0] cur_state, nxt_state;

reg  [3:0] cnt, cnt_comb;
wire [3:0] cntPlusOne;

reg  [7:0] din[0:15], din_comb[0:15];
reg  handshake_sready_comb;
reg  [7:0] handshake_din_comb;

// OUTPUT
reg  out_valid_comb;
reg  [7:0] out_matrix_comb;

reg  empty_ff1, empty_ff2;

//==============================================//
//                  PARAMETER                   //
//==============================================//

parameter S_IDLE            = 0;
parameter S_INPUT           = 1;
parameter S_CLK1_TO_CLK2    = 2;

//==============================================//
//                     FSM                      //
//==============================================//

always @(*) begin
    case(cur_state)
        S_IDLE: begin
            if(in_valid)
                nxt_state = S_INPUT;
            else
                nxt_state = cur_state;
        end
        S_INPUT: begin
            if(&cnt)
                nxt_state = S_CLK1_TO_CLK2;
            else
                nxt_state = cur_state;
        end
        S_CLK1_TO_CLK2: begin
            if(&cnt & handshake_sready & flag_handshake_to_clk1)
                nxt_state = S_IDLE;
            else
                nxt_state = cur_state;
        end
        default: nxt_state = cur_state;
    endcase 
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        cur_state <= S_IDLE;
    else
        cur_state <= nxt_state;
end

//==============================================//
//       TRANSFER DATA TO ANOTHER DOMAIN        //
//==============================================//

// counter
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        cnt <= 0;
    else
        cnt <= cnt_comb;
end

always @(*) begin
    case(cur_state)
        S_IDLE: begin
            if(in_valid)
                cnt_comb = cntPlusOne;
            else
                cnt_comb = cnt;
        end
        S_INPUT: cnt_comb = cntPlusOne;
        S_CLK1_TO_CLK2:  begin
            if(handshake_sready & flag_handshake_to_clk1)
                cnt_comb = cntPlusOne;
            else
                cnt_comb = cnt;
        end
        default: cnt_comb = cnt;
    endcase
    
end

assign cntPlusOne = cnt + 1;

// din register
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for(i=0;i<16;i=i+1)
            din[i] <= 8'd0;
    end else
        din <= din_comb;
end

always @(*) begin
    case(cur_state)
        S_IDLE: begin
            if(in_valid)
                din_comb = {din[1:15],{in_matrix_B,in_matrix_A}};
            else
                din_comb = din;
        end
        S_INPUT: din_comb = {din[1:15],{in_matrix_B,in_matrix_A}};
        S_CLK1_TO_CLK2: begin
            if(handshake_sready & flag_handshake_to_clk1)
                din_comb = {din[1:15],8'd0};
            else
                din_comb = din;
        end
        default: din_comb = din;
    endcase
    
end

// handshake_sready
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        handshake_sready <= 0;
    else
        handshake_sready <= handshake_sready_comb;
end

always @(*) begin
    case(cur_state)
        S_CLK1_TO_CLK2: begin
            if(handshake_sready)
                handshake_sready_comb = ~flag_handshake_to_clk1;
            else
                handshake_sready_comb = out_idle; 
        end
        default: handshake_sready_comb = 0;
    endcase
end

// handshake_din
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        handshake_din <= 0;
    else
        handshake_din <= handshake_din_comb;
end

always @(*) begin
    case(cur_state)
        S_CLK1_TO_CLK2: begin
            if(handshake_sready & (~flag_handshake_to_clk1))
                handshake_din_comb = handshake_din;
            else if(handshake_sready & flag_handshake_to_clk1)
                handshake_din_comb = 0;
            else if(out_idle)
                handshake_din_comb = din[0];
            else
                handshake_din_comb = 0;
        end
        default: handshake_din_comb = 0;
    endcase
end

//==============================================//
//                    OUTPUT                    //
//==============================================//

assign fifo_rinc = ~fifo_empty;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        empty_ff1 <= 1;
    else
        empty_ff1 <= fifo_empty;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        empty_ff2 <= 1;
    else
        empty_ff2 <= empty_ff1;
end

assign out_valid_comb = ~empty_ff2;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        out_valid <= 0;
    else
        out_valid <= out_valid_comb;
end

assign out_matrix_comb = (~empty_ff2) ? fifo_rdata : 0;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        out_matrix <= 0;
    else
        out_matrix <= out_matrix_comb;
end

endmodule

//==============================================//
//                   MODULE2                    //
//==============================================//

module CLK_2_MODULE (
    clk,
    rst_n,
    in_valid,
    fifo_full,
    in_matrix,
    out_valid,
    out_matrix,
    busy,

    flag_handshake_to_clk2,
    flag_clk2_to_handshake,

    flag_fifo_to_clk2,
    flag_clk2_to_fifo
);

input clk;
input rst_n;
input in_valid;
input fifo_full;
input [7:0] in_matrix;
output reg out_valid;
output reg [7:0] out_matrix;
output reg busy;

// You can use the the custom flag ports for your design
input  flag_handshake_to_clk2;
output flag_clk2_to_handshake;

input  flag_fifo_to_clk2;
output flag_clk2_to_fifo;

// counter
reg  [7:0] cnt, cnt_comb;
wire [7:0] cntPlusOne;

// input ff
reg  [3:0] matA[0:15], matA_comb[0:15], matB[0:15], matB_comb[0:15];

// output
reg  out_valid_comb;
reg  [7:0] out_matrix_comb;
wire [7:0] ans;
reg  [3:0] mula, mula_comb, mulb, mulb_comb;

integer i;

//==============================================//
//                   COUNTER                    //
//==============================================//

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        cnt <= 0;
    else
        cnt <= cnt_comb;
end

always @(*) begin
    if(cnt <= 15) begin
        if(in_valid)
            cnt_comb = cntPlusOne;
        else
            cnt_comb = cnt;
    end else begin
        if(~flag_fifo_to_clk2)
            cnt_comb = cntPlusOne;
        else
            cnt_comb = cnt;
    end
end

assign cntPlusOne = cnt + 1;

//==============================================//
//                   INPUT FF                   //
//==============================================//

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for(i=0;i<16;i=i+1)
            matA[i] <= 4'd0;
    end else
        matA <= matA_comb;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for(i=0;i<16;i=i+1)
            matB[i] <= 4'd0;
    end else
        matB <= matB_comb;
end

always @(*) begin
    if(in_valid)
        matA_comb = {matA[1:14],in_matrix[3:0],matA[0]};
    else if(cnt[3:0] == 15 && (|cnt[7:4]) && ~flag_fifo_to_clk2)
        matA_comb = {matA[1:15],matA[0]};
    else
        matA_comb = matA;
end

always @(*) begin
    if(in_valid)
        matB_comb = {matB[1:15],in_matrix[7:4]};
    else if(cnt >= 16 && ~flag_fifo_to_clk2)
        matB_comb = {matB[1:15],matB[0]};
    else
        matB_comb = matB;
end

//==============================================//
//                    OUTPUT                    //
//==============================================//

always @(*) begin
    if(cnt > 15)
        mula_comb = matA[0];
    else if(cnt == 0 & in_valid)
        mula_comb = in_matrix[3:0];
    else
        mula_comb = mula;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        mula <= 0;
    else
        mula <= mula_comb;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        mulb <= 0;
    else
        mulb <= mulb_comb;
end

always @(*) begin
    if(cnt > 15)
        mulb_comb = matB[0];
    else if(in_valid)
        mulb_comb = in_matrix[7:4];
    else
        mulb_comb = mulb;
end

assign ans = mula_comb * mulb_comb;

always @(*) begin 
    if(cnt <= 15) begin
        if(in_valid & ~flag_fifo_to_clk2)
            out_valid_comb = 1;
        else
            out_valid_comb = 0;
    end else begin
        if(~flag_fifo_to_clk2)
            out_valid_comb = 1;
        else
            out_valid_comb = 0;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        out_valid <= 0;
    else
        out_valid <= out_valid_comb;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        busy <= 0;
    else
        busy <= 0;
end

always @(*) begin 
    if(cnt <= 15) begin
        if(in_valid & ~flag_fifo_to_clk2)
            out_matrix_comb = ans;
        else
            out_matrix_comb = 0;
    end else begin
        if(~flag_fifo_to_clk2)
            out_matrix_comb = ans;
        else
            out_matrix_comb = 0;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        out_matrix <= 0;
    else
        out_matrix <= out_matrix_comb;
end

endmodule