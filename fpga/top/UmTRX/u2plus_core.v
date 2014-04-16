//
// Copyright 2011 Ettus Research LLC
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

// ////////////////////////////////////////////////////////////////////////////////
// Module Name:    u2_core
// ////////////////////////////////////////////////////////////////////////////////

module u2plus_core
  (// Clocks
   input sys_clk,
   input dsp_clk,
   input fe_clk,
   input wb_clk,
   input clk_icap, //ICAP timing fixes for UmTRX Spartan-6 FPGA.
   output clock_ready,
   input clk_to_mac,
   input pps_in,
   
   // Misc, debug
   output [7:0] leds,
   output [31:0] debug,
   output [1:0] debug_clk,

   // GMII
   //   GMII-CTRL
   input GMII_COL,
   input GMII_CRS,

   //   GMII-TX
   output [7:0] GMII_TXD,
   output GMII_TX_EN,
   output GMII_TX_ER,
   output GMII_GTX_CLK,
   input GMII_TX_CLK,  // 100mbps clk

   //   GMII-RX
   input [7:0] GMII_RXD,
   input GMII_RX_CLK,
   input GMII_RX_DV,
   input GMII_RX_ER,

   //   GMII-Management
   inout MDIO,
   output MDC,
   input PHY_INTn,   // open drain
   output PHY_RESETn,

   // ADC
   input adc0_strobe,
   input [11:0] adc0_a,
   input [11:0] adc0_b,
   input adc1_strobe,
   input [11:0] adc1_a,
   input [11:0] adc1_b,
   output [1:0] lms_res,

   // DAC
   input dac0_strobe,
   output [11:0] dac0_a,
   output [11:0] dac0_b,
   input dac1_strobe,
   output [11:0] dac1_a,
   output [11:0] dac1_b,

   // I2C
   input scl_pad_i,
   output scl_pad_o,
   output scl_pad_oen_o,
   input sda_pad_i,
   output sda_pad_o,
   output sda_pad_oen_o,
   
   // Clock Gen Control
   output [1:0] clk_en,
   output [1:0] clk_sel,
   input clk_func,        // FIXME is an input to control the 9510
   input clk_status,

   // Generic SPI
   output sclk,
   output mosi,
   input miso,
   output sen_dac,
   output sen_lms1,
   output sen_lms2,
   //Diversity switches
   output DivSw1,
   output DivSw2,
   input aux_scl_pad_i,
   output aux_scl_pad_o,
   output aux_scl_pad_oen_o,
   input aux_sda_pad_i,
   output aux_sda_pad_o,
   output aux_sda_pad_oen_o,
   //AUX SPI
   output aux_sdat,
   output aux_sclk,
   output aux_sen1,
   output aux_sen2,
   input aux_ld1,
   input aux_ld2, 
   
   // GPIO to DBoards
   inout [15:0] io_tx,
   inout [15:0] io_rx,

`ifndef NO_EXT_FIFO
   // External RAM
   input [35:0] RAM_D_pi,
   output [35:0] RAM_D_po,
   output RAM_D_poe,
   output [20:0] RAM_A,
   output RAM_CE1n,
   output RAM_CENn,
   output RAM_WEn,
   output RAM_OEn,
   output RAM_LDn,
`endif // !`ifndef NO_EXT_FIFO
   
   // Debug stuff
   output [3:0] uart_tx_o, 
   input [3:0] uart_rx_i,
   output [3:0] uart_baud_o,
   input sim_mode,
   input [3:0] clock_divider,
   input button,
   
   output spiflash_cs, output spiflash_clk, input spiflash_miso, output spiflash_mosi
   );

   localparam SR_MISC     =   0;   // 7 regs
   localparam SR_TESTSIG  =   8;   // 2 regs for each DAC
   localparam SR_TIME64   =  10;   // 6
   localparam SR_BUF_POOL =  16;   // 4

   localparam SR_RX_FRONT0 =  20;   // 5
   localparam SR_RX_FRONT1 =  25;   // 5
   localparam SR_RX_CTRL0 =  32;   // 9
   localparam SR_RX_DSP0  =  48;   // 7
   localparam SR_RX_CTRL1 =  80;   // 9
   localparam SR_RX_DSP1  =  96;   // 7

   localparam SR_TX_FRONT0 = 110;   // ?
   localparam SR_TX_CTRL0  = 126;   // 6
   localparam SR_TX_DSP0   = 135;   // 5
   localparam SR_TX_FRONT1 = 145;   // ?
   localparam SR_TX_CTRL1  = 161;   // 6
   localparam SR_TX_DSP1   = 170;   // 5
   localparam SR_RX_FRONT_SW = 176;
   localparam SR_TX_FRONT_SW = 177;

   localparam SR_DIVSW    = 180;   // 2
   localparam SR_GPIO     = 184;   // 5   
   localparam SR_UDP_SM   = 192;   // 64
   
   // FIFO Sizes, 9 = 512 lines, 10 = 1024, 11 = 2048
   // all (most?) are 36 bits wide, so 9 is 1 BRAM, 10 is 2, 11 is 4 BRAMs
   localparam DSP_RX_FIFOSIZE = 10;
   localparam DSP_TX_FIFOSIZE = 10;
   localparam ETH_TX_FIFOSIZE = 9;
   localparam ETH_RX_FIFOSIZE = 11;
   
   wire [7:0] 	set_addr, set_addr_dsp, set_addr_sys, set_addr_user, set_addr_fe;
   wire [31:0] 	set_data, set_data_dsp, set_data_sys, set_data_user, set_data_fe;
   wire 	set_stb, set_stb_dsp, set_stb_sys, set_stb_user, set_stb_fe;
   
   reg 		wb_rst;
   wire 	dsp_rst, sys_rst, fe_rst;

   wire [31:0] 	status;
   wire 	bus_error, spi_int, i2c_int, aux_i2c_int, pps_int, onetime_int, periodic_int, buffer_int;
   wire 	proc_int, overrun0, overrun1, underrun;
   wire 	 underrun1;
   wire [3:0] 	uart_tx_int, uart_rx_int;

   wire [31:0] 	debug_gpio_0, debug_gpio_1;

   wire [31:0] 	debug_rx, debug_mac, debug_mac0, debug_mac1, debug_tx_dsp, debug_txc,
		debug_rx_dsp, debug_udp, debug_extfifo, debug_extfifo2;

   wire [15:0] 	dsp_rx_occ, dsp_tx_occ, eth_rx_occ, eth_tx_occ, eth_rx_occ2;
   wire 	dsp_rx_full, dsp_tx_full, eth_rx_full, eth_tx_full, eth_rx_full2;
   wire 	dsp_rx_empty, dsp_tx_empty, eth_rx_empty, eth_tx_empty, eth_rx_empty2;
	
   wire [31:0] 	irq;
   wire [63:0] 	vita_time, vita_time_pps;
   
   wire 	 run_rx0, run_rx1, run_tx0, run_tx1;
   wire   run_rx0_mux, run_rx1_mux;
   wire   run_tx0_mux, run_tx1_mux;

    //generate sync reset signals for dsp and sys domains
    reset_sync sys_rst_sync(.clk(sys_clk), .reset_in(wb_rst), .reset_out(sys_rst));
    reset_sync dsp_rst_sync(.clk(dsp_clk), .reset_in(wb_rst), .reset_out(dsp_rst));
    reset_sync fe_rst_sync(.clk(fe_clk), .reset_in(wb_rst), .reset_out(fe_rst));

   // ///////////////////////////////////////////////////////////////////////////////////////////////
   // Wishbone Single Master INTERCON
   localparam 	dw = 32;  // Data bus width
   localparam 	aw = 16;  // Address bus width, for byte addressibility, 16 = 64K byte memory space
   localparam	sw = 4;   // Select width -- 32-bit data bus with 8-bit granularity.  
   
   wire [dw-1:0] m0_dat_o, m0_dat_i;
   wire [dw-1:0] s0_dat_o, s1_dat_o, s0_dat_i, s1_dat_i, s2_dat_o, s3_dat_o, s2_dat_i, s3_dat_i,
		 s4_dat_o, s5_dat_o, s4_dat_i, s5_dat_i, s6_dat_o, s7_dat_o, s6_dat_i, s7_dat_i,
		 s8_dat_o, s9_dat_o, s8_dat_i, s9_dat_i, sa_dat_o, sa_dat_i, sb_dat_i, sb_dat_o,
		 sc_dat_i, sc_dat_o, sd_dat_i, sd_dat_o, se_dat_i, se_dat_o, sf_dat_i, sf_dat_o;
   wire [aw-1:0] m0_adr,s0_adr,s1_adr,s2_adr,s3_adr,s4_adr,s5_adr,s6_adr,s7_adr,s8_adr,s9_adr,sa_adr,sb_adr,sc_adr, sd_adr, se_adr, sf_adr;
   wire [sw-1:0] m0_sel,s0_sel,s1_sel,s2_sel,s3_sel,s4_sel,s5_sel,s6_sel,s7_sel,s8_sel,s9_sel,sa_sel,sb_sel,sc_sel, sd_sel, se_sel, sf_sel;
   wire 	 m0_ack,s0_ack,s1_ack,s2_ack,s3_ack,s4_ack,s5_ack,s6_ack,s7_ack,s8_ack,s9_ack,sa_ack,sb_ack,sc_ack, sd_ack, se_ack, sf_ack;
   wire 	 m0_stb,s0_stb,s1_stb,s2_stb,s3_stb,s4_stb,s5_stb,s6_stb,s7_stb,s8_stb,s9_stb,sa_stb,sb_stb,sc_stb, sd_stb, se_stb, sf_stb;
   wire 	 m0_cyc,s0_cyc,s1_cyc,s2_cyc,s3_cyc,s4_cyc,s5_cyc,s6_cyc,s7_cyc,s8_cyc,s9_cyc,sa_cyc,sb_cyc,sc_cyc, sd_cyc, se_cyc, sf_cyc;
   wire 	 m0_err, m0_rty;
   wire 	 m0_we,s0_we,s1_we,s2_we,s3_we,s4_we,s5_we,s6_we,s7_we,s8_we,s9_we,sa_we,sb_we,sc_we,sd_we,se_we,sf_we;
   
   wb_1master #(.decode_w(8),
		.s0_addr(8'b0000_0000),.s0_mask(8'b1100_0000),  // Main RAM (0-16K)
		.s1_addr(8'b0100_0000),.s1_mask(8'b1111_0000),  // Packet Router (16-20K)
 		.s2_addr(8'b0101_0000),.s2_mask(8'b1111_1100),  // SPI
		.s3_addr(8'b0101_0100),.s3_mask(8'b1111_1100),  // I2C
		.s4_addr(8'b0101_1000),.s4_mask(8'b1111_1100),  // GPSDO
		.s5_addr(8'b0101_1100),.s5_mask(8'b1111_1100),  // Readback
		.s6_addr(8'b0110_0000),.s6_mask(8'b1111_0000),  // Ethernet MAC
		.s7_addr(8'b0111_0000),.s7_mask(8'b1111_0000),  // Settings Bus (only uses 1K)
		.s8_addr(8'b1000_0000),.s8_mask(8'b1111_1100),  // PIC
		.s9_addr(8'b1000_0100),.s9_mask(8'b1111_1100),  // I2C AUX
		.sa_addr(8'b1000_1000),.sa_mask(8'b1111_1100),  // UART
		.sb_addr(8'b1000_1100),.sb_mask(8'b1111_1100),  // Unused
		.sc_addr(8'b1001_0000),.sc_mask(8'b1111_0000),  // Unused
		.sd_addr(8'b1010_0000),.sd_mask(8'b1111_0000),  // ICAP
		.se_addr(8'b1011_0000),.se_mask(8'b1111_0000),  // SPI Flash
		.sf_addr(8'b1100_0000),.sf_mask(8'b1100_0000),  // 48K-64K, Boot RAM
		.dw(dw),.aw(aw),.sw(sw)) wb_1master
     (.clk_i(wb_clk),.rst_i(wb_rst),       
      .m0_dat_o(m0_dat_o),.m0_ack_o(m0_ack),.m0_err_o(m0_err),.m0_rty_o(m0_rty),.m0_dat_i(m0_dat_i),
      .m0_adr_i(m0_adr),.m0_sel_i(m0_sel),.m0_we_i(m0_we),.m0_cyc_i(m0_cyc),.m0_stb_i(m0_stb),
      .s0_dat_o(s0_dat_o),.s0_adr_o(s0_adr),.s0_sel_o(s0_sel),.s0_we_o	(s0_we),.s0_cyc_o(s0_cyc),.s0_stb_o(s0_stb),
      .s0_dat_i(s0_dat_i),.s0_ack_i(s0_ack),.s0_err_i(0),.s0_rty_i(0),
      .s1_dat_o(s1_dat_o),.s1_adr_o(s1_adr),.s1_sel_o(s1_sel),.s1_we_o	(s1_we),.s1_cyc_o(s1_cyc),.s1_stb_o(s1_stb),
      .s1_dat_i(s1_dat_i),.s1_ack_i(s1_ack),.s1_err_i(0),.s1_rty_i(0),
      .s2_dat_o(s2_dat_o),.s2_adr_o(s2_adr),.s2_sel_o(s2_sel),.s2_we_o	(s2_we),.s2_cyc_o(s2_cyc),.s2_stb_o(s2_stb),
      .s2_dat_i(s2_dat_i),.s2_ack_i(s2_ack),.s2_err_i(0),.s2_rty_i(0),
      .s3_dat_o(s3_dat_o),.s3_adr_o(s3_adr),.s3_sel_o(s3_sel),.s3_we_o	(s3_we),.s3_cyc_o(s3_cyc),.s3_stb_o(s3_stb),
      .s3_dat_i(s3_dat_i),.s3_ack_i(s3_ack),.s3_err_i(0),.s3_rty_i(0),
      .s4_dat_o(s4_dat_o),.s4_adr_o(s4_adr),.s4_sel_o(s4_sel),.s4_we_o	(s4_we),.s4_cyc_o(s4_cyc),.s4_stb_o(s4_stb),
      .s4_dat_i(s4_dat_i),.s4_ack_i(s4_ack),.s4_err_i(0),.s4_rty_i(0),
      .s5_dat_o(s5_dat_o),.s5_adr_o(s5_adr),.s5_sel_o(s5_sel),.s5_we_o	(s5_we),.s5_cyc_o(s5_cyc),.s5_stb_o(s5_stb),
      .s5_dat_i(s5_dat_i),.s5_ack_i(s5_ack),.s5_err_i(0),.s5_rty_i(0),
      .s6_dat_o(s6_dat_o),.s6_adr_o(s6_adr),.s6_sel_o(s6_sel),.s6_we_o	(s6_we),.s6_cyc_o(s6_cyc),.s6_stb_o(s6_stb),
      .s6_dat_i(s6_dat_i),.s6_ack_i(s6_ack),.s6_err_i(0),.s6_rty_i(0),
      .s7_dat_o(s7_dat_o),.s7_adr_o(s7_adr),.s7_sel_o(s7_sel),.s7_we_o	(s7_we),.s7_cyc_o(s7_cyc),.s7_stb_o(s7_stb),
      .s7_dat_i(s7_dat_i),.s7_ack_i(s7_ack),.s7_err_i(0),.s7_rty_i(0),
      .s8_dat_o(s8_dat_o),.s8_adr_o(s8_adr),.s8_sel_o(s8_sel),.s8_we_o	(s8_we),.s8_cyc_o(s8_cyc),.s8_stb_o(s8_stb),
      .s8_dat_i(s8_dat_i),.s8_ack_i(s8_ack),.s8_err_i(0),.s8_rty_i(0),
      .s9_dat_o(s9_dat_o),.s9_adr_o(s9_adr),.s9_sel_o(s9_sel),.s9_we_o	(s9_we),.s9_cyc_o(s9_cyc),.s9_stb_o(s9_stb),
      .s9_dat_i(s9_dat_i),.s9_ack_i(s9_ack),.s9_err_i(0),.s9_rty_i(0),
      .sa_dat_o(sa_dat_o),.sa_adr_o(sa_adr),.sa_sel_o(sa_sel),.sa_we_o(sa_we),.sa_cyc_o(sa_cyc),.sa_stb_o(sa_stb),
      .sa_dat_i(sa_dat_i),.sa_ack_i(sa_ack),.sa_err_i(0),.sa_rty_i(0),
      .sb_dat_o(sb_dat_o),.sb_adr_o(sb_adr),.sb_sel_o(sb_sel),.sb_we_o(sb_we),.sb_cyc_o(sb_cyc),.sb_stb_o(sb_stb),
      .sb_dat_i(sb_dat_i),.sb_ack_i(sb_ack),.sb_err_i(0),.sb_rty_i(0),
      .sc_dat_o(sc_dat_o),.sc_adr_o(sc_adr),.sc_sel_o(sc_sel),.sc_we_o(sc_we),.sc_cyc_o(sc_cyc),.sc_stb_o(sc_stb),
      .sc_dat_i(sc_dat_i),.sc_ack_i(sc_ack),.sc_err_i(0),.sc_rty_i(0),
      .sd_dat_o(sd_dat_o),.sd_adr_o(sd_adr),.sd_sel_o(sd_sel),.sd_we_o(sd_we),.sd_cyc_o(sd_cyc),.sd_stb_o(sd_stb),
      .sd_dat_i(sd_dat_i),.sd_ack_i(sd_ack),.sd_err_i(0),.sd_rty_i(0),
      .se_dat_o(se_dat_o),.se_adr_o(se_adr),.se_sel_o(se_sel),.se_we_o(se_we),.se_cyc_o(se_cyc),.se_stb_o(se_stb),
      .se_dat_i(se_dat_i),.se_ack_i(se_ack),.se_err_i(0),.se_rty_i(0),
      .sf_dat_o(sf_dat_o),.sf_adr_o(sf_adr),.sf_sel_o(sf_sel),.sf_we_o(sf_we),.sf_cyc_o(sf_cyc),.sf_stb_o(sf_stb),
      .sf_dat_i(sf_dat_i),.sf_ack_i(sf_ack),.sf_err_i(0),.sf_rty_i(0));

   // Unused Slaves b, c
   assign sb_ack = 0;   assign sc_ack = 0;
   
   // ////////////////////////////////////////////////////////////////////////////////////////
   // Reset Controller

   reg 		 cpu_bldr_ctrl_state;
   localparam CPU_BLDR_CTRL_WAIT = 0;
   localparam CPU_BLDR_CTRL_DONE = 1;
   
   wire 	 bldr_done;
   wire 	 por_rst;
   wire [aw-1:0] cpu_adr;

   // Swap boot ram and main ram when in bootloader mode
   assign m0_adr = (^cpu_adr[15:14] | (cpu_bldr_ctrl_state == CPU_BLDR_CTRL_DONE)) ? cpu_adr :
		   cpu_adr ^ 16'hC000;
   
   system_control sysctrl 
     (.wb_clk_i(wb_clk), .wb_rst_o(por_rst), .ram_loader_done_i(1'b1) );
   
   always @(posedge wb_clk)
     if(por_rst) begin
        cpu_bldr_ctrl_state <= CPU_BLDR_CTRL_WAIT;
        wb_rst <= 1'b1;
     end
     else begin
        case(cpu_bldr_ctrl_state)
	  
          CPU_BLDR_CTRL_WAIT: begin
             wb_rst <= 1'b0;
             if (bldr_done == 1'b1) begin //set by the bootloader
                cpu_bldr_ctrl_state <= CPU_BLDR_CTRL_DONE;
                wb_rst <= 1'b1;
             end
          end
	  
          CPU_BLDR_CTRL_DONE: begin //stay here forever
             wb_rst <= 1'b0;
          end
	  
        endcase //cpu_bldr_ctrl_state
     end
   
   // /////////////////////////////////////////////////////////////////////////
   // Processor

   assign 	 bus_error = m0_err | m0_rty;

   wire [63:0] zpu_status;
   zpu_wb_top #(.dat_w(dw), .adr_w(aw), .sel_w(sw))
     zpu_top0 (.clk(wb_clk), .rst(wb_rst), .enb(~wb_rst),
	   // Data Wishbone bus to system bus fabric
	   .we_o(m0_we),.stb_o(m0_stb),.dat_o(m0_dat_i),.adr_o(cpu_adr),
	   .dat_i(m0_dat_o),.ack_i(m0_ack),.sel_o(m0_sel),.cyc_o(m0_cyc),
	   // Interrupts and exceptions
	   .zpu_status(zpu_status), .interrupt(proc_int & 1'b0));
   
   // /////////////////////////////////////////////////////////////////////////
   // Dual Ported Boot RAM -- D-Port is Slave #0 on main Wishbone
   // Dual Ported Main RAM -- D-Port is Slave #F on main Wishbone
   // I-port connects directly to processor

   bootram bootram(.clk(wb_clk), .reset(wb_rst),
		   .if_adr(14'b0), .if_data(),
		   .dwb_adr_i(sf_adr[13:0]), .dwb_dat_i(sf_dat_o), .dwb_dat_o(sf_dat_i),
		   .dwb_we_i(sf_we), .dwb_ack_o(sf_ack), .dwb_stb_i(sf_stb), .dwb_sel_i(sf_sel));

////blinkenlights v0.1
//defparam bootram.RAM0.INIT_00=256'hbc32fff0_aa43502b_b00000fe_30630001_80000000_10600000_a48500ff_10a00000;
//defparam bootram.RAM0.INIT_01=256'ha48500ff_b810ffd0_f880200c_30a50001_10830000_308000ff_be23000c_a4640001;

`include "bootloader_umtrx.rmi"

   ram_harvard2 #(.AWIDTH(14),.RAM_SIZE(16384))
   sys_ram(.wb_clk_i(wb_clk),.wb_rst_i(wb_rst),	     
	   .if_adr(14'b0), .if_data(),
	   .dwb_adr_i(s0_adr[13:0]), .dwb_dat_i(s0_dat_o), .dwb_dat_o(s0_dat_i),
	   .dwb_we_i(s0_we), .dwb_ack_o(s0_ack), .dwb_stb_i(s0_stb), .dwb_sel_i(s0_sel));
   
   // /////////////////////////////////////////////////////////////////////////
   // Buffer Pool, slave #1
   wire 	 rd0_ready_i, rd0_ready_o;
   wire 	 rd1_ready_i, rd1_ready_o;
   wire 	 rd1_ready_i_1, rd1_ready_o_1;
   wire 	 rd2_ready_i, rd2_ready_o;
   wire 	 rd3_ready_i, rd3_ready_o;
   wire [35:0] 	 rd0_dat, rd1_dat, rd2_dat, rd3_dat;

   wire 	 wr0_ready_i, wr0_ready_o;
   wire 	 wr1_ready_i, wr1_ready_o;
   wire 	 wr2_ready_i, wr2_ready_o;
   wire 	 wr3_ready_i, wr3_ready_o;
   wire [35:0] 	 wr0_dat, wr1_dat, wr2_dat, wr3_dat;

   wire [35:0] 	 tx_err_data;
   wire 	 tx_err_src_rdy, tx_err_dst_rdy;
   wire [35:0] 	 tx1_err_data;
   wire 	 tx1_err_src_rdy, tx1_err_dst_rdy;

   wire [31:0] router_debug;

   packet_router #(.BUF_SIZE(9), .UDP_BASE(SR_UDP_SM), .CTRL_BASE(SR_BUF_POOL)) packet_router
     (.wb_clk_i(wb_clk),.wb_rst_i(wb_rst),
      .wb_we_i(s1_we),.wb_stb_i(s1_stb),.wb_adr_i(s1_adr),.wb_dat_i(s1_dat_o),
      .wb_dat_o(s1_dat_i),.wb_ack_o(s1_ack),.wb_err_o(),.wb_rty_o(),

      .set_stb(set_stb_sys), .set_addr(set_addr_sys), .set_data(set_data_sys),

      .stream_clk(sys_clk), .stream_rst(sys_rst), .stream_clr(1'b0),

      .status(status), .sys_int_o(buffer_int), .debug(router_debug),

      .ser_inp_data(wr0_dat), .ser_inp_valid(wr0_ready_i), .ser_inp_ready(wr0_ready_o),
      .dsp0_inp_data(wr1_dat), .dsp0_inp_valid(wr1_ready_i), .dsp0_inp_ready(wr1_ready_o),
      .dsp1_inp_data(wr3_dat), .dsp1_inp_valid(wr3_ready_i), .dsp1_inp_ready(wr3_ready_o),
      .eth_inp_data(wr2_dat), .eth_inp_valid(wr2_ready_i), .eth_inp_ready(wr2_ready_o),
      .err_inp_data(tx_err_data), .err_inp_ready(tx_err_dst_rdy), .err_inp_valid(tx_err_src_rdy),

      .ser_out_data(rd0_dat), .ser_out_valid(rd0_ready_o), .ser_out_ready(rd0_ready_i),
      .dsp_out_data(rd1_dat), .dsp_out_valid(rd1_ready_o), .dsp_out_ready(rd1_ready_i),
      .dsp1_out_valid(rd1_ready_o_1), .dsp1_out_ready(rd1_ready_i_1),
      .err_inp1_data(tx1_err_data), .err_inp1_ready(tx1_err_dst_rdy), .err_inp1_valid(tx1_err_src_rdy),
      .eth_out_data(rd2_dat), .eth_out_valid(rd2_ready_o), .eth_out_ready(rd2_ready_i)
      );

   // /////////////////////////////////////////////////////////////////////////
   // SPI -- Slave #2
   spi_top shared_spi
     (.wb_clk_i(wb_clk),.wb_rst_i(wb_rst),.wb_adr_i(s2_adr[4:0]),.wb_dat_i(s2_dat_o),
      .wb_dat_o(s2_dat_i),.wb_sel_i(s2_sel),.wb_we_i(s2_we),.wb_stb_i(s2_stb),
      .wb_cyc_i(s2_cyc),.wb_ack_o(s2_ack),.wb_err_o(),.wb_int_o(spi_int),
      .ss_pad_o({aux_sen2,aux_sen1,sen_dac,sen_lms2,sen_lms1}),
      .sclk_pad_o(sclk),.mosi_pad_o(mosi),.miso_pad_i(miso) );

   // /////////////////////////////////////////////////////////////////////////
   // I2C -- Slave #3
   i2c_master_top #(.ARST_LVL(1)) 
     i2c (.wb_clk_i(wb_clk),.wb_rst_i(wb_rst),.arst_i(1'b0), 
	  .wb_adr_i(s3_adr[4:2]),.wb_dat_i(s3_dat_o[7:0]),.wb_dat_o(s3_dat_i[7:0]),
	  .wb_we_i(s3_we),.wb_stb_i(s3_stb),.wb_cyc_i(s3_cyc),
	  .wb_ack_o(s3_ack),.wb_inta_o(i2c_int),
	  .scl_pad_i(scl_pad_i),.scl_pad_o(scl_pad_o),.scl_padoen_o(scl_pad_oen_o),
	  .sda_pad_i(sda_pad_i),.sda_pad_o(sda_pad_o),.sda_padoen_o(sda_pad_oen_o) );
     
   i2c_master_top #(.ARST_LVL(1)) 
     aux_i2c (.wb_clk_i(wb_clk),.wb_rst_i(wb_rst),.arst_i(1'b0), 
	  .wb_adr_i(s9_adr[4:2]),.wb_dat_i(s9_dat_o[7:0]),.wb_dat_o(s9_dat_i[7:0]),
	  .wb_we_i(s9_we),.wb_stb_i(s9_stb),.wb_cyc_i(s9_cyc),
	  .wb_ack_o(s9_ack),.wb_inta_o(aux_i2c_int),
	  .scl_pad_i(aux_scl_pad_i),.scl_pad_o(aux_scl_pad_o),.scl_padoen_o(aux_scl_pad_oen_o),
	  .sda_pad_i(aux_sda_pad_i),.sda_pad_o(aux_sda_pad_o),.sda_padoen_o(aux_sda_pad_oen_o) );

   assign 	 s3_dat_i[31:8] = 24'd0;
   assign 	 s9_dat_i[31:8] = 24'd0;
   
   // /////////////////////////////////////////////////////////////////////////
   // GPIOs

   wire [31:0] gpio_readback;
   
   gpio_atr #(.BASE(SR_GPIO), .WIDTH(32)) 
   gpio_atr(.clk(dsp_clk),.reset(dsp_rst),
	    .set_stb(set_stb_dsp),.set_addr(set_addr_dsp),.set_data(set_data_dsp),
	    .rx(run_rx0 | run_rx1), .tx(run_tx0 | run_tx1),
	    .gpio({io_tx,io_rx}), .gpio_readback(gpio_readback) );

   // /////////////////////////////////////////////////////////////////////////
   // Buffer Pool Status -- Slave #5   
   
   //compatibility number -> increment when the fpga has been sufficiently altered
   localparam compat_num = {16'd8, 16'd2}; //major, minor

   wb_readback_mux buff_pool_status
     (.wb_clk_i(wb_clk), .wb_rst_i(wb_rst), .wb_stb_i(s5_stb),
      .wb_adr_i(s5_adr), .wb_dat_o(s5_dat_i), .wb_ack_o(s5_ack),

      .word00(32'b0),.word01(32'b0),.word02(32'b0),.word03(32'b0),
      .word04(32'b0),.word05(32'b0),.word06({adc0_a, 4'b0, adc0_b, 4'b0}),.word07({adc1_a, 4'b0, adc1_b, 4'b0}),
      .word08(status),.word09(gpio_readback),.word10(vita_time[63:32]),
      .word11(vita_time[31:0]),.word12(compat_num),.word13({16'b0, aux_ld2, aux_ld1, button, 1'b0, clk_status, 1'b0, 10'b0}),
      .word14(vita_time_pps[63:32]),.word15(vita_time_pps[31:0])
      );

   // /////////////////////////////////////////////////////////////////////////
   // Ethernet MAC  Slave #6

   simple_gemac_wrapper #(.RXFIFOSIZE(ETH_RX_FIFOSIZE), 
			  .TXFIFOSIZE(ETH_TX_FIFOSIZE)) simple_gemac_wrapper
     (.clk125(clk_to_mac),  .reset(wb_rst),
      .GMII_GTX_CLK(GMII_GTX_CLK), .GMII_TX_EN(GMII_TX_EN),  
      .GMII_TX_ER(GMII_TX_ER), .GMII_TXD(GMII_TXD),
      .GMII_RX_CLK(GMII_RX_CLK), .GMII_RX_DV(GMII_RX_DV),  
      .GMII_RX_ER(GMII_RX_ER), .GMII_RXD(GMII_RXD),
      .sys_clk(sys_clk),
      .rx_f36_data(wr2_dat), .rx_f36_src_rdy(wr2_ready_i), .rx_f36_dst_rdy(wr2_ready_o),
      .tx_f36_data(rd2_dat), .tx_f36_src_rdy(rd2_ready_o), .tx_f36_dst_rdy(rd2_ready_i),
      .wb_clk(wb_clk), .wb_rst(wb_rst), .wb_stb(s6_stb), .wb_cyc(s6_cyc), .wb_ack(s6_ack),
      .wb_we(s6_we), .wb_adr(s6_adr), .wb_dat_i(s6_dat_o), .wb_dat_o(s6_dat_i),
      .mdio(MDIO), .mdc(MDC),
      .debug(debug_mac));

   // /////////////////////////////////////////////////////////////////////////
   // Settings Bus -- Slave #7
   settings_bus settings_bus
     (.wb_clk(wb_clk),.wb_rst(wb_rst),.wb_adr_i(s7_adr),.wb_dat_i(s7_dat_o),
      .wb_stb_i(s7_stb),.wb_we_i(s7_we),.wb_ack_o(s7_ack),
      .strobe(set_stb),.addr(set_addr),.data(set_data));
   
   assign 	 s7_dat_i = 32'd0;

   settings_bus_crossclock settings_bus_dsp_crossclock
     (.clk_i(wb_clk), .rst_i(wb_rst), .set_stb_i(set_stb), .set_addr_i(set_addr), .set_data_i(set_data),
      .clk_o(dsp_clk), .rst_o(dsp_rst), .set_stb_o(set_stb_dsp), .set_addr_o(set_addr_dsp), .set_data_o(set_data_dsp));

   settings_bus_crossclock settings_bus_sys_crossclock
     (.clk_i(wb_clk), .rst_i(wb_rst), .set_stb_i(set_stb), .set_addr_i(set_addr), .set_data_i(set_data),
      .clk_o(sys_clk), .rst_o(sys_rst), .set_stb_o(set_stb_sys), .set_addr_o(set_addr_sys), .set_data_o(set_data_sys));

   settings_bus_crossclock settings_bus_fe_crossclock
     (.clk_i(wb_clk), .rst_i(wb_rst), .set_stb_i(set_stb), .set_addr_i(set_addr), .set_data_i(set_data),
      .clk_o(fe_clk), .rst_o(fe_rst), .set_stb_o(set_stb_fe), .set_addr_o(set_addr_fe), .set_data_o(set_data_fe));

   // Output control lines
   wire [7:0] 	 clock_outs, adc_outs;
   assign 	 {clock_ready, clk_en[1:0], clk_sel[1:0]} = clock_outs[4:0];
   assign lms_res = clock_outs[6:5];
   assign 	 {adc_oe_a, adc_on_a, adc_oe_b, adc_on_b } = adc_outs[3:0];

   wire 	 phy_reset;
   assign 	 PHY_RESETn = ~phy_reset;
   
   setting_reg #(.my_addr(SR_MISC+0),.width(8)) sr_clk
     (.clk(wb_clk),.rst(wb_rst),.strobe(s7_ack),.addr(set_addr),.in(set_data),.out(clock_outs),.changed());

   setting_reg #(.my_addr(SR_MISC+2),.width(8)) sr_adc
     (.clk(dsp_clk),.rst(dsp_rst),.strobe(set_stb_dsp),.addr(set_addr_dsp),.in(set_data_dsp),.out(adc_outs),.changed());

   setting_reg #(.my_addr(SR_MISC+4),.width(1)) sr_phy
     (.clk(wb_clk),.rst(wb_rst),.strobe(set_stb),.addr(set_addr),.in(set_data),.out(phy_reset),.changed());

   setting_reg #(.my_addr(SR_MISC+5),.width(1)) sr_bld
     (.clk(wb_clk),.rst(wb_rst),.strobe(set_stb),.addr(set_addr),.in(set_data),.out(bldr_done),.changed());

   // Diversity switches
   setting_reg #(.my_addr(SR_DIVSW+0),.width(1), .at_reset(32'd1)) sr_divsw1
     (.clk(wb_clk),.rst(wb_rst),.strobe(set_stb),.addr(set_addr),.in(set_data),.out(DivSw1),.changed());

   setting_reg #(.my_addr(SR_DIVSW+1),.width(1), .at_reset(32'd1)) sr_divsw2
     (.clk(wb_clk),.rst(wb_rst),.strobe(set_stb),.addr(set_addr),.in(set_data),.out(DivSw2),.changed());

  wire [31:0] testsig0;
  setting_reg #(.my_addr(SR_TESTSIG+0),.width(32)) sr_testsig0
     (.clk(wb_clk),.rst(wb_rst),.strobe(set_stb),.addr(set_addr),.in(set_data),.out(testsig0),.changed());

  wire [31:0] testsig1;
  setting_reg #(.my_addr(SR_TESTSIG+1),.width(32)) sr_testsig1
     (.clk(wb_clk),.rst(wb_rst),.strobe(set_stb),.addr(set_addr),.in(set_data),.out(testsig1),.changed());

   // /////////////////////////////////////////////////////////////////////////
   //  LEDS
   //    register 8 determines whether leds are controlled by SW or not
   //    1 = controlled by HW, 0 = by SW
   //    In Rev3 there are only 6 leds, and the highest one is on the ETH connector

    //FIXME
    assign run_tx0_mux = run_tx0;
    assign run_rx0_mux = run_rx0;
    assign run_tx1_mux = run_tx1;
    assign run_rx1_mux = run_rx1;

   wire [7:0] 	 led_src, led_sw;
   wire [7:0] 	 led_hw = {run_tx0_mux, run_rx0_mux, run_tx1_mux, run_rx1_mux, 1'b0};
   
   setting_reg #(.my_addr(SR_MISC+3),.width(8)) sr_led
     (.clk(wb_clk),.rst(wb_rst),.strobe(set_stb),.addr(set_addr),.in(set_data),.out(led_sw),.changed());

   setting_reg #(.my_addr(SR_MISC+6),.width(8), .at_reset(8'b0001_1110)) sr_led_src
     (.clk(wb_clk),.rst(wb_rst),.strobe(set_stb),.addr(set_addr),.in(set_data),.out(led_src),.changed());

   assign 	 leds = (led_src & led_hw) | (~led_src & led_sw);

   // /////////////////////////////////////////////////////////////////////////
   // GPSDO unit

   wire gpsdo_int;

   gpsdo gpsdo(
      .pps_in(pps_in),
      .clk_in(wb_clk),
      .wb_adr_i(s4_adr[4:2]),
      .wb_dat_i(s4_dat_o),
      .wb_dat_o(s4_dat_i),
      .wb_we_i(s4_we),
      .wb_stb_i(s4_stb),
      .wb_cyc_i(s4_cyc),
      .wb_ack_o(s4_ack),
      .wb_err_o(s4_err),
      .wb_int_o(gpsdo_int),
      .wb_clk_i(wb_clk),
      .wb_rst_i(wb_rst)
   );
 
   // /////////////////////////////////////////////////////////////////////////
   // Interrupt Controller, Slave #8

   assign irq= {{8'b0},
		{uart_tx_int[3:0], uart_rx_int[3:0]},
		{4'b0, clk_status, 3'b0},
		{2'b0,aux_i2c_int, PHY_INTn, i2c_int,spi_int,gpsdo_int,1'b0}};
   
   pic pic(.clk_i(wb_clk),.rst_i(wb_rst),.cyc_i(s8_cyc),.stb_i(s8_stb),.adr_i(s8_adr[4:2]),
	   .we_i(s8_we),.dat_i(s8_dat_o),.dat_o(s8_dat_i),.ack_o(s8_ack),.int_o(proc_int),
	   .irq(irq) );
 	 
   // /////////////////////////////////////////////////////////////////////////
   // UART, Slave #10

   quad_uart #(.TXDEPTH(3),.RXDEPTH(3)) uart  // depth of 3 is 128 entries
     (.clk_i(wb_clk),.rst_i(wb_rst),
      .we_i(sa_we),.stb_i(sa_stb),.cyc_i(sa_cyc),.ack_o(sa_ack),
      .adr_i(sa_adr[6:2]),.dat_i(sa_dat_o),.dat_o(sa_dat_i),
      .rx_int_o(uart_rx_int),.tx_int_o(uart_tx_int),
      .tx_o(uart_tx_o),.rx_i(uart_rx_i),.baud_o(uart_baud_o));
   // /////////////////////////////////////////////////////////////////////////
   // ICAP for reprogramming the FPGA, Slave #13 (D)

   s6_icap_wb s6_icap_wb
     (.clk(wb_clk), .clk_icap(clk_icap),.reset(wb_rst), .cyc_i(sd_cyc), .stb_i(sd_stb),
      .we_i(sd_we), .ack_o(sd_ack), .dat_i(sd_dat_o), .dat_o(sd_dat_i));
   
   // /////////////////////////////////////////////////////////////////////////
   // SPI for Flash -- Slave #14 (E)
   spi_top flash_spi
     (.wb_clk_i(wb_clk),.wb_rst_i(wb_rst),.wb_adr_i(se_adr[4:0]),.wb_dat_i(se_dat_o),
      .wb_dat_o(se_dat_i),.wb_sel_i(se_sel),.wb_we_i(se_we),.wb_stb_i(se_stb),
      .wb_cyc_i(se_cyc),.wb_ack_o(se_ack),.wb_err_o(se_err),.wb_int_o(spiflash_int),
      .ss_pad_o(spiflash_cs),
      .sclk_pad_o(spiflash_clk),.mosi_pad_o(spiflash_mosi),.miso_pad_i(spiflash_miso) );

   // /////////////////////////////////////////////////////////////////////////
   // RX chains

    umtrx_rx_chain
    #(
        .DSPNO(0),
        .FRONT_BASE(SR_RX_FRONT0),
        .DSP_BASE(SR_RX_DSP0),
        .CTRL_BASE(SR_RX_CTRL0),
        .FIFOSIZE(DSP_RX_FIFOSIZE)
    )
    umtrx_rx_chain0
    (
        .sys_clk(sys_clk), .sys_rst(sys_rst),
        .dsp_clk(dsp_clk), .dsp_rst(dsp_rst),
        .fe_clk(fe_clk), .fe_rst(fe_rst),
        .set_stb_dsp(set_stb_dsp), .set_addr_dsp(set_addr_dsp), .set_data_dsp(set_data_dsp),
        .adc_i(adc0_a), .adc_q(adc0_b), .adc_stb(adc0_strobe), .run(run_rx0),
        .vita_data_sys(wr1_dat), .vita_valid_sys(wr1_ready_i), .vita_ready_sys(wr1_ready_o),
        .vita_time(vita_time)
    );

    umtrx_rx_chain
    #(
        .DSPNO(1),
        .FRONT_BASE(SR_RX_FRONT1),
        .DSP_BASE(SR_RX_DSP1),
        .CTRL_BASE(SR_RX_CTRL1),
        .FIFOSIZE(DSP_RX_FIFOSIZE)
    )
    umtrx_rx_chain1
    (
        .sys_clk(sys_clk), .sys_rst(sys_rst),
        .dsp_clk(dsp_clk), .dsp_rst(dsp_rst),
        .fe_clk(fe_clk), .fe_rst(fe_rst),
        .set_stb_dsp(set_stb_dsp), .set_addr_dsp(set_addr_dsp), .set_data_dsp(set_data_dsp),
        .adc_i(adc1_a), .adc_q(adc1_b), .adc_stb(adc1_strobe), .run(run_rx1),
        .vita_data_sys(wr3_dat), .vita_valid_sys(wr3_ready_i), .vita_ready_sys(wr3_ready_o),
        .vita_time(vita_time)
    );

   // /////////////////////////////////////////////////////////////////////////
   // TX chains

    wire [35:0]          tx_data;
    wire         tx_src_rdy, tx_dst_rdy;
    wire [35:0]          tx_data_1;
    wire         tx_src_rdy_1, tx_dst_rdy_1;

    umtrx_tx_chain
    #(
        .DSPNO(0),
        .FRONT_BASE(SR_TX_FRONT0),
        .DSP_BASE(SR_TX_DSP0),
        .CTRL_BASE(SR_TX_CTRL0),
        .FIFOSIZE(DSP_TX_FIFOSIZE)
    )
    umtrx_tx_chain0
    (
        .sys_clk(sys_clk), .sys_rst(sys_rst),
        .dsp_clk(dsp_clk), .dsp_rst(dsp_rst),
        .fe_clk(fe_clk), .fe_rst(fe_rst),
        .set_stb_dsp(set_stb_dsp), .set_addr_dsp(set_addr_dsp), .set_data_dsp(set_data_dsp),
        .dac_i(dac0_a), .dac_q(dac0_b), .dac_stb(dac0_strobe), .run(run_tx0),
        .vita_data_sys(tx_data), .vita_valid_sys(tx_src_rdy), .vita_ready_sys(tx_dst_rdy),
        .err_data_sys(tx_err_data), .err_valid_sys(tx_err_src_rdy), .err_ready_sys(tx_err_dst_rdy),
        .vita_time(vita_time)
    );

    umtrx_tx_chain
    #(
        .DSPNO(1),
        .FRONT_BASE(SR_TX_FRONT1),
        .DSP_BASE(SR_TX_DSP1),
        .CTRL_BASE(SR_TX_CTRL1),
        .FIFOSIZE(DSP_TX_FIFOSIZE)
    )
    umtrx_tx_chain1
    (
        .sys_clk(sys_clk), .sys_rst(sys_rst),
        .dsp_clk(dsp_clk), .dsp_rst(dsp_rst),
        .fe_clk(fe_clk), .fe_rst(fe_rst),
        .set_stb_dsp(set_stb_dsp), .set_addr_dsp(set_addr_dsp), .set_data_dsp(set_data_dsp),
        .dac_i(dac1_a), .dac_q(dac1_b), .dac_stb(dac1_strobe), .run(run_tx1),
        .vita_data_sys(tx_data_1), .vita_valid_sys(tx_src_rdy_1), .vita_ready_sys(tx_dst_rdy_1),
        .err_data_sys(tx1_err_data), .err_valid_sys(tx1_err_src_rdy), .err_ready_sys(tx1_err_dst_rdy),
        .vita_time(vita_time)
    );

   // ///////////////////////////////////////////////////////////////////////////////////
   // DSP TX

`ifndef NO_EXT_FIFO
   assign 	 RAM_A[20:19] = 2'b0;
`endif // !`ifndef NO_EXT_FIFO
   
   ext_fifo #(.EXT_WIDTH(36),.INT_WIDTH(36),.RAM_DEPTH(19),.FIFO_DEPTH(19)) 
     ext_fifo_i1
       (.int_clk(sys_clk),
	.ext_clk(sys_clk),
	.rst(sys_rst),
`ifndef NO_EXT_FIFO
	.RAM_D_pi(RAM_D_pi),
	.RAM_D_po(RAM_D_po),
	.RAM_D_poe(RAM_D_poe),
	.RAM_A(RAM_A[18:0]),
	.RAM_WEn(RAM_WEn),
	.RAM_CENn(RAM_CENn),
	.RAM_LDn(RAM_LDn),
	.RAM_OEn(RAM_OEn),
	.RAM_CE1n(RAM_CE1n),
`else
	.RAM_D_pi(),
	.RAM_D_po(),
	.RAM_D_poe(),
	.RAM_A(),
	.RAM_WEn(),
	.RAM_CENn(),
	.RAM_LDn(),
	.RAM_OEn(),
	.RAM_CE1n(),
`endif // !`ifndef NO_EXT_FIFO
	.datain(rd1_dat),
	.src_rdy_i(rd1_ready_o),
	.dst_rdy_o(rd1_ready_i),
	.dataout(tx_data),
	.src_rdy_o(tx_src_rdy),
	.dst_rdy_i(tx_dst_rdy),
	.src1_rdy_i(rd1_ready_o_1),
	.dst1_rdy_o(rd1_ready_i_1),
	.src1_rdy_o(tx_src_rdy_1),
	.dst1_rdy_i(tx_dst_rdy_1),
	.dataout_1(tx_data_1),
	.debug(debug_extfifo),
	.debug2(debug_extfifo2) );

   // ///////////////////////////////////////////////////////////////////////////////////
   // SERDES

    assign rd0_ready_i = 1; //null sink
    assign wr0_ready_i = 0;

   // /////////////////////////////////////////////////////////////////////////
   // VITA Timing

   time_64bit #(.BASE(SR_TIME64)) time_64bit
     (.clk(dsp_clk), .rst(dsp_rst), .set_stb(set_stb_dsp), .set_addr(set_addr_dsp), .set_data(set_data_dsp),
      .pps(pps_in), .vita_time(vita_time), .vita_time_pps(vita_time_pps), .pps_int(pps_int));

   // /////////////////////////////////////////////////////////////////////////////////////////
   // Debug Pins
  
   assign debug_clk = 2'b00; // {dsp_clk, clk_to_mac};
   assign debug = 32'd0;
   assign debug_gpio_0 = 32'd0;
   assign debug_gpio_1 = 32'd0;
   
endmodule // u2_core
