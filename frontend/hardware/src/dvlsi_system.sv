// Author : Seungheon Baek <qwdqwd00@g.skku.edu>
module dvlsi_system 
    import cva6_config_pkg::*;
    import riscv::*;
    import acc_pkg::*;
    import dvlsi_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = cva6_config_pkg::cva6_cfg
    // parameter int unsigned NR_CORES = 4
)(
    input logic clk_i,
    input logic rst_ni,
    /////////////////////////////
    //     Ports for AXI4      //
    /////////////////////////////
    output req_chan_cva6_t cva6_axi_req_o,
    input resp_chan_cva6_t cva6_axi_resp_i
);
    `include "axi/typedef.svh"

    cva6_to_acc_t acc_req;
    acc_to_cva6_t acc_resp;
    cva6 #(
        .CVA6Cfg(CVA6Cfg),
        .noc_req_t(req_chan_cva6_t),
        .noc_resp_t(resp_chan_cva6_t),
        .cvxif_req_t(acc_pkg::cva6_to_acc_t),
        .cvxif_resp_t(acc_pkg::acc_to_cva6_t)
    )cva6_inst(
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .boot_addr_i(DRAMBase),                 // boot address is set to 0x8000_0000
        .hart_id_i(64'h0),                      // hart id is set to 0(single core system)
        .irq_i('0),                             // not using asynchronous interrupt
        .ipi_i('0),                             // not using asynchronous inter-processor interrupt
        .time_irq_i('0),                        // not using asynchronous timer interrupt
        .debug_req_i('0),                       // not using asynchronous debug request
        .clic_irq_valid_i('0),                  // not using Clic(Client Local Interrupt Controller) interrupt
        .clic_irq_id_i('0),                     // not using Clic interrupt
        .clic_irq_level_i('0),                  // not using Clic interrupt
        .clic_irq_priv_i(riscv::PRIV_LVL_U),    // not using Clic interrupt, set to user mode
        .clic_irq_shv_i('0),                    // not using Clic interrupt
        .noc_req_o(cva6_axi_req_o),
        .noc_resp_i(cva6_axi_resp_i),

        // Interface with acc_orchestration
        .cvxif_req_o(acc_req),
        .cvxif_resp_i(acc_resp)
    );

    // No accelerator is connected
    always_comb begin
        acc_resp = '0;
    end


endmodule

