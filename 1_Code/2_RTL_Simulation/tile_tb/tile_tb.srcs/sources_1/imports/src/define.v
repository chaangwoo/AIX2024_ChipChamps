// CONV module consumes {Tr * Tc * (Fx x Fy x Ti)} IFMs and produces {Tr x Tc x To} OFMs every cycle

/* ################################# CONV 06 ################################# */
parameter LAYER_NUM = 6;
parameter is_CONV00 = 0;
parameter is_1x1 = 0;
parameter is_relu = 1;
parameter is_maxpool = 1;
parameter is_last = 0;
parameter Tr = 2,  Tc = 2; // row-wise and col-wise factor
parameter Ti = 16, To = 1; // input-channel-wise and output-channel-wise factor
parameter SCALE_FACTOR = 10;
parameter NEXT_LAYER_INPUT_M = 3;

// counters
parameter MAX_WEIGHT_COUNTER = 511;
parameter MAX_BIAS_COUNTER   = 63;
parameter MAX_IFM_COUNTER    = 1087;

// Weight
parameter Fx = 3, Fy = 3;
parameter Ni = 64, No = 128; 
parameter WGT_DATA_SIZE   = Fx*Fy*Ni*No;
parameter WGT_WORD_SIZE   = 32;

// IFM
parameter IFM_WIDTH         = 32;
parameter IFM_HEIGHT        = 32;
parameter IFM_DATA_SIZE     = IFM_HEIGHT*IFM_WIDTH*Ni;	
parameter IFM_WORD_SIZE     = 32;

// Bias
parameter BIAS_DATA_SIZE = No;
parameter BIAS_WORD_SIZE = 32;

// OFM
parameter OFM_DATA_SIZE = IFM_WIDTH * IFM_HEIGHT / 4 * No; // max-pooling reduces the size by 4

// File directory
parameter IFM_FILE   		 = "../../inout_data_sw/log_feamap/CONV06_input_32b.hex"; 
parameter WGT_FILE   		 = "../../inout_data_sw/log_param/CONV06_param_weight_32b.hex";
parameter BIAS_FILE          = "../../inout_data_sw/log_param/CONV06_param_biases_32b.hex";
parameter ANSWER_FILE        = "../../inout_data_sw/log_feamap/CONV08_input_32b.hex";
/* ########################################################################### */