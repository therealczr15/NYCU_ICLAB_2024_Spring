/*
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
NYCU Institute of Electronic
2024 Spring IC Design Laboratory 
Lab09: SystemVerilog Design and Verification 
File Name   : PATTERN.sv
Module Name : PATTERN
Release version : v1.0 (Release Date: Apr-2024)
Author : Jui-Huang Tsai (erictsai.ee12@nycu.edu.tw)
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
*/

`include "Usertype_BEV.sv"

program automatic PATTERN(input clk, INF.PATTERN inf);
import usertype::*;

//================================================================
// parameters & integer
//================================================================
parameter DRAM_p_r = "../00_TESTBED/DRAM/dram.dat";

parameter PAT_NUM = 3600;
parameter CYCLE_DELAY = 1000;

integer i;
integer i_pat;
integer total_latency, latency;
integer cnt;

Action    _act;
Bev_Type  _type;
Bev_Size  _size;
Date      _date;
Barrel_No _box_no;
ING       _black;
ING       _green;
ING       _milk;
ING       _pineapple;

ING       golden_black;
ING       golden_green;
ING       golden_milk;
ING       golden_pineapple;
Month     golden_month;
Day       golden_day;

ING       s_black;
ING       s_green;
ING       s_milk;
ING       s_pineapple;

logic     golden_complete;
Error_Msg golden_err_msg;

//================================================================
// wire & registers 
//================================================================
logic [7:0] golden_DRAM [((65536+8*256)-1):(65536+0)];  // 256 box

//================================================================
// class random
//================================================================

class random_act;
	randc Action act;
	constraint range{
		act inside {Make_drink, Supply, Check_Valid_Date};
	}
endclass

class random_type;
	randc Bev_Type Type;
	constraint range{
		Type inside {Black_Tea, Milk_Tea, Extra_Milk_Tea, Green_Tea, Green_Milk_Tea, Pineapple_Juice, Super_Pineapple_Tea, Super_Pineapple_Milk_Tea};
	}
endclass

class random_size;
	randc Bev_Size size;
	constraint range{
		size inside {L, M, S};
	}
endclass

class random_date;
	randc Date date;
	constraint range{
		date.M inside {[1:12]};
		(date.M == 1)  -> date.D inside{[1:31]};    
        (date.M == 2)  -> date.D inside{[1:28]};
        (date.M == 3)  -> date.D inside{[1:31]};
        (date.M == 4)  -> date.D inside{[1:30]};    
        (date.M == 5)  -> date.D inside{[1:31]};
        (date.M == 6)  -> date.D inside{[1:30]};
        (date.M == 7)  -> date.D inside{[1:31]};    
        (date.M == 8)  -> date.D inside{[1:31]};
        (date.M == 9)  -> date.D inside{[1:30]};
        (date.M == 10) -> date.D inside{[1:31]};    
        (date.M == 11) -> date.D inside{[1:30]};
        (date.M == 12) -> date.D inside{[1:31]};
	}
endclass

class random_box_no;
	randc Barrel_No box_no;
	constraint range{
		box_no inside {[0:255]};
	}
endclass

class random_ing;
	randc ING ing;
	constraint range{
		ing inside {127,  255,  383,  511,  639,  767,  895,  1023,
		            1151, 1279, 1407, 1535, 1663, 1791, 1919, 2047,
		            2175, 2303, 2431, 2559, 2687, 2815, 2943, 3071,
		            3199, 3327, 3455, 3583, 3711, 3839, 3967, 4095};
	}
endclass

//================================================================
// initial
//================================================================

random_act    r_act       = new();
random_size   r_size      = new();
random_type   r_type      = new();
random_date   r_date      = new();
random_box_no r_box_no    = new();
random_ing    r_black     = new();
random_ing    r_green     = new();
random_ing    r_milk      = new();
random_ing    r_pineapple = new();

initial $readmemh(DRAM_p_r, golden_DRAM);

initial begin
	reset_signal_task;
	for(i_pat = 0; i_pat < PAT_NUM; i_pat = i_pat + 1) begin
        input_task;
        wait_out_valid_task;
        check_ans_task;
        total_latency = total_latency + latency;
        $display("\033[1;32mPASS PATTERN NO.%4d\033[m", i_pat);
    end
    YOU_PASS_task;
end

task reset_signal_task; begin 
    inf.rst_n            = 1'b1;
    inf.sel_action_valid = 'b0;
    inf.type_valid       = 'b0;
    inf.size_valid       = 'b0;
    inf.date_valid       = 'b0;
    inf.box_no_valid     = 'b0;
    inf.box_sup_valid    = 'b0;
    inf.D                = 'bx;

    total_latency = 0;
    cnt = 0;

    #1; inf.rst_n = 1'b0; 
    #29; inf.rst_n = 1'b1;
    
    if(inf.out_valid !== 'b0 || inf.err_msg !== 'b0 || inf.complete !== 'b0) begin
        $display("\033[m---------------------------------------------------------------------------------------\033[m");
        $display("\033[m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                                    \033[m");
        $display("\033[m    ▄▀            ▀▄      ▄▄                                                           \033[m");
        $display("\033[m    █  ▀   ▀       ▀▄▄   █  █      FAIL !                                              \033[m");
        $display("\033[m    █   ▀▀            ▀▀▀   ▀▄  ╭  All output signal should be reset after RESET at %8t PS\033[m", $time);
        $display("\033[m    █  ▄▀▀▀▄                 █  ╭                                                      \033[m");
        $display("\033[m    ▀▄                       █                                                         \033[m");
        $display("\033[m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                                          \033[m");
        $display("\033[m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                                           \033[m");
        $display("\033[m---------------------------------------------------------------------------------------\033[m");
        $finish;
    end

    //@(negedge clk);

end endtask

task input_task; begin

	if(i_pat < 1800)
		_act = Make_drink;
	else begin
		case(i_pat % 9)
			0, 2, 8: _act = Make_drink;
			1, 4, 5: _act = Supply;
			3, 6, 7: _act = Check_Valid_Date;
		endcase
	end

    inf.sel_action_valid = 1'b1;
    inf.D.d_act[0] = _act;

    @(negedge clk);

    inf.sel_action_valid = 1'b0;
    inf.D = 'bx;

    case(_act)
    	Make_drink: make_drink_task;
    	Supply: supply_task;
    	Check_Valid_Date: check_date_task;
    endcase

end endtask 

task make_drink_task; begin

	// type
    case(cnt % 8)
        0: _type = Black_Tea;            
        1: _type = Milk_Tea;               
        2: _type = Extra_Milk_Tea;      
        3: _type = Green_Tea;         
        4: _type = Green_Milk_Tea;          
        5: _type = Pineapple_Juice;         
        6: _type = Super_Pineapple_Tea;     
        7: _type = Super_Pineapple_Milk_Tea;
    endcase
    
	inf.type_valid = 1'b1;
    inf.D.d_type[0] = _type;

    @(negedge clk);

    inf.type_valid = 1'b0;
    inf.D = 'bx;

    // size
    case(cnt % 3)
        0: _size = L;            
        1: _size = M;               
        2: _size = S;      
    endcase

	inf.size_valid = 1'b1;
    inf.D.d_size[0] = _size;

    @(negedge clk);

    inf.size_valid = 1'b0;
    inf.D = 'bx;

    // date
    if(cnt < 20)begin
        _date.M = 1;
        _date.D = 1;
    end else begin
        _date.M = 12;
        _date.D = 31;
    end
        
	inf.date_valid = 1'b1;
    inf.D.d_date[0] = _date;

    @(negedge clk);

    inf.date_valid = 1'b0;
    inf.D = 'bx;

    // box_no
    i = r_box_no.randomize();
    if(cnt < 20)
        _box_no = 0;
    else
    	_box_no = 1;

	inf.box_no_valid = 1'b1;
    inf.D.d_box_no[0] = _box_no;

    @(negedge clk);

    inf.box_no_valid = 1'b0;
    inf.D = 'bx;

    golden_make_drink_task;

    cnt = cnt + 1;

end endtask

task supply_task; begin

    // date
    i = r_date.randomize();
    _date = r_date.date;

    inf.date_valid = 1'b1;
    inf.D.d_date[0] = _date;

    @(negedge clk);

    inf.date_valid = 1'b0;
    inf.D = 'bx;

    // box_no
    i = r_box_no.randomize();
    _box_no = r_box_no.box_no;

    inf.box_no_valid = 1'b1;
    inf.D.d_box_no[0] = _box_no;

    @(negedge clk);

    inf.box_no_valid = 1'b0;
    inf.D = 'bx;

    // black tea
    i = r_black.randomize();
    _black = r_black.ing;

    inf.box_sup_valid = 1'b1;
    inf.D.d_ing[0] = _black;

    @(negedge clk);

    // green tea
    i = r_green.randomize();
    _green = r_green.ing;

    inf.box_sup_valid = 1'b1;
    inf.D.d_ing[0] = _green;

    @(negedge clk);

    // milk
    i = r_milk.randomize();
    _milk = r_milk.ing;

    inf.box_sup_valid = 1'b1;
    inf.D.d_ing[0] = _milk;

    @(negedge clk);

    // pineapple
    i = r_pineapple.randomize();
    _pineapple = r_pineapple.ing;

    inf.box_sup_valid = 1'b1;
    inf.D.d_ing[0] = _pineapple;

    @(negedge clk);

    inf.box_sup_valid = 1'b0;
    inf.D = 'bx;

    golden_supply_task;

end endtask

task check_date_task; begin

    // date
    i = r_date.randomize();
    _date = r_date.date;

    inf.date_valid = 1'b1;
    inf.D.d_date[0] = _date;

    @(negedge clk);

    inf.date_valid = 1'b0;
    inf.D = 'bx;

    // box_no
    i = r_box_no.randomize();
    _box_no = r_box_no.box_no;

    inf.box_no_valid = 1'b1;
    inf.D.d_box_no[0] = _box_no;

    @(negedge clk);

    inf.box_no_valid = 1'b0;
    inf.D = 'bx;

    golden_check_date_task;

end endtask

task golden_make_drink_task; begin
    golden_black     = {golden_DRAM[(65536+8*_box_no)+7], golden_DRAM[(65536+8*_box_no)+6][7:4]};
    golden_green     = {golden_DRAM[(65536+8*_box_no)+6][3:0], golden_DRAM[(65536+8*_box_no)+5]};
    golden_month     = {golden_DRAM[(65536+8*_box_no)+4][3:0]};
    golden_milk      = {golden_DRAM[(65536+8*_box_no)+3], golden_DRAM[(65536+8*_box_no)+2][7:4]};
    golden_pineapple = {golden_DRAM[(65536+8*_box_no)+2][3:0], golden_DRAM[(65536+8*_box_no)+1]};
    golden_day       = {golden_DRAM[(65536+8*_box_no)][4:0]};

    s_black     = 0;
    s_green     = 0;
    s_milk      = 0;
    s_pineapple = 0;

    case(_type)
        Black_Tea: begin
            case(_size)
                L: s_black = 960;
                M: s_black = 720;
                S: s_black = 480;
            endcase
        end
        Milk_Tea: begin
            case(_size)
                L:  begin
                    s_black = 720;
                    s_milk  = 240;
                end
                M: begin
                    s_black = 540;
                    s_milk  = 180;
                end
                S: begin
                    s_black = 360;
                    s_milk  = 120;
                end
            endcase
        end
        Extra_Milk_Tea: begin
            case(_size)
                L:  begin
                    s_black = 480;
                    s_milk  = 480;
                end
                M: begin
                    s_black = 360;
                    s_milk  = 360;
                end
                S: begin
                    s_black = 240;
                    s_milk  = 240;
                end
            endcase
        end
        Green_Tea: begin
            case(_size)
                L: s_green = 960;
                M: s_green = 720;
                S: s_green = 480;
            endcase
        end
        Green_Milk_Tea: begin
            case(_size)
                L:  begin
                    s_green = 480;
                    s_milk  = 480;
                end
                M: begin
                    s_green = 360;
                    s_milk  = 360;
                end
                S: begin
                    s_green = 240;
                    s_milk  = 240;
                end
            endcase
        end
        Pineapple_Juice: begin
            case(_size)
                L: s_pineapple = 960;
                M: s_pineapple = 720;
                S: s_pineapple = 480;
            endcase
        end
        Super_Pineapple_Tea: begin
            case(_size)
                L:  begin
                    s_black      = 480;
                    s_pineapple  = 480;
                end
                M: begin
                    s_black      = 360;
                    s_pineapple  = 360;
                end
                S: begin
                    s_black      = 240;
                    s_pineapple  = 240;
                end
            endcase
        end
        Super_Pineapple_Milk_Tea: begin
            case(_size)
                L:  begin
                    s_black      = 480;
                    s_milk       = 240;
                    s_pineapple  = 240;
                end
                M: begin
                    s_black      = 360;
                    s_milk       = 180;
                    s_pineapple  = 180;
                end
                S: begin
                    s_black      = 240;
                    s_milk       = 120;
                    s_pineapple  = 120;
                end
            endcase
        end
    endcase

    // expire
    if({_date.M, _date.D} > {golden_month, golden_day}) begin
        golden_err_msg  = No_Exp;
        golden_complete = 0;

    // no ingredient
    end else if(s_black > golden_black || s_green > golden_green || s_milk > golden_milk || s_pineapple > golden_pineapple) begin
        golden_err_msg  = No_Ing;
        golden_complete = 0;

    // no error
    end else begin
        golden_err_msg  = No_Err;
        golden_complete = 1;

        // update golden_dram
        {golden_DRAM[(65536+8*_box_no)+7], golden_DRAM[(65536+8*_box_no)+6][7:4]} = golden_black     - s_black;
        {golden_DRAM[(65536+8*_box_no)+6][3:0], golden_DRAM[(65536+8*_box_no)+5]} = golden_green     - s_green;
        {golden_DRAM[(65536+8*_box_no)+3], golden_DRAM[(65536+8*_box_no)+2][7:4]} = golden_milk      - s_milk;
        {golden_DRAM[(65536+8*_box_no)+2][3:0], golden_DRAM[(65536+8*_box_no)+1]} = golden_pineapple - s_pineapple;

    end

end endtask

task golden_supply_task; begin
    golden_black     = {golden_DRAM[(65536+8*_box_no)+7], golden_DRAM[(65536+8*_box_no)+6][7:4]};
    golden_green     = {golden_DRAM[(65536+8*_box_no)+6][3:0], golden_DRAM[(65536+8*_box_no)+5]};
    golden_month     = {golden_DRAM[(65536+8*_box_no)+4][3:0]};
    golden_milk      = {golden_DRAM[(65536+8*_box_no)+3], golden_DRAM[(65536+8*_box_no)+2][7:4]};
    golden_pineapple = {golden_DRAM[(65536+8*_box_no)+2][3:0], golden_DRAM[(65536+8*_box_no)+1]};
    golden_day       = {golden_DRAM[(65536+8*_box_no)][4:0]};

    // no_error
    golden_err_msg  = No_Err;
    golden_complete = 1;

    // update golden_dram 
    {golden_DRAM[(65536+8*_box_no)+4][3:0]} = _date.M;
    {golden_DRAM[(65536+8*_box_no)][4:0]}   = _date.D;

    // ingredient overflow
    if(golden_black > 4095 - _black) begin
        golden_err_msg  = Ing_OF;
        golden_complete = 0;
        {golden_DRAM[(65536+8*_box_no)+7], golden_DRAM[(65536+8*_box_no)+6][7:4]} = 4095;
    end else 
        {golden_DRAM[(65536+8*_box_no)+7], golden_DRAM[(65536+8*_box_no)+6][7:4]} = golden_black + _black;

    if(golden_green > 4095 - _green) begin
        golden_err_msg  = Ing_OF;
        golden_complete = 0;
        {golden_DRAM[(65536+8*_box_no)+6][3:0], golden_DRAM[(65536+8*_box_no)+5]} = 4095;
    end else 
        {golden_DRAM[(65536+8*_box_no)+6][3:0], golden_DRAM[(65536+8*_box_no)+5]} = golden_green + _green;

    if(golden_milk > 4095 - _milk) begin
        golden_err_msg  = Ing_OF;
        golden_complete = 0;
        {golden_DRAM[(65536+8*_box_no)+3], golden_DRAM[(65536+8*_box_no)+2][7:4]} = 4095;
    end else 
        {golden_DRAM[(65536+8*_box_no)+3], golden_DRAM[(65536+8*_box_no)+2][7:4]} = golden_milk + _milk;

    if(golden_pineapple > 4095 - _pineapple) begin
        golden_err_msg  = Ing_OF;
        golden_complete = 0;
        {golden_DRAM[(65536+8*_box_no)+2][3:0], golden_DRAM[(65536+8*_box_no)+1]} = 4095;
    end else 
        {golden_DRAM[(65536+8*_box_no)+2][3:0], golden_DRAM[(65536+8*_box_no)+1]} = golden_pineapple + _pineapple;

end endtask

task golden_check_date_task; begin
    golden_black     = {golden_DRAM[(65536+8*_box_no)+7], golden_DRAM[(65536+8*_box_no)+6][7:4]};
    golden_green     = {golden_DRAM[(65536+8*_box_no)+6][3:0], golden_DRAM[(65536+8*_box_no)+5]};
    golden_month     = {golden_DRAM[(65536+8*_box_no)+4][3:0]};
    golden_milk      = {golden_DRAM[(65536+8*_box_no)+3], golden_DRAM[(65536+8*_box_no)+2][7:4]};
    golden_pineapple = {golden_DRAM[(65536+8*_box_no)+2][3:0], golden_DRAM[(65536+8*_box_no)+1]};
    golden_day       = {golden_DRAM[(65536+8*_box_no)][4:0]};

    // expire
    if({_date.M, _date.D} > {golden_month, golden_day}) begin
        golden_err_msg  = No_Exp;
        golden_complete = 0;

    // no error
    end else begin
        golden_err_msg  = No_Err;
        golden_complete = 1;
    end

end endtask

task wait_out_valid_task; begin
    latency = 0;
    while(inf.out_valid !== 1'b1) begin
        latency = latency + 1;
        if(latency == CYCLE_DELAY) begin
            $display("\033[m-----------------------------------------------------------------------------\033[m");
            $display("\033[m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                          \033[m");
            $display("\033[m    ▄▀            ▀▄      ▄▄                                                 \033[m");
            $display("\033[m    █  ▀   ▀       ▀▄▄   █  █      FAIL !                                    \033[m");
            $display("\033[m    █   ▀▀            ▀▀▀   ▀▄  ╭  The execution latency is over cycles  %3d\033[m", CYCLE_DELAY);
            $display("\033[m    █  ▄▀▀▀▄                 █  ╭                                            \033[m");
            $display("\033[m    ▀▄                       █                                               \033[m");
            $display("\033[m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                                \033[m");
            $display("\033[m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                                 \033[m");
            $display("\033[m-----------------------------------------------------------------------------\033[m");
            $finish;
        end
        @(negedge clk);
    end
end endtask

task check_ans_task; begin
    while (inf.out_valid === 1'b1) begin   
        if(inf.err_msg !== golden_err_msg || inf.complete !== golden_complete) begin
            $display("\033[0;32;31mWrong Answer\033[m");
            $display("\033[m--------------------------------------------------------------------\033[m");
            $display("\033[m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                 \033[m");
            $display("\033[m    ▄▀            ▀▄      ▄▄       \033[0;32;31mFAIL at %8t PS\033[m", $time);
            $display("\033[m    █  ▀   ▀       ▀▄▄   █  █      \033[0;32;31mAction = %d \033[m", _act);
            $display("\033[m    █   ▀▀            ▀▀▀   ▀▄  ╭  \033[0;32;31mYour   err_msg = %b, complete = %b  \033[m", inf.err_msg, inf.complete);
            $display("\033[m    █  ▄▀▀▀▄                 █  ╭  \033[0;32;31mGolden err_msg = %b, complete = %b  \033[m", golden_err_msg, golden_complete);
            $display("\033[m    ▀▄                       █                                      \033[m");
            $display("\033[m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                       \033[m");
            $display("\033[m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                        \033[m");
            $display("\033[m--------------------------------------------------------------------\033[m");
            $finish;   
        end     
        @(negedge clk);
    end 
end endtask

task YOU_PASS_task; begin
    $display("\033[0;35mCongratulations\033[m");
    $display("\033[m------------------------------------------------------------------------\033[m");
    $display("\033[m     ▄▀▀▄▀▀▀▀▀▀▄▀▀▄                                                     \033[m");
    $display("\033[m    ▄▀            ▀▄      ▄▄                                            \033[m");
    $display("\033[m    █  ▀   ▀       ▀▄▄   █  █      \033[0;35mCongratulations !                    \033[m");
    $display("\033[m    █   ▀▀            ▀▀▀   ▀▄  ╭  \033[0;35mYou have passed all patterns !       \033[m");
    $display("\033[m    █ ▀▄▀▄▄▀                 █  ╭  \033[0;35mYour execution cycles = %5d cycles   \033[m", total_latency);
    $display("\033[m    ▀▄                       █                                          \033[m");
    $display("\033[m     █   ▄▄   ▄▄▄▄▄    ▄▄   █                                           \033[m");
    $display("\033[m     ▀▄▄▀ ▀▀▄▀     ▀▄▄▀  ▀▄▀                                            \033[m");
    $display("\033[m------------------------------------------------------------------------\033[m");  
    $finish;
end endtask

endprogram
