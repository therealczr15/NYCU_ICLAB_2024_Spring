module Handshake_syn #(parameter WIDTH=8) (
    sclk,
    dclk,
    rst_n,
    sready,
    din,
    dbusy,
    sidle,
    dvalid,
    dout,

    flag_handshake_to_clk1,
    flag_clk1_to_handshake,

    flag_handshake_to_clk2,
    flag_clk2_to_handshake
);

input sclk, dclk;
input rst_n;
input sready;
input [WIDTH-1:0] din;
input dbusy;
output sidle;
output reg dvalid;
output reg [WIDTH-1:0] dout;

// You can change the input / output of the custom flag ports
output reg flag_handshake_to_clk1;
input flag_clk1_to_handshake;

output flag_handshake_to_clk2;
input flag_clk2_to_handshake;

// Remember:
//   Don't modify the signal name
reg sreq;
wire dreq;
reg dack;
wire sack;

reg  [WIDTH-1:0] data, data_comb;
reg  sreq_comb;

reg  dack_comb;
reg  [WIDTH-1:0] dout_comb;

reg  dvalid_ff;
wire dvalid_edge;
wire dvalid_comb;

//==============================================//
//                 sclk domain                  //
//==============================================//

// sreq
always @(posedge sclk or negedge rst_n) begin
    if(!rst_n) 
        sreq <= 0;
    else
        sreq <= sreq_comb;
end

always @(*) begin
    if(sack)
        sreq_comb = 0;
    else if(sready)
        sreq_comb = 1;
    else
        sreq_comb = sreq;
end

// dreq
NDFF_syn NDFF_SYN_S2D(.D(sreq),.Q(dreq),.clk(dclk),.rst_n(rst_n));

// sidle
assign sidle = ~(sreq | sack);

// data
always @(posedge sclk or negedge rst_n) begin
    if(!rst_n) 
        data <= 0;
    else
        data <= data_comb;
end

always @(*) begin
    if(sready)
        data_comb = din;
    else
        data_comb = data;
end

//==============================================//
//                 dclk domain                  //
//==============================================//

// dack
always @(posedge dclk or negedge rst_n) begin
    if(!rst_n) 
        dack <= 0;
    else
        dack <= dack_comb;
end

assign dack_comb = (dreq & (~dbusy));

// sack
NDFF_syn NDFF_SYN_D2S(.D(dack),.Q(sack),.clk(sclk),.rst_n(rst_n));

always @(*) begin
    flag_handshake_to_clk1 = sack;
end

// dout
always @(posedge dclk or negedge rst_n) begin
    if(!rst_n) 
        dout <= 0;
    else
        dout <= dout_comb;
end

always @(*) begin
    if(dvalid_edge)
        dout_comb = data;
    else
        dout_comb = 0;
end

// dvalid
always @(posedge dclk or negedge rst_n) begin
    if(!rst_n) 
        dvalid_ff <= 0;
    else
        dvalid_ff <= dvalid_comb;
end

assign dvalid_comb = (dreq & (~dbusy));

always @(posedge dclk or negedge rst_n) begin
    if(!rst_n) 
        dvalid <= 0;
    else
        dvalid <= dvalid_edge;
end

assign dvalid_edge = (dvalid_comb & (~dvalid_ff));

endmodule