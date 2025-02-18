/*
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
NYCU Institute of Electronic
2023 Autumn IC Design Laboratory 
Lab09: SystemVerilog Design and Verification 
File Name   : PATTERN.sv
Module Name : PATTERN
Release version : v1.0 (Release Date: Nov-2023)
Author : Jui-Huang Tsai (erictsai.10@nycu.edu.tw)
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
*/

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
`include "../00_TESTBED/bem_flowMgr.sv"
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
`include "Usertype_BEV.sv"

program automatic PATTERN(input clk, INF.PATTERN inf);
import usertype::*;

//================================================================
//      PARAMETERS & VARIABLES
//================================================================
// ---------------------------------
// User modification
parameter PATNUM               = 100000;
parameter IS_GEN_DRAM          = 1; // Regenerate the dram.dat
parameter IS_DUMP_DRAM_TO_FILE = 1; // dump dram.dat to readable dram_check.txt
integer   SEED                 = 4948;
// ---------------------------------
// PATTERN operation
parameter DELAY   = 1000;
parameter OUT_NUM = 1;
// ---------------------------------
// Probability
parameter ZERO_INGREDIEN_N = 4;
parameter ZERO_INGREDIEN_D = 10;
// ---------------------------------
// PATTERN CONTROL
integer       i;
integer       j;
integer       k;
integer       m;
integer    stop;
integer     pat;
integer exe_lat;
integer out_lat;
integer out_check_idx;
integer tot_lat;
integer input_delay;
integer each_delay;

// FILE CONTROL
integer file;
integer file_out;

// String control
// Should use %0s
string reset_color       = "\033[1;0m";
string txt_black_prefix  = "\033[1;30m";
string txt_red_prefix    = "\033[1;31m";
string txt_green_prefix  = "\033[1;32m";
string txt_yellow_prefix = "\033[1;33m";
string txt_blue_prefix   = "\033[1;34m";

string bkg_black_prefix  = "\033[40;1m";
string bkg_red_prefix    = "\033[41;1m";
string bkg_green_prefix  = "\033[42;1m";
string bkg_yellow_prefix = "\033[43;1m";
string bkg_blue_prefix   = "\033[44;1m";
string bkg_white_prefix  = "\033[47;1m";

//======================================
//      FLOW MANAGER INITIALIZATION
//======================================
bemFlowMgr bfm = new(SEED, ZERO_INGREDIEN_N, ZERO_INGREDIEN_D);

//======================================
//      MAIN
//======================================
initial exe_task;

//======================================
//              TASKS
//======================================
task exe_task; begin
    reset_task;
    dram_task;
    for (pat=0 ; pat<PATNUM ; pat=pat+1) begin
        input_task;
        cal_task;
        wait_task;
        check_task;
        // TODO : show pat pass
    end
    pass_task;
    $finish;
end endtask

//**************************************
//      Reset Task
//**************************************
task reset_task; begin
    inf.rst_n            = 1;
    inf.sel_action_valid = 0;
    inf.type_valid       = 0;
    inf.size_valid       = 0;
    inf.date_valid       = 0;
    inf.box_no_valid     = 0;
    inf.box_sup_valid    = 0;
    inf.D                = 'dx;
    tot_lat              = 0;

    #(10) inf.rst_n = 0;
    #(10) inf.rst_n = 1;
    if ( inf.out_valid !== 0 || inf.complete !== 0 || inf.err_msg !== 0) begin
        $display("==========================================================================");
        $display("    Output signal should be 0 at %-12d ps  ", $time*1000);
        $display("==========================================================================");
        repeat(5) #(10);
        $finish;
    end
end endtask

//**************************************
//      Dram Task
//**************************************
task dram_task; begin
    bfm.initializeDram(IS_GEN_DRAM, IS_DUMP_DRAM_TO_FILE);
end endtask

//**************************************
//      Input Task
//**************************************
task give_action_task; begin
    inf.sel_action_valid = 'b1;
    inf.D = bfm.getInputMgr().getInputRandMgr().action;
    @(negedge clk);
    inf.sel_action_valid = 'b0;
    inf.D = 'dx;
end endtask

task give_type_task; begin
    inf.type_valid = 'b1;
    inf.D = bfm.getInputMgr().getInputRandMgr().bevType;
    @(negedge clk);
    inf.type_valid = 'b0;
    inf.D = 'dx;
end endtask

task give_size_task; begin
    inf.size_valid = 'b1;
    inf.D = bfm.getInputMgr().getInputRandMgr().bevSize;
    @(negedge clk);
    inf.size_valid = 'b0;
    inf.D = 'dx;
end endtask

task give_date_task; begin
    inf.date_valid = 'b1;
    inf.D = bfm.getInputMgr().getInputRandMgr().date;
    @(negedge clk);
    inf.date_valid = 'b0;
    inf.D = 'dx;
end endtask

task give_box_no_task; begin
    inf.box_no_valid = 'b1;
    inf.D = bfm.getInputMgr().getInputRandMgr().boxId;
    @(negedge clk);
    inf.box_no_valid = 'b0;
    inf.D = 'dx;
end endtask

task give_box_sup_task; begin
    inf.box_sup_valid = 'b1;
    inf.D = bfm.getInputMgr().getInputRandMgr().ingBT;
    @(negedge clk);
    inf.box_sup_valid = 'b0;
    inf.D = 'dx;
    random_gap_cycles();

    inf.box_sup_valid = 'b1;
    inf.D = bfm.getInputMgr().getInputRandMgr().ingGT;
    @(negedge clk);
    inf.box_sup_valid = 'b0;
    inf.D = 'dx;
    random_gap_cycles();

    inf.box_sup_valid = 'b1;
    inf.D = bfm.getInputMgr().getInputRandMgr().ingM;
    @(negedge clk);
    inf.box_sup_valid = 'b0;
    inf.D = 'dx;
    random_gap_cycles();

    inf.box_sup_valid = 'b1;
    inf.D = bfm.getInputMgr().getInputRandMgr().ingPJ;
    @(negedge clk);
    inf.box_sup_valid = 'b0;
    inf.D = 'dx;
end endtask

task random_gap_cycles; begin
    repeat( ({$random(SEED)} % 4 + 0) ) @(negedge clk);
end endtask

task input_task; begin
    repeat( ({$random(SEED)} % 4 + 1) ) @(negedge clk);
    bfm.randomizeInput();
    // bfm.displayInput();

    give_action_task();
    random_gap_cycles();
    case(bfm.getInputMgr().getInputRandMgr().action)
        Make_drink : begin
            // Beverage type
            give_type_task();
            random_gap_cycles();
            // Volume
            give_size_task();
            random_gap_cycles();
            // Today's Date
            give_date_task();
            random_gap_cycles();
            // Ingredient box
            give_box_no_task();
        end
        Supply : begin
            // Expired Date
            give_date_task();
            random_gap_cycles();
            // Ingredient box
            give_box_no_task();
            random_gap_cycles();
            // Supply
            give_box_sup_task();
        end
        Check_Valid_Date : begin
            // Today's Date
            give_date_task();
            random_gap_cycles();
            // Ingredient box
            give_box_no_task();
        end
    endcase
end endtask

//**************************************
//      Calculation Task
//**************************************
task cal_task; begin
    bfm.run();
end endtask

//**************************************
//      Wait Task
//**************************************
task wait_task; begin
    exe_lat = -1;
    while(inf.out_valid !== 1) begin
        if (inf.complete !== 0 || inf.err_msg !== 0) begin
            $display("==========================================================================");
            $display("    Output signal should be 0 at %-12d ps  ", $time*1000);
            $display("==========================================================================");
            repeat(5) @(negedge clk);
            $finish;
        end
        if (exe_lat == DELAY) begin
            $display("==========================================================================");
            $display("    The execution latency at %-12d ps is over %5d cycles  ", $time*1000, DELAY);
            $display("==========================================================================");
            repeat(5) @(negedge clk);
            $finish; 
        end
        exe_lat = exe_lat + 1;
        @(negedge clk);
    end
end endtask

//**************************************
//      Check Task
//**************************************task check_task; begin
task check_task; begin
    out_lat = 0;
    while(inf.out_valid === 1) begin
        if(out_lat == OUT_NUM) begin
            $display("==========================================================================");
            $display("    Out cycles is more than %3d at %-12d ps", OUT_NUM, $time*1000);
            $display("==========================================================================");
            repeat(5) @(negedge clk);
            $finish;
        end
        //====================
        // Check
        //====================
        if ( out_lat<OUT_NUM ) begin
            if(!bfm.isCorrect(inf.err_msg, inf.complete)) begin
                repeat(5) @(negedge clk);
                $finish;
            end
        end

        out_lat = out_lat + 1;
        @(negedge clk);
    end
    tot_lat = tot_lat + exe_lat;

    $display("%0sPASS Action  : %16s, Error : %0s, PATTERN NO.%4d, %0sCycles: %3d%0s",txt_blue_prefix, bfm.getInputMgr().getInputRandMgr().action.name(), bfm.getOutputMgr().isComplete() ? "X" : "V" , pat, txt_green_prefix, exe_lat, reset_color);
end endtask

//**************************************
//      PASS Task
//**************************************
task pass_task; begin
    $display("\033[1;33m                `oo+oy+`                            \033[1;35m Congratulation!!! \033[1;0m                                   ");
    $display("\033[1;33m               /h/----+y        `+++++:             \033[1;35m PASS This Lab........Maybe \033[1;0m                          ");
    $display("\033[1;33m             .y------:m/+ydoo+:y:---:+o             \033[1;35m Total Latency : %-10d\033[1;0m                                ", tot_lat);
    $display("\033[1;33m              o+------/y--::::::+oso+:/y                                                                                     ");
    $display("\033[1;33m              s/-----:/:----------:+ooy+-                                                                                    ");
    $display("\033[1;33m             /o----------------/yhyo/::/o+/:-.`                                                                              ");
    $display("\033[1;33m            `ys----------------:::--------:::+yyo+                                                                           ");
    $display("\033[1;33m            .d/:-------------------:--------/--/hos/                                                                         ");
    $display("\033[1;33m            y/-------------------::ds------:s:/-:sy-                                                                         ");
    $display("\033[1;33m           +y--------------------::os:-----:ssm/o+`                                                                          ");
    $display("\033[1;33m          `d:-----------------------:-----/+o++yNNmms                                                                        ");
    $display("\033[1;33m           /y-----------------------------------hMMMMN.                                                                      ");
    $display("\033[1;33m           o+---------------------://:----------:odmdy/+.                                                                    ");
    $display("\033[1;33m           o+---------------------::y:------------::+o-/h                                                                    ");
    $display("\033[1;33m           :y-----------------------+s:------------/h:-:d                                                                    ");
    $display("\033[1;33m           `m/-----------------------+y/---------:oy:--/y                                                                    ");
    $display("\033[1;33m            /h------------------------:os++/:::/+o/:--:h-                                                                    ");
    $display("\033[1;33m         `:+ym--------------------------://++++o/:---:h/                                                                     ");
    $display("\033[1;31m        `hhhhhoooo++oo+/:\033[1;33m--------------------:oo----\033[1;31m+dd+                                                 ");
    $display("\033[1;31m         shyyyhhhhhhhhhhhso/:\033[1;33m---------------:+/---\033[1;31m/ydyyhs:`                                              ");
    $display("\033[1;31m         .mhyyyyyyhhhdddhhhhhs+:\033[1;33m----------------\033[1;31m:sdmhyyyyyyo:                                            ");
    $display("\033[1;31m        `hhdhhyyyyhhhhhddddhyyyyyo++/:\033[1;33m--------\033[1;31m:odmyhmhhyyyyhy                                            ");
    $display("\033[1;31m        -dyyhhyyyyyyhdhyhhddhhyyyyyhhhs+/::\033[1;33m-\033[1;31m:ohdmhdhhhdmdhdmy:                                           ");
    $display("\033[1;31m         hhdhyyyyyyyyyddyyyyhdddhhyyyyyhhhyyhdhdyyhyys+ossyhssy:-`                                                           ");
    $display("\033[1;31m         `Ndyyyyyyyyyyymdyyyyyyyhddddhhhyhhhhhhhhy+/:\033[1;33m-------::/+o++++-`                                            ");
    $display("\033[1;31m          dyyyyyyyyyyyyhNyydyyyyyyyyyyhhhhyyhhy+/\033[1;33m------------------:/ooo:`                                         ");
    $display("\033[1;31m         :myyyyyyyyyyyyyNyhmhhhyyyyyhdhyyyhho/\033[1;33m-------------------------:+o/`                                       ");
    $display("\033[1;31m        /dyyyyyyyyyyyyyyddmmhyyyyyyhhyyyhh+:\033[1;33m-----------------------------:+s-                                      ");
    $display("\033[1;31m      +dyyyyyyyyyyyyyyydmyyyyyyyyyyyyyds:\033[1;33m---------------------------------:s+                                      ");
    $display("\033[1;31m      -ddhhyyyyyyyyyyyyyddyyyyyyyyyyyhd+\033[1;33m------------------------------------:oo              `-++o+:.`             ");
    $display("\033[1;31m       `/dhshdhyyyyyyyyyhdyyyyyyyyyydh:\033[1;33m---------------------------------------s/            -o/://:/+s             ");
    $display("\033[1;31m         os-:/oyhhhhyyyydhyyyyyyyyyds:\033[1;33m----------------------------------------:h:--.`      `y:------+os            ");
    $display("\033[1;33m         h+-----\033[1;31m:/+oosshdyyyyyyyyhds\033[1;33m-------------------------------------------+h//o+s+-.` :o-------s/y  ");
    $display("\033[1;33m         m:------------\033[1;31mdyyyyyyyyymo\033[1;33m--------------------------------------------oh----:://++oo------:s/d  ");
    $display("\033[1;33m        `N/-----------+\033[1;31mmyyyyyyyydo\033[1;33m---------------------------------------------sy---------:/s------+o/d  ");
    $display("\033[1;33m        .m-----------:d\033[1;31mhhyyyyyyd+\033[1;33m----------------------------------------------y+-----------+:-----oo/h  ");
    $display("\033[1;33m        +s-----------+N\033[1;31mhmyyyyhd/\033[1;33m----------------------------------------------:h:-----------::-----+o/m  ");
    $display("\033[1;33m        h/----------:d/\033[1;31mmmhyyhh:\033[1;33m-----------------------------------------------oo-------------------+o/h  ");
    $display("\033[1;33m       `y-----------so /\033[1;31mNhydh:\033[1;33m-----------------------------------------------/h:-------------------:soo  ");
    $display("\033[1;33m    `.:+o:---------+h   \033[1;31mmddhhh/:\033[1;33m---------------:/osssssoo+/::---------------+d+//++///::+++//::::::/y+`  ");
    $display("\033[1;33m   -s+/::/--------+d.   \033[1;31mohso+/+y/:\033[1;33m-----------:yo+/:-----:/oooo/:----------:+s//::-.....--:://////+/:`    ");
    $display("\033[1;33m   s/------------/y`           `/oo:--------:y/-------------:/oo+:------:/s:                                                 ");
    $display("\033[1;33m   o+:--------::++`              `:so/:-----s+-----------------:oy+:--:+s/``````                                             ");
    $display("\033[1;33m    :+o++///+oo/.                   .+o+::--os-------------------:oy+oo:`/o+++++o-                                           ");
    $display("\033[1;33m       .---.`                          -+oo/:yo:-------------------:oy-:h/:---:+oyo                                          ");
    $display("\033[1;33m                                          `:+omy/---------------------+h:----:y+//so                                         ");
    $display("\033[1;33m                                              `-ys:-------------------+s-----+s///om                                         ");
    $display("\033[1;33m                                                 -os+::---------------/y-----ho///om                                         ");
    $display("\033[1;33m                                                    -+oo//:-----------:h-----h+///+d                                         ");
    $display("\033[1;33m                                                       `-oyy+:---------s:----s/////y                                         ");
    $display("\033[1;33m                                                           `-/o+::-----:+----oo///+s                                         ");
    $display("\033[1;33m                                                               ./+o+::-------:y///s:                                         ");
    $display("\033[1;33m                                                                   ./+oo/-----oo/+h                                          ");
    $display("\033[1;33m                                                                       `://++++syo`                                          ");
    $display("\033[1;0m"); 
    repeat(5) @(negedge clk);
    $finish;
end endtask

endprogram

