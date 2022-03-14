/**
 * @Author: German Cano Quiveu <germancq>
 * @Date:   2018-11-13T12:23:24+01:00
 * @Email:  germancq@dte.us.es
 * @Filename: pulse_button.v
 * @Last modified by:   germancq
 * @Last modified time: 2018-11-13T12:41:19+01:00
 */


module pulse_button(
	input clk,
	input reset,
	input button,
	output pulse);

wire currentValue_q;
wire currentValue_not_q;
wire previousValue_q;
wire previousValue_not_q;

biestable_d currentValue(
	.clk(clk),
	.reset(reset),
	.d(button),
	.q(currentValue_q),
	.not_q(currentValue_not_q)
);

biestable_d previousValue(
	.clk(clk),
	.reset(reset),
	.d(currentValue_q),
	.q(previousValue_q),
	.not_q(previousValue_not_q)
);

and_gate and1(
	.a(currentValue_q),
	.b(previousValue_not_q),
	.c(pulse)
);

endmodule : pulse_button

module biestable_d(
	input clk,
	input reset,
	input d,
	output reg q,
	output not_q);

always @(posedge clk)
begin
	if(reset == 1'b1)
		q <= 1'b0;
	else
		q <= d;
end

assign not_q = ~q;

endmodule : biestable_d

module and_gate(
	input a,
	input b,
	output c);

assign c = a & b;

endmodule : and_gate