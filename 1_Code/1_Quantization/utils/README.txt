This file contains descriptions of utility files.

=== Finding optimal multiplier ===

1. Description of 'weights_find_n.ipynb'
	This file consists of the code and the results of finding the minimum MSE of each layer.

=========================


====  Re-shape the hex files ====

As we get the quantized input files (CONVnn_input.hex) via the given skeleton code in 'yolov2_forward_network_quantized.c', the stored word size is 8-bit.

For the compatibility with given skeleton code and to use 32-bit BRAM, we need to convert the word size into 32-bit.

The following files convert the word size into 32-bit with little endianness.

1. Description of '8bit_to_32bit_b.ipynb'	
	Convert the bias files.

2. Description of '8bit_to_32bit_ifm.ipynb'
	Convert the IFM files.

3. Description of '8bit_to_32bit_ifm_conv00.ipynb'
	Convert the ifm files, for layer 0. The first layer has 3 channels, which is not a multiple of 4. Thus, we pad zeros on each pixel to align to 32-bit lines.

4. Description of '8bit_to_32bit_w.ipynb'
	Convert the weight files.

5. Description of '8bit_to_32bit_w_conv00.ipynb'
	Convert the ifm files, for layer 0. Each filter of the first layer has 27 elements, which is not a multiple of 4. Thus, we pad zeros on every 3 elements, converting the number of each filter into 36.

6. Description of 'pad_output.ipynb'
	Pad zeros on every 195 elements, to convert `No` of layer 14 and layer 20 into 200. This is because making `No` as the multiple of `To` is easy to implement. Note that we also manually add zeros into biases. 

=========================