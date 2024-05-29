This file contains a detailed explanation of the quantization methodology and descriptions of utility files('./utils').

1. Quantization Methodology

	Finding the set of multipliers that results in the acceptable mAP (>75%) by only trial-and-error methodology takes LOTS OF time. Considering just two options per layer requires 2^22 combinations, which is over 4 million. 

Therefore, we need some theoretical baseline of the multiplier set, which can be empirically optimized later.

A set whose element has a power-of-two scale factor that minimizes the mean squared error (MSE) between the original floating-point value and the approximated value can be a good baseline([1]).

To find the best scale factor for the weights of each layer, we first added some codes to save the weights of each layer as a text file (yolov2_forward_network_quantized.c:379-399).

For each CONV layer, we multiplied the weight by 2^s to get the 8-bit fixed-point approximated value and then calculated the MSE while the scale factor 's' iterates from 1 to 11.

With the methodology mentioned above, we can figure out the best scale factor for each CONV layer.

Based on these weight multipliers, we empirically optimized the values to get a higher mAP. Our final values are denoted in 'yolov2_forward_network_quantized.c:303-350'.

We got 81.06% of mAP, which is only a 0.7%P reduction in mAP compared with the baseline(81.76%). The captured result is in '1_Code/4_others/mAP.png'. Also, you can run the code by just replacing the 'yolov2_forward_network_quantized.c' file to our own code attached, and follow the instructions on '01_AIX2024_Orientation.pdf'.

The quantized weights and biases are archived in '1_Code/2_RTL_Simulation/07_SIC/07_SIC.sim/sim_1/inout_data_sw/log_param'.


2. Description of 'weights_find_n.ipynb'

	This file consists of the code and the results of finding the minimum MSE of each layer.


3. Description of '8bit_to_32bit.ipynb'

	As we get the quantized input files(CONVnn_input.hex) via the given skeleton code in 'yolov2_forward_network_quantized.c', the stored word size is 8-bit.

For the compatibility with given skeleton code and to use 32-bit BRAM, we need to convert the word size into 32-bit.

This file converts the word size into 32-bit with little endianness.

--------
[1] Minsik Kim, Kyoungseok Oh, Youngmock Cho, Hojin Seo, Xuan Truong Nguyen, and Hyuk-Jae Lee. 2024. A Low-Latency FPGA Accelerator for YOLOv3-Tiny With Flexible Layerwise Mapping and Dataflow. IEEE Transactions on Circuits and Systems I: Regular Papers 71, 3 (2024), 1158-1171. DOI:https://doi.org/10.1109/tcsi.2023.3335949