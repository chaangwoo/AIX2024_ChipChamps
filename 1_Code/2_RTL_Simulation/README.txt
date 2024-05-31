=== conv_tb ===
1. How to run
(1) Open `conv_tb/conv_tb.xpr` (vivado project)
(2) Choose the layer you want to simulate: uncomment compiler directive within `define.v:25-35`
(3) Run simulation
(4) Check Tcl Console output.
  - You may check total cycles, including feature map, parameter reading, and computing cycles.
  - Validation result follows.
(5) Close the simulation, change the compiler directive, and re-launch the simulation to simulate another layer.


2. FSM States
(1) COMMAND_IDLE
  - The first state when the module starts.

(2) COMMAND_GET_F
  - The module gets the input feature map from testbench.
  - Considering the AXI granularity, we set the input port as 32-bit.
  - It takes `IFM_WIDTH * IFM_HEIGHT * Ni / 4` cycles to get all input feature maps.
  - Notify the testbench when got all IFMs, via the `F_writedone` signal.

(3) COMMAND_GET_W
  - The module gets the weight from the testbench.
  - Likely, it takes `Fx * Fy * Ni * No / 4` cycles to get all weights.
  - Notify the testbench when got all weights, via the `W_writedone` signal.

(4) COMMAND_GET_B
  - The module gets the bias from the testbench.
  - Likely, it takes `No / 4` cycles to get all biases.
  - Notify the testbench when got all biases, via the `B_writedone` signal.

(5) COMMAND_COMPUTE
  - Testbench sends a `COMMAND` signal as `4'b1000`, and the module starts to compute.

(5-1) STATE_IDLE
  - When firstly transitioned into `COMMAND_COMPUTE`.

(5-2) STATE_RUN
  - Do MAC, max-pooling, and data-send in parallel.
  - Our INTEGRATED model does not need a separate model for max-pooling, since we can process 4 features leveraging 4 MAC arrays.
  - When MAC, max-pooling, and data-send are all done, transition into the next state.

(5-3) STATE_DONE
  - Notify the testbench that the module is done, via the `conv_done` signal.

3. Testbench Validation
  - Testbench stores the module output into `OFM[]`.
  - To get the sorted output, the output should be well-addressed considering the row, col, and channel.
  - See `tb.v:355-431` for detailed implementation.

  - For ordinary layers whose output is always non-negative, we can verify the result by simply comparing it with `answer[]`.
  - For layers 14 and 20, we tolerated the difference of 1 in the validation when the output was negative.
  - See `tb.v:215-248` for detailed implementation.
  - All validation results are archived in `1_Code/4_Captured_Results (Waveforms, Utilization)/ver_results/`.

4. Miscellaneous
  - We separated the behavior of the module using `is_CONV00`, `is_1x1`, and otherwise. This is because our MAC mechanism leveraging `mac_array` differs.
  - The granularity of data-sending is 16*8-bit since all layers except for the first layer have multiple-of-16 `No`.
===========

=== tile_tb ===
1. How to run
(1) Open `conv_tb/tile_tb.xpr` (vivado project)
(2) Run simulation.
(3) Check Tcl Console output.

2. IFM Buffer Implementation
  - Since storing all IFMs within the module is NOT practical, we suggest a new architecture.
  - See `1_Code/4_Captured_Results (Waveforms, Utilization)/Structure_IFM_Buffer.jpg`.

  - Module gets 2*2*32*8-bit (1024-bit) data every cycle, which we call "sub_tile" (a~d).
    ( a: left-top sub_tile / b: left-bottom sub_tile / c: right-top sub_tile / d: right_bottom sub_tile. )
  - Filling 4*4*Ni buffer takes `Ni`/32 * 4 cycles.
  - When the data comes, parse it to store in the IFM buffer. See `getAddr()` function (conv_maxpool_modul.v:241-252).

  - After processing one frame, re-load the IFM into the buffer.
  - Before getting new feature maps, we have to copy the data of sub_tile c and d into a and b, respectively.
  - Note that we do not have to copy sub_tile when we fetch a new row.
  - See `conv_maxpool_modul.v:1231-1250` for detailed implementation.

3. FSM States
(1) STATE_IDLE
  - The first state when the module starts.

(2) STATE_GET_B
  - The module gets the bias from the testbench.
  - Note that the bias data size is small enough to be stored within the module

(3) STATE_GET_F
  - The module gets the IFM tile from the testbench.
  - See `2. IFM Buffer Implementation` for description.

(4) STATE_RUN
  - Leverage streaming weight rather than storing it.
  - Just re-shape the input weights. See `conv_maxpool_module.v:128-140` for detailed implementation.
  - Do MAC, max-pooling, and data-sending in parallel.
  - State transition into `STATE_GET_F` when processed given frame.
  - State transition into `STATE_DONE` when processing all frames.

(5) STATE_DONE
  - Notify the testbench that the module is done, via the `conv_done` signal.
===========

== BRAM_top.v ==
 ** Incomplete module 
(0) Purpose
 - Instantiate BRAM and store weight, bias, and feature map each layer
 - Providing appropriate data for the conv_maxpool module

(1) Write BRAM
 - Stack 32 bits of data per cycle in weight_i_buffer and ofm_i_buffer, since DMA can read 32 bits per cycle from DRAM
 - Except for layer00, receive ofm 256 bits from conv_maxpool module

(2) Read BRAM
 - When conv_maxpool module sends ready_w, ready_b or ready_f, reads appropriate date from BRAM and increments each counter
 - With each counter, calculate the appropriate address for each BRAM
 - For weight and bias, the counter rotates for each pixel of the feature map (feature map stationary implementation in conv_maxpool module)
 - Since BRAM has 2-cycle delay, use 2 cycles delayed counters and valid signals for exact timing and getting back counters in case ready signals become off during the delaying time

(3) Zero padding
 - Check whether the reading column or row is padding area
 - Using is_first_row, is_first_col, is_last_row, is_last_col value, provide 256 zeros
=============

