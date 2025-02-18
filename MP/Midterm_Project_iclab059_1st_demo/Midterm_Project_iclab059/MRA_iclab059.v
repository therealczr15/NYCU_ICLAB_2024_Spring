//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Si2 LAB @NYCU ED430
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2024 Spring
//   Midterm Proejct            : MRA  
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : MRA.v
//   Module Name : MRA
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module MRA(
	// CHIP IO
		   	  clk,	
		  		rst_n,	
	      in_valid,	
	      frame_id,	
		 	  net_id,	  
		  		loc_x,	  
    			loc_y,
		   	 cost,		
		   	 busy,

    // AXI4 IO
	     arid_m_inf,
	   araddr_m_inf,
	    arlen_m_inf,
	   arsize_m_inf,
	  arburst_m_inf,
	  arvalid_m_inf,
	  arready_m_inf,
	
	      rid_m_inf,
	    rdata_m_inf,
	    rresp_m_inf,
	    rlast_m_inf,
	   rvalid_m_inf,
	   rready_m_inf,
	
	     awid_m_inf,
	   awaddr_m_inf,
	   awsize_m_inf,
	  awburst_m_inf,
	    awlen_m_inf,
	  awvalid_m_inf,
	  awready_m_inf,
	
	    wdata_m_inf,
	    wlast_m_inf,
	   wvalid_m_inf,
	   wready_m_inf,
	
	      bid_m_inf,
	    bresp_m_inf,
	   bvalid_m_inf,
	   bready_m_inf 
);

// ===============================================================
//  					Input / Output 
// ===============================================================

parameter ID_WIDTH = 4 , ADDR_WIDTH = 32, DATA_WIDTH = 128;

// << CHIP io port with system >>
input 			 clk,rst_n;
input 			  in_valid;
input  [4:0] 	  frame_id;
input  [3:0]       net_id;     
input  [5:0]        loc_x; 
input  [5:0]        loc_y; 
output reg [13:0] 	cost;
output reg           busy;       
  
// AXI Interface wire connecttion for pseudo DRAM read/write
/* Hint:
       Your AXI-4 interface could be designed as a bridge in submodule,
	   therefore I declared output of AXI as wire.  
	   Ex: AXI4_interface AXI4_INF(...);
*/

// ------------------------
// <<<<< AXI READ >>>>>
// ------------------------
// (1)	axi read address channel 
output wire [ID_WIDTH-1:0]      arid_m_inf;
output wire [1:0]            arburst_m_inf;
output wire [2:0]             arsize_m_inf;
output wire [7:0]              arlen_m_inf;
output wire                  arvalid_m_inf;
input  wire                  arready_m_inf;
output wire [ADDR_WIDTH-1:0]  araddr_m_inf;
// ------------------------
// (2)	axi read data channel 
input  wire [ID_WIDTH-1:0]       rid_m_inf;
input  wire                   rvalid_m_inf;
output wire                   rready_m_inf;
input  wire [DATA_WIDTH-1:0]   rdata_m_inf;
input  wire                    rlast_m_inf;
input  wire [1:0]              rresp_m_inf;
// ------------------------
// <<<<< AXI WRITE >>>>>
// ------------------------
// (1) 	axi write address channel 
output wire [ID_WIDTH-1:0]      awid_m_inf;
output wire [1:0]            awburst_m_inf;
output wire [2:0]             awsize_m_inf;
output wire [7:0]              awlen_m_inf;
output wire                  awvalid_m_inf;
input  wire                  awready_m_inf;
output wire [ADDR_WIDTH-1:0]  awaddr_m_inf;
// -------------------------
// (2)	axi write data channel 
output wire                   wvalid_m_inf;
input  wire                   wready_m_inf;
output wire [DATA_WIDTH-1:0]   wdata_m_inf;
output wire                    wlast_m_inf;
// -------------------------
// (3)	axi write response channel 
input  wire  [ID_WIDTH-1:0]      bid_m_inf;
input  wire                   bvalid_m_inf;
output wire                   bready_m_inf;
input  wire  [1:0]             bresp_m_inf;
// -----------------------------

//==============================================//
//                  REG & WIRE                  //
//==============================================//

// DRAM FSM
reg  [2:0] cur_dram, nxt_dram;

// AXI4 READ ADDR CHANNEL
reg  						 arvalid;
reg  [ADDR_WIDTH-1:0]  araddr;

// AXI4 READ DATA CHANNEL
reg  rready;

// AXI4 WRITE ADDR CHANNEL
reg  						 awvalid;
reg  [ADDR_WIDTH-1:0]  awaddr;
reg  [DATA_WIDTH-1:0]   wdata;

// AXI4 WRITE DATA CHANNEL
reg  						  wvalid;
reg							wlast;

// AXI4 WRITE DATA CHANNEL
reg							bready;

// FSM
reg  [2:0] cur_state, nxt_state;

// COUNTER
reg  [5:0] cnt_fill, cnt_fill_comb;
wire [5:0] cnt_fillPlusOne, cnt_fillMinusTwo;

reg  [6:0] cnt_retrace , cnt_retrace_comb;
wire [6:0] cnt_retraceMinusOne;

reg  [6:0] cnt_read, cnt_read_comb;
wire [6:0] cnt_readPlusOne, cnt_readPlusTwo;

reg  [6:0] cnt_write, cnt_write_comb;

reg  [3:0] cnt_net, cnt_net_comb;
wire [3:0] cnt_netPlusOne;

reg  [3:0] total_net, total_net_comb;

// REGISTER
reg  [4:0] frame_id_ff, frame_id_comb;
reg  [3:0] net_id_ff[0:14], net_id_comb[0:14];
reg  [5:0] sourceX_ff[0:14], sourceX_comb[0:14];
reg  [5:0] sinkX_ff[0:14], sinkX_comb[0:14];
reg  [5:0] sourceY_ff[0:14], sourceY_comb[0:14];
reg  [5:0] sinkY_ff[0:14], sinkY_comb[0:14];

// REGISTER MAP
reg  [1:0] local_map[0:4095], local_map_comb[0:4095];

// FILL CONTROL
reg  fill_done;
reg  fill_done_comb;

// RETRACE CONTROL
reg  [5:0] retrace_x, retrace_x_comb, retrace_y, retrace_y_comb;

reg  [6:0] point_down, point_up, point_right;
reg  [6:0] point_down_comb, point_up_comb, point_right_comb;
reg  [1:0] up, down, right, up_comb, down_comb, right_comb;

// SRAM A
reg         sram_a_w;
reg  [63:0] sram_a_di, sram_a_do; 
reg  [7:0]  sram_a_addr;

// SRAM B
reg         sram_b_w;
reg  [63:0] sram_b_di, sram_b_do; 
reg  [7:0]  sram_b_addr;

// OUTPUT
reg  [127:0] wdata_write[0:1], wdata_write_comb[0:1];
reg  [3:0]   weight, weight_comb[0:15];
reg  [13:0]  cost_comb;
reg          busy_comb;

integer i, j;

//==============================================//
//              DRAM FSM PARAMETER              //
//==============================================//

parameter 	D_IDLE	=	3'd0;
parameter	D_AR		=	3'd1;
parameter	D_R		=	3'd2;
parameter	D_AW 		=	3'd3;
parameter	D_W 		=	3'd4;
parameter	D_B 		=	3'd5;

//==============================================//
//                FSM PARAMETER                 //
//==============================================//

parameter 	S_IDLE			=	3'd0;
parameter	S_READ_LMAP		=	3'd1;
parameter	S_FILL_SET		=	3'd2;
parameter	S_FILL			=	3'd3;
parameter	S_WAIT_READ_W	=	3'd4;
parameter	S_RETRACE		=	3'd5;
parameter	S_CLEAN			=	3'd6;
parameter	S_WRITE			=	3'd7;

//==============================================//
//                   DRAM FSM                   //
//==============================================//

always @(*) begin
	case(cur_dram)
		D_IDLE: begin
			if(in_valid) // in_valid means READ LMAP
				nxt_dram = D_AR;
			else if(cur_state == S_CLEAN && cnt_net == total_net)
				nxt_dram = D_AW;
			else
				nxt_dram = cur_dram;
		end
		D_AR: begin
			if(arready_m_inf)
				nxt_dram = D_R;
			else
				nxt_dram = cur_dram;
		end
		D_R: begin
			if(rlast_m_inf && cur_state == S_READ_LMAP) // READ LMAP TO READ WMAP
				nxt_dram = D_AR;
			else if(rlast_m_inf)
				nxt_dram = D_IDLE;
			else
				nxt_dram = cur_dram;
		end
		D_AW: begin
			if(awready_m_inf)
				nxt_dram = D_W;
			else
				nxt_dram = cur_dram;
		end
		D_W: begin
			if(cnt_read == 127)
				nxt_dram = D_B;
			else
				nxt_dram = cur_dram;
		end
		D_B: begin
			if(bvalid_m_inf)
				nxt_dram = D_IDLE;
			else
				nxt_dram = cur_dram;
		end
		default: nxt_dram = cur_dram;
	endcase	
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		cur_dram <= D_IDLE;
	else
		cur_dram <= nxt_dram;
end

//==============================================//
//                 AXI4 CONTROL                 //
//==============================================//

// READ ADDR CHANNEL
assign    arid_m_inf = 4'd0;
assign arburst_m_inf = 2'd1;
assign  arsize_m_inf = 3'd4;
assign   arlen_m_inf = 8'd127;

always @(*) begin
	case(cur_dram)
		D_AR: arvalid = 1;
		default: arvalid = 0;
	endcase
end

assign arvalid_m_inf = arvalid;

always @(*) begin
	case(cur_state)
		S_READ_LMAP: araddr = {16'h0001,frame_id_ff,11'h0};
		S_FILL_SET: araddr = {16'h0002,frame_id_ff,11'h0};
		S_FILL: araddr = {16'h0002,frame_id_ff,11'h0};
		default: araddr = 0;
	endcase
end

assign  araddr_m_inf = araddr;

// READ DATA CHANNEL
always @(*) begin
	case(cur_dram)
		D_R: rready = 1;
		default: rready = 0;
	endcase
end

assign  rready_m_inf = rready;

// WRITE ADDR CHANNEL
assign    awid_m_inf = 4'd0;
assign awburst_m_inf = 2'd1;
assign  awsize_m_inf = 3'd4;
assign   awlen_m_inf = 8'd127;

always @(*) begin
	case(cur_dram)
		D_AW: awvalid = 1;
		default: awvalid = 0;
	endcase
end

assign awvalid_m_inf = awvalid;

always @(*) begin
	case(cur_state)
		S_WRITE: awaddr = {16'h0001,frame_id_ff,11'h0};
		default: awaddr = 0;
	endcase
end

assign  awaddr_m_inf = awaddr;

// WRITE DATA CHANNEL
always @(*) begin
	case(cur_dram)
		D_W: wvalid = 1;
		default: wvalid = 0;
	endcase
end

assign wvalid_m_inf = wvalid;

always @(*) begin
	case(cur_dram)
		D_W: begin
			if(cnt_read == 127)
				wlast = 1;
			else
				wlast = 0;
		end
		default: wlast = 0;
	endcase
end

assign  wlast_m_inf = wlast;

always @(*) begin
	case(cur_dram)
		D_W: begin
			if(cnt_read == 0)
				wdata = wdata_write[0];
			else
				wdata = wdata_write[1];
		end
		default: wdata = 0;
	endcase
end

assign  wdata_m_inf = wdata;

// WRITE RESP CHANNEL
always @(*) begin
	case(cur_dram)
		D_W: bready = 1;
		D_B: bready = 1;
		default: bready = 0;
	endcase
end

assign bready_m_inf = bready;

//==============================================//
//                     FSM                      //
//==============================================//

always @(*) begin
	case(cur_state)
		S_IDLE: begin
         if(in_valid)
            nxt_state = S_READ_LMAP;
         else
            nxt_state = cur_state;
      end
      S_READ_LMAP: begin
      	if(rlast_m_inf)
      		nxt_state = S_FILL_SET;
      	else
      		nxt_state = cur_state;
      end
      S_FILL_SET: nxt_state = S_FILL;
      S_FILL: begin
      	if(fill_done)
      		nxt_state = cur_state;
      	else if(cnt_net == 0)
      		nxt_state = S_WAIT_READ_W;
      	else
      		nxt_state = S_RETRACE;
      end
      S_WAIT_READ_W: begin
      	if(rlast_m_inf)
      		nxt_state = S_RETRACE;
      	else
      		nxt_state = S_WAIT_READ_W;
      end
      S_RETRACE: begin
      	if(retrace_x == sourceX_ff[0] && retrace_y == sourceY_ff[0])
      		nxt_state = S_CLEAN;
      	else
      		nxt_state = cur_state;
      end
      S_CLEAN: begin
      	if(cnt_net == total_net)
      		nxt_state = S_WRITE;
      	else
      		nxt_state = S_FILL_SET;
      end
      S_WRITE: begin
      	if(cnt_read == 127)
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

// cnt_fill
assign cnt_fillPlusOne  = cnt_fill + 1;
assign cnt_fillMinusTwo = cnt_fill - 3;

always @(*) begin
	case(cur_state)
		S_IDLE: begin
			if(in_valid)
				cnt_fill_comb = cnt_fillPlusOne;
			else
				cnt_fill_comb = 0;
		end
		S_READ_LMAP: begin
			if(in_valid)
				cnt_fill_comb = cnt_fillPlusOne;
			else
				cnt_fill_comb = 0;
		end
		S_FILL: cnt_fill_comb = cnt_fillPlusOne;
		default: cnt_fill_comb = 0;
	endcase
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		cnt_fill <= 0;
	else
		cnt_fill <= cnt_fill_comb;
end

// cnt_retrace
assign cnt_retraceMinusOne  = cnt_retrace - 1;

always @(*) begin
	case(cur_state)
		S_FILL: cnt_retrace_comb = {cnt_fillMinusTwo[5:0],1'b1};
		S_WAIT_READ_W: cnt_retrace_comb = cnt_retrace;
		S_RETRACE: cnt_retrace_comb = cnt_retraceMinusOne;
		default: cnt_retrace_comb = 0;
	endcase
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		cnt_retrace <= 0;
	else
		cnt_retrace <= cnt_retrace_comb;
end

// cnt_read
assign cnt_readPlusOne = cnt_read + 1;
assign cnt_readPlusTwo = cnt_read + 2;

always @(*) begin
	if(rvalid_m_inf | wready_m_inf)
		cnt_read_comb = cnt_readPlusOne;
	else
		cnt_read_comb = 0;
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		cnt_read <= 0;
	else
		cnt_read <= cnt_read_comb;
end

// cnt_net
assign cnt_netPlusOne = cnt_net + 1;

always @(*) begin
	if(cur_state == S_IDLE)
		cnt_net_comb = 0;
	else if(cur_state == S_CLEAN)
		cnt_net_comb = cnt_netPlusOne;
	else
		cnt_net_comb = cnt_net;
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		cnt_net <= 0;
	else
		cnt_net <= cnt_net_comb;
end

// total_net
always @(*) begin
	if(in_valid)
		total_net_comb = cnt_fill[4:1];
	else
		total_net_comb = total_net;
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		total_net <= 0;
	else
		total_net <= total_net_comb;
end


//==============================================//
//                   REGISTER                   //
//==============================================//

// frame_id
always @(*) begin
	if(in_valid)
		frame_id_comb = frame_id;
	else
		frame_id_comb = frame_id_ff;
end

always @(posedge clk ) begin
	frame_id_ff <= frame_id_comb;
end

// net_id
always @(*) begin
	for(i=0;i<15;i=i+1)
		net_id_comb[i] = net_id_ff[i];
	case(cur_state)
		S_CLEAN: begin
			for(i=0;i<14;i=i+1)
				net_id_comb[i] = net_id_ff[i+1];
		end
		default: begin
			if(in_valid)
				net_id_comb[cnt_fill[4:1]] = net_id;
		end
	endcase
end

always @(posedge clk) begin
	net_id_ff <= net_id_comb;
end

// source X
always @(*) begin
	for(i=0;i<15;i=i+1)
		sourceX_comb[i] = sourceX_ff[i];
	if(in_valid && !cnt_fill[0])
		sourceX_comb[cnt_fill[4:1]] = loc_x;
	else if(cur_state == S_CLEAN) begin
		for(i=0;i<14;i=i+1)
			sourceX_comb[i] = sourceX_ff[i+1];
	end
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		for(i=0;i<15;i=i+1)
			sourceX_ff[i] <= 0;
	end else
		sourceX_ff <= sourceX_comb;
end

// sink X
always @(*) begin
	for(i=0;i<15;i=i+1)
		sinkX_comb[i] = sinkX_ff[i];
	if(in_valid && cnt_fill[0])
		sinkX_comb[cnt_fill[4:1]] = loc_x;
	else if(cur_state == S_CLEAN) begin
		for(i=0;i<14;i=i+1)
			sinkX_comb[i] = sinkX_ff[i+1];
	end
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		for(i=0;i<15;i=i+1)
			sinkX_ff[i] <= 0;
	end else
		sinkX_ff <= sinkX_comb;
end

// source Y
always @(*) begin
	for(i=0;i<15;i=i+1)
		sourceY_comb[i] = sourceY_ff[i];
	if(in_valid && !cnt_fill[0])
		sourceY_comb[cnt_fill[4:1]] = loc_y;
	else if(cur_state == S_CLEAN) begin
		for(i=0;i<14;i=i+1)
			sourceY_comb[i] = sourceY_ff[i+1];
	end

end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		for(i=0;i<15;i=i+1)
			sourceY_ff[i] <= 0;
	end else
		sourceY_ff <= sourceY_comb;
end

// sink Y
always @(*) begin
	for(i=0;i<15;i=i+1)
		sinkY_comb[i] = sinkY_ff[i];
	if(in_valid && cnt_fill[0])
		sinkY_comb[cnt_fill[4:1]] = loc_y;
	else if(cur_state == S_CLEAN) begin
		for(i=0;i<14;i=i+1)
			sinkY_comb[i] = sinkY_ff[i+1];
	end
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		for(i=0;i<15;i=i+1)
			sinkY_ff[i] <= 0;
	end else
		sinkY_ff <= sinkY_comb;
end

//==============================================//
//              REGISTER LOCAL MAP              //
//==============================================//

always @(*) begin
	case(cur_state)
		S_READ_LMAP: begin
			local_map_comb = {local_map[32:4095],
			{1'b0,{|(rdata_m_inf[3:0])}},   {1'b0,{|(rdata_m_inf[7:4])}},     {1'b0,{|(rdata_m_inf[11:8])}},    {1'b0,{|(rdata_m_inf[15:12])}},   {1'b0,{|(rdata_m_inf[19:16])}},   {1'b0,{|(rdata_m_inf[23:20])}},   {1'b0,{|(rdata_m_inf[27:24])}},   {1'b0,{|(rdata_m_inf[31:28])}},
			{1'b0,{|(rdata_m_inf[35:32])}}, {1'b0,{|(rdata_m_inf[39:36])}},   {1'b0,{|(rdata_m_inf[43:40])}},   {1'b0,{|(rdata_m_inf[47:44])}},   {1'b0,{|(rdata_m_inf[51:48])}},   {1'b0,{|(rdata_m_inf[55:52])}},   {1'b0,{|(rdata_m_inf[59:56])}},   {1'b0,{|(rdata_m_inf[63:60])}},
			{1'b0,{|(rdata_m_inf[67:64])}}, {1'b0,{|(rdata_m_inf[71:68])}},   {1'b0,{|(rdata_m_inf[75:72])}},   {1'b0,{|(rdata_m_inf[79:76])}},   {1'b0,{|(rdata_m_inf[83:80])}},   {1'b0,{|(rdata_m_inf[87:84])}},   {1'b0,{|(rdata_m_inf[91:88])}},   {1'b0,{|(rdata_m_inf[95:92])}},
			{1'b0,{|(rdata_m_inf[99:96])}}, {1'b0,{|(rdata_m_inf[103:100])}}, {1'b0,{|(rdata_m_inf[107:104])}}, {1'b0,{|(rdata_m_inf[111:108])}}, {1'b0,{|(rdata_m_inf[115:112])}}, {1'b0,{|(rdata_m_inf[119:116])}}, {1'b0,{|(rdata_m_inf[123:120])}}, {1'b0,{|(rdata_m_inf[127:124])}}
			};
		end
		S_FILL_SET: begin
			local_map_comb = local_map;
			local_map_comb[{sourceY_ff[0],sourceX_ff[0]}] = 3;
			local_map_comb[{sinkY_ff[0],sinkX_ff[0]}] = 0;
		end
		S_FILL: begin
			local_map_comb = local_map;

			// 4 corner
			// left up
			if(local_map[0] == 0 && (local_map[1][1] | local_map[64][1])) 
				local_map_comb[0] = {1'd1,cnt_fill[1]};

			// right up
			if(local_map[63] == 0 && (local_map[62][1] | local_map[127][1])) 
				local_map_comb[63] = {1'd1,cnt_fill[1]};

			// left down
			if(local_map[4032] == 0 && (local_map[4033][1] | local_map[3968][1])) 
				local_map_comb[4032] = {1'd1,cnt_fill[1]};

			// right down
			if(local_map[4095] == 0 && (local_map[4094][1] | local_map[4031][1])) 
				local_map_comb[4095] = {1'd1,cnt_fill[1]};
		
			for(i=1;i<63;i=i+1) begin
				// 1st row
				if(local_map[i] == 0 && (local_map[i-1][1] | local_map[i+1][1] | local_map[i+64][1]))
					local_map_comb[i] = {1'd1,cnt_fill[1]};

				// last row
				if(local_map[4095-i] == 0 && (local_map[4095-i-1][1] | local_map[4095-i+1][1] | local_map[4095-i-64][1]))
					local_map_comb[4095-i] = {1'd1,cnt_fill[1]};

				// 1st col
				if(local_map[i*64] == 0 && (local_map[(i-1)*64][1] | local_map[(i+1)*64][1] | local_map[i*64+1][1]))
					local_map_comb[i*64] = {1'd1,cnt_fill[1]};

				// last col
				if(local_map[i*64+63] == 0 && (local_map[(i-1)*64+63][1] | local_map[(i+1)*64+63][1] | local_map[i*64+62][1]))
					local_map_comb[i*64+63] = {1'd1,cnt_fill[1]};
			end

			for(j=1;j<63;j=j+1) begin
				for(i=1;i<63;i=i+1) begin
					if(local_map[j*64+i] == 0 && (local_map[j*64+i-1][1] | local_map[j*64+i+1][1] | local_map[(j-1)*64+i][1] | local_map[(j+1)*64+i][1]))
						local_map_comb[j*64+i] = {1'd1,cnt_fill[1]};
				end
			end
		
		end
		S_RETRACE: begin
			local_map_comb = local_map;
			local_map_comb[{retrace_y, retrace_x}] = 1;
		end
		S_CLEAN: begin
			for(i=0;i<4096;i=i+1) begin
				if(local_map[i][1])
					local_map_comb[i] = 0;
				else
					local_map_comb[i] = local_map[i];
			end
		end
		default: local_map_comb = local_map;
	endcase
end

always @(posedge clk) begin
	local_map <= local_map_comb;
end

//==============================================//
//                 FILL CONTROL                 //
//==============================================// 

always @(*) begin
	case(cur_state)
		S_FILL_SET: fill_done_comb = 1;
		S_FILL: fill_done_comb = (local_map[{sinkY_ff[0],sinkX_ff[0]}] == 0);
		default: fill_done_comb = 0;
	endcase
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		fill_done <= 0;
	else
		fill_done <= fill_done_comb;
end

//==============================================//
//               RETRACE CONTROL                //
//==============================================// 
always @(*) begin
	case(cur_state)
		S_RETRACE: begin
			if(!cnt_retrace[0]) begin
				if(down == {1'b1, cnt_retrace[2]})
					point_down_comb = retrace_y + 2;
				else if(up == {1'b1, cnt_retrace[2]})
					point_down_comb = retrace_y;
				else 
					point_down_comb = retrace_y + 1;
			end else
				point_down_comb = point_down;
		end
		default: point_down_comb = retrace_y + 1;
	endcase
end

always @(*) begin
	case(cur_state)
		S_RETRACE: begin
			if(!cnt_retrace[0]) begin
				if(down == {1'b1, cnt_retrace[2]})
					point_up_comb = retrace_y;
				else if(up == {1'b1, cnt_retrace[2]})
					point_up_comb = retrace_y - 2;
				else 
					point_up_comb = retrace_y - 1;
			end else
				point_up_comb = point_up;
		end
		default: point_up_comb = retrace_y - 1;
	endcase
end

always @(*) begin
	case(cur_state)
		S_RETRACE: begin
			if(!cnt_retrace[0]) begin
				if(down == {1'b1, cnt_retrace[2]})
					point_right_comb = retrace_x + 1;
				else if(up == {1'b1, cnt_retrace[2]})
					point_right_comb = retrace_x + 1;
				else if(right == {1'b1, cnt_retrace[2]})
					point_right_comb = retrace_x + 2;
				else 
					point_right_comb = retrace_x;
			end else
				point_right_comb = point_right;
		end
		default: point_right_comb = retrace_x + 1;
	endcase
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		point_down <= 0;
	else
		point_down <= point_down_comb;
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		point_up <= 0;
	else
		point_up <= point_up_comb;
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		point_right <= 0;
	else
		point_right <= point_right_comb;
end

always @(*) begin
	if(!point_down[6])
		down_comb = local_map[{point_down[5:0],retrace_x}];
	else
		down_comb = 0;
end

always @(*) begin
	if(!point_up[6])
		up_comb = local_map[{point_up[5:0],retrace_x}];
	else
		up_comb = 0;
end

always @(*) begin
	if(!point_right[6])
		right_comb = local_map[{retrace_y,point_right[5:0]}];
	else
		right_comb = 0;
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		down <= 0;
	else
		down <= down_comb;
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		up <= 0;
	else
		up <= up_comb;
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		right <= 0;
	else
		right <= right_comb;
end


always @(*) begin
	case(cur_state)
		S_RETRACE: begin
			if(!cnt_retrace[0]) begin
				if(down == {1'b1, cnt_retrace[2]})
					retrace_x_comb = retrace_x;
				else if(up == {1'b1, cnt_retrace[2]})
					retrace_x_comb = retrace_x;
				else if(right == {1'b1, cnt_retrace[2]})
					retrace_x_comb = retrace_x + 1;
				else
					retrace_x_comb = retrace_x - 1;
			end else
				retrace_x_comb = retrace_x;
		end
		default: retrace_x_comb = sinkX_ff[0];
	endcase
end

always @(*) begin
	case(cur_state)
		S_RETRACE: begin
			if(!cnt_retrace[0]) begin
				if(down == {1'b1, cnt_retrace[2]})
					retrace_y_comb = retrace_y + 1;
				else if(up == {1'b1, cnt_retrace[2]})
					retrace_y_comb = retrace_y - 1;
				else if(right == {1'b1, cnt_retrace[2]})
					retrace_y_comb = retrace_y;
				else
					retrace_y_comb = retrace_y;
			end else
				retrace_y_comb = retrace_y;
		end
		default: retrace_y_comb = sinkY_ff[0];
	endcase
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		retrace_x <= 0;
	else
		retrace_x <= retrace_x_comb;
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		retrace_y <= 0;
	else
		retrace_y <= retrace_y_comb;
end

//==============================================//
//                 SRAM CONTROL                 //
//==============================================// 

// SRAM A write
// w = 1 (read)
always @(*) begin                                                   
	case(cur_state)
		S_READ_LMAP: sram_a_w = 0;
		S_FILL: begin
			if(cur_dram == D_R)
				sram_a_w = 0;
			else
				sram_a_w = 1;
		end
		S_WAIT_READ_W: begin
			if(cur_dram == D_R)
				sram_a_w = 0;
			else
				sram_a_w = 1;
		end
		S_RETRACE: begin
			if(!(retrace_x == sinkX_ff[0] && retrace_y == sinkY_ff[0]))
				sram_a_w = cnt_retrace[0] | retrace_x[4];
			else
				sram_a_w = 1;
		end
		default: sram_a_w = 1;
	endcase
end

// SRAM B write
// w = 1 (read)
always @(*) begin                                                   
	case(cur_state)
		S_READ_LMAP: sram_b_w = 0;
		S_FILL: begin
			if(cur_dram == D_R)
				sram_b_w = 0;
			else
				sram_b_w = 1;
		end
		S_WAIT_READ_W: begin
			if(cur_dram == D_R)
				sram_b_w = 0;
			else
				sram_b_w = 1;
		end
		S_RETRACE: begin
			if(!(retrace_x == sinkX_ff[0] && retrace_y == sinkY_ff[0]))
				sram_b_w = cnt_retrace[0] | (~retrace_x[4]);
			else
				sram_b_w = 1;
		end
		default: sram_b_w = 1;
	endcase
end

// SRAM A ADDR
always @(*) begin
	case(cur_state)
		S_READ_LMAP: sram_a_addr = {cnt_read,1'd0};
		S_FILL: begin
			if(cur_dram == D_R)
				sram_a_addr = {cnt_read,1'd1};
			else
				sram_a_addr = 0;
		end
		S_WAIT_READ_W: begin
			if(cur_dram == D_R)
				sram_a_addr = {cnt_read,1'd1};
			else
				sram_a_addr = 0;
		end
		// read weight, write local
		S_RETRACE: sram_a_addr = {retrace_y,retrace_x[5],retrace_x[4]};
		S_WRITE: begin 
			case(cur_dram)
				D_AW: sram_a_addr = 0;
				D_W: begin
					if(wready_m_inf)
						sram_a_addr = {cnt_readPlusTwo,1'd0};
					else
						sram_a_addr = 2;
				end
				default: sram_a_addr = 0;
			endcase
		end
		default: sram_a_addr = 0;
	endcase
end

// SRAM B ADDR
always @(*) begin
	case(cur_state)
		S_READ_LMAP: sram_b_addr = {cnt_read,1'd0};
		S_FILL: begin
			if(cur_dram == D_R)
				sram_b_addr = {cnt_read,1'd1};
			else
				sram_b_addr = 0;
		end
		S_WAIT_READ_W: begin
			if(cur_dram == D_R)
				sram_b_addr = {cnt_read,1'd1};
			else
				sram_b_addr = 0;
		end
		// read weight, write local
		S_RETRACE: sram_b_addr = {retrace_y,retrace_x[5],!retrace_x[4]};
		S_WRITE: begin 
			case(cur_dram)
				D_AW: sram_b_addr = 0;
				D_W: begin
					if(wready_m_inf)
						sram_b_addr = {cnt_readPlusTwo,1'd0};
					else
						sram_b_addr = 2;
				end
				default: sram_b_addr = 0;
			endcase
		end
		default: sram_b_addr = 0;
	endcase
end

// SRAM A DI
always @(*) begin
	case(cur_state)
		S_READ_LMAP: sram_a_di = rdata_m_inf[63:0];
		S_FILL: begin
			if(cur_dram == D_R)
				sram_a_di = rdata_m_inf[127:64];
			else
				sram_a_di = 0;
		end
		S_WAIT_READ_W: begin
			if(cur_dram == D_R)
				sram_a_di = rdata_m_inf[127:64];
			else
				sram_a_di = 0;
		end
		S_RETRACE: begin
			for(i=0;i<16;i=i+1) begin
				if(i == retrace_x[3:0])
					sram_a_di[i*4+:4] = net_id_ff[0];
				else
					sram_a_di[i*4+:4] = sram_a_do[i*4+:4];
			end
		end
		default: sram_a_di = 0;
	endcase
end

// SRAM B DI
always @(*) begin
	case(cur_state)
		S_READ_LMAP: sram_b_di = rdata_m_inf[127:64];
		S_FILL: begin
			if(cur_dram == D_R)
				sram_b_di = rdata_m_inf[63:0];
			else
				sram_b_di = 0;
		end
		S_WAIT_READ_W: begin
			if(cur_dram == D_R)
				sram_b_di = rdata_m_inf[63:0];
			else
				sram_b_di = 0;
		end
		S_RETRACE: begin
			for(i=0;i<16;i=i+1) begin
				if(i == retrace_x[3:0])
					sram_b_di[i*4+:4] = net_id_ff[0];
				else
					sram_b_di[i*4+:4] = sram_b_do[i*4+:4];
			end
		end
		default: sram_b_di = 0;
	endcase
end

//==============================================//
//                     SRAM                     //
//==============================================// 

SRAM_256x64 SA (
    .A0(sram_a_addr[0]),   .A1(sram_a_addr[1]),   .A2(sram_a_addr[2]),    .A3(sram_a_addr[3]),   .A4(sram_a_addr[4]),  .A5(sram_a_addr[5]),   .A6(sram_a_addr[6]),  .A7(sram_a_addr[7]),
    .DO0(sram_a_do[0]),    .DO1(sram_a_do[1]),    .DO2(sram_a_do[2]),     .DO3(sram_a_do[3]),    .DO4(sram_a_do[4]),   .DO5(sram_a_do[5]),    .DO6(sram_a_do[6]),   .DO7(sram_a_do[7]),  
    .DO8(sram_a_do[8]),    .DO9(sram_a_do[9]),    .DO10(sram_a_do[10]),   .DO11(sram_a_do[11]),  .DO12(sram_a_do[12]), .DO13(sram_a_do[13]),  .DO14(sram_a_do[14]), .DO15(sram_a_do[15]),
    .DO16(sram_a_do[16]),  .DO17(sram_a_do[17]),  .DO18(sram_a_do[18]),   .DO19(sram_a_do[19]),  .DO20(sram_a_do[20]), .DO21(sram_a_do[21]),  .DO22(sram_a_do[22]), .DO23(sram_a_do[23]),
    .DO24(sram_a_do[24]),  .DO25(sram_a_do[25]),  .DO26(sram_a_do[26]),   .DO27(sram_a_do[27]),  .DO28(sram_a_do[28]), .DO29(sram_a_do[29]),  .DO30(sram_a_do[30]), .DO31(sram_a_do[31]),
    .DO32(sram_a_do[32]),  .DO33(sram_a_do[33]),  .DO34(sram_a_do[34]),   .DO35(sram_a_do[35]),  .DO36(sram_a_do[36]), .DO37(sram_a_do[37]),  .DO38(sram_a_do[38]), .DO39(sram_a_do[39]),
    .DO40(sram_a_do[40]),  .DO41(sram_a_do[41]),  .DO42(sram_a_do[42]),   .DO43(sram_a_do[43]),  .DO44(sram_a_do[44]), .DO45(sram_a_do[45]),  .DO46(sram_a_do[46]), .DO47(sram_a_do[47]),
    .DO48(sram_a_do[48]),  .DO49(sram_a_do[49]),  .DO50(sram_a_do[50]),   .DO51(sram_a_do[51]),  .DO52(sram_a_do[52]), .DO53(sram_a_do[53]),  .DO54(sram_a_do[54]), .DO55(sram_a_do[55]),
    .DO56(sram_a_do[56]),  .DO57(sram_a_do[57]),  .DO58(sram_a_do[58]),   .DO59(sram_a_do[59]),  .DO60(sram_a_do[60]), .DO61(sram_a_do[61]),  .DO62(sram_a_do[62]), .DO63(sram_a_do[63]),
    .DI0(sram_a_di[0]),    .DI1(sram_a_di[1]),    .DI2(sram_a_di[2]),     .DI3(sram_a_di[3]),    .DI4(sram_a_di[4]),   .DI5(sram_a_di[5]),    .DI6(sram_a_di[6]),   .DI7(sram_a_di[7]),   
    .DI8(sram_a_di[8]),    .DI9(sram_a_di[9]),    .DI10(sram_a_di[10]),   .DI11(sram_a_di[11]),  .DI12(sram_a_di[12]), .DI13(sram_a_di[13]),  .DI14(sram_a_di[14]), .DI15(sram_a_di[15]),   
    .DI16(sram_a_di[16]),  .DI17(sram_a_di[17]),  .DI18(sram_a_di[18]),   .DI19(sram_a_di[19]),  .DI20(sram_a_di[20]), .DI21(sram_a_di[21]),  .DI22(sram_a_di[22]), .DI23(sram_a_di[23]),   
    .DI24(sram_a_di[24]),  .DI25(sram_a_di[25]),  .DI26(sram_a_di[26]),   .DI27(sram_a_di[27]),  .DI28(sram_a_di[28]), .DI29(sram_a_di[29]),  .DI30(sram_a_di[30]), .DI31(sram_a_di[31]),   
    .DI32(sram_a_di[32]),  .DI33(sram_a_di[33]),  .DI34(sram_a_di[34]),   .DI35(sram_a_di[35]),  .DI36(sram_a_di[36]), .DI37(sram_a_di[37]),  .DI38(sram_a_di[38]), .DI39(sram_a_di[39]),   
    .DI40(sram_a_di[40]),  .DI41(sram_a_di[41]),  .DI42(sram_a_di[42]),   .DI43(sram_a_di[43]),  .DI44(sram_a_di[44]), .DI45(sram_a_di[45]),  .DI46(sram_a_di[46]), .DI47(sram_a_di[47]),  
    .DI48(sram_a_di[48]),  .DI49(sram_a_di[49]),  .DI50(sram_a_di[50]),   .DI51(sram_a_di[51]),  .DI52(sram_a_di[52]), .DI53(sram_a_di[53]),  .DI54(sram_a_di[54]), .DI55(sram_a_di[55]),   
    .DI56(sram_a_di[56]),  .DI57(sram_a_di[57]),  .DI58(sram_a_di[58]),   .DI59(sram_a_di[59]),  .DI60(sram_a_di[60]), .DI61(sram_a_di[61]),  .DI62(sram_a_di[62]), .DI63(sram_a_di[63]),
    .CK(clk), .WEB(sram_a_w),   .OE(1'b1), .CS(1'b1)
    );

SRAM_256x64 SB (
    .A0(sram_b_addr[0]),   .A1(sram_b_addr[1]),   .A2(sram_b_addr[2]),    .A3(sram_b_addr[3]),   .A4(sram_b_addr[4]),  .A5(sram_b_addr[5]),   .A6(sram_b_addr[6]),  .A7(sram_b_addr[7]),
    .DO0(sram_b_do[0]),    .DO1(sram_b_do[1]),    .DO2(sram_b_do[2]),     .DO3(sram_b_do[3]),    .DO4(sram_b_do[4]),   .DO5(sram_b_do[5]),    .DO6(sram_b_do[6]),   .DO7(sram_b_do[7]),  
    .DO8(sram_b_do[8]),    .DO9(sram_b_do[9]),    .DO10(sram_b_do[10]),   .DO11(sram_b_do[11]),  .DO12(sram_b_do[12]), .DO13(sram_b_do[13]),  .DO14(sram_b_do[14]), .DO15(sram_b_do[15]),
    .DO16(sram_b_do[16]),  .DO17(sram_b_do[17]),  .DO18(sram_b_do[18]),   .DO19(sram_b_do[19]),  .DO20(sram_b_do[20]), .DO21(sram_b_do[21]),  .DO22(sram_b_do[22]), .DO23(sram_b_do[23]),
    .DO24(sram_b_do[24]),  .DO25(sram_b_do[25]),  .DO26(sram_b_do[26]),   .DO27(sram_b_do[27]),  .DO28(sram_b_do[28]), .DO29(sram_b_do[29]),  .DO30(sram_b_do[30]), .DO31(sram_b_do[31]),
    .DO32(sram_b_do[32]),  .DO33(sram_b_do[33]),  .DO34(sram_b_do[34]),   .DO35(sram_b_do[35]),  .DO36(sram_b_do[36]), .DO37(sram_b_do[37]),  .DO38(sram_b_do[38]), .DO39(sram_b_do[39]),
    .DO40(sram_b_do[40]),  .DO41(sram_b_do[41]),  .DO42(sram_b_do[42]),   .DO43(sram_b_do[43]),  .DO44(sram_b_do[44]), .DO45(sram_b_do[45]),  .DO46(sram_b_do[46]), .DO47(sram_b_do[47]),
    .DO48(sram_b_do[48]),  .DO49(sram_b_do[49]),  .DO50(sram_b_do[50]),   .DO51(sram_b_do[51]),  .DO52(sram_b_do[52]), .DO53(sram_b_do[53]),  .DO54(sram_b_do[54]), .DO55(sram_b_do[55]),
    .DO56(sram_b_do[56]),  .DO57(sram_b_do[57]),  .DO58(sram_b_do[58]),   .DO59(sram_b_do[59]),  .DO60(sram_b_do[60]), .DO61(sram_b_do[61]),  .DO62(sram_b_do[62]), .DO63(sram_b_do[63]),
    .DI0(sram_b_di[0]),    .DI1(sram_b_di[1]),    .DI2(sram_b_di[2]),     .DI3(sram_b_di[3]),    .DI4(sram_b_di[4]),   .DI5(sram_b_di[5]),    .DI6(sram_b_di[6]),   .DI7(sram_b_di[7]),   
    .DI8(sram_b_di[8]),    .DI9(sram_b_di[9]),    .DI10(sram_b_di[10]),   .DI11(sram_b_di[11]),  .DI12(sram_b_di[12]), .DI13(sram_b_di[13]),  .DI14(sram_b_di[14]), .DI15(sram_b_di[15]),   
    .DI16(sram_b_di[16]),  .DI17(sram_b_di[17]),  .DI18(sram_b_di[18]),   .DI19(sram_b_di[19]),  .DI20(sram_b_di[20]), .DI21(sram_b_di[21]),  .DI22(sram_b_di[22]), .DI23(sram_b_di[23]),   
    .DI24(sram_b_di[24]),  .DI25(sram_b_di[25]),  .DI26(sram_b_di[26]),   .DI27(sram_b_di[27]),  .DI28(sram_b_di[28]), .DI29(sram_b_di[29]),  .DI30(sram_b_di[30]), .DI31(sram_b_di[31]),   
    .DI32(sram_b_di[32]),  .DI33(sram_b_di[33]),  .DI34(sram_b_di[34]),   .DI35(sram_b_di[35]),  .DI36(sram_b_di[36]), .DI37(sram_b_di[37]),  .DI38(sram_b_di[38]), .DI39(sram_b_di[39]),   
    .DI40(sram_b_di[40]),  .DI41(sram_b_di[41]),  .DI42(sram_b_di[42]),   .DI43(sram_b_di[43]),  .DI44(sram_b_di[44]), .DI45(sram_b_di[45]),  .DI46(sram_b_di[46]), .DI47(sram_b_di[47]),  
    .DI48(sram_b_di[48]),  .DI49(sram_b_di[49]),  .DI50(sram_b_di[50]),   .DI51(sram_b_di[51]),  .DI52(sram_b_di[52]), .DI53(sram_b_di[53]),  .DI54(sram_b_di[54]), .DI55(sram_b_di[55]),   
    .DI56(sram_b_di[56]),  .DI57(sram_b_di[57]),  .DI58(sram_b_di[58]),   .DI59(sram_b_di[59]),  .DI60(sram_b_di[60]), .DI61(sram_b_di[61]),  .DI62(sram_b_di[62]), .DI63(sram_b_di[63]),
    .CK(clk), .WEB(sram_b_w),   .OE(1'b1), .CS(1'b1)
    );

//==============================================//
//                    OUTPUT                    //
//==============================================//

// DRAM WRITE
always @(*) begin
	case(cur_dram)
		D_AW: begin
			wdata_write_comb[0] = {sram_b_do,sram_a_do};
			wdata_write_comb[1] = 0;
		end
		D_W: begin
			if(wready_m_inf) begin
				wdata_write_comb[0] = wdata_write[1];
				wdata_write_comb[1] = {sram_b_do,sram_a_do};
			end else begin
				wdata_write_comb[0] = wdata_write[0];
				wdata_write_comb[1] = {sram_b_do,sram_a_do};
			end
		end
		default:  begin
			wdata_write_comb[0] = 0;
			wdata_write_comb[1] = 0;
		end
	endcase
end

always @(posedge clk) begin
	wdata_write <= wdata_write_comb;
end

genvar w_i;
generate
	for(w_i=0;w_i<16;w_i=w_i+1) begin
		always @(*) begin
			if(!(retrace_x == sinkX_ff[0] && retrace_y == sinkY_ff[0])) begin
				if(retrace_x[4])
					weight_comb[w_i] = sram_a_do[w_i*4+:4];
				else
					weight_comb[w_i] = sram_b_do[w_i*4+:4];
			end else
				weight_comb[w_i] = 0;
		end
	end
endgenerate

always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		weight <= 0;
	else
		weight <= weight_comb[retrace_x[3:0]];
end

always @(*) begin
	case(cur_state)
		S_READ_LMAP: cost_comb = 0;
		S_RETRACE: begin
			if(cnt_retrace[0])
				cost_comb = cost + weight;
			else
				cost_comb = cost;
		end
		default: cost_comb = cost;
	endcase
end

always @(posedge clk or negedge rst_n) begin
   if(!rst_n)
      cost <= 0;
   else
      cost <= cost_comb;
end

// busy 
always @(*) begin
	if(cur_state != S_IDLE && !in_valid) 
		busy_comb = 1;
	else                                
		busy_comb = 0;
end

always @(posedge clk or negedge rst_n) begin
   if(!rst_n)
      busy <= 0;
   else
      busy <= busy_comb;
end

endmodule
