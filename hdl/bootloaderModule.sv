/**
 * @ Author: German Cano Quiveu, germancq
 * @ Create Time: 2022-02-22 12:43:31
 * @ Modified by: German Cano Quiveu, germancq
 * @ Modified time: 2023-02-14 17:49:01
 * @ Description:
 */

module bootloaderModule 
#(parameter WB_DATA=32,
  parameter ELUKS_WB_ADDR = 32'h92000000,
  parameter RAM_WB_ADDR = 0)
(
    input                           wb_clk,
    input                           rst,
    input                           clk_ctr,
    output logic                    bus_rst,
    output logic                    wb_rst_o,

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
    input   [63:0]                  psw,
    input   [31:0]                  start_block,
    input                           hmac_enable,
    
    
    output [31:0]                   debug,
    output logic                    error,
    output [63:0]                   exec_timer,
    input                           dbg_btn
);
    
    
    localparam ELUKS_PSW_0_ADDR        = ELUKS_WB_ADDR + 0;
    localparam ELUKS_PSW_1_ADDR        = ELUKS_WB_ADDR + 1;
    localparam ELUKS_START_BLOCK_ADDR  = ELUKS_WB_ADDR + 2;
    localparam ELUKS_BLOCK_DIR_ADDR    = ELUKS_WB_ADDR + 3;
    localparam ELUKS_HMAC_ENABLE_ADDR  = ELUKS_WB_ADDR + 4;
    localparam ELUKS_RQ_DATA_ADDR      = ELUKS_WB_ADDR + 5;
    localparam ELUKS_RQ_STATUS_ADDR    = ELUKS_WB_ADDR + 6;

    logic [31:0] total_blocks;
    logic        eluks_error;
    logic [WB_DATA-1:0] status;
    logic status_cl;
    logic [WB_DATA-1:0] status_i;
    logic status_w;

    assign total_blocks = status[WB_DATA-2:0];
    assign eluks_error = status[WB_DATA-1:WB_DATA-1];

    register #(.DATA_WIDTH(WB_DATA)) reg_status(
                .clk(wb_clk),
                .cl(status_cl),
                .w(status_w),
                .din(wb_dat_i),
                .dout(status)
            );



    logic rst_exec_timer;
    logic up_exec_timer;

    counter #(.DATA_WIDTH(64)) counter_exec_timer(
        .clk(wb_clk),
        .rst(rst_exec_timer),
        .up(up_exec_timer),
        .down(1'b0),
        .din(32'h0),
        .dout(exec_timer)
    );

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


    logic [31:0] counter_rst_state_o;
    logic rst_counter_rst_state;

    counter #(.DATA_WIDTH(32)) counter_rst_state(
        .clk(clk_ctr),
        .rst(rst_counter_rst_state),
        .up(1'b1),
        .down(1'b0),
        .din(32'h0),
        .dout(counter_rst_state_o)
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
    logic [0:0] reg_eluks_data_cl [3:0];
    logic [0:0] reg_eluks_data_w [3:0];
    logic [31:0] eluks_data;
    generate
        for (i = 0;i < 4 ;i = i+1 ) begin
            register #(.DATA_WIDTH(8)) r_i(
                .clk(wb_clk),
                .cl(reg_eluks_data_cl[i]),
                .w(reg_eluks_data_w[i]),
                .din(wb_dat_i[7:0]),
                .dout(eluks_data[(i<<3)+7:(i<<3)])
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

    localparam RST_STATE = 0;
    localparam IDLE = 1;
    localparam SEND_PSW_0_ADDR = 2;
    localparam SEND_PSW_0_CMD = 3;
    localparam SEND_PSW_1_ADDR = 4;
    localparam SEND_PSW_1_CMD = 5;
    localparam SEND_START_BLOCK_ADDR = 6;
    localparam SEND_START_BLOCK_CMD = 7;
    localparam SEND_HMAC_ENABLE_ADDR = 8;
    localparam SEND_HMAC_ENABLE_CMD = 9;
    localparam SEND_BLOCK_DIR_ADDR = 10;
    localparam SEND_BLOCK_DIR_CMD = 11;
    localparam SEND_RQ_STATUS_ADDR = 12;
    localparam SEND_RQ_STATUS_CMD = 13;
    localparam SET_TOTAL_BLOCK_AND_ERROR = 14;
    localparam CHECK_ERROR = 15;
    localparam CHECK_LOOP_COND = 16;
    localparam SEND_RQ_BYTE_ADDR = 17;
    localparam SEND_RQ_BYTE_CMD = 18;
    localparam RAM_STEP_0 = 19;
    localparam RAM_STEP_1 = 20;
    localparam RAM_STEP_2 = 21;
    localparam END_BOOT = 22;
    localparam WAIT_ACK_ELUKS = 23;
    localparam WAIT_NEG_ACK_ELUKS = 24;
    localparam ERROR = 25;

    logic [4:0] current_state, next_state, jmp_state;

    logic r_jmp_state_w;
    logic [4:0] r_jmp_state_i;
    register #(.DATA_WIDTH(5)) r_jmp_state(
                .clk(wb_clk),
                .cl(rst),
                .w(r_jmp_state_w),
                .din(r_jmp_state_i),
                .dout(jmp_state)
            );

    logic [31:0] j;

    always_comb begin 

        next_state = current_state;

        up_exec_timer = 1;
        rst_exec_timer = 0;
        
        cpu_rst = 1;
        error = 0;

        status_cl = 0;
        status_w = 0;

        bus_rst = 0;
        rst_counter_rst_state = 1;

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
		    reg_eluks_data_cl[j] = 0;
		    reg_eluks_data_w[j] = 0;
	    end 

        rst_counter_word = 0;
        down_word = 0;

        rst_counter_ram_addr = 0;
        up_counter_ram_addr = 0;

        r_jmp_state_i = IDLE;
        r_jmp_state_w = 0;

        case (current_state)
            RST_STATE: begin
                rst_exec_timer = 1;
                rst_counter_rst_state = 0;
                bus_rst = 1;
                if(counter_rst_state_o > 32'h10) begin
                    next_state = IDLE;
                end
            end
            IDLE: begin
                cpu_rst = 0;

                rst_counter_word = 1;
                rst_counter_ram_addr = 1;

                status_cl = 1;

                r_wb_adr_o_cl = 1;

                for (j = 0;j<4 ;j=j+1 ) begin
					reg_eluks_data_cl[j] = 1;
				end 
                
                if(start) begin
                    next_state = SEND_PSW_0_ADDR;
                end
            end 
            SEND_PSW_0_ADDR:begin
                r_wb_adr_o_w = 1;
                r_wb_adr_o_din = ELUKS_PSW_0_ADDR;
                next_state = SEND_PSW_0_CMD;
            end
            SEND_PSW_0_CMD: begin
                wb_dat_o = psw[63:32];
                wb_cyc_o = 1;
                wb_stb_o = 1;
                wb_sel_o = {(WB_DATA>>3){1'b1}};
                wb_we_o  = 1;

                r_jmp_state_w = 1;
                r_jmp_state_i = SEND_PSW_1_ADDR;
                
                if(wb_ack_i == 1) begin
                    next_state = WAIT_NEG_ACK_ELUKS;
                end    
            end
            SEND_PSW_1_ADDR:begin
                r_wb_adr_o_w = 1;
                r_wb_adr_o_din = ELUKS_PSW_1_ADDR;
                next_state = SEND_PSW_1_CMD;
            end
            SEND_PSW_1_CMD: begin
                wb_dat_o = psw[31:0];
                wb_cyc_o = 1;
                wb_stb_o = 1;
                wb_sel_o = {(WB_DATA>>3){1'b1}};
                wb_we_o  = 1;

                r_jmp_state_w = 1;
                r_jmp_state_i = SEND_START_BLOCK_ADDR;
                
                if(wb_ack_i == 1) begin
                    next_state = WAIT_NEG_ACK_ELUKS;
                end    
            end
            SEND_START_BLOCK_ADDR: begin
                r_wb_adr_o_w = 1;
                r_wb_adr_o_din = ELUKS_START_BLOCK_ADDR;
                next_state = SEND_START_BLOCK_CMD;
            end
            SEND_START_BLOCK_CMD: begin
                wb_dat_o = start_block;
                wb_cyc_o = 1;
                wb_stb_o = 1;
                wb_sel_o = {(WB_DATA>>3){1'b1}};
                wb_we_o  = 1;

                r_jmp_state_w = 1;
                r_jmp_state_i = SEND_HMAC_ENABLE_ADDR;
                
                if(wb_ack_i == 1) begin
                    next_state = WAIT_NEG_ACK_ELUKS;
                end  
            end
            SEND_HMAC_ENABLE_ADDR: begin
                r_wb_adr_o_w = 1;
                r_wb_adr_o_din = ELUKS_HMAC_ENABLE_ADDR;
                next_state = SEND_HMAC_ENABLE_CMD;
            end
            SEND_HMAC_ENABLE_CMD: begin
                wb_dat_o = hmac_enable;
                wb_cyc_o = 1;
                wb_stb_o = 1;
                wb_sel_o = {(WB_DATA>>3){1'b1}};
                wb_we_o  = 1;

                r_jmp_state_w = 1;
                r_jmp_state_i = SEND_BLOCK_DIR_ADDR;
                
                if(wb_ack_i == 1) begin
                    next_state = WAIT_NEG_ACK_ELUKS;
                end 
            end
            SEND_BLOCK_DIR_ADDR: begin
                r_wb_adr_o_w = 1;
                r_wb_adr_o_din = ELUKS_BLOCK_DIR_ADDR;
                next_state = SEND_BLOCK_DIR_CMD;
            end
            SEND_BLOCK_DIR_CMD: begin
                wb_dat_o = start_block;
                wb_cyc_o = 1;
                wb_stb_o = 1;
                wb_sel_o = {(WB_DATA>>3){1'b1}};
                wb_we_o  = 1;

                r_jmp_state_w = 1;
                r_jmp_state_i = SEND_RQ_STATUS_ADDR;
                
                if(wb_ack_i == 1) begin
                    next_state = WAIT_NEG_ACK_ELUKS;
                end 
            end
            /////////RQ STATUS/////////////////////////
            SEND_RQ_STATUS_ADDR: begin
                r_wb_adr_o_w = 1;
                r_wb_adr_o_din = ELUKS_RQ_STATUS_ADDR;
                next_state = SEND_RQ_STATUS_CMD;
            end
            SEND_RQ_STATUS_CMD: begin
                wb_dat_o = 32'h01;
                wb_cyc_o = 1;
                wb_stb_o = 1;
                wb_sel_o = {(WB_DATA>>3){1'b1}};
                wb_we_o  = 1;
                
                r_jmp_state_w = 1;
                r_jmp_state_i = SET_TOTAL_BLOCK_AND_ERROR;

                
                if(wb_ack_i == 1) begin
                    next_state = WAIT_NEG_ACK_ELUKS;
                end
                
            end
            SET_TOTAL_BLOCK_AND_ERROR: begin
                //to take control of the wb_bus
                wb_cyc_o = 1;

                status_w = 1;
                next_state = CHECK_ERROR;
            end
            CHECK_ERROR: begin
                
                next_state = CHECK_LOOP_COND;
                
                 
                if(eluks_error) begin
                    next_state = ERROR;
                end
                
            end

            ///////////////////////////////////////////
            CHECK_LOOP_COND: begin
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
                r_wb_adr_o_din = ELUKS_RQ_DATA_ADDR;
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

                next_state = WAIT_ACK_ELUKS;
            end
            RAM_STEP_0: begin
                rst_counter_word = 1;
                next_state = RAM_STEP_1;
                r_wb_adr_o_w = 1;
                r_wb_adr_o_din = RAM_WB_ADDR + (counter_ram_addr_o<<2);
            end
            RAM_STEP_1: begin
                wb_dat_o = eluks_data;
                wb_we_o = 1'b1;
				wb_cyc_o = 1'b1;
				wb_stb_o = 1'b1;
				wb_sel_o = 4'b1111;
				r_jmp_state_w = 1;
                r_jmp_state_i = RAM_STEP_2;
				if(wb_ack_i == 1'b1) begin
                    next_state = WAIT_NEG_ACK_ELUKS;
                end	
            end
            RAM_STEP_2: begin
                //wb_cyc_o = 1'b1;
				//wb_stb_o = 1'b1;
                //if(dbg_btn) begin
                up_counter_ram_addr = 1;
                next_state = CHECK_LOOP_COND;
                //end
            end
            END_BOOT : begin
                cpu_rst = 0; 
                up_exec_timer = 0;
            end

            
            WAIT_ACK_ELUKS:begin
                wb_cyc_o = 1;
                wb_stb_o = 1;
                if(wb_ack_i == 1) begin
                    //register data
                    down_word = 1'b1;
                    reg_eluks_data_w[counter_word_o[1:0]] = 1;
                    next_state = WAIT_NEG_ACK_ELUKS;
                end
            end
            WAIT_NEG_ACK_ELUKS:begin
                if(wb_ack_i == 0) begin
                    next_state = jmp_state;
                end
            end
            ERROR: begin
                error = 1;
                up_exec_timer = 0;
                cpu_rst = 0;
            end
            default: ;
        endcase

    end


    always_ff @( posedge wb_clk ) begin
        if(rst) begin
            current_state <= RST_STATE;
        end
        else begin
            current_state <= next_state;
        end
        
    end


    //assign debug = {wb_dat_o[3:0],wb_adr_o[3:0],3'b0,current_state};
    //assign debug = {current_state,1'b0,wb_adr_o[2:0],wb_cyc_o,wb_stb_o,wb_we_o,wb_ack_i};
    assign debug = {current_state};
endmodule : bootloaderModule