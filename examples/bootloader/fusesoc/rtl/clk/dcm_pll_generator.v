/**
 * @Author: German Cano Quiveu <germancq>
 * @Date:   2019-03-13T11:33:52+01:00
 * @Email:  germancq@dte.us.es
 * @Filename: dcm_pll_generator.v
 * @Last modified by:   germancq
 * @Last modified time: 2019-03-14T16:22:10+01:00
 */

module dcm_pll_generator(
  input global_clk_in,
  input rst,
  output locked,
  output clk200,
  output clk100,
  output clk50
  );


//IBUFG drives a global clock net from an external pin.
IBUFG sys_clk_in_ibufg (
	.I	(global_clk_in),
	.O	(global_clk_in_ibufg)
);


assign locked = mmcm_locked;
wire mmcm_clkout0;
wire mmcm_clkout1;
wire mmcm_clkout2;
wire mmcm_clkout3;
wire mmcm_clkout4;
wire mmcm_clkout5;
wire mmcm_clkout_feedback;
wire mmcm_locked;
wire mmcm_clkin_feedback;
//MMCM
/*
  M = CLKFBOUT_MULT_F
  D = DIVCLK_DIVIDE
  On = CLKOUT_DIVIDE
  PFD = Phase Frequency Detector
  Fvco = Fclkin x M/D drives all the counters O
  Foutn = Fclkin x M/(DxOn)

  CLK_OUT
    User configurable clock outputs (0 through 6)
    that can be divided versions of the
    VCO phase outputs (user controllable)
    from 1 (bypassed) to 128.
    The output clocks are phase aligned to each other
    (unless phase shifted) and aligned to the input clock
    with a proper feedback configuration

  Dmin = ceil(Fin/Fpfdmax)
  Dmax = floor(Fin/Fpfdmin)
  Mmin = ceil((Fvcomin/Fin) * Dmin)
  Mmax = floor((Fvcomax/Fin) * Dmax)

  Mideal = (Dmin * Fvcomax)/Fin

  nuestro caso
  Fin = 100MHz
*/
MMCME2_BASE #(
  //Specifies the MMCM programming algorithm affecting the jitter,
  .BANDWIDTH("OPTIMIZED"),
  //specifies the amount to divide the associated CLKOUT clock output
  // values 1-128
  .CLKOUT0_DIVIDE_F(4),
  .CLKOUT1_DIVIDE(8),
  .CLKOUT2_DIVIDE(16),
  .CLKOUT3_DIVIDE(1),
  .CLKOUT4_DIVIDE(1),
  .CLKOUT5_DIVIDE(1),
  .CLKOUT6_DIVIDE(1),
  //Allows specification of the output phase relationship of the associated CLKOUT clock output
  .CLKOUT0_PHASE(0.0),
  .CLKOUT1_PHASE(0.0),
  .CLKOUT2_PHASE(0.0),
  .CLKOUT3_PHASE(0.0),
  .CLKOUT4_PHASE(0.0),
  .CLKOUT5_PHASE(0.0),
  .CLKOUT6_PHASE(0.0),
  //Specifies the Duty Cycle of the associated CLKOUT clock output in percentage
  .CLKOUT0_DUTY_CYCLE(0.50),
  .CLKOUT1_DUTY_CYCLE(0.50),
  .CLKOUT2_DUTY_CYCLE(0.50),
  .CLKOUT3_DUTY_CYCLE(0.50),
  .CLKOUT4_DUTY_CYCLE(0.50),
  .CLKOUT5_DUTY_CYCLE(0.50),
  .CLKOUT6_DUTY_CYCLE(0.50),
  //Specifies the amount to multiply all CLKOUT clock outputs if a different frequency is desired
  //values 2-64
  .CLKFBOUT_MULT_F(8),
  //Specifies the division ratio for all output clocks with respect to the input clock
  //values 1-106
  .DIVCLK_DIVIDE(1),
  //Specifies the phase offset in degrees of the clock feedback output.
  .CLKFBOUT_PHASE(0.0),
  //This attribute is for simulation purposes only.
  .REF_JITTER1(0.010),
  //Specifies the input period in ns
  .CLKIN1_PERIOD(10.000),
  //Wait during the configuration start-up cycle for the MMCM to lock
  .STARTUP_WAIT("FALSE"),
  //Cascades the output divider (counter) CLKOUT6 into the input of the CLKOUT4 divider for an output clock divider that is greater than 128
  .CLKOUT4_CASCADE("FALSE")
)
mcmm(
  .CLKIN1(global_clk_in_ibufg),
  .CLKFBIN(mmcm_clkin_feedback), //Feedback clk
  .RST(rst), //Asynchronous reset signal.
  .PWRDWN(1'b0), //Powers down instantiated but unused

  .CLKOUT0(mmcm_clkout0),
  .CLKOUT1(mmcm_clkout1),
  .CLKOUT2(mmcm_clkout2),
  .CLKOUT3(mmcm_clkout3),
  .CLKOUT4(mmcm_clkout4),
  .CLKOUT5(mmcm_clkout5),
  .CLKFBOUT(mmcm_clkout_feedback), //Dedicated MMCM feedback output

  .LOCKED(mmcm_locked) //An output from the MMCM that indicates when the MMCM has achieved phase alignment
);


//BUFG drives a global clock net from an internal signal.
BUFG clk0(
  .I(mmcm_clkout0),
  .O(clk200)
  );

BUFG clk1(
  .I(mmcm_clkout1),
  .O(clk100)
  );

BUFG clk2(
  .I(mmcm_clkout2),
  .O(clk50)
  );

BUFG clk_feedback(
  .I(mmcm_clkout_feedback),
  .O(mmcm_clkin_feedback)
  );


endmodule
