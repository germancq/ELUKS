/**
 * @ Author: German Cano Quiveu, germancq
 * @ Create Time: 2022-02-22 13:35:16
 * @ Modified by: German Cano Quiveu, germancq
 * @ Modified time: 2022-03-04 12:27:51
 * @ Description:
 */

module wb_eluks
#(
    parameter CLK_FQ_KHZ = 100000,
    parameter WB_ADDR_DIR = 8,
    parameter WB_DATA_WIDTH = 32,
    parameter PSW_WIDTH = 64,
    parameter SALT_WIDTH = 64,
    parameter COUNT_WIDTH = 32,
    parameter BLOCK_SIZE = 64,
    parameter KEY_SIZE = 80,
    parameter N = 88,
    parameter c = 80,
    parameter r = 8,
    parameter R = 45,
    parameter lCounter_initial_state = 6'h05,
    parameter lCounter_feedback_coeff = 7'h61,
    parameter N_kdf = 88,
    parameter c_kdf = 80,
    parameter r_kdf = 8,
    parameter R_kdf = 45,
    parameter lCounter_initial_state_kdf = 6'h05,
    parameter lCounter_feedback_coeff_kdf = 7'h61
) 
(
    input                           wb_clk,
    input                           wb_rst,
    //wishbone interface
    input [$clog2(WB_ADDR_DIR)-1:0] wb_adr_i,
    input [WB_DATA_WIDTH-1:0]       wb_dat_i,
    input                           wb_we_i,
    input                           wb_cyc_i,
    input                           wb_stb_i,
    input [(WB_DATA_WIDTH>>3)-1:0]  wb_sel_i,
    input [2:0]                     wb_cti_i,
    input [1:0]                     wb_bte_i,
    output logic                    wb_ack_o,
    output logic                    wb_err_o,
    output                          wb_rty_o,
    output [WB_DATA_WIDTH-1:0]      wb_dat_o,

    //////////////
    output                          sclk,
    output                          cs,
    output                          mosi,
    input                           miso,

    input [4:0]                     sclk_speed,

    
    
    output [31:0]                   debug,
    input                           dbg_btn
);


    logic eluks_rst;
    logic [PSW_WIDTH-1:0] eluks_user_password;
    logic [31:0] eluks_first_block;
    logic [31:0] total_blocks;
    logic [31:0] eluks_block_addr;
    logic eluks_r_block;
    logic eluks_r_multi_block;
    logic eluks_r_byte;
    logic eluks_busy;
    logic [7:0] eluks_data;
    logic eluks_end_header;
    logic [31:0] spi_block_addr;
    logic [7:0] spi_data;
    logic spi_busy;
    logic spi_r_block;
    logic spi_r_byte;
    logic spi_r_multi_block;
    logic spi_err;
    logic eluks_error;

    

    eluks_wb_bridge #(
        .WB_DATA_WIDTH(WB_DATA_WIDTH),
        .WB_ADDR_DIR(WB_ADDR_DIR),
        .PSW_WIDTH(PSW_WIDTH)
    ) 
    bridge_inst(
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
        .eluks_rst_o(eluks_rst),
        .eluks_user_password_o(eluks_user_password),
        .eluks_hmac_enable_o(eluks_hmac_enable),
        .eluks_first_block_o(eluks_first_block),
        .eluks_block_addr_o(eluks_block_addr),
        .eluks_r_block_o(eluks_r_block),
        .eluks_r_multi_block_o(eluks_r_multi_block),
        .eluks_r_byte_o(eluks_r_byte),
        .eluks_busy_i(eluks_busy),
        .eluks_dat_i(eluks_data),
        .eluks_end_header_i(eluks_end_header),
        .eluks_total_blocks_o(total_blocks),
        .eluks_error(eluks_error),
        .debug(debug[7:0])
    );

    eluks #(
        .PSW_WIDTH(PSW_WIDTH),
        .SALT_WIDTH(SALT_WIDTH),
        .COUNT_WIDTH(COUNT_WIDTH),
        .BLOCK_SIZE(BLOCK_SIZE),
        .KEY_SIZE(KEY_SIZE),
        .N(N),
        .c(c),
        .r(r),
        .R(R),
        .lCounter_initial_state(lCounter_initial_state),
        .lCounter_feedback_coeff(lCounter_feedback_coeff),
        .N_kdf(N_kdf),
        .c_kdf(c_kdf),
        .r_kdf(r_kdf),
        .R_kdf(R_kdf),
        .lCounter_initial_state_kdf(lCounter_initial_state_kdf),
        .lCounter_feedback_coeff_kdf(lCounter_feedback_coeff_kdf)
    )
    eluks_inst(
        .clk(wb_clk),
        .rst(eluks_rst),
        .user_password(eluks_user_password),
        .eluks_first_block(eluks_first_block),
        .hmac_enable(eluks_hmac_enable),
        .block_addr(eluks_block_addr),
        .r_block(eluks_r_block),
        .r_multi_block(eluks_r_multi_block),
        .r_byte(eluks_r_byte),
        .eluks_busy(eluks_busy),
        .eluks_data(eluks_data),
        .spi_block_addr(spi_block_addr),
        .spi_r_block(spi_r_block),
        .spi_r_multi_block(spi_r_multi_block),
        .spi_r_byte(spi_r_byte),
        .spi_data(spi_data),
        .spi_busy(spi_busy),
        .spi_err(spi_err),
        .end_eluks_header(eluks_end_header),
        .total_blocks(total_blocks),
        .error(eluks_error),
        .debug_data(debug[15:8])
    );

    sdspihost #(
        .CLK_FQ_KHZ(CLK_FQ_KHZ)
    )
    spi_inst(
        .clk(wb_clk),
        .reset(eluks_rst),
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
        .sclk_speed(sclk_speed),
        .debug(debug[31:16])
    );
    
endmodule : wb_eluks  