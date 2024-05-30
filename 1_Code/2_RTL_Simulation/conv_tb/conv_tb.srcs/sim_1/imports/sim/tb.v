`timescale 1ns / 1ns

module tb;
// `include "../src/define.v"
`include "../../../sources_1/imports/src/define.v"

// Clock
parameter CLK_PERIOD = 10;   //100MHz
reg [63:0] cur_tick;
reg clk;
reg rstn;
initial begin
   cur_tick = 1'b0;	
   clk = 1'b1;
   forever #(CLK_PERIOD/2) clk = ~clk;
end
always @ (posedge clk) begin
	cur_tick = cur_tick + 1;
end

// Preloaded data
reg  preload;
reg  [IFM_WORD_SIZE-1:0] 	in_img [0:IFM_DATA_SIZE-1];  // Infmap
reg  [WGT_WORD_SIZE-1:0] 	filter [0:WGT_DATA_SIZE-1];	 // Filter
reg	 [BIAS_WORD_SIZE-1:0] 	bias   [0:BIAS_DATA_SIZE-1];  // Bias

// Answer
parameter THRES = 10;
reg  [3:0]                  wrong_cnt;
reg                         compare_flag;
reg  [IFM_WORD_SIZE-1:0]    answer [0:IFM_DATA_SIZE-1];


//--------------------------------------------------------------------
// Test vector
//--------------------------------------------------------------------
integer i;
reg [ 3:0] COMMAND;
reg [31:0] RECEIVE_SIZE;

reg [63:0] timestamp;
reg [63:0] read_f_cyc;
reg [63:0] read_w_cyc;
reg [63:0] read_b_cyc;
reg [63:0] compute_cyc;

reg		   vld_i;
reg		   conv_start;

initial begin
	// Initialization
    rstn = 1'b0;         // Reset, low active
    wrong_cnt = 1'b0;
    compare_flag = 1'b1;
	COMMAND = 1'b0;
    preload = 1'b0;
	RECEIVE_SIZE = 1'b0;
	vld_i = 1'b0;
	conv_start = 1'b0;

	// Load memory from file
	repeat(100) 
        @(posedge clk);
    preload = 1'b1;

	// Inputs
	$display ("Loading input feature maps from file: %s", IFM_FILE);
    for (i = 0; i < IFM_DATA_SIZE; i=i+1) begin
		in_img[i] = 0;
        answer[i] = 0;
	end
	$readmemh(IFM_FILE, in_img);

	repeat(100) 
        @(posedge clk);
	
	// Filters
	$display ("Loading weights from file: %s", WGT_FILE);
    for (i = 0; i < WGT_DATA_SIZE; i=i+1) begin
		filter[i] = 0;
	end
	$readmemh(WGT_FILE, filter);

	repeat(100) 
        @(posedge clk);

	// Biases
	$display ("Loading biases from file: %s", BIAS_FILE);
    for (i = 0; i < BIAS_DATA_SIZE; i=i+1) begin
		bias[i] = 0;
	end
	$readmemh(BIAS_FILE, bias);

	$display ("Preload data done.\n");

	repeat(100) 
        @(posedge clk);
    preload = 1'b0;	

	// Start test vector
	repeat(4)
		@(posedge clk);
    rstn = 1'b1;
	repeat(4)
		@(posedge clk);
	
	vld_i = 1'b1;
	tick = 1'b0;
	COMMAND = 4'b0001;
	RECEIVE_SIZE = IFM_DATA_SIZE;
	conv_start = 1'b1;
	$display ("Conv start at cycle %0d\n", cur_tick);

	repeat(100)
		@(posedge clk);
	
	$display ("Conv module starts to read feature...");
	timestamp = cur_tick;
	wait(F_writedone);
	$display("Conv module finishes reading feature");
	read_f_cyc = cur_tick - timestamp;
	$display("Reading feature takes %0d cycles\n", read_f_cyc);

	repeat(100)
		@(posedge clk);

	tick = 1'b0;
	COMMAND = 4'b0010;
	RECEIVE_SIZE = WGT_DATA_SIZE;

	repeat(100)
		@(posedge clk);

	$display ("Conv module starts to read weight...");
	timestamp = cur_tick;
	wait(W_writedone);
	$display("Conv module finishes reading weight");
	read_w_cyc = cur_tick - timestamp;
	$display("Reading weight takes %0d cycles\n", read_w_cyc);
	
	repeat(100)
		@(posedge clk);
	
	tick = 1'b0;
	COMMAND = 4'b0100;
	RECEIVE_SIZE = BIAS_DATA_SIZE;

	repeat(100)
		@(posedge clk);

	$display ("Conv module starts to read bias...");
	timestamp = cur_tick;
	wait(B_writedone);
	$display("Conv module finishes reading bias");
	read_b_cyc = cur_tick - timestamp;
	$display("Reading bias takes %0d cycles\n", read_b_cyc);

	repeat(100)
		@(posedge clk);

	COMMAND = 4'b1000;

	$display ("Conv module starts to compute...");
	timestamp = cur_tick;
	wait(conv_done);
	$display ("Conv module finishes computing");
	compute_cyc = cur_tick - timestamp;
	$display ("Computing takes %0d cycles\n", compute_cyc);
	$display ("Conv module done");
	$display ("Total cycle: %0d\n\n", read_f_cyc + read_b_cyc + read_w_cyc + compute_cyc);

    // Validation
	$display ("=== Validation ===\n");
    $display ("Validation for layer %0d", LAYER_NUM);
	$display ("Loading answers from file: %s", ANSWER_FILE);
	$readmemh(ANSWER_FILE, answer);

    for (i = 0; i < OFM_DATA_SIZE / 4; i = i + 1) begin       
        if (OFM[i] != answer[i]) begin
            $display("\nResult is different at %0d th line!", i+1);
            $display("Expected value: %h", answer[i]);
            $display("Output value: %h\n", OFM[i]);
            
            compare_flag = 1'b0;
            wrong_cnt = wrong_cnt + 1;
            if (wrong_cnt == THRES) begin
                $display("Too many errors, only first %0d errors are printed.\n", THRES);
                i = OFM_DATA_SIZE / 4; // break the loop;
            end
        end
    end
    
    if (compare_flag) begin
        $display("\nResult is correct!\n");
    end
    
    $display("Validation done.\n");
    $finish;
    
    // End test vector
    #(100*CLK_PERIOD) 
        @(posedge clk) $stop;

		
end

//-------------------------------------------
// conv_MAXPOOL Module
//-------------------------------------------
wire F_writedone, W_writedone, B_writedone;
wire conv_ready, conv_valid;
wire [127:0] conv_dout;
wire [127:0] conv_dout_2;
wire [127:0] conv_dout_3;
wire [127:0] conv_dout_4;
wire conv_done;
conv_maxpool_module m_conv_maxpool_module (
	// inputs
	.IFM_WIDTH			(IFM_WIDTH),
	.IFM_HEIGHT			(IFM_HEIGHT),
	.Tr					(Tr),
	.Tc					(Tc),
	.Ti					(Ti),
	.To					(To),
	.Ni					(Ni),
	.No					(No),
	.SCALE_FACTOR		(SCALE_FACTOR),
	.NEXT_LAYER_INPUT_M (NEXT_LAYER_INPUT_M),

	.clk				(clk),
	.rstn				(rstn),
	.is_CONV00			(is_CONV00),
	.is_1x1				(is_1x1),
	.is_relu			(is_relu),
	.is_maxpool			(is_maxpool),
	.COMMAND			(COMMAND),
	.RECEIVE_SIZE		(RECEIVE_SIZE),
	.conv_start			(conv_start),
	.valid_i			(vld_i),
	.data_in			(data),

	// outputs
	.F_writedone		(F_writedone),
	.W_writedone		(W_writedone),
	.B_writedone		(B_writedone),
	.ready_o			(conv_ready),
	.valid_o			(conv_valid),
	.data_out			(conv_dout),
	.data_out_2			(conv_dout_2),
	.data_out_3			(conv_dout_3),
	.data_out_4			(conv_dout_4),
	.conv_done			(conv_done)
);

//-------------------------------------------
// Data Feeding
//-------------------------------------------
reg [31:0] tick;
wire [31:0] data;
assign data = COMMAND[0] ? in_img[tick]
						 : (COMMAND[1] ? filter[tick]
						 			   : (COMMAND[2] ? bias[tick] : 1'b0));
always @ (posedge clk) begin
	if (!rstn) begin
		tick <= 32'd0;
	end else begin
		case (COMMAND)
			4'b0001: begin
				if (vld_i && conv_ready)
					tick <= tick + 1;
				else
					tick <= tick;
			end
			4'b0010: begin
				if (vld_i && conv_ready)
					tick <= tick + 1;
				else
					tick <= tick;
			end
			4'b0100: begin
				if (vld_i && conv_ready)
					tick <= tick + 1;
				else
					tick <= tick;
			end
			default: begin
				tick <= 1'b0;
			end
		endcase
	end
end

//-------------------------------------------
// OFM Saving
//-------------------------------------------
wire [31:0] OFM_DATA_SIZE;
assign OFM_DATA_SIZE = is_maxpool ? (IFM_WIDTH / 2 * IFM_HEIGHT / 2 * No) : (IFM_WIDTH * IFM_HEIGHT * No);

reg  [31:0] OFM [0:IFM_DATA_SIZE/4-1]; // Output Feature Map; 4 data per address
reg  [31:0] out_counter;
reg  [31:0] jump_counter;
wire [31:0] mask;
assign mask = is_1x1 ? ((No >> 3) - 1) : ((No >> 4) - 1);

wire [63:0] dout_1x1_00, dout_1x1_01, dout_1x1_10, dout_1x1_11;
assign dout_1x1_00 = conv_dout[ 63: 0];
assign dout_1x1_01 = conv_dout[127:64];
assign dout_1x1_10 = conv_dout_2[ 63: 0];
assign dout_1x1_11 = conv_dout_2[127:64];

always @ (posedge clk) begin
	if (!rstn) begin
		for (i = 0; i < OFM_DATA_SIZE; i=i+1)
			OFM[i] = 8'd0;
		out_counter <= 1'b0;
		jump_counter <= 1'b0;
	end else if (!conv_done) begin
		if (conv_start) begin
			if (conv_valid) begin
				if (!is_1x1 && is_maxpool) begin
					for (i = 0; i < 4; i=i+1) begin
						OFM[4 * out_counter + i] = conv_dout[32*i+:32];
					end
					out_counter <= out_counter + 1;
				end else if (!is_1x1) begin
					for (i = 0; i < 4; i=i+1) begin
						OFM[4 * out_counter			  					  + i] =   conv_dout[32*i+:32];
						OFM[4 * out_counter + (No >> 2)					  + i] = conv_dout_2[32*i+:32];
						OFM[4 * out_counter + IFM_WIDTH * (No >> 2) 	  + i] = conv_dout_3[32*i+:32];
						OFM[4 * out_counter + (IFM_WIDTH + 1) * (No >> 2) + i] = conv_dout_4[32*i+:32];
					end
					if ((out_counter & mask) == mask) begin
						if (jump_counter == (IFM_WIDTH >> 1) - 1) begin
							jump_counter <= 1'b0;
							out_counter <= out_counter + 1 + (No >> 4) + IFM_WIDTH * (No >> 4);
						end else begin
							jump_counter <= jump_counter + 1;
							out_counter <= out_counter + 1 + (No >> 4);
						end
					end else begin
						out_counter <= out_counter + 1;
					end
				end else begin
					for (i = 0; i < 2; i=i+1) begin
						OFM[2 * out_counter			  				      + i] = dout_1x1_00[32*i+:32];
						OFM[2 * out_counter + (No >> 2)				      + i] = dout_1x1_01[32*i+:32];
						OFM[2 * out_counter + IFM_WIDTH * (No >> 2) 	  + i] = dout_1x1_10[32*i+:32];
						OFM[2 * out_counter + (IFM_WIDTH + 1) * (No >> 2) + i] = dout_1x1_11[32*i+:32];
					end
					if ((out_counter & mask) == mask) begin
						if (jump_counter == (IFM_WIDTH >> 1) - 1) begin
							jump_counter <= 1'b0;
							out_counter <= out_counter + 1 + (No >> 3) + IFM_WIDTH * (No >> 3);
						end else begin
							jump_counter <= jump_counter + 1;
							out_counter <= out_counter + 1 + (No >> 3);
						end
					end else begin
						out_counter <= out_counter + 1;
					end
				end
			end
		end else begin
			vld_i <= 1'b0;
		end
	end
end
endmodule