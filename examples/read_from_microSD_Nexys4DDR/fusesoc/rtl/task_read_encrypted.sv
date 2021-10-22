/**
 * @ Author: German Cano Quiveu, germancq
 * @ Create Time: 2021-10-14 16:35:29
 * @ Modified by: German Cano Quiveu, germancq
 * @ Modified time: 2021-10-22 12:59:55
 * @ Description:
 */

module task_read_encrypted #(
    parameter BYTES_TO_READ = 256
    )
(
    input clk,
    input rst,
    output spi_ctl,

    output logic rst_eluks,
    output logic rst_spi,

    output r_block,
    output logic r_multi_block,
    output logic r_byte,
    output [31:0] block_addr,
    input spi_busy,

    input [7:0] eluks_data,
    input eluks_busy,
    input eluks_error,
    input end_eluks_header,

    output logic end_signal,
    output [63:0] exec_time,
    output logic error
);
    
    assign spi_ctl = 1;
    assign r_block = 0;
    assign block_addr = 0; 
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

    logic up_exec_time;
    logic rst_exec_time;
    counter #(.DATA_WIDTH(64)) counter_timer_exec(
        .clk(clk),
        .rst(rst_exec_time),
        .up(up_exec_time),
        .down(1'b0),
        .din(32'b0),
        .dout(exec_time)
    );


    localparam IDLE = 0;
    localparam RST_SPI = 1;
    localparam INIT_ELUKS = 2;
    localparam WAIT_ELUKS = 3;
    localparam READ_DATA = 4;
    localparam WAIT_BYTE = 5;
    localparam END_STATE = 6;
    localparam ERROR = 7;

    logic [3:0] current_state;
    logic [3:0] next_state;

    always_comb begin
        
        next_state = current_state;
        
        rst_eluks = 0;

        rst_spi = 0;
        r_multi_block = 1;
        r_byte = 0;
        end_signal = 0;
        
        rst_counter_bytes = 1'b0;
        up_bytes = 1'b0;

        rst_exec_time = 0;
        up_exec_time = 1;

        error = 0;

        case (current_state)
            IDLE:   
                begin
                    rst_counter_bytes = 1;
                    rst_eluks = 1;
                    rst_exec_time = 1;
                    next_state = RST_SPI;
                end
            RST_SPI:
                begin
                    rst_exec_time = 1;
                    rst_eluks = 1;
                    rst_spi = 1;
                    next_state = INIT_ELUKS;
                end
            INIT_ELUKS:
                begin
                    rst_exec_time = 1;
                    rst_eluks = 1;
                    if(spi_busy == 0) begin
                        rst_eluks = 0;
                        next_state = WAIT_ELUKS;
                    end
                end
            WAIT_ELUKS:
                begin
                    if(end_eluks_header == 1 && eluks_busy == 0) begin
                        next_state = READ_DATA;
                    end
                end
            READ_DATA:
                begin
                    if(counter_bytes_out == BYTES_TO_READ) begin
                        next_state = END_STATE;
                    end
                    else begin
                        up_bytes = 1;
                        r_byte = 1;
                        next_state = WAIT_BYTE;
                    end
                end
            WAIT_BYTE:
                begin
                    if(eluks_busy == 0) begin
                        next_state = READ_DATA;
                    end
                end
            END_STATE:
                begin
                    up_exec_time = 0;
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
        else if (eluks_error) begin
            current_state <= ERROR;
        end
        else begin
            current_state <= next_state;
        end
    end

endmodule : task_read_encrypted