`timescale 1ns / 1ps
module conv_maxpool_module_tb();
`include "../../../sources_1/imports/src/define.v"

//==========================================
//VARIABLE
//==========================================
reg             clk;
reg             rstn;

wire            conv_start;

reg             valid_w;
reg             valid_b;
wire    [127:0] data_in_w0;
wire    [127:0] data_in_w1;
wire    [127:0] data_in_w2;
wire    [127:0] data_in_w3;
wire    [127:0] data_in_w4;
wire    [127:0] data_in_w5;
wire    [127:0] data_in_w6;
wire    [127:0] data_in_w7;
wire    [127:0] data_in_w8;
wire    [ 31:0] data_in_b; 

reg             valid_f;
wire    [1023:0]data_in_f;

//output
wire            conv_done;
wire             ready_w; 
wire             ready_b; 
wire             ready_f; 
wire            valid_o0;
wire            valid_o1;
wire    [255:0] data_out0;
wire    [255:0] data_out1;

reg ready_w_t0;
reg ready_w_t1;
reg ready_b_t0;
reg ready_b_t1;
reg ready_f_t0;
reg ready_f_t1;

reg [31:0] weight_register [80000:0];
reg [31:0] bias_register   [127:0];
reg [31:0] ifm_register    [80000:0];
reg [31:0] ofm_register    [0:65536-1];

reg        compare_flag;
reg [31:0] wrong_cnt;
reg [31:0] out_counter;
reg [31:0] answer          [0:65536-1];

//==========================================
//LOCALPARAMETER
//==========================================
integer HALF_CLK_PERIOD = 5;
integer NB_TB_KILLED = 200000;
localparam channel_num_per_ifm = 32;
localparam col_num_per_ifm = 2;
localparam row_num_per_ifm = 2;
localparam padding_size = 1;
localparam THRES = 10;

//==========================================
//TASK
//==========================================
task time_out;
begin
   repeat(NB_TB_KILLED) @(posedge clk);
   $display("[Info] time-out");
   $display("============================");
   $finish; 
end
endtask

task reset_dut;
begin
    rstn = 1'b1;
    repeat(1) @(posedge clk);
    rstn = 1'b0;
    repeat(1) @(posedge clk);
    rstn = 1'b1;
end
endtask

task read_weight;
begin
    //CONV06 ver.
    $readmemh(WGT_FILE,weight_register);
end
endtask

task read_bias;
begin
    //CONV06 ver.
    $readmemh(BIAS_FILE,bias_register);
end
endtask

task read_ifm;
begin
    //CONV06 ver.
    $readmemh(IFM_FILE,ifm_register);
end
endtask

task read_ans;
begin
    $readmemh(ANSWER_FILE,answer);
end
endtask

integer j;
task validate;
begin
    for (j = 0; j < OFM_DATA_SIZE / 4; j = j + 1) begin       
        if (ofm_register[j] != answer[j]) begin
            $display("\nResult is different at %0d th line!", j+1);
            $display("Expected value: %h", answer[j]);
            $display("Output value: %h\n", ofm_register[j]);
            
            compare_flag = 1'b0;
            wrong_cnt = wrong_cnt + 1;
            if (wrong_cnt == THRES) begin
                $display("Too many errors, only first %0d errors are printed.\n", THRES);
                j = OFM_DATA_SIZE / 4; // break the loop;
            end
        end
    end
end
endtask

//==========================================
//SYSTEM
//==========================================
initial begin
    clk =1'b1;
    forever #(HALF_CLK_PERIOD)  clk = ~clk;
end

//==========================================
//MAIN
//==========================================
initial begin
    compare_flag = 1;
    wrong_cnt = 0;

    time_out();
end

assign conv_start = 1;

initial begin
    $display("=============================");
    $display("[Info] Test Start!");
    
    reset_dut();

    read_weight(); 
    read_bias();
    read_ifm();

    wait(conv_done);

    read_ans();
    
    $display("\n=== Validation <IFM TILING> ===\n");
    $display ("Validation for layer %0d", LAYER_NUM);
	$display ("Loading answers from file: %s", ANSWER_FILE);

    validate();

    if (compare_flag) begin
        $display("\nResult is correct!\n");
    end
    
    $display("Validation done.\n");
    $finish;
end

always @(posedge clk, negedge rstn) begin
    if(!rstn) begin
        ready_w_t0 <= 0;
        ready_w_t1 <= 0;
        ready_b_t0 <= 0;
        ready_b_t1 <= 0;
        ready_f_t0 <= 0;
        ready_f_t1 <= 0;
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

reg [9:0] weight_counter;
reg [9:0] bias_counter;
reg [11:0] ifm_counter;

always @(posedge clk, negedge rstn) begin
    if(!rstn)
    begin
        weight_counter <= 0;       
        bias_counter <= 0;
        ifm_counter <= 0;
    end
    else begin
        if(ready_w) begin
            if(weight_counter < MAX_WEIGHT_COUNTER) weight_counter <= weight_counter + 1;
            else weight_counter <= 0;
        end
        else if(ready_w_t0) begin
            weight_counter <= weight_counter_t2;
        end
        if(ready_b) begin
            if(bias_counter < MAX_BIAS_COUNTER) bias_counter <= bias_counter + 1;
            else bias_counter <= 0;
        end
        else if(ready_b_t0) begin
            bias_counter <= bias_counter_t2;
        end
        if(ready_f) begin
            if(ifm_counter < MAX_IFM_COUNTER) ifm_counter <= ifm_counter + 1;
        end
        else if(ready_f_t0) begin
            ifm_counter <= ifm_counter_t2;
        end
    end
end

reg [9:0] weight_counter_t0;
reg [9:0] weight_counter_t1;
reg [9:0] weight_counter_t2;
reg [9:0] bias_counter_t0;
reg [9:0] bias_counter_t1;
reg [9:0] bias_counter_t2;
reg [11:0] ifm_counter_t0;
reg [11:0] ifm_counter_t1;
reg [11:0] ifm_counter_t2;

always @(posedge clk, negedge rstn) begin
    if(!rstn) begin
        weight_counter_t0 <= 0;
        weight_counter_t1 <= 0;
        weight_counter_t2 <= 0;
        bias_counter_t0 <= 0;
        bias_counter_t1 <= 0;
        bias_counter_t2 <= 0;
        ifm_counter_t0 <= 0;
        ifm_counter_t1 <= 0;
        ifm_counter_t2 <= 0;
    end
    else begin
        weight_counter_t0 <= weight_counter;
        weight_counter_t1 <= weight_counter_t0;
        weight_counter_t2 <= weight_counter_t1;
        bias_counter_t0 <= bias_counter;
        bias_counter_t1 <= bias_counter_t0;
        bias_counter_t2 <= bias_counter_t1;
        ifm_counter_t0 <= ifm_counter;
        ifm_counter_t1 <= ifm_counter_t0;
        ifm_counter_t2 <= ifm_counter_t1;
    end
end

assign data_in_w0 = {weight_register[36*weight_counter_t2+3], weight_register[36*weight_counter_t2+2], weight_register[36*weight_counter_t2+1], weight_register[36*weight_counter_t2]};
assign data_in_w1 = {weight_register[36*weight_counter_t2+7], weight_register[36*weight_counter_t2+6], weight_register[36*weight_counter_t2+5], weight_register[36*weight_counter_t2+4]};
assign data_in_w2 = {weight_register[36*weight_counter_t2+11], weight_register[36*weight_counter_t2+10], weight_register[36*weight_counter_t2+9], weight_register[36*weight_counter_t2+8]};
assign data_in_w3 = {weight_register[36*weight_counter_t2+15], weight_register[36*weight_counter_t2+14], weight_register[36*weight_counter_t2+13], weight_register[36*weight_counter_t2+12]};
assign data_in_w4 = {weight_register[36*weight_counter_t2+19], weight_register[36*weight_counter_t2+18], weight_register[36*weight_counter_t2+17], weight_register[36*weight_counter_t2+16]};
assign data_in_w5 = {weight_register[36*weight_counter_t2+23], weight_register[36*weight_counter_t2+22], weight_register[36*weight_counter_t2+21], weight_register[36*weight_counter_t2+20]};
assign data_in_w6 = {weight_register[36*weight_counter_t2+27], weight_register[36*weight_counter_t2+26], weight_register[36*weight_counter_t2+25], weight_register[36*weight_counter_t2+24]};
assign data_in_w7 = {weight_register[36*weight_counter_t2+31], weight_register[36*weight_counter_t2+30], weight_register[36*weight_counter_t2+29], weight_register[36*weight_counter_t2+28]};
assign data_in_w8 = {weight_register[36*weight_counter_t2+35], weight_register[36*weight_counter_t2+34], weight_register[36*weight_counter_t2+33], weight_register[36*weight_counter_t2+32]};

assign data_in_b = bias_register[bias_counter_t2];

//================ ifm ==================

wire        ifm_is_first_row;
wire        ifm_is_last_row;
wire        ifm_is_first_col;
wire        ifm_is_last_col;

wire [7:0]  channel_iter;
wire [7:0]  row_iter;
wire [7:0]  col_iter;

wire [9:0] ifm_counter_wo_channel;
wire [6:0] big_row;
wire [6:0] ifm_counter_in_a_big_row;

wire [9:0] ifm_row_0;
wire [9:0] ifm_col_0;
wire [9:0] ifm_row_1;
wire [9:0] ifm_col_1;
wire [9:0] ifm_row_2;
wire [9:0] ifm_col_2;
wire [9:0] ifm_row_3;
wire [9:0] ifm_col_3;

assign channel_iter = Ni/channel_num_per_ifm;
assign row_iter = (IFM_HEIGHT+2*padding_size)/row_num_per_ifm;
assign col_iter = (IFM_WIDTH+2*padding_size)/col_num_per_ifm;

assign ifm_counter_wo_channel = ifm_counter_t2/channel_iter;
assign big_row = ifm_counter_wo_channel/(2*col_iter);
assign ifm_counter_in_a_big_row = ifm_counter_wo_channel - 2*col_iter*big_row;

assign ifm_row_0 = (ifm_counter_in_a_big_row[0])? 2*big_row-1+2 : 2*big_row-1; //ifm_counter_in_a_big_row[0] -> odd number check, not true for layer00, layer02, layer04
assign ifm_row_1 = (ifm_counter_in_a_big_row[0])? 2*big_row-1+2 : 2*big_row-1; //ifm_counter_in_a_big_row[0] -> odd number check, not true for layer00, layer02, layer04
assign ifm_row_2 = (ifm_counter_in_a_big_row[0])? 2*big_row+2 : 2*big_row; //ifm_counter_in_a_big_row[0] -> odd number check, not true for layer00, layer02, layer04
assign ifm_row_3 = (ifm_counter_in_a_big_row[0])? 2*big_row+2 : 2*big_row; //ifm_counter_in_a_big_row[0] -> odd number check, not true for layer00, layer02, layer04
assign ifm_col_0 = 2*(ifm_counter_in_a_big_row/2)-1;
assign ifm_col_1 = 2*(ifm_counter_in_a_big_row/2);
assign ifm_col_2 = 2*(ifm_counter_in_a_big_row/2)-1;
assign ifm_col_3 = 2*(ifm_counter_in_a_big_row/2);

assign ifm_is_first_row = (ifm_counter_in_a_big_row[0]==0)? (big_row ==0)? 1 : 0 : 0; 
assign ifm_is_last_row = (ifm_row_2 == IFM_HEIGHT)? 1 : 0;
assign ifm_is_first_col = (ifm_counter_in_a_big_row == 0)? 1 : (ifm_counter_in_a_big_row == 1)? 1 : 0;
assign ifm_is_last_col = (ifm_counter_in_a_big_row == (col_iter-1)*2)? 1 : (ifm_counter_in_a_big_row == (col_iter-1)*2+1)? 1 : 0;

wire [15:0] ifm_index_0;
wire [15:0] ifm_index_1;
wire [15:0] ifm_index_2;
wire [15:0] ifm_index_3;

assign ifm_index_0 = (ifm_row_0 * IFM_WIDTH + ifm_col_0)*(Ni/4) + (ifm_counter_t2%channel_iter)*8; 
assign ifm_index_1 = (ifm_row_1 * IFM_WIDTH + ifm_col_1)*(Ni/4) + (ifm_counter_t2%channel_iter)*8; 
assign ifm_index_2 = (ifm_row_2 * IFM_WIDTH + ifm_col_2)*(Ni/4) + (ifm_counter_t2%channel_iter)*8; 
assign ifm_index_3 = (ifm_row_3 * IFM_WIDTH + ifm_col_3)*(Ni/4) + (ifm_counter_t2%channel_iter)*8; 

wire [255:0]  data_in_f_0;
wire [255:0]  data_in_f_1;
wire [255:0]  data_in_f_2;
wire [255:0]  data_in_f_3;

assign data_in_f_0 = (ifm_is_first_row || ifm_is_first_col)? 256'b0 : {ifm_register[ifm_index_0+7], ifm_register[ifm_index_0+6], ifm_register[ifm_index_0+5], ifm_register[ifm_index_0+4], ifm_register[ifm_index_0+3], ifm_register[ifm_index_0+2], ifm_register[ifm_index_0+1], ifm_register[ifm_index_0]};
assign data_in_f_1 = (ifm_is_first_row || ifm_is_last_col )? 256'b0 : {ifm_register[ifm_index_1+7], ifm_register[ifm_index_1+6], ifm_register[ifm_index_1+5], ifm_register[ifm_index_1+4], ifm_register[ifm_index_1+3], ifm_register[ifm_index_1+2], ifm_register[ifm_index_1+1], ifm_register[ifm_index_1]};
assign data_in_f_2 = (ifm_is_last_row  || ifm_is_first_col)? 256'b0 : {ifm_register[ifm_index_2+7], ifm_register[ifm_index_2+6], ifm_register[ifm_index_2+5], ifm_register[ifm_index_2+4], ifm_register[ifm_index_2+3], ifm_register[ifm_index_2+2], ifm_register[ifm_index_2+1], ifm_register[ifm_index_2]};
assign data_in_f_3 = (ifm_is_last_row  || ifm_is_last_col )? 256'b0 : {ifm_register[ifm_index_3+7], ifm_register[ifm_index_3+6], ifm_register[ifm_index_3+5], ifm_register[ifm_index_3+4], ifm_register[ifm_index_3+3], ifm_register[ifm_index_3+2], ifm_register[ifm_index_3+1], ifm_register[ifm_index_3]};

assign data_in_f = {data_in_f_3,data_in_f_2,data_in_f_1,data_in_f_0};
//=========================================

//==========================================
//DUT
//==========================================
conv_maxpool_module u_conv_maxpool_module
( 
    .IFM_WIDTH          (IFM_WIDTH          ),
    .IFM_HEIGHT         (IFM_HEIGHT         ),
    .Tr                 (Tr                 ),
    .Tc                 (Tc                 ),
    .Ti                 (Ti                 ),
    .To                 (To                 ),
    .Ni                 (Ni                 ),
    .No                 (No                 ),
    .SCALE_FACTOR       (SCALE_FACTOR       ),
    .NEXT_LAYER_INPUT_M (NEXT_LAYER_INPUT_M ),
    .is_CONV00          (is_CONV00          ),
    .is_1x1             (is_1x1             ),
    .is_relu            (is_relu            ),
    .clk                (clk                ),
    .rstn               (rstn               ),
    .conv_start         (conv_start         ),
    .valid_w            (valid_w            ),
    .valid_b            (valid_b            ),
    .data_in_w0         (data_in_w0         ),
    .data_in_w1         (data_in_w1         ),
    .data_in_w2         (data_in_w2         ),
    .data_in_w3         (data_in_w3         ),
    .data_in_w4         (data_in_w4         ),
    .data_in_w5         (data_in_w5         ),
    .data_in_w6         (data_in_w6         ),
    .data_in_w7         (data_in_w7         ),
    .data_in_w8         (data_in_w8         ),
    .data_in_b          (data_in_b          ), 
    .valid_f            (valid_f            ),
    .data_in_f          (data_in_f          ),
    .conv_done          (conv_done          ),
    .ready_w            (ready_w            ),
    .ready_b            (ready_b            ),
    .ready_f            (ready_f            ),
    .valid_o0           (valid_o0           ),
    .valid_o1           (valid_o1           ),
    .data_out0          (data_out0          ),
    .data_out1          (data_out1          )  
);

// get OFM from the module
integer i;
always @ (posedge clk) begin
	if (!rstn) begin
		for (i = 0; i < OFM_DATA_SIZE / 4; i=i+1) // 4 outputs in a line
			ofm_register[i] = 1'b0;
		out_counter <= 1'b0;
	end else if (!conv_done) begin
		if (conv_start) begin
			if (valid_o0) begin
                for (i = 0; i < 8; i=i+1) begin
                    ofm_register[8 * out_counter + i] = data_out0[32*i+:32];
                end
                out_counter <= out_counter + 1;
            end
        end
    end
end

endmodule