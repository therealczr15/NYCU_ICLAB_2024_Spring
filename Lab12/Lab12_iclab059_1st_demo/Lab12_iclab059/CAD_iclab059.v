module CAD(
    // input signals
    clk,
    rst_n,
    in_valid, 
    in_valid2,
    mode,
    matrix_size,
    matrix,
    matrix_idx,
    // output signals
    out_valid,
    out_value
    );

input [1:0] matrix_size;
input clk;
input [7:0] matrix;
input rst_n;
input [3:0] matrix_idx;
input in_valid2;

input mode;
input in_valid;
output reg out_valid;
output reg out_value;


//==============================================//
//                   REG/WIRE                   //
//==============================================//

// FSM
reg [3:0] cur_state, nxt_state;

// INPUT FF
reg mode_ff, mode_comb;
reg [1:0] matrix_size_ff, matrix_size_comb;
reg [3:0] img_channel_ff, img_channel_comb, knl_channel_ff, knl_channel_comb;

// INPUT COUNTER CONTROL
reg [6:0] cnt, cnt_comb, cntPlusOne;
reg [6:0] row, row_comb, rowPlusOne;
reg [3:0] channel, channel_comb, channelPlusOne;

// INPUT SHIFT REGISTER 1x8
reg [7:0] shift_register1x8 [0:7], shift_register1x8_comb[0:7];

// IMAGE SRAM CONTROL
reg writeImg;
reg [63:0] DoImg, DiImg;
reg [10:0] aImg;

// KERNEL SRAM CONTROL
reg writeKnl;
reg [39:0] DoKnl, DiKnl;
reg [6:0] aKnl;

// MULTIPLIER
reg  signed [7:0]  ma[0:19], mb[0:19], ma_comb[0:19], mb_comb[0:19];
wire signed [15:0] mz[0:19];

// PE 
reg signed [19:0] pe[0:3], pe_comb[0:3];

// POOLING
wire signed [19:0] max[0:2];
reg  signed [19:0] pool, pool_comb;
reg  signed [19:0] max_store, max_store_comb;

// CONVOLUTION CONTROL
reg [6:0] row_conv8, row_conv8_comb, row_conv16, row_conv16_comb, row_conv32, row_conv32_comb;
reg [6:0] row_deconv8, row_deconv8_comb, row_deconv16, row_deconv16_comb, row_deconv32, row_deconv32_comb;

reg  [4:0] index_offset, index_offset_comb;
wire [4:0] index_offsetPlusTwo, index_offsetPlusOne;
reg  [6:0] row_offset, row_offset_comb;
wire [6:0] row_offsetPlusOne;
reg  [1:0] row_offset32, row_offset32_comb;
wire [1:0] row_offset32PlusOne;

// CONVOLUTION SHIFT REGISTER 1x32
reg [7:0] shift_register1x32 [0:31], shift_register1x32_comb[0:31];

// DECONV
reg signed [19:0] deconv, deconv_comb, deconv_store, deconv_store_comb;

// DECONVOLUTION SHIFT REGISTER 1x16
reg [7:0] shift_register1x16 [0:15], shift_register1x16_comb[0:15];

// DECONVOLUTION SHIFT REGISTER 1x24
reg [7:0] shift_register1x24 [0:23], shift_register1x24_comb[0:23];

// DECONVOLUTION SHIFT REGISTER 1x5
reg [7:0] shift_register1x5 [0:4], shift_register1x5_comb[0:4];

// OUTPUT
reg out_valid_comb;
reg out_value_comb;

//==============================================//
//                  PARAMETER                   //
//==============================================//

parameter   S_IDLE      =   4'd0;
parameter   S_IMAGE     =   4'd1;
parameter   S_KERNEL    =   4'd2;
parameter   S_CONV      =   4'd3;
parameter   S_CONV8     =   4'd4;
parameter   S_CONV16    =   4'd5;
parameter   S_CONV32    =   4'd6;
parameter   S_DECONV    =   4'd7;
parameter   S_DECONV8   =   4'd8;
parameter   S_DECONV16  =   4'd9;
parameter   S_DECONV32  =   4'd10;   

//==============================================//
//                     FSM                      //
//==============================================//

always @(*) begin
    case(cur_state)
        S_IDLE: begin
            if(in_valid)
                nxt_state = S_IMAGE;
            else if(in_valid2) begin
                if(mode)
                    nxt_state = S_DECONV;
                else
                    nxt_state = S_CONV;
            end else
                nxt_state = cur_state;
        end
        S_IMAGE: begin
            case(matrix_size_ff)
                2'd0: begin
                    if(cnt == 7 && row == 7 && channel == 15)
                        nxt_state = S_KERNEL;
                    else
                        nxt_state = cur_state;
                end
                2'd1: begin
                    if(cnt == 7 && row == 31 && channel == 15)
                        nxt_state = S_KERNEL;
                    else
                        nxt_state = cur_state;
                end
                2'd2: begin
                    if(cnt == 7 && row == 127 && channel == 15)
                        nxt_state = S_KERNEL;
                    else
                        nxt_state = cur_state;
                end
                default: nxt_state = cur_state;
            endcase
        end
        S_KERNEL: begin
            if(cnt == 4 && row == 4 && channel == 15)
                nxt_state = S_IDLE;
            else
                nxt_state = cur_state;
        end
        S_CONV: begin
            if(cnt == 8) begin
                case(matrix_size_ff)
                    2'd0: nxt_state = S_CONV8;
                    2'd1: nxt_state = S_CONV16;
                    2'd2: nxt_state = S_CONV32;
                    default: nxt_state = cur_state;
                endcase
            end else
                nxt_state = cur_state;
        end
        S_CONV8: begin
            if(cnt == 19 && row_offset == 2 && index_offset == 0)
                nxt_state = S_IDLE;
            else
                nxt_state = cur_state;
        end
        S_CONV16: begin
            if(cnt == 19 && row_offset == 6 && index_offset == 0)
                nxt_state = S_IDLE;
            else
                nxt_state = cur_state;
        end
        S_CONV32: begin
            if(cnt == 19 && row_offset == 14 && index_offset == 0)
                nxt_state = S_IDLE;
            else
                nxt_state = cur_state;
        end
        S_DECONV: begin
            if(cnt == 2) begin
                case(matrix_size_ff)
                    2'd0: nxt_state = S_DECONV8;
                    2'd1: nxt_state = S_DECONV16;
                    2'd2: nxt_state = S_DECONV32;
                    default: nxt_state = cur_state;
                endcase
            end else
                nxt_state = cur_state;
        end
        S_DECONV8: begin
            if(cnt == 19 && (row + row_offset == 12) && index_offset == 0)
                nxt_state = S_IDLE;
            else
                nxt_state = cur_state;
        end
        S_DECONV16: begin
            if(cnt == 19 && (row + row_offset == 20) && index_offset == 0)
                nxt_state = S_IDLE;
            else
                nxt_state = cur_state;
        end
        S_DECONV32: begin
            if(cnt == 19 && (row + row_offset == 36) && index_offset == 0)
                nxt_state = S_IDLE;
            else
                nxt_state = cur_state;
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

assign rowPlusOne = row + 1;
assign cntPlusOne = cnt + 1;
assign channelPlusOne = channel + 1;

always @(*) begin
    case(cur_state)
        S_IDLE: begin
            if(in_valid2 && !mode)
                cnt_comb = cntPlusOne;
            else
                cnt_comb = 0;
        end
        S_IMAGE: begin
            if(cnt == 7)
                cnt_comb = 0;
            else
                cnt_comb = cntPlusOne;
        end
        S_KERNEL: begin
            if(cnt == 4)
                cnt_comb = 0;
            else
                cnt_comb = cntPlusOne;
        end

        // USED FOR IMAGE BELOW
        S_CONV: begin
            if(cnt == 8)
                cnt_comb = 0;
            else
                cnt_comb = cntPlusOne;
        end
        S_CONV8: begin
            if(cnt == 19)
                cnt_comb = 0;
            else
                cnt_comb = cntPlusOne;
        end
        S_CONV16: begin
            if(cnt == 19)
                cnt_comb = 0;
            else
                cnt_comb = cntPlusOne;
        end
        S_CONV32: begin
            if(cnt == 19)
                cnt_comb = 0;
            else
                cnt_comb = cntPlusOne;
        end
        S_DECONV: begin
            if(cnt == 2)
                cnt_comb = 0;
            else
                cnt_comb = cntPlusOne;
        end
        S_DECONV8: begin
            if(cnt == 19)
                cnt_comb = 0;
            else
                cnt_comb = cntPlusOne;
        end
        S_DECONV16: begin
            if(cnt == 19)
                cnt_comb = 0;
            else
                cnt_comb = cntPlusOne;
        end
        S_DECONV32: begin
            if(cnt == 19)
                cnt_comb = 0;
            else
                cnt_comb = cntPlusOne;
        end
        default: cnt_comb = 0;
    endcase
end

always @(*) begin
    case(cur_state)
        // USED FOR IMAGE BELOW
        S_IMAGE: begin
            case(matrix_size_ff)
                2'd0: begin
                    if(cnt == 7 && row == 7)
                        row_comb = 0;
                    else if(cnt == 7)
                        row_comb = rowPlusOne;
                    else
                        row_comb = row;
                end
                2'd1: begin
                    if(cnt == 7 && row == 31)
                        row_comb = 0;
                    else if(cnt == 7)
                        row_comb = rowPlusOne;
                    else
                        row_comb = row;
                end
                2'd2: begin
                    if(cnt == 7)
                        row_comb = rowPlusOne;
                    else
                        row_comb = row;
                end
                default: row_comb = 0;
            endcase
        end

        // USED FOR KERNEL BELOW
        S_KERNEL: begin
            if(cnt == 4 && row == 4)
                row_comb = 0;
            else if(cnt == 4)
                row_comb = rowPlusOne;
            else
                row_comb = row;
        end
        S_CONV: begin
            if(cnt == 8)
                row_comb = 0;
            else
                row_comb = rowPlusOne;
        end
        S_CONV8: begin
            if(cnt > 0)
                row_comb = rowPlusOne;
            else
                row_comb = 0;
        end
        S_CONV16: begin
            if(cnt >= 4 && cnt[0])
                row_comb = rowPlusOne;
            else if(cnt >= 4)
                row_comb = row;
            else
                row_comb = 0;
        end
        S_CONV32: begin
            if(cnt >= 4 && cnt[0])
                row_comb = rowPlusOne;
            else if(cnt >= 4)
                row_comb = row;
            else
                row_comb = 0;
        end
        S_DECONV8: begin
            if(row < 4 && row_offset > 0)
                row_comb = rowPlusOne;
            else if(cnt == 19)
                row_comb = 0;
            else
                row_comb = row;
        end
        S_DECONV16: begin
            if(row < 4 && row_offset > 0 && cnt[0])
                row_comb = rowPlusOne;
            else if(cnt == 19)
                row_comb = 0;
            else
                row_comb = row;
        end
        S_DECONV32: begin
            if(row < 4 && row_offset > 0 && cnt[0])
                row_comb = rowPlusOne;
            else if(cnt == 19)
                row_comb = 0;
            else
                row_comb = row;
        end
        default row_comb = 0;
    endcase    
end

always @(*) begin
    case(cur_state)
        S_IMAGE: begin
            case(matrix_size_ff)
                2'd0: begin
                    if(cnt == 7 && row == 7)
                        channel_comb = channelPlusOne;
                    else
                        channel_comb = channel;
                end
                2'd1: begin
                    if(cnt == 7 && row == 31)
                        channel_comb = channelPlusOne;
                    else
                        channel_comb = channel;
                end
                2'd2: begin
                    if(cnt == 7 && row == 127)
                        channel_comb = channelPlusOne;
                    else
                        channel_comb = channel;
                end
                default: channel_comb = 0;
            endcase
        end
        S_KERNEL: begin
            if(cnt == 4 && row == 4)
                channel_comb = channelPlusOne;
            else
                channel_comb = channel;
        end
        default: channel_comb = 0;
    endcase        
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        cnt <= 0;
    else
        cnt <= cnt_comb;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        row <= 0;
    else
        row <= row_comb;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        channel <= 0;
    else
        channel <= channel_comb;
end

//==============================================//
//                   INPUT FF                   //
//==============================================//

always @(*) begin
    if(in_valid && cur_state == S_IDLE)
        matrix_size_comb = matrix_size;
    else
        matrix_size_comb = matrix_size_ff;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        matrix_size_ff <= 0;
    else 
        matrix_size_ff <= matrix_size_comb;
end

always @(*) begin
    if(in_valid2 && cur_state == S_IDLE)
        mode_comb = mode;
    else
        mode_comb = mode_ff;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        mode_ff <= 0;
    else 
        mode_ff <= mode_comb;
end

always @(*) begin
    if(in_valid2 && cur_state == S_IDLE)
        img_channel_comb = matrix_idx;
    else
        img_channel_comb = img_channel_ff;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        img_channel_ff <= 0;
    else 
        img_channel_ff <= img_channel_comb;
end

always @(*) begin
    if(in_valid2 && (cur_state == S_CONV || cur_state == S_DECONV))
        knl_channel_comb = matrix_idx;
    else
        knl_channel_comb = knl_channel_ff;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        knl_channel_ff <= 0;
    else 
        knl_channel_ff <= knl_channel_comb;
end

//==============================================//
//    SHIFT REGISTER (USED TO WRITE IN SRAM)    //
//          & TO READ 8x8 CONVOLUTION           //
//==============================================//

always @(*) begin
    case(cur_state)
        S_IDLE: begin
            if(in_valid)
                shift_register1x8_comb = {shift_register1x8[1:7],matrix};
            else
                shift_register1x8_comb = {8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0};
        end
        S_IMAGE: shift_register1x8_comb = {shift_register1x8[1:7],matrix};
        S_KERNEL: shift_register1x8_comb = {shift_register1x8[1:7],matrix};
        S_CONV: shift_register1x8_comb = {DoImg[63:56],DoImg[55:48],DoImg[47:40],DoImg[39:32],DoImg[31:24],DoImg[23:16],DoImg[15:8],DoImg[7:0]};
        S_CONV8: shift_register1x8_comb = {DoImg[63:56],DoImg[55:48],DoImg[47:40],DoImg[39:32],DoImg[31:24],DoImg[23:16],DoImg[15:8],DoImg[7:0]};
        default: shift_register1x8_comb = {8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0};
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        shift_register1x8 <= {8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0};
    else
        shift_register1x8 <= shift_register1x8_comb;
end

//==============================================//
//              IMAGE SRAM CONTROL              //
//==============================================//

always @(*) begin
    case(cur_state)
        S_IMAGE: writeImg = 1'b0;
        default: writeImg = 1'b1;
    endcase
end

// address [4bit channel,7bit row] 16 x 128
always @(*) begin
    case(cur_state)
        S_IDLE: begin
            if(in_valid2)
                aImg = {matrix_idx,7'd0};
            else
                aImg = 0;
        end
        S_IMAGE: aImg = {channel,row};
        S_CONV: begin
            case(matrix_size_ff)
                2'd0: aImg = {img_channel_ff,cnt}; 
                2'd1: aImg = {img_channel_ff,cnt[5:0],1'd0}; 
                2'd2: aImg = {img_channel_ff,cnt[4:0],2'd0}; 
                default: aImg = 0;
            endcase
        end
        S_CONV8: aImg = {img_channel_ff,row_conv8};
        S_CONV16: aImg = {img_channel_ff,row_conv16};
        S_CONV32: aImg = {img_channel_ff,row_conv32};
        S_DECONV: aImg = {img_channel_ff,cnt};
        S_DECONV8: aImg = {img_channel_ff,row_deconv8};
        S_DECONV16: aImg = {img_channel_ff,row_deconv16};
        S_DECONV32: aImg = {img_channel_ff,row_deconv32};
        default: aImg = 0;
    endcase    
end

always @(*) begin
    DiImg = {shift_register1x8[0],shift_register1x8[1],shift_register1x8[2],shift_register1x8[3],shift_register1x8[4],shift_register1x8[5],shift_register1x8[6],shift_register1x8[7]};
end

//==============================================//
//             KERNEL SRAM CONTROL              //
//==============================================//

always @(*) begin
    case(cur_state)
        S_KERNEL: writeKnl = 1'b0;
        default: writeKnl = 1'b1;
    endcase
end

// address [3bit row,4bit channel] 5 x 16
always @(*) begin
    case(cur_state)
        S_KERNEL: aKnl = {row[2:0],channel};
        S_CONV: begin
            if(in_valid2)
                aKnl = {row[2:0],matrix_idx};
            else if(cnt <= 5)
                aKnl = {row[2:0],knl_channel_ff};
            else
                aKnl = 0;
        end
        S_CONV8: begin
            if(cnt <= 5) 
                aKnl = {row[2:0],knl_channel_ff};
            else
                aKnl = 0;
        end
        S_CONV16: begin
            if(cnt <= 12) 
                aKnl = {row[2:0],knl_channel_ff};
            else
                aKnl = 0;
        end
        S_CONV32: begin
            if(cnt <= 12) 
                aKnl = {row[2:0],knl_channel_ff};
            else
                aKnl = 0;
        end
        S_DECONV: begin
            if(in_valid2)
                aKnl = {row[2:0],matrix_idx};
            else 
                aKnl = 0;
        end
        S_DECONV8: aKnl = {row[2:0],knl_channel_ff};
        S_DECONV16: aKnl = {row[2:0],knl_channel_ff};
        S_DECONV32: aKnl = {row[2:0],knl_channel_ff};
        default: aKnl = 0;
    endcase
end

always @(*) begin
    DiKnl = {shift_register1x8[3],shift_register1x8[4],shift_register1x8[5],shift_register1x8[6],shift_register1x8[7]};
end

//==============================================//
//                  MULTIPLIER                  //
//==============================================//

always @(*) begin
    case(cur_state)
        S_CONV: begin
            ma_comb[0] = shift_register1x8[0];
            ma_comb[1] = shift_register1x8[1];
            ma_comb[2] = shift_register1x8[2];
            ma_comb[3] = shift_register1x8[3];
            ma_comb[4] = shift_register1x8[4];

            ma_comb[5] = shift_register1x8[1];
            ma_comb[6] = shift_register1x8[2];
            ma_comb[7] = shift_register1x8[3];
            ma_comb[8] = shift_register1x8[4];
            ma_comb[9] = shift_register1x8[5];

            ma_comb[10] = DoImg[63:56]; 
            ma_comb[11] = DoImg[55:48]; 
            ma_comb[12] = DoImg[47:40]; 
            ma_comb[13] = DoImg[39:32]; 
            ma_comb[14] = DoImg[31:24];

            ma_comb[15] = DoImg[55:48]; 
            ma_comb[16] = DoImg[47:40]; 
            ma_comb[17] = DoImg[39:32]; 
            ma_comb[18] = DoImg[31:24];
            ma_comb[19] = DoImg[23:16];
        end
        S_CONV8: begin
            ma_comb[0] = shift_register1x8[0+index_offset];
            ma_comb[1] = shift_register1x8[1+index_offset];
            ma_comb[2] = shift_register1x8[2+index_offset];
            ma_comb[3] = shift_register1x8[3+index_offset];
            ma_comb[4] = shift_register1x8[4+index_offset];

            ma_comb[5] = shift_register1x8[1+index_offset];
            ma_comb[6] = shift_register1x8[2+index_offset];
            ma_comb[7] = shift_register1x8[3+index_offset];
            ma_comb[8] = shift_register1x8[4+index_offset];
            ma_comb[9] = shift_register1x8[5+index_offset];

            ma_comb[10] = shift_register1x8_comb[0+index_offset]; 
            ma_comb[11] = shift_register1x8_comb[1+index_offset]; 
            ma_comb[12] = shift_register1x8_comb[2+index_offset]; 
            ma_comb[13] = shift_register1x8_comb[3+index_offset]; 
            ma_comb[14] = shift_register1x8_comb[4+index_offset];

            ma_comb[15] = shift_register1x8_comb[1+index_offset]; 
            ma_comb[16] = shift_register1x8_comb[2+index_offset]; 
            ma_comb[17] = shift_register1x8_comb[3+index_offset]; 
            ma_comb[18] = shift_register1x8_comb[4+index_offset];
            ma_comb[19] = shift_register1x8_comb[5+index_offset];
        end
        S_CONV16: begin
            ma_comb[0]  = shift_register1x32[0+index_offset];
            ma_comb[1]  = shift_register1x32[1+index_offset];
            ma_comb[2]  = shift_register1x32[2+index_offset];
            ma_comb[3]  = shift_register1x32[3+index_offset];
            ma_comb[4]  = shift_register1x32[4+index_offset];

            ma_comb[5]  = shift_register1x32[1+index_offset];
            ma_comb[6]  = shift_register1x32[2+index_offset];
            ma_comb[7]  = shift_register1x32[3+index_offset];
            ma_comb[8]  = shift_register1x32[4+index_offset];
            ma_comb[9]  = shift_register1x32[5+index_offset];

            ma_comb[10] = shift_register1x32[16+index_offset];
            ma_comb[11] = shift_register1x32[17+index_offset];
            ma_comb[12] = shift_register1x32[18+index_offset];
            ma_comb[13] = shift_register1x32[19+index_offset];
            ma_comb[14] = shift_register1x32[20+index_offset];

            ma_comb[15] = shift_register1x32[17+index_offset];
            ma_comb[16] = shift_register1x32[18+index_offset];
            ma_comb[17] = shift_register1x32[19+index_offset];
            ma_comb[18] = shift_register1x32[20+index_offset];
            ma_comb[19] = shift_register1x32[21+index_offset];
        end
        S_CONV32: begin
            ma_comb[0]  = shift_register1x32[0+index_offset];
            ma_comb[1]  = shift_register1x32[1+index_offset];
            ma_comb[2]  = shift_register1x32[2+index_offset];
            ma_comb[3]  = shift_register1x32[3+index_offset];
            ma_comb[4]  = shift_register1x32[4+index_offset];

            ma_comb[5]  = shift_register1x32[1+index_offset];
            ma_comb[6]  = shift_register1x32[2+index_offset];
            ma_comb[7]  = shift_register1x32[3+index_offset];
            ma_comb[8]  = shift_register1x32[4+index_offset];
            ma_comb[9]  = shift_register1x32[5+index_offset];

            ma_comb[10] = shift_register1x32[16+index_offset];
            ma_comb[11] = shift_register1x32[17+index_offset];
            ma_comb[12] = shift_register1x32[18+index_offset];
            ma_comb[13] = shift_register1x32[19+index_offset];
            ma_comb[14] = shift_register1x32[20+index_offset];

            ma_comb[15] = shift_register1x32[17+index_offset];
            ma_comb[16] = shift_register1x32[18+index_offset];
            ma_comb[17] = shift_register1x32[19+index_offset];
            ma_comb[18] = shift_register1x32[20+index_offset];
            ma_comb[19] = shift_register1x32[21+index_offset];
        end
        S_DECONV8: begin
            ma_comb[0]  = shift_register1x16[4+index_offset];
            ma_comb[1]  = shift_register1x16[3+index_offset];
            ma_comb[2]  = shift_register1x16[2+index_offset];
            ma_comb[3]  = shift_register1x16[1+index_offset];
            ma_comb[4]  = shift_register1x16[0+index_offset];

            ma_comb[5]  = shift_register1x8[1];
            ma_comb[6]  = shift_register1x8[2];
            ma_comb[7]  = shift_register1x8[3];
            ma_comb[8]  = shift_register1x8[4];
            ma_comb[9]  = shift_register1x8[5];

            ma_comb[10] =  DoImg[63:56]; 
            ma_comb[11] =  DoImg[55:48]; 
            ma_comb[12] =  DoImg[47:40]; 
            ma_comb[13] =  DoImg[39:32]; 
            ma_comb[14] =  DoImg[31:24];

            ma_comb[15] =  DoImg[55:48]; 
            ma_comb[16] =  DoImg[47:40]; 
            ma_comb[17] =  DoImg[39:32]; 
            ma_comb[18] =  DoImg[31:24];
            ma_comb[19] =  DoImg[23:16];
        end
        S_DECONV16: begin
            ma_comb[0]  = shift_register1x24[4+index_offset];
            ma_comb[1]  = shift_register1x24[3+index_offset];
            ma_comb[2]  = shift_register1x24[2+index_offset];
            ma_comb[3]  = shift_register1x24[1+index_offset];
            ma_comb[4]  = shift_register1x24[0+index_offset];

            ma_comb[5]  = shift_register1x8[1];
            ma_comb[6]  = shift_register1x8[2];
            ma_comb[7]  = shift_register1x8[3];
            ma_comb[8]  = shift_register1x8[4];
            ma_comb[9]  = shift_register1x8[5];

            ma_comb[10] =  DoImg[63:56]; 
            ma_comb[11] =  DoImg[55:48]; 
            ma_comb[12] =  DoImg[47:40]; 
            ma_comb[13] =  DoImg[39:32]; 
            ma_comb[14] =  DoImg[31:24];

            ma_comb[15] =  DoImg[55:48]; 
            ma_comb[16] =  DoImg[47:40]; 
            ma_comb[17] =  DoImg[39:32]; 
            ma_comb[18] =  DoImg[31:24];
            ma_comb[19] =  DoImg[23:16];
        end
        S_DECONV32: begin
            ma_comb[0]  = shift_register1x24[4+index_offset];
            ma_comb[1]  = shift_register1x24[3+index_offset];
            ma_comb[2]  = shift_register1x24[2+index_offset];
            ma_comb[3]  = shift_register1x24[1+index_offset];
            ma_comb[4]  = shift_register1x24[0+index_offset];

            ma_comb[5]  = shift_register1x8[1];
            ma_comb[6]  = shift_register1x8[2];
            ma_comb[7]  = shift_register1x8[3];
            ma_comb[8]  = shift_register1x8[4];
            ma_comb[9]  = shift_register1x8[5];

            ma_comb[10] =  DoImg[63:56]; 
            ma_comb[11] =  DoImg[55:48]; 
            ma_comb[12] =  DoImg[47:40]; 
            ma_comb[13] =  DoImg[39:32]; 
            ma_comb[14] =  DoImg[31:24];

            ma_comb[15] =  DoImg[55:48]; 
            ma_comb[16] =  DoImg[47:40]; 
            ma_comb[17] =  DoImg[39:32]; 
            ma_comb[18] =  DoImg[31:24];
            ma_comb[19] =  DoImg[23:16];
        end
        default: begin
            ma_comb[0] = shift_register1x8[0];
            ma_comb[1] = shift_register1x8[1];
            ma_comb[2] = shift_register1x8[2];
            ma_comb[3] = shift_register1x8[3];
            ma_comb[4] = shift_register1x8[4];

            ma_comb[5] = shift_register1x8[1];
            ma_comb[6] = shift_register1x8[2];
            ma_comb[7] = shift_register1x8[3];
            ma_comb[8] = shift_register1x8[4];
            ma_comb[9] = shift_register1x8[5];

            ma_comb[10] = DoImg[63:56]; 
            ma_comb[11] = DoImg[55:48]; 
            ma_comb[12] = DoImg[47:40]; 
            ma_comb[13] = DoImg[39:32]; 
            ma_comb[14] = DoImg[31:24];

            ma_comb[15] = DoImg[55:48]; 
            ma_comb[16] = DoImg[47:40]; 
            ma_comb[17] = DoImg[39:32]; 
            ma_comb[18] = DoImg[31:24];
            ma_comb[19] = DoImg[23:16];
        end
    endcase
end

always @(*) begin
    case(cur_state)
        S_DECONV8: begin
            mb_comb[0] = shift_register1x5[0];
            mb_comb[1] = shift_register1x5[1];
            mb_comb[2] = shift_register1x5[2];
            mb_comb[3] = shift_register1x5[3];
            mb_comb[4] = shift_register1x5[4];

            mb_comb[5] = DoKnl[39:32];
            mb_comb[6] = DoKnl[31:24];
            mb_comb[7] = DoKnl[23:16];
            mb_comb[8] = DoKnl[15:8];
            mb_comb[9] = DoKnl[7:0];

            mb_comb[10] = DoKnl[39:32];
            mb_comb[11] = DoKnl[31:24];
            mb_comb[12] = DoKnl[23:16];
            mb_comb[13] = DoKnl[15:8];
            mb_comb[14] = DoKnl[7:0];

            mb_comb[15] = DoKnl[39:32];
            mb_comb[16] = DoKnl[31:24];
            mb_comb[17] = DoKnl[23:16];
            mb_comb[18] = DoKnl[15:8];
            mb_comb[19] = DoKnl[7:0];
        end
        S_DECONV16: begin
            mb_comb[0] = shift_register1x5[0];
            mb_comb[1] = shift_register1x5[1];
            mb_comb[2] = shift_register1x5[2];
            mb_comb[3] = shift_register1x5[3];
            mb_comb[4] = shift_register1x5[4];

            mb_comb[5] = DoKnl[39:32];
            mb_comb[6] = DoKnl[31:24];
            mb_comb[7] = DoKnl[23:16];
            mb_comb[8] = DoKnl[15:8];
            mb_comb[9] = DoKnl[7:0];

            mb_comb[10] = DoKnl[39:32];
            mb_comb[11] = DoKnl[31:24];
            mb_comb[12] = DoKnl[23:16];
            mb_comb[13] = DoKnl[15:8];
            mb_comb[14] = DoKnl[7:0];

            mb_comb[15] = DoKnl[39:32];
            mb_comb[16] = DoKnl[31:24];
            mb_comb[17] = DoKnl[23:16];
            mb_comb[18] = DoKnl[15:8];
            mb_comb[19] = DoKnl[7:0];
        end
        S_DECONV32: begin
            mb_comb[0] = shift_register1x5[0];
            mb_comb[1] = shift_register1x5[1];
            mb_comb[2] = shift_register1x5[2];
            mb_comb[3] = shift_register1x5[3];
            mb_comb[4] = shift_register1x5[4];

            mb_comb[5] = DoKnl[39:32];
            mb_comb[6] = DoKnl[31:24];
            mb_comb[7] = DoKnl[23:16];
            mb_comb[8] = DoKnl[15:8];
            mb_comb[9] = DoKnl[7:0];

            mb_comb[10] = DoKnl[39:32];
            mb_comb[11] = DoKnl[31:24];
            mb_comb[12] = DoKnl[23:16];
            mb_comb[13] = DoKnl[15:8];
            mb_comb[14] = DoKnl[7:0];

            mb_comb[15] = DoKnl[39:32];
            mb_comb[16] = DoKnl[31:24];
            mb_comb[17] = DoKnl[23:16];
            mb_comb[18] = DoKnl[15:8];
            mb_comb[19] = DoKnl[7:0];
        end
        default: begin
            mb_comb[0] = DoKnl[39:32];
            mb_comb[1] = DoKnl[31:24];
            mb_comb[2] = DoKnl[23:16];
            mb_comb[3] = DoKnl[15:8];
            mb_comb[4] = DoKnl[7:0];

            mb_comb[5] = DoKnl[39:32];
            mb_comb[6] = DoKnl[31:24];
            mb_comb[7] = DoKnl[23:16];
            mb_comb[8] = DoKnl[15:8];
            mb_comb[9] = DoKnl[7:0];

            mb_comb[10] = DoKnl[39:32];
            mb_comb[11] = DoKnl[31:24];
            mb_comb[12] = DoKnl[23:16];
            mb_comb[13] = DoKnl[15:8];
            mb_comb[14] = DoKnl[7:0];

            mb_comb[15] = DoKnl[39:32];
            mb_comb[16] = DoKnl[31:24];
            mb_comb[17] = DoKnl[23:16];
            mb_comb[18] = DoKnl[15:8];
            mb_comb[19] = DoKnl[7:0];
        end
    endcase
end

genvar i;
generate
    for(i=0;i<20;i=i+1) begin
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) 
                ma[i] <= 0;
            else 
                ma[i] <= ma_comb[i];
        end
    end
endgenerate

genvar i;
generate
    for(i=0;i<20;i=i+1) begin
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) 
                mb[i] <= 0;
            else 
                mb[i] <= mb_comb[i];
        end
    end
endgenerate

assign mz[0] = ma[0] * mb[0];
assign mz[1] = ma[1] * mb[1];
assign mz[2] = ma[2] * mb[2];
assign mz[3] = ma[3] * mb[3];
assign mz[4] = ma[4] * mb[4];

assign mz[5] = ma[5] * mb[5];
assign mz[6] = ma[6] * mb[6];
assign mz[7] = ma[7] * mb[7];
assign mz[8] = ma[8] * mb[8];
assign mz[9] = ma[9] * mb[9];

assign mz[10] = ma[10] * mb[10];
assign mz[11] = ma[11] * mb[11];
assign mz[12] = ma[12] * mb[12];
assign mz[13] = ma[13] * mb[13];
assign mz[14] = ma[14] * mb[14];

assign mz[15] = ma[15] * mb[15];
assign mz[16] = ma[16] * mb[16];
assign mz[17] = ma[17] * mb[17];
assign mz[18] = ma[18] * mb[18];
assign mz[19] = ma[19] * mb[19];

//==============================================//
//                 CONVOLUTION                  //
//==============================================//

always @(*) begin
    case(cur_state)
        S_CONV: begin
            if(cnt >= 3 && cnt <= 7) begin
                pe_comb[0] = (pe[0] + mz[0])  + (mz[1]  + mz[2])  + (mz[3]  + mz[4]);
                pe_comb[1] = (pe[1] + mz[5])  + (mz[6]  + mz[7])  + (mz[8]  + mz[9]);
                pe_comb[2] = (pe[2] + mz[10]) + (mz[11] + mz[12]) + (mz[13] + mz[14]);
                pe_comb[3] = (pe[3] + mz[15]) + (mz[16] + mz[17]) + (mz[18] + mz[19]);
            end else begin
                pe_comb[0] = 0;
                pe_comb[1] = 0;
                pe_comb[2] = 0;
                pe_comb[3] = 0;
            end
        end
        S_CONV8: begin
            if(cnt >= 3 && cnt <= 7) begin
                pe_comb[0] = (pe[0] + mz[0])  + (mz[1]  + mz[2])  + (mz[3]  + mz[4]);
                pe_comb[1] = (pe[1] + mz[5])  + (mz[6]  + mz[7])  + (mz[8]  + mz[9]);
                pe_comb[2] = (pe[2] + mz[10]) + (mz[11] + mz[12]) + (mz[13] + mz[14]);
                pe_comb[3] = (pe[3] + mz[15]) + (mz[16] + mz[17]) + (mz[18] + mz[19]);
            end else begin
                pe_comb[0] = 0;
                pe_comb[1] = 0;
                pe_comb[2] = 0;
                pe_comb[3] = 0;
            end
        end
        S_CONV16: begin
            if(cnt == 6 || cnt == 8 || cnt == 10 || cnt == 12 || cnt == 14) begin
                pe_comb[0] = (pe[0] + mz[0])  + (mz[1]  + mz[2])  + (mz[3]  + mz[4]);
                pe_comb[1] = (pe[1] + mz[5])  + (mz[6]  + mz[7])  + (mz[8]  + mz[9]);
                pe_comb[2] = (pe[2] + mz[10]) + (mz[11] + mz[12]) + (mz[13] + mz[14]);
                pe_comb[3] = (pe[3] + mz[15]) + (mz[16] + mz[17]) + (mz[18] + mz[19]);
            end else if(cnt == 0) begin
                pe_comb[0] = 0;
                pe_comb[1] = 0;
                pe_comb[2] = 0;
                pe_comb[3] = 0;
            end else begin
                pe_comb[0] = pe[0];
                pe_comb[1] = pe[1];
                pe_comb[2] = pe[2];
                pe_comb[3] = pe[3];
            end
        end
        S_CONV32: begin
            if(cnt == 6 || cnt == 8 || cnt == 10 || cnt == 12 || cnt == 14) begin
                pe_comb[0] = (pe[0] + mz[0])  + (mz[1]  + mz[2])  + (mz[3]  + mz[4]);
                pe_comb[1] = (pe[1] + mz[5])  + (mz[6]  + mz[7])  + (mz[8]  + mz[9]);
                pe_comb[2] = (pe[2] + mz[10]) + (mz[11] + mz[12]) + (mz[13] + mz[14]);
                pe_comb[3] = (pe[3] + mz[15]) + (mz[16] + mz[17]) + (mz[18] + mz[19]);
            end else if(cnt == 0) begin
                pe_comb[0] = 0;
                pe_comb[1] = 0;
                pe_comb[2] = 0;
                pe_comb[3] = 0;
            end else begin
                pe_comb[0] = pe[0];
                pe_comb[1] = pe[1];
                pe_comb[2] = pe[2];
                pe_comb[3] = pe[3];
            end
        end
        S_DECONV8: begin
            if(cnt >= 3 && cnt <= 7) begin
                pe_comb[0] = (pe[0] + mz[0])  + (mz[1]  + mz[2])  + (mz[3]  + mz[4]);
                pe_comb[1] = (pe[1] + mz[5])  + (mz[6]  + mz[7])  + (mz[8]  + mz[9]);
                pe_comb[2] = (pe[2] + mz[10]) + (mz[11] + mz[12]) + (mz[13] + mz[14]);
                pe_comb[3] = (pe[3] + mz[15]) + (mz[16] + mz[17]) + (mz[18] + mz[19]);
            end else if(cnt == 0) begin
                pe_comb[0] = 0;
                pe_comb[1] = 0;
                pe_comb[2] = 0;
                pe_comb[3] = 0;
            end else begin
                pe_comb[0] = pe[0];
                pe_comb[1] = pe[1];
                pe_comb[2] = pe[2];
                pe_comb[3] = pe[3];
            end
        end
        S_DECONV16: begin
            if(cnt == 4 || cnt == 6 || cnt == 8 || cnt == 10 || cnt == 12) begin
                pe_comb[0] = (pe[0] + mz[0])  + (mz[1]  + mz[2])  + (mz[3]  + mz[4]);
                pe_comb[1] = (pe[1] + mz[5])  + (mz[6]  + mz[7])  + (mz[8]  + mz[9]);
                pe_comb[2] = (pe[2] + mz[10]) + (mz[11] + mz[12]) + (mz[13] + mz[14]);
                pe_comb[3] = (pe[3] + mz[15]) + (mz[16] + mz[17]) + (mz[18] + mz[19]);
            end else if(cnt == 0) begin
                pe_comb[0] = 0;
                pe_comb[1] = 0;
                pe_comb[2] = 0;
                pe_comb[3] = 0;
            end else begin
                pe_comb[0] = pe[0];
                pe_comb[1] = pe[1];
                pe_comb[2] = pe[2];
                pe_comb[3] = pe[3];
            end
        end
        S_DECONV32: begin
            if(cnt == 4 || cnt == 6 || cnt == 8 || cnt == 10 || cnt == 12) begin
                pe_comb[0] = (pe[0] + mz[0])  + (mz[1]  + mz[2])  + (mz[3]  + mz[4]);
                pe_comb[1] = (pe[1] + mz[5])  + (mz[6]  + mz[7])  + (mz[8]  + mz[9]);
                pe_comb[2] = (pe[2] + mz[10]) + (mz[11] + mz[12]) + (mz[13] + mz[14]);
                pe_comb[3] = (pe[3] + mz[15]) + (mz[16] + mz[17]) + (mz[18] + mz[19]);
            end else if(cnt == 0) begin
                pe_comb[0] = 0;
                pe_comb[1] = 0;
                pe_comb[2] = 0;
                pe_comb[3] = 0;
            end else begin
                pe_comb[0] = pe[0];
                pe_comb[1] = pe[1];
                pe_comb[2] = pe[2];
                pe_comb[3] = pe[3];
            end
        end
        default: begin
            pe_comb[0] = 0;
            pe_comb[1] = 0;
            pe_comb[2] = 0;
            pe_comb[3] = 0;
        end
    endcase
end

genvar i;
generate
    for(i=0;i<4;i=i+1) begin
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) 
                pe[i] <= 0;
            else 
                pe[i] <= pe_comb[i];
        end
    end
endgenerate

//==============================================//
//                 MAX POOLING                  //
//==============================================//

assign max[0] = (pe[0]  > pe[1])  ? pe[0]  : pe[1];
assign max[1] = (pe[2]  > pe[3])  ? pe[2]  : pe[3];
assign max[2] = (max[0] > max[1]) ? max[0] : max[1];

always @(*) begin
    case(cur_state)
        S_CONV: pool_comb = max[2];
        S_CONV8: begin
            if(cnt == 19)
                pool_comb = max_store;
            else
                pool_comb = pool >> 1;
        end
        S_CONV16: begin
            if(cnt == 19)
                pool_comb = max_store;
            else
                pool_comb = pool >> 1;
        end
        S_CONV32: begin
            if(cnt == 19)
                pool_comb = max_store;
            else
                pool_comb = pool >> 1;
        end
        default: pool_comb = 0;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        pool <= 0;
    else 
        pool <= pool_comb;
end

always @(*) begin
    case(cur_state)
        S_CONV8: begin
            if(cnt == 8)
                max_store_comb = max[2];
            else
                max_store_comb = max_store;
        end
        S_CONV16: begin
            if(cnt == 15)
                max_store_comb = max[2];
            else
                max_store_comb = max_store;
        end
        S_CONV32: begin
            if(cnt == 15)
                max_store_comb = max[2];
            else
                max_store_comb = max_store;
        end
        default: max_store_comb = max_store;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        max_store <= 0;
    else 
        max_store <= max_store_comb;
end

//==============================================//
//     GET OFFSET(FOR CONVOLUTION CONTROL)      //
//==============================================//

assign index_offsetPlusTwo = index_offset + 2;
assign row_offsetPlusOne = row_offset + 1;
assign row_offset32PlusOne = row_offset32 + 1;
assign index_offsetPlusOne = index_offset + 1;

always @(*) begin
    case(cur_state)
        S_CONV: begin
            if(cnt == 8)
                index_offset_comb = index_offsetPlusTwo;
            else
                index_offset_comb = 0;
        end
        S_CONV8: begin
            if(index_offset == 2 && cnt == 19)
                index_offset_comb = 0;
            else if(cnt == 19)
                index_offset_comb = index_offsetPlusTwo;
            else
                index_offset_comb = index_offset;
        end
        S_CONV16: begin
            if(index_offset == 10 && cnt == 19)
                index_offset_comb = 0;
            else if(cnt == 19)
                index_offset_comb = index_offsetPlusTwo;
            else
                index_offset_comb = index_offset;
        end
        S_CONV32: begin
            if(cnt == 19 && index_offset == 2 && row_offset32[1:0] == 3)
                index_offset_comb = 0;
            else if(cnt == 19 && index_offset == 6 && row_offset32[1:0] != 3)
                index_offset_comb = 0;
            else if(cnt == 19)
                index_offset_comb = index_offsetPlusTwo;
            else
                index_offset_comb = index_offset;
        end
        S_DECONV: begin
            if(cnt == 2)
                index_offset_comb = index_offsetPlusOne;
            else
                index_offset_comb = 0;
        end
        S_DECONV8: begin
            if(index_offset == 11 && cnt == 19)
                index_offset_comb = 0;
            else if(cnt == 19)
                index_offset_comb = index_offsetPlusOne;
            else
                index_offset_comb = index_offset;
        end
        S_DECONV16: begin
            if(index_offset == 19 && cnt == 19)
                index_offset_comb = 0;
            else if(cnt == 19)
                index_offset_comb = index_offsetPlusOne;
            else
                index_offset_comb = index_offset;
        end
        S_DECONV32: begin
            if(row_offset32 == 2 && cnt == 19 && index_offset == 19)
                index_offset_comb = 0;
            else if(index_offset == 11 && cnt == 19 && row_offset32 != 2)
                index_offset_comb = 4;
            else if(cnt == 19)
                index_offset_comb = index_offsetPlusOne;
            else
                index_offset_comb = index_offset;
        end
        default: index_offset_comb = 0;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        index_offset <= 0;
    else 
        index_offset <= index_offset_comb;
end

always @(*) begin
    case(cur_state)
        S_CONV8: begin
            if(cnt == 19 && index_offset == 2)
                row_offset_comb = row_offsetPlusOne;
            else
                row_offset_comb = row_offset;
        end
        S_CONV16: begin
            if(cnt == 19 && index_offset == 10)
                row_offset_comb = row_offsetPlusOne;
            else
                row_offset_comb = row_offset;  
        end
        S_CONV32: begin
            if(cnt == 19 && index_offset == 2 && row_offset32[1:0] == 3)
                row_offset_comb = row_offsetPlusOne;
            else
                row_offset_comb = row_offset;
        end
        S_DECONV8: begin
            if(cnt == 19 && index_offset == 11)
                row_offset_comb = row_offset + row + 1;
            else if(cnt == 19)
                row_offset_comb = row_offset + row;
            else if(row_offset > 0 && row < 4)
                row_offset_comb = row_offset - 1;
            else
                row_offset_comb = row_offset;  
        end
        S_DECONV16: begin
            if(cnt == 19 && index_offset == 19)
                row_offset_comb = row_offset + row + 1;
            else if(cnt == 19)
                row_offset_comb = row_offset + row;
            else if(cnt[0] && row_offset > 0 && row < 4)
                row_offset_comb = row_offset - 1;
            else
                row_offset_comb = row_offset;  
        end
        S_DECONV32: begin
            if(cnt == 19 && index_offset == 19)
                row_offset_comb = row_offset + row + 1;
            else if(cnt == 19)
                row_offset_comb = row_offset + row;
            else if(cnt[0] && row_offset > 0 && row < 4)
                row_offset_comb = row_offset - 1;
            else
                row_offset_comb = row_offset;  
        end
        default: row_offset_comb = 0;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        row_offset <= 0;
    else 
        row_offset <= row_offset_comb;
end

always @(*) begin
    case(cur_state)
        S_CONV32: begin
            if(cnt == 19 && index_offset == 6)
                row_offset32_comb = row_offset32PlusOne;
            else if(cnt == 19 && index_offset == 2 && row_offset32 == 3)
                row_offset32_comb = 0;
            else
                row_offset32_comb = row_offset32;
        end
        S_DECONV32: begin
            if(cnt == 19 && index_offset == 19)
                row_offset32_comb = 0;
            else if(cnt == 19 && index_offset == 11 && row_offset32 != 2)
                row_offset32_comb = row_offset32PlusOne;
            else
                row_offset32_comb = row_offset32;
        end
        default: row_offset32_comb = 0;
    endcase   
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        row_offset32 <= 0;
    else 
        row_offset32 <= row_offset32_comb;
end

assign row_conv8  = cnt + (row_offset << 1);
assign row_conv16 = cnt + (row_offset << 2);
assign row_conv32 = {{cnt[5:1] << 1}, cnt[0]} + (row_offset << 3) + row_offset32;

//==============================================//
//                SHIFT REGISTER                //
//    USED TO READ 16x16 & 32x32 CONVOLUTION    //
//==============================================//

always @(*) begin
    case(cur_state)
        S_CONV16: shift_register1x32_comb = {shift_register1x32[8:31],DoImg[63:56],DoImg[55:48],DoImg[47:40],DoImg[39:32],DoImg[31:24],DoImg[23:16],DoImg[15:8],DoImg[7:0]};
        S_CONV32: shift_register1x32_comb = {shift_register1x32[8:31],DoImg[63:56],DoImg[55:48],DoImg[47:40],DoImg[39:32],DoImg[31:24],DoImg[23:16],DoImg[15:8],DoImg[7:0]};
        default: shift_register1x32_comb = {8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0};
    endcase
end

genvar i;
generate
    for(i=0;i<32;i=i+1) begin
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) 
                shift_register1x32[i] <= 0;
            else 
                shift_register1x32[i] <= shift_register1x32_comb[i];
        end
    end
endgenerate

//==============================================//
//                DECONVOLUTION                 //
//==============================================//

always @(*) begin
    case(cur_state)
        S_DECONV: begin
            if(cnt == 2)
                deconv_comb = mz[10];
            else
                deconv_comb = 0;
        end
        S_DECONV8: begin
            if(cnt == 19)
                deconv_comb = deconv_store; 
            else
                deconv_comb = deconv >> 1;
        end
        S_DECONV16: begin
            if(cnt == 19)
                deconv_comb = deconv_store; 
            else
                deconv_comb = deconv >> 1;
        end
        S_DECONV32: begin
            if(cnt == 19)
                deconv_comb = deconv_store; 
            else
                deconv_comb = deconv >> 1;
        end
        default: deconv_comb = 0;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        deconv <= 0;
    else 
        deconv <= deconv_comb;
end

always @(*) begin
    case(cur_state)
        S_DECONV8: begin
            if(cnt == 4)
                deconv_store_comb = pe[0];
            else if(cnt == 5 && (row_offset + row) >= 1)
                deconv_store_comb = pe[0];
            else if(cnt == 6 && (row_offset + row) >= 2)
                deconv_store_comb = pe[0];
            else if(cnt == 7 && (row_offset + row) >= 3)
                deconv_store_comb = pe[0];
            else if(cnt == 8 && (row_offset + row) >= 4)
                deconv_store_comb = pe[0];
            else
                deconv_store_comb = deconv_store;
        end
        S_DECONV16: begin
            if(cnt == 5)
                deconv_store_comb = pe[0];
            else if(cnt == 7 && (row_offset + row) >= 1)
                deconv_store_comb = pe[0];
            else if(cnt == 9 && (row_offset + row) >= 2)
                deconv_store_comb = pe[0];
            else if(cnt == 11 && (row_offset + row) >= 3)
                deconv_store_comb = pe[0];
            else if(cnt == 13 && (row_offset + row) >= 4)
                deconv_store_comb = pe[0];
            else
                deconv_store_comb = deconv_store;
        end
        S_DECONV32: begin
            if(cnt == 5)
                deconv_store_comb = pe[0];
            else if(cnt == 7 && (row_offset + row) >= 1)
                deconv_store_comb = pe[0];
            else if(cnt == 9 && (row_offset + row) >= 2)
                deconv_store_comb = pe[0];
            else if(cnt == 11 && (row_offset + row) >= 3)
                deconv_store_comb = pe[0];
            else if(cnt == 13 && (row_offset + row) >= 4)
                deconv_store_comb = pe[0];
            else
                deconv_store_comb = deconv_store;
        end
        default: deconv_store_comb = 0;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        deconv_store <= 0;
    else 
        deconv_store <= deconv_store_comb;
end

assign row_deconv8  = (row_offset >= 8)  ? 0 : row_offset;
assign row_deconv16 = (row_offset >= 16) ? 0 : (row_offset << 1) + cnt[0];
assign row_deconv32 = (row_offset >= 32) ? 0 : (row_offset << 2) + cnt[0] + row_offset32;
//assign row_deconv32 = {{cnt[5:1] << 1}, cnt[0]} + (row_offset << 3) + row_offset32;

//==============================================//
//                SHIFT REGISTER                //
//   USED TO READ 16x16 & 32x32 DECONVOLUTION   //
//==============================================//

always @(*) begin
    case(cur_state)
        S_DECONV16: begin
            if((cnt == 1 || cnt == 2) && (row_offset + row) >= 16)
                shift_register1x24_comb = {8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0};
            else if((cnt == 3 || cnt == 4) && (row_offset + row) >= 17)
                shift_register1x24_comb = {8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0};
            else if((cnt == 5 || cnt == 6) && (row_offset + row) >= 18)
                shift_register1x24_comb = {8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0};
            else if((cnt == 7 || cnt == 8) && (row_offset + row) >= 19)
                shift_register1x24_comb = {8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0};
            else if((cnt == 9 || cnt == 10) && (row_offset + row) >= 20)
                shift_register1x24_comb = {8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0};
            else
                shift_register1x24_comb = {8'd0,8'd0,8'd0,8'd0,shift_register1x24[12:19],DoImg[63:56],DoImg[55:48],DoImg[47:40],DoImg[39:32],DoImg[31:24],DoImg[23:16],DoImg[15:8],DoImg[7:0],8'd0,8'd0,8'd0,8'd0};
        end
        S_DECONV32: begin
            if((cnt == 1 || cnt == 2) && (row_offset + row) >= 32)
                shift_register1x24_comb = {8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0};
            else if((cnt == 3 || cnt == 4) && (row_offset + row) >= 33)
                shift_register1x24_comb = {8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0};
            else if((cnt == 5 || cnt == 6) && (row_offset + row) >= 34)
                shift_register1x24_comb = {8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0};
            else if((cnt == 7 || cnt == 8) && (row_offset + row) >= 35)
                shift_register1x24_comb = {8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0};
            else if((cnt == 9 || cnt == 10) && (row_offset + row) >= 36)
                shift_register1x24_comb = {8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0};
            else
                shift_register1x24_comb = {8'd0,8'd0,8'd0,8'd0,shift_register1x24[12:19],DoImg[63:56],DoImg[55:48],DoImg[47:40],DoImg[39:32],DoImg[31:24],DoImg[23:16],DoImg[15:8],DoImg[7:0],8'd0,8'd0,8'd0,8'd0};
        end
        default: shift_register1x24_comb = {8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0};
    endcase
end

genvar i;
generate
    for(i=0;i<24;i=i+1) begin
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) 
                shift_register1x24[i] <= 0;
            else 
                shift_register1x24[i] <= shift_register1x24_comb[i];
        end
    end
endgenerate

always @(*) begin
    case(cur_state)
        S_DECONV8: begin
            if((cnt == 1) && (row_offset + row) >= 8)
                shift_register1x16_comb = {8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0};
            else if((cnt == 2) && (row_offset + row) >= 9)
                shift_register1x16_comb = {8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0};
            else if((cnt == 3) && (row_offset + row) >= 10)
                shift_register1x16_comb = {8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0};
            else if((cnt == 4) && (row_offset + row) >= 11)
                shift_register1x16_comb = {8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0};
            else if((cnt == 5) && (row_offset + row) >= 12)
                shift_register1x16_comb = {8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0};
            else
                shift_register1x16_comb = {8'd0,8'd0,8'd0,8'd0,DoImg[63:56],DoImg[55:48],DoImg[47:40],DoImg[39:32],DoImg[31:24],DoImg[23:16],DoImg[15:8],DoImg[7:0],8'd0,8'd0,8'd0,8'd0};
        end
        default: shift_register1x16_comb = {8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0,8'd0};
    endcase
end

genvar i;
generate
    for(i=0;i<16;i=i+1) begin
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) 
                shift_register1x16[i] <= 0;
            else 
                shift_register1x16[i] <= shift_register1x16_comb[i];
        end
    end
endgenerate

always @(*) begin
    shift_register1x5_comb = {DoKnl[39:32],DoKnl[31:24],DoKnl[23:16],DoKnl[15:8],DoKnl[7:0]};
end

genvar i;
generate
    for(i=0;i<5;i=i+1) begin
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) 
                shift_register1x5[i] <= 0;
            else 
                shift_register1x5[i] <= shift_register1x5_comb[i];
        end
    end
endgenerate

//==============================================//
//                    OUTPUT                    //
//==============================================//

always @(*) begin
    case(cur_state)
        S_CONV: begin
            if(cnt == 8)
                out_valid_comb = 1;
            else
                out_valid_comb = 0;
        end
        S_CONV8: begin
            if(cnt == 19 && row_offset == 2 && index_offset == 0)
                out_valid_comb = 0;
            else
                out_valid_comb = 1;
        end
        S_CONV16: begin
            if(cnt == 19 && row_offset == 6 && index_offset == 0)
                out_valid_comb = 0;
            else
                out_valid_comb = 1;
        end
        S_CONV32: begin
            if(cnt == 19 && row_offset == 14 && index_offset == 0)
                out_valid_comb = 0;
            else
                out_valid_comb = 1;
        end
        S_DECONV: begin
            if(cnt == 2)
                out_valid_comb = 1;
            else
                out_valid_comb = 0;
        end
        S_DECONV8: begin
            if(cnt == 19 && (row + row_offset == 12) && index_offset == 0)
                out_valid_comb = 0;
            else
                out_valid_comb = 1;
        end
        S_DECONV16: begin
            if(cnt == 19 && (row + row_offset == 20) && index_offset == 0)
                out_valid_comb = 0;
            else
                out_valid_comb = 1;
        end
        S_DECONV32: begin
            if(cnt == 19 && (row + row_offset == 36) && index_offset == 0)
                out_valid_comb = 0;
            else
                out_valid_comb = 1;
        end
        default: out_valid_comb = 0;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        out_valid <= 0;
    else
        out_valid <= out_valid_comb;
end


always @(*) begin
    case(cur_state)
        S_CONV: begin
            if(cnt == 8)
                out_value_comb = max[2][0];
            else
                out_value_comb = 0;
        end
        S_CONV8: begin
            if(cnt == 19 && row_offset == 2 && index_offset == 0)
                out_value_comb = 0;
            else if(cnt == 19)
                out_value_comb = max_store[0];
            else
                out_value_comb = pool[1];
        end
        S_CONV16: begin
            if(cnt == 19 && row_offset == 6 && index_offset == 0)
                out_value_comb = 0;
            else if(cnt == 19)
                out_value_comb = max_store[0];
            else
                out_value_comb = pool[1];
        end
        S_CONV32: begin
            if(cnt == 19 && row_offset == 14 && index_offset == 0)
                out_value_comb = 0;
            else if(cnt == 19)
                out_value_comb = max_store[0];
            else
                out_value_comb = pool[1];
        end
        S_DECONV: begin
            if(cnt == 2)
                out_value_comb = mz[10][0];
            else
                out_value_comb = 0;
        end
        S_DECONV8: begin
            if(cnt == 19 && (row + row_offset == 12) && index_offset == 0)
                out_value_comb = 0;
            else if(cnt == 19)
                out_value_comb = deconv_store[0];
            else
                out_value_comb = deconv[1];
        end
        S_DECONV16: begin
            if(cnt == 19 && (row + row_offset == 20) && index_offset == 0)
                out_value_comb = 0;
            else if(cnt == 19)
                out_value_comb = deconv_store[0];
            else
                out_value_comb = deconv[1];
        end
        S_DECONV32: begin
            if(cnt == 19 && (row + row_offset == 36) && index_offset == 0)
                out_value_comb = 0;
            else if(cnt == 19)
                out_value_comb = deconv_store[0];
            else
                out_value_comb = deconv[1];
        end
        default: out_value_comb = 0;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        out_value <= 0;
    else
        out_value <= out_value_comb;
end

//==============================================//
//                     SRAM                     //
//==============================================//  

IMG_2048x64 S0 (
    .A0(aImg[0]),     .A1(aImg[1]),      .A2(aImg[2]),     .A3(aImg[3]),     .A4(aImg[4]),     .A5(aImg[5]),     .A6(aImg[6]),     .A7(aImg[7]),   .A8(aImg[8]),   .A9(aImg[9]),   .A10(aImg[10]),
    .DO0(DoImg[0]),   .DO1(DoImg[1]),    .DO2(DoImg[2]),   .DO3(DoImg[3]),   .DO4(DoImg[4]),   .DO5(DoImg[5]),   .DO6(DoImg[6]),   .DO7(DoImg[7]), 
    .DO8(DoImg[8]),   .DO9(DoImg[9]),    .DO10(DoImg[10]), .DO11(DoImg[11]), .DO12(DoImg[12]), .DO13(DoImg[13]), .DO14(DoImg[14]), .DO15(DoImg[15]),
    .DO16(DoImg[16]), .DO17(DoImg[17]),  .DO18(DoImg[18]), .DO19(DoImg[19]), .DO20(DoImg[20]), .DO21(DoImg[21]), .DO22(DoImg[22]), .DO23(DoImg[23]),  
    .DO24(DoImg[24]), .DO25(DoImg[25]),  .DO26(DoImg[26]), .DO27(DoImg[27]), .DO28(DoImg[28]), .DO29(DoImg[29]), .DO30(DoImg[30]), .DO31(DoImg[31]),  
    .DO32(DoImg[32]), .DO33(DoImg[33]),  .DO34(DoImg[34]), .DO35(DoImg[35]), .DO36(DoImg[36]), .DO37(DoImg[37]), .DO38(DoImg[38]), .DO39(DoImg[39]),   
    .DO40(DoImg[40]), .DO41(DoImg[41]),  .DO42(DoImg[42]), .DO43(DoImg[43]), .DO44(DoImg[44]), .DO45(DoImg[45]), .DO46(DoImg[46]), .DO47(DoImg[47]),  
    .DO48(DoImg[48]), .DO49(DoImg[49]),  .DO50(DoImg[50]), .DO51(DoImg[51]), .DO52(DoImg[52]), .DO53(DoImg[53]), .DO54(DoImg[54]), .DO55(DoImg[55]),  
    .DO56(DoImg[56]), .DO57(DoImg[57]),  .DO58(DoImg[58]), .DO59(DoImg[59]), .DO60(DoImg[60]), .DO61(DoImg[61]), .DO62(DoImg[62]), .DO63(DoImg[63]),
    .DI0(DiImg[0]),   .DI1(DiImg[1]),    .DI2(DiImg[2]),   .DI3(DiImg[3]),   .DI4(DiImg[4]),   .DI5(DiImg[5]),   .DI6(DiImg[6]),   .DI7(DiImg[7]),   
    .DI8(DiImg[8]),   .DI9(DiImg[9]),    .DI10(DiImg[10]), .DI11(DiImg[11]), .DI12(DiImg[12]), .DI13(DiImg[13]), .DI14(DiImg[14]), .DI15(DiImg[15]),   
    .DI16(DiImg[16]), .DI17(DiImg[17]),  .DI18(DiImg[18]), .DI19(DiImg[19]), .DI20(DiImg[20]), .DI21(DiImg[21]), .DI22(DiImg[22]), .DI23(DiImg[23]),   
    .DI24(DiImg[24]), .DI25(DiImg[25]),  .DI26(DiImg[26]), .DI27(DiImg[27]), .DI28(DiImg[28]), .DI29(DiImg[29]), .DI30(DiImg[30]), .DI31(DiImg[31]),   
    .DI32(DiImg[32]), .DI33(DiImg[33]),  .DI34(DiImg[34]), .DI35(DiImg[35]), .DI36(DiImg[36]), .DI37(DiImg[37]), .DI38(DiImg[38]), .DI39(DiImg[39]),   
    .DI40(DiImg[40]), .DI41(DiImg[41]),  .DI42(DiImg[42]), .DI43(DiImg[43]), .DI44(DiImg[44]), .DI45(DiImg[45]), .DI46(DiImg[46]), .DI47(DiImg[47]),  
    .DI48(DiImg[48]), .DI49(DiImg[49]),  .DI50(DiImg[50]), .DI51(DiImg[51]), .DI52(DiImg[52]), .DI53(DiImg[53]), .DI54(DiImg[54]), .DI55(DiImg[55]),   
    .DI56(DiImg[56]), .DI57(DiImg[57]),  .DI58(DiImg[58]), .DI59(DiImg[59]), .DI60(DiImg[60]), .DI61(DiImg[61]), .DI62(DiImg[62]), .DI63(DiImg[63]),
    .CK(clk),         .WEB(writeImg),    .OE(1'b1),        .CS(1'b1)
    );

KNL_80x40 S1 (
    .A0(aKnl[0]),     .A1(aKnl[1]),      .A2(aKnl[2]),     .A3(aKnl[3]),     .A4(aKnl[4]),     .A5(aKnl[5]),     .A6(aKnl[6]),
    .DO0(DoKnl[0]),   .DO1(DoKnl[1]),    .DO2(DoKnl[2]),   .DO3(DoKnl[3]),   .DO4(DoKnl[4]),   .DO5(DoKnl[5]),   .DO6(DoKnl[6]),   .DO7(DoKnl[7]), 
    .DO8(DoKnl[8]),   .DO9(DoKnl[9]),    .DO10(DoKnl[10]), .DO11(DoKnl[11]), .DO12(DoKnl[12]), .DO13(DoKnl[13]), .DO14(DoKnl[14]), .DO15(DoKnl[15]),
    .DO16(DoKnl[16]), .DO17(DoKnl[17]),  .DO18(DoKnl[18]), .DO19(DoKnl[19]), .DO20(DoKnl[20]), .DO21(DoKnl[21]), .DO22(DoKnl[22]), .DO23(DoKnl[23]),  
    .DO24(DoKnl[24]), .DO25(DoKnl[25]),  .DO26(DoKnl[26]), .DO27(DoKnl[27]), .DO28(DoKnl[28]), .DO29(DoKnl[29]), .DO30(DoKnl[30]), .DO31(DoKnl[31]),  
    .DO32(DoKnl[32]), .DO33(DoKnl[33]),  .DO34(DoKnl[34]), .DO35(DoKnl[35]), .DO36(DoKnl[36]), .DO37(DoKnl[37]), .DO38(DoKnl[38]), .DO39(DoKnl[39]),     
    .DI0(DiKnl[0]),   .DI1(DiKnl[1]),    .DI2(DiKnl[2]),   .DI3(DiKnl[3]),   .DI4(DiKnl[4]),   .DI5(DiKnl[5]),   .DI6(DiKnl[6]),   .DI7(DiKnl[7]),   
    .DI8(DiKnl[8]),   .DI9(DiKnl[9]),    .DI10(DiKnl[10]), .DI11(DiKnl[11]), .DI12(DiKnl[12]), .DI13(DiKnl[13]), .DI14(DiKnl[14]), .DI15(DiKnl[15]),   
    .DI16(DiKnl[16]), .DI17(DiKnl[17]),  .DI18(DiKnl[18]), .DI19(DiKnl[19]), .DI20(DiKnl[20]), .DI21(DiKnl[21]), .DI22(DiKnl[22]), .DI23(DiKnl[23]),   
    .DI24(DiKnl[24]), .DI25(DiKnl[25]),  .DI26(DiKnl[26]), .DI27(DiKnl[27]), .DI28(DiKnl[28]), .DI29(DiKnl[29]), .DI30(DiKnl[30]), .DI31(DiKnl[31]),   
    .DI32(DiKnl[32]), .DI33(DiKnl[33]),  .DI34(DiKnl[34]), .DI35(DiKnl[35]), .DI36(DiKnl[36]), .DI37(DiKnl[37]), .DI38(DiKnl[38]), .DI39(DiKnl[39]),
    .CK(clk),         .WEB(writeKnl),    .OE(1'b1),        .CS(1'b1)
    );

endmodule