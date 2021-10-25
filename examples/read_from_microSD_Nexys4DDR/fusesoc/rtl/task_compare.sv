/**
 * @ Author: German Cano Quiveu, germancq
 * @ Create Time: 2021-10-14 16:35:45
 * @ Modified by: German Cano Quiveu, germancq
 * @ Modified time: 2021-10-25 14:20:16
 * @ Description:
 */

module task_compare #(
    parameter BYTES_TO_READ = 256,
    parameter FIRST_RAW_BLOCK = 50
    )
(
    input clk,
    input rst,
    output logic spi_ctl,

    output logic rst_eluks,
    output logic rst_spi,

    output raw_r_block,
    output logic raw_r_multi_block,
    output logic raw_r_byte,
    output [31:0] raw_block_addr,
    output eluks_r_block,
    output logic eluks_r_multi_block,
    output logic eluks_r_byte,
    output [31:0] eluks_block_addr,

    input spi_err,
    input eluks_err,

    input [7:0] spi_data,
    input [7:0] eluks_data,

    input end_eluks_header,

    input spi_busy,
    input eluks_busy,

    output logic end_signal,
    output logic error,
    output [31:0] debug
    
);
    
    assign raw_block_addr = FIRST_RAW_BLOCK;
    assign raw_r_block = 0;
    assign eluks_block_addr = 0;
    assign eluks_r_block = 0;

    logic [63:0] counter_bytes_out;
    logic up_bytes;
    logic rst_counter_bytes;
    counter #(.DATA_WIDTH(64)) counter_bytes_impl(
        .clk(clk),
        .rst(rst_counter_bytes),
        .up(up_bytes),
        .down(1'b0),
        .din(64'h0),
        .dout(counter_bytes_out)
    );

    logic r_w;
    logic [$clog2(BYTES_TO_READ)-1:0] mem_addr;
    logic [7:0] mem_data;
    memory_module #(
        .ADDR($clog2(BYTES_TO_READ)),
        .DATA_WIDTH(8)
    ) mem(
        .clk(clk),
        .r_w(r_w),
        .addr(mem_addr),
        .din(spi_data),
        .dout(mem_data)
    );

    localparam IDLE = 0;
    localparam RST_SPI = 1;
    localparam READ_FIRST_BLOCK = 2;
    localparam WAIT_BLOCK = 3;
    localparam READ_DATA = 4;
    localparam READ_BYTE = 5;
    localparam WAIT_BYTE = 6;   
    localparam INIT_ELUKS = 7;
    localparam WAIT_ELUKS = 8;
    localparam REQUEST_ELUKS_BYTE = 9;
    localparam WAIT_ELUKS_BYTE = 10;
    localparam READ_ELUKS_DATA = 11;
    localparam END_STATE = 12;
    localparam ERROR = 13;

    logic [3:0] current_state;
    logic [3:0] next_state;
    logic [3:0] prev_state;
    /*
    prev state
    */
    logic r_state_prev_cl;
    logic r_state_prev_w;
    logic [3:0] r_state_prev_i;
    logic [3:0] r_state_prev_o;
    register #(.DATA_WIDTH(4)) r_state_prev(
        .clk(clk),
        .cl(r_state_prev_cl),
        .w(r_state_prev_w),
        .din(r_state_prev_i),
        .dout(r_state_prev_o)
    );
    assign prev_state = r_state_prev_o;

    assign debug = {current_state,mem_data,eluks_data};
    always_comb begin
        
        next_state = current_state;
        r_state_prev_cl = 1'b0;
        r_state_prev_w = 1'b0;
        r_state_prev_i = current_state;

        rst_spi = 0;
        rst_eluks = 0;
        
        raw_r_multi_block = 0;
        raw_r_byte = 0;
        eluks_r_multi_block = 0;
        eluks_r_byte = 0;

        end_signal = 0;
        error = 0;

        spi_ctl = 0;
        
        rst_counter_bytes = 1'b0;
        up_bytes = 1'b0;

        r_w = 0;
        mem_addr = counter_bytes_out;


        case (current_state)
            IDLE:   
                begin
                   rst_counter_bytes = 1;
                   rst_eluks = 1; 
                   r_state_prev_cl = 1;
                   next_state = RST_SPI;
                end
            RST_SPI:
                begin
                    rst_spi = 1;
                    rst_eluks = 1;
                    if(prev_state == READ_DATA) begin
                        next_state = INIT_ELUKS;
                    end
                    else begin
                        next_state = READ_FIRST_BLOCK;
                    end
                end
            READ_FIRST_BLOCK:
                begin
                    rst_eluks = 1;
                    
                    if(spi_busy == 0) begin
                        raw_r_multi_block = 1;
                        next_state = WAIT_BLOCK;
                    end
                end
            WAIT_BLOCK:
                begin
                    rst_eluks = 1;
                    raw_r_multi_block = 1;
                    if(spi_busy == 0) begin
                        next_state = READ_DATA;
                    end
                end
            READ_DATA:
                begin
                    r_state_prev_w = 1;
                    rst_eluks = 1;
                    raw_r_multi_block = 1;
                    r_w = 1;
                    if(counter_bytes_out == BYTES_TO_READ-1) begin
                        next_state = RST_SPI;
                    end
                    else begin
                        next_state = READ_BYTE;
                    end
                end
            READ_BYTE: 
                begin
                    rst_eluks = 1;
                    raw_r_multi_block = 1;
                    up_bytes = 1;
                    raw_r_byte = 1;
                    next_state = WAIT_BYTE;
                end
            WAIT_BYTE:
                begin
                    rst_eluks = 1;
                    raw_r_multi_block = 1;
                    if(spi_busy == 0) begin
                        next_state = READ_DATA;
                    end
                end
            INIT_ELUKS:
                begin
                    spi_ctl = 1;
                    rst_counter_bytes = 1;
                    rst_eluks = 1;
                    eluks_r_multi_block = 1;
                    if(spi_busy == 0) begin
                        rst_eluks = 0;
                        next_state = WAIT_ELUKS;
                    end
                end
            WAIT_ELUKS:
                begin
                    spi_ctl = 1;
                    eluks_r_multi_block = 1;
                    if(end_eluks_header == 1 && eluks_busy == 0) begin
                        next_state = REQUEST_ELUKS_BYTE;
                    end
                end
            REQUEST_ELUKS_BYTE:
                begin
                    spi_ctl = 1;
                    eluks_r_multi_block = 1;
                    eluks_r_byte = 1;
                    next_state = WAIT_ELUKS_BYTE;
                end
            WAIT_ELUKS_BYTE:
                begin
                    spi_ctl = 1;
                    eluks_r_multi_block = 1;
                    if(eluks_busy == 0) begin
                        next_state = READ_ELUKS_DATA;
                    end
                end
            READ_ELUKS_DATA:
                begin
                    spi_ctl = 1;
                    eluks_r_multi_block = 1;
                    if(counter_bytes_out == BYTES_TO_READ-1) begin
                        next_state = END_STATE;
                    end
                    else begin
                        if(mem_data != eluks_data) begin
                            next_state = ERROR;
                        end
                        else begin
                            up_bytes = 1;
                            next_state = REQUEST_ELUKS_BYTE;
                        end
                        
                    end
                end
            END_STATE:
                begin
                    end_signal = 1;
                end
            ERROR: 
                begin
                    error = 1;
                end
            default:
                begin
                    
                end
        endcase
    end
    

    always_ff @( posedge clk ) begin
        if (rst) begin
            current_state <= IDLE;
        end
        else if (eluks_err) begin
            current_state <= ERROR;
        end
        else begin
            current_state <= next_state;
        end
    end

endmodule: task_compare