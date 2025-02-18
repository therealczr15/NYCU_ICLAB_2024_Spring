//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   2023 ICLAB Fall Course
//   Lab03      : BRIDGE
//   Author     : Ting-Yu Chang
//                
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : BRIDGE_encrypted.v
//   Module Name : BRIDGE
//   Release version : v1.0 (Release Date: Sep-2023)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module BRIDGE(
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

//==============================================//
//                Input Signals                 //
//==============================================//
input clk, rst_n;
input in_valid;
input direction;
input [12:0] addr_dram;
input [15:0] addr_sd;

//==============================================//
//                Output Signals                //
//==============================================//
output reg out_valid;
output reg [7:0] out_data;

//==============================================//
//                 DRAM Signals                 //
//==============================================//

// write address channel
output reg [31:0] AW_ADDR;
output reg AW_VALID;
input AW_READY;

// write data channel
output reg W_VALID;
output reg [63:0] W_DATA;
input W_READY;

// write response channel
input B_VALID;
input [1:0] B_RESP;
output reg B_READY;

// read address channel
output reg [31:0] AR_ADDR;
output reg AR_VALID;
input AR_READY;

// read data channel
input [63:0] R_DATA;
input R_VALID;
input [1:0] R_RESP;
output reg R_READY;

//==============================================//
//                  SD Signals                  //
//==============================================//
input MISO;
output reg MOSI;

//==============================================//
//       Parameter & Integer Declaration        //
//==============================================//
parameter   S_IDLE                      =   4'd0;
parameter   S_INPUT                     =   4'd1;
parameter   S_SD_COMMAND                =   4'd2;
parameter   S_SD_WAIT_RESPONSE          =   4'd3;
parameter   S_SD_WAIT_DATA              =   4'd4; 
parameter   S_SD_READ                   =   4'd5;
parameter   S_DRAM_AW                   =   4'd6;
parameter   S_DRAM_W                    =   4'd7;
parameter   S_DRAM_B                    =   4'd8;
parameter   S_DRAM_AR                   =   4'd9;
parameter   S_DRAM_R                    =   4'd10;
parameter   S_SD_WRITE                  =   4'd11;
parameter   S_SD_WAIT_DATA_RESPONSE     =   4'd12;
parameter   S_SD_BUSY                   =   4'd13;
parameter   S_OUT                       =   4'd14;

//==============================================//
//           Reg & Wire Declaration             //
//==============================================//
reg direction_reg, direction_comb;
reg [12:0] addr_dram_reg, addr_dram_comb;
reg [31:0] addr_sd_reg, addr_sd_comb;

reg [3:0] cur_state, nxt_state;
reg [6:0] cnt, cnt_comb;

wire out_valid_comb;
reg [7:0] out_data_comb;

wire [31:0] AW_ADDR_comb;
wire AW_VALID_comb;
wire W_VALID_comb;
wire [63:0] W_DATA_comb;
wire B_READY_comb;
wire [31:0] AR_ADDR_comb;
wire AR_VALID_comb;
wire R_READY_comb;

reg [0:63]w_data, w_data_comb;

reg [0:63] R_DATA_reg, R_DATA_comb;
wire [0:47] command;
wire [0:87] MOSI_data;
reg MOSI_comb;

//==============================================//
//                  Design                      //
//==============================================//

//==============================================//
//                   Input FF                   //
//==============================================//
always @(*) begin
    if(in_valid)
        direction_comb = direction;
    else
        direction_comb = direction_reg;
end

always @(*) begin
    if(in_valid)
        addr_dram_comb = addr_dram;
    else
        addr_dram_comb = addr_dram_reg;
end

always @(*) begin
    if(in_valid)
        addr_sd_comb = addr_sd;
    else
        addr_sd_comb = addr_sd_reg;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        direction_reg <= 0;
    else 
        direction_reg <= direction_comb;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        addr_dram_reg <= 0;
    else 
        addr_dram_reg <= addr_dram_comb;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        addr_sd_reg <= 0;
    else 
        addr_sd_reg <= addr_sd_comb;
end

//==============================================//
//                     FSM                      //
//==============================================//
always @(*) begin
    case(cur_state)
        S_IDLE: begin
            if(in_valid)
                nxt_state = S_INPUT;
            else
                nxt_state = S_IDLE;
        end
        S_INPUT: begin
            if(direction_reg)
                nxt_state = S_SD_COMMAND;
            else
                nxt_state = S_DRAM_AR;
        end
        S_SD_COMMAND: begin
            if(cnt == 47)
                nxt_state = S_SD_WAIT_RESPONSE;
            else
                nxt_state = S_SD_COMMAND;
        end
        S_SD_WAIT_RESPONSE: begin
            if(cnt == 7 && !MISO)
                nxt_state = S_SD_WAIT_DATA;
            else
                nxt_state = S_SD_WAIT_RESPONSE;
        end
        S_SD_WAIT_DATA: begin
            if(cnt == 7 && direction_reg && !MISO)
                nxt_state = S_SD_READ;
            else if(cnt == 6 && !direction_reg)
                nxt_state = S_SD_WRITE;
            else
                nxt_state = S_SD_WAIT_DATA;
        end
        S_SD_READ: begin
            if(cnt == 79)
                nxt_state = S_DRAM_AW;
            else
                nxt_state = S_SD_READ;
        end
        S_DRAM_AW: begin
            if(AW_VALID && AW_READY) 
                nxt_state = S_DRAM_W;
            else
                nxt_state = S_DRAM_AW;
        end
        S_DRAM_W: begin
            if(W_VALID && W_READY)
                nxt_state = S_DRAM_B;
            else
                nxt_state = S_DRAM_W;
        end
        S_DRAM_B: begin
            if(B_VALID && B_READY)
                nxt_state = S_OUT;
            else
                nxt_state = S_DRAM_B;
        end
        S_DRAM_AR: begin
            if(AR_VALID && AR_READY)
                nxt_state = S_DRAM_R;
            else
                nxt_state = S_DRAM_AR;
        end
        S_DRAM_R: begin
            if(R_VALID && R_READY)
                nxt_state = S_SD_COMMAND;
            else
                nxt_state = S_DRAM_R;
        end
        S_SD_WRITE: begin
            if(cnt == 87)
                nxt_state = S_SD_WAIT_DATA_RESPONSE;
            else
                nxt_state = S_SD_WRITE;
        end
        S_SD_WAIT_DATA_RESPONSE: begin
            if(cnt == 7 && MISO)
                nxt_state = S_SD_BUSY;
            else
                nxt_state = S_SD_WAIT_DATA_RESPONSE;
        end
        S_SD_BUSY: begin
            if(MISO)
                nxt_state = S_OUT;
            else
                nxt_state = S_SD_BUSY;
        end
        S_OUT: begin
            if(cnt == 7)
                nxt_state = S_IDLE;
            else
                nxt_state = S_OUT;
        end
        default: nxt_state = S_IDLE;
    endcase    
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        cur_state <= 0;
    else 
        cur_state <= nxt_state;
end

//==============================================//
//                   Counter                    //
//==============================================//
always @(*) begin
    case(cur_state)
        S_IDLE: begin
            cnt_comb = 0;
        end
        S_INPUT: begin
            cnt_comb = 0;
        end
        S_SD_COMMAND: begin
            if(cnt == 47)
                cnt_comb = 0;
            else
                cnt_comb = cnt + 1;
        end
        S_SD_WAIT_RESPONSE: begin
            if(cnt == 7 && !MISO)
                cnt_comb = 0;
            else if(!MISO)
                cnt_comb = cnt + 1;
            else
                cnt_comb = 0;
        end
        S_SD_WAIT_DATA: begin
            if(direction_reg) begin
                if(cnt == 7 && !MISO)
                    cnt_comb = 0;
                else if(cnt < 7 && MISO)
                    cnt_comb = cnt + 1;
                else
                    cnt_comb = 0;
            end else begin
                if(cnt == 6)
                    cnt_comb = 0;
                else if(cnt < 6)
                    cnt_comb = cnt + 1;
                else
                    cnt_comb = 0;
            end
        end
        S_SD_READ: begin
            if(cnt == 79)
                cnt_comb = 0;
            else
                cnt_comb = cnt + 1;
        end
        S_DRAM_AW: begin
            cnt_comb = 0;
        end
        S_DRAM_W: begin
            cnt_comb = 0;
        end
        S_DRAM_B: begin
            cnt_comb = 0;
        end
        S_DRAM_AR: begin
            cnt_comb = 0;
        end
        S_DRAM_R: begin
            cnt_comb = 0;
        end
        S_SD_WRITE: begin
            if(cnt == 87)
                cnt_comb = 0;
            else
                cnt_comb = cnt + 1;
        end
        S_SD_WAIT_DATA_RESPONSE: begin
            case(cnt)
                0: begin
                    if(!MISO)
                        cnt_comb = 1;
                    else
                        cnt_comb = 0;
                end 
                1: begin
                    if(!MISO)
                        cnt_comb = 2;
                    else
                        cnt_comb = 0;
                end
                2: begin
                    if(!MISO)
                        cnt_comb = 3;
                    else
                        cnt_comb = 0;
                end
                3: begin
                    if(!MISO)
                        cnt_comb = 4;
                    else
                        cnt_comb = 0;
                end
                4: begin
                    if(!MISO)
                        cnt_comb = 5;
                    else
                        cnt_comb = 0;
                end
                5: begin
                    if(MISO)
                        cnt_comb = 6;
                    else
                        cnt_comb = 0;
                end
                6: begin
                    if(!MISO)
                        cnt_comb = 7;
                    else
                        cnt_comb = 0;
                end
                7: cnt_comb = 0;
                default cnt_comb = 0;
            endcase
        end
        S_SD_BUSY: begin
            cnt_comb = 0;
        end
        S_OUT: begin
            if(cnt == 7)
                cnt_comb = 0;
            else
                cnt_comb = cnt + 1;            
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
//                    Output                    //
//==============================================//
assign out_valid_comb = (cur_state == S_OUT);
always @(*) begin
    if(cur_state == S_OUT)
        case(cnt)
            0: out_data_comb = (direction_reg) ? {w_data[0:7]}   : {R_DATA_reg[0:7]};
            1: out_data_comb = (direction_reg) ? {w_data[8:15]}  : {R_DATA_reg[8:15]};
            2: out_data_comb = (direction_reg) ? {w_data[16:23]} : {R_DATA_reg[16:23]};
            3: out_data_comb = (direction_reg) ? {w_data[24:31]} : {R_DATA_reg[24:31]};
            4: out_data_comb = (direction_reg) ? {w_data[32:39]} : {R_DATA_reg[32:39]};
            5: out_data_comb = (direction_reg) ? {w_data[40:47]} : {R_DATA_reg[40:47]};
            6: out_data_comb = (direction_reg) ? {w_data[48:55]} : {R_DATA_reg[48:55]};
            7: out_data_comb = (direction_reg) ? {w_data[56:63]} : {R_DATA_reg[56:63]};
            default out_data_comb = 0;
        endcase
    else
        out_data_comb = 0;
end


always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        out_valid <= 0;
    else 
        out_valid <= out_valid_comb;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        out_data <= 0;
    else 
        out_data <= out_data_comb;
end

//==============================================//
//               Output for Dram                //
//            Write Address Channel             //
//==============================================//
assign AW_VALID_comb = (nxt_state == S_DRAM_AW);
assign AW_ADDR_comb  = (nxt_state == S_DRAM_AW) ? addr_dram_reg : 0;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        AW_VALID <= 0;
    else 
        AW_VALID <= AW_VALID_comb;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        AW_ADDR <= 0;
    else 
        AW_ADDR <= AW_ADDR_comb;
end

//==============================================//
//               Output for Dram                //
//              Write Data Channel              //
//==============================================//
assign W_VALID_comb = (nxt_state == S_DRAM_W);
assign W_DATA_comb  = (nxt_state == S_DRAM_W) ? w_data : 0;

always @(*) begin
    if(cur_state == S_SD_READ && cnt < 64) 
        w_data_comb = {w_data[1:63],MISO};
    else
        w_data_comb = w_data;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        w_data <= 0;
    else 
        w_data <= w_data_comb;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        W_VALID <= 0;
    else 
        W_VALID <= W_VALID_comb;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        W_DATA <= 0;
    else 
        W_DATA <= W_DATA_comb;
end

//==============================================//
//               Output for Dram                //
//            Write Response Channel            //
//==============================================//
assign B_READY_comb = (nxt_state == S_DRAM_W || nxt_state == S_DRAM_B);

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        B_READY <= 0;
    else 
        B_READY <= B_READY_comb;
end

//==============================================//
//               Output for Dram                //
//             Read Address Channel             //
//==============================================//
assign AR_VALID_comb = (nxt_state == S_DRAM_AR);
assign AR_ADDR_comb = (nxt_state == S_DRAM_AR) ? addr_dram_reg : 0;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        AR_VALID <= 0;
    else 
        AR_VALID <= AR_VALID_comb;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        AR_ADDR <= 0;
    else 
        AR_ADDR <= AR_ADDR_comb;
end

//==============================================//
//               Output for Dram                //
//              Read Data Channel               //
//==============================================//
assign R_READY_comb = (nxt_state == S_DRAM_R);
assign R_DATA_comb = (cur_state == S_DRAM_R) ? R_DATA : R_DATA_reg;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        R_READY <= 0;
    else 
        R_READY <= R_READY_comb;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        R_DATA_reg <= 0;
    else 
        R_DATA_reg <= R_DATA_comb;
end

//==============================================//
//                Output for SD                 //
//==============================================//
assign command = direction_reg ? {2'b01,6'd17,addr_sd_reg,CRC7({2'b01,6'd17,addr_sd_reg}),1'b1} : {2'b01,6'd24,addr_sd_reg,CRC7({2'b01,6'd24,addr_sd_reg}),1'b1};
assign MOSI_data = {8'hfe,R_DATA_reg,CRC16_CCITT({R_DATA_reg})} ;

always @(*) begin
    case(cur_state)
        S_IDLE: MOSI_comb = 1;
        S_INPUT: MOSI_comb = 1;
        S_SD_COMMAND: MOSI_comb = command[cnt];
        S_SD_WAIT_RESPONSE: MOSI_comb = 1;
        S_SD_WAIT_DATA: MOSI_comb = 1;
        S_SD_READ: MOSI_comb = 1;
        S_DRAM_AW: MOSI_comb = 1;
        S_DRAM_W: MOSI_comb = 1;
        S_DRAM_B: MOSI_comb = 1;
        S_DRAM_AR: MOSI_comb = 1;
        S_DRAM_R: MOSI_comb = 1;
        S_SD_WRITE: MOSI_comb = MOSI_data[cnt];
        S_SD_WAIT_DATA_RESPONSE: MOSI_comb = 1;
        S_SD_BUSY: MOSI_comb = 1;
        S_OUT: MOSI_comb = 1;
        default MOSI_comb = 1;
    endcase    
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        MOSI <= 1;
    else 
        MOSI <= MOSI_comb;
end

//==============================================//
//             Example for function             //
//==============================================//
function automatic [15:0] CRC16_CCITT;
    // Try to implement CRC-16-CCITT function by yourself.
    input [63:0] data;  // 64-bit data input
    reg [15:0] crc;
    integer i;
    reg data_in, data_out;
    parameter polynomial = 16'h1021;  // x^12 + x^5 + 1

    begin
        crc = 16'd0;
        for (i = 0; i < 64; i = i + 1) begin
            data_in = data[63-i];
            data_out = crc[15];
            crc = crc << 1;  // Shift the CRC
            if (data_in ^ data_out) begin
                crc = crc ^ polynomial;
            end
        end
        CRC16_CCITT = crc;
    end
endfunction

function automatic [6:0] CRC7;  // Return 7-bit result
    input [39:0] data;  // 40-bit data input
    reg [6:0] crc;
    integer i;
    reg data_in, data_out;
    parameter polynomial = 7'h9;  // x^7 + x^3 + 1

    begin
        crc = 7'd0;
        for (i = 0; i < 40; i = i + 1) begin
            data_in = data[39-i];
            data_out = crc[6];
            crc = crc << 1;  // Shift the CRC
            if (data_in ^ data_out) begin
                crc = crc ^ polynomial;
            end
        end
        CRC7 = crc;
    end
endfunction



endmodule