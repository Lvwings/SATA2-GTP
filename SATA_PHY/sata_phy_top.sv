`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/08/27 13:42:01
// Design Name: 
// Module Name: sata_phy_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module sata_phy_top#(
    parameter   SATA_VERSION            =   2,
    parameter   SATA_GEN1_COMRESET      =   155,
    parameter   SATA_GEN1_COMWAKE       =   49,
    parameter   SATA_TYPE               =   0   //  1 for host, 0 for device    
    )
(
    input           sys_clk,        //  150 Mhz - from tx_user_clk
    input           sys_rst,
    input           test_port_n,

    //  reset done signal
    input           gt_tx_reset_done_in,
    input           gt_rx_reset_done_in,

    input           gt_tx_pll_lock_in,
    input           gt_rx_pll_lock_in,

    //  OOB signal
    input           rx_comwake_in,
    input           rx_cominit_in,
    input           rx_elecidle_in,
    output          rx_cdrhold_out,
    output          rx_pcsreset_out,
    
    output          tx_comwake_out,
    output          tx_cominit_out,
    output          tx_elecidle_out,
    input           tx_comfinish_in,

    //  DRP

    output  [8:0]   drpaddr_out,
    output  [15:0]  drpdi_out  ,
    input   [15:0]  drpdo_in   ,
    output          drpen_out  ,
    input           drprdy_in  ,
    output          drpwe_out  ,

    //  Data
    input   [31:0]  gt_rxdata_in,             //  GTP receive data
    input   [3:0]   gt_rxcharisk_in,
    
    output  [31:0]  phy_data_out,            //  GTP transmit data
    output  [3:0]   phy_charisk_out,         //  GTP data K/D

    output          phy_links_up_out,

    //  data from link layer
    input  [31:0]  link_data_in,
    input  [3:0]   link_charisk_in

    );

    wire    [31:0]  tx_data_out;
    wire    [3:0]   tx_charisk_out;
(* dont_touch="true" *)    wire            phy_reset_done_in;
(* dont_touch="true" *)    wire            phy_pll_lock_in;
(* dont_touch="true" *)    wire    [1:0]   sata_vesions;
    
    assign          phy_data_out    =   phy_links_up_out ? link_data_in : tx_data_out;
    assign          phy_charisk_out =   phy_links_up_out ? link_charisk_in : tx_charisk_out;
    assign          phy_reset_done_in   =   gt_rx_reset_done_in && gt_tx_reset_done_in;
    assign          phy_pll_lock_in =   gt_rx_pll_lock_in && gt_tx_pll_lock_in;


    generate
        if (SATA_TYPE) begin
            sata_oob #(
                    .SATA_VERSION(SATA_VERSION),
                    .SATA_GEN1_COMRESET(SATA_GEN1_COMRESET),
                    .SATA_GEN1_COMWAKE(SATA_GEN1_COMWAKE)
                ) inst_sata_oob_host (
                    .sys_clk           (sys_clk),
                    .sys_rst           (sys_rst),
                    .test_port_n       (test_port_n),
                    .sata_vesions      (SATA_VERSION),
                    .phy_pll_lock_in   (phy_pll_lock_in),
                    .phy_reset_done_in (phy_reset_done_in),
                    .rx_comwake_in     (rx_comwake_in),
                    .rx_cominit_in     (rx_cominit_in),
                    .rx_elecidle_in    (rx_elecidle_in),
                    .rx_cdrhold_out    (rx_cdrhold_out),
                    .rx_pcsreset_out   (rx_pcsreset_out),
                    .tx_comwake_out    (tx_comwake_out),
                    .tx_cominit_out    (tx_cominit_out),
                    .tx_elecidle_out   (tx_elecidle_out),
                    .tx_comfinish_in   (tx_comfinish_in),
                    .drpaddr_out       (drpaddr_out),
                    .drpdi_out         (drpdi_out),
                    .drpdo_in          (drpdo_in),
                    .drpen_out         (drpen_out),
                    .drprdy_in         (drprdy_in),
                    .drpwe_out         (drpwe_out),
                    .gt_rxdata_in      (gt_rxdata_in),
                    .gt_rxcharisk_in   (gt_rxcharisk_in),
                    .tx_data_out       (tx_data_out),
                    .tx_charisk_out    (tx_charisk_out),
                    .phy_links_up_out  (phy_links_up_out)
                );
        end
        else begin
            sata_oob_device #(
                    .SATA_VERSION(SATA_VERSION),
                    .SATA_GEN1_COMRESET(SATA_GEN1_COMRESET),
                    .SATA_GEN1_COMWAKE(SATA_GEN1_COMWAKE)
                ) inst_sata_oob_device (
                    .sys_clk           (sys_clk),
                    .sys_rst           (sys_rst),
                    .test_port_n       (test_port_n),
                    .sata_vesions      (SATA_VERSION),
                    .phy_pll_lock_in   (phy_pll_lock_in),
                    .phy_reset_done_in (phy_reset_done_in),
                    .rx_comwake_in     (rx_comwake_in),
                    .rx_cominit_in     (rx_cominit_in),
                    .rx_elecidle_in    (rx_elecidle_in),
                    .rx_cdrhold_out    (rx_cdrhold_out),
                    .rx_pcsreset_out   (rx_pcsreset_out),
                    .tx_comwake_out    (tx_comwake_out),
                    .tx_cominit_out    (tx_cominit_out),
                    .tx_elecidle_out   (tx_elecidle_out),
                    .tx_comfinish_in   (tx_comfinish_in),
                    .drpaddr_out       (drpaddr_out),
                    .drpdi_out         (drpdi_out),
                    .drpdo_in          (drpdo_in),
                    .drpen_out         (drpen_out),
                    .drprdy_in         (drprdy_in),
                    .drpwe_out         (drpwe_out),
                    .gt_rxdata_in      (gt_rxdata_in),
                    .gt_rxcharisk_in   (gt_rxcharisk_in),
                    .tx_data_out       (tx_data_out),
                    .tx_charisk_out    (tx_charisk_out),
                    .phy_links_up_out  (phy_links_up_out)
        );
        
        end
    endgenerate

/*
    sata_speed_negotiation inst_sata_speed_negotiation
        (
            .drp_clk           (sys_clk),
            .sys_rst           (sys_rst),
            .speed_neg_rst     (speed_neg_rst),
            .linkup            (phy_links_up_out),
            .drpaddr_out       (drpaddr_out),
            .drpen_out         (drpen_out),
            .drpdi_out         (drpdi_out),
            .drpdo_in          (drpdo_in),
            .drprdy_in         (drprdy_in),
            .drpwe_out         (drpwe_out),
            .phy_reset_done_in (phy_reset_done_in),
            .sata_vesions      (sata_vesions)
        );
*/

endmodule
