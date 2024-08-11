//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//    (C) Copyright System Integration and Silicon Implementation Laboratory
//    All Right Reserved
//      Date        : 2023/10
//      Version     : v1.0
//      File Name   : HT_TOP.v
//      Module Name : HT_TOP
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

//synopsys translate_off
`include "SORT_IP.v"
//synopsys translate_on

module HT_TOP(
    // Input signals
    clk,
    rst_n,
    in_valid,
    in_weight, 
    out_mode,
    // Output signals
    out_valid, 
    out_code
);

input clk, rst_n, in_valid, out_mode;
input [2:0] in_weight;

output reg out_valid, out_code;

//==============================================//
//                  REG & WIRE                  //
//==============================================//

// FSM
reg [3:0] cur_state, nxt_state;

// COUNTER
reg  [7:0] cnt, cnt_comb;
reg  [2:0] outcnt, outcnt_comb;
wire [2:0] cntPlusOne;

// MODE FF
reg mode_ff;
wire mode_comb;

// HUFFMAN TREE
reg  [7:0] char [0:7], char_comb[0:7];
reg  [2:0] wgt  [0:7], wgt_comb [0:7];

// ENCODE
wire [7:0] char8;
wire [3:0] wgt8;
reg  [7:0] char8_comb[0:6], char8_reg[0:6];;
reg  [3:0] wgt8_comb [0:6], wgt8_reg[0:6];;
reg  [6:0] code8_comb[0:7], code8_reg[0:7];;
wire [2:0] length8_comb[0:7];
reg  [2:0] length8_reg[0:7];

wire [7:0] char7;
wire [3:0] wgt7;
reg  [7:0] char7_comb[0:5];
reg  [3:0] wgt7_comb [0:5];
reg  [6:0] code7_comb[0:7];
wire [2:0] length7_comb[0:7];

wire [7:0] char6;
wire [3:0] wgt6;
reg  [7:0] char6_comb[0:4];
reg  [3:0] wgt6_comb [0:4];
reg  [6:0] code6_comb[0:7];
wire [2:0] length6_comb[0:7];

wire [7:0] char5;
wire [3:0] wgt5;
reg  [7:0] char5_comb[0:3];
reg  [3:0] wgt5_comb [0:3];
reg  [6:0] code5_comb[0:7];
wire [2:0] length5_comb[0:7];

wire [7:0] char4;
wire [4:0] wgt4;
reg  [7:0] char4_comb[0:2];
reg  [4:0] wgt4_comb [0:2];
reg  [6:0] code4_comb[0:7];
wire [2:0] length4_comb[0:7];

wire [7:0] char3;
wire [4:0] wgt3;
reg  [7:0] char3_comb[0:1];
reg  [4:0] wgt3_comb [0:1];
reg  [6:0] code3_comb[0:7];
wire [2:0] length3_comb[0:7];

reg  [6:0] code2_comb[0:7], code[0:7];
wire [2:0] length2_comb[0:7]; 
reg  [2:0] length[0:7];

// OUTPUT
reg out_valid_comb;
reg out_code_comb;

// IP
wire [39:0] in_w;
wire [31:0] in_c;
wire [31:0] out_c;

//==============================================//
//                  PARAMETER                   //
//==============================================//

parameter   S_IDLE      =   4'd0;
parameter   S_INPUT     =   4'd1;
parameter   S_I         =   4'd2;
parameter   S_L         =   4'd3;
parameter   S_O         =   4'd4;
parameter   S_V         =   4'd5;
parameter   S_E         =   4'd6;
parameter   S_C         =   4'd7;
parameter   S_A         =   4'd8;
parameter   S_B         =   4'd9;

SORT_IP #(.IP_WIDTH(8)) I_SORT_IP(.IN_character(in_c), .IN_weight(in_w), .OUT_character(out_c)); 

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
            if(cnt == 0)
                nxt_state = S_I;
            else
                nxt_state = cur_state;
        end
        S_I: begin
            if(outcnt == length[4])
                nxt_state = (mode_ff) ? S_C : S_L;
            else
                nxt_state = cur_state;
        end
        S_L: begin
            if(outcnt == length[5])
                nxt_state = (mode_ff) ? S_A : S_O;
            else
                nxt_state = cur_state;
        end
        S_O: begin
            if(outcnt == length[6])
                nxt_state = S_V;
            else
                nxt_state = cur_state;
        end
        S_V: begin
            if(outcnt == length[7])
                nxt_state = S_E;
            else
                nxt_state = cur_state;
        end
        S_E: begin
            if(outcnt == length[3])
                nxt_state = S_IDLE;
            else
                nxt_state = cur_state;
        end
        S_C: begin
            if(outcnt == length[2])
                nxt_state = S_L;
            else
                nxt_state = cur_state;
        end
        S_A: begin
            if(outcnt == length[0])
                nxt_state = S_B;
            else
                nxt_state = cur_state;
        end
        S_B: begin
            if(outcnt == length[1])
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
//                   COUNTER                    //
//==============================================//

always @(*) begin
    case(cur_state)
        S_IDLE: begin
            if(in_valid)
                cnt_comb = cnt >> 1;
            else
                cnt_comb = 128;
        end
        S_INPUT: cnt_comb = cnt >> 1;
        default: cnt_comb = 0;
    endcase
end

always @(posedge clk) begin
    cnt <= cnt_comb;
end

assign cntPlusOne = outcnt + 1;

always @(*) begin
    case(cur_state)
        S_IDLE: outcnt_comb = 0;
        S_INPUT: begin
            if(cnt == 0)
                outcnt_comb = 1;
            else
                outcnt_comb = 0;
        end
        S_I: begin
            if(outcnt == length[4])
                outcnt_comb = 1;
            else
                outcnt_comb = cntPlusOne;
        end
        S_L: begin
            if(outcnt == length[5])
                outcnt_comb = 1;
            else
                outcnt_comb = cntPlusOne;
        end
        S_O: begin
            if(outcnt == length[6])
                outcnt_comb = 1;
            else
                outcnt_comb = cntPlusOne;
        end
        S_V: begin
            if(outcnt == length[7])
                outcnt_comb = 1;
            else
                outcnt_comb = cntPlusOne;
        end
        S_E: begin
            if(outcnt == length[3])
                outcnt_comb = 0;
            else
                outcnt_comb = cntPlusOne;
        end
        S_C: begin
            if(outcnt == length[2])
                outcnt_comb = 1;
            else
                outcnt_comb = cntPlusOne;
        end
        S_A: begin
            if(outcnt == length[0])
                outcnt_comb = 1;
            else
                outcnt_comb = cntPlusOne;
        end
        S_B: begin
            if(outcnt == length[1])
                outcnt_comb = 0;
            else
                outcnt_comb = cntPlusOne;
        end
        default: outcnt_comb = outcnt;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        outcnt <= 0;
    else
        outcnt <= outcnt_comb;
end

//==============================================//
//                   MODE_FF                    //
//==============================================//

assign mode_comb = (in_valid && cur_state == S_IDLE) ? out_mode : mode_ff;

always @(posedge clk) begin
    mode_ff <= mode_comb;
end

//==============================================//
//                INSERTION SORT                //
//==============================================//

always @(*) begin
    if(in_valid) begin
        if(in_weight > wgt[3] || !(|char[3])) begin
            if(in_weight > wgt[1] || !(|char[1])) begin
                if(in_weight > wgt[0] || !(|char[0])) begin
                    char_comb = {cnt,char[0:6]};
                end else begin
                    char_comb = {char[0],cnt,char[1:6]};
                end
            end else begin
                if(in_weight > wgt[2] || !(|char[2])) begin
                    char_comb = {char[0:1],cnt,char[2:6]};
                end else begin
                    char_comb = {char[0:2],cnt,char[3:6]};
                end
            end
        end else begin
            if(in_weight > wgt[5] || !(|char[5])) begin
                if(in_weight > wgt[4] || !(|char[4])) begin
                    char_comb = {char[0:3],cnt,char[4:6]};
                end else begin
                    char_comb = {char[0:4],cnt,char[5:6]};
                end
            end else begin
                if(in_weight > wgt[6] || !(|char[6])) begin
                    char_comb = {char[0:5],cnt,char[6]};
                end else begin
                    char_comb = {char[0:6],cnt};
                end
            end
        end
    end else 
        char_comb = {8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0};
end

always @(*) begin
    if(in_valid) begin
        if(in_weight > wgt[3] || !(|char[3])) begin
            if(in_weight > wgt[1] || !(|char[1])) begin
                if(in_weight > wgt[0] || !(|char[0])) begin
                    wgt_comb = {in_weight,wgt[0:6]};
                end else begin
                    wgt_comb = {wgt[0],in_weight,wgt[1:6]};
                end
            end else begin
                if(in_weight > wgt[2] || !(|char[2])) begin
                    wgt_comb = {wgt[0:1],in_weight,wgt[2:6]};
                end else begin
                    wgt_comb = {wgt[0:2],in_weight,wgt[3:6]};
                end
            end
        end else begin
            if(in_weight > wgt[5] || !(|char[5])) begin
                if(in_weight > wgt[4] || !(|char[4])) begin
                    wgt_comb = {wgt[0:3],in_weight,wgt[4:6]};
                end else begin
                    wgt_comb = {wgt[0:4],in_weight,wgt[5:6]};
                end
            end else begin
                if(in_weight > wgt[6] || !(|char[6])) begin
                    wgt_comb = {wgt[0:5],in_weight,wgt[6]};
                end else begin
                    wgt_comb = {wgt[0:6],in_weight};
                end
            end
        end
    end else
        wgt_comb = {3'd0,3'd0,3'd0,3'd0,3'd0,3'd0,3'd0,3'd0};
end

always @(posedge clk) begin
    char <= char_comb;
end

always @(posedge clk) begin
    wgt <= wgt_comb;
end

//==============================================//
//                   ENCODE8                    //
//==============================================//

assign char8 = char_comb[6] | char_comb[7];
assign wgt8  = wgt_comb[6] + wgt_comb[7];

always @(*) begin
    if(wgt8 > wgt_comb[3]) begin
        if(wgt8 > wgt_comb[1]) begin
            if(wgt8 > wgt_comb[0]) begin
                wgt8_comb = {{wgt8},{1'd0,wgt_comb[0]},{1'd0,wgt_comb[1]},{1'd0,wgt_comb[2]},{1'd0,wgt_comb[3]},{1'd0,wgt_comb[4]},{1'd0,wgt_comb[5]}};
            end else begin
                wgt8_comb = {{1'd0,wgt_comb[0]},{wgt8},{1'd0,wgt_comb[1]},{1'd0,wgt_comb[2]},{1'd0,wgt_comb[3]},{1'd0,wgt_comb[4]},{1'd0,wgt_comb[5]}};
            end
        end else begin
            if(wgt8 > wgt_comb[2]) begin
                wgt8_comb = {{1'd0,wgt_comb[0]},{1'd0,wgt_comb[1]},{wgt8},{1'd0,wgt_comb[2]},{1'd0,wgt_comb[3]},{1'd0,wgt_comb[4]},{1'd0,wgt_comb[5]}};
            end else begin
                wgt8_comb = {{1'd0,wgt_comb[0]},{1'd0,wgt_comb[1]},{1'd0,wgt_comb[2]},{wgt8},{1'd0,wgt_comb[3]},{1'd0,wgt_comb[4]},{1'd0,wgt_comb[5]}};
            end
        end
    end else begin
        if(wgt8 > wgt_comb[5]) begin
            if(wgt8 > wgt_comb[4]) begin
                wgt8_comb = {{1'd0,wgt_comb[0]},{1'd0,wgt_comb[1]},{1'd0,wgt_comb[2]},{1'd0,wgt_comb[3]},{wgt8},{1'd0,wgt_comb[4]},{1'd0,wgt_comb[5]}};
            end else begin
                wgt8_comb = {{1'd0,wgt_comb[0]},{1'd0,wgt_comb[1]},{1'd0,wgt_comb[2]},{1'd0,wgt_comb[3]},{1'd0,wgt_comb[4]},{wgt8},{1'd0,wgt_comb[5]}};
            end
        end else begin
            wgt8_comb = {{1'd0,wgt_comb[0]},{1'd0,wgt_comb[1]},{1'd0,wgt_comb[2]},{1'd0,wgt_comb[3]},{1'd0,wgt_comb[4]},{1'd0,wgt_comb[5]},{wgt8}};
        end
    end
end

always @(*) begin
    if(wgt8 > wgt_comb[3]) begin
        if(wgt8 > wgt_comb[1]) begin
            if(wgt8 > wgt_comb[0]) begin
                char8_comb = {char8,char_comb[0:5]};
            end else begin
                char8_comb = {char_comb[0],char8,char_comb[1:5]};
            end
        end else begin
            if(wgt8 > wgt_comb[2]) begin
                char8_comb = {char_comb[0:1],char8,char_comb[2:5]};
            end else begin
                char8_comb = {char_comb[0:2],char8,char_comb[3:5]};
            end
        end
    end else begin
        if(wgt8 > wgt_comb[5]) begin
            if(wgt8 > wgt_comb[4]) begin
                char8_comb = {char_comb[0:3],char8,char_comb[4:5]};
            end else begin
                char8_comb = {char_comb[0:4],char8,char_comb[5]};
            end
        end else begin
            char8_comb = {char_comb[0:5],char8};
        end
    end
end

assign length8_comb[0] = (char_comb[6][7] || char_comb[7][7]);
assign length8_comb[1] = (char_comb[6][6] || char_comb[7][6]);
assign length8_comb[2] = (char_comb[6][5] || char_comb[7][5]);
assign length8_comb[3] = (char_comb[6][4] || char_comb[7][4]);
assign length8_comb[4] = (char_comb[6][3] || char_comb[7][3]);
assign length8_comb[5] = (char_comb[6][2] || char_comb[7][2]);
assign length8_comb[6] = (char_comb[6][1] || char_comb[7][1]);
assign length8_comb[7] = (char_comb[6][0] || char_comb[7][0]);

always @(*) begin
    if(char_comb[7][7])
        code8_comb[0] = {1'd1,6'd0};
    else
        code8_comb[0] = 7'd0;
end

always @(*) begin
    if(char_comb[7][6])
        code8_comb[1] = {1'd1,6'd0};
    else
        code8_comb[1] = 7'd0;
end

always @(*) begin
    if(char_comb[7][5])
        code8_comb[2] = {1'd1,6'd0};
    else
        code8_comb[2] = 7'd0;
end

always @(*) begin
    if(char_comb[7][4])
        code8_comb[3] = {1'd1,6'd0};
    else
        code8_comb[3] = 7'd0;
end

always @(*) begin
    if(char_comb[7][3])
        code8_comb[4] = {1'd1,6'd0};
    else
        code8_comb[4] = 7'd0;
end

always @(*) begin
    if(char_comb[7][2])
        code8_comb[5] = {1'd1,6'd0};
    else
        code8_comb[5] = 7'd0;
end

always @(*) begin
    if(char_comb[7][1])
        code8_comb[6] = {1'd1,6'd0};
    else
        code8_comb[6] = 7'd0;
end

always @(*) begin
    if(char_comb[7][0])
        code8_comb[7] = {1'd1,6'd0};
    else
        code8_comb[7] = 7'd0;
end

always @(posedge clk) begin
    char8_reg <= char8_comb;
end

always @(posedge clk) begin
    wgt8_reg <= wgt8_comb;
end

always @(posedge clk) begin
    code8_reg <= code8_comb;
end

always @(posedge clk) begin
    length8_reg <= length8_comb;
end

//==============================================//
//                   ENCODE7                    //
//==============================================//

assign char7 = char8_reg[5] | char8_reg[6];
assign wgt7  = wgt8_reg[5] + wgt8_reg[6];

always @(*) begin
    if(wgt7 > wgt8_reg[3]) begin
        if(wgt7 > wgt8_reg[1]) begin
            if(wgt7 > wgt8_reg[0]) begin
                wgt7_comb = {wgt7,wgt8_reg[0:4]};
            end else begin
                wgt7_comb = {wgt8_reg[0],wgt7,wgt8_reg[1:4]};
            end
        end else begin
            if(wgt7 > wgt8_reg[2]) begin
                wgt7_comb = {wgt8_reg[0:1],wgt7,wgt8_reg[2:4]};
            end else begin
                wgt7_comb = {wgt8_reg[0:2],wgt7,wgt8_reg[3:4]};
            end
        end
    end else begin
        if(wgt7 > wgt8_reg[4]) begin
            wgt7_comb = {wgt8_reg[0:3],wgt7,wgt8_reg[4]};
        end else begin
             wgt7_comb = {wgt8_reg[0:4],wgt7};
        end
    end
end

always @(*) begin
    if(wgt7 > wgt8_reg[3]) begin
        if(wgt7 > wgt8_reg[1]) begin
            if(wgt7 > wgt8_reg[0]) begin
                char7_comb = {char7,char8_reg[0:4]};
            end else begin
                char7_comb = {char8_reg[0],char7,char8_reg[1:4]};
            end
        end else begin
            if(wgt7 > wgt8_reg[2]) begin
                char7_comb = {char8_reg[0:1],char7,char8_reg[2:4]};
            end else begin
                char7_comb = {char8_reg[0:2],char7,char8_reg[3:4]};
            end
        end
    end else begin
        if(wgt7 > wgt8_reg[4]) begin
            char7_comb = {char8_reg[0:3],char7,char8_reg[4]};
        end else begin
            char7_comb = {char8_reg[0:4],char7};
        end
    end
end

assign length7_comb[0] = (char8_reg[5][7] || char8_reg[6][7]) ? length8_reg[0] + 1 : length8_reg[0];
assign length7_comb[1] = (char8_reg[5][6] || char8_reg[6][6]) ? length8_reg[1] + 1 : length8_reg[1];
assign length7_comb[2] = (char8_reg[5][5] || char8_reg[6][5]) ? length8_reg[2] + 1 : length8_reg[2];
assign length7_comb[3] = (char8_reg[5][4] || char8_reg[6][4]) ? length8_reg[3] + 1 : length8_reg[3];
assign length7_comb[4] = (char8_reg[5][3] || char8_reg[6][3]) ? length8_reg[4] + 1 : length8_reg[4];
assign length7_comb[5] = (char8_reg[5][2] || char8_reg[6][2]) ? length8_reg[5] + 1 : length8_reg[5];
assign length7_comb[6] = (char8_reg[5][1] || char8_reg[6][1]) ? length8_reg[6] + 1 : length8_reg[6];
assign length7_comb[7] = (char8_reg[5][0] || char8_reg[6][0]) ? length8_reg[7] + 1 : length8_reg[7];

always @(*) begin
    if(char8_reg[6][7])
        code7_comb[0] = {1'd1,code8_reg[0][6:1]};
    else if(char8_reg[5][7])
        code7_comb[0] = {1'd0,code8_reg[0][6:1]};
    else
        code7_comb[0] = code8_reg[0];
end

always @(*) begin
    if(char8_reg[6][6])
        code7_comb[1] = {1'd1,code8_reg[1][6:1]};
    else if(char8_reg[5][6])
        code7_comb[1] = {1'd0,code8_reg[1][6:1]};
    else
        code7_comb[1] = code8_reg[1];
end

always @(*) begin
    if(char8_reg[6][5])
        code7_comb[2] = {1'd1,code8_reg[2][6:1]};
    else if(char8_reg[5][5])
        code7_comb[2] = {1'd0,code8_reg[2][6:1]};
    else
        code7_comb[2] = code8_reg[2];
end

always @(*) begin
    if(char8_reg[6][4])
        code7_comb[3] = {1'd1,code8_reg[3][6:1]};
    else if(char8_reg[5][4])
        code7_comb[3] = {1'd0,code8_reg[3][6:1]};
    else
        code7_comb[3] = code8_reg[3];
end

always @(*) begin
    if(char8_reg[6][3])
        code7_comb[4] = {1'd1,code8_reg[4][6:1]};
    else if(char8_reg[5][3])
        code7_comb[4] = {1'd0,code8_reg[4][6:1]};
    else
        code7_comb[4] = code8_reg[4];
end

always @(*) begin
    if(char8_reg[6][2])
        code7_comb[5] = {1'd1,code8_reg[5][6:1]};
    else if(char8_reg[5][2])
        code7_comb[5] = {1'd0,code8_reg[5][6:1]};
    else
        code7_comb[5] = code8_reg[5];
end

always @(*) begin
    if(char8_reg[6][1])
        code7_comb[6] = {1'd1,code8_reg[6][6:1]};
    else if(char8_reg[5][1])
        code7_comb[6] = {1'd0,code8_reg[6][6:1]};
    else
        code7_comb[6] = code8_reg[6];
end

always @(*) begin
    if(char8_reg[6][0])
        code7_comb[7] = {1'd1,code8_reg[7][6:1]};
    else if(char8_reg[5][0])
        code7_comb[7] = {1'd0,code8_reg[7][6:1]};
    else
        code7_comb[7] = code8_reg[7];
end



//==============================================//
//                   ENCODE6                    //
//==============================================//

assign char6 = char7_comb[4] | char7_comb[5];
assign wgt6  = wgt7_comb[4] + wgt7_comb[5];

always @(*) begin
    if(wgt6 > wgt7_comb[3]) begin
        if(wgt6 > wgt7_comb[1]) begin
            if(wgt6 > wgt7_comb[0]) begin
                wgt6_comb = {wgt6,wgt7_comb[0:3]};
            end else begin
                wgt6_comb = {wgt7_comb[0],wgt6,wgt7_comb[1:3]};
            end
        end else begin
            if(wgt6 > wgt7_comb[2]) begin
                wgt6_comb = {wgt7_comb[0:1],wgt6,wgt7_comb[2:3]};
            end else begin
                wgt6_comb = {wgt7_comb[0:2],wgt6,wgt7_comb[3]};
            end
        end
    end else begin
        wgt6_comb = {wgt7_comb[0:3],wgt6};
    end
end

always @(*) begin
    if(wgt6 > wgt7_comb[3]) begin
        if(wgt6 > wgt7_comb[1]) begin
            if(wgt6 > wgt7_comb[0]) begin
                char6_comb = {char6,char7_comb[0:3]};
            end else begin
                char6_comb = {char7_comb[0],char6,char7_comb[1:3]};
            end
        end else begin
            if(wgt6 > wgt7_comb[2]) begin
                char6_comb = {char7_comb[0:1],char6,char7_comb[2:3]};
            end else begin
                char6_comb = {char7_comb[0:2],char6,char7_comb[3]};
            end
        end
    end else begin
        char6_comb = {char7_comb[0:3],char6};
    end
end

assign length6_comb[0] = (char7_comb[4][7] || char7_comb[5][7]) ? length7_comb[0] + 1 : length7_comb[0];
assign length6_comb[1] = (char7_comb[4][6] || char7_comb[5][6]) ? length7_comb[1] + 1 : length7_comb[1];
assign length6_comb[2] = (char7_comb[4][5] || char7_comb[5][5]) ? length7_comb[2] + 1 : length7_comb[2];
assign length6_comb[3] = (char7_comb[4][4] || char7_comb[5][4]) ? length7_comb[3] + 1 : length7_comb[3];
assign length6_comb[4] = (char7_comb[4][3] || char7_comb[5][3]) ? length7_comb[4] + 1 : length7_comb[4];
assign length6_comb[5] = (char7_comb[4][2] || char7_comb[5][2]) ? length7_comb[5] + 1 : length7_comb[5];
assign length6_comb[6] = (char7_comb[4][1] || char7_comb[5][1]) ? length7_comb[6] + 1 : length7_comb[6];
assign length6_comb[7] = (char7_comb[4][0] || char7_comb[5][0]) ? length7_comb[7] + 1 : length7_comb[7];

always @(*) begin
    if(char7_comb[5][7])
        code6_comb[0] = {1'd1,code7_comb[0][6:1]};
    else if(char7_comb[4][7])
        code6_comb[0] = {1'd0,code7_comb[0][6:1]};
    else
        code6_comb[0] = code7_comb[0];
end

always @(*) begin
    if(char7_comb[5][6])
        code6_comb[1] = {1'd1,code7_comb[1][6:1]};
    else if(char7_comb[4][6])
        code6_comb[1] = {1'd0,code7_comb[1][6:1]};
    else
        code6_comb[1] = code7_comb[1];
end

always @(*) begin
    if(char7_comb[5][5])
        code6_comb[2] = {1'd1,code7_comb[2][6:1]};
    else if(char7_comb[4][5])
        code6_comb[2] = {1'd0,code7_comb[2][6:1]};
    else
        code6_comb[2] = code7_comb[2];
end

always @(*) begin
    if(char7_comb[5][4])
        code6_comb[3] = {1'd1,code7_comb[3][6:1]};
    else if(char7_comb[4][4])
        code6_comb[3] = {1'd0,code7_comb[3][6:1]};
    else
        code6_comb[3] = code7_comb[3];
end

always @(*) begin
    if(char7_comb[5][3])
        code6_comb[4] = {1'd1,code7_comb[4][6:1]};
    else if(char7_comb[4][3])
        code6_comb[4] = {1'd0,code7_comb[4][6:1]};
    else
        code6_comb[4] = code7_comb[4];
end

always @(*) begin
    if(char7_comb[5][2])
        code6_comb[5] = {1'd1,code7_comb[5][6:1]};
    else if(char7_comb[4][2])
        code6_comb[5] = {1'd0,code7_comb[5][6:1]};
    else
        code6_comb[5] = code7_comb[5];
end

always @(*) begin
    if(char7_comb[5][1])
        code6_comb[6] = {1'd1,code7_comb[6][6:1]};
    else if(char7_comb[4][1])
        code6_comb[6] = {1'd0,code7_comb[6][6:1]};
    else
        code6_comb[6] = code7_comb[6];
end

always @(*) begin
    if(char7_comb[5][0])
        code6_comb[7] = {1'd1,code7_comb[7][6:1]};
    else if(char7_comb[4][0])
        code6_comb[7] = {1'd0,code7_comb[7][6:1]};
    else
        code6_comb[7] = code7_comb[7];
end

//==============================================//
//                   ENCODE5                    //
//==============================================//

assign char5 = char6_comb[3] | char6_comb[4];
assign wgt5  = wgt6_comb[3] + wgt6_comb[4];

always @(*) begin
    if(wgt5 > wgt6_comb[1]) begin
        if(wgt5 > wgt6_comb[0]) begin
            wgt5_comb = {wgt5,wgt6_comb[0:2]};
        end else begin
            wgt5_comb = {wgt6_comb[0],wgt5,wgt6_comb[1:2]};
        end
    end else begin
        if(wgt5 > wgt6_comb[2]) begin
            wgt5_comb = {wgt6_comb[0:1],wgt5,wgt6_comb[2]};
        end else begin
            wgt5_comb = {wgt6_comb[0:2],wgt5};
        end
    end
end

always @(*) begin
    if(wgt5 > wgt6_comb[1]) begin
        if(wgt5 > wgt6_comb[0]) begin
            char5_comb = {char5,char6_comb[0:2]};
        end else begin
            char5_comb = {char6_comb[0],char5,char6_comb[1:2]};
        end
    end else begin
        if(wgt5 > wgt6_comb[2]) begin
            char5_comb = {char6_comb[0:1],char5,char6_comb[2]};
        end else begin
            char5_comb = {char6_comb[0:2],char5};
        end
    end
end

assign length5_comb[0] = (char6_comb[3][7] || char6_comb[4][7]) ? length6_comb[0] + 1 : length6_comb[0];
assign length5_comb[1] = (char6_comb[3][6] || char6_comb[4][6]) ? length6_comb[1] + 1 : length6_comb[1];
assign length5_comb[2] = (char6_comb[3][5] || char6_comb[4][5]) ? length6_comb[2] + 1 : length6_comb[2];
assign length5_comb[3] = (char6_comb[3][4] || char6_comb[4][4]) ? length6_comb[3] + 1 : length6_comb[3];
assign length5_comb[4] = (char6_comb[3][3] || char6_comb[4][3]) ? length6_comb[4] + 1 : length6_comb[4];
assign length5_comb[5] = (char6_comb[3][2] || char6_comb[4][2]) ? length6_comb[5] + 1 : length6_comb[5];
assign length5_comb[6] = (char6_comb[3][1] || char6_comb[4][1]) ? length6_comb[6] + 1 : length6_comb[6];
assign length5_comb[7] = (char6_comb[3][0] || char6_comb[4][0]) ? length6_comb[7] + 1 : length6_comb[7];

always @(*) begin
    if(char6_comb[4][7])
        code5_comb[0] = {1'd1,code6_comb[0][6:1]};
    else if(char6_comb[3][7])
        code5_comb[0] = {1'd0,code6_comb[0][6:1]};
    else
        code5_comb[0] = code6_comb[0];
end

always @(*) begin
    if(char6_comb[4][6])
        code5_comb[1] = {1'd1,code6_comb[1][6:1]};
    else if(char6_comb[3][6])
        code5_comb[1] = {1'd0,code6_comb[1][6:1]};
    else
        code5_comb[1] = code6_comb[1];
end

always @(*) begin
    if(char6_comb[4][5])
        code5_comb[2] = {1'd1,code6_comb[2][6:1]};
    else if(char6_comb[3][5])
        code5_comb[2] = {1'd0,code6_comb[2][6:1]};
    else
        code5_comb[2] = code6_comb[2];
end

always @(*) begin
    if(char6_comb[4][4])
        code5_comb[3] = {1'd1,code6_comb[3][6:1]};
    else if(char6_comb[3][4])
        code5_comb[3] = {1'd0,code6_comb[3][6:1]};
    else
        code5_comb[3] = code6_comb[3];
end

always @(*) begin
    if(char6_comb[4][3])
        code5_comb[4] = {1'd1,code6_comb[4][6:1]};
    else if(char6_comb[3][3])
        code5_comb[4] = {1'd0,code6_comb[4][6:1]};
    else
        code5_comb[4] = code6_comb[4];
end

always @(*) begin
    if(char6_comb[4][2])
        code5_comb[5] = {1'd1,code6_comb[5][6:1]};
    else if(char6_comb[3][2])
        code5_comb[5] = {1'd0,code6_comb[5][6:1]};
    else
        code5_comb[5] = code6_comb[5];
end

always @(*) begin
    if(char6_comb[4][1])
        code5_comb[6] = {1'd1,code6_comb[6][6:1]};
    else if(char6_comb[3][1])
        code5_comb[6] = {1'd0,code6_comb[6][6:1]};
    else
        code5_comb[6] = code6_comb[6];
end

always @(*) begin
    if(char6_comb[4][0])
        code5_comb[7] = {1'd1,code6_comb[7][6:1]};
    else if(char6_comb[3][0])
        code5_comb[7] = {1'd0,code6_comb[7][6:1]};
    else
        code5_comb[7] = code6_comb[7];
end

//==============================================//
//                   ENCODE4                    //
//==============================================//

assign char4 = char5_comb[2] | char5_comb[3];
assign wgt4  = wgt5_comb[2] + wgt5_comb[3];

always @(*) begin
    if(wgt4 > wgt5_comb[1]) begin
        if(wgt4 > wgt5_comb[0]) begin
            wgt4_comb = {wgt4,{1'd0,wgt5_comb[0]},{1'd0,wgt5_comb[1]}};
        end else begin
            wgt4_comb = {{1'd0,wgt5_comb[0]},wgt4,{1'd0,wgt5_comb[1]}};
        end
    end else begin
        wgt4_comb = {{1'd0,wgt5_comb[0]},{1'd0,wgt5_comb[1]},wgt4};
    end
end

always @(*) begin
    if(wgt4 > wgt5_comb[1]) begin
        if(wgt4 > wgt5_comb[0]) begin
            char4_comb = {char4,char5_comb[0:1]};
        end else begin
            char4_comb = {char5_comb[0],char4,char5_comb[1]};
        end
    end else begin
        char4_comb = {char5_comb[0:1],char4};
    end
end

assign length4_comb[0] = (char5_comb[2][7] || char5_comb[3][7]) ? length5_comb[0] + 1 : length5_comb[0];
assign length4_comb[1] = (char5_comb[2][6] || char5_comb[3][6]) ? length5_comb[1] + 1 : length5_comb[1];
assign length4_comb[2] = (char5_comb[2][5] || char5_comb[3][5]) ? length5_comb[2] + 1 : length5_comb[2];
assign length4_comb[3] = (char5_comb[2][4] || char5_comb[3][4]) ? length5_comb[3] + 1 : length5_comb[3];
assign length4_comb[4] = (char5_comb[2][3] || char5_comb[3][3]) ? length5_comb[4] + 1 : length5_comb[4];
assign length4_comb[5] = (char5_comb[2][2] || char5_comb[3][2]) ? length5_comb[5] + 1 : length5_comb[5];
assign length4_comb[6] = (char5_comb[2][1] || char5_comb[3][1]) ? length5_comb[6] + 1 : length5_comb[6];
assign length4_comb[7] = (char5_comb[2][0] || char5_comb[3][0]) ? length5_comb[7] + 1 : length5_comb[7];

always @(*) begin
    if(char5_comb[3][7])
        code4_comb[0] = {1'd1,code5_comb[0][6:1]};
    else if(char5_comb[2][7])
        code4_comb[0] = {1'd0,code5_comb[0][6:1]};
    else
        code4_comb[0] = code5_comb[0];
end

always @(*) begin
    if(char5_comb[3][6])
        code4_comb[1] = {1'd1,code5_comb[1][6:1]};
    else if(char5_comb[2][6])
        code4_comb[1] = {1'd0,code5_comb[1][6:1]};
    else
        code4_comb[1] = code5_comb[1];
end

always @(*) begin
    if(char5_comb[3][5])
        code4_comb[2] = {1'd1,code5_comb[2][6:1]};
    else if(char5_comb[2][5])
        code4_comb[2] = {1'd0,code5_comb[2][6:1]};
    else
        code4_comb[2] = code5_comb[2];
end

always @(*) begin
    if(char5_comb[3][4])
        code4_comb[3] = {1'd1,code5_comb[3][6:1]};
    else if(char5_comb[2][4])
        code4_comb[3] = {1'd0,code5_comb[3][6:1]};
    else
        code4_comb[3] = code5_comb[3];
end

always @(*) begin
    if(char5_comb[3][3])
        code4_comb[4] = {1'd1,code5_comb[4][6:1]};
    else if(char5_comb[2][3])
        code4_comb[4] = {1'd0,code5_comb[4][6:1]};
    else
        code4_comb[4] = code5_comb[4];
end

always @(*) begin
    if(char5_comb[3][2])
        code4_comb[5] = {1'd1,code5_comb[5][6:1]};
    else if(char5_comb[2][2])
        code4_comb[5] = {1'd0,code5_comb[5][6:1]};
    else
        code4_comb[5] = code5_comb[5];
end

always @(*) begin
    if(char5_comb[3][1])
        code4_comb[6] = {1'd1,code5_comb[6][6:1]};
    else if(char5_comb[2][1])
        code4_comb[6] = {1'd0,code5_comb[6][6:1]};
    else
        code4_comb[6] = code5_comb[6];
end

always @(*) begin
    if(char5_comb[3][0])
        code4_comb[7] = {1'd1,code5_comb[7][6:1]};
    else if(char5_comb[2][0])
        code4_comb[7] = {1'd0,code5_comb[7][6:1]};
    else
        code4_comb[7] = code5_comb[7];
end

//==============================================//
//                   ENCODE3                    //
//==============================================//

assign char3 = char4_comb[1] | char4_comb[2];
assign wgt3  = wgt4_comb[1] + wgt4_comb[2];

always @(*) begin
    if(wgt3 > wgt4_comb[0]) begin
        wgt3_comb = {wgt3,wgt4_comb[0]};
    end else begin
        wgt3_comb = {wgt4_comb[0],wgt3};
    end
end

always @(*) begin
    if(wgt3 > wgt4_comb[0]) begin
        char3_comb = {char3,char4_comb[0]};
    end else begin
        char3_comb = {char4_comb[0],char3};
    end
end

assign length3_comb[0] = (char4_comb[1][7] || char4_comb[2][7]) ? length4_comb[0] + 1 : length4_comb[0];
assign length3_comb[1] = (char4_comb[1][6] || char4_comb[2][6]) ? length4_comb[1] + 1 : length4_comb[1];
assign length3_comb[2] = (char4_comb[1][5] || char4_comb[2][5]) ? length4_comb[2] + 1 : length4_comb[2];
assign length3_comb[3] = (char4_comb[1][4] || char4_comb[2][4]) ? length4_comb[3] + 1 : length4_comb[3];
assign length3_comb[4] = (char4_comb[1][3] || char4_comb[2][3]) ? length4_comb[4] + 1 : length4_comb[4];
assign length3_comb[5] = (char4_comb[1][2] || char4_comb[2][2]) ? length4_comb[5] + 1 : length4_comb[5];
assign length3_comb[6] = (char4_comb[1][1] || char4_comb[2][1]) ? length4_comb[6] + 1 : length4_comb[6];
assign length3_comb[7] = (char4_comb[1][0] || char4_comb[2][0]) ? length4_comb[7] + 1 : length4_comb[7];

always @(*) begin
    if(char4_comb[2][7])
        code3_comb[0] = {1'd1,code4_comb[0][6:1]};
    else if(char4_comb[1][7])
        code3_comb[0] = {1'd0,code4_comb[0][6:1]};
    else
        code3_comb[0] = code4_comb[0];
end

always @(*) begin
    if(char4_comb[2][6])
        code3_comb[1] = {1'd1,code4_comb[1][6:1]};
    else if(char4_comb[1][6])
        code3_comb[1] = {1'd0,code4_comb[1][6:1]};
    else
        code3_comb[1] = code4_comb[1];
end

always @(*) begin
    if(char4_comb[2][5])
        code3_comb[2] = {1'd1,code4_comb[2][6:1]};
    else if(char4_comb[1][5])
        code3_comb[2] = {1'd0,code4_comb[2][6:1]};
    else
        code3_comb[2] = code4_comb[2];
end

always @(*) begin
    if(char4_comb[2][4])
        code3_comb[3] = {1'd1,code4_comb[3][6:1]};
    else if(char4_comb[1][4])
        code3_comb[3] = {1'd0,code4_comb[3][6:1]};
    else
        code3_comb[3] = code4_comb[3];
end

always @(*) begin
    if(char4_comb[2][3])
        code3_comb[4] = {1'd1,code4_comb[4][6:1]};
    else if(char4_comb[1][3])
        code3_comb[4] = {1'd0,code4_comb[4][6:1]};
    else
        code3_comb[4] = code4_comb[4];
end

always @(*) begin
    if(char4_comb[2][2])
        code3_comb[5] = {1'd1,code4_comb[5][6:1]};
    else if(char4_comb[1][2])
        code3_comb[5] = {1'd0,code4_comb[5][6:1]};
    else
        code3_comb[5] = code4_comb[5];
end

always @(*) begin
    if(char4_comb[2][1])
        code3_comb[6] = {1'd1,code4_comb[6][6:1]};
    else if(char4_comb[1][1])
        code3_comb[6] = {1'd0,code4_comb[6][6:1]};
    else
        code3_comb[6] = code4_comb[6];
end

always @(*) begin
    if(char4_comb[2][0])
        code3_comb[7] = {1'd1,code4_comb[7][6:1]};
    else if(char4_comb[1][0])
        code3_comb[7] = {1'd0,code4_comb[7][6:1]};
    else
        code3_comb[7] = code4_comb[7];
end

//==============================================//
//                   ENCODE2                    //
//==============================================//

assign length2_comb[0] = (cur_state == S_INPUT) ? length3_comb[0] + 1 : length[0];
assign length2_comb[1] = (cur_state == S_INPUT) ? length3_comb[1] + 1 : length[1];
assign length2_comb[2] = (cur_state == S_INPUT) ? length3_comb[2] + 1 : length[2];
assign length2_comb[3] = (cur_state == S_INPUT) ? length3_comb[3] + 1 : length[3];
assign length2_comb[4] = (cur_state == S_INPUT) ? length3_comb[4] + 1 : length[4];
assign length2_comb[5] = (cur_state == S_INPUT) ? length3_comb[5] + 1 : length[5];
assign length2_comb[6] = (cur_state == S_INPUT) ? length3_comb[6] + 1 : length[6];
assign length2_comb[7] = (cur_state == S_INPUT) ? length3_comb[7] + 1 : length[7];

always @(*) begin
    case(cur_state)
        S_INPUT: begin
            if(char3_comb[1][7])
                code2_comb[0] = {1'd1,code3_comb[0][6:1]};
            else if(char3_comb[0][7])
                code2_comb[0] = {1'd0,code3_comb[0][6:1]};
            else
                code2_comb[0] = code3_comb[0];
        end
        S_A: code2_comb[0] = code[0] << 1;
        default: code2_comb[0] = code[0];
    endcase   
end

always @(*) begin
    case(cur_state)
        S_INPUT: begin
        if(char3_comb[1][6])
            code2_comb[1] = {1'd1,code3_comb[1][6:1]};
        else if(char3_comb[0][6])
            code2_comb[1] = {1'd0,code3_comb[1][6:1]};
        else
            code2_comb[1] = code3_comb[1];
        end
        S_B: code2_comb[1] = code[1] << 1;
        default: code2_comb[1] = code[1];
    endcase
end

always @(*) begin
    case(cur_state)
        S_INPUT: begin
        if(char3_comb[1][5])
            code2_comb[2] = {1'd1,code3_comb[2][6:1]};
        else if(char3_comb[0][5])
            code2_comb[2] = {1'd0,code3_comb[2][6:1]};
        else
            code2_comb[2] = code3_comb[2];
        end
        S_C: code2_comb[2] = code[2] << 1;
        default: code2_comb[2] = code[2];
    endcase
end

always @(*) begin
    case(cur_state)
        S_INPUT: begin
        if(char3_comb[1][4])
            code2_comb[3] = {1'd1,code3_comb[3][6:1]};
        else if(char3_comb[0][4])
            code2_comb[3] = {1'd0,code3_comb[3][6:1]};
        else
            code2_comb[3] = code3_comb[3];
        end
        S_E: code2_comb[3] = code[3] << 1;
        default: code2_comb[3] = code[3];
    endcase
end

always @(*) begin
    case(cur_state)
        S_INPUT: begin
        if(char3_comb[1][3])
            code2_comb[4] = {1'd1,code3_comb[4][6:1]};
        else if(char3_comb[0][3])
            code2_comb[4] = {1'd0,code3_comb[4][6:1]};
        else
            code2_comb[4] = code3_comb[4];
        end
        S_I: code2_comb[4] = code[4] << 1;
        default: code2_comb[4] = code[4];
    endcase
end

always @(*) begin
    case(cur_state)
        S_INPUT: begin
        if(char3_comb[1][2])
            code2_comb[5] = {1'd1,code3_comb[5][6:1]};
        else if(char3_comb[0][2])
            code2_comb[5] = {1'd0,code3_comb[5][6:1]};
        else
            code2_comb[5] = code3_comb[5];
        end
        S_L: code2_comb[5] = code[5] << 1;
        default: code2_comb[5] = code[5];
    endcase
end

always @(*) begin
    case(cur_state)
        S_INPUT: begin
        if(char3_comb[1][1])
            code2_comb[6] = {1'd1,code3_comb[6][6:1]};
        else if(char3_comb[0][1])
            code2_comb[6] = {1'd0,code3_comb[6][6:1]};
        else
            code2_comb[6] = code3_comb[6];
        end
        S_O: code2_comb[6] = code[6] << 1;
        default: code2_comb[6] = code[6];
    endcase
end

always @(*) begin
    case(cur_state)
        S_INPUT: begin
        if(char3_comb[1][0])
            code2_comb[7] = {1'd1,code3_comb[7][6:1]};
        else if(char3_comb[0][0])
            code2_comb[7] = {1'd0,code3_comb[7][6:1]};
        else
            code2_comb[7] = code3_comb[7];
        end
        S_V: code2_comb[7] = code[7] << 1;
        default: code2_comb[7] = code[7];
    endcase
end

always @(posedge clk) begin
    code <= code2_comb;
end

always @(posedge clk) begin
    length <= length2_comb;
end

//==============================================//
//                    OUTPUT                    //
//==============================================//

always @(*) begin
    case(cur_state)
        S_INPUT: begin
            if(cnt == 0)
                out_valid_comb = 1;
            else
                out_valid_comb = 0;
        end
        S_I: out_valid_comb = 1;
        S_L: out_valid_comb = 1;
        S_O: out_valid_comb = 1;
        S_V: out_valid_comb = 1;
        S_E: begin
            if(outcnt == length[3])
                out_valid_comb = 0;
            else
                out_valid_comb = 1;
        end
        S_C: out_valid_comb = 1;
        S_A: out_valid_comb = 1;
        S_B: begin
            if(outcnt == length[1])
                out_valid_comb = 0;
            else
                out_valid_comb = 1;
        end
        default: out_valid_comb = 0;
    endcase
end

always @(*) begin
    case(cur_state)
        S_INPUT: begin
            if(cnt == 0)
                out_code_comb = code2_comb[4][6];
            else
                out_code_comb = 0;
        end
        S_I: begin
            if(outcnt == length[4])
                if(mode_ff)
                    out_code_comb = code[2][6];
                else
                    out_code_comb = code[5][6];
            else
                out_code_comb = code[4][5];
        end
        S_L: begin
            if(outcnt == length[5])
                if(mode_ff)
                    out_code_comb = code[0][6];
                else
                    out_code_comb = code[6][6];
            else
                out_code_comb = code[5][5];
        end
        S_O: begin
            if(outcnt == length[6])
                out_code_comb = code[7][6];
            else
                out_code_comb = code[6][5];
        end
        S_V: begin
            if(outcnt == length[7])
                out_code_comb = code[3][6];
            else
                out_code_comb = code[7][5];
        end
        S_E: begin
            if(outcnt == length[3])
                out_code_comb = 0;
            else
                out_code_comb = code[3][5];
        end
        S_C: begin
            if(outcnt == length[2])
                out_code_comb = code[5][6];
            else
                out_code_comb = code[2][5];
        end
        S_A: begin
            if(outcnt == length[0])
                out_code_comb = code[1][6];
            else
                out_code_comb = code[0][5];
        end
        S_B: begin
            if(outcnt == length[1])
                out_code_comb = 0;
            else
                out_code_comb = code[1][5];
        end
        default: out_code_comb = 0;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        out_valid <= 0;
    else
        out_valid <= out_valid_comb;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        out_code <= 0;
    else
        out_code <= out_code_comb;
end

endmodule