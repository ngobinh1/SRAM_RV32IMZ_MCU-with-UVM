`ifndef RISCV_DEFS_V
`define RISCV_DEFS_V

`define SATP_MODE_R   31
`define SATP_PPN_R    21:0

`define PRIV_USER     2'b00
`define PRIV_SUPER    2'b01
`define PRIV_MACHINE  2'b11

`define PAGE_PRESENT  0
`define PAGE_READ     1
`define PAGE_WRITE    2
`define PAGE_EXEC     3
`define PAGE_USER     4
`define PAGE_GLOBAL   5
`define PAGE_ACCESSED 6
`define PAGE_DIRTY    7

`define PAGE_PFN_SHIFT 10
`define MMU_PGSHIFT    12

`endif
