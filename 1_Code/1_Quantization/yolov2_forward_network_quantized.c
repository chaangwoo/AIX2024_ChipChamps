#include "additionally.h"    // some definitions from: im2col.h, blas.h, list.h, utils.h, activations.h, tree.h, layer.h, network.h
// softmax_layer.h, reorg_layer.h, route_layer.h, region_layer.h, maxpool_layer.h, convolutional_layer.h

#define GEMMCONV

//#define SSE41
//#undef AVX

#define MAX_VAL_8       127         // 7-bit (1-bit sign)
#define MAX_VAL_16      32767       // 15-bit (1-bit sign)
#define MAX_VAL_32      2147483647  // 31-bit (1-bit sign)
#define MAX_VAL_UINT_8  255

int const run_single_image_test = 0;

int max_abs(int src, int max_val)
{
    //if (abs(src) > abs(max_val)) src = (src > 0) ? max_val : -max_val;
    if (abs(src) > abs(max_val)) src = (src > 0) ? max_val : -max_val-1;
    return src;
}

short int max_abs_short(short int src, short int max_val)
{
    //if (abs(src) > abs(max_val)) src = (src > 0) ? max_val : -max_val;
    if (abs(src) > abs(max_val)) src = (src > 0) ? max_val : -max_val-1;
    return src;
}

// im2col.c
int8_t im2col_get_pixel_int8(int8_t *im, int height, int width, int channels,
    int row, int col, int channel, int pad)
{
    row -= pad;
    col -= pad;

    if (row < 0 || col < 0 ||
        row >= height || col >= width) return 0;
    return im[col + width*(row + height*channel)];
}

// im2col.c
//From Berkeley Vision's Caffe!
//https://github.com/BVLC/caffe/blob/master/LICENSE
void im2col_cpu_int8(int8_t* data_im,
    int channels, int height, int width,
    int ksize, int stride, int pad, int8_t* data_col)
{
    int c, h, w;
    int height_col = (height + 2 * pad - ksize) / stride + 1;
    int width_col = (width + 2 * pad - ksize) / stride + 1;

    int channels_col = channels * ksize * ksize;
    for (c = 0; c < channels_col; ++c) {
        int w_offset = c % ksize;
        int h_offset = (c / ksize) % ksize;
        int c_im = c / ksize / ksize;
        for (h = 0; h < height_col; ++h) {
            for (w = 0; w < width_col; ++w) {
                int im_row = h_offset + h * stride;
                int im_col = w_offset + w * stride;
                int col_index = (c * height_col + h) * width_col + w;
                data_col[col_index] = im2col_get_pixel_int8(data_im, height, width, channels,
                    im_row, im_col, c_im, pad);
            }
        }
    }
}

void gemm_nn_int8_int16(int M, int N, int K, int8_t ALPHA,
    int8_t *A, int lda,
    int8_t *B, int ldb,
    int16_t *C, int ldc)
{
    int32_t *c_tmp = calloc(N, sizeof(int32_t));
    int i, j, k;
    for (i = 0; i < M; ++i) {
        for (k = 0; k < K; ++k) {
            register int16_t A_PART = ALPHA*A[i*lda + k];
            //#pragma simd parallel for
            for (j = 0; j < N; ++j) {
                c_tmp[j] += A_PART*B[k*ldb + j];
            }
        }
        for (j = 0; j < N; ++j) {
            C[i*ldc + j] += max_abs(c_tmp[j], MAX_VAL_16);
            c_tmp[j] = 0;
        }
    }
    free(c_tmp);
}

void gemm_nn_int8_int32(int M, int N, int K, int8_t ALPHA,
    int8_t *A, int lda,
    int8_t *B, int ldb,
    int32_t *C, int ldc)
{
    int32_t *c_tmp = calloc(N, sizeof(int32_t));
    int i, j, k;
    for (i = 0; i < M; ++i) {
        for (k = 0; k < K; ++k) {
            register int16_t A_PART = ALPHA*A[i*lda + k];
            //#pragma simd parallel for
            for (j = 0; j < N; ++j) {
                c_tmp[j] += A_PART*B[k*ldb + j];
            }
        }
        for (j = 0; j < N; ++j) {
            C[i*ldc + j] += max_abs(c_tmp[j], MAX_VAL_32);
            c_tmp[j] = 0;
        }
    }
    free(c_tmp);
}

void forward_convolutional_layer_q(network net, layer l, network_state state)
{

    int out_h = (l.h + 2 * l.pad - l.size) / l.stride + 1;    // output_height=input_height for stride=1 and pad=1
    int out_w = (l.w + 2 * l.pad - l.size) / l.stride + 1;    // output_width=input_width for stride=1 and pad=1
    int i, j;
    int const out_size = out_h*out_w;

    typedef int32_t conv_t;    // l.output
    conv_t *output_q = calloc(l.outputs, sizeof(conv_t));

    state.input_uint8 = (int8_t*)calloc(l.inputs, sizeof(uint8_t)); //state.input_int8 = (int8_t *)calloc(l.inputs, sizeof(int));
    int z;
    for (z = 0; z < l.inputs; ++z) {
        int16_t src = state.input[z] * l.input_quant_multiplier;        
        state.input_uint8[z] = max_abs(src, MAX_VAL_UINT_8);    //state.input_int8[z] = max_abs(src, MAX_VAL_8);
    }

    //// Profiling range
    ////{{{{
    //float xmin = 0, xmax = 0, qmin = 0, qmax = 0;
    //for (int i = 0; i < l.inputs; i++) {
    //    xmin = (xmin > state.input[i]) ? state.input[i] : xmin;
    //    xmax = (xmax < state.input[i]) ? state.input[i] : xmax;
    //    qmin = (qmin > state.input_uint8[i]) ? state.input_uint8[i] : qmin;
    //    qmax = (qmax < state.input_uint8[i]) ? state.input_uint8[i] : qmax;
    //}
    //fprintf(stderr, "(%.2f %.2f)  (%.0f %.0f) \n", xmin, xmax, qmin, qmax);
    ////}}}
    
    // Write data for the HW verification
    //{{{
    if (run_single_image_test) {
        // Input Feature Map (IFM)
        char file_input_femap[100];
        // snprintf(file_input_femap, sizeof(file_input_femap), "C:/skeleton/bin/log_feamap/CONV%02d_input.hex", state.index);
        snprintf(file_input_femap, sizeof(file_input_femap), "../bin/log_feamap/CONV%02d_input.hex", state.index);
        FILE* fp = fopen(file_input_femap, "w");
    
        // Data Format: [Channel, Width, Height]        
        for (int idx = 0; idx < l.h * l.w; idx++) {  // IFM: Pixel index in ONE feature map
            for (int chn = 0; chn < l.c; chn++) {    // IFM: Channel/index of an feature map
                int i = chn * l.h * l.w + idx;       // IFM: Pixel index 
                uint8_t pixel = state.input_uint8[i];
                fprintf(fp, "%02x\n", pixel);
            }
        }
        if (fp) fclose(fp);
    }
    //}}}

    // Convolution
    int m = l.n;
    int k = l.size*l.size*l.c;
    int n = out_h*out_w;
    int8_t *a = l.weights_int8;    
    uint8_t* b = (uint8_t*)state.workspace; //int8_t *b = (int8_t *)state.workspace;
    conv_t *c = output_q;    // int32_t

    // Use GEMM (as part of BLAS)
    im2col_cpu_int8(state.input_uint8, l.c, l.h, l.w, l.size, l.stride, l.pad, b);

    int t;    // multi-thread gemm
    #pragma omp parallel for
    for (t = 0; t < m; ++t) {
        gemm_nn_int8_int32(1, n, k, 1, a + t*k, k, b, n, c + t*n, n);
    }    
    free(state.input_uint8);    //free(state.input_int8);

    // Bias addition
    int fil;
    for (fil = 0; fil < l.n; ++fil) {
        for (j = 0; j < out_size; ++j) {
            output_q[fil*out_size + j] = output_q[fil*out_size + j] + l.biases_quant[fil];
        }
    }

    // Activation
    if (l.activation == RELU) {
        for (i = 0; i < l.n * out_size; ++i) {
            output_q[i] = (output_q[i] > 0) ? output_q[i] : 0;
        }
    }

    // De-scaling or De-quantization
    float ALPHA1 = 1 / (l.input_quant_multiplier * l.weights_quant_multiplier);
    for (i = 0; i < l.outputs; ++i) {
        l.output[i] = output_q[i] * ALPHA1;
    }

    
    // Write data for the HW verification
    //{{{
    if (run_single_image_test) {
        // Output Feature Map (OFM)
        int z;
        int next_input_quant_multiplier = 1;
        for (z = state.index + 1; z < net.n; ++z) {
            if (net.layers[z].type == CONVOLUTIONAL) {
                next_input_quant_multiplier = net.layers[z].input_quant_multiplier;
                break;
            }
        }
        char file_output_femap[100];
        // snprintf(file_output_femap, sizeof(file_output_femap), "C:/skeleton/bin/log_feamap/CONV%02d_output.hex", state.index);
        snprintf(file_output_femap, sizeof(file_output_femap), "../bin/log_feamap/CONV%02d_output.hex", state.index);
        FILE* fp = fopen(file_output_femap, "w");
    
        // Data Format: [Channel, Width, Height]
        for (int idx = 0; idx < out_size; idx++) {  // OFM: Pixel index in ONE feature map
            for (int chn = 0; chn < l.n; chn++) {   // OFM: Channel/index of an feature map
                int i = chn * out_size + idx;       // OFM: Pixel index
                uint8_t pixel = max_abs(l.output[i] * next_input_quant_multiplier, MAX_VAL_UINT_8);
                fprintf(fp, "%02x\n", pixel);
            }
        }
        if (fp) fclose(fp);
    }
    //}}}
    free(output_q);
}

void yolov2_forward_network_q(network net, network_state state)
{
    state.workspace = net.workspace;
    int i;
    for (i = 0; i < net.n; ++i) {
        state.index = i;
        layer l = net.layers[i];

        if (l.type == CONVOLUTIONAL) {
            forward_convolutional_layer_q(net, l, state);
        }
        else if (l.type == MAXPOOL) {
            forward_maxpool_layer_cpu(l, state);
        }
        else if (l.type == ROUTE) {
            forward_route_layer_cpu(l, state);
        }
        else if (l.type == REORG) {
            forward_reorg_layer_cpu(l, state);
        }
        else if (l.type == UPSAMPLE) {
            forward_upsample_layer_cpu(l, state);
        }
        else if (l.type == SHORTCUT) {
            forward_shortcut_layer_cpu(l, state);
        }
        else if (l.type == YOLO) {
            forward_yolo_layer_cpu(l, state);
        }
        else if (l.type == REGION) {
            forward_region_layer_cpu(l, state);
        }
        else {
            printf("\n layer: %d \n", l.type);
        }
        state.input = l.output;
    }
}

// detect on CPU
float *network_predict_quantized(network net, float *input)
{
    network_state state;
    state.net = net;
    state.index = 0;
    state.input = input;
    state.truth = 0;
    state.train = 0;
    state.delta = 0;

    yolov2_forward_network_q(net, state);    // network on CPU
                                            //float *out = get_network_output(net);
    int i;
    for (i = net.n - 1; i > 0; --i) if (net.layers[i].type != COST) break;
    return net.layers[i].output;
}

/* Quantization-related */

void do_quantization(network net) {
    int counter = 0;

    int j;
	//Dummy weight_quantization 
	#define TOTAL_CALIB_LAYER 11
	// TODO
	//{{
    // ------------------------------
    // Baseline: multipliers with minimum MSE
    // ------------------------------
    /*
    float weight_quant_multiplier[TOTAL_CALIB_LAYER] = {
      16,       //conv 0
      128,      //conv 2
      128,      //conv 4
      256,      //conv 6
      256,      //conv 8
      1024,     //conv 10
      256,      //conv 12
      512,      //conv 13
      256,      //conv 14
      128,      //conv 17
      256};     //conv 20
    */

    // ------------------------------
    // Optimized multipliers
    // ------------------------------
	float weight_quant_multiplier[TOTAL_CALIB_LAYER] = {
      16,       //conv 0
      128,      //conv 2
      128,      //conv 4
      128,      //conv 6
      64,       //conv 8
      2048,     //conv 10
      256,      //conv 12
      1024,     //conv 13
      256,      //conv 14
      128,      //conv 17
      512};     //conv 20

    float input_quant_multiplier[TOTAL_CALIB_LAYER] = {
      64,	  //conv 0
      8,      //conv 2
      8,      //conv 4
      8,      //conv 6
      8,      //conv 8
      8,      //conv 10     
      8,      //conv 12
      8,      //conv 13
      8,      //conv 14
      8,      //conv 17
      8};     //conv 20

	printf("Multipler    Input    Weight    Bias\n");
    for (j = 0; j < net.n; ++j) {
        layer *l = &net.layers[j];

        /*
        TODO: implement quantization 
        The implementation given below is a naive version of per-network quantization; implement your own quantization that minimizes the mAP degradation
        */

        //printf("\n");
        if (l->type == CONVOLUTIONAL) { // Quantize conv layer only            
            size_t const filter_size = l->size*l->size*l->c;

            int i, fil;

            // Quantized Parameters
			//{{{
				// Input feature map
				l->input_quant_multiplier   = (counter < TOTAL_CALIB_LAYER) ? input_quant_multiplier [counter] : 16;
				
				// Weight
				l->weights_quant_multiplier = (counter < TOTAL_CALIB_LAYER) ? weight_quant_multiplier[counter] : 16;
				
				++counter;
			//}}}	
            // Weight Quantization

            // ------------------------------
            // Saving the weights before quantization
            // for selecting the best quant_multipliers
            // ------------------------------
            FILE *fp;
            char filename[50];
            sprintf(filename, "../bin/weights/weights_of_layer_%02d.txt", j);
            
            fp = fopen(filename, "w");
            if (fp == NULL) {
                printf("Error opening file %s.\n", filename);
            }

			for (fil = 0; fil < l->n; ++fil) { 
                for (i = 0; i < filter_size; ++i) {
                    fprintf(fp, "%f\n", l->weights[fil*filter_size + i]); // Write w to the file, one element per line
                    float w = l->weights[fil*filter_size + i] * l->weights_quant_multiplier; // Scale
                    l->weights_int8[fil*filter_size + i] = max_abs(w, MAX_VAL_8); // Clip
                }
            }
            fclose(fp);

            // Bias Quantization
            float biases_multiplier = (l->weights_quant_multiplier * l->input_quant_multiplier);
            for (fil = 0; fil < l->n; ++fil) {
                float b = l->biases[fil] * biases_multiplier; // Scale
                l->biases_quant[fil] = max_abs(b, MAX_VAL_16); // Clip
            }

            //printf(" CONV%d multipliers: input %g, weights %g, bias %g \n", j, l->input_quant_multiplier, l->weights_quant_multiplier, biases_multiplier);
			printf(" CONV%d: \t%g \t%g \t%g \n", j, l->input_quant_multiplier, l->weights_quant_multiplier, biases_multiplier);
        }
        else {
            //printf(" No quantization for layer %d (layer type: %d) \n", j, l->type);
        }
    }
}

void save_quantized_model(network net) {
    int j;
    if (!run_single_image_test) return;
    for (j = 0; j < net.n; ++j) {
        layer* l = &net.layers[j];
        if (l->type == CONVOLUTIONAL) {            
            size_t filter_size = l->size * l->size * l->c;            
            
            printf(" Saving quantized weights, bias, and scale for CONV%02d \n", j);

            char weightfile [100];            
            char biasfile   [100];
            char scalefile  [100];

            // sprintf(weightfile  , "C:/skeleton/bin//log_param/CONV%02d_param_weight.hex", j);
            // sprintf(biasfile    , "C:/skeleton/bin//log_param/CONV%02d_param_biases.hex", j);
            // sprintf(scalefile   , "C:/skeleton/bin//log_param/CONV%02d_param_scales.hex", j);
            sprintf(weightfile  , "../bin/log_param/CONV%02d_param_weight.hex", j);
            sprintf(biasfile    , "../bin/log_param/CONV%02d_param_biases.hex", j);
            sprintf(scalefile   , "../bin/log_param/CONV%02d_param_scales.hex", j);
            FILE* fp_w = fopen(weightfile, "w");
            FILE* fp_b = fopen(biasfile, "w");
            FILE* fp_s = fopen(scalefile, "w");
            
            int f;            
            for (f = 0; f < l->n; f++) {    // Out_channel
                // Weights
                //{{{
                for (int i = 0; i < filter_size; ++i) {     // Filter size
                    int w_index = f * filter_size + i;
                    fprintf(fp_w, "%08x\n", l->weights_int8[w_index]);
                }                
                //}}}
                
                // Biases
                //{{{
                fprintf(fp_b, "%08x\n", l->biases_quant[f]);
                //}}}
                
                // Dequantization or Scaling                
                //{{{
                // Find the input quantization factor for the next CONV layer
                int next_input_quant_multiplier = 1;
                for (int z = l->index+ 1; z < net.n; ++z) {
                    if (net.layers[z].type == CONVOLUTIONAL) {
                        next_input_quant_multiplier = net.layers[z].input_quant_multiplier;
                        break;
                    }
                }                

                int scale = (l->input_quant_multiplier * l->weights_quant_multiplier) / next_input_quant_multiplier;
                fprintf(fp_s, "%08x\n", scale);
                //}}}
            }

            fclose(fp_w);
            fclose(fp_b);
            fclose(fp_s);
        }
    }
}
