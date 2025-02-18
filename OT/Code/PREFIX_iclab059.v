module PREFIX (
    // input port
    clk,
    rst_n,
    in_valid,
    opt,
    in_data,
    // output port
    out_valid,
    out
);

input clk;
input rst_n;
input in_valid;
input opt;
input [4:0] in_data;
output reg out_valid;
output reg signed [94:0] out;

integer  i;

parameter S_IDLE    = 0;
parameter S_INPUT   = 1;
parameter S_PREFIX  = 2;
parameter S_PRE_OUT = 3;
parameter S_INFIX   = 4;
parameter S_POP     = 5;
parameter S_IN_OUT  = 6;

reg opt_ff;

reg signed [4:0] input_stack [0:18], input_stack_comb [0:18];
reg signed [40:0] operand_stack[0:9], operand_stack_comb[0:9];

reg signed [4:0] rpe [0:18], rpe_comb [0:18];
reg [4:0] operator_stack[0:8], operator_stack_comb[0:8];

reg [3:0] operator_length, operator_length_comb;

reg [3:0] cur_state, nxt_state;
reg [4:0] cnt, cnt_comb;

reg out_valid_comb;
reg signed [94:0] out_comb;

// fsm
always @(*) begin
    case(cur_state)
        S_IDLE: begin
         if(in_valid)
            nxt_state = S_INPUT;
         else
            nxt_state = cur_state;
        end
        S_INPUT: begin
            if(cnt == 18 && opt_ff)
                nxt_state = S_INFIX;
            else if(cnt == 18 && !opt_ff)
                nxt_state = S_PREFIX;
            else
                nxt_state = cur_state;
        end
        S_PREFIX: begin
            if(cnt == 18)
                nxt_state = S_PRE_OUT;
            else
                nxt_state = cur_state;
        end
        S_PRE_OUT: nxt_state = S_IDLE;
        S_INFIX: begin
            if(cnt == 18)
                nxt_state = S_POP;
            else
                nxt_state = cur_state;
        end
        S_POP: begin
            if(operator_length == 1)
                nxt_state = S_IN_OUT;
            else
                nxt_state = cur_state;
        end
        S_IN_OUT: nxt_state = S_IDLE;
        default: nxt_state = cur_state;
    endcase 
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        cur_state <= S_IDLE;
    else
        cur_state <= nxt_state;
end

// cnt
always @(*) begin
    case(cur_state)
        S_IDLE: begin
            if(in_valid)
                cnt_comb = cnt + 1;
            else
                cnt_comb = 0;
        end
        S_INPUT: begin
            if(cnt == 18)
                cnt_comb = 0;
            else 
                cnt_comb = cnt + 1;
        end
        S_PREFIX: cnt_comb = cnt + 1;
        S_INFIX: begin
            if(input_stack[18][4]) begin
                if(operator_length == 0)
                    cnt_comb = cnt + 1;
                else if(!input_stack[18][1] & operator_stack[0][1])
                    cnt_comb = cnt;
                else
                    cnt_comb = cnt + 1;
            end else
                cnt_comb = cnt + 1;
        end
        default: cnt_comb = cnt;
    endcase 
    
end

always @(posedge clk or negedge rst_n) begin
   if(!rst_n)
        cnt <= 0;
   else
        cnt <= cnt_comb;
end

// input stack
always @(*) begin
    case(cur_state)
        S_IDLE: begin
            if(in_valid)
                input_stack_comb = {input_stack[1:18],in_data};
            else
                input_stack_comb = input_stack;
        end
        S_INPUT: input_stack_comb = {input_stack[1:18],in_data};
        S_PREFIX: input_stack_comb = {0,input_stack[0:17]};
        S_INFIX: begin
            if(input_stack[18][4]) begin
                if(operator_length == 0)
                    input_stack_comb = {0,input_stack[0:17]};
                else if(!input_stack[18][1] & operator_stack[0][1])
                    input_stack_comb = input_stack;
                else
                    input_stack_comb = {0,input_stack[0:17]};
            end else
                input_stack_comb = {0,input_stack[0:17]};
        end
        default: input_stack_comb = input_stack;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for(i=0;i<19;i=i+1)
            input_stack[i] <= 0;
    end else
        input_stack <= input_stack_comb;
end

// opt_ff
always @(posedge clk or negedge rst_n) begin
   if(!rst_n)
      opt_ff <= 0;
   else if(in_valid && cnt == 0)
      opt_ff <= opt;
end

// operand stack
always @(*) begin
    case(cur_state)
        S_PREFIX: begin
            if(input_stack[18][4]) begin
                case(input_stack[18][1:0])
                    0: begin
                        operand_stack_comb[0] = operand_stack[0] + operand_stack[1];
                        operand_stack_comb[1] = operand_stack[2];
                        operand_stack_comb[2] = operand_stack[3];
                        operand_stack_comb[3] = operand_stack[4];
                        operand_stack_comb[4] = operand_stack[5];
                        operand_stack_comb[5] = operand_stack[6];
                        operand_stack_comb[6] = operand_stack[7];
                        operand_stack_comb[7] = operand_stack[8];
                        operand_stack_comb[8] = operand_stack[9];
                        operand_stack_comb[9] = 0;
                    end
                    1: begin
                        operand_stack_comb[0] = operand_stack[0] - operand_stack[1];
                        operand_stack_comb[1] = operand_stack[2];
                        operand_stack_comb[2] = operand_stack[3];
                        operand_stack_comb[3] = operand_stack[4];
                        operand_stack_comb[4] = operand_stack[5];
                        operand_stack_comb[5] = operand_stack[6];
                        operand_stack_comb[6] = operand_stack[7];
                        operand_stack_comb[7] = operand_stack[8];
                        operand_stack_comb[8] = operand_stack[9];
                        operand_stack_comb[9] = 0;
                    end
                    2: begin
                        operand_stack_comb[0] = operand_stack[0] * operand_stack[1];
                        operand_stack_comb[1] = operand_stack[2];
                        operand_stack_comb[2] = operand_stack[3];
                        operand_stack_comb[3] = operand_stack[4];
                        operand_stack_comb[4] = operand_stack[5];
                        operand_stack_comb[5] = operand_stack[6];
                        operand_stack_comb[6] = operand_stack[7];
                        operand_stack_comb[7] = operand_stack[8];
                        operand_stack_comb[8] = operand_stack[9];
                        operand_stack_comb[9] = 0;
                    end
                    3: begin
                        operand_stack_comb[0] = operand_stack[0] / operand_stack[1];
                        operand_stack_comb[1] = operand_stack[2];
                        operand_stack_comb[2] = operand_stack[3];
                        operand_stack_comb[3] = operand_stack[4];
                        operand_stack_comb[4] = operand_stack[5];
                        operand_stack_comb[5] = operand_stack[6];
                        operand_stack_comb[6] = operand_stack[7];
                        operand_stack_comb[7] = operand_stack[8];
                        operand_stack_comb[8] = operand_stack[9];
                        operand_stack_comb[9] = 0;
                    end
                endcase
            end else
                operand_stack_comb = {input_stack[18],operand_stack[0:8]};
        end
        default: operand_stack_comb = operand_stack;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for(i=0;i<10;i=i+1)
            operand_stack[i] <= 0;
    end else
        operand_stack <= operand_stack_comb;
end

// operator stack
always @(*) begin
    case(cur_state)
        S_INFIX: begin
            if(input_stack[18][4]) begin
                if(operator_length == 0)
                    operator_stack_comb = {input_stack[18],operator_stack[0:7]};
                else if(!input_stack[18][1] & operator_stack[0][1])
                    operator_stack_comb = {operator_stack[1:8],0};
                else
                    operator_stack_comb = {input_stack[18],operator_stack[0:7]};
            end else
                operator_stack_comb = operator_stack;
        end
        S_POP: operator_stack_comb = {operator_stack[1:8],0};
        default: operator_stack_comb = operator_stack;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for(i=0;i<9;i=i+1)
            operator_stack[i] <= 0;
    end else
        operator_stack <= operator_stack_comb;
end

// rpe
always @(*) begin
    case(cur_state)
        S_INFIX: begin
            if(input_stack[18][4]) begin
                if(operator_length == 0)
                    rpe_comb = rpe;
                else if(!input_stack[18][1] & operator_stack[0][1])
                    rpe_comb = {operator_stack[0],rpe[0:17]};
                else
                    rpe_comb = rpe;

            end else
                rpe_comb = {input_stack[18],rpe[0:17]};
        end
        S_POP: rpe_comb = {operator_stack[0],rpe[0:17]};
        default: rpe_comb = rpe;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for(i=0;i<19;i=i+1)
            rpe[i] <= 0;
    end else
        rpe <= rpe_comb;
end


// operator length
always @(*) begin
    case(cur_state)
        S_INFIX: begin
            if(input_stack[18][4]) begin
                if(operator_length == 0)
                    operator_length_comb = 1;
                else if(!input_stack[18][1] & operator_stack[0][1])
                    operator_length_comb = operator_length - 1;
                else
                    operator_length_comb = operator_length + 1;
            end else
                operator_length_comb = operator_length;
        end
        S_POP: operator_length_comb = operator_length - 1;
        default: operator_length_comb = operator_length;
    endcase
end

always @(posedge clk or negedge rst_n) begin
   if(!rst_n)
      operator_length <= 0;
   else
      operator_length <= operator_length_comb;
end

// output
always @(*) begin
    if(cur_state == S_PRE_OUT)
        out_comb = {{54{operand_stack[0][40]}}, operand_stack[0]};
    else if(cur_state == S_IN_OUT)
        out_comb = {rpe[18],rpe[17],rpe[16],rpe[15],rpe[14],rpe[13],rpe[12],rpe[11],rpe[10],rpe[9],rpe[8],rpe[7],rpe[6],rpe[5],rpe[4],rpe[3],rpe[2],rpe[1],rpe[0]};
    else
        out_comb = 0;
end

always @(posedge clk or negedge rst_n) begin
   if(!rst_n)
      out <= 0;
   else
      out <= out_comb;
end

always @(*) begin
    if(cur_state == S_PRE_OUT)
        out_valid_comb = 1;
    else if(cur_state == S_IN_OUT)
        out_valid_comb = 1;
    else
        out_valid_comb = 0;
end

always @(posedge clk or negedge rst_n) begin
   if(!rst_n)
      out_valid <= 0;
   else
      out_valid <= out_valid_comb;
end

endmodule