module FIFO_syn #(parameter WIDTH=8, parameter WORDS=64) (
    wclk,
    rclk,
    rst_n,
    winc,
    wdata,
    wfull,
    rinc,
    rdata,
    rempty,

    flag_fifo_to_clk2,
    flag_clk2_to_fifo,

    flag_fifo_to_clk1,
	flag_clk1_to_fifo
);

input wclk, rclk;
input rst_n;
input winc;
input [WIDTH-1:0] wdata;
output reg wfull;
input rinc;
output reg [WIDTH-1:0] rdata;
output reg rempty;

// You can change the input / output of the custom flag ports
output  flag_fifo_to_clk2;
input flag_clk2_to_fifo;

output flag_fifo_to_clk1;
input flag_clk1_to_fifo;

wire [WIDTH-1:0] rdata_q;

// Remember: 
//   wptr and rptr should be gray coded
//   Don't modify the signal name
reg [$clog2(WORDS):0] wptr;
reg [$clog2(WORDS):0] rptr;

reg  [6:0] waddr, raddr;
wire [6:0] waddr_comb, raddr_comb;

wire [$clog2(WORDS):0] wptr_comb, rptr_comb;
wire [$clog2(WORDS):0] wptr_r, rptr_w;

wire wfull_comb, rempty_comb;

wire wean;

//==============================================//
//                 wclk domain                  //
//==============================================//

assign flag_fifo_to_clk2 = wfull_comb;

// waddr
assign waddr_comb = (winc & (~wfull)) ? (waddr + 1) : waddr;

always @(posedge wclk, negedge rst_n) begin
    if (!rst_n)
        waddr <= 0;
    else 
        waddr <= waddr_comb;
end

// wptr (gray code counter)
assign wptr_comb = (waddr_comb >> 1) ^ waddr_comb;

always @(posedge wclk, negedge rst_n) begin
    if (!rst_n)
        wptr <= 0;
    else 
        wptr <= wptr_comb;
end

// rptr in wclk domain
NDFF_BUS_syn #(.WIDTH(7)) NDFF_BUS_SYN_R2W(.D(rptr),.Q(rptr_w),.clk(wclk),.rst_n(rst_n));

// wfull
assign wfull_comb = ({~wptr_comb[$clog2(WORDS):$clog2(WORDS)-1],wptr_comb[$clog2(WORDS)-2:0]} == rptr_w);

always @(posedge wclk, negedge rst_n) begin
    if (!rst_n)
        wfull <= 0;
    else 
        wfull <= wfull_comb;
end

assign wean = ~(~wfull & winc);

//==============================================//
//                 rclk domain                  //
//==============================================//

// raddr
assign raddr_comb = (rinc & (~rempty)) ? (raddr + 1) : raddr;

always @(posedge rclk, negedge rst_n) begin
    if (!rst_n)
        raddr <= 0;
    else 
        raddr <= raddr_comb;
end

// rptr (gray code counter)
assign rptr_comb = (raddr_comb >> 1) ^ raddr_comb;

always @(posedge rclk, negedge rst_n) begin
    if (!rst_n)
        rptr <= 0;
    else 
        rptr <= rptr_comb;
end

// wptr in rclk domain
NDFF_BUS_syn #(.WIDTH(7)) NDFF_BUS_SYN_W2R(.D(wptr),.Q(wptr_r),.clk(rclk),.rst_n(rst_n));

// rempty
assign rempty_comb = (rptr_comb == wptr_r);

always @(posedge rclk, negedge rst_n) begin
    if (!rst_n)
        rempty <= 1;
    else 
        rempty <= rempty_comb;
end

// rdata
//  Add one more register stage to rdata
always @(posedge rclk, negedge rst_n) begin
    if (!rst_n) begin
        rdata <= 0;
    end
    else begin
		rdata <= rdata_q;
    end
end

//==============================================//
//                     SRAM                     //
//==============================================//

DUAL_64X8X1BM1 u_dual_sram (
    .CKA(wclk),
    .CKB(rclk),
    .WEAN(wean),
    .WEBN(1'b1),
    .CSA(1'b1),
    .CSB(1'b1),
    .OEA(1'b1),
    .OEB(1'b1),
    .A0(waddr[0]),
    .A1(waddr[1]),
    .A2(waddr[2]),
    .A3(waddr[3]),
    .A4(waddr[4]),
    .A5(waddr[5]),
    .B0(raddr[0]),
    .B1(raddr[1]),
    .B2(raddr[2]),
    .B3(raddr[3]),
    .B4(raddr[4]),
    .B5(raddr[5]),
    .DIA0(wdata[0]),
    .DIA1(wdata[1]),
    .DIA2(wdata[2]),
    .DIA3(wdata[3]),
    .DIA4(wdata[4]),
    .DIA5(wdata[5]),
    .DIA6(wdata[6]),
    .DIA7(wdata[7]),
    .DIB0(1'b0),
    .DIB1(1'b0),
    .DIB2(1'b0),
    .DIB3(1'b0),
    .DIB4(1'b0),
    .DIB5(1'b0),
    .DIB6(1'b0),
    .DIB7(1'b0),
    .DOB0(rdata_q[0]),
    .DOB1(rdata_q[1]),
    .DOB2(rdata_q[2]),
    .DOB3(rdata_q[3]),
    .DOB4(rdata_q[4]),
    .DOB5(rdata_q[5]),
    .DOB6(rdata_q[6]),
    .DOB7(rdata_q[7])
);


endmodule
