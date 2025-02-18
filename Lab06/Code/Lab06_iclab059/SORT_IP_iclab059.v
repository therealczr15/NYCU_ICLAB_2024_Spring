//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//    (C) Copyright System Integration and Silicon Implementation Laboratory
//    All Right Reserved
//      Date        : 2023/10
//      Version     : v1.0
//      File Name   : SORT_IP.v
//      Module Name : SORT_IP
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################
module SORT_IP #(parameter IP_WIDTH = 8) (
    // Input signals
    IN_character, IN_weight,
    // Output signals
    OUT_character
);

// ===============================================================
// Input & Output
// ===============================================================
input [IP_WIDTH*4-1:0]  IN_character;
input [IP_WIDTH*5-1:0]  IN_weight;

output [IP_WIDTH*4-1:0] OUT_character;

// ===============================================================
// Design
// ===============================================================
wire [4:0] in_w[0:7];
wire [3:0] in_c[0:7];
wire [3:0] out_c[0:7];
reg  [8:0] sort[IP_WIDTH-1:0];

integer i, j, k;
generate
    always @(*) begin 
        for(i=0;i<IP_WIDTH;i=i+1) begin
            sort[i] = {IN_character[i*4+:4],IN_weight[i*5+:5]};
        end

        for(j=0;j<IP_WIDTH;j=j+1) begin
            for(k=IP_WIDTH-1;k>j;k=k-1) begin
                if(sort[k][4:0] < sort[k-1][4:0]) begin
                    {sort[k],sort[k-1]} = {sort[k-1],sort[k]};
                end
            end
        end
        
    end
endgenerate

genvar l;
generate
    for(l=0;l<IP_WIDTH;l=l+1) begin
        assign OUT_character[l*4+:4] = sort[l][8:5];
    end
endgenerate

endmodule