`timescale 1ns / 1ps

module mac_array(
  input clk, 
  input rstn, 
  input vld_i,
  input is_CONV00,
  input is_1x1,

  input [127:0] win_0, 
  input [127:0] win_1,
  input [127:0] win_2, 
  input [127:0] win_3,
  input [127:0] win_4, 
  input [127:0] win_5,
  input [127:0] win_6, 
  input [127:0] win_7,
  input [127:0] win_8,

  input [127:0] din_0, 
  input [127:0] din_1,
  input [127:0] din_2, 
  input [127:0] din_3,
  input [127:0] din_4, 
  input [127:0] din_5,
  input [127:0] din_6, 
  input [127:0] din_7,
  input [127:0] din_8,

  output reg [ 28:0] acc_o_0, 
  output reg [ 28:0] acc_o_1, 
  output reg [ 28:0] acc_o_2, 
  output reg [ 28:0] acc_o_3,
  output reg [ 28:0] acc_o_4, 
  output reg [ 28:0] acc_o_5, 
  output reg [ 28:0] acc_o_6, 
  output reg [ 28:0] acc_o_7, 
  output reg         vld_o
);

wire [19:0] mac_out [0:8]; 
wire [ 8:0] mvld_o;

mac u_mac_0 (
  .clk   (clk   ), 
  .rstn  (rstn  ), 
  .vld_i (vld_i ), 
  .win   (win_0), 
  .din   (din_0),
  .acc_o (mac_out[0]),
  .vld_o (mvld_o[0])
);

mac u_mac_1 (
  .clk   (clk   ), 
  .rstn  (rstn  ), 
  .vld_i (vld_i ), 
  .win   (win_1), 
  .din   (din_1),
  .acc_o (mac_out[1]),
  .vld_o (mvld_o[1])
);

mac u_mac_2 (
  .clk   (clk   ), 
  .rstn  (rstn  ), 
  .vld_i (vld_i ), 
  .win   (win_2), 
  .din   (din_2),
  .acc_o (mac_out[2]),
  .vld_o (mvld_o[2])
);

mac u_mac_3 (
  .clk   (clk   ), 
  .rstn  (rstn  ), 
  .vld_i (vld_i ), 
  .win   (win_3), 
  .din   (din_3),
  .acc_o (mac_out[3]),
  .vld_o (mvld_o[3])
);

mac u_mac_4 (
  .clk   (clk   ), 
  .rstn  (rstn  ), 
  .vld_i (vld_i ), 
  .win   (win_4), 
  .din   (din_4),
  .acc_o (mac_out[4]),
  .vld_o (mvld_o[4])
);

mac u_mac_5 (
  .clk   (clk   ), 
  .rstn  (rstn  ), 
  .vld_i (vld_i ), 
  .win   (win_5), 
  .din   (din_5),
  .acc_o (mac_out[5]),
  .vld_o (mvld_o[5])
);

mac u_mac_6 (
  .clk   (clk   ), 
  .rstn  (rstn  ), 
  .vld_i (vld_i ), 
  .win   (win_6), 
  .din   (din_6),
  .acc_o (mac_out[6]),
  .vld_o (mvld_o[6])
);

mac u_mac_7 (
  .clk   (clk   ), 
  .rstn  (rstn  ), 
  .vld_i (vld_i ), 
  .win   (win_7), 
  .din   (din_7),
  .acc_o (mac_out[7]),
  .vld_o (mvld_o[7])
);
mac u_mac_8 (
  .clk   (clk   ), 
  .rstn  (rstn  ), 
  .vld_i (vld_i ), 
  .win   (win_8), 
  .din   (din_8),
  .acc_o (mac_out[8]),
  .vld_o (mvld_o[8])
);

always @ (*) begin
  if (is_CONV00) begin
    acc_o_0 = $signed(mac_out[0]) + $signed(mac_out[1]);
    acc_o_1 = $signed(mac_out[2]) + $signed(mac_out[3]);
    acc_o_2 = $signed(mac_out[4]) + $signed(mac_out[5]);
    acc_o_3 = $signed(mac_out[6]) + $signed(mac_out[7]);
    acc_o_4 = 1'b0;
    acc_o_5 = 1'b0;
    acc_o_6 = 1'b0;
    acc_o_7 = 1'b0;

    vld_o = &mvld_o;
    
  end else if (is_1x1) begin
    acc_o_0 = $signed(mac_out[0]);
    acc_o_1 = $signed(mac_out[1]);
    acc_o_2 = $signed(mac_out[2]);
    acc_o_3 = $signed(mac_out[3]);
    acc_o_4 = $signed(mac_out[4]);
    acc_o_5 = $signed(mac_out[5]);
    acc_o_6 = $signed(mac_out[6]);
    acc_o_7 = $signed(mac_out[7]);

    vld_o = &mvld_o;

  end else begin
    acc_o_0 = $signed(mac_out[0]) + $signed(mac_out[1]) + $signed(mac_out[2]) + 
              $signed(mac_out[3]) + $signed(mac_out[4]) + $signed(mac_out[5]) + 
              $signed(mac_out[6]) + $signed(mac_out[7]) + $signed(mac_out[8]);
    acc_o_1 = 1'b0;
    acc_o_2 = 1'b0;
    acc_o_3 = 1'b0;
    acc_o_4 = 1'b0;
    acc_o_5 = 1'b0;
    acc_o_6 = 1'b0;
    acc_o_7 = 1'b0;

    vld_o = &mvld_o;
  end
end

endmodule
