module BEV(input clk, INF.BEV_inf inf);
import usertype::*;
// This file contains the definition of several state machines used in the BEV (Beverage) System RTL design.
// The state machines are defined using SystemVerilog enumerated types.
// The state machines are:
// - state_t: used to represent the overall state of the BEV system
//
// Each enumerated type defines a set of named states that the corresponding process can be in.

//==============================================//
//               PORT DECLARATION               //
//==============================================//

// COUNTER
logic [1:0] cnt, cnt_comb;

// BEVERAGE
logic signed [8:0] black_tea, green_tea, milk, pineapple_juice;
logic signed [11:0] bt, gt, mi, pj;

// OUTPUT TO BRIDGE
logic        ready, ready_comb;
logic [7:0]  c_addr_comb;
logic [63:0] c_data_w_comb;
logic        c_in_valid_comb;
logic        c_r_wb_comb;

// OUTPUT

logic [1:0] err_msg_comb;
logic       complete_comb;
logic       out_valid_comb;

//==============================================//
//                   COUNTER                    //
//==============================================//

always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) 
        cnt <= 0;
    else 
        cnt <= cnt_comb;
end

always_comb begin
    if(inf.box_sup_valid)
        cnt_comb = cnt + 1;
    else
        cnt_comb = cnt;
end

//==============================================//
//                   BEVERAGE                   //
//==============================================//

// BLACK TEA
always_comb begin
    case(inf.C_data_w[7:5])
        Black_Tea: begin
            case(inf.C_data_w[37:36])
                L: black_tea = -240;
                M: black_tea = -180;
                S: black_tea = -120;
                default: black_tea = 0;
            endcase
        end            
        Milk_Tea: begin
            case(inf.C_data_w[37:36])
                L: black_tea = -180;
                M: black_tea = -135;
                S: black_tea = -90;
                default: black_tea = 0;
            endcase
        end              
        Extra_Milk_Tea: begin
            case(inf.C_data_w[37:36])
                L: black_tea = -120;
                M: black_tea = -90;
                S: black_tea = -60;
                default: black_tea = 0;
            endcase
        end        
        Green_Tea: black_tea = 0;           
        Green_Milk_Tea: black_tea = 0;
        Pineapple_Juice: black_tea = 0;
        Super_Pineapple_Tea: begin
            case(inf.C_data_w[37:36])
                L: black_tea = -120;
                M: black_tea = -90;
                S: black_tea = -60;
                default: black_tea = 0;
            endcase
        end
        Super_Pineapple_Milk_Tea: begin
            case(inf.C_data_w[37:36])
                L: black_tea = -120;
                M: black_tea = -90;
                S: black_tea = -60;
                default: black_tea = 0;
            endcase
        end
        default: black_tea = 0;
    endcase
end

// GREEN TEA
always_comb begin
    case(inf.C_data_w[7:5])
        Black_Tea: green_tea = 0;
        Milk_Tea: green_tea = 0; 
        Extra_Milk_Tea: green_tea = 0;
        Green_Tea: begin
            case(inf.C_data_w[37:36])
                L: green_tea = -240;
                M: green_tea = -180;
                S: green_tea = -120;
                default: green_tea = 0;
            endcase
        end          
        Green_Milk_Tea: begin
            case(inf.C_data_w[37:36])
                L: green_tea = -120;
                M: green_tea = -90;
                S: green_tea = -60;
                default: green_tea = 0;
            endcase
        end
        Pineapple_Juice: green_tea = 0;
        Super_Pineapple_Tea: green_tea = 0;
        Super_Pineapple_Milk_Tea: green_tea = 0;
        default: green_tea = 0;
    endcase
end

// MILK
always_comb begin
    case(inf.C_data_w[7:5])
        Black_Tea: milk = 0;
        Milk_Tea: begin
            case(inf.C_data_w[37:36])
                L: milk = -60;
                M: milk = -45;
                S: milk = -30;
                default: milk = 0;
            endcase
        end              
        Extra_Milk_Tea: begin
            case(inf.C_data_w[37:36])
                L: milk = -120;
                M: milk = -90;
                S: milk = -60;
                default: milk = 0;
            endcase
        end        
        Green_Tea: milk = 0;        
        Green_Milk_Tea: begin
            case(inf.C_data_w[37:36])
                L: milk = -120;
                M: milk = -90;
                S: milk = -60;
                default: milk = 0;
            endcase
        end
        Pineapple_Juice: milk = 0;
        Super_Pineapple_Tea: milk = 0;
        Super_Pineapple_Milk_Tea: begin
            case(inf.C_data_w[37:36])
                L: milk = -60;
                M: milk = -45;
                S: milk = -30;
                default: milk = 0;
            endcase
        end
        default: milk = 0;
    endcase
end

// PINEAPPLE JUICE
always_comb begin
    case(inf.C_data_w[7:5])
        Black_Tea: pineapple_juice = 0;
        Milk_Tea: pineapple_juice = 0;     
        Extra_Milk_Tea: pineapple_juice = 0;
        Green_Tea: pineapple_juice = 0;     
        Green_Milk_Tea: pineapple_juice = 0;
        Pineapple_Juice: begin
            case(inf.C_data_w[37:36])
                L: pineapple_juice = -240;
                M: pineapple_juice = -180;
                S: pineapple_juice = -120;
                default: pineapple_juice = 0;
            endcase
        end
        Super_Pineapple_Tea: begin
            case(inf.C_data_w[37:36])
                L: pineapple_juice = -120;
                M: pineapple_juice = -90;
                S: pineapple_juice = -60;
                default: pineapple_juice = 0;
            endcase
        end
        Super_Pineapple_Milk_Tea: begin
            case(inf.C_data_w[37:36])
                L: pineapple_juice = -60;
                M: pineapple_juice = -45;
                S: pineapple_juice = -30;
                default: pineapple_juice = 0;
            endcase
        end
        default: pineapple_juice = 0;
    endcase
end

//==============================================//
//               OUTPUT TO BRIDGE               //
//==============================================//

// ready
always_comb begin
    if(ready)
        ready_comb = ~inf.C_in_valid;
    else
        ready_comb = inf.box_no_valid;
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) 
        ready <= 0;
    else 
        ready <= ready_comb;
end


// C_r_wb
always_comb begin
    if(inf.C_r_wb) begin
        c_r_wb_comb = ~inf.C_out_valid;
    end else
        c_r_wb_comb = &cnt & inf.box_sup_valid;
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) 
        inf.C_r_wb <= 0;
    else 
        inf.C_r_wb <= c_r_wb_comb;
end


// C_in_valid
always_comb begin
    c_in_valid_comb = ready_comb & ~inf.C_data_r[2];
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) 
        inf.C_in_valid <= 0;
    else 
        inf.C_in_valid <= c_in_valid_comb;
end

// C_data_w
/*
[63:52] Black Tea
[51:40] Green Tea
[39:38] Action
[37:36] Size
[35:32] Month
[31:20] Milk
[19:8]  Pineapple Juice
[7:5]   Type
[4:0]   Day
*/

// [63:52] Black Tea
always_comb begin
    case(inf.C_data_w[39:38])
        0: c_data_w_comb[63:52] = {black_tea[8],black_tea,2'd0};
        1: begin
            if(inf.box_sup_valid)
                c_data_w_comb[63:52] = inf.C_data_w[51:40];
            else
                c_data_w_comb[63:52] = inf.C_data_w[63:52];
        end
        default: c_data_w_comb[63:52] = inf.C_data_w[63:52];
    endcase
end

// [51:40] Green Tea
always_comb begin
    case(inf.C_data_w[39:38])
        0: c_data_w_comb[51:40] = {green_tea[8],green_tea,2'd0};
        1: begin
            if(inf.box_sup_valid)
                c_data_w_comb[51:40] = inf.C_data_w[31:20];
            else
                c_data_w_comb[51:40] = inf.C_data_w[51:40];
        end
        default: c_data_w_comb[51:40] = inf.C_data_w[51:40];
    endcase
end

// [31:20] Milk
always_comb begin
    case(inf.C_data_w[39:38])
        0: c_data_w_comb[31:20] = {milk[8],milk,2'd0};
        1: begin
            if(inf.box_sup_valid)
                c_data_w_comb[31:20] = inf.C_data_w[19:8];
            else
                c_data_w_comb[31:20] = inf.C_data_w[31:20];
        end
        default: c_data_w_comb[31:20] = inf.C_data_w[31:20];
    endcase
end

// [19:8] Pineapple Juice
always_comb begin
    case(inf.C_data_w[39:38])
        0: c_data_w_comb[19:8] = {pineapple_juice[8],pineapple_juice,2'd0};
        1: begin
            if(inf.box_sup_valid)
                c_data_w_comb[19:8] = inf.D.d_ing[0];
            else
                c_data_w_comb[19:8] = inf.C_data_w[19:8];
        end
        default: c_data_w_comb[19:8] = inf.C_data_w[19:8];
    endcase
end

// [39:38] Action
always_comb begin
    if(inf.sel_action_valid)
        c_data_w_comb[39:38] = inf.D.d_act[0];
    else
        c_data_w_comb[39:38] = inf.C_data_w[39:38];
end

// [7:5] Type
always_comb begin
    if(inf.type_valid)
        c_data_w_comb[7:5] = inf.D.d_type[0];
    else
        c_data_w_comb[7:5] = inf.C_data_w[7:5];
end

// [37:36] Size
always_comb begin
    if(inf.size_valid)
        c_data_w_comb[37:36] = inf.D.d_size[0];
    else
        c_data_w_comb[37:36] = inf.C_data_w[37:36];
end

// [35:32] Month
always_comb begin
    if(inf.date_valid)
        c_data_w_comb[35:32] = inf.D.d_date[0].M;
    else
        c_data_w_comb[35:32] = inf.C_data_w[35:32];
end

// [4:0] Day
always_comb begin
    if(inf.date_valid)
        c_data_w_comb[4:0] = inf.D.d_date[0].D;
    else
        c_data_w_comb[4:0] = inf.C_data_w[4:0];
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) 
        inf.C_data_w <= 0;
    else 
        inf.C_data_w <= c_data_w_comb;
end

// C_addr
always_comb begin
    if(inf.box_no_valid)
        c_addr_comb = inf.D.d_box_no[0];
    else
        c_addr_comb = inf.C_addr;
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) 
        inf.C_addr <= 0;
    else 
        inf.C_addr <= c_addr_comb;
end

//==============================================//
//              OUTPUT TO PATTERN               //
//==============================================//

always_comb begin
    if(inf.C_out_valid)
        out_valid_comb = 1;
    else
        out_valid_comb = 0;
end

always_comb begin
    if(inf.C_out_valid)
        err_msg_comb = inf.C_data_r[1:0];
    else
        err_msg_comb = 0;
end

always_comb begin
    if(inf.C_out_valid)
        complete_comb = (inf.C_data_r[1:0] == 0);
    else
        complete_comb = 0;
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) 
        inf.out_valid <= 0;
    else 
        inf.out_valid <= out_valid_comb;
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) 
        inf.err_msg <= 0;
    else 
        inf.err_msg <= err_msg_comb;
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) 
        inf.complete <= 0;
    else 
        inf.complete <= complete_comb;
end

endmodule
