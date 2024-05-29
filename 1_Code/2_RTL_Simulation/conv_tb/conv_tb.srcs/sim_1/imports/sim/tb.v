`timescale 1ns / 1ns

module tb;
// `include "../src/define.v"
`include "../../../sources_1/imports/src/define.v"

// Clock
parameter CLK_PERIOD = 10;   //100MHz
reg clk;
reg rstn;
initial begin
   clk = 1'b1;
   forever #(CLK_PERIOD/2) clk = ~clk;
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

	repeat(100)
		@(posedge clk);
	
	$display ("Conv module starts to read feature...");
	wait(F_writedone);
	$display("Conv module finishes reading feature\n");

	repeat(100)
		@(posedge clk);

	tick = 1'b0;
	COMMAND = 4'b0010;
	RECEIVE_SIZE = WGT_DATA_SIZE;

	repeat(100)
		@(posedge clk);

	$display ("Conv module starts to read weight...");
	wait(W_writedone);
	$display("Conv module finishes reading weight\n");
	
	repeat(100)
		@(posedge clk);
	
	tick = 1'b0;
	COMMAND = 4'b0100;
	RECEIVE_SIZE = BIAS_DATA_SIZE;

	repeat(100)
		@(posedge clk);

	$display ("Conv module starts to read bias...");
	wait(B_writedone);
	$display("Conv module finishes reading bias\n");

	repeat(100)
		@(posedge clk);

	COMMAND = 4'b1000;

	$display ("Conv module starts to compute...");
	wait(conv_done);
	$display ("Conv module done\n\n");

    // validation
	$display ("=== Validation ===\n");
    $display ("Validation for layer %d\n", LAYER_NUM);
	$display ("Loading answers from file: %s", ANSWER_FILE);
	$readmemh(ANSWER_FILE, answer);

    for (i = 0; i < OFM_DATA_SIZE / 4; i = i + 1) begin       
        if (OFM[i] != answer[i]) begin
            $display("\nResult is different at %d th line!", i+1);
            $display("Expected value: %h", answer[i]);
            $display("Output value: %h\n", OFM[i]);
            
            compare_flag = 1'b0;
            wrong_cnt = wrong_cnt + 1;
            if (wrong_cnt == THRES) begin
                $display("Too many errors, only first %d errors are printed.\n", THRES);
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
// CONV result
//-------------------------------------------
wire [31:0] OFM_DATA_SIZE;
assign OFM_DATA_SIZE = is_maxpool ? (IFM_WIDTH / 2 * IFM_HEIGHT / 2 * No) : (IFM_WIDTH * IFM_HEIGHT * No);

reg [31:0] OFM [0:IFM_DATA_SIZE/4-1]; // Output Feature Map; 4 data per address
reg [31:0] out_counter;
reg [31:0] pixel_counter;
reg [7:0] validation [0:No-1];
reg validation_done;
integer j;
always @ (posedge clk) begin
	if (!rstn) begin
		for (i = 0; i < OFM_DATA_SIZE; i=i+1)
			OFM[i] = 8'd0;
		for (i = 0; i < No; i=i+1)
			validation[i] = 8'd0;
		out_counter <= 1'b0;
		pixel_counter <= 1'b0;
		validation_done <= 1'b0;
	end else if (!conv_done) begin
		if (conv_start) begin
			if (conv_valid) begin
				for (i = 0; i < 4; i=i+1) begin
                    for (j = 0; j < 4; j=j+1) begin
                        // should consider non-maxpool version...
                        OFM[4 * out_counter + i][8*j+:8] = conv_dout[8*(4*i+j)+:8];
                    end
				end
				out_counter <= out_counter + 1;
			end
		end else begin
			vld_i <= 1'b0;
		end
	end
end
endmodule