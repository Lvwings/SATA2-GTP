`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/10/08 14:02:56
// Design Name: 
// Module Name: sata_oob_device
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


module sata_oob_device#(
    parameter   SATA_VERSION            =   1,
    parameter   SATA_GEN1_COMRESET      =   155,
    parameter   SATA_GEN1_COMWAKE       =   49
    )
    (
    input           sys_clk,        //  75 Mhz - from tx_user_clk2
    input           sys_rst,
    input           test_port_n,
    input   [1:0]   sata_vesions, 

    //  reset done signal
    input           phy_pll_lock_in,
    input           phy_reset_done_in,

    //  OOB signal
    input           rx_comwake_in,
    input           rx_cominit_in,
    input           rx_elecidle_in,
    output          rx_cdrhold_out,
    output          rx_pcsreset_out,
    
    output          tx_comwake_out,
    output          tx_cominit_out,
    output          tx_elecidle_out,        //  high : forces GTPTXP and GTPTXN both to Common mode, creating an electrical idle signal
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
    
    output  [31:0]  tx_data_out,            //  GTP transmit data
    output  [3:0]   tx_charisk_out,         //  GTP data K/D

    output          phy_links_up_out
    );

 `include "Primitives.vh"
/*-----------------------------------------------------------------------------    
// state machine param
//---------------------------------------------------------------------------*/            

    typedef enum  reg [3:0] {
                HOST0_IDLE, 
                HOST1_COMINIT,
                HOST2_WAIT_COMWAKE,
                HOST2B_WAIT_NO_COMWAKE,
                HOST3_CALIBRATE,
                HOST4_COMWAKE,
                HOST5_SEND_ALIGN,
                HOST6_LINK_READY
    }  state_t;

(* dont_touch="true" *)    state_t oob_current_state,oob_next_state;


/******************************************************************************
// declaration
//****************************************************************************/            

always_ff @(posedge sys_clk) begin 
    if(sys_rst) begin
        oob_current_state <= HOST0_IDLE;
    end else begin
        oob_current_state <= oob_next_state;
    end
end

 /******************************************************************************
// JUMP
//****************************************************************************/            

          
(* dont_touch="true" *) reg     flag_oob_start          =   1'b0;
(* dont_touch="true" *) reg     flag_align_time_out     =   1'b0;
(* dont_touch="true" *) reg     flag_retry_time_out     =   1'b0;

(* dont_touch="true" *) reg     rx_cominit_detect       =   1'b0;
(* dont_touch="true" *) reg     rx_comwake_detect       =   1'b0;
(* dont_touch="true" *) reg     rx_elecidle_detect      =   1'b0;
(* dont_touch="true" *) reg     rx_align_detect         =   1'b0;

(* dont_touch="true" *) reg     flag_cominit_done      =   1'b0;   
(* dont_touch="true" *) reg     flag_comwkae_done       =   1'b0;    
(* dont_touch="true" *) reg     flag_no_comwake         =   1'b0;
/*------------------------------------------------------------------------------
--  OOB signal detect
------------------------------------------------------------------------------*/
always_ff @(posedge sys_clk) begin 
    if(sys_rst) begin
        rx_cominit_detect   <= 0;
        rx_comwake_detect   <= 0;
        rx_elecidle_detect  <= 0;
    end else begin
        rx_cominit_detect   <= rx_cominit_in;
        rx_comwake_detect   <= rx_comwake_in;
        rx_elecidle_detect  <= rx_elecidle_in;
    end
end

always_ff @(posedge sys_clk) begin
    if (sys_rst)
        rx_align_detect <=  0;
    else
        rx_align_detect <=  (gt_rxdata_in == `ALIGN && gt_rxcharisk_in == 4'b0001);
end
/*------------------------------------------------------------------------------
--  OOB comreset start
--  Used for start OOB session,
------------------------------------------------------------------------------*/      
always_ff @(posedge sys_clk) begin 
    if(sys_rst) begin
        flag_oob_start <= 0;
    end else begin
        flag_oob_start <= (test_port_n || rx_cominit_detect) && phy_reset_done_in && !phy_links_up_out;  //  phy_reset_done_in && !rx_cominit_detect
    end
end  

/*------------------------------------------------------------------------------
--  jump
------------------------------------------------------------------------------*/
always_comb begin 

    case (oob_current_state)
        HOST0_IDLE  : 
                    if (flag_oob_start)
                        oob_next_state  =   HOST1_COMINIT;
                    else
                        oob_next_state  =   HOST0_IDLE;                    

        HOST1_COMINIT   : 
                    if (flag_cominit_done && tx_comfinish_in)
                        oob_next_state  =   HOST2_WAIT_COMWAKE;
                    else
                        oob_next_state  =   HOST1_COMINIT;

        HOST2_WAIT_COMWAKE    : 
                    if (rx_comwake_detect)
                        oob_next_state  =   HOST2B_WAIT_NO_COMWAKE;
                    else if (flag_retry_time_out)
                        oob_next_state  =   HOST0_IDLE;
                    else
                        oob_next_state  =   HOST2_WAIT_COMWAKE;

        HOST2B_WAIT_NO_COMWAKE  : 
                    if (!flag_no_comwake)
                        oob_next_state  =   HOST3_CALIBRATE;
                    else
                        oob_next_state  =   HOST2B_WAIT_NO_COMWAKE;

        HOST3_CALIBRATE : 
                        oob_next_state  =   HOST4_COMWAKE;

        HOST4_COMWAKE   : 
                    if (flag_comwkae_done && tx_comfinish_in)
                        oob_next_state  =   HOST5_SEND_ALIGN;
                    else
                        oob_next_state  =   HOST4_COMWAKE;

        HOST5_SEND_ALIGN  : 
                    if (rx_align_detect)
                        oob_next_state  =   HOST6_LINK_READY;
                    else if (flag_align_time_out)
                        oob_next_state  =   HOST0_IDLE;
                    else
                        oob_next_state  =   HOST5_SEND_ALIGN;

        HOST6_LINK_READY    : 
                    if (rx_elecidle_detect)
                        oob_next_state  =   HOST0_IDLE;
                    else
                        oob_next_state  =   HOST6_LINK_READY;
    
        default :   oob_next_state  =   HOST0_IDLE;
    endcase
end

   
/******************************************************************************
// do
//****************************************************************************/           

/*------------------------------------------------------------------------------
--  transmit OOB COM 10 TIMES
--  COMRESET    :   [align(106.7ns) + space(320ns)] * 6 = 2560.2ns
--      SATA1   :   75MHz/2  * 97  =   2586ns
--      SATA2   :   150MHz/2 * 194 =   2586ns
--      SATA3   :   300MHz/2 * 388 =   2586ns
--  COMWAKE     :   [align(106.7ns) + space(106.7ns)] * 6 = 1280.4ns
--      SATA1   :   75MHz/2  * 49  =   1306ns
--      SATA2   :   150MHz/2 * 98  =   1306ns
--      SATA3   :   300MHz/2 * 196 =   1306ns
--  leave 1 clk ilde
------------------------------------------------------------------------------*/
wire    [9:0]   TIME_COMINIT;
wire    [9:0]   TIME_COMWAKE;
(* dont_touch="true" *) assign          TIME_COMINIT    =   SATA_GEN1_COMRESET   << (sata_vesions - 1);  //  81
(* dont_touch="true" *) assign          TIME_COMWAKE    =   SATA_GEN1_COMWAKE    << (sata_vesions - 1);  //  41
reg         [9:0]   tx_com_cnt      =   0;

(* dont_touch="true" *) reg                 tx_cmoreset_o   =   1'b0;
(* dont_touch="true" *) reg                 tx_comwake_o    =   1'b0;

assign  tx_cominit_out  =   tx_cmoreset_o;
assign  tx_comwake_out  =   tx_comwake_o;

always_ff @(posedge sys_clk) begin
    if(sys_rst) begin
        tx_com_cnt         <=  0;
        tx_cmoreset_o      <=  0;
        tx_comwake_o       <=  0;
        flag_cominit_done <=  0;
        flag_comwkae_done  <=  0;
    end else begin
        case (oob_next_state)
            HOST1_COMINIT  : begin
                if (tx_com_cnt == TIME_COMINIT) begin
                    tx_cmoreset_o       <=  0;
                    tx_com_cnt          <=  tx_com_cnt;
                    flag_cominit_done  <=  1;
                end
                else begin
                    tx_cmoreset_o       <=  1;
                    tx_com_cnt          <=  tx_com_cnt + 1;
                    flag_cominit_done  <=  0;
                end
            end // HOST1_COMRESET  

            HOST4_COMWAKE   : begin
                if (tx_com_cnt == TIME_COMWAKE) begin
                    tx_comwake_o        <=  0;
                    tx_com_cnt          <=  tx_com_cnt;
                    flag_comwkae_done   <=  1;
                end
                else begin
                    tx_comwake_o        <=  1;
                    tx_com_cnt          <=  tx_com_cnt + 1;
                    flag_comwkae_done   <=  0;
                end
            end // HOST4_COMWAKE   
            default : begin
                tx_com_cnt         <=  0;
                tx_cmoreset_o      <=  0;
                tx_comwake_o       <=  0;
                flag_cominit_done <=  0;
                flag_comwkae_done  <=  0;
            end // default 
        endcase
    end
end

/*------------------------------------------------------------------------------
--  Transfer ELECIDLE
--  ELECIDLE must be asserted during setup OOB link 
------------------------------------------------------------------------------*/
reg     tx_elecidle_o   =   1'b1;

assign  tx_elecidle_out =   tx_elecidle_o;

always_ff @(posedge sys_clk) begin 
    if(sys_rst) begin
       tx_elecidle_o  <= 1;
    end else begin
        case (oob_next_state)
            HOST5_SEND_ALIGN, HOST6_LINK_READY : begin
                tx_elecidle_o  <= 0;
            end // HOST5_SEND_ALIGN, HOST6_LINK_READY
            default : tx_elecidle_o  <= 1;
        endcase
    end
end

/*------------------------------------------------------------------------------
--  Trnasfer    CDRHOLD
--  CDRHOLD should be asserted before sending COMRESET 
--          and deasserted after RXELEIDLE deassert for 20 clk ( > 250 ns)
--      SATA1   :   75MHz/2  * 20  =   532ns
--      SATA2   :   150MHz/2 * 40  =   532ns
--      SATA3   :   300MHz/2 * 80  =   532ns
------------------------------------------------------------------------------*/
reg         rx_cdrhold_o    =   1'b1;

reg  [6:0]  cdrhold_cnt     =   0;
wire [6:0]  TIME_CDRLOD;
assign      TIME_CDRLOD     =   20 << (sata_vesions - 1); 

assign  rx_cdrhold_out  =   rx_cdrhold_o;

always_ff @(posedge sys_clk) begin 
    if(sys_rst) begin
       rx_cdrhold_o  <= 1;
       cdrhold_cnt   <= 0;
    end else begin
        case (oob_next_state)
            HOST5_SEND_ALIGN, HOST6_LINK_READY: begin
                if (cdrhold_cnt == TIME_CDRLOD) begin
                   cdrhold_cnt   <= cdrhold_cnt;
                   rx_cdrhold_o  <= 0;
                end
                else begin
                   cdrhold_cnt   <= cdrhold_cnt + 1;
                   rx_cdrhold_o  <= 1;                    
                end              
            end //
            default : begin
                rx_cdrhold_o  <= 1;
                cdrhold_cnt   <= 0;
            end // default 
        endcase
    end
end


/*------------------------------------------------------------------------------
--  transmit primitives
--  Used for HOST complete OOB session
------------------------------------------------------------------------------*/
(* dont_touch="true" *) reg [31:0]      tx_data_o       =   0;
(* dont_touch="true" *) reg [3:0]       tx_charisk_o    =   0;

assign  tx_data_out     =   tx_data_o;
assign  tx_charisk_out  =   tx_charisk_o;

reg [7:0]   d102_cnt    =   0;   

always_ff @(posedge sys_clk) begin 
    if(sys_rst) begin
        tx_data_o       <=  0;
        tx_charisk_o    <=  0;
        d102_cnt        <=  0; 
    end else begin
        case (oob_next_state)   

            HOST5_SEND_ALIGN : begin
                        tx_data_o       <=  `ALIGN;
                        tx_charisk_o    <=  4'b0001;                
            end // HOST7_ALIGN 

            HOST6_LINK_READY : begin
                        tx_data_o       <=  `R_RDY;
                        tx_charisk_o    <=  4'b0001;
            end // HOST8_LINK_READY 
            default : begin
                        tx_data_o       <=  0;
                        tx_charisk_o    <=  0; 
                        d102_cnt        <=  0; 
            end // default 
        endcase
    end
end


/*------------------------------------------------------------------------------
--  comwake wait
------------------------------------------------------------------------------*/
reg         [5:0]   no_comwake_cnt  =   0;
localparam  [5:0]   TIME_NO_COMWKAE =   6'h0F;

always_ff @(posedge sys_clk) begin
    if(sys_rst) begin
        no_comwake_cnt <= 0;
    end else begin
        case (oob_next_state)
            HOST2B_WAIT_NO_COMWAKE  : begin
                if (no_comwake_cnt == TIME_NO_COMWKAE) begin
                    flag_no_comwake <=  1;
                    no_comwake_cnt  <=  no_comwake_cnt;
                end
                else begin
                    flag_no_comwake <=  0;
                    if (!rx_comwake_detect)
                        no_comwake_cnt  <=  no_comwake_cnt + 1;
                    else
                        no_comwake_cnt  <=  0;
                end
            end // HOST2B_WAIT_NO_COMWAKE  
            default : begin
                    flag_no_comwake <=  0;
                    no_comwake_cnt  <=  0;               
            end // default 
        endcase
    end
end


/*------------------------------------------------------------------------------
--  align time out
--  Used to send COMRESET if ALIGN primitives are not detected within 54.6us.
--  SATA1 : 75MHz/2  * 2063  = 55us    
--  SATA2 : 150MHz/2 * 4126  = 55us
--  SATA3 : 300MHz/2 * 8252  = 55us
------------------------------------------------------------------------------*/   
wire  [13:0]    TIME_WAIT_ALIGN_55US;
assign          TIME_WAIT_ALIGN_55US    = 14'd2063 << (sata_vesions - 1);    
reg   [14:0]    align_wait_cnt          = 0;     

always_ff @(posedge sys_clk) begin 
    if(sys_rst) begin
        align_wait_cnt                  <=  0;
        flag_align_time_out             <=  0;
    end else begin
        case (oob_next_state)
            HOST5_SEND_ALIGN    : begin
                    align_wait_cnt      <=  align_wait_cnt + 1;
                    flag_align_time_out <=  (align_wait_cnt == TIME_WAIT_ALIGN_55US);
            end // HOST5_SEND_ALIGN    
            default : begin 
                    align_wait_cnt      <=  0;
                    flag_align_time_out <=  0;
            end // default 
        endcase
    end
end

/*------------------------------------------------------------------------------
--  retry time out
--  Used for async signal recovery (880 us)
--  SATA1 : 75MHz/2  * 33000  = 880us    
--  SATA2 : 150MHz/2 * 66000  = 880us
--  SATA3 : 300MHz/2 * 132000 = 880us
------------------------------------------------------------------------------*/   
wire  [19:0]    TIME_RETRY_880US;
assign          TIME_RETRY_880US        = 20'd33000 << (sata_vesions - 1);    
reg [19:0]      retry_cnt               = 0;     

always_ff @(posedge sys_clk) begin 
    if(sys_rst) begin
        retry_cnt  <=  0;
        flag_retry_time_out   <=  0;
    end else begin
        case (oob_next_state)
            HOST2_WAIT_COMWAKE    : begin
                    retry_cnt               <=  retry_cnt + 1;
                    flag_retry_time_out     <=  (retry_cnt == TIME_RETRY_880US);
            end // HOST2_WAIT_COMWAKE

            default : begin 
                    retry_cnt               <=  0;
                    flag_retry_time_out     <=  0;
            end // default 
        endcase
    end
end

/*------------------------------------------------------------------------------
--  phy link up
--  assert link up for furture logic used
------------------------------------------------------------------------------*/
(* dont_touch="true" *) reg       phy_links_up_o    =   1'b0;
assign  phy_links_up_out    =   phy_links_up_o; //  phy_links_up_o

always_ff @(posedge sys_clk) begin
     if(sys_rst) begin
        phy_links_up_o  <= 0;
     end else begin
        case (oob_next_state)
            HOST6_LINK_READY    : begin
                        phy_links_up_o  <=  1;
            end // HOST6_LINK_READY    
            default :   phy_links_up_o  <=  0;
        endcase
     end
 end 
 


/*------------------------------------------------------------------------------
--  Transfer    RXPCSRESET
--  RXPCSRESET  should be asserted when sending D10.2
------------------------------------------------------------------------------*/
reg         rx_pcsreset_o   =   1'b0;
reg         valid_one_clk   =   1'b1;   //  vaild for one clk
reg         drpdry_d        =   1'b0;

(* dont_touch="true" *) reg [8:0]   drpaddr_o       =   0;
(* dont_touch="true" *) reg [15:0]  drpdi_o         =   0;
(* dont_touch="true" *) reg [15:0]  drpdo_i         =   0;
(* dont_touch="true" *) reg         drpen_o         =   1'b0;
(* dont_touch="true" *) reg         drpwe_o         =   1'b0;

assign      drpaddr_out     =   drpaddr_o;
assign      drpdi_out       =   drpdi_o;
assign      drpen_out       =   drpen_o;
assign      drpwe_out       =   drpwe_o;

typedef enum  reg  [2:0] {DRP_IDLE,DRP_READ,DRP_WRITE,DRP_ASSERT_RESET,DRP_REWRITE,DRP_COMPLETE} state_d;
(* dont_touch="true" *) state_d drp_state;

localparam  DRP_PMA_ADDR        =   9'h011,
            DRP_PMA_ADDR_BIT11  =   16'hF7FF;   

assign  rx_pcsreset_out =   rx_pcsreset_o;

always_ff @(posedge sys_clk) begin 
    if(sys_rst) begin
       rx_pcsreset_o <= 0;
       drpaddr_o     <= 0;
       drpdi_o       <= 0;
       drpdo_i       <= 0;
       drpen_o       <= 1'b0;
       drpwe_o       <= 1'b0;  
       drp_state     <= DRP_IDLE; 
       valid_one_clk <= 1;  
       drpdry_d      <= 0;  
    end else begin
        case (oob_next_state)
            HOST5_SEND_ALIGN : begin
                drpdry_d      <= drprdy_in; 
                case (drp_state)
                    DRP_IDLE    :   begin
                        drp_state   <=  !rx_cdrhold_out ? DRP_READ : DRP_IDLE;
                    end // DRP_IDLE    

                    DRP_READ    :   begin
                        drpaddr_o   <=  DRP_PMA_ADDR;
                        
                        if (!drpdry_d && drprdy_in) begin
                            drpdo_i         <=  drpdo_in;
                            drp_state       <=  DRP_WRITE;
                            valid_one_clk   <=  1;
                        end
                        else begin
                            if (valid_one_clk) begin
                                drpen_o         <=  1;
                                valid_one_clk   <=  0;
                            end
                            else begin
                                drpen_o     <=  0;                                
                            end
                            drp_state   <=  DRP_READ;                            
                        end
                    end // DRP_READ    

                    DRP_WRITE   : begin
                        if (!drpdry_d && drprdy_in) begin
                            drp_state     <=  DRP_ASSERT_RESET;
                            valid_one_clk <=  1; 
                        end
                        else begin
                            if (valid_one_clk) begin
                                drpwe_o       <=  1;
                                drpen_o       <=  1;
                                drpdi_o       <=  drpdo_i & DRP_PMA_ADDR_BIT11;   //  set bit 11 to 0
                                valid_one_clk <=  0;
                            end
                            else begin
                                drpwe_o     <=  0;
                                drpen_o     <=  0;
                                drpdi_o     <=  0;                                 
                            end
                            drp_state   <=  DRP_WRITE;                             
                        end

                    end // DRP_WRITE  

                    DRP_ASSERT_RESET    : begin
                        rx_pcsreset_o   <=  1;

                        drp_state   <=  !phy_reset_done_in ? DRP_REWRITE : DRP_ASSERT_RESET;
                    end // DRP_ASSERT_RESET    
 
                    DRP_REWRITE : begin
                        if (!drpdry_d && drprdy_in) begin
                            drpaddr_o     <=  0;
                            drp_state     <=  DRP_COMPLETE;                        
                        end
                        else begin
                            if (valid_one_clk) begin
                                drpwe_o       <=  1;
                                drpen_o       <=  1;
                                drpdi_o       <=  drpdo_i;                     //  restore setting
                                valid_one_clk <=  0;
                            end
                            else begin
                                drpwe_o       <=  0;
                                drpen_o       <=  0;
                                drpdi_o       <=  0;                                                  
                            end
                            drp_state   <=  DRP_REWRITE; 
                        end
                    end // DRP_REWRITE 

                    DRP_COMPLETE    : begin
                        rx_pcsreset_o   <=  0;
                        valid_one_clk   <=  1;
                        drpaddr_o       <= 0;
                        drpdi_o         <= 0;
                        drpdo_i         <= 0;
                        drpen_o         <= 1'b0;
                        drpwe_o         <= 1'b0;                         
                        drp_state       <=  DRP_COMPLETE; 
                    end // DRP_COMPLETE    
                    default : begin
                       drpaddr_o     <= 0;
                       drpdi_o       <= 0;
                       drpdo_i       <= 0;
                       drpen_o       <= 1'b0;
                       drpwe_o       <= 1'b0; 
                       valid_one_clk <= 1;
                       drp_state     <= DRP_IDLE; 
                    end // default 
                endcase
            end
            default : begin
                rx_pcsreset_o <= 0;
                drpaddr_o     <= 0;
                drpdi_o       <= 0;
                drpdo_i       <= 0;
                drpen_o       <= 1'b0;
                drpwe_o       <= 1'b0;
                valid_one_clk <= 1; 
                drpdry_d      <= 0;
                drp_state     <= DRP_IDLE;                 
            end
        endcase
    end
end

endmodule
