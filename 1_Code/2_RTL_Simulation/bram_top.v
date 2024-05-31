`timescale 1ns / 1ps
module bram_top (
    input                   clk,
    input                   rstn,

    input [4:0]             layer_cnt,

    // unused
    // input [3:0]             Tr,
    // input [3:0]             Tc,
    // input [4:0]             Ti,
    // input [3:0]             To,
    input [15:0]            Ni,
    // input [15:0]            No,
    input [16-1:0]          IFM_HEIGHT,
    input [16-1:0]          IFM_WIDTH,

    input                   ready_w,
    input                   ready_b,
    input                   ready_f,

    input [256-1:0]         ofm_input, // need to update for 1x1 conv //conv00 or ofm
    input [32-1:0]          DMA_input,
    input [1:0]             DMA_which_input // 00 : weight, 01 : bias, 02 : ifm

    input                   ofm_i_v,
    input                   DMA_i_v,


    output  [16*8-1:0]      weight_o0,
    output  [16*8-1:0]      weight_o1,
    output  [16*8-1:0]      weight_o2,
    output  [16*8-1:0]      weight_o3,
    output  [16*8-1:0]      weight_o4,
    output  [16*8-1:0]      weight_o5,
    output  [16*8-1:0]      weight_o6,
    output  [16*8-1:0]      weight_o7,
    output  [16*8-1:0]      weight_o8,
    output  [2*2*32*8-1:0]  ifm_o,
    output  [32*8-1:0]      bias_o,
    output reg              valid_w,
    output reg              valid_b,
    output reg              valid_f
);

localparam BRAM_ADDR_BITS = 12;
localparam BRAM_BIAS_ADDR_BITS = 9;
localparam BRAM_DATA_WIDTH = 1152;
localparam BRAM_BIAS_DATA_WIDTH = 32;
localparam WEIGHT_COUNTER_BITS = 13; // need to update
localparam IFM_COUNTER_BITS = 13; // need to update
localparam BIAS_COUNTER_BITS = 13; // need to update
localparam PADDING_SIZE = 1;
localparam CHANNEL_PER_LINE  = 32; // except conv00 conv02
localparam IFM_HEIGHT_PER_LINE = 2; // except conv00 conv02?
localparam IFM_WIDTH_PER_LINE = 2; // except conv00 conv02?
localparam DMA_WEIGHT = 0;
localparam DMA_BIAS = 1;
localparam DMA_IFM = 2;


reg [4:0]                           layer_num_pre_cycle;
wire                                layer_changed;

reg [BRAM_ADDR_BITS-1:0]           weight_i_start_addr;
reg [BRAM_ADDR_BITS-1:0]           ifm_i_start_addr;
reg [BRAM_BIAS_ADDR_BITS-1:0]      bias_i_start_addr;
reg [BRAM_ADDR_BITS-1:0]           weight_i_end_addr;
reg [BRAM_ADDR_BITS-1:0]           ifm_i_end_addr;
reg [BRAM_BIAS_ADDR_BITS-1:0]      bias_i_end_addr;
reg                                weight_i_which_bram;
reg [BRAM_ADDR_BITS-1:0]           weight_o_start_addr;
reg [BRAM_ADDR_BITS-1:0]           ifm_o_start_addr;
reg [BRAM_BIAS_ADDR_BITS-1:0]      bias_o_start_addr;

reg                                weight_o_which_bram;

reg [WEIGHT_COUNTER_BITS-1:0]      max_weight_counter;
reg [IFM_COUNTER_BITS-1:0]         max_ifm_counter;
reg [BIAS_COUNTER_BITS-1:0]        max_bias_counter;

reg [WEIGHT_COUNTER_BITS-1:0]       weight_i_counter; 
reg [IFM_COUNTER_BITS-1:0]          ifm_i_counter; 
reg [BIAS_COUNTER_BITS-1:0]         bias_i_counter; 
wire [BRAM_ADDR_BITS-1:0]           weight_i_addr_offset;
wire [BRAM_ADDR_BITS-1:0]           ifm_i_addr_offset;
wire [BRAM_BIAS_ADDR_BITS-1:0]      bias_i_addr_offset;

wire [BRAM_ADDR_BITS-1:0]           weight_i_addr;
wire [BRAM_ADDR_BITS-1:0]           ofm_i_addr;
wire [BRAM_BIAS_ADDR_BITS-1:0]      bias_i_addr;

reg  [1:0]                          DMA_which_input_delayed;
reg                                 DMA_input_valid_delayed;      

reg [1024-1:0]                      ofm_i_buffer;
reg [1152-1:0]                      weight_i_buffer;

reg [WEIGHT_COUNTER_BITS-1:0]       weight_o_counter; 
reg [IFM_COUNTER_BITS-1:0]          ifm_o_counter; 
reg [BIAS_COUNTER_BITS-1:0]         bias_o_counter; 
wire [BRAM_ADDR_BITS-1:0]           weight_o_addr_offset;
wire [BRAM_ADDR_BITS-1:0]           ifm_o_addr_offset;
wire [BRAM_BIAS_ADDR_BITS-1:0]      bias_o_addr_offset;

wire [BRAM_ADDR_BITS-1:0]           weight_o_addr;
wire [BRAM_ADDR_BITS-1:0]           ifm_o_addr;
wire [BRAM_BIAS_ADDR_BITS-1:0]      bias_o_addr;

reg                                 ready_w_t0;
reg                                 ready_w_t1;
reg                                 ready_f_t0;
reg                                 ready_f_t1;
reg                                 ready_b_t0;
reg                                 ready_b_t1;

wire                                bram0_ena;
wire                                bram0_wea;
wire [BRAM_ADDR_BITS-1:0]           bram0_addra;
wire [BRAM_DATA_WIDTH-1:0]          bram0_dia;
wire [BRAM_DATA_WIDTH-1:0]          bram0_doa;
wire                                bram0_enb;
wire                                bram0_web;
wire [BRAM_ADDR_BITS-1:0]           bram0_addrb;
wire [BRAM_DATA_WIDTH-1:0]          bram0_dib;
wire [BRAM_DATA_WIDTH-1:0]          bram0_dob; 
wire                                bram1_ena;
wire                                bram1_wea;
wire [BRAM_ADDR_BITS-1:0]           bram1_addra;
wire [BRAM_DATA_WIDTH-1:0]          bram1_dia;
wire [BRAM_DATA_WIDTH-1:0]          bram1_doa;
wire                                bram1_enb;
wire                                bram1_web;
wire [BRAM_ADDR_BITS-1:0]           bram1_addrb;
wire [BRAM_DATA_WIDTH-1:0]          bram1_dib;
wire [BRAM_DATA_WIDTH-1:0]          bram1_dob;
wire                                bram_bias_ena;
wire                                bram_bias_wea;
wire [BRAM_BIAS_ADDR_BITS-1:0]      bram_bias_addra;
wire [BRAM_BIAS_DATA_WIDTH-1:0]     bram_bias_dia; //write_port
wire                                bram_bias_enb;
wire [BRAM_BIAS_ADDR_BITS-1:0]      bram_bias_addrb;
wire [BRAM_BIAS_DATA_WIDTH-1:0]     bram_bias_dob; //read_port

wire [9*16*8:0]                     weight_o;

//========================================
//Layer information
//========================================
always @(layer_cnt) begin
    case (layer_cnt)
        6: begin
            weight_i_start_addr <= 0; //temporal address
            ifm_i_start_addr <= 0; //temporal address
            bias_i_start_addr <= 0; //temporal address
            weight_i_end_addr <= 511; //temporal address
            ifm_i_end_addr <= 511; //temporal address
            bias_i_end_addr <= 127; //temporal address
            weight_i_which_bram <= 1;

            weight_o_start_addr <= 0; //temporal address
            ifm_o_start_addr <= 0; //temporal address
            bias_o_start_addr <= 0; //temporal address
            max_weight_counter <= 511;
            max_bias_counter <= 127;
            max_ifm_counter <= 1087;
            weight_o_which_bram <= 0;
        end
        default: ;
    endcase
end

//========================================
// Check layer num is changed
//========================================
always @(posedge clk) begin
    layer_num_pre_cycle <= layer_cnt;
end

assign layer_changed = (layer_num_pre_cycle != layer_cnt)? 1 : 0;

//========================================
// LOAD INPUT
//========================================

// DMA signals delay
always @(posedge clk, negedge rstn) begin
    if(!rstn) begin
        DMA_input_valid_delayed <= 0;
        DMA_which_input_delayed <= 0;
    end
    else begin
        DMA_input_valid_delayed <= DMA_i_v;
        DMA_which_input_delayed <= DMA_which_input;
    end
end

// Load Buffers
always @(posedge clk, negedge rstn) begin
    if(!rstn) begin
        ofm_i_buffer <= 1024'b0;
        weight_i_buffer <= 1152'b0;
    end
    else begin
        if(DMA_which_input == DMA_IFM && DMA_i_v) begin
            ofm_i_buffer[32*(ofm_i_counter%32)+:32] <= DMA_input;
        end
        else if(ofm_i_v) begin
            ofm_i_buffer[256*(ofm_i_counter)+:256] <= ofm_input;
        end

        if(DMA_which_input == DMA_WEIGHT && DMA_i_v) begin
            weight_i_buffer[32*(weight_i_counter%36)+:32] <= DMA_input;
        end
    end
end

//========================================
//assign output (only data, no valid) 
//========================================

//=============== IFM =================
wire [1024-1:0] ifm_from_BRAM;

reg [255:0]    data_in_f_0;
reg [255:0]    data_in_f_1;
reg [255:0]    data_in_f_2;
reg [255:0]    data_in_f_3;

wire            ifm_is_first_row;
wire            ifm_is_last_row;
wire            ifm_is_first_col;
wire            ifm_is_last_col;

wire [7:0]      channel_iter;
wire [7:0]      row_iter;
wire [7:0]      col_iter;

wire [9:0]      ifm_counter_wo_channel;
wire [6:0]      big_row;
wire [6:0]      ifm_counter_in_a_big_row;

wire [9:0]      ifm_row_0;
wire [9:0]      ifm_col_0;
wire [9:0]      ifm_row_1;
wire [9:0]      ifm_col_1;
wire [9:0]      ifm_row_2;
wire [9:0]      ifm_col_2;
wire [9:0]      ifm_row_3;
wire [9:0]      ifm_col_3;

reg [15:0] ifm_address;

assign ifm_from_BRAM = (weight_o_which_bram == 1)? bram0_dob : bram1_dob;

assign channel_iter = Ni/CHANNEL_PER_LINE;
assign row_iter = (IFM_HEIGHT+2*PADDING_SIZE)/IFM_HEIGHT_PER_LINE;
assign col_iter = (IFM_WIDTH+2*PADDING_SIZE)/IFM_WIDTH_PER_LINE;

assign ifm_counter_wo_channel = ifm_o_counter/channel_iter;
assign big_row = ifm_counter_wo_channel/(2*col_iter);
assign ifm_counter_in_a_big_row = ifm_counter_wo_channel - 2*col_iter*big_row;

assign ifm_row_0 = (ifm_counter_in_a_big_row[0])? 2*big_row-1+2 : 2*big_row-1; 
assign ifm_row_1 = (ifm_counter_in_a_big_row[0])? 2*big_row-1+2 : 2*big_row-1; 
assign ifm_row_2 = (ifm_counter_in_a_big_row[0])? 2*big_row+2 : 2*big_row; 
assign ifm_row_3 = (ifm_counter_in_a_big_row[0])? 2*big_row+2 : 2*big_row; 
assign ifm_col_0 = 2*(ifm_counter_in_a_big_row/2)-1;
assign ifm_col_1 = 2*(ifm_counter_in_a_big_row/2);
assign ifm_col_2 = 2*(ifm_counter_in_a_big_row/2)-1;
assign ifm_col_3 = 2*(ifm_counter_in_a_big_row/2);

assign ifm_is_first_row = (ifm_counter_in_a_big_row[0]==0)? (big_row ==0)? 1 : 0 : 0; 
assign ifm_is_last_row = (ifm_row_2 == IFM_HEIGHT)? 1 : 0;
assign ifm_is_first_col = (ifm_counter_in_a_big_row == 0)? 1 : (ifm_counter_in_a_big_row == 1)? 1 : 0;
assign ifm_is_last_col = (ifm_counter_in_a_big_row == (col_iter-1)*2)? 1 : (ifm_counter_in_a_big_row == (col_iter-1)*2+1)? 1 : 0;

assign ifm_address_0 = ((ifm_row_0 * IFM_WIDTH + ifm_col_0)*Ni)/128 + (ifm_counter_t2%channel_iter)*8; 
assign ifm_address_1 = (ifm_row_1 * IFM_WIDTH + ifm_col_1)*(Ni/4) + (ifm_counter_t2%channel_iter)*8; 
assign ifm_address_2 = (ifm_row_2 * IFM_WIDTH + ifm_col_2)*(Ni/4) + (ifm_counter_t2%channel_iter)*8; 
assign ifm_address_3 = (ifm_row_3 * IFM_WIDTH + ifm_col_3)*(Ni/4) + (ifm_counter_t2%channel_iter)*8; 

//===========================================
// TODO
//===========================================

// reg [1:0] ifm_position_counter;
// wire ifm_done_next_ifm; // ifm_done_next_ifm = 1, then valid = 1 and ifm_o_counter incresase

// always @(posedge clk, negedge rstn) begin
//     if(!rstn) begin
//         ifm_position_counter <= 0;        
//     end
//     else begin
//         if(ifm_position_counter == 2'b0 && ) begin
//             // ifm_address <= ((ifm_row_0 * IFM_WIDTH + ifm_col_0)*Ni)/128 + (ifm_counter%channel_iter)*8; // ?? before 
//             ifm_address <= ((ifm_row_0 * IFM_WIDTH + ifm_col_0)*Ni)/128 + (ifm_counter%channel_iter)/(128/CHANNEL_PER_LINE); // after 
//             ifm_position_counter <= ifm_position_counter + 1;
//         end
//         else if(ifm_position_counter == 2'b1) begin
            
//         end
//         else if(ifm_position_counter == 2'b2) begin
            
//         end
//         else if(ifm_position_counter == 2'b3) begin
            
//             if(BRAM_delay_counter_ifm == 3'b5) begin
//                 ifm_position_counter <= 2'b0;
//             end
//         end
//     end
// end
// reg [2:0] BRAM_delay_counter_ifm;

// always @(posedge clk, negedge rstn) begin
//     if(!rstn) begin
        
//     end
//     else begin
//         if(ifm_position_counter == 2'b0) BRAM_delay_counter_ifm <= 3'b0;
//         else BRAM_delay_counter_ifm <= BRAM_delay_counter_ifm + 1;
        
//         if(BRAM_delay_counter_ifm == 3'b2) begin
//             if(ifm_is_first_col || ifm_is_first_row) data_in_f_0 <= 256'b0;
//             else data_in_f_0 <= ifm_from_BRAM[] //32 개를 챙겨가
//         end
//     end
// end
assign data_in_f_0 = (ifm_is_first_row || ifm_is_first_col)? 256'b0 : ifm_from_BRAM[256-1:0];
assign data_in_f_1 = (ifm_is_first_row || ifm_is_last_col )? 256'b0 : ifm_from_BRAM[512-1:256];
assign data_in_f_2 = (ifm_is_last_row  || ifm_is_first_col)? 256'b0 : ifm_from_BRAM[768-1:512];
assign data_in_f_3 = (ifm_is_last_row  || ifm_is_last_col )? 256'b0 : ifm_from_BRAM[1024-1:768];
//========================================

//=============== weight =================
assign weight_o = (weight_o_which_bram == 0)? bram0_dob : bram1_dob;
//========================================

assign weight_o0 = weight_o[128-1:0];
assign weight_o1 = weight_o[256-1:128];
assign weight_o2 = weight_o[384-1:256];
assign weight_o3 = weight_o[512-1:384];
assign weight_o4 = weight_o[640-1:512];
assign weight_o5 = weight_o[768-1:640];
assign weight_o6 = weight_o[896-1:768];
assign weight_o7 = weight_o[1024-1:896];
assign weight_o8 = weight_o[1152-1:1024];
assign ifm_o = {data_in_f_3,data_in_f_2,data_in_f_1,data_in_f_0};
assign bias_o = bram_bias_dob;


//========================================
//BRAM I/O counter & addresses update
//========================================
always @(posedge clk, negedge rstn) begin
    if(!rstn) begin 
        weight_i_counter <= 0;
        ofm_i_counter <= 0;
        bias_i_counter <= 0;
        weight_o_counter <= 0;
        ifm_o_counter <= 0;
        bias_o_counter <= 0;
    end

    else begin
        if(layer_changed) begin 
            weight_i_counter <= 0;
            ofm_i_counter <= 0;
            bias_i_counter <= 0;
            weight_o_counter <= 0;
            ifm_o_counter <= 0;
            bias_o_counter <= 0;
        end
        else begin
            if(DMA_which_input == DMA_WEIGHT && weight_i_v) begin
                weight_i_counter <= weight_i_counter + 1;
            end
            if(DMA_which_input == DMA_IFM && ifm_i_v || ofm_i_v) begin
                if(ofm_i_v && ofm_i_counter == 3) begin
                    ofm_i_counter <= 0;
                end
                else begin
                    ofm_i_counter <= ofm_i_counter + 1;
                end
            end 
            if(DMA_which_input == DMA_BIAS && bias_i_v) begin
                bias_i_counter <= bias_i_counter + 1;
            end 

            if(ready_w) begin // counter increment condition 
                if(weight_o_counter < max_weight_counter) weight_o_counter <= weight_o_counter + 1;
                else weight_o_counter <= 0;
            end
            else if(ready_w_t0) begin
                weight_o_counter <= weight_o_counter_t2;
            end 
            if(ready_b) begin
                if(bias_o_counter < max_bias_counter) bias_o_counter <= bias_o_counter + 1;
                else bias_o_counter <= 0;
            end 
            else if(ready_b_t0) begin
                bias_o_counter <= bias_o_counter_t2;
            end
            if(ready_f) begin // counter increment condition
                if(ifm_o_counter < max_ifm_counter) ifm_o_counter <= ifm_o_counter +1;
            end 
            else if(ready_f_t0) begin
                ifm_o_counter <= ifm_o_counter_t2;
            end
        end
    end
end

// Input Address
assign weight_i_addr_offset = weight_i_counter / 36;
assign bias_i_addr_offset = bias_i_counter;
assign ifm_i_addr_offset = ifm_i_counter >>> 5;

assign weight_i_addr = weight_i_start_addr + weight_i_addr_offset;
assign bias_i_addr = bias_i_start_addr + bias_i_addr_offset;
assign ifm_i_addr = ifm_i_start_addr + ifm_i_addr_offset;

// Output Address

reg [WEIGHT_COUNTER_BITS-1:0]       weight_o_counter_t0; 
reg [IFM_COUNTER_BITS-1:0]          ifm_o_counter_t0; 
reg [BIAS_COUNTER_BITS-1:0]         bias_o_counter_t0; 
reg [WEIGHT_COUNTER_BITS-1:0]       weight_o_counter_t1; 
reg [IFM_COUNTER_BITS-1:0]          ifm_o_counter_t1; 
reg [BIAS_COUNTER_BITS-1:0]         bias_o_counter_t1; 
reg [WEIGHT_COUNTER_BITS-1:0]       weight_o_counter_t2; 
reg [IFM_COUNTER_BITS-1:0]          ifm_o_counter_t2; 
reg [BIAS_COUNTER_BITS-1:0]         bias_o_counter_t2;

always @(posedge clk, negedge rstn) begin
    if(!rstn) begin
        weight_o_counter_t0 <=0; 
        ifm_o_counter_t0 <=0; 
        bias_o_counter_t0 <=0; 
        weight_o_counter_t1 <=0; 
        ifm_o_counter_t1 <=0; 
        bias_o_counter_t1 <=0; 
        weight_o_counter_t2 <=0; 
        ifm_o_counter_t2 <=0; 
        bias_o_counter_t2 <=0;
    end
    else begin
        weight_o_counter_t0 <= weight_o_counter; 
        ifm_o_counter_t0 <= ifm_o_counter; 
        bias_o_counter_t0 <= bias_o_counter; 

        weight_o_counter_t1 <= weight_o_counter_t0; 
        ifm_o_counter_t1 <= ifm_o_counter_t0; 
        bias_o_counter_t1 <= bias_o_counter_t0; 

        weight_o_counter_t2 <= weight_o_counter_t1; 
        ifm_o_counter_t2 <= ifm_o_counter_t1; 
        bias_o_counter_t2 <= bias_o_counter_t1;
    end
end

assign weight_o_addr_offset = weight_o_counter;
assign ifm_o_addr_offset = 000000000; // to do
assign bias_o_addr_offset = bias_o_counter >> 1;

assign weight_o_addr = weight_o_start_addr + weight_o_addr_offset;
assign ifm_o_addr = ifm_o_start_addr + ifm_o_addr_offset;
assign bias_o_addr = bias_o_start_addr + bias_o_addr_offset;


//========================================
// BRAM WIRES
//========================================
assign bram0_ena = (weight_i_which_bram == 0)? DMA_input_valid_delayed && (DMA_which_input_delayed == DMA_WEIGHT) && (weight_i_counter % 36 == 0) : DMA_input_valid_delayed && (DMA_which_input_delayed == DMA_IFM) && (ofm_i_counter % 32 == 0);
assign bram0_wea = (weight_i_which_bram == 0)? DMA_input_valid_delayed && (DMA_which_input_delayed == DMA_WEIGHT) && (weight_i_counter % 36 == 0) : DMA_input_valid_delayed && (DMA_which_input_delayed == DMA_IFM) && (ofm_i_counter % 32 == 0);
assign bram0_addra = (weight_i_which_bram == 0)? weight_i_addr : ofm_i_addr;
assign bram0_dia = (weight_i_which_bram == 0)? weight_i_buffer : {128'b0, ofm_i_buffer};

assign bram0_enb = (weight_o_which_bram == 0)? ready_w : ready_f;
assign bram0_web = 0;
assign bram0_addrb = (weight_i_which_bram == 0)? weight_o_addr : ifm_o_addr;
//assign bram0_dib = 

assign bram1_ena = (weight_i_which_bram == 1)? DMA_input_valid_delayed && (DMA_which_input_delayed == DMA_WEIGHT) && (weight_i_counter % 36 == 0) : DMA_input_valid_delayed && (DMA_which_input_delayed == DMA_IFM) && (ofm_i_counter % 32 == 0);
assign bram1_wea = (weight_i_which_bram == 1)? DMA_input_valid_delayed && (DMA_which_input_delayed == DMA_WEIGHT) && (weight_i_counter % 36 == 0) : DMA_input_valid_delayed && (DMA_which_input_delayed == DMA_IFM) && (ofm_i_counter % 32 == 0);
assign bram1_addra = (weight_i_which_bram == 1)? weight_i_addr : ofm_i_addr;
assign bram1_dia = (weight_i_which_bram == 1)? weight_i_buffer : {128'b0, ofm_i_buffer};

assign bram1_enb = (weight_i_which_bram == 1)? ready_w : ready_f;
assign bram1_web = 0;
assign bram1_addrb = (weight_i_which_bram == 1)? weight_o_addr : ifm_o_addr;
//assign bram1_dia = 

assign bram_bias_ena = bias_i_v;
assign bram_bias_wea = bias_i_v;
assign bram_bias_addra = bias_i_addr;
assign bram_bias_dia = DMA_input;

assign bram_bias_enb = ready_b;
assign bram_bias_addrb = bias_o_addr;

//========================================
// VALID DELAY
//========================================
always @(posedge clk, negedge rstn) begin
    if(!rstn) begin
        ready_w_t0 <= 0;
        ready_w_t1 <= 0;
        ready_f_t0 <= 0;
        ready_f_t1 <= 0;
        ready_b_t0 <= 0;
        ready_b_t1 <= 0;
    end
    else begin
        if(ready_w) begin
            ready_w_t0 <= ready_w;
            ready_w_t1 <= ready_w_t0;
            valid_w <= ready_w_t1;
        end
        else begin
            ready_w_t0 <= 0;
            ready_w_t1 <= 0;
            valid_w <= 0;
        end
        if(ready_b) begin
            ready_b_t0 <= ready_b;
            ready_b_t1 <= ready_b_t0;
            valid_b <= ready_b_t1;
        end
        else begin
            ready_b_t0 <= 0;
            ready_b_t1 <= 0;
            valid_b <= 0;
        end
        if(ready_f) begin
            ready_f_t0 <= ready_f;
            ready_f_t1 <= ready_f_t0;
            valid_f <= ready_f_t1;
        end
        else begin
            ready_f_t0 <= 0;
            ready_f_t1 <= 0;
            valid_f <= 0;
        end
    end
end

//========================================
// BRAM
//========================================
dpram_2145x1152 bram_0_2100x1152 ( // size should be computed again
    .clka    (clk),
    .ena     (bram0_ena),
    .wea     (bram0_wea),
    .addra   (bram0_addra),
    .dina    (bram0_dia),
    .douta   (bram0_doa),

    .clkb    (clk),
    .enb     (bram0_enb),
    .web     (bram0_web),
    .addrb   (bram0_addrb),
    .dinb    (bram0_dib),
    .doutb   (bram0_dob)
);

dpram_2145x1152 bram_1_2100x1152 ( // size should be computed again
    .clka    (clk),
    .ena     (bram1_ena),
    .wea     (bram1_wea),
    .addra   (bram1_addra),
    .dina    (bram1_dia),
    .douta   (bram1_doa),

    .clkb    (clk),
    .enb     (bram1_enb),
    .web     (bram1_web),
    .addrb   (bram1_addrb),
    .dinb    (bram1_dib),
    .doutb   (bram1_dob)
);

dpram_384x32 bram_bias_384x32(
    .clka    (clk),
    .ena     (bram_bias_ena),
    .wea     (bram_bias_wea),
    .addra   (bram_bias_addra),
    .dina    (bram_bias_dia), //write port

    .clkb    (clk),
    .enb     (bram_bias_enb),
    .addrb   (bram_bias_addrb),
    .doutb   (bram_bias_dob) //read port
);

endmodule