/**
 * @ Author: German Cano Quiveu, germancq
 * @ Create Time: 2021-06-09 16:59:50
 * @ Modified by: German Cano Quiveu, germancq
 * @ Modified time: 2021-06-10 12:15:23
 * @ Description:
 */

module wb_sdspi #(
    parameter  CLK_FQ_KHZ = 100000
) 
(
    input                           wb_clk,
    input                           wb_rst,
    //wishbone interface
    input [1:0] wb_adr_i,
    input [31:0]       wb_dat_i,
    input                           wb_we_i,
    input                           wb_cyc_i,
    input                           wb_stb_i,
    input [3:0]  wb_sel_i,
    input [2:0]                     wb_cti_i,
    input [1:0]                     wb_bte_i,
    output logic                    wb_ack_o,
    output logic                    wb_err_o,
    output                          wb_rty_o,
    output [31:0]      wb_dat_o,

    //////////////
    output                          sclk,
    output                          cs,
    output                          mosi,
    input                           miso,
    output [31:0]                   debug
);

    logic        spi_rst;
    logic        spi_r_block;
    logic        spi_r_multi_block;
    logic        spi_r_byte;
    logic        spi_w_block;
    logic        spi_w_byte;
    logic [31:0] spi_block_addr;
    logic [7:0]  spi_dat_i;
    logic [4:0]  spi_sclk_speed;
    logic        spi_busy;
    logic        spi_err;
    logic [7:0]  spi_dat_o;

    wb_sdspi_adapter sdspi_adapter_inst(
        .wb_clk(wb_clk),
        .wb_rst(wb_rst),
        .wb_adr_i(wb_adr_i),
        .wb_dat_i(wb_dat_i),
        .wb_we_i(wb_we_i),
        .wb_cyc_i(wb_cyc_i),
        .wb_stb_i(wb_stb_i),
        .wb_sel_i(wb_sel_i),
        .wb_cti_i(wb_cti_i),
        .wb_bte_i(wb_bte_i),
        .wb_ack_o(wb_ack_o),
        .wb_err_o(wb_err_o),
        .wb_rty_o(wb_rty_o),
        .wb_dat_o(wb_dat_o),
        .spi_rst(spi_rst),
        .spi_r_block(spi_r_block),
        .spi_r_multi_block(spi_r_multi_block),
        .spi_r_byte(spi_r_byte),
        .spi_w_byte(spi_w_byte),
        .spi_w_block(spi_w_block),
        .spi_block_addr(spi_block_addr),
        .spi_dat_i(spi_dat_i),
        .spi_sclk_speed(spi_sclk_speed),
        .spi_busy(spi_busy),
        .spi_err(spi_err),
        .spi_dat_o(spi_dat_o),
        .debug(debug)
    );

    sdspihost #(.CLK_FQ_KHZ(CLK_FQ_KHZ)) sdspi_inst(
        .clk(wb_clk),
        .reset(spi_rst),
        .busy(spi_busy),
        .err(spi_err),
        .r_block(spi_r_block),
        .r_multi_block(spi_r_multi_block),
        .r_byte(spi_r_byte),
        .w_block(spi_w_block),
        .w_byte(spi_w_byte),
        .block_addr(spi_block_addr),
        .data_out(spi_dat_o),
        .data_in(spi_dat_i),
        .miso(miso),
        .mosi(mosi),
        .sclk(sclk),
        .ss(cs),
        .sclk_speed(spi_sclk_speed),
        .debug()
    );
    
endmodule:wb_sdspi