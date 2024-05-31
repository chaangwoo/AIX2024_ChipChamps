`timescale 1ns / 1ps
module mul(
input clk, 
input [7:0] w, 
input [7:0] x, 
output[15:0] y
);
`include "define.v"
`ifdef FPGA    
	wire [17:0] dsp_A, dsp_B;
	wire [47:0] dsp_P;

	assign dsp_A = w[7]? {10'b11_1111_1111, w} : {10'b00_0000_0000, w};
	assign dsp_B = x[7]? {10'b11_1111_1111, x} : {10'b00_0000_0000, x};
	assign y = dsp_P[15:0];

	dsp_macro_0 u_dsp(.CLK(clk), .A(dsp_A), .B(dsp_B), .C(48'b0), .P(dsp_P));
`else 
	// Assume that i
	reg [15:0] dsp_P[0:3];
	always@(posedge clk) begin 
		// Multiplication with LUT
		dsp_P[0] <= $signed(w) * $signed(x);
		// Sync with dedicated DSP
		dsp_P[1] <= dsp_P[0];
		dsp_P[2] <= dsp_P[1];
		dsp_P[3] <= dsp_P[2];
	end 
	assign y = dsp_P[3];
`endif	
endmodule
