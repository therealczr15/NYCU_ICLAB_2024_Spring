module bridge(input clk, INF.bridge_inf inf);


//==============================================//
//                  PARAMETER                   //
//==============================================//

typedef enum logic [3:0]{
    S_IDLE,
    S_AR,
    S_R,
    S_CHECK_EXPIRE,
    S_SUB,
    S_CHECK_ING1,
    S_CHECK_ING2,
    S_ADD,
    S_CHECK_OVERFLOW,
    S_AW,
    S_W,
    S_B
} state_t;

//==============================================//
//               PORT DECLARATION               //
//==============================================//

// FSM
state_t cur_state, nxt_state;

// AXI4 AR_CHANNEL
logic        ar_valid_comb;
logic [16:0] ar_addr_comb;

// AXI4 R_CHANNEL
logic        r_ready_comb;

// CHECK EXPIRE
logic [8:0]  today;

// CHECK_OVERFLOW
logic [1:0]  cnt, cnt_comb, cntPlusOne;
logic signed [12:0] add1, add1_comb, add2, add2_comb;
logic signed [13:0] add_ans;
logic        overflow, overflow_comb;
logic        ing_flag;

// AXI4 AW_CHANNEL
logic        aw_valid_comb;
logic [16:0] aw_addr_comb;

// AXI4 W_CHANNEL
logic        w_valid_comb;
logic [63:0] w_data_comb;

// AXI4 W_CHANNEL
logic        b_ready_comb;

// OUTPUT TO BERVERAGE
logic [1:0]  err_msg;
logic        busy;
logic        c_out_valid_comb;

//==============================================//
//                     FSM                      //
//==============================================//

always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) 
        cur_state <= S_IDLE;
    else 
        cur_state <= nxt_state;
end

always_comb begin
    case(cur_state)
        S_IDLE: begin
            if(inf.C_in_valid)
                nxt_state = S_AR;
            else
                nxt_state = cur_state;
        end
        S_AR: begin
            if(inf.AR_READY)
                nxt_state = S_R;
            else
                nxt_state = cur_state;
        end
        S_R: begin
            if(inf.R_VALID) begin
                if(inf.C_data_w[38])
                    nxt_state = S_ADD;
                else
                    nxt_state = S_CHECK_EXPIRE;
            end else
                nxt_state = cur_state;
        end
        S_CHECK_EXPIRE: begin
            if(today > {inf.W_DATA[35:32],inf.W_DATA[4:0]} | inf.C_data_w[39])
                nxt_state = S_IDLE;
            else
                nxt_state = S_SUB;
        end
        S_ADD: begin
            if(&cnt)
                nxt_state = S_CHECK_OVERFLOW;
            else
                nxt_state = cur_state;
        end
        S_CHECK_OVERFLOW: nxt_state = S_AW;
        S_AW: begin
            if(inf.AW_READY)
                nxt_state = S_W;
            else
                nxt_state = cur_state;
        end
        S_W: begin
            if(inf.W_READY)
                nxt_state = S_B;
            else
                nxt_state = cur_state;
        end
        S_B: begin
            if(inf.B_VALID)
                nxt_state = S_IDLE;
            else
                nxt_state = cur_state;
        end
        S_SUB: begin
            if(ing_flag)
                nxt_state = S_IDLE;
            else if(&cnt)
                nxt_state = S_CHECK_ING1;
            else
                nxt_state = cur_state;
        end
        S_CHECK_ING1: begin
            if(ing_flag)
                nxt_state = S_IDLE;
            else 
                nxt_state = S_CHECK_ING2;
        end
        S_CHECK_ING2: begin
            if(ing_flag)
                nxt_state = S_IDLE;
            else 
                nxt_state = S_AW;
        end
        default: nxt_state = cur_state;
    endcase
end

//==============================================//
//               AXI4 AR_CHANNEL                //
//==============================================//

// AR_VALID
always_comb begin
    case(cur_state)
        S_IDLE: begin
            if(inf.C_in_valid)
                ar_valid_comb = 1;
            else
                ar_valid_comb = 0;
        end
        S_AR: begin
            if(inf.AR_READY)
                ar_valid_comb = 0;
            else
                ar_valid_comb = 1;
        end
        default: ar_valid_comb = 0;
    endcase
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) 
        inf.AR_VALID <= 0;
    else 
        inf.AR_VALID <= ar_valid_comb;
end

// AR_ADDR
always_comb begin
    case(cur_state)
        S_IDLE: begin
            if(inf.C_in_valid)
                ar_addr_comb = {6'h20,inf.C_addr,3'd0};
            else
                ar_addr_comb = 0;
        end
        S_AR: begin
            if(inf.AR_READY)
                ar_addr_comb = 0;
            else
                ar_addr_comb = inf.AR_ADDR;
        end
        default: ar_addr_comb = 0;
    endcase
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) 
        inf.AR_ADDR <= 0;
    else 
        inf.AR_ADDR <= ar_addr_comb;
end

//==============================================//
//                AXI4 R_CHANNEL                //
//==============================================//

// R_READY
always_comb begin
    case(cur_state)
        S_AR: begin
            if(inf.AR_READY)
                r_ready_comb = 1;
            else
                r_ready_comb = 0;
        end
        S_R: begin
            if(inf.R_VALID)
                r_ready_comb = 0;
            else
                r_ready_comb = 1;
        end
        default: r_ready_comb = 0;
    endcase
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) 
        inf.R_READY <= 0;
    else 
        inf.R_READY <= r_ready_comb;
end

//==============================================//
//                 CHECK_EXPIRE                 //
//==============================================//

always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) 
        today <= 0;
    else 
        today <= {inf.C_data_w[35:32],inf.C_data_w[4:0]};
end

//==============================================//
//                CHECK_OVERFLOW                //
//==============================================//

// cnt
assign cntPlusOne = cnt + 1;

always_comb begin
    case(cur_state)
        S_ADD: begin
            if(inf.C_r_wb)
                cnt_comb = cntPlusOne;
            else
                cnt_comb = cnt;
        end
        S_SUB: cnt_comb = cntPlusOne;
        default: cnt_comb = 0;
    endcase
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) 
        cnt <= 0;
    else 
        cnt <= cnt_comb;
end

// add
assign add_ans = add1 + add2;

always_comb begin
    case(cnt)
        0: add1_comb = {1'd0,inf.W_DATA[63:52]};
        1: add1_comb = {1'd0,inf.W_DATA[51:40]};
        2: add1_comb = {1'd0,inf.W_DATA[31:20]};
        3: add1_comb = {1'd0,inf.W_DATA[19:8]};
    endcase
end

always_comb begin
    case(cur_state)
        S_ADD: begin
            case(cnt)
                0: add2_comb = {1'd0,inf.C_data_w[63:52]};
                1: add2_comb = {1'd0,inf.C_data_w[51:40]};
                2: add2_comb = {1'd0,inf.C_data_w[31:20]};
                3: add2_comb = {1'd0,inf.C_data_w[19:8]};
            endcase
        end
        S_SUB: begin
            case(cnt)
                0: add2_comb = {inf.C_data_w[63],inf.C_data_w[63:52]};
                1: add2_comb = {inf.C_data_w[51],inf.C_data_w[51:40]};
                2: add2_comb = {inf.C_data_w[31],inf.C_data_w[31:20]};
                3: add2_comb = {inf.C_data_w[19],inf.C_data_w[19:8]};
            endcase
        end
        default: add2_comb = 0;
    endcase
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) 
        add1 <= 0;
    else 
        add1 <= add1_comb;
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) 
        add2 <= 0;
    else 
        add2 <= add2_comb;
end

// ing_flag
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) 
        ing_flag <= 0;
    else 
        ing_flag <= add_ans[12];
end

// overflow
always_comb begin
    case(cur_state)
        S_ADD: begin
            if(cnt > 0)
                overflow_comb = (add_ans[12] | overflow);
            else
                overflow_comb = 0;
        end
        S_CHECK_OVERFLOW: overflow_comb = (add_ans[12] | overflow);
        default: overflow_comb = 0;
    endcase
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) 
        overflow <= 0;
    else 
        overflow <= overflow_comb;
end

//==============================================//
//               AXI4 AW_CHANNEL                //
//==============================================//

// AW_VALID
always_comb begin
    case(cur_state)
        S_CHECK_OVERFLOW: aw_valid_comb = 1;
        S_CHECK_ING2: begin
            if(ing_flag)
                aw_valid_comb = 0;
            else
                aw_valid_comb = 1;
        end
        S_AW: begin
            if(inf.AW_READY)
                aw_valid_comb = 0;
            else
                aw_valid_comb = 1;
        end
        default: aw_valid_comb = 0;
    endcase
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) 
        inf.AW_VALID <= 0;
    else 
        inf.AW_VALID <= aw_valid_comb;
end

// AW_ADDR
always_comb begin
    case(cur_state)
        S_CHECK_OVERFLOW: aw_addr_comb = {6'h20,inf.C_addr,3'd0};
        S_CHECK_ING2: begin
            if(ing_flag)
                aw_addr_comb = 0;
            else
                aw_addr_comb = {6'h20,inf.C_addr,3'd0};
        end
        S_AW: begin
            if(inf.AW_READY)
                aw_addr_comb = 0;
            else
                aw_addr_comb = inf.AW_ADDR;
        end
        default: aw_addr_comb = 0;
    endcase
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) 
        inf.AW_ADDR <= 0;
    else 
        inf.AW_ADDR <= aw_addr_comb;
end

//==============================================//
//               AXI4 W_CHANNEL                 //
//==============================================//

// W_VALID
always_comb begin
    case(cur_state)
        S_AW: begin
            if(inf.AW_READY)
                w_valid_comb = 1;
            else
                w_valid_comb = 0;
        end
        S_W: begin
            if(inf.W_READY)
                w_valid_comb = 0;
            else
                w_valid_comb = 1;
        end
        default: w_valid_comb = 0;
    endcase
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) 
        inf.W_VALID <= 0;
    else 
        inf.W_VALID <= w_valid_comb;
end


// W_DATA
/*
[63:52] Black Tea
[51:40] Green Tea
[39:32] Month
[31:20] Milk
[19:8]  Pineapple Juice
[7:0]   Day
*/

// [63:52] Black Tea
always_comb begin
    case(cur_state)
        S_R: begin
            if(inf.R_VALID)
                w_data_comb[63:52] = inf.R_DATA[63:52];
            else
                w_data_comb[63:52] = inf.W_DATA[63:52];
        end
        S_ADD: begin
            if(cnt == 1) begin
                if(add_ans[12])
                    w_data_comb[63:52] = 4095;
                else
                    w_data_comb[63:52] = add_ans[11:0];
            end else
                w_data_comb[63:52] = inf.W_DATA[63:52];
        end
        S_SUB: begin
            if(cnt == 1) 
                w_data_comb[63:52] = add_ans[11:0];
            else
                w_data_comb[63:52] = inf.W_DATA[63:52];
        end
        default: w_data_comb[63:52] = inf.W_DATA[63:52];
    endcase
end

// [51:40] Green Tea
always_comb begin
    case(cur_state)
        S_R: begin
            if(inf.R_VALID)
                w_data_comb[51:40] = inf.R_DATA[51:40];
            else
                w_data_comb[51:40] = inf.W_DATA[51:40];
        end
        S_ADD: begin
            if(cnt == 2) begin
                if(add_ans[12])
                    w_data_comb[51:40] = 4095;
                else
                    w_data_comb[51:40] = add_ans[11:0];
            end else
                w_data_comb[51:40] = inf.W_DATA[51:40];
        end
        S_SUB: begin
            if(cnt == 2) 
                w_data_comb[51:40] = add_ans[11:0];
            else
                w_data_comb[51:40] = inf.W_DATA[51:40];
        end
        default: w_data_comb[51:40] = inf.W_DATA[51:40];
    endcase
end

// [31:20] Milk
always_comb begin
    case(cur_state)
        S_R: begin
            if(inf.R_VALID)
                w_data_comb[31:20] = inf.R_DATA[31:20];
            else
                w_data_comb[31:20] = inf.W_DATA[31:20];
        end
        S_ADD: begin
            if(cnt == 3) begin
                if(add_ans[12])
                    w_data_comb[31:20] = 4095;
                else
                    w_data_comb[31:20] = add_ans[11:0];
            end else
                w_data_comb[31:20] = inf.W_DATA[31:20];
        end
        S_SUB: begin
            if(cnt == 3) 
                w_data_comb[31:20] = add_ans[11:0];
            else
                w_data_comb[31:20] = inf.W_DATA[31:20];
        end
        default: w_data_comb[31:20] = inf.W_DATA[31:20];
    endcase
end

// [19:8] Pineapple Juice
always_comb begin
    case(cur_state)
        S_R: begin
            if(inf.R_VALID)
                w_data_comb[19:8] = inf.R_DATA[19:8];
            else
                w_data_comb[19:8] = inf.W_DATA[19:8];
        end
        S_CHECK_OVERFLOW: begin
            if(add_ans[12])
                w_data_comb[19:8] = 4095;
            else
                w_data_comb[19:8] = add_ans[11:0];
        end
        S_CHECK_ING1: w_data_comb[19:8] = add_ans[11:0];
        default: w_data_comb[19:8] = inf.W_DATA[19:8];
    endcase
end

// [39:32] Month
always_comb begin
    case(cur_state)
        S_R: begin
            if(inf.R_VALID)
                w_data_comb[39:32] = inf.R_DATA[39:32];
            else
                w_data_comb[39:32] = inf.W_DATA[39:32];
        end
        S_ADD: w_data_comb[39:32] = {4'd0,inf.C_data_w[35:32]};
        default: w_data_comb[39:32] = inf.W_DATA[39:32];
    endcase
end

// [7:0] Day
always_comb begin
    case(cur_state)
        S_R: begin
            if(inf.R_VALID)
                w_data_comb[7:0] = inf.R_DATA[7:0];
            else
                w_data_comb[7:0] = inf.W_DATA[7:0];
        end
        S_ADD: w_data_comb[7:0] = {3'd0,inf.C_data_w[4:0]};
        default: w_data_comb[7:0] = inf.W_DATA[7:0];
    endcase
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) 
        inf.W_DATA <= 0;
    else 
        inf.W_DATA <= w_data_comb;
end

//==============================================//
//               AXI4 B_CHANNEL                 //
//==============================================//

// B_READY
always_comb begin
    case(cur_state)
        S_W: begin
            if(inf.W_READY)
                b_ready_comb = 1;
            else
                b_ready_comb = 0;
        end
        S_B: begin
            if(inf.B_VALID)
                b_ready_comb = 0;
            else
                b_ready_comb = 1;
        end
        default: b_ready_comb = 0;
    endcase
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) 
        inf.B_READY <= 0;
    else 
        inf.B_READY <= b_ready_comb;
end

//==============================================//
//             OUTPUT TO BERVERAGE              //
//==============================================//

// C_data_r
assign inf.C_data_r[63:3] = 0;

always_comb begin
    case(cur_state)
        S_CHECK_OVERFLOW: busy = 1;
        S_CHECK_ING2: begin
            if(ing_flag)
                busy = 0;
            else
                busy = 1;
        end
        S_AW: busy = 1;
        S_W: busy = 1;
        S_B: begin
            if(inf.B_VALID)
                busy = 0;
            else
                busy = 1;
        end
        default: busy = 0;
    endcase
end

always_comb begin
    case(cur_state)
        S_CHECK_EXPIRE: begin
            if(today > {inf.W_DATA[35:32],inf.W_DATA[4:0]})
                err_msg = 1;
            else
                err_msg = 0;
        end
        S_CHECK_OVERFLOW: begin
            if(add_ans[12] | overflow)
                err_msg = 3;
            else
                err_msg = 0;
        end
        S_SUB: begin
            if(ing_flag)
                err_msg = 2;
            else
                err_msg = 0;
        end
        S_CHECK_ING1: begin
            if(ing_flag)
                err_msg = 2;
            else
                err_msg = 0;
        end
        S_CHECK_ING2: begin
            if(ing_flag)
                err_msg = 2;
            else
                err_msg = 0;
        end
        default: err_msg = 0;
    endcase
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) 
        inf.C_data_r[2:0] <= 0;
    else 
        inf.C_data_r[2:0] <= {busy,err_msg};
end

// C_out_valid
always_comb begin
    case(cur_state)
        S_CHECK_EXPIRE: begin
            if(today > {inf.W_DATA[35:32],inf.W_DATA[4:0]} | inf.C_data_w[39])
                c_out_valid_comb = 1;
            else
                c_out_valid_comb = 0;
        end
        S_CHECK_OVERFLOW: c_out_valid_comb = 1;
        S_SUB: begin
            if(ing_flag)
                c_out_valid_comb = 1;
            else
                c_out_valid_comb = 0;
        end
        S_CHECK_ING1: begin
            if(ing_flag)
                c_out_valid_comb = 1;
            else
                c_out_valid_comb = 0;
        end
        S_CHECK_ING2: c_out_valid_comb = 1;
        default: c_out_valid_comb = 0;
    endcase
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) 
        inf.C_out_valid <= 0;
    else 
        inf.C_out_valid <= c_out_valid_comb;
end

endmodule