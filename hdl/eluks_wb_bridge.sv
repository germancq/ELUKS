/**
 * @ Author: German Cano Quiveu, germancq
 * @ Create Time: 2022-02-22 11:37:45
 * @ Modified by: German Cano Quiveu, germancq
 * @ Modified time: 2022-02-22 15:32:34
 * @ Description:
 */

module eluks_wb_bridge 
#(parameter WB_DATA_WIDTH=32,
  parameter WB_ADDR_DIR=8,
  parameter PSW_WIDTH = 64)
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
    //eluks interface
    output logic                    eluks_rst_o,    
    output logic [PSW_WIDTH-1:0]    eluks_user_password_o,
    output                          eluks_hmac_enable_o,
    output logic [31:0]             eluks_first_block_o,
    output logic [31:0]             eluks_block_addr_o,
    output logic                    eluks_r_block_o,
    output logic                    eluks_r_multi_block_o,
    output logic                    eluks_r_byte_o,
    input                           eluks_busy_i,
    input  [7:0]                    eluks_dat_i,
    input                           eluks_end_header_i,
    input                           eluks_error,
    input  [31:0]                   eluks_total_blocks_o,
    
    output [31:0]                   debug    
);

    localparam PSW_SLOT_0 = 0;
    localparam PSW_SLOT_1 = 1;
    localparam START_BLOCK_SLOT = 2;
    localparam BLOCK_ADDR_SLOT = 3;
    localparam HMAC_ENABLE_SLOT = 4;
    localparam RQ_DATA_SLOT = 5;
    localparam RQ_STATUS = 6;




    //cte values
    assign wb_rty_o = 0;

    logic [WB_DATA_WIDTH-1:0] bank_register [WB_ADDR_DIR-1:0];

    genvar i;
   //register data from wishbone bus
   generate
        for (i = 0;i<(WB_ADDR_DIR) ;i=i+1 ) begin
            register #(.DATA_WIDTH(WB_DATA_WIDTH)) r_banks(
                .clk(wb_clk),
                .cl(wb_rst),
                .w(wb_adr_i == i ? (wb_stb_i & wb_we_i) : 0 ),
                .din(wb_dat_i),
                .dout(bank_register[i])
            );
        end
    endgenerate 

    

    assign eluks_user_password_o = {bank_register[PSW_SLOT_0],bank_register[PSW_SLOT_1]};
    assign eluks_first_block_o = bank_register[START_BLOCK_SLOT];
    assign eluks_block_addr_o = bank_register[BLOCK_ADDR_SLOT];
    assign eluks_hmac_enable_o = bank_register[HMAC_ENABLE_SLOT];
    
    logic r_data_w;
    logic [WB_DATA_WIDTH-1:0] wb_data;
    //register data to wishbone bus
    register #(.DATA_WIDTH(WB_DATA_WIDTH)) r_data(
                .clk(wb_clk),
                .cl(wb_rst),
                .w(r_data_w),
                .din(wb_data),
                .dout(wb_dat_o)
            ); 

    logic eluks_r_multi_block_cl;
    logic eluks_r_multi_block_w;
    register #(.DATA_WIDTH(1)) r_eluks_r_multi_block(
                .clk(wb_clk),
                .cl(eluks_r_multi_block_cl),
                .w(eluks_r_multi_block_w),
                .din(1'b1),
                .dout(eluks_r_multi_block_o)
    );
    
    //control unit
    localparam START_STATE = 0;
    localparam IDLE = 1;
    localparam BLOCK_ADDR_OP_0 = 2;
    localparam BLOCK_ADDR_OP_1 = 3;
    localparam BLOCK_ADDR_OP_2 = 4;
    localparam RQ_DATA_OP_0 = 5;
    localparam RQ_DATA_OP_1 = 6;
    localparam RQ_DATA_OP_2 = 7;
    localparam RQ_STATUS_OP_0 = 8;
    localparam RQ_STATUS_OP_1 = 9;
    localparam END_OP = 10;
    localparam CHECK_BUSY_FLAG = 11;

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

    always_comb begin 
        eluks_rst_o = 0;
        eluks_r_byte_o = 0;
        eluks_r_block_o = 0;

        eluks_r_multi_block_cl = 0;
        eluks_r_multi_block_w = 0;

        
        wb_err_o = 0;
        wb_ack_o = 0;

        r_data_w = 0;

        r_jmp_state_w = 0;
        r_jmp_state_i = START_STATE;

        wb_data = eluks_dat_i;

        next_state = current_state;

        case(current_state)
            START_STATE: begin
                eluks_rst_o = 1;
                next_state = IDLE;
            end
            IDLE:begin
                eluks_rst_o = ~eluks_end_header_i;
                if(wb_stb_i) begin
                    case (wb_adr_i)
                        BLOCK_ADDR_SLOT: next_state = BLOCK_ADDR_OP_0;
                        RQ_DATA_SLOT: next_state = RQ_DATA_OP_0;
                        RQ_STATUS: next_state = RQ_STATUS_OP_0;
                        default: next_state = END_OP;
                    endcase
                end
            end 
            BLOCK_ADDR_OP_0: begin
                eluks_rst_o = ~eluks_end_header_i;
                eluks_r_multi_block_cl = 1;
                next_state = BLOCK_ADDR_OP_1;
                
            end
            BLOCK_ADDR_OP_1: begin
                eluks_rst_o = ~eluks_end_header_i;
                if(eluks_end_header_i == 1) begin
                    r_jmp_state_w = 1;
                    r_jmp_state_i = BLOCK_ADDR_OP_2;
                    next_state = CHECK_BUSY_FLAG;
                end
                else begin
                    eluks_r_multi_block_w = 1;
                    next_state = END_OP;
                end
            end
            BLOCK_ADDR_OP_2: begin
                eluks_rst_o = ~eluks_end_header_i;
                eluks_r_multi_block_w = 1;
                next_state = END_OP;
            end
            RQ_DATA_OP_0: begin

                r_jmp_state_w = 1;
                r_jmp_state_i = RQ_DATA_OP_1;
                
                if(eluks_end_header_i) begin
                    next_state = CHECK_BUSY_FLAG;
                end
            end
            RQ_DATA_OP_1: begin
                eluks_r_byte_o = 1;

                r_jmp_state_w = 1;
                r_jmp_state_i = RQ_DATA_OP_2;

                next_state = CHECK_BUSY_FLAG;
            end
            RQ_DATA_OP_2: begin
                r_data_w = 1;
                next_state = END_OP;
            end
            RQ_STATUS_OP_0: begin
                wb_data = {eluks_error, eluks_total_blocks_o[WB_DATA_WIDTH-2:0]};
                if(eluks_end_header_i) begin
                    next_state = RQ_STATUS_OP_1;
                end
            end
            RQ_STATUS_OP_1: begin
                wb_data = {eluks_error, eluks_total_blocks_o[WB_DATA_WIDTH-2:0]};
                r_data_w = 1;
                next_state = END_OP;
            end
            CHECK_BUSY_FLAG: begin
                if(eluks_busy_i == 0) begin
                    next_state = jmp_state;
                end
            end
            END_OP: begin
                eluks_rst_o = ~eluks_end_header_i;
                wb_ack_o = 1;
                if(wb_stb_i == 0) begin
                    next_state = IDLE;
                end
            end
            default: begin
                wb_err_o = 1;
            end
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

    //assign debug = {wb_dat_i[3:0],1'b0,wb_adr_i[2:0],1'b0,current_state};
    assign debug = {current_state};//1'b0,wb_adr_i[2:0],wb_cyc_i,wb_stb_i,wb_we_i,wb_ack_o};

endmodule : eluks_wb_bridge