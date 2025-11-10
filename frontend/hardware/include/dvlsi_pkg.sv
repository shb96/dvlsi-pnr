// Author : Seungheon Baek <qwdqwd00@g.skku.edu>

package dvlsi_pkg;

    `include "axi/typedef.svh"

    import riscv::*;
    import cva6_config_pkg::*;

    ///////////////////////////////////////////////////////////////
    //              Custom interface for tensor cores            //
    ///////////////////////////////////////////////////////////////
    
    typedef struct packed {
        // memory addresses
        logic [22:0] LHS_start_addr; // rs1
        logic [22:0] RHS_start_addr; // rs2
        logic [22:0] PSUM_start_addr; // r3
        // logic [63:0] DST_start_addr; // rd
        
        // tile dimensions
        logic [15:0] tM;
        logic [15:0] tK;
        logic [15:0] tN;
        
        // tile stride length
        logic [15:0] rs1_slen;
        logic [15:0] rs2_slen;
        logic [15:0] r3d_slen;

        logic        is_uint; // 0 : Not UINT input, 1 : UINT input
    } tmma_req_t;

    typedef struct packed {
        logic tensor_core_valid;
        tmma_req_t tmma_req;
    } tensor_core_req_t;

    typedef struct packed {
        logic tensor_core_ready;
        logic tensor_core_done;
    } tensor_core_resp_t;

    /////////////////////
    // 1. Parameters   //
    /////////////////////
    localparam logic [63:0] DRAMBase = 64'h0000_0010_0000_0000;
    localparam int unsigned AXI_ADDR_WIDTH = 64;
    localparam int unsigned AXI_DATA_WIDTH_64 = 64;
    localparam int unsigned AXI_STRB_WIDTH_64 = AXI_DATA_WIDTH_64/8;
    localparam int unsigned AXI_ID_WIDTH = 4;
    localparam int unsigned AXI_USER_WIDTH = 1;

    ////////////////////////
    // 2. Type Definition //
    ///////////////////////
    // type definition for AXI Channels
    typedef logic [AXI_ADDR_WIDTH-1      :0]        axi_addr_t;
    typedef logic [AXI_DATA_WIDTH_64-1   :0]        axi_data_64_t;
    typedef logic [AXI_STRB_WIDTH_64-1   :0]        axi_strb_64_t;
    typedef logic [AXI_ID_WIDTH-1        :0]        axi_id_t;
    typedef logic [AXI_ID_WIDTH-1        :0]        axi_id_cva6_t;
    typedef logic [AXI_USER_WIDTH-1      :0]        axi_user_t;

    ///////////////////////////
    // 3. Channel Definition //
    ///////////////////////////
    // CVA6 AXI Channel Definition (64b)
    `AXI_TYPEDEF_AW_CHAN_T (aw_chan_cva6_t, axi_addr_t, axi_id_cva6_t, axi_user_t)
    `AXI_TYPEDEF_W_CHAN_T  (w_chan_cva6_t, axi_data_64_t, axi_strb_64_t, axi_user_t)
    `AXI_TYPEDEF_B_CHAN_T  (b_chan_cva6_t, axi_id_cva6_t, axi_user_t)
    `AXI_TYPEDEF_AR_CHAN_T (ar_chan_cva6_t, axi_addr_t, axi_id_cva6_t, axi_user_t)
    `AXI_TYPEDEF_R_CHAN_T  (r_chan_cva6_t, axi_data_64_t, axi_id_cva6_t, axi_user_t)
    `AXI_TYPEDEF_REQ_T     (req_chan_cva6_t, aw_chan_cva6_t, w_chan_cva6_t, ar_chan_cva6_t)
    `AXI_TYPEDEF_RESP_T    (resp_chan_cva6_t, b_chan_cva6_t, r_chan_cva6_t)

endpackage : dvlsi_pkg