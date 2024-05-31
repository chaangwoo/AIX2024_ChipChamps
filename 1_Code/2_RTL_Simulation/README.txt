=== conv_tb ===
1. How to run
	(1) Open `conv_tb/conv_tb.xpr` (vivado project)
	(2) Choose the layer you want to simulate: uncomment compiler directive within `define.v:25-35`
	(3) Run simulation
	(4) Check Tcl Console output.
	  - You may check total cycles, including feature map and parameter reading and computing cycles.
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


3. Miscellaneous
  - We separated the behavior of the module using `is_CONV00`, `is_1x1`, and otherwise. This is because our MAC mechanism leveraging `mac_array` differs.
  - The granularity of data-sending is 16*8-bit since all layers except for the first layer have multiple-of-16 `No`.
===========

=== tile_tb ===
1. How to run
	(1) Open `conv_tb/tile_tb.xpr` (vivado project)
	(2) Enable `conv_maxpool_tb.v` (now disabled)
	(2) Run simulation.
	(3) Check Tcl Console output.

2. IFM Buffer Implementation
  - See `1_Code/4_Captured_Results (Waveforms, Utilization)/Structure_IFM_Buffer.jpg`.
  - Since storing all IFMs within the module is NOT practical, we suggest new architecture.
  - Module gets 2*2*32*8-bit (1024-bit) data every cycle, which 

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


3. Miscellaneous
  - We separated the behavior of the module using `is_CONV00`, `is_1x1`, and otherwise. This is because our MAC mechanism leveraging `mac_array` differs.
  - The granularity of data-sending is 16*8-bit since all layers except for the first layer have multiple-of-16 `No`.