/**
 * @ Author: German Cano Quiveu, germancq
 * @ Create Time: 2021-10-14 13:49:48
 * @ Modified by: German Cano Quiveu, germancq
 * @ Modified time: 2021-10-25 12:44:30
 * @ Description:
 */

module top (
    input sys_clk_pad_i,
    input rst,

    input [15:0] switch_i,
    output [15:0] leds,
    
    //SPI
	output	   sclk,
	output	   mosi,
	input	   miso,
	output 	   cs,
	output SD_RESET,
	output SD_DAT_1,
	output SD_DAT_2,


	//7seg
	output [6:0] seg,
    output [7:0] AN,
    output DP
);

//SD in SPI_MODE
assign SD_RESET = 1'b0;
assign SD_DAT_1 = 1'b1;
assign SD_DAT_2 = 1'b1;


localparam USER_PASSWORD = 64'h1122334455667788;
localparam START_ELUKS = 0; //block number
localparam START_RAW_DATA = 19; // block number
localparam TOTAL_RAW_DATA = 8 << 9; // total bytes


logic spi_ctl;
logic eluks_2_spi_r_block;
logic eluks_2_spi_r_multi_block;
logic [31:0] eluks_2_spi_block_addr;
logic eluks_2_spi_r_byte;
logic raw_2_spi_r_block;
logic raw_2_spi_r_multi_block;
logic [31:0] raw_2_spi_block_addr;
logic raw_2_spi_r_byte;
logic spi_r_block;
logic spi_r_multi_block;
logic [31:0] spi_block_addr;
logic spi_r_byte;
assign spi_r_block = spi_ctl == 0 ? raw_2_spi_r_block : eluks_2_spi_r_block;
assign spi_r_multi_block = spi_ctl == 0 ? raw_2_spi_r_multi_block : eluks_2_spi_r_multi_block;
assign spi_block_addr = spi_ctl == 0 ? raw_2_spi_block_addr : eluks_2_spi_block_addr;
assign spi_r_byte = spi_ctl == 0 ? raw_2_spi_r_byte : eluks_2_spi_r_byte;

logic eluks_rst;
logic eluks_busy;
logic [7:0] eluks_data;
logic end_eluks_header;
logic eluks_error;

logic spi_rst;
logic [7:0] spi_data;
logic spi_err;
logic spi_busy;

eluks eluks_inst(
    .clk(sys_clk_pad_i),
    .rst(eluks_rst),
    .user_password(USER_PASSWORD),
    .hmac_enable(switch_i[3]),
    .eluks_first_block(START_ELUKS),
    .block_addr(eluks_block_addr),
    .r_block(eluks_r_block),
    .r_multi_block(eluks_r_multi_block),
    .r_byte(eluks_r_byte),
    .eluks_busy(eluks_busy),
    .eluks_data(eluks_data),
    .spi_block_addr(eluks_2_spi_block_addr),
    .spi_r_block(eluks_2_spi_r_block),
    .spi_r_multi_block(eluks_2_spi_r_multi_block),
    .spi_r_byte(eluks_2_spi_r_byte),
    .spi_data(spi_data),
    .spi_busy(spi_busy),
    .spi_err(spi_err),
    .end_eluks_header(end_eluks_header),
    .error(eluks_error),
    .debug_data()
);

sdspihost #(.CLK_FQ_KHZ(100000)) spi_inst(
    .clk(sys_clk_pad_i),
    .reset(spi_rst),
    .busy(spi_busy),
    .err(spi_err),
    .r_block(spi_r_block),
    .r_multi_block(spi_r_multi_block),
    .r_byte(spi_r_byte),
    .w_block(1'b0),
    .w_byte(1'b0),
    .block_addr(spi_block_addr),
    .data_out(spi_data),
    .data_in(8'h0),
    .miso(miso),
    .mosi(mosi),
    .sclk(sclk),
    .ss(cs),
    .sclk_speed(4'h1), //25MHz => 100MHZ/(2^(sclk_speed+1))
    .debug()
);

logic [63:0] exec_time;
logic [63:0] exec_time_raw;
logic [63:0] exec_time_eluks;

assign exec_time = switch_i[0] == 0 ? exec_time_raw : exec_time_eluks ;

logic rst_read_raw = switch_i[1:0] == 0 ? 0 : 1;
logic task1_spi_ctl;
logic task1_rst_eluks;
logic task1_rst_spi;
logic task1_raw_r_block;
logic task1_raw_r_multi_block;
logic task1_raw_r_byte;
logic [31:0] task1_raw_block_addr;


task_read_raw #(
    .BYTES_TO_READ(TOTAL_RAW_DATA),
    .FIRST_BLOCK(START_RAW_DATA)
) task1(
    .clk(sys_clk_pad_i),
    .rst(rst_read_raw | rst),
    .spi_ctl(task1_spi_ctl),
    .rst_eluks(task1_rst_eluks),
    .rst_spi(task1_rst_spi),
    .r_block(task1_raw_r_block),
    .r_multi_block(task1_raw_r_multi_block),
    .r_byte(task1_raw_r_byte),
    .block_addr(task1_raw_block_addr),
    .spi_err(spi_err),
    .spi_data(spi_data),
    .spi_busy(spi_busy),
    .end_signal(leds[0]),
    .exec_time(exec_time_raw)
);

logic rst_read_encrypted = switch_i[1:0] == 1 ? 0 : 1;
logic task2_spi_ctl;
logic task2_rst_eluks;
logic task2_rst_spi;
logic task2_eluks_r_block;
logic task2_eluks_r_multi_block;
logic task2_eluks_r_byte;
logic [31:0] task2_eluks_block_addr;

task_read_encrypted #(.BYTES_TO_READ(TOTAL_RAW_DATA)) task2(
    .clk(sys_clk_pad_i),
    .rst(rst_read_encrypted | rst),
    .spi_ctl(task2_spi_ctl),
    .rst_eluks(task2_rst_eluks),
    .rst_spi(task2_rst_spi),
    .r_block(task2_eluks_r_block),
    .r_multi_block(task2_eluks_r_multi_block),
    .r_byte(task2_eluks_r_byte),
    .block_addr(task2_eluks_block_addr),
    .spi_busy(spi_busy),
    .eluks_data(eluks_data),
    .eluks_busy(eluks_busy),
    .eluks_error(eluks_error),
    .end_eluks_header(end_eluks_header),
    .end_signal(leds[1]),
    .exec_time(exec_time_eluks),
    .error(leds[14])
);

logic rst_compare = switch_i[1:0] == 2 ? 0 : 1;
logic task3_spi_ctl;
logic task3_rst_eluks;
logic task3_rst_spi;
logic task3_raw_r_block;
logic task3_raw_r_multi_block;
logic task3_raw_r_byte;
logic [31:0] task3_raw_block_addr;
logic task3_eluks_r_block;
logic task3_eluks_r_multi_block;
logic task3_eluks_r_byte;
logic [31:0] task3_eluks_block_addr;

task_compare #(
    .BYTES_TO_READ(TOTAL_RAW_DATA),
    .FIRST_RAW_BLOCK(START_RAW_DATA)
) task3 (
    .clk(sys_clk_pad_i),
    .rst(rst_compare | rst),
    .spi_ctl(task3_spi_ctl),
    .rst_eluks(task3_rst_eluks),
    .rst_spi(task3_rst_spi),
    .raw_r_block(task3_raw_r_block),
    .raw_r_multi_block(task3_raw_r_multi_block),
    .raw_r_byte(task3_raw_r_byte),
    .raw_block_addr(task3_raw_block_addr),
    .eluks_r_block(task3_eluks_r_block),
    .eluks_r_multi_block(task3_eluks_r_multi_block),
    .eluks_r_byte(task3_eluks_r_byte),
    .eluks_block_addr(task3_eluks_block_addr),
    .spi_err(spi_err),
    .eluks_err(eluks_error),
    .spi_data(spi_data),
    .eluks_data(eluks_data),
    .end_eluks_header(end_eluks_header),
    .spi_busy(spi_busy),
    .eluks_busy(eluks_busy),
    .end_signal(leds[2]),
    .error(leds[15])
);
    
mux_4 #(.DATA_WIDTH(1)) mux_spi_ctl(
    .a(task1_spi_ctl),
    .b(task2_spi_ctl),
    .c(task3_spi_ctl),
    .d(0),
    .e(spi_ctl),
    .sel(switch_i[1:0])
);

mux_4 #(.DATA_WIDTH(1)) mux_rst_eluks(
    .a(task1_rst_eluks),
    .b(task2_rst_eluks),
    .c(task3_rst_eluks),
    .d(1),
    .e(eluks_rst),
    .sel(switch_i[1:0])
);

mux_4 #(.DATA_WIDTH(1)) mux_rst_spi(
    .a(task1_rst_spi),
    .b(task2_rst_spi),
    .c(task3_rst_spi),
    .d(1),
    .e(rst_spi),
    .sel(switch_i[1:0])
);

mux_4 #(.DATA_WIDTH(1)) mux_raw_r_block(
    .a(task1_raw_r_block),
    .b(0),
    .c(task3_raw_r_block),
    .d(0),
    .e(raw_2_spi_r_block),
    .sel(switch_i[1:0])
);

mux_4 #(.DATA_WIDTH(1)) mux_raw_r_multi_block(
    .a(task1_raw_r_multi_block),
    .b(0),
    .c(task3_raw_r_multi_block),
    .d(0),
    .e(raw_2_spi_r_multi_block),
    .sel(switch_i[1:0])
);

mux_4 #(.DATA_WIDTH(1)) mux_raw_r_byte(
    .a(task1_raw_r_byte),
    .b(0),
    .c(task3_raw_r_byte),
    .d(0),
    .e(raw_2_spi_r_byte),
    .sel(switch_i[1:0])
);

mux_4 #(.DATA_WIDTH(32)) mux_raw_block_addr(
    .a(task1_raw_block_addr),
    .b(0),
    .c(task3_raw_block_addr),
    .d(0),
    .e(raw_2_spi_block_addr),
    .sel(switch_i[1:0])
);

mux_4 #(.DATA_WIDTH(1)) mux_eluks_r_block(
    .a(0),
    .b(task2_eluks_r_block),
    .c(task3_eluks_r_block),
    .d(0),
    .e(eluks_r_block),
    .sel(switch_i[1:0])
);

mux_4 #(.DATA_WIDTH(1)) mux_eluks_r_multi_block(
    .a(0),
    .b(task2_eluks_r_multi_block),
    .c(task3_eluks_r_multi_block),
    .d(0),
    .e(eluks_r_multi_block),
    .sel(switch_i[1:0])
);

mux_4 #(.DATA_WIDTH(1)) mux_eluks_r_byte(
    .a(0),
    .b(task2_eluks_r_byte),
    .c(task3_eluks_r_byte),
    .d(0),
    .e(eluks_r_byte),
    .sel(switch_i[1:0])
);

mux_4 #(.DATA_WIDTH(32)) mux_eluks_block_addr(
    .a(0),
    .b(task2_eluks_block_addr),
    .c(task3_eluks_block_addr),
    .d(0),
    .e(eluks_block_addr),
    .sel(switch_i[1:0])
);


logic [31:0] debug_7_seg;
display #(.N(32),.CLK_HZ(100000000)) seg7(
    .clk(sys_clk_pad_i),
	.rst(rst),
	.din(debug_7_seg),
	.seg(seg),
	.an(AN)
);
assign debug_7_seg = switch_i[15] == 0 ? exec_time[31:0]: exec_time[63:32];

endmodule : top