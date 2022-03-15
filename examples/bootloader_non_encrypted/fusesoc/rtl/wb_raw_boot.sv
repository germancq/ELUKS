/**
 * @ Author: German Cano Quiveu, germancq
 * @ Create Time: 2021-06-09 17:26:46
 * @ Modified by: German Cano Quiveu, germancq
 * @ Modified time: 2022-03-15 13:59:02
 * @ Description:
 */

module wb_raw_boot #(
    parameter WB_DATA=32,
    parameter SDSPI_WB_ADDR = 32'h92000000,
    parameter RAM_WB_ADDR = 0
)
(
    input                           wb_clk,
    input                           wb_rst,
    output  logic                   wb_rst_o,

    input                           wb_ack_i,
    input                           wb_err_i,
    input   [WB_DATA - 1:0]         wb_dat_i,
    input                           wb_rty_i,
    output logic [WB_DATA - 1:0]    wb_dat_o,
    output logic                    wb_cyc_o,
    output logic                    wb_stb_o,
    output logic [(WB_DATA>>3)-1:0] wb_sel_o, 
    output logic                    wb_we_o,
    output logic [2:0]              wb_cti_o,
    output logic [1:0]              wb_bte_o,
    output [WB_DATA-1:0]            wb_adr_o,

    

    input                           start,
    output logic                    cpu_rst,
    input   [31:0]                  start_block,
    input   [31:0]                  total_blocks,
    input   [4:0]                   sclk_speed,

    output  [31:0]                  debug,
    output  [63:0]                  exec_timer,
    input                           btn_dbg

);

    localparam SDSPI_BLOCK_DIR_ADDR  = SDSPI_WB_ADDR + 0;
    localparam SDSPI_RQ_DATA_ADDR    = SDSPI_WB_ADDR + 1;
    localparam SDSPI_SCLK_SPEED_ADDR = SDSPI_WB_ADDR + 2;


    logic up_counter_ram_addr;
    logic [31:0] counter_ram_addr_o;
    logic rst_counter_ram_addr;

    counter #(.DATA_WIDTH(32)) counter_addr_ram(
        .clk(wb_clk),
        .rst(rst_counter_ram_addr),
        .up(up_counter_ram_addr),
        .down(1'b0),
        .din(32'h0),
        .dout(counter_ram_addr_o)
    );


    logic up_exec_timer;
    logic rst_exec_timer;

    counter #(.DATA_WIDTH(64)) counter_exec_timer(
        .clk(wb_clk),
        .rst(rst_exec_timer),
        .up(up_exec_timer),
        .down(1'b0),
        .din(32'h0),
        .dout(exec_timer)
    );

    logic rst_counter_word;
    logic [7:0] counter_word_o;
    logic down_word;
    assign counter_word = counter_word_o[2];

    counter #(.DATA_WIDTH(8)) counter_word_i(
        .clk(wb_clk),
        .rst(rst_counter_word),
        .up(1'b0),
        .down(down_word),
        .din(8'h3),
        .dout(counter_word_o)
    );


    genvar i;
    logic [0:0] reg_sdspi_data_cl [3:0];
    logic [0:0] reg_sdspi_data_w [3:0];
    logic [31:0] sdspi_data;
    generate
        for (i = 0;i < 4 ;i = i+1 ) begin
            register #(.DATA_WIDTH(8)) r_i(
                .clk(wb_clk),
                .cl(reg_sdspi_data_cl[i]),
                .w(reg_sdspi_data_w[i]),
                .din(wb_dat_i[7:0]),
                .dout(sdspi_data[(i<<3)+7:(i<<3)])
            );
        end
    endgenerate

    logic r_wb_adr_o_cl;
    logic r_wb_adr_o_w;
    logic [WB_DATA-1:0] r_wb_adr_o_din;
    register #(.DATA_WIDTH(WB_DATA)) r_wb_adr_o(
                .clk(wb_clk),
                .cl(r_wb_adr_o_cl),
                .w(r_wb_adr_o_w),
                .din(r_wb_adr_o_din),
                .dout(wb_adr_o)
            );

    

    localparam IDLE = 0;
    localparam SEND_SCLK_SPEED_ADDR = 1;
    localparam SEND_SCLK_SPEED_CMD = 2;
    localparam SEND_BLOCK_DIR_ADDR = 3;
    localparam SEND_BLOCK_DIR_CMD = 4;
    localparam CHECK_LOOP_COND = 5;
    localparam SEND_RQ_BYTE_ADDR = 6;
    localparam SEND_RQ_BYTE_CMD = 7;
    localparam RAM_STEP_0 = 8;
    localparam RAM_STEP_1 = 9;
    localparam RAM_STEP_2 = 10;
    localparam END_BOOT = 11;
    localparam WAIT_ACK = 12;
    localparam WAIT_NEG_ACK = 13;

    logic [3:0] current_state, next_state, jmp_state;

    logic r_jmp_state_w;
    logic [3:0] r_jmp_state_i;
    register #(.DATA_WIDTH(4)) r_jmp_state(
                .clk(wb_clk),
                .cl(wb_rst),
                .w(r_jmp_state_w),
                .din(r_jmp_state_i),
                .dout(jmp_state)
            );

    logic [31:0] j;

    always_comb begin 

        next_state = current_state;
        
        cpu_rst = 1;

        rst_exec_timer = 0;
        up_exec_timer = 1;

        wb_rst_o = 0;

        r_wb_adr_o_din = 0;
        r_wb_adr_o_cl = 0;
        r_wb_adr_o_w = 0;
        wb_dat_o = 0;
        wb_we_o = 0;
        wb_cyc_o = 0;
        wb_stb_o = 0;
        wb_sel_o = 0;
        wb_cti_o = 0;
        wb_bte_o = 0;

        for (j = 0;j<4 ;j=j+1 ) begin
		    reg_sdspi_data_cl[j] = 0;
		    reg_sdspi_data_w[j] = 0;
	    end 

        rst_counter_word = 0;
        down_word = 0;

        rst_counter_ram_addr = 0;
        up_counter_ram_addr = 0;

        r_jmp_state_i = IDLE;
        r_jmp_state_w = 0;

        case (current_state)
            IDLE: begin
                cpu_rst = 0;
                rst_exec_timer = 1;

                rst_counter_word = 1;
                rst_counter_ram_addr = 1;

                r_wb_adr_o_cl = 1;

                for (j = 0;j<4 ;j=j+1 ) begin
					reg_sdspi_data_cl[j] = 1;
				end 
                
                if(start) begin
                    next_state = SEND_SCLK_SPEED_ADDR;
                end
            end 
            SEND_SCLK_SPEED_ADDR:begin
                r_wb_adr_o_w = 1;
                r_wb_adr_o_din = SDSPI_SCLK_SPEED_ADDR;
                next_state = SEND_SCLK_SPEED_CMD;
            end
            SEND_SCLK_SPEED_CMD: begin
                wb_dat_o = sclk_speed;
                wb_cyc_o = 1;
                wb_stb_o = 1;
                wb_sel_o = {(WB_DATA>>3){1'b1}};
                wb_we_o  = 1;

                r_jmp_state_w = 1;
                r_jmp_state_i = SEND_BLOCK_DIR_ADDR;
                
                if(wb_ack_i == 1) begin
                    next_state = WAIT_NEG_ACK;
                end  
            end
            SEND_BLOCK_DIR_ADDR: begin
                r_wb_adr_o_w = 1;
                r_wb_adr_o_din = SDSPI_BLOCK_DIR_ADDR;
                next_state = SEND_BLOCK_DIR_CMD;
            end
            SEND_BLOCK_DIR_CMD: begin
                wb_dat_o = start_block;
                wb_cyc_o = 1;
                wb_stb_o = 1;
                wb_sel_o = {(WB_DATA>>3){1'b1}};
                wb_we_o  = 1;

                r_jmp_state_w = 1;
                r_jmp_state_i = CHECK_LOOP_COND;

                rst_counter_word = 1;
                
                if(wb_ack_i == 1) begin
                    next_state = WAIT_NEG_ACK;
                end 
            end
            ///////////////////////////////////////////
            CHECK_LOOP_COND: begin
                //if((counter_ram_addr_o<<2) > (total_blocks<<9)) begin
                if((counter_ram_addr_o<<2) > (total_blocks<<9)) begin
                    next_state = END_BOOT;
                end
                else if(counter_word_o > 3) begin
                    next_state = RAM_STEP_0;
                end
                else begin
                    next_state = SEND_RQ_BYTE_ADDR;
                end
            end
            SEND_RQ_BYTE_ADDR: begin
                r_wb_adr_o_w = 1;
                r_wb_adr_o_din = SDSPI_RQ_DATA_ADDR;
                next_state = SEND_RQ_BYTE_CMD;
            end
            SEND_RQ_BYTE_CMD:begin
                wb_dat_o = 32'h01;
                wb_cyc_o = 1;
                wb_stb_o = 1;
                wb_sel_o = {(WB_DATA>>3){1'b1}};
                wb_we_o  = 1;
                
                r_jmp_state_w = 1;
                r_jmp_state_i = CHECK_LOOP_COND;

                next_state = WAIT_ACK;
            end
            RAM_STEP_0: begin
                rst_counter_word = 1;
                next_state = RAM_STEP_1;
                r_wb_adr_o_w = 1;
                r_wb_adr_o_din = RAM_WB_ADDR + (counter_ram_addr_o<<2);
            end
            RAM_STEP_1: begin
                wb_dat_o = sdspi_data;
                wb_we_o = 1'b1;
				wb_cyc_o = 1'b1;
				wb_stb_o = 1'b1;
				wb_sel_o = 4'b1111;
				r_jmp_state_w = 1;
                r_jmp_state_i = RAM_STEP_2;
				if(wb_ack_i == 1'b1) begin
                    next_state = WAIT_NEG_ACK;
                end	
            end
            RAM_STEP_2: begin
                //wb_cyc_o = 1'b1;
				//wb_stb_o = 1'b1;
                //if(btn_dbg) begin
                up_counter_ram_addr = 1;
                next_state = CHECK_LOOP_COND;
                //end
            end
            END_BOOT : begin
                cpu_rst = 0;
                up_exec_timer = 0; 
            end

            
            WAIT_ACK:begin
                wb_cyc_o = 1;
                wb_stb_o = 1;
                if(wb_ack_i == 1) begin
                    //register data
                    down_word = 1'b1;
                    reg_sdspi_data_w[counter_word_o[1:0]] = 1;
                    next_state = WAIT_NEG_ACK;
                end
            end
            WAIT_NEG_ACK:begin
                if(wb_ack_i == 0) begin
                    next_state = jmp_state;
                end
            end

            default: ;
        endcase

    end


    always_ff @( posedge wb_clk ) begin
        if(wb_rst) begin
            current_state <= IDLE;
        end
        else begin
            current_state <= next_state;
        end
        
    end
    
    assign debug = {current_state};
    //assign debug = {wb_dat_i[31:16],wb_adr_o[15:0]};
    
    
endmodule: wb_raw_boot
