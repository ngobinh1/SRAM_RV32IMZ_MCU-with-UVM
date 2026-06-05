# Hướng dẫn chạy mô phỏng (How to Run)

## 1. Môi trường Windows (Manual)
Chạy trực tiếp các lệnh sau trong thư mục gốc của project (nơi có chứa file source) qua terminal của QuestaSim/ModelSim:
```bash
vlog *.v *.sv
vsim -voptargs="+acc" -c -do "run -all" tb_top +UVM_TESTNAME=riscv_full_test
```

## 2. Môi trường Linux (sử dụng Makefile)
Trong Linux, hệ thống đã được thiết lập sẵn Makefile, hỗ trợ việc build và chạy rất tiện lợi. Bạn có thể sử dụng các lệnh sau trong terminal:

- **Biên dịch mã nguồn (RTL):**
  ```bash
  make compile_rtl
  ```

- **Chạy Legacy Testbench (Không UVM):**
  ```bash
  make sim_legacy
  ```

- **Chạy UVM Testbench (Mặc định: riscv_full_test):**
  ```bash
  make sim_uvm
  ```

- **Chạy một UVM test cụ thể (VD: riscv_smode_mmu_random_test):**
  ```bash
  make sim_uvm TEST=riscv_smode_mmu_random_test
  ```

- **Chạy UVM test kèm giao diện GUI (Mở waveform):**
  ```bash
  make sim_uvm_gui TEST=riscv_mmu_test
  ```

- **Chạy toàn bộ Regression (tất cả UVM tests):**
  ```bash
  make regression
  ```

- **Dọn dẹp các tệp tạm / thư mục output:**
  ```bash
  make clean
  ```