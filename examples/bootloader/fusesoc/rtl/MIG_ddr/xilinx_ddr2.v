/* 
 * Wrapper for Xilinx MIG'd DDR2 controller
 * The DDR2 controller have 5 wishbone slave interfaces,
 * if more masters than that is needed, arbiters have to be added
 */

module xilinx_ddr2
  (
   // Inputs
    input [31:0]  wbm0_adr_i, 
    input [1:0]   wbm0_bte_i, 
    input [2:0]   wbm0_cti_i, 
    input 	  wbm0_cyc_i, 
    input [31:0]  wbm0_dat_i, 
    input [3:0]   wbm0_sel_i,
  
    input 	  wbm0_stb_i, 
    input 	  wbm0_we_i,
  
   // Outputs
    output 	  wbm0_ack_o, 
    output 	  wbm0_err_o, 
    output 	  wbm0_rty_o, 
    output [31:0] wbm0_dat_o,
  
    output 	  wb_clk,
    input 	  wb_rst,

    output [12:0] ddr2_addr,
    output [2:0]  ddr2_ba,
    output 	  ddr2_ras_n,
    output 	  ddr2_cas_n,
    output 	  ddr2_we_n,

    output 	  ddr2_odt,
    output 	  ddr2_cke,
    output 	  ddr2_dm,
    output 	  ddr2_udm,
   
    inout [15:0]  ddr2_dq, 
    inout 	  ddr2_dqs_p,
    inout 	  ddr2_dqs_n,
    inout 	  ddr2_udqs_p,
    inout 	  ddr2_udqs_n,
    output 	  ddr2_ck_p,
    output 	  ddr2_ck_n,
    output ddr2_cs_n,
    input 	  ddr2_if_clk,
    input 	  ddr2_if_rst,
    output        init_calib_complete
   );

   parameter DATA_WIDTH = 32;
   parameter AXI_DATA_WIDTH = 32;
   parameter ADDR_WIDTH = 28;
   parameter AXI_ID_WIDTH = 4;

   wire [AXI_ID_WIDTH-1:0] s_axi_awid;
   wire [ADDR_WIDTH-1:0] s_axi_awaddr;	
   wire [7:0] s_axi_awlen;
   wire [2:0] s_axi_awsize;
   wire [1:0] s_axi_awburst;
   wire [3:0] s_axi_awcache;
   wire [2:0] s_axi_awprot;
   wire [3:0] s_axi_awqos;
   wire [0:0] s_axi_awvalid;
   wire [0:0] s_axi_awready;
   wire [AXI_DATA_WIDTH-1:0] s_axi_wdata;
   wire [AXI_DATA_WIDTH/8-1:0] s_axi_wstrb;
   wire [0:0] s_axi_wlast;
   wire [0:0] s_axi_wvalid;
   wire [0:0] s_axi_wready;

   wire [AXI_ID_WIDTH-1:0] s_axi_bid;
   wire [1:0] s_axi_bresp;
   wire [0:0] s_axi_bvalid;
   wire [0:0] s_axi_bready;

   wire [AXI_ID_WIDTH-1:0] s_axi_arid;
   wire [ADDR_WIDTH-1:0] s_axi_araddr;
   wire [7:0] s_axi_arlen;
   wire [2:0] s_axi_arsize;
   wire [1:0] s_axi_arburst;
   wire [3:0] s_axi_arcache;
   wire [2:0] s_axi_arprot;
   wire [3:0] s_axi_arqos;
   wire [0:0]  s_axi_arvalid;
   wire [0:0] s_axi_arready;

   wire [AXI_ID_WIDTH-1:0] s_axi_rid;
   wire [AXI_DATA_WIDTH-1:0] s_axi_rdata;
   wire [1:0] s_axi_rresp;
   wire [0:0] s_axi_rlast;
   wire [0:0] s_axi_rvalid;
   wire [0:0] s_axi_rready;


    wire mig_ui_clk;
    wire ddr_mmcm_locked;
    wire ddr_calib_done;
    wire mig_ui_rst;
    wire sys_rst;
    wire sys_clk;

    assign sys_rst = !(ddr_mmcm_locked & ddr_calib_done);
    assign wb_clk = mig_ui_clk;

   wb2axi #(.DATA_WIDTH(DATA_WIDTH),
            .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
            .ADDR_WIDTH(ADDR_WIDTH),
            .AXI_ID_WIDTH(AXI_ID_WIDTH)) 
   u_wb_2_axi(
    .clk(wb_clk),
    .rst(wb_rst),

    // Wishbone signals
    .wb_cyc_i(wbm0_cyc_i),
    .wb_stb_i(wbm0_stb_i),
    .wb_we_i(wbm0_we_i),
    .wb_adr_i(wbm0_adr_i),
    .wb_dat_i(wbm0_dat_i),
    .wb_sel_i(wbm0_sel_i),
    .wb_cti_i(wbm0_cti_i),
    .wb_bte_i(wbm0_bte_i),
    .wb_ack_o(wbm0_ack_o),
    .wb_err_o(wbm0_err_o),
    .wb_rty_o(wbm0_rty_o),
    .wb_dat_o(wbm0_dat_o),

    // AXI signals
    .m_axi_awid(s_axi_awid),
    .m_axi_awaddr(s_axi_awaddr),
    .m_axi_awlen(s_axi_awlen),
    .m_axi_awsize(s_axi_awsize),
    .m_axi_awburst(s_axi_awburst),
    .m_axi_awcache(s_axi_awcache),
    .m_axi_awprot(s_axi_awprot),
    .m_axi_awqos(s_axi_awqos),
    .m_axi_awvalid(s_axi_awvalid),
    .m_axi_awready(s_axi_awready),

    .m_axi_wdata(s_axi_wdata),
    .m_axi_wstrb(s_axi_wstrb),
    .m_axi_wlast(s_axi_wlast),
    .m_axi_wvalid(s_axi_wvalid),
    .m_axi_wready(s_axi_wready),
    
    .m_axi_bid(s_axi_bid),
    .m_axi_bresp(s_axi_bresp),
    .m_axi_bvalid(s_axi_bvalid),
    .m_axi_bready(s_axi_bready),
    
    .m_axi_arid(s_axi_arid),
    .m_axi_araddr(s_axi_araddr),
    .m_axi_arlen(s_axi_arlen),
    .m_axi_arsize(s_axi_arsize),
    .m_axi_arburst(s_axi_arburst),
    .m_axi_arcache(s_axi_arcache),
    .m_axi_arprot(s_axi_arprot),
    .m_axi_arqos(s_axi_arqos),
    .m_axi_arvalid(s_axi_arvalid),
    .m_axi_arready(s_axi_arready),
    
    .m_axi_rid(s_axi_rid),
    .m_axi_rdata(s_axi_rdata),
    .m_axi_rresp(s_axi_rresp),
    .m_axi_rlast(s_axi_rlast),
    .m_axi_rvalid(s_axi_rvalid),
    .m_axi_rready(s_axi_rready)
    );

      
   design_1_mig_7series_0_0 u_design_1_mig_7series_0_1 (

    // Memory interface ports
    .ddr2_addr                      (ddr2_addr),  // output [12:0]                       ddr2_addr
    .ddr2_ba                        (ddr2_ba),  // output [2:0]                      ddr2_ba
    .ddr2_cas_n                     (ddr2_cas_n),  // output                                       ddr2_cas_n
    .ddr2_ck_n                      (ddr2_ck_n),  // output [0:0]                        ddr2_ck_n
    .ddr2_ck_p                      (ddr2_ck_p),  // output [0:0]                        ddr2_ck_p
    .ddr2_cke                       (ddr2_cke),  // output [0:0]                       ddr2_cke
    .ddr2_ras_n                     (ddr2_ras_n),  // output                                       ddr2_ras_n
    .ddr2_we_n                      (ddr2_we_n),  // output                                       ddr2_we_n
    .ddr2_dq                        (ddr2_dq),  // inout [15:0]                         ddr2_dq
    .ddr2_dqs_n                     ({ddr2_udqs_n,ddr2_dqs_n}),  // inout [1:0]                        ddr2_dqs_n
    .ddr2_dqs_p                     ({ddr2_udqs_p,ddr2_dqs_p}),  // inout [1:0]                        ddr2_dqs_p
    .init_calib_complete            (ddr_calib_done),  // output                                       init_calib_complete
      
	.ddr2_cs_n                      (ddr2_cs_n),  // output [0:0]           ddr2_cs_n
    .ddr2_dm                        ({ddr2_udm,ddr2_dm}),  // output [1:0]                        ddr2_dm
    .ddr2_odt                       (ddr2_odt),  // output [0:0]                       ddr2_odt
    // Application interface ports
    .ui_clk                         (mig_ui_clk),  // output                                       ui_clk
    .ui_clk_sync_rst                (mig_ui_rst),  // output                                       ui_clk_sync_rst
    .mmcm_locked                    (ddr_mmcm_locked),  // 
    .aresetn                        (!sys_rst),  // 
    .app_sr_active                  (0),  // output                                       app_sr_active
    .app_ref_ack                    (0),  // output                                       app_ref_ack
    .app_zq_ack                     (0),  // output                                       app_zq_ack
    // Slave Interface Write Address Ports
    .s_axi_awid                     (s_axi_awid),  // input  [3:0]                s_axi_awid
    .s_axi_awaddr                   (s_axi_awaddr),  // input  [31:0]              s_axi_awaddr
    .s_axi_awlen                    (s_axi_awlen),  // input  [7:0]                                 s_axi_awlen
    .s_axi_awsize                   (s_axi_awsize),  // input  [2:0]                                 s_axi_awsize
    .s_axi_awburst                  (s_axi_awburst),  // input  [1:0]                                 s_axi_awburst
    .s_axi_awlock                   (0),  // input  [0:0]                                 s_axi_awlock
    .s_axi_awcache                  (s_axi_awcache),  // input  [3:0]                                 s_axi_awcache
    .s_axi_awprot                   (s_axi_awprot),  // input  [2:0]                                 s_axi_awprot
    .s_axi_awqos                    (s_axi_awqos),  // input  [3:0]                                 s_axi_awqos
    .s_axi_awvalid                  (s_axi_awvalid),  // input                                        s_axi_awvalid
    .s_axi_awready                  (s_axi_awready),  // output                                       s_axi_awready
    // Slave Interface Write Data Ports
    .s_axi_wdata                    (s_axi_wdata),  // input  [31:0]              s_axi_wdata
    .s_axi_wstrb                    (s_axi_wstrb),  // input  [3:0]            s_axi_wstrb
    .s_axi_wlast                    (s_axi_wlast),  // input                                        s_axi_wlast
    .s_axi_wvalid                   (s_axi_wvalid),  // input                                        s_axi_wvalid
    .s_axi_wready                   (s_axi_wready),  // output                                       s_axi_wready
    // Slave Interface Write Response Ports
    .s_axi_bid                      (s_axi_bid),  // output [3:0]                s_axi_bid
    .s_axi_bresp                    (s_axi_bresp),  // output [1:0]                                 s_axi_bresp
    .s_axi_bvalid                   (s_axi_bvalid),  // output                                       s_axi_bvalid
    .s_axi_bready                   (s_axi_bready),  // input                                        s_axi_bready
    // Slave Interface Read Address Ports
    .s_axi_arid                     (s_axi_arid),  // input  [3:0]                s_axi_arid
    .s_axi_araddr                   (s_axi_araddr),  // input  [31:0]              s_axi_araddr
    .s_axi_arlen                    (s_axi_arlen),  // input  [7:0]                                 s_axi_arlen
    .s_axi_arsize                   (s_axi_arsize),  // input  [2:0]                                 s_axi_arsize
    .s_axi_arburst                  (s_axi_arburst),  // input  [1:0]                                 s_axi_arburst
    .s_axi_arlock                   (0),  // input  [0:0]                                 s_axi_arlock
    .s_axi_arcache                  (s_axi_arcache),  // input  [3:0]                                 s_axi_arcache
    .s_axi_arprot                   (s_axi_arprot),  // input  [2:0]                                 s_axi_arprot
    .s_axi_arqos                    (s_axi_arqos),  // input  [3:0]                                 s_axi_arqos
    .s_axi_arvalid                  (s_axi_arvalid),  // input                                        s_axi_arvalid
    .s_axi_arready                  (s_axi_arready),  // output                                       s_axi_arready
    // Slave Interface Read Data Ports
    .s_axi_rid                      (s_axi_rid),  // output [3:0]                s_axi_rid
    .s_axi_rdata                    (s_axi_rdata),  // output [31:0]              s_axi_rdata
    .s_axi_rresp                    (s_axi_rresp),  // output [1:0]                                 s_axi_rresp
    .s_axi_rlast                    (s_axi_rlast),  // output                                       s_axi_rlast
    .s_axi_rvalid                   (s_axi_rvalid),  // output                                       s_axi_rvalid
    .s_axi_rready                   (s_axi_rready),  // input                                        s_axi_rready
    // System Clock Ports
    .sys_clk_i                       (ddr2_if_clk),
    // Reference Clock Ports
    .clk_ref_i                      (ddr2_if_clk),
    .sys_rst                        (ddr2_if_rst) // input  sys_rst
    );



    

endmodule //xilinx_ddr2
