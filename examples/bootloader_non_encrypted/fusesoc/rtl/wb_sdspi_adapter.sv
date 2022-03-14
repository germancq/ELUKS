/**
 * @ Author: German Cano Quiveu, germancq
 * @ Create Time: 2021-06-09 13:53:43
 * @ Modified by: German Cano Quiveu, germancq
 * @ Modified time: 2022-03-02 16:23:51
 * @ Description:
 */

module wb_sdspi_adapter (
    input           wb_clk,
    input           wb_rst,

    input [1:0]     wb_adr_i,
    input [31:0]    wb_dat_i,
    input           wb_we_i,
    input           wb_cyc_i,
    input           wb_stb_i,
    input [3:0]     wb_sel_i,
    input [2:0]     wb_cti_i,
    input [1:0]     wb_bte_i,
    output logic    wb_ack_o,
    output logic    wb_err_o,
    output          wb_rty_o,
    output [31:0]   wb_dat_o,

    output logic    spi_rst,
    output          spi_r_block,
    output          spi_r_multi_block,
    output logic    spi_r_byte,
    output          spi_w_block,
    output          spi_w_byte,
    output [31:0]   spi_block_addr,
    output [7:0]    spi_dat_i,
    output [4:0]    spi_sclk_speed,
    input           spi_busy,
    input           spi_err,
    input  [7:0]    spi_dat_o,

    
    output [31:0]   debug
    );

    localparam BLOCK_ADDR_SLOT = 0;
    localparam RQ_DATA_SLOT = 1;
    localparam SCLK_SLOT = 2;

    //cte values
    assign wb_rty_o = 0;
    assign spi_r_block = 0;
    assign spi_w_block = 0;
    assign spi_w_byte = 0;
    assign spi_dat_i = 8'h00;

    //register wb data
    logic [31:0] bank_register [7:0];
    genvar i;
    //register data from wishbone bus
    generate
        for (i = 0;i<(4) ;i=i+1 ) begin
            register #(.DATA_WIDTH(32)) r_banks(
                .clk(wb_clk),
                .cl(wb_rst),
                .w(wb_adr_i == i ? (wb_stb_i & wb_we_i) : 0 ),
                .din(wb_dat_i),
                .dout(bank_register[i])
            );
        end
    endgenerate 
    
    assign spi_block_addr = bank_register[BLOCK_ADDR_SLOT];
    assign spi_sclk_speed = bank_register[SCLK_SLOT];

    logic r_data_w;
    //register data to wishbone bus
    register #(.DATA_WIDTH(32)) r_data(
                .clk(wb_clk),
                .cl(wb_rst),
                .w(r_data_w),
                .din({{(24){1'b0}},spi_dat_o}),
                .dout(wb_dat_o)
            ); 
    
    logic spi_r_multi_block_cl;
    logic spi_r_multi_block_w;
    register #(.DATA_WIDTH(1)) r_spi_r_multi_block(
                .clk(wb_clk),
                .cl(spi_r_multi_block_cl),
                .w(spi_r_multi_block_w),
                .din(1'b1),
                .dout(spi_r_multi_block)
    );

    
    localparam START_STATE = 0;
    localparam IDLE = 1;
    localparam BLOCK_ADDR_OP_0 = 2;
    localparam BLOCK_ADDR_OP_1 = 3;
    localparam BLOCK_ADDR_OP_2 = 4;
    localparam RQ_DATA_OP_0 = 5;
    localparam RQ_DATA_OP_1 = 6;
    localparam END_OP = 7;
    localparam CHECK_BUSY_FLAG = 8;


    logic [3:0] current_state,next_state,jmp_state;

    logic r_jmp_state_w;
    logic [3:0] r_jmp_state_i;
    register #(.DATA_WIDTH(4)) r_jmp_state(
                .clk(wb_clk),
                .cl(wb_rst),
                .w(r_jmp_state_w),
                .din(r_jmp_state_i),
                .dout(jmp_state)
            );

    always_comb begin 

        next_state = current_state;

        r_data_w = 0;
        spi_r_multi_block_w = 0;
        spi_r_multi_block_cl = 0;
        
        wb_ack_o = 0;
        wb_err_o = 0;
        spi_rst = 0;
        spi_r_byte = 0;

        r_jmp_state_w = 0;
        r_jmp_state_i = START_STATE;

        case (current_state)
            START_STATE:begin
                spi_r_multi_block_cl = 1;
                spi_rst = 1;
                r_jmp_state_w = 1;
                r_jmp_state_i = IDLE;
                next_state = CHECK_BUSY_FLAG;
            end
            IDLE:begin
                if(wb_stb_i) begin
                    case (wb_adr_i)
                        BLOCK_ADDR_SLOT: next_state = BLOCK_ADDR_OP_0;
                        RQ_DATA_SLOT: next_state = RQ_DATA_OP_0;
                        default: next_state = END_OP;
                    endcase
                end
            end 
            BLOCK_ADDR_OP_0:begin
                spi_r_multi_block_cl = 1;
                r_jmp_state_w = 1;
                r_jmp_state_i = BLOCK_ADDR_OP_1;
                next_state = CHECK_BUSY_FLAG;
            end
            BLOCK_ADDR_OP_1:begin
                spi_r_multi_block_w = 1;
                r_jmp_state_w = 1;
                r_jmp_state_i = BLOCK_ADDR_OP_2;
                next_state = CHECK_BUSY_FLAG;
            end
            //EN MULTIBLOCK EL PRIMER BYTE SE DESCARTA
            BLOCK_ADDR_OP_2:begin
                spi_r_byte = 1;
                r_jmp_state_w = 1;
                r_jmp_state_i = END_OP;
                next_state = CHECK_BUSY_FLAG;
            end
            RQ_DATA_OP_0: begin
                r_data_w = 1;
                next_state = RQ_DATA_OP_1;
            end
            RQ_DATA_OP_1: begin
                spi_r_byte = 1;
                r_jmp_state_w = 1;
                r_jmp_state_i = END_OP;
                next_state = CHECK_BUSY_FLAG;
            end
            CHECK_BUSY_FLAG: begin
                if(spi_busy == 0) begin
                    next_state = jmp_state;
                end
            end
            END_OP: begin
                wb_ack_o = 1;
                if(wb_stb_i == 0) begin
                    next_state = IDLE;
                end
            end
            default: wb_err_o = 1;
        endcase

    end

    always_ff @( posedge wb_clk ) begin
        if(wb_rst) begin
            current_state <= START_STATE;
        end
        else begin
            current_state <= next_state;
        end
        
    end

    assign debug = {current_state};

endmodule : wb_sdspi_adapter