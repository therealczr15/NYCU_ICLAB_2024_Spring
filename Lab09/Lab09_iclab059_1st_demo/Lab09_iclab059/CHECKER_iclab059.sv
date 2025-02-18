/*
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
NYCU Institute of Electronic
2024 Spring IC Design Laboratory 
Lab09: SystemVerilog Coverage & Assertion
File Name   : CHECKER.sv
Module Name : CHECKER
Release version : v1.0 (Release Date: Apr-2024)
Author : Jui-Huang Tsai (erictsai.ee12@nycu.edu.tw)
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
*/

`include "Usertype_BEV.sv"
module Checker(input clk, INF.CHECKER inf);
import usertype::*;

//==============================================//
//                   COVERAGE                   //
//==============================================//

class BEV;
    Bev_Type bev_type;
    Bev_Size bev_size;
endclass

BEV bev_info = new();

Action golden_act;

ING ing;

always_comb begin

    if(inf.sel_action_valid)
        golden_act = inf.D.d_act[0];

    if(inf.type_valid)
        bev_info.bev_type = inf.D.d_type[0];

    if(inf.size_valid)
        bev_info.bev_size = inf.D.d_size[0];

    if(inf.box_sup_valid)
        ing = inf.D.d_ing[0];

end


// 1. Each case of Beverage_Type should be select at least 100 times.

covergroup Spec1 @(posedge clk iff(inf.type_valid));
    option.per_instance = 1;
    option.at_least = 100;
    coverpoint bev_info.bev_type{
        bins b_bev_type [] = {[Black_Tea:Super_Pineapple_Milk_Tea]};
    }
endgroup

// 2.  Each case of Bererage_Size should be select at least 100 times.

covergroup Spec2 @(posedge clk iff(inf.size_valid));
    option.per_instance = 1;
    option.at_least = 100;
    coverpoint bev_info.bev_size{
        bins b_bev_size [] = {[L:S]};
    }
endgroup


// 3.  Create a cross bin for the SPEC1 and SPEC2. Each combination should be selected at least 100 times. 
// (Black Tea, Milk Tea, Extra Milk Tea, Green Tea, Green Milk Tea, Pineapple Juice, Super Pineapple Tea, Super Pineapple Tea) x (L, M, S)

covergroup Spec3 @(posedge clk iff(inf.size_valid));
    option.per_instance = 1;
    option.at_least = 100;
    cross bev_info.bev_type, bev_info.bev_size;
endgroup

// 4.  Output signal inf.err_msg should be No_Err, No_Exp, No_Ing and Ing_OF, each at least 20 times. (Sample the value when inf.out_valid is high)

covergroup Spec4 @(posedge clk iff(inf.out_valid));
    option.per_instance = 1;
    option.at_least = 20;
    coverpoint inf.err_msg{
        bins b_err_msg [] = {[No_Err:Ing_OF]};
    }
endgroup

// 5.  Create the transitions bin for the inf.D.act[0] signal from [0:2] to [0:2]. Each transition should be hit at least 200 times. (sample the value at posedge clk iff inf.sel_action_valid)

covergroup Spec5 @(posedge clk iff(inf.sel_action_valid));
    option.per_instance = 1;
    option.at_least = 200;
    coverpoint golden_act{
        bins b_act [] = ([Make_drink:Check_Valid_Date] => [Make_drink:Check_Valid_Date]);
    }
endgroup

// 6.  Create a covergroup for material of supply action with auto_bin_max = 32, and each bin have to hit at least one time.

covergroup Spec6 @(posedge clk iff(inf.sel_action_valid));
    option.per_instance = 1;
    option.at_least = 1;
    coverpoint ing{
        option.auto_bin_max = 32;
    }
endgroup

// Create instances of Spec1, Spec2, Spec3, Spec4, Spec5, and Spec6
// Spec1_2_3 cov_inst_1_2_3 = new();

Spec1 conv_inst_1 = new();
Spec2 conv_inst_2 = new();
Spec3 conv_inst_3 = new();
Spec4 conv_inst_4 = new();
Spec5 conv_inst_5 = new();
Spec6 conv_inst_6 = new();

//==============================================//
//                  ASSERTION                   //
//==============================================//

// 1. All outputs signals (including BEV.sv and bridge.sv) should be zero after reset.

logic check_rst;
assign check_rst = (inf.out_valid === 'b0) && (inf.err_msg === 'b0) && (inf.complete === 'b0) &&
                   (inf.C_addr === 'b0) && (inf.C_data_w === 'b0) && (inf.C_in_valid === 'b0) && (inf.C_r_wb === 'b0) &&
                   (inf.C_out_valid === 'b0) && (inf.C_data_r === 'b0) &&
                   (inf.AR_VALID === 'b0) && (inf.AR_ADDR === 'b0) && 
                   (inf.R_READY === 'b0) && 
                   (inf.AW_VALID === 'b0) && (inf.AW_ADDR === 'b0) && 
                   (inf.W_VALID === 'b0) && (inf.W_DATA === 'b0) && 
                   (inf.B_READY === 'b0);

always @(negedge inf.rst_n) begin
    @(posedge inf.rst_n)
    assert_1: assert (check_rst)
    else $fatal(0, "Assertion 1 is violated");
end

// 2.  Latency should be less than 1000 cycles for each operation.

logic check_make;
assign check_make = (golden_act === Make_drink && inf.box_no_valid === 1'b1);

logic check_supply;
assign check_supply = (golden_act === Supply && inf.box_sup_valid === 1'b1);

logic check_check;
assign check_check = (golden_act === Check_Valid_Date && inf.box_no_valid === 1'b1);

assert_2_1: assert property(over_1)
else $fatal(0, "Assertion 2 is violated");

property over_1;
    @(negedge clk) check_make |=> ##[1:1000] inf.out_valid;
endproperty: over_1

assert_2_2: assert property(over_2)
else $fatal(0, "Assertion 2 is violated");


property over_2;
    @(negedge clk) check_supply |=> ##[1:1000] inf.out_valid;
endproperty: over_2

assert_2_3: assert property(over_3)
else $fatal(0, "Assertion 2 is violated");

property over_3;
    @(negedge clk) check_check |=> ##[1:1000] inf.out_valid;
endproperty: over_3

// 3. If out_valid does not pull up, complete should be 0.

assert_3: assert property(complete)
else $fatal(0, "Assertion 3 is violated");

property complete;
    @(negedge clk) inf.complete |-> inf.err_msg === 'b0;
endproperty: complete

// 4. Next input valid will be valid 1-4 cycles after previous input valid fall.

logic [2:0] cnt_box_sup;
always @(negedge clk) begin
    cnt_box_sup = 0;
    if(inf.box_sup_valid === 1'b1) begin
        cnt_box_sup = 0;
        while(cnt_box_sup !== 4) begin
            if(inf.box_sup_valid === 1'b1) begin
                cnt_box_sup = cnt_box_sup + 1;
            end
            @(negedge clk);
        end
        cnt_box_sup = 0;
    end
end

assert_4_1: assert property(md_sel_nxt)
else $fatal(0, "Assertion 4 is violated");

property md_sel_nxt;
    @(posedge clk) (inf.sel_action_valid && golden_act === Make_drink) |-> ##[1:4] inf.type_valid;
endproperty: md_sel_nxt

assert_4_2: assert property(su_sel_nxt)
else $fatal(0, "Assertion 4 is violated");

property su_sel_nxt;
    @(posedge clk) (inf.sel_action_valid && golden_act === Supply) |-> ##[1:4] inf.date_valid;
endproperty: su_sel_nxt

assert_4_3: assert property(cd_sel_nxt)
else $fatal(0, "Assertion 4 is violated");

property cd_sel_nxt;
    @(posedge clk) (inf.sel_action_valid && golden_act === Check_Valid_Date) |-> ##[1:4] inf.date_valid;
endproperty: cd_sel_nxt

assert_4_4: assert property(type_nxt)
else $fatal(0, "Assertion 4 is violated");

property type_nxt;
    @(posedge clk) inf.type_valid |-> ##[1:4] inf.size_valid;
endproperty: type_nxt

assert_4_5: assert property(size_nxt)
else $fatal(0, "Assertion 4 is violated");

property size_nxt;
    @(posedge clk) inf.size_valid |-> ##[1:4] inf.date_valid;
endproperty: size_nxt

assert_4_6: assert property(date_nxt)
else $fatal(0, "Assertion 4 is violated");

property date_nxt;
    @(posedge clk) inf.date_valid |-> ##[1:4] inf.box_no_valid;
endproperty: date_nxt

assert_4_7: assert property(box_no_nxt)
else $fatal(0, "Assertion 4 is violated");

property box_no_nxt;
    @(posedge clk) (inf.box_no_valid && golden_act == Supply) |-> ##[1:4] inf.box_sup_valid;
endproperty: box_no_nxt

assert_4_8: assert property(box_sup_nxt)
else $fatal(0, "Assertion 4 is violated");

property box_sup_nxt;
    @(posedge clk) (inf.box_sup_valid && cnt_box_sup !== 3) |-> ##[1:4] inf.box_sup_valid;
endproperty: box_sup_nxt

// 5. All input valid signals won't overlap with each other. 
logic all_valid;
logic [2:0] valid_count;
assign all_valid   = inf.sel_action_valid | inf.type_valid | inf.size_valid | inf.date_valid | inf.box_no_valid | inf.box_sup_valid;
assign valid_count = inf.sel_action_valid + inf.type_valid + inf.size_valid + inf.date_valid + inf.box_no_valid + inf.box_sup_valid;

always @(posedge clk) begin
    assert_5: assert(valid_count <= 1)
    else $fatal(0, "Assertion 5 is violated");
end

// 6. Out_valid can only be high for exactly one cycle.

assert_6: assert property(out_for_one)
else $fatal(0, "Assertion 6 is violated");

property out_for_one;
    @(negedge clk) inf.out_valid |=> !inf.out_valid;
endproperty: out_for_one

// 7. Next operation will be valid 1-4 cycles after out_valid fall.

assert_7: assert property(nxt_op)
else $fatal(0, "Assertion 7 is violated");

property nxt_op;
    @(negedge clk) inf.out_valid |-> ##[2:5] inf.sel_action_valid;
endproperty: nxt_op

// 8. The input date from pattern should adhere to the real calendar. (ex: 2/29, 3/0, 4/31, 13/1 are illegal cases)

logic false_date;
always_comb begin
    if(inf.date_valid) begin
        case(inf.D.d_date[0].M)
            1, 3, 5, 7, 8, 10, 12: begin
                if(inf.D.d_date[0].D > 31 || inf.D.d_date[0].D < 1)
                    false_date = 1;
                else
                    false_date = 0;
            end
            2: begin
                if(inf.D.d_date[0].D > 28 || inf.D.d_date[0].D < 1)
                    false_date = 1;
                else
                    false_date = 0;
            end
            4, 6, 9, 11: begin
                if(inf.D.d_date[0].D > 30 || inf.D.d_date[0].D < 1)
                    false_date = 1;
                else
                    false_date = 0;
            end
            default: false_date = 1;
        endcase
    end else
        false_date = 0;
end

assert_8: assert property(real_date)
else $fatal(0, "Assertion 8 is violated");

property real_date;
    @(posedge clk) inf.date_valid |-> !false_date;
endproperty: real_date

// 9. C_in_valid can only be high for one cycle and can't be pulled high again before C_out_valid

integer c_valid_cnt;
always @(negedge clk) begin
    if(inf.C_in_valid === 1'b1) begin
        c_valid_cnt = 0;
        while(inf.C_out_valid !== 1'b1) begin
            if(inf.C_in_valid === 1'b1) begin
                c_valid_cnt = c_valid_cnt + 1;
            end
            @(negedge clk);
        end
        c_valid_cnt = 0;
    end
end

assert_9: assert property(c_valid_for_one)
else $fatal(0, "Assertion 9 is violated");

property c_valid_for_one;
    @(negedge clk) inf.C_out_valid |-> (c_valid_cnt == 1);
endproperty: c_valid_for_one

endmodule
