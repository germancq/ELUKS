/**
 * @ Author: German Cano Quiveu, germancq
 * @ Create Time: 2021-10-13 16:09:38
 * @ Modified by: German Cano Quiveu, germancq
 * @ Modified time: 2021-10-22 13:08:30
 * @ Description:
 */


 
 



module eluks
    #(parameter PSW_WIDTH = 64,
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
    input clk,
    input rst,

    input [PSW_WIDTH-1:0] user_password,
    input hmac_enable,

    input [31:0] eluks_first_block,
    
    input [31:0] block_addr,
    input r_block,
    input r_multi_block,
    input r_byte,
    output eluks_busy,
    output [7:0] eluks_data,

    output [31:0] spi_block_addr,
    output spi_r_block,
    output spi_r_multi_block,
    output spi_r_byte,
    input [7:0] spi_data,
    input spi_busy,
    input spi_err,

    output end_eluks_header,
    output logic error,
    output [31:0] debug_data
);

    

    logic [31:0] eluks_block_addr;
    logic eluks_r_block;
    logic eluks_r_multi_block;
    logic eluks_r_byte;
    logic sel_spi_signal;


    assign spi_r_byte = eluks_r_byte;

    logic [SALT_WIDTH-1:0] salt;
    logic [COUNT_WIDTH-1:0] count;
    logic [KEY_SIZE-1:0] kdf_psw;
    logic [N_kdf-1:0] kdf_o;
    logic rst_kdf;
    logic end_kdf;


    logic [BLOCK_SIZE-1:0] cipher_IV;
    logic [BLOCK_SIZE-1:0] cipher_block_number;
    logic [KEY_SIZE-1:0] cipher_key;
    logic [BLOCK_SIZE-1:0] cipher_block_i;
    logic [BLOCK_SIZE-1:0] cipher_block_o;
    logic rq_data_cipher;
    logic end_key_generation_cipher;
    logic end_dec;
    logic rst_cipher;



    logic rst_hmac;
    logic data_ready_hmac;
    logic stop_feed_hmac;
    logic busy_hmac;
    logic end_hmac;
    logic [KEY_SIZE-1:0] key_hmac;
    logic [r-1:0] feed_data_hmac;
    logic [N-1:0] hmac_o;

    
    KDF_spongent #(
        .N(N_kdf),
        .c(c_kdf),
        .r(r_kdf),
        .R(R_kdf),
        .lCounter_initial_state(lCounter_initial_state_kdf),
        .lCounter_feedback_coeff(lCounter_feedback_coeff_kdf),
        .SALT_WIDTH(SALT_WIDTH),
        .COUNT_WIDTH(COUNT_WIDTH),
        .PSW_WIDTH(KEY_SIZE)
    ) 
    KDF_impl(
        .clk(clk),
        .rst(rst_kdf),
        .salt(salt),
        .count(count),
        .user_password(kdf_psw),
        .key_derivated(kdf_o),
        .end_signal(end_kdf)
    );


    present_ctr present_impl(
        .clk(clk),
        .rst(rst_cipher),
        .IV(cipher_IV),
        .block_number(cipher_block_number),
        .key(cipher_key),
        .block_i(cipher_block_i),
        .block_o(cipher_block_o),
        .end_key_generation(end_key_generation_cipher),
        .rq_data(rq_data_cipher),
        .end_signal(end_dec)
    );

    //HMAC
    hmac_spongent_iter #(
        .N(N),
        .c(c),
        .r(r),
        .R(R),
        .lCounter_feedback_coeff(lCounter_feedback_coeff),
        .lCounter_initial_state(lCounter_initial_state),
        .KEY_WIDTH(KEY_SIZE)
    )hmac_impl(
        .clk(clk),
        .rst(rst_hmac),
        .feed_data(feed_data_hmac),
        .data_ready(data_ready_hmac),
        .stop_feed(stop_feed_hmac),
        .busy(busy_hmac),
        .key(key_hmac),
        .digest(hmac_o),
        .end_hmac(end_hmac)
    );


    mux #(.DATA_WIDTH(32)) mux_spi_addr(
        .a(eluks_block_addr),
        .b(block_addr + 1),
        .sel(sel_spi_signal),
        .c(spi_block_addr)
    );

    mux #(.DATA_WIDTH(1)) mux_r_block(
        .a(eluks_r_block),
        .b(r_block),
        .sel(sel_spi_signal),
        .c(spi_r_block)
    );
    
    mux #(.DATA_WIDTH(1)) mux_r_multi_block(
        .a(eluks_r_multi_block),
        .b(r_multi_block),
        .sel(sel_spi_signal),
        .c(spi_r_multi_block)
    );
    
    
    
    eluks_control_unit #(
        .DIGEST_SIZE(N_kdf),
        .SALT_WIDTH(SALT_WIDTH),
        .COUNT_WIDTH(COUNT_WIDTH),
        .PSW_WIDTH(PSW_WIDTH),
        .BLOCK_SIZE(BLOCK_SIZE),
        .KEY_SIZE(KEY_SIZE),
        .r(r),
        .N(N)
    ) fsm(
        .clk(clk),
        .rst(rst),

        .hmac_enable(hmac_enable),
        .user_password(user_password),
        .end_eluks_header(end_eluks_header),
        .block_addr(block_addr),
        .eluks_first_block(eluks_first_block),


        .kdf_salt(salt),
        .kdf_count(count),
        .kdf_psw(kdf_psw),
        .rst_kdf(rst_kdf),
        .end_kdf(end_kdf),
        .kdf_o(kdf_o),

        .cipher_key(cipher_key),
        .cipher_block_i(cipher_block_i),
        .cipher_block_o(cipher_block_o),
        .end_dec(end_dec),
        .rst_cipher(rst_cipher),
        .end_key_generation_cipher(end_key_generation_cipher),
        .rq_data_cipher(rq_data_cipher),
        .cipher_IV(cipher_IV),
        .cipher_block_number(cipher_block_number),

        .key_hmac(key_hmac),
        .rst_hmac(rst_hmac),
        .busy_hmac(busy_hmac),
        .feed_data_hmac(feed_data_hmac),
        .end_hmac(end_hmac),
        .stop_feed_hmac(stop_feed_hmac),
        .data_ready_hmac(data_ready_hmac),
        .hmac_o(hmac_o),

        .sel_spi_signal(sel_spi_signal),
        .eluks_r_block(eluks_r_block),
        .eluks_r_multi_block(eluks_r_multi_block),
        .eluks_r_byte(eluks_r_byte),
        .r_byte(r_byte),
        .r_block(r_block),
        .r_multi_block(r_multi_block),
        .spi_data(spi_data),
        .spi_busy(spi_busy),
        .spi_err(spi_err),
        .eluks_data(eluks_data),
        .eluks_busy(eluks_busy),
        .eluks_block_addr(eluks_block_addr),

        .error(error),
        .debug_data(debug_data)
    );




endmodule : eluks


module eluks_control_unit #(
    parameter DIGEST_SIZE = 128,
    parameter SALT_WIDTH = 64,
    parameter COUNT_WIDTH = 32,
    parameter PSW_WIDTH = 64,
    parameter BLOCK_SIZE = 64,
    parameter KEY_SIZE = 80,
    parameter USER_SPACE_WIDTH = 32,
    parameter r = 8,
    parameter N = 88
)
(
    input clk,
    input rst,

    input [PSW_WIDTH-1:0] user_password,
    output logic end_eluks_header,
    input hmac_enable,
    input [31:0] block_addr,
    input [31:0] eluks_first_block,

    /*KDF signals*/
    output [SALT_WIDTH-1:0] kdf_salt,
    output [COUNT_WIDTH-1:0] kdf_count,
    output [KEY_SIZE-1:0] kdf_psw,
    output logic rst_kdf,
    input end_kdf,
    input [DIGEST_SIZE-1:0] kdf_o,
    

    /*cipher signals*/
    output [KEY_SIZE-1:0] cipher_key,
    output [BLOCK_SIZE-1:0] cipher_block_i,
    input [BLOCK_SIZE-1:0] cipher_block_o,
    input end_dec,
    output logic rst_cipher,
    output [BLOCK_SIZE-1:0] cipher_IV,
    output [BLOCK_SIZE-1:0] cipher_block_number,
    output logic rq_data_cipher,
    input end_key_generation_cipher,

    /*HMAC signals*/
    output [KEY_SIZE-1:0] key_hmac,
    output logic rst_hmac,
    input busy_hmac,
    output [r-1:0] feed_data_hmac,
    input end_hmac,
    output logic stop_feed_hmac,
    output logic data_ready_hmac,
    input [N-1:0] hmac_o,

    /*eluks signals*/
    output logic sel_spi_signal,
    output logic eluks_r_block,
    output logic eluks_r_multi_block,
    output logic eluks_r_byte,
    input spi_busy,
    input spi_err,
    input r_byte,
    input r_block,
    input r_multi_block,
    input [7:0] spi_data,
    output logic eluks_busy,
    output [7:0] eluks_data,
    output [31:0] eluks_block_addr,

    output logic error,
    output [31:0] debug_data
    
);
    localparam ACTIVATE_SIGNATURE = 32'h22446688;
    localparam ELUKS_SIGNATURE = 48'hAABBCCDDEEFF;
    localparam DECRYPT_STAGES = $rtoi($floor((KEY_SIZE-1)/BLOCK_SIZE) + 1);
    localparam KS_SLOTS = (BLOCK_SIZE>>3);
    localparam BASE_KEY_SLOT = 8'h6 + 8'(DIGEST_SIZE>>3) + 8'(SALT_WIDTH>>3) + 8'(COUNT_WIDTH>>3) + 8'(N>>3) + 8'(BLOCK_SIZE>>3) + 8'(USER_SPACE_WIDTH>>3);
    localparam KEY_SLOT_SIZE = 8'h4 + 8'(SALT_WIDTH>>3) + 8'(COUNT_WIDTH>>3) + 8'((DECRYPT_STAGES*BLOCK_SIZE)>>3) + 8'(BLOCK_SIZE>>3);
    localparam KS_SLOTS_LOG = $clog2(KS_SLOTS);
    localparam OFFSET_BLOCKNUM_CTR = (9-$clog2(BLOCK_SIZE>>3)); //BLOCK SIZE MUST BE IN BYTES

    

    assign debug_data = {current_state};
    /*
        1 - Leer Bloque 0
        2 - check MAGIC LUKS
        3 - Store mk-digest
        4 - store mk-salt
        5 - store mk-iter
        6 - store keys_slot_offset
        7 - store key_slot_size
        8 - Por cada key_slot
            +) store key_iter
            +) store key_salt
            +) store pwd_encrypt
            +) realizar pwd-digest =  KDF(user_password,key_iter,key_salt)
            +) MK_candidate = decrypt(pwd-digest,encrypted_pwd)    
            +) sii KDF(MK_candidate,mk-salt,mk-iter) == mk-digest then end_loop

        LECTURA Y POSTERIOR DECRYPT

        9 - rq_byte , (leer 64 bits, 8 bytes / ir paso 11) 
        10 - decrypt(64bits, MK)
        11 - dar 1 byte del descrifado segun un contador interno
             
    */

    genvar i;

    /*ELUKS SIGNATURE*/
    logic [0:0] eluks_signature_w [5:0];
    logic [0:0] eluks_signature_cl [5:0];
    logic [47:0] eluks_signature;

    
    generate
        for (i = 0;i<6 ;i=i+1 ) begin
            register #(.DATA_WIDTH(8)) r_eluks_signature_i(
                .clk(clk),
                .cl(eluks_signature_cl[i]),
                .w(eluks_signature_w[i]),
                .din(spi_data),
                .dout(eluks_signature[(i<<3)+7:(i<<3)])
            );
        end
    endgenerate

    /*MK DIGEST*/
    logic [0:0] mk_digest_w [(DIGEST_SIZE>>3)-1:0];
    logic [0:0] mk_digest_cl [(DIGEST_SIZE>>3)-1:0];
    logic [DIGEST_SIZE-1:0] mk_digest;

    
    generate
        for (i = 0;i<(DIGEST_SIZE>>3) ;i=i+1 ) begin
            register #(.DATA_WIDTH(8)) r_mk_digest_i(
                .clk(clk),
                .cl(mk_digest_cl[i]),
                .w(mk_digest_w[i]),
                .din(spi_data),
                .dout(mk_digest[(i<<3)+7:(i<<3)])
            );
        end
    endgenerate
    
    /*MK COUNT*/
    logic [0:0] mk_count_w [(COUNT_WIDTH>>3)-1:0];
    logic [0:0] mk_count_cl [(COUNT_WIDTH>>3)-1:0];
    logic [COUNT_WIDTH-1:0] mk_count;

    
    generate
        for (i = 0;i<(COUNT_WIDTH>>3) ;i=i+1 ) begin
            register #(.DATA_WIDTH(8)) r_mk_count_i(
                .clk(clk),
                .cl(mk_count_cl[i]),
                .w(mk_count_w[i]),
                .din(spi_data),
                .dout(mk_count[(i<<3)+7:(i<<3)])
            );
        end
    endgenerate

    /*MK SALT*/
    logic [0:0] mk_salt_w [(SALT_WIDTH>>3)-1:0];
    logic [0:0] mk_salt_cl [(SALT_WIDTH>>3)-1:0];
    logic [SALT_WIDTH-1:0] mk_salt;

    
    generate
        for (i = 0;i<(SALT_WIDTH>>3) ;i=i+1 ) begin
            register #(.DATA_WIDTH(8)) r_mk_salt_i(
                .clk(clk),
                .cl(mk_salt_cl[i]),
                .w(mk_salt_w[i]),
                .din(spi_data),
                .dout(mk_salt[(i<<3)+7:(i<<3)])
            );
        end
    endgenerate

    /*MK HMAC*/
    logic [0:0] mk_hmac_w [(N>>3)-1:0];
    logic [0:0] mk_hmac_cl [(N>>3)-1:0];
    logic [N-1:0] mk_hmac;

    
    generate
        for (i = 0;i<(N>>3) ;i=i+1 ) begin
            register #(.DATA_WIDTH(8)) r_mk_hmac_i(
                .clk(clk),
                .cl(mk_hmac_cl[i]),
                .w(mk_hmac_w[i]),
                .din(spi_data),
                .dout(mk_hmac[(i<<3)+7:(i<<3)])
            );
        end
    endgenerate


    /*MK_IV*/
    logic [0:0] mk_iv_w [(BLOCK_SIZE>>3)-1:0];
    logic [0:0] mk_iv_cl [(BLOCK_SIZE>>3)-1:0];
    logic [BLOCK_SIZE-1:0] mk_iv;

    
    generate
        for (i = 0;i<(BLOCK_SIZE>>3) ;i=i+1 ) begin
            register #(.DATA_WIDTH(8)) r_mk_iv_i(
                .clk(clk),
                .cl(mk_iv_cl[i]),
                .w(mk_iv_w[i]),
                .din(spi_data),
                .dout(mk_iv[(i<<3)+7:(i<<3)])
            );
        end
    endgenerate


    /*USER DATA BLOCKS*/
    logic [0:0] user_data_blocks_w [(USER_SPACE_WIDTH>>3)-1:0];
    logic [0:0] user_data_blocks_cl [(USER_SPACE_WIDTH>>3)-1:0];
    logic [USER_SPACE_WIDTH-1:0] user_data_blocks;

    
    generate
        for (i = 0;i<(USER_SPACE_WIDTH>>3) ;i=i+1 ) begin
            register #(.DATA_WIDTH(8)) r_user_data_blocks_i(
                .clk(clk),
                .cl(user_data_blocks_cl[i]),
                .w(user_data_blocks_w[i]),
                .din(spi_data),
                .dout(user_data_blocks[(i<<3)+7:(i<<3)])
            );
        end
    endgenerate

    /*KEY SLOT ACTIVATE*/
    logic [0:0] activate_w [3:0];
    logic [0:0] activate_cl [3:0];
    logic [31:0] activate;

    generate
        for (i = 0;i<4 ;i=i+1 ) begin
            register #(.DATA_WIDTH(8)) r_activate_i(
                .clk(clk),
                .cl(activate_cl[i]),
                .w(activate_w[i]),
                .din(spi_data),
                .dout(activate[(i<<3)+7:(i<<3)])
            );
        end
    endgenerate

    /*KEY SLOT COUNT*/
    logic [0:0] pwd_count_w [(COUNT_WIDTH>>3)-1:0];
    logic [0:0] pwd_count_cl [(COUNT_WIDTH>>3)-1:0];
    logic [COUNT_WIDTH-1:0] pwd_count;

    
    generate
        for (i = 0;i<(COUNT_WIDTH>>3) ;i=i+1 ) begin
            register #(.DATA_WIDTH(8)) r_pwd_count_i(
                .clk(clk),
                .cl(pwd_count_cl[i]),
                .w(pwd_count_w[i]),
                .din(spi_data),
                .dout(pwd_count[(i<<3)+7:(i<<3)])
            );
        end
    endgenerate

    /*KEY SLOT SALT*/
    logic [0:0] pwd_salt_w [(SALT_WIDTH>>3)-1:0];
    logic [0:0] pwd_salt_cl [(SALT_WIDTH>>3)-1:0];
    logic [SALT_WIDTH-1:0] pwd_salt;

    
    generate
        for (i = 0;i<(SALT_WIDTH>>3) ;i=i+1 ) begin
            register #(.DATA_WIDTH(8)) r_pwd_salt_i(
                .clk(clk),
                .cl(pwd_salt_cl[i]),
                .w(pwd_salt_w[i]),
                .din(spi_data),
                .dout(pwd_salt[(i<<3)+7:(i<<3)])
            );
        end
    endgenerate

    /*KEY SLOT ENCRYPT*/
    logic [0:0] pwd_encrypt_w [((DECRYPT_STAGES*BLOCK_SIZE)>>3)-1:0];
    logic [0:0] pwd_encrypt_cl [((DECRYPT_STAGES*BLOCK_SIZE)>>3)-1:0];
    logic [(DECRYPT_STAGES*BLOCK_SIZE)-1:0] pwd_encrypt;

    
    generate
        for (i = 0;i<((DECRYPT_STAGES*BLOCK_SIZE)>>3) ;i=i+1 ) begin
            register #(.DATA_WIDTH(8)) r_pwd_encrypt_i(
                .clk(clk),
                .cl(pwd_encrypt_cl[i]),
                .w(pwd_encrypt_w[i]),
                .din(spi_data),
                .dout(pwd_encrypt[(i<<3)+7:(i<<3)])
            );
        end
    endgenerate

    /*KEY SLOT IV*/
    logic [0:0] pwd_iv_w [(BLOCK_SIZE>>3)-1:0];
    logic [0:0] pwd_iv_cl [(BLOCK_SIZE>>3)-1:0];
    logic [BLOCK_SIZE-1:0] pwd_iv;

    
    generate
        for (i = 0;i<(BLOCK_SIZE>>3) ;i=i+1 ) begin
            register #(.DATA_WIDTH(8)) r_pwd_iv_i(
                .clk(clk),
                .cl(pwd_iv_cl[i]),
                .w(pwd_iv_w[i]),
                .din(spi_data),
                .dout(pwd_iv[(i<<3)+7:(i<<3)])
            );
        end
    endgenerate

    /*ENC DATA*/
    logic [0:0] enc_data_i_w [(BLOCK_SIZE>>3)-1:0];
    logic [0:0] enc_data_i_cl [(BLOCK_SIZE>>3)-1:0];
    logic [BLOCK_SIZE-1:0] enc_data;

    
    generate
        for (i = 0;i<(BLOCK_SIZE>>3) ;i=i+1 ) begin
            register #(.DATA_WIDTH(8)) r_pwd_salt_i(
                .clk(clk),
                .cl(enc_data_i_cl[i]),
                .w(enc_data_i_w[i]),
                .din(spi_data),
                .dout(enc_data[(i<<3)+7:(i<<3)])
            );
        end
    endgenerate

    /*KDF salt*/
    logic kdf_salt_cl;
    logic kdf_salt_w;
    logic [SALT_WIDTH-1:0] kdf_salt_i; 
    register #(.DATA_WIDTH(SALT_WIDTH)) r_kdf_salt(
                .clk(clk),
                .cl(kdf_salt_cl),
                .w(kdf_salt_w),
                .din(kdf_salt_i),
                .dout(kdf_salt)
            );

    /*KDF count*/
    logic kdf_count_cl;
    logic kdf_count_w;
    logic [COUNT_WIDTH-1:0] kdf_count_i; 
    register #(.DATA_WIDTH(COUNT_WIDTH)) r_kdf_count(
                .clk(clk),
                .cl(kdf_count_cl),
                .w(kdf_count_w),
                .din(kdf_count_i),
                .dout(kdf_count)
            );        

    /*KDF user_password*/
    logic kdf_userpassword_cl;
    logic kdf_userpassword_w;
    logic [KEY_SIZE-1:0] kdf_userpassword_i; 
    register #(.DATA_WIDTH(KEY_SIZE)) r_kdf_userpassword(
                .clk(clk),
                .cl(kdf_userpassword_cl),
                .w(kdf_userpassword_w),
                .din(kdf_userpassword_i),
                .dout(kdf_psw)
            );         

    /*cipher key*/
    logic cipher_key_cl;
    logic cipher_key_w;
    logic [KEY_SIZE-1:0] cipher_key_i;  
    register #(.DATA_WIDTH(KEY_SIZE)) r_cipher_key(
                .clk(clk),
                .cl(cipher_key_cl),
                .w(cipher_key_w),
                .din(cipher_key_i),
                .dout(cipher_key)
            );   

    /*cipher block_i*/   
    logic cipher_block_i_cl;
    logic cipher_block_i_w;
    logic [BLOCK_SIZE-1:0] cipher_block_i_i;  
    register #(.DATA_WIDTH(BLOCK_SIZE)) r_cipher_block_i(
                .clk(clk),
                .cl(cipher_block_i_cl),
                .w(cipher_block_i_w),
                .din(cipher_block_i_i),
                .dout(cipher_block_i)
            );         

    /*cipher IV*/
    logic cipher_iv_cl;
    logic cipher_iv_w;
    logic [BLOCK_SIZE-1:0] cipher_iv_i;  
    register #(.DATA_WIDTH(BLOCK_SIZE)) r_cipher_iv_i(
                .clk(clk),
                .cl(cipher_iv_cl),
                .w(cipher_iv_w),
                .din(cipher_iv_i),
                .dout(cipher_IV)
    );

    /*cipher BLOCK NUMBER*/
    logic cipher_block_number_up;
    logic rst_cipher_block_number;
    counter #(.DATA_WIDTH(64)) r_cipher_block_number_impl(
        .clk(clk),
        .rst(rst_cipher_block_number),
        .up(cipher_block_number_up),
        .down(1'b0),
        .din(sel_spi_signal==1?((eluks_block_addr-eluks_first_block)<<OFFSET_BLOCKNUM_CTR):(64'b0)),
        .dout(cipher_block_number)
    );        

    /*MK CANDIDATE*/

    logic [0:0] mk_candidate_w [DECRYPT_STAGES-1:0];
    logic [0:0] mk_candidate_cl [DECRYPT_STAGES-1:0];
    
    logic [KEY_SIZE-1: 0] mk_candidate;
    logic [(DECRYPT_STAGES*BLOCK_SIZE)-1:0] mk_candidate_o;
    assign mk_candidate = mk_candidate_o[KEY_SIZE-1:0];
    assign key_hmac = mk_candidate;

    generate
        for (i = 0;i<(DECRYPT_STAGES) ;i=i+1) begin
            register #(.DATA_WIDTH(BLOCK_SIZE)) r_mk_candidate_i(
                .clk(clk),
                .cl(mk_candidate_cl[i]),
                .w(mk_candidate_w[i]),
                .din(cipher_block_o),
                .dout(mk_candidate_o[(i<<$clog2(BLOCK_SIZE))+(BLOCK_SIZE-1):(i<<$clog2(BLOCK_SIZE))])
            );
        end
    endgenerate
    
    /*DEC DATA*/
    logic dec_data_cl;
    logic dec_data_w;
    logic [BLOCK_SIZE-1:0] dec_data;
    register #(.DATA_WIDTH(BLOCK_SIZE)) r_dec_data(
                .clk(clk),
                .cl(dec_data_cl),
                .w(dec_data_w),
                .din(cipher_block_o),
                .dout(dec_data)
            ); 

    /*BYTE DATA*/
    logic byte_data_cl;
    logic byte_data_w;
    logic [7:0] byte_data_i;

    register #(.DATA_WIDTH(8)) r_byte_data(
                .clk(clk),
                .cl(byte_data_cl),
                .w(byte_data_w),
                .din(byte_data_i),
                .dout(eluks_data)
            );

    /*HMAC FEED DATA REGISTER*/
    logic [0:0] feed_data_hmac_cl[(r>>3)-1:0];
    logic [0:0] feed_data_hmac_w[(r>>3)-1:0];
    generate
        for (i=0;i<(r>>3);i=i+1) begin
            register #(.DATA_WIDTH(8)) reg_feed_data_i(
                .clk(clk),
                .cl(feed_data_hmac_cl[(r>>3)-1-i]), //big endian
                .w(feed_data_hmac_w[(r>>3)-1-i]),
                .din(spi_data),
                .dout(feed_data_hmac[(i<<3)+7:(i<<3)])
            );
        end
    endgenerate


    /////////////////////////////////////////////////////////////////////

    /*Counter Bytes*/
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

    /*Counter number_of_key_slot*/
    logic [KS_SLOTS_LOG-1:0] counter_tries_out;
    logic up_counter_tries;
    logic rst_counter_tries;
    counter #(.DATA_WIDTH(KS_SLOTS_LOG)) counter_tries_impl(
        .clk(clk),
        .rst(rst_counter_tries),
        .up(up_counter_tries),
        .down(1'b0),
        .din({KS_SLOTS_LOG{1'b0}}),
        .dout(counter_tries_out)
    );

     //////////////index_counter////////////////////
 
    logic up_index;
    logic [7:0] index_o;
    logic rst_index;
    counter #(.DATA_WIDTH(8)) counter_index(
        .clk(clk),
        .rst(rst_index),
        .up(up_index),
        .down(1'b0),
        .din(8'h0),
        .dout(index_o)
    );

    /////////////counter spi blocks/////////////////

    logic up_counter_spi_block;
    logic rst_counter_spi_block;
    counter #(.DATA_WIDTH(32)) counter_spi_blocks(
        .clk(clk),
        .rst(rst_counter_spi_block),
        .up(up_counter_spi_block),
        .down(1'b0),
        .din(block_addr),
        .dout(eluks_block_addr)
    );
    
    ////////////////////////////////////////////////
    
    logic block_addr_cl;
    logic block_addr_w;
    logic [31:0] block_addr_reg;
    register #(.DATA_WIDTH(32)) r_block_addr(
                .clk(clk),
                .cl(block_addr_cl),
                .w(block_addr_w),
                .din(block_addr),
                .dout(block_addr_reg)
                ); 
    
    

    
    localparam IDLE = 6'h0;
    localparam READ_BLOCK_BASE = 6'h1;
    localparam WAIT_BLOCK = 6'h2;
    localparam READ_DATA = 6'h3;
    localparam READ_BYTE = 6'h4;
    localparam WAIT_BYTE = 6'h5;
    localparam CHECK_SIGNATURE = 6'h6;
    localparam READ_KEY_SLOT = 6'h7;
    localparam CHECK_ACTIVE_KEY_SLOT = 6'h8;
    localparam KDF_USER_PASSWORD = 6'h9;
    localparam WAIT_KDF = 6'hA;
    localparam DECRYPT = 6'hB;
    localparam WAIT_DECRYPT = 6'hC;
    localparam KDF_MK_CANDIDATE = 6'hD;
    localparam WAIT_KDF_MK_CANDIDATE = 6'hE;
    localparam CHECK_MK_CANDIDATE = 6'hF;
    localparam WAIT_END_BLOCK_SPI = 6'h10;
    localparam SEL_FIRST_ENCRYPTED_BLOCK = 6'h11;
    localparam READ_BLOCK_CMD18_MODE = 6'h12;
    localparam WAIT_BLOCK_CMD18 = 6'h13;
    localparam READ_FEED_DATA = 6'h14;
    localparam READ_FEED_DATA_BYTE = 6'h15;
    localparam WAIT_FEED_BYTE = 6'h16;
    localparam FEED_CONTROL = 6'h17;
    localparam WAIT_BUSY_HMAC_0 = 6'h18;
    localparam WAIT_BUSY_HMAC_1 = 6'h19;
    localparam STOP_FEED = 6'h1A;
    localparam CHECK_HMAC = 6'h1B;
    localparam SETUP_CIPHER = 6'h1C;
    localparam WAIT_SETUP_CIPHER = 6'h1D;
    localparam WAIT_FOR_RQ_BYTE = 6'h1E;
    localparam READ_ENCRYPT_DATA = 6'h1F;
    localparam DECRYPT_DATA = 6'h20;
    localparam WAIT_DECRYPT_DATA = 6'h21;
    localparam SEND_DECRYPT_BYTE = 6'h22;
    localparam ERROR_PASSWORD = 6'h23;
    localparam ERR_SIGNATURE = 6'h24;
    localparam ERR_HMAC = 6'h25;
    
    logic [5:0] current_state;
    logic [5:0] next_state;
    logic [5:0] prev_state;
    /*
    prev state
    */
    logic r_state_prev_cl;
    logic r_state_prev_w;
    logic [5:0] r_state_prev_i;
    logic [5:0] r_state_prev_o;
    register #(.DATA_WIDTH(6)) r_state_prev(
        .clk(clk),
        .cl(r_state_prev_cl),
        .w(r_state_prev_w),
        .din(r_state_prev_i),
        .dout(r_state_prev_o)
    );
    assign prev_state = r_state_prev_o;

    logic [31:0] j;


    always_comb begin
        next_state = current_state;

        error = 0;
        
        end_eluks_header = 1'b0;

        rst_counter_bytes = 1'b0;
        up_bytes = 1'b0;

        rst_counter_tries = 1'b0;
        up_counter_tries = 1'b0;

        rst_index = 1'b0;
        up_index = 1'b0;

        up_counter_spi_block = 1'b0;
        rst_counter_spi_block = 1'b0;

        sel_spi_signal = 1'b0;
        rst_kdf = 1'b1;
        rst_cipher = 1'b1;
        rst_hmac = 1'b1;
        eluks_r_block = 1'b0;
        eluks_r_multi_block = 1'b0;
        eluks_r_byte = 1'b0;
        eluks_busy = 1'b1;        

        r_state_prev_cl = 1'b0;
        r_state_prev_w = 1'b0;
        r_state_prev_i = current_state;
        
        for (j = 0;j<6 ;j=j+1 ) begin
            eluks_signature_cl[j] = 1'b0;
            eluks_signature_w[j] = 1'b0;
        end

        for (j = 0;j<(DIGEST_SIZE>>3) ;j=j+1 ) begin
            mk_digest_cl[j] = 1'b0;
            mk_digest_w[j] = 1'b0;
        end

        for (j = 0;j < (COUNT_WIDTH>>3) ;j=j+1 ) begin
            mk_count_cl[j] = 1'b0;
            mk_count_w[j] = 1'b0;
            pwd_count_cl[j] = 1'b0;
            pwd_count_w[j] = 1'b0;
        end

        for (j = 0;j < (SALT_WIDTH>>3) ;j=j+1 ) begin
            mk_salt_cl[j] = 1'b0;
            mk_salt_w[j] = 1'b0;
            pwd_salt_cl[j] = 1'b0;
            pwd_salt_w[j] = 1'b0;
        end

        for (j = 0;j<(N>>3) ;j=j+1 ) begin
            mk_hmac_cl[j] = 1'b0;
            mk_hmac_w[j] = 1'b0;
        end

        for (j = 0;j<(BLOCK_SIZE>>3) ;j=j+1 ) begin
            mk_iv_cl[j] = 1'b0;
            mk_iv_w[j] = 1'b0;
        end

        for (j=0;j<4;j=j+1) begin
            user_data_blocks_w[j] = 1'b0;
            user_data_blocks_cl[j] = 1'b0;
        end
        
        for (j = 0;j<4 ;j=j+1 ) begin
            activate_cl[j] = 1'b0;
            activate_w[j] = 1'b0;
        end

        for ( j=0 ;j< (DECRYPT_STAGES * BLOCK_SIZE)>>3 ;j=j+1 ) begin
            pwd_encrypt_cl[j] = 1'b0;
            pwd_encrypt_w[j] = 1'b0;
        end

        for ( j=0 ;j< (BLOCK_SIZE)>>3 ;j=j+1 ) begin
            pwd_iv_cl[j] = 1'b0;
            pwd_iv_w[j] = 1'b0;
        end

        for (j = 0;j<(BLOCK_SIZE>>3) ;j=j+1 ) begin
            enc_data_i_cl[j] = 1'b0;
            enc_data_i_w[j] = 1'b0;
        end

        for (j = 0; j< DECRYPT_STAGES ;j=j+1 ) begin
            mk_candidate_cl[j] = 1'b0;
            mk_candidate_w[j] = 1'b0;
        end


        kdf_salt_cl = 1'b0;
        kdf_salt_w = 1'b0;
        kdf_salt_i = {SALT_WIDTH{1'b0}};

        kdf_count_cl = 1'b0;
        kdf_count_w = 1'b0;
        kdf_count_i = {COUNT_WIDTH{1'b0}};

        kdf_userpassword_cl = 1'b0;
        kdf_userpassword_w = 1'b0;
        kdf_userpassword_i = {KEY_SIZE{1'b0}};

        cipher_key_cl = 1'b0;
        cipher_key_w = 1'b0;
        cipher_key_i = {KEY_SIZE{1'b0}};

        cipher_block_i_cl = 1'b0;
        cipher_block_i_w = 1'b0;
        cipher_block_i_i = {BLOCK_SIZE{1'b0}};

        cipher_iv_cl = 1'b0;
        cipher_iv_w = 1'b0;
        cipher_iv_i = {BLOCK_SIZE{1'b0}};

        rq_data_cipher = 1'b0;

        rst_cipher_block_number = 1'b0;
        cipher_block_number_up = 1'b0;

        stop_feed_hmac = 1'b0;
        data_ready_hmac = 1'b0;

        dec_data_cl = 1'b0;
        dec_data_w = 1'b0;

        byte_data_cl = 1'b0;
        byte_data_w = 1'b0;
        byte_data_i = 8'b0;

        for (j=0;j<(r>>3);j=j+1) begin
            feed_data_hmac_cl[j] = 0;
            feed_data_hmac_w[j] = 0;
        end

        block_addr_cl = 1'b0;
        block_addr_w = 1'b0;


        case(current_state)
            IDLE : 
                begin
                    rst_counter_bytes = 1'b1;
                    rst_counter_tries = 1'b1;
                    rst_index = 1'b1;
                    rst_counter_spi_block = 1'b1;

                    r_state_prev_cl = 1'b1;

                    for (j = 0;j<6 ;j=j+1 ) begin
                        eluks_signature_cl[j] = 1'b1;
                    end

                    for (j = 0;j<(DIGEST_SIZE>>3) ;j=j+1 ) begin
                        mk_digest_cl[j] = 1'b1;
                    end

                    for (j = 0;j < (COUNT_WIDTH>>3) ;j=j+1 ) begin
                        mk_count_cl[j] = 1'b1;
                        pwd_count_cl[j] = 1'b1;
                    end

                    for (j = 0;j < (SALT_WIDTH>>3) ;j=j+1 ) begin
                        mk_salt_cl[j] = 1'b1;
                        pwd_salt_cl[j] = 1'b1;
                    end

                    for (j = 0;j<(N>>3) ;j=j+1 ) begin
                        mk_hmac_cl[j] = 1'b1;
                    end

                    for (j = 0;j<(BLOCK_SIZE>>3) ;j=j+1 ) begin
                        mk_iv_cl[j] = 1'b1;
                    end

                    for (j=0;j<4;j=j+1) begin
                        user_data_blocks_cl[j] = 1'b1;
                    end
                    
                    for (j = 0;j<4 ;j=j+1 ) begin
                        activate_cl[j] = 1'b1;
                    end

                    for ( j=0 ;j< (DECRYPT_STAGES*BLOCK_SIZE)>>3 ;j=j+1 ) begin
                        pwd_encrypt_cl[j] = 1'b1;
                    end

                    for ( j=0 ;j< (BLOCK_SIZE)>>3 ;j=j+1 ) begin
                        pwd_iv_cl[j] = 1'b1;
                    end

                    for (j = 0;j<(BLOCK_SIZE>>3) ;j=j+1 ) begin
                        enc_data_i_cl[j] = 1'b1;
                    end

                    for (j = 0; j<DECRYPT_STAGES ;j=j+1 ) begin
                        mk_candidate_cl[j] = 1'b1;
                    end

                    kdf_salt_cl = 1'b1;

                    kdf_count_cl = 1'b1;

                    kdf_userpassword_cl = 1'b1;

                    cipher_key_cl = 1'b1;

                    cipher_block_i_cl = 1'b1;

                    cipher_iv_cl = 1'b1;

                    rst_cipher_block_number = 1'b1;

                    dec_data_cl = 1'b1;

                    byte_data_cl = 1'b1;

                    eluks_busy = 1'b0;

                    for (j = 0; j<(r>>3) ;j=j+1 ) begin
                        feed_data_hmac_cl[j] = 1'b1;
                    end

                    block_addr_cl = 1'b1;

                    next_state = READ_BLOCK_BASE;


                end
            READ_BLOCK_BASE :
                begin
                    if(spi_busy == 0) begin
                        eluks_r_block = 1'b1;
                        next_state = WAIT_BLOCK;
                    end
                end    
            WAIT_BLOCK :
                begin
                    eluks_r_block = 1'b1;
                    if(spi_busy == 1'b0) begin
                        next_state = READ_DATA;
                    end    
                end    
            READ_DATA :
                begin
                    eluks_r_block = 1'b1;
                    
                        
                    r_state_prev_w = 1'b1;
                    //up_bytes = 1;
                    next_state = READ_BYTE;
                    case(counter_bytes_out)
                        8'h0 + index_o : begin
                            eluks_signature_w[index_o[2:0]] = 1'b1;
                            up_index = 1'b1;
                            if(index_o == 8'h5) begin
                                rst_index = 1'b1;
                            end
                        end 
                        8'h6 + index_o : begin
                            mk_digest_w[index_o[$clog2(DIGEST_SIZE>>3)-1:0]] = 1'b1;
                            up_index = 1'b1;
                            if(index_o == (DIGEST_SIZE>>3)-1) begin
                                rst_index = 1'b1;
                            end
                        end 
                        8'h6 + (DIGEST_SIZE>>3) + index_o : begin
                            mk_count_w[index_o[$clog2(COUNT_WIDTH>>3)-1:0]] = 1'b1;
                            up_index = 1'b1;
                            if(index_o == (COUNT_WIDTH>>3)-1) begin
                                rst_index = 1'b1;
                            end
                        end 
                        8'h6 + (DIGEST_SIZE>>3) + (COUNT_WIDTH>>3) + index_o : begin
                            mk_salt_w[index_o[$clog2(SALT_WIDTH>>3)-1:0]] = 1'b1;
                            up_index = 1'b1;
                            if(index_o == (SALT_WIDTH>>3)-1) begin
                                rst_index = 1'b1; 
                            end
                        end 
                        8'h6 + (DIGEST_SIZE>>3) + (COUNT_WIDTH>>3) + (SALT_WIDTH>>3) + index_o : begin
                            mk_hmac_w[index_o[$clog2(N>>3)-1:0]] = 1'b1;
                            up_index = 1'b1;
                            if(index_o == (N>>3)-1) begin
                                rst_index = 1'b1; 
                            end
                        end
                        8'h6 + (DIGEST_SIZE>>3) + (COUNT_WIDTH>>3) + (SALT_WIDTH>>3) + (N>>3) + index_o : begin
                            mk_iv_w[index_o[$clog2(BLOCK_SIZE>>3)-1:0]] = 1'b1;
                            up_index = 1'b1;
                            if(index_o == (BLOCK_SIZE>>3)-1) begin
                                rst_index = 1'b1; 
                            end
                        end
                        8'h6 + (DIGEST_SIZE>>3) + (COUNT_WIDTH>>3) + (SALT_WIDTH>>3) + (N>>3) + (BLOCK_SIZE>>3)+ index_o : begin
                            user_data_blocks_w[index_o[$clog2(USER_SPACE_WIDTH>>3)-1:0]] = 1'b1;
                            up_index = 1'b1;
                            if(index_o == (USER_SPACE_WIDTH>>3)-1) begin
                                rst_index = 1'b1; 
                            end
                        end
                        default :next_state = CHECK_SIGNATURE; 
                            
                    endcase
                    
                    
                end    
            READ_BYTE:
                begin
                    if(prev_state == READ_ENCRYPT_DATA)begin
                        end_eluks_header = 1'b1;
                        eluks_r_block = r_multi_block == 1 ? 0 : 1;
                        eluks_r_multi_block = r_multi_block == 1 ? 1 : 0;
                    end
                    else begin
                        eluks_r_block = 1;
                        eluks_r_multi_block = 0;
                    end
                    
                    eluks_r_byte = 1;
                    up_bytes = 1;

                    next_state = WAIT_BYTE;
                end
            WAIT_BYTE:
                begin
                    if(prev_state == READ_ENCRYPT_DATA)begin
                        end_eluks_header = 1'b1;
                        eluks_r_block = r_multi_block == 1 ? 0 : 1;
                        eluks_r_multi_block = r_multi_block == 1 ? 1 : 0;
                    end
                    else begin
                        eluks_r_block = 1;
                        eluks_r_multi_block = 0;
                    end
                    if(spi_busy == 1'b0)
                    begin
                        next_state = prev_state;
                    end

                end
            CHECK_SIGNATURE :
                begin
                    eluks_r_block = 1;

                    if(eluks_signature == ELUKS_SIGNATURE) begin
                        next_state = READ_KEY_SLOT;
                    end
                    else begin
                        next_state = ERR_SIGNATURE;
                    end
                    
                end
            READ_KEY_SLOT:
                begin
                    eluks_r_block = 1'b1;
                    r_state_prev_w = 1'b1;
                    //up_bytes = 1;
                    next_state = READ_BYTE;
                    case(counter_bytes_out)
                        BASE_KEY_SLOT + (counter_tries_out*KEY_SLOT_SIZE)+index_o: begin
                            activate_w[index_o[1:0]] = 1'b1;
                            up_index = 1'b1;
                            if(index_o == 8'h3) begin
                                rst_index = 1'b1;
                            end
                        end 
                        BASE_KEY_SLOT + (counter_tries_out*KEY_SLOT_SIZE) + 8'h4 + index_o : begin
                            pwd_count_w[index_o[$clog2(COUNT_WIDTH>>3)-1:0]] = 1'b1;
                            up_index = 1'b1;
                            if(index_o == (COUNT_WIDTH>>3)-1) begin
                                rst_index = 1'b1;
                            end
                        end 
                        BASE_KEY_SLOT + (counter_tries_out*KEY_SLOT_SIZE) + 8'h4 + (COUNT_WIDTH>>3) + index_o : begin
                            pwd_salt_w[index_o[$clog2(SALT_WIDTH>>3)-1:0]] = 1'b1;
                            up_index = 1'b1;
                            if(index_o == (SALT_WIDTH>>3)-1) begin
                                rst_index = 1'b1;
                            end
                        end 
                        BASE_KEY_SLOT + (counter_tries_out*KEY_SLOT_SIZE) + 8'h4 + (COUNT_WIDTH>>3) + (SALT_WIDTH>>3) + index_o : begin
                            pwd_encrypt_w[index_o[$clog2((DECRYPT_STAGES*BLOCK_SIZE)>>3)-1:0]] = 1'b1;
                            up_index = 1'b1;
                            if(index_o == 8'((DECRYPT_STAGES*BLOCK_SIZE)>>3)-1) begin
                                rst_index = 1'b1;
                                
                            end
                        end 
                        BASE_KEY_SLOT + (counter_tries_out*KEY_SLOT_SIZE) + 8'h4 + (COUNT_WIDTH>>3) + (SALT_WIDTH>>3) + ((DECRYPT_STAGES*BLOCK_SIZE)>>3) + index_o : begin
                            pwd_iv_w[index_o[$clog2((BLOCK_SIZE)>>3)-1:0]] = 1'b1;
                            up_index = 1'b1;
                            if(index_o == 8'((BLOCK_SIZE)>>3)-1) begin
                                rst_index = 1'b1;
                                
                            end
                        end 
                        default : next_state = CHECK_ACTIVE_KEY_SLOT;
                    endcase
                end
            CHECK_ACTIVE_KEY_SLOT:
                begin
                    eluks_r_block = 1'b1;
                    rst_counter_bytes = 1'b1;
                    up_counter_tries = 1'b1;
                    if(activate == ACTIVATE_SIGNATURE) begin
                        next_state = KDF_USER_PASSWORD;
                    end
                    
                    else begin
                        if(counter_tries_out == KS_SLOTS_LOG'(KS_SLOTS-1)) begin
                            next_state = ERR_SIGNATURE;
                        end
                        else begin
                            next_state = READ_KEY_SLOT;
                        end
                    end
                end
            KDF_USER_PASSWORD :
                begin
                    eluks_r_block = 1'b1;
                    kdf_salt_i = pwd_salt;
                    kdf_count_i = pwd_count;
                    kdf_salt_w = 1'b1;
                    kdf_count_w = 1'b1;
                    kdf_userpassword_i[PSW_WIDTH-1:0] = user_password;
                    kdf_userpassword_w = 1'b1;
                    next_state = WAIT_KDF;
                end
            WAIT_KDF:
                begin
                    eluks_r_block = 1'b1;
                    rst_kdf = 1'b0;
                    if(end_kdf == 1'b1) begin
                        next_state = DECRYPT;
                    end
                end    
            DECRYPT :
                begin
                    rst_kdf = 1'b0;
                    eluks_r_block = 1'b1;
                    cipher_key_i = kdf_o[KEY_SIZE-1:0];
                    cipher_key_w = 1'b1;
                    cipher_iv_i = pwd_iv;
                    cipher_iv_w = 1'b1;
                    cipher_block_i_i = BLOCK_SIZE'(pwd_encrypt >> index_o*BLOCK_SIZE);
                    cipher_block_i_w = 1'b1;
                    next_state = WAIT_DECRYPT;
                end
            WAIT_DECRYPT:
                begin
                    eluks_r_block = 1'b1;
                    rst_cipher = 1'b0;
                    rst_kdf = 1'b0;
                    if(end_dec == 1'b1) begin
                        mk_candidate_w[index_o[0]] = 1'b1;
                        cipher_block_number_up = 1'b1;
                        if(index_o == 8'(DECRYPT_STAGES-1)) begin
                            next_state = KDF_MK_CANDIDATE;
                            rst_kdf = 1'b1;
                            rst_index = 1'b1;
                        end
                        else begin
                            next_state = DECRYPT;
                            up_index = 1'b1;
                        end
                        
                    end
                end    
                
            KDF_MK_CANDIDATE:
                begin
                    rst_cipher_block_number = 1'b1;
                    eluks_r_block = 1'b1;
                    kdf_count_i = mk_count;
                    kdf_salt_i = mk_salt;
                    kdf_salt_w = 1'b1;
                    kdf_count_w = 1'b1;
                    kdf_userpassword_i = mk_candidate;
                    kdf_userpassword_w = 1'b1;
                    next_state = WAIT_KDF_MK_CANDIDATE;
                end
            WAIT_KDF_MK_CANDIDATE:
                begin
                    eluks_r_block = 1'b1;
                    rst_kdf = 1'b0;
                    if(end_kdf == 1'b1) begin
                        next_state = CHECK_MK_CANDIDATE;
                    end
                end
            CHECK_MK_CANDIDATE:
                begin
                    eluks_r_block = 1'b1;
                    rst_kdf = 1'b0;
                    
                    if(kdf_o == mk_digest) begin
                        next_state = WAIT_END_BLOCK_SPI;
                    end
                    
                    else begin
                        if(counter_tries_out == KS_SLOTS_LOG'(KS_SLOTS-1)) begin
                            next_state = ERR_SIGNATURE;
                        end
                        else begin
                            next_state = READ_KEY_SLOT;
                        end
                    end
                    
                end
            WAIT_END_BLOCK_SPI:
                begin
                    rst_counter_tries = 1'b1;
                    rst_counter_bytes = 1'b1;
                    
                    if(spi_busy == 1'b0) begin
                        if(hmac_enable == 1'b1) begin
                            next_state = SEL_FIRST_ENCRYPTED_BLOCK;
                        end
                        else begin
                            next_state = SETUP_CIPHER;
                        end
                    end
                    
                end    
            /*--------------------------------------------------*/
            /*******************CHECK HMAC***********************/
            /*
                1- Seleccionar primer bloque encriptado
                2- Leer en Modo CMD18
                3- Feed Hmac hasta BYTES_IN_NANOFS_PART

            */
            SEL_FIRST_ENCRYPTED_BLOCK:
                begin
                    rst_hmac = 1'b0;

                    up_counter_spi_block = 1'b1;
                    rst_index = 1'b1;
                    rst_counter_bytes = 1'b1;
                    next_state = READ_BLOCK_CMD18_MODE;
                end
            READ_BLOCK_CMD18_MODE:
                begin
                    rst_hmac = 1'b0;
                    eluks_r_multi_block = 1'b1;
                    if(spi_busy == 1) begin
                        next_state = WAIT_BLOCK_CMD18;
                    end
                end 
            WAIT_BLOCK_CMD18:
                begin
                    rst_hmac = 1'b0;
                    eluks_r_multi_block = 1'b1;
                    if(spi_busy == 0) begin          
                        next_state = READ_FEED_DATA_BYTE;
                    end
                end       
            READ_FEED_DATA:
                begin
                    rst_hmac = 1'b0;
                    eluks_r_multi_block = 1'b1;
                    feed_data_hmac_w[index_o] = 1'b1;
                    up_index = 1'b1;
                    next_state = READ_FEED_DATA_BYTE;
                end    
            READ_FEED_DATA_BYTE:
             begin
                 rst_hmac = 1'b0;
                 eluks_r_multi_block = 1'b1;
                 eluks_r_byte = 1;

                 if(spi_busy == 1)
                 begin
                     next_state = WAIT_FEED_BYTE;
                     up_bytes = 1;
                 end

             end
            WAIT_FEED_BYTE:
             begin
                 rst_hmac = 1'b0;
                 eluks_r_multi_block = 1'b1;
                 if(spi_busy == 1'b0)
                 begin
                     if((r >> 3) == index_o) begin
                            next_state = FEED_CONTROL;
                            rst_index = 1'b1;
                        end
                        else begin
                            next_state = READ_FEED_DATA;
                        end
                 end
             end  
            FEED_CONTROL : 
                begin
                    rst_hmac = 1'b0;
                    eluks_r_multi_block = 1;
                    if(busy_hmac == 0) begin
                        data_ready_hmac = 1;
                        next_state = WAIT_BUSY_HMAC_0;
                        if(counter_bytes_out >= (((user_data_blocks)<<9) + 2)) begin
                            data_ready_hmac = 0;
                            next_state = STOP_FEED;
                        end
                        
                    end
                end
            WAIT_BUSY_HMAC_0:
                begin
                    rst_hmac = 1'b0;
                    eluks_r_multi_block = 1;
                    if(busy_hmac == 1)
                        next_state = WAIT_BUSY_HMAC_1;
                end        
            WAIT_BUSY_HMAC_1:
                begin
                    rst_hmac = 1'b0;
                    eluks_r_multi_block = 1;
                    
                    if(busy_hmac == 0) begin
                        next_state = READ_FEED_DATA;
                    end
                end
            STOP_FEED : 
                begin
                    rst_hmac = 1'b0;
                    
                    stop_feed_hmac = 1'b1;
                    
                    if(end_hmac == 1'b1) begin
                       next_state = CHECK_HMAC; 
                    end
                    
                end    
            CHECK_HMAC :
                begin
                    sel_spi_signal = 1'b1;
                    rst_hmac = 1'b0;
                    rst_cipher_block_number = 1'b1;
                    rst_counter_bytes = 1'b1;
                    rst_index = 1'b1;
                    block_addr_w = 1'b1;
                    if(hmac_o != mk_hmac) begin
                        next_state = ERR_HMAC;
                    end
                    
                    else begin
                        if(spi_busy == 1'b1) begin
                            next_state = SETUP_CIPHER;
                        end    
                    end
                    
                end
            /*--------------------------------------------------*/
            SETUP_CIPHER:
                begin
                    sel_spi_signal = 1'b1;
                    cipher_key_i = mk_candidate;
                    cipher_key_w = 1'b1;
                    cipher_block_i_i = 0;
                    cipher_block_i_w = 1'b1; 
                    cipher_iv_i = mk_iv;
                    cipher_iv_w = 1'b1;
                    if(spi_busy == 1'b0) begin
                        next_state = WAIT_SETUP_CIPHER;
                    end                   
                end
            WAIT_SETUP_CIPHER:
                begin
                    sel_spi_signal = 1'b1;
                    rst_cipher = 1'b0;
                    
                    if(end_dec == 1'b1) begin
                        next_state = WAIT_FOR_RQ_BYTE;
                    end
                end
            /*--------------------------------------------------*/
            WAIT_FOR_RQ_BYTE:
                begin
                    //reiniciar contador cada vez que se cambia de bloque, un contador de 0,7 . Cada vez que es 0 se debe leer datos de la flash
                    
                    end_eluks_header = 1'b1;
                    sel_spi_signal = 1'b1;
                    eluks_busy = spi_busy;
                    rst_cipher = 1'b0;
                    
                    if(block_addr_reg != block_addr) begin
                        block_addr_w = 1'b1;
                        rst_cipher_block_number = 1'b1;
                    end
                    
                    
                    if(r_block == 0 && r_multi_block == 0) begin
                        rst_counter_tries = 1'b1;
                        rst_counter_bytes = 1'b1;
                    end
                    if(r_byte == 1'b1) begin
                        
                        if(counter_tries_out == KS_SLOTS_LOG'(0)) begin
                            rst_counter_bytes = 1'b1;
                            next_state = READ_ENCRYPT_DATA;
                        end
                        else begin
                            next_state = SEND_DECRYPT_BYTE;
                        end
                    end
                    
                end    
            READ_ENCRYPT_DATA:
                begin
                    end_eluks_header = 1'b1;
                    sel_spi_signal = 1'b1;
                    r_state_prev_w = 1'b1;
                    rst_cipher = 1'b0;
                    //up_bytes = 1;
                    next_state = READ_BYTE;
                    case(counter_bytes_out)
                        8'h0 + index_o : begin
                                    enc_data_i_w[index_o[$clog2(BLOCK_SIZE>>3)-1:0]] = 1'b1;
                                    up_index = 1'b1;
                                    if(index_o == (BLOCK_SIZE>>3)-1 ) begin
                                        rst_index = 1'b1;  
                                    end
                                end 
                        default :begin
                            cipher_block_i_i = enc_data;
                            cipher_block_i_w = 1'b1;
                            next_state = DECRYPT_DATA;
                        end    
                         
                    endcase
                end
            DECRYPT_DATA:
                begin
                    end_eluks_header = 1'b1;
                    sel_spi_signal = 1'b1;
                    rst_counter_bytes = 1'b1;
                    rst_cipher = 1'b0;
                    rq_data_cipher = 1'b1;

                    next_state = WAIT_DECRYPT_DATA;
                end
            WAIT_DECRYPT_DATA:
                begin
                    end_eluks_header = 1'b1;
                    sel_spi_signal = 1'b1;
                    rst_cipher = 1'b0;
                    if(end_dec == 1'b1) begin
                        cipher_block_number_up = 1'b1;
                        dec_data_w = 1'b1;
                        next_state = SEND_DECRYPT_BYTE;
                    end
                end
            SEND_DECRYPT_BYTE:
                begin
                    rst_cipher = 1'b0;
                    end_eluks_header = 1'b1;
                    sel_spi_signal = 1'b1;
                    up_counter_tries = 1'b1;
                    byte_data_i = 8'(dec_data >> (counter_tries_out*8));
                    byte_data_w = 1'b1; 
                    next_state = WAIT_FOR_RQ_BYTE;
                    if(counter_tries_out == KS_SLOTS_LOG'((BLOCK_SIZE>>3)-1)) begin
                        rst_counter_tries = 1'b1;
                    end
                end          
            ERROR_PASSWORD:
                begin
                    sel_spi_signal = 1'b1;
                    eluks_busy = 1'b0;
                    error = 1;
                end     
            ERR_SIGNATURE:
                begin
                    sel_spi_signal = 1'b1;
                    eluks_busy = 1'b0;
                    error = 1;
                end 
            ERR_HMAC:
                begin
                    rst_hmac = 1'b0;
                    sel_spi_signal = 1'b1;
                    eluks_busy = 1'b0;
                    error = 1;
                end                                    
            default:;
        endcase


    end
    
    


    always_ff @(posedge clk) begin
        if (rst) begin
            current_state <= IDLE;
        end
        else begin
            current_state <= next_state;
        end
    end


endmodule : eluks_control_unit