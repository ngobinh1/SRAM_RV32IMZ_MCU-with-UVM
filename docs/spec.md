# 1. Tổng Quan Hệ Thống

## Mục tiêu thiết kế
Thiết kế một lõi vi xử lý (CPU core) dựa trên kiến trúc tập lệnh mở RISC-V, tối ưu hóa cho các hệ thống vi điều khiển (MCU) nhúng yêu cầu hiệu năng khá, tiết kiệm diện tích và có khả năng chạy hệ điều hành thời gian thực (RTOS). Mục tiêu là tạo ra một thiết kế ổn định, có thể kiểm chứng đầy đủ (fully verifiable) thông qua UVM, và dễ dàng tổng hợp trên FPGA hoặc ASIC.

## ISA hỗ trợ
- RV32I: Tập lệnh số nguyên cơ sở 32-bit.
- Zicsr: Mở rộng thanh ghi trạng thái và điều khiển (Control and Status Register).
- M: Mở rộng nhân chia số nguyên (Integer Multiplication and Division).

## Pipeline tổng thể
Thiết kế sử dụng pipeline 5 tầng (5-stage pipeline) cổ điển để cân bằng giữa tần số hoạt động (clock frequency) và độ phức tạp:
1. **IF** (Instruction Fetch): Lấy lệnh từ bộ nhớ lệnh (ICache/ITCM).
2. **ID** (Instruction Decode): Giải mã lệnh, đọc thanh ghi, sinh giá trị tức thời (immediate), và kiểm tra hazard.
3. **EX** (Execute): Thực thi các phép toán ALU, tính toán địa chỉ nhánh (branch), độ phân giải nhánh, và tính toán địa chỉ bộ nhớ (AGU).
4. **MEM** (Memory): Truy cập bộ nhớ dữ liệu (DCache/DTCM) cho các lệnh Load/Store.
5. **WB** (Writeback): Ghi kết quả tính toán hoặc dữ liệu đọc từ bộ nhớ trở lại tập thanh ghi (Register File).

## Datapath tổng thể
Datapath được thiết kế Single-Issue (phát hành đơn) và In-Order (thực thi tuần tự). Để tối ưu hóa đường trễ (critical path), các khối tính toán đặc biệt được tách rời:
- Dedicated Branch Comparator và Branch Adder được đặt tại tầng EX để quyết định nhánh sớm nhất có thể.
- AGU (Address Generation Unit) được tách biệt để tính địa chỉ truy xuất bộ nhớ.
- Multiply/Divide Unit được thiết kế đa chu kỳ (multi-cycle) và quản lý qua Scoreboard để không làm kẹt pipeline nếu không cần thiết.

## Triết lý thiết kế
- **Đơn giản là trên hết**: Ưu tiên tính đúng đắn và dễ kiểm chứng hơn là các tính năng dự đoán cực kỳ phức tạp (Out-of-Order).
- **Tối ưu hóa Critical Path**: Giảm thiểu độ sâu của mạch tổ hợp trong các giai đoạn EX và MEM bằng cách sử dụng các module chuyên biệt thay vì dùng chung ALU cho mọi thứ.
- **Tính mô-đun cao**: Các thành phần (Branch Predictor, ICache, DCache, ALU) được thiết kế thành các module độc lập với giao tiếp rõ ràng, cho phép thay thế hoặc nâng cấp mà không ảnh hưởng tới toàn hệ thống.

---

# 2. Sơ Đồ Pipeline

Pipeline được chia làm 5 tầng hoạt động song song.

## IF (Instruction Fetch)
- **Nhiệm vụ**: Cung cấp địa chỉ lệnh tiếp theo (PC), lấy lệnh từ bộ nhớ (ICache/ITCM), và dự đoán nhánh sơ bộ (Branch Prediction).
- **Dữ liệu đầu vào**: PC kế tiếp từ các nguồn (PC+4, Branch Target, Exception Target).
- **Dữ liệu đầu ra**: Instruction 32-bit, PC hiện tại, thông tin dự đoán nhánh (Predict Taken, Predict Target).
- **Module liên quan**: Fetch Unit, Branch Predictor, BTB, ICache / ITCM, Fetch Buffer.

## ID (Instruction Decode)
- **Nhiệm vụ**: Nhận lệnh từ IF, giải mã opcode, sinh tín hiệu điều khiển, đọc giá trị từ Register File, kiểm tra Scoreboard để phát hiện Hazard.
- **Dữ liệu đầu vào**: Instruction, PC, Predict Info từ IF. Ghi dữ liệu từ WB.
- **Dữ liệu đầu ra**: Opcode, Operand 1, Operand 2, Immediate, PC, thông tin điều khiển pipeline.
- **Module liên quan**: Decoder, Immediate Generator, Register File, Scoreboard, Issue Logic.

## EX (Execute)
- **Nhiệm vụ**: Thực hiện phép toán logic/số học, so sánh điều kiện nhánh, tính toán địa chỉ đích của nhánh, tính toán địa chỉ load/store.
- **Dữ liệu đầu vào**: Operands, Immediate, PC, Opcode từ ID. Forwarding data từ MEM/WB.
- **Dữ liệu đầu ra**: ALU Result, Branch Decision (Taken/Not Taken), Branch Target, Memory Address, Write Data (cho Store).
- **Module liên quan**: ALU, Dedicated Branch Unit, Dedicated Branch Comparator, Dedicated Branch Adder, AGU, LSU Front-End, Multiply Unit, Divide Unit, CSR Unit.

## MEM (Memory)
- **Nhiệm vụ**: Truy xuất bộ nhớ cho lệnh Load/Store hoặc đơn giản là truyền dữ liệu qua nếu không phải lệnh memory. Xử lý Exception liên quan đến bộ nhớ.
- **Dữ liệu đầu vào**: Memory Address, Write Data, Memory Control signals, ALU Result (cho forwarding/pass-through).
- **Dữ liệu đầu ra**: Load Data, Pass-through ALU Result, Exception Status.
- **Module liên quan**: LSU Back-End, MMU/PMP (nếu có), DCache / DTCM.

## WB (Writeback)
- **Nhiệm vụ**: Chọn dữ liệu từ ALU, Memory, hoặc CSR để ghi vào Register File. Cập nhật trạng thái hoàn thành lệnh (Retire).
- **Dữ liệu đầu vào**: Load Data, ALU Result, CSR Data, Destination Register ID.
- **Dữ liệu đầu ra**: Writeback Data, Register Write Enable.
- **Module liên quan**: Writeback Arbiter, Register File Writeback port.

---

# 3. Mối Quan Hệ Giữa Các Stage

## IF → ID
Truyền thông tin lệnh vừa lấy được để giải mã. Quá trình này thường đi qua một thanh ghi pipeline (IF/ID Register) hoặc Fetch Buffer.
Truyền:
- `instruction` [31:0]: Mã máy của lệnh.
- `pc` [31:0]: Program Counter của lệnh.
- `predict_taken` [0:0]: Báo cho ID biết lệnh này đã được dự đoán là rẽ nhánh.
- `predict_target` [31:0]: Đích dự đoán (để ID có thể kiểm tra hoặc chuyển tiếp cho EX).

## ID → EX
Truyền các toán hạng và tín hiệu điều khiển cần thiết để thực thi. (Qua ID/EX Register).
Truyền:
- `opcode_ctrl` [N:0]: Tín hiệu điều khiển cụ thể cho ALU, MUL/DIV, LSU.
- `rs1_data` [31:0]: Dữ liệu toán hạng 1.
- `rs2_data` [31:0]: Dữ liệu toán hạng 2.
- `imm` [31:0]: Dữ liệu tức thời đã mở rộng.
- `pc` [31:0]: Dùng để tính toán địa chỉ tương đối (như AUIPC, Branch).
- `rd_addr` [4:0]: Địa chỉ thanh ghi đích.
- `scoreboard_status`: Tín hiệu cho biết các resource có sẵn sàng không.

## EX → MEM
Chuyển kết quả thực thi hoặc yêu cầu truy cập bộ nhớ xuống tầng MEM. (Qua EX/MEM Register).
Truyền:
- `alu_result` [31:0]: Kết quả từ ALU/MUL/DIV (hoặc địa chỉ Load/Store từ AGU).
- `rs2_data` [31:0]: Dữ liệu cần ghi cho lệnh Store.
- `mem_req` [0:0]: Yêu cầu truy cập bộ nhớ.
- `mem_we` [0:0]: Yêu cầu ghi bộ nhớ.
- `mem_size` [1:0]: Kích thước truy cập (Byte, Half, Word).
- `rd_addr` [4:0]: Đích ghi (để pass tới WB).
- `branch_mispredict` [0:0]: Báo hiệu dự đoán sai để MEM báo cho Pipeline Controller flush các tầng trên.

## MEM → WB
Chuyển dữ liệu cuối cùng để ghi vào Register File. (Qua MEM/WB Register).
Truyền:
- `mem_rdata` [31:0]: Dữ liệu đọc từ bộ nhớ (đã được alignment và sign-extension).
- `alu_result` [31:0]: Kết quả ALU truyền qua.
- `wb_sel` [1:0]: Tín hiệu chọn nguồn ghi (MEM hay ALU hay CSR).
- `rd_addr` [4:0]: Đích ghi.
- `rd_wen` [0:0]: Cho phép ghi thanh ghi.
- `exception_status`: Thông tin lỗi bộ nhớ (Page Fault, Misaligned) để gửi tới Exception Controller.

---

# 4. Mô Tả Chi Tiết Từng Module

## Fetch Unit

### Chức Năng
Cung cấp PC tiếp theo, gửi yêu cầu đọc (read request) tới ICache/ITCM và nhận Instruction trả về.

### Bảng Tín Hiệu
| Signal | Dir | Width | Description |
| ------ | --- | ----- | ----------- |
| clk | in | 1 | Clock hệ thống |
| rst_n | in | 1 | Reset tích cực mức thấp |
| flush_req | in | 1 | Yêu cầu xóa pipeline từ Controller |
| flush_pc | in | 32 | PC mới do flush (branch taken/exception) |
| stall_req | in | 1 | Yêu cầu dừng lấy lệnh (stall) |
| predict_pc | in | 32 | PC dự đoán từ Branch Predictor |
| icache_req | out | 1 | Yêu cầu đọc ICache |
| icache_addr| out | 32 | Địa chỉ gửi tới ICache |
| icache_ack | in | 1 | Báo hiệu ICache đã nhận yêu cầu |
| icache_rdata| in | 32 | Dữ liệu trả về từ ICache |
| if_inst | out | 32 | Instruction xuất ra Fetch Buffer/ID |
| if_pc | out | 32 | PC của Instruction xuất ra |

### Nguyên Lý Hoạt Động
- **Nhận**: `flush_pc` (khi flush), `predict_pc` (khi hoạt động bình thường), `stall_req`.
- **Xử lý**: Lựa chọn PC tiếp theo (Mux). Nếu có `flush_req`, PC = `flush_pc`. Nếu không, PC = `predict_pc` (có thể là PC+4 hoặc Target). Gửi PC ra `icache_addr` cùng `icache_req`.
- **Trả về**: Đóng gói `icache_rdata` thành `if_inst` và truyền kèm `if_pc` xuống tầng dưới.

### Sơ Đồ Trạng Thái
Module này là một FSM đơn giản để giao tiếp với ICache.
```text
IDLE
 ↓ (icache_req)
WAIT_ACK
 ↓ (icache_ack)
DONE (Output Inst)
```
Nếu ICache là single-cycle SRAM, không cần FSM (luôn hit). FSM chỉ cần khi ICache có cache miss (trễ nhiều chu kỳ).

### Hazard / Exception Interaction
- **Stall**: Giữ nguyên giá trị PC hiện tại, không phát request mới.
- **Flush**: Hủy request hiện tại (nếu đang wait), cập nhật PC bằng `flush_pc`.
- **Exception**: Ghi nhận Instruction Access Fault nếu bộ nhớ trả về lỗi.

### Timing Considerations
- **Critical path**: Mux chọn PC -> Thanh ghi PC -> Địa chỉ ICache. Cần đảm bảo đường này cực ngắn.

---

## Branch Predictor

### Chức Năng
Dự đoán hướng rẽ (Taken/Not Taken) của lệnh Branch tĩnh/động trước khi giải mã để tránh stall pipeline.

### Bảng Tín Hiệu
| Signal | Dir | Width | Description |
| ------ | --- | ----- | ----------- |
| clk | in | 1 | |
| rst_n | in | 1 | |
| pc_in | in | 32 | PC hiện tại đang fetch |
| update_en | in | 1 | Tín hiệu cập nhật từ tầng EX |
| update_pc | in | 32 | PC của lệnh Branch cần cập nhật |
| update_taken| in | 1 | Kết quả rẽ nhánh thực sự (1=Taken) |
| pred_taken| out | 1 | Kết quả dự đoán cho `pc_in` |

### Nguyên Lý Hoạt Động
- **Nhận**: `pc_in` ở tầng IF, và thông tin `update_*` từ tầng EX khi một lệnh branch được resolve.
- **Xử lý**: Sử dụng Bimodal Predictor (Bảng BHT 2-bit saturating counter). Index bằng các bit thấp của PC.
- **Trả về**: Tín hiệu `pred_taken`. Nếu Taken, Fetch Unit sẽ dùng địa chỉ từ BTB.

### Sơ Đồ Trạng Thái
BHT Entry FSM (2-bit saturating counter):
```text
STRONGLY_NOT_TAKEN (00) <-> WEAKLY_NOT_TAKEN (01)
        ^                          ^
        |                          |
        v                          v
WEAKLY_TAKEN (10)       <-> STRONGLY_TAKEN (11)
```

### Hazard / Exception Interaction
- Cập nhật chỉ xảy ra khi có lệnh Branch thực sự hoàn thành, không bị flush bởi exception trước đó.

### Timing Considerations
- Tra cứu (Lookup) BHT phải diễn ra song song với ICache Read, sử dụng SRAM tĩnh hoặc thanh ghi flip-flop tốc độ cao.

---

## BTB (Branch Target Buffer)

### Chức Năng
Lưu trữ và cung cấp địa chỉ đích (Target Address) cho các lệnh nhánh đã được dự đoán là Taken.

### Bảng Tín Hiệu
| Signal | Dir | Width | Description |
| ------ | --- | ----- | ----------- |
| clk | in | 1 | |
| pc_in | in | 32 | |
| update_en | in | 1 | |
| update_pc | in | 32 | |
| update_target|in| 32 | Đích nhảy thực tế |
| target_out| out | 32 | Đích dự đoán trả về |
| hit | out | 1 | Báo hiệu PC có trong BTB |

### Nguyên Lý Hoạt Động
- Bộ nhớ Cache tổ chức dạng Direct Mapped hoặc Set-Associative. Chứa Tag (PC) và Data (Target PC).
- Khi IF cung cấp `pc_in`, BTB so sánh Tag, nếu trùng (`hit`=1) và Branch Predictor cho `pred_taken`=1, Target sẽ được dùng làm PC tiếp theo.
- Được cập nhật từ EX stage khi lệnh Branch hoặc Jump được tính toán xong đích đến.

### Sơ Đồ Trạng Thái
Không cần FSM. Hoạt động giống RAM Lookup thuần túy tổ hợp hoặc SRAM 1-cycle.

### Hazard / Exception Interaction
Flush không ảnh hưởng đến nội dung BTB.

### Timing Considerations
Mạch so sánh Tag của BTB nằm trên critical path của IF stage.

---

## ICache (Instruction Cache)

### Chức Năng
Lưu trữ đệm lệnh từ bộ nhớ chính (Main Memory/Flash) để cung cấp nhanh cho Fetch Unit.

### Bảng Tín Hiệu
| Signal | Dir | Width | Description |
| ------ | --- | ----- | ----------- |
| req | in | 1 | |
| addr | in | 32 | |
| ack | out | 1 | |
| rdata | out | 32 | |
| mem_* | in/out| ... | Giao tiếp AXI/AHB với Main Mem |

### Nguyên Lý Hoạt Động
- Tổ chức dạng Direct Mapped hoặc N-way Set Associative.
- Khi Cache Hit: Trả về lệnh trong 1 cycle.
- Khi Cache Miss: Giữ `ack` = 0, phát yêu cầu ra bộ nhớ ngoài, chờ dữ liệu fill vào Cache Line, sau đó trả lệnh cho Fetch Unit.

### Sơ Đồ Trạng Thái
```text
IDLE
 ↓ (req & miss)
MEM_READ_REQ
 ↓ (wait mem)
MEM_FILL
 ↓
DONE (Hit & trả data)
```

### Hazard / Exception Interaction
Nếu có ngắt hoặc flush trong lúc Cache Miss, Cache vẫn hoàn thành việc Fill (để tận dụng cho lần sau) nhưng Fetch Unit sẽ bỏ qua `rdata`.

### Timing Considerations
SRAM read delay là đường timing chính của ICache.

---

## Fetch Buffer

### Chức Năng
Hàng đợi (FIFO) nhỏ giữa IF và ID để tách rời (decouple) quá trình Fetch và Decode, giúp hấp thụ các độ trễ nhỏ của ICache.

### Bảng Tín Hiệu
| Signal | Dir | Width | Description |
| ------ | --- | ----- | ----------- |
| push_req | in | 1 | |
| push_data | in | 65 | {predict_taken, pc, inst} |
| pop_req | in | 1 | Từ ID stage |
| pop_data | out | 65 | |
| empty | out | 1 | |
| full | out | 1 | |

### Nguyên Lý Hoạt Động
- IF đẩy lệnh vào nếu chưa full.
- ID lấy lệnh ra nếu chưa empty.

### Sơ Đồ Trạng Thái
Không có FSM. Được thiết kế như một Circular FIFO.

### Hazard / Exception Interaction
Khi có `flush_req` từ Pipeline Controller, reset các pointer của FIFO về 0 (xóa sạch buffer).

### Timing Considerations
Giao tiếp FIFO đơn giản bằng RAM/Registers. Không gây áp lực lên critical path.

---

## Decoder

### Chức Năng
Phân tích 32-bit instruction để tạo ra các tín hiệu điều khiển cho các stage sau.

### Bảng Tín Hiệu
| Signal | Dir | Width | Description |
| ------ | --- | ----- | ----------- |
| inst | in | 32 | |
| alu_op | out | 5 | Mã phép toán ALU |
| branch_op | out | 3 | Mã loại Branch |
| mem_req | out | 1 | Yêu cầu load/store |
| mem_we | out | 1 | 1=Store, 0=Load |
| mem_size | out | 2 | Byte/Half/Word |
| wb_sel | out | 2 | Nguồn ghi writeback |
| is_muldiv | out | 1 | Lệnh M-extension |
| is_csr | out | 1 | Lệnh CSR |
| rs1_addr | out | 5 | Đọc Reg 1 |
| rs2_addr | out | 5 | Đọc Reg 2 |
| rd_addr | out | 5 | Ghi Reg |

### Nguyên Lý Hoạt Động
- Sử dụng bảng chân lý (Truth Table) kết hợp `opcode`, `funct3`, `funct7` để giải mã ra các nhóm lệnh.
- Không giữ trạng thái. Mọi tính toán diễn ra trong 1 chu kỳ clock bằng tổ hợp.

### Sơ Đồ Trạng Thái
Không có FSM.

### Hazard / Exception Interaction
Phát hiện lệnh không hợp lệ (Illegal Instruction) dựa trên opcode không tồn tại và báo Exception tới Controller.

### Timing Considerations
Giải mã hoàn toàn bằng mạch tổ hợp song song để giảm độ trễ tối đa.

---

## Immediate Generator

### Chức Năng
Trích xuất và mở rộng dấu (Sign-Extend) các bit tức thời (Immediate) từ lệnh dựa theo định dạng lệnh.

### Bảng Tín Hiệu
| Signal | Dir | Width | Description |
| ------ | --- | ----- | ----------- |
| inst | in | 32 | |
| imm_type | in | 3 | Tín hiệu từ Decoder báo loại lệnh |
| imm_out | out | 32 | Giá trị mở rộng 32-bit |

### Nguyên Lý Hoạt Động
- Multiplexer tổ hợp chọn các bit từ `inst` và ghép nối thành giá trị 32-bit, bit dấu (bit 31) luôn được copy ra các bit cao.
- **I-type**: `inst[31:20]`
- **S-type**: `inst[31:25], inst[11:7]`
- **B-type**: `inst[31], inst[7], inst[30:25], inst[11:8]`
- **U-type**: `inst[31:12], 12'b0`
- **J-type**: `inst[31], inst[19:12], inst[20], inst[30:21]`

### Sơ Đồ Trạng Thái
Không có FSM. Mạch tổ hợp thuần túy.

### Hazard / Exception Interaction
Không xử lý.

### Timing Considerations
Mạch Mux rất nhỏ, định tuyến trực tiếp từ thanh ghi lệnh.

---

## Register File

### Chức Năng
Chứa 32 thanh ghi số nguyên 32-bit (x0 tới x31), trong đó x0 luôn bằng 0. Hỗ trợ đọc song song 2 port và ghi 1 port.

### Bảng Tín Hiệu
| Signal | Dir | Width | Description |
| ------ | --- | ----- | ----------- |
| clk | in | 1 | |
| rs1_addr | in | 5 | |
| rs2_addr | in | 5 | |
| rd_addr | in | 5 | Từ WB stage |
| rd_data | in | 32 | Từ WB stage |
| rd_wen | in | 1 | Từ WB stage |
| rs1_data | out | 32 | |
| rs2_data | out | 32 | |

### Nguyên Lý Hoạt Động
- Cung cấp tính năng "Write-First" (Internal Forwarding): Nếu ghi và đọc cùng một thanh ghi trong cùng 1 chu kỳ, giá trị đọc sẽ là giá trị mới đang được ghi vào.

### Sơ Đồ Trạng Thái
Không có FSM.

### Hazard / Exception Interaction
Chỉ bị cập nhật khi WB có `rd_wen` hợp lệ (không bị exception/flush).

### Timing Considerations
Quá trình Read là Asynchronous (mạch tổ hợp), Write là Synchronous.

---

## Scoreboard

### Chức Năng
Theo dõi trạng thái của các thanh ghi để phát hiện Data Hazard (RAW) giữa lệnh đang Decode và các lệnh đang nằm ở EX, MEM, WB.

### Bảng Tín Hiệu
| Signal | Dir | Width | Description |
| ------ | --- | ----- | ----------- |
| clk | in | 1 | |
| rst_n | in | 1 | |
| id_rs1 | in | 5 | |
| id_rs2 | in | 5 | |
| ex_rd | in | 5 | |
| ex_wen | in | 1 | |
| mem_rd | in | 5 | |
| mem_wen | in | 1 | |
| wb_rd | in | 5 | |
| wb_wen | in | 1 | |
| mem_req_ex| in| 1 | Báo EX là lệnh Load |
| hazard_rs1| out| 1 | Báo rs1 đang bị conflict |
| hazard_rs2| out| 1 | Báo rs2 đang bị conflict |
| fwd_rs1_sel|out| 2 | Chọn nguồn Forwarding (EX, MEM, WB)|
| fwd_rs2_sel|out| 2 | Chọn nguồn Forwarding cho rs2 |

### Nguyên Lý Hoạt Động
- Liên tục so sánh `id_rs1` và `id_rs2` với các thanh ghi đích `rd` đang ở EX, MEM, WB.
- Phát tín hiệu Forwarding (`fwd_rs1_sel`, `fwd_rs2_sel`) để mạng Bypass lấy dữ liệu mới nhất.
- Nếu lệnh ở EX là LOAD và đích của nó trùng với nguồn ở ID, Scoreboard sẽ kích hoạt **Load-Use Hazard** -> Buộc phải Stall pipeline.

### Sơ Đồ Trạng Thái
Mạch tổ hợp chuyên dụng liên hệ với các thanh ghi pipeline.

### Hazard / Exception Interaction
Là khối chính giải quyết Data Hazard.

### Timing Considerations
Các mạch Comparators ở đây cung cấp tín hiệu cho các MUX Forwarding cực lớn ở tầng EX, nên phải tối ưu logic thật mỏng.

---

## Issue Logic

### Chức Năng
Quyết định xem lệnh ở tầng ID có được chuyển sang tầng EX (Issue) hay phải chờ (Stall) do Hazard hoặc Multi-cycle unit đang bận.

### Bảng Tín Hiệu
| Signal | Dir | Width | Description |
| ------ | --- | ----- | ----------- |
| id_valid | in | 1 | Báo có lệnh hợp lệ ở ID |
| load_use | in | 1 | Từ Scoreboard |
| muldiv_busy| in | 1 | Từ Multiply/Divide Unit |
| flush_req | in | 1 | Từ Controller |
| stall_if | out | 1 | Báo IF ngừng fetch |
| stall_id | out | 1 | Giữ nguyên lệnh ở ID |
| issue_valid| out | 1 | Đẩy lệnh hợp lệ sang EX |

### Nguyên Lý Hoạt Động
- Nếu `flush_req` == 1: Hủy lệnh (chuyển thành NOP).
- Nếu `load_use` == 1 hoặc `muldiv_busy` == 1: `stall_if` = 1, `stall_id` = 1, `issue_valid` = 0 (truyền bong bóng - bubble xuống EX).
- Ngược lại: `issue_valid` = 1, lệnh qua EX.

### Sơ Đồ Trạng Thái
Mạch tổ hợp thuần túy.

### Hazard / Exception Interaction
Chịu trách nhiệm thực thi các tín hiệu stall để chặn lỗi hazard.

### Timing Considerations
Là gatekeeper cuối cùng của chu kỳ ID.

---

## ALU (Arithmetic Logic Unit)

### Chức Năng
Thực thi các phép toán số học và logic cơ sở (ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU).

### Bảng Tín Hiệu
| Signal | Dir | Width | Description |
| ------ | --- | ----- | ----------- |
| opA | in | 32 | Toán hạng 1 (sau Bypass) |
| opB | in | 32 | Toán hạng 2 (sau Bypass / Imm) |
| alu_ctrl | in | 4 | Lệnh ALU (từ Decoder) |
| result | out | 32 | Kết quả tính toán |

### Nguyên Lý Hoạt Động
- Tích hợp một bộ cộng (Adder/Subtractor), các cổng Logic, và một Barrel Shifter.
- Chọn dữ liệu xuất ra thông qua multiplexer điều khiển bởi `alu_ctrl`.

### Sơ Đồ Trạng Thái
Không FSM.

### Hazard / Exception Interaction
Không.

### Timing Considerations
Đường Barrel Shifter và Bộ cộng (Carry-Lookahead) tạo thành critical path chính yếu của ALU.

---

## Dedicated Branch Unit

### Chức Năng
Bao gồm Branch Comparator và Branch Adder, dùng để độc lập đánh giá điều kiện rẽ nhánh và tính toán địa chỉ đích nhánh.

### Bảng Tín Hiệu
| Signal | Dir | Width | Description |
| ------ | --- | ----- | ----------- |
| opA | in | 32 | rs1_data |
| opB | in | 32 | rs2_data |
| pc | in | 32 | PC lệnh hiện tại |
| imm | in | 32 | Offset của branch/jump |
| br_type | in | 3 | BEQ, BNE, BLT... |
| pred_taken | in | 1 | Dự đoán từ IF |
| is_jump | in | 1 | Báo hiệu JAL/JALR |
| actual_taken|out| 1 | Nhánh thực sự nhảy |
| target_addr| out| 32 | Địa chỉ nhảy tới |
| mispredict | out| 1 | Báo sai dự đoán |

### Nguyên Lý Hoạt Động
- Sử dụng Comparator để so sánh `opA` và `opB`, sinh ra cờ Taken thực tế.
- Sử dụng Adder tính `target_addr` = `pc` + `imm` (hoặc `rs1` + `imm`).
- Nếu (`actual_taken` != `pred_taken`), cờ `mispredict` bật lên 1. Pipeline Controller sẽ tiến hành flush.

### Sơ Đồ Trạng Thái
Mạch tổ hợp.

### Hazard / Exception Interaction
Tạo ra `mispredict` để kích hoạt quá trình Branch Recovery, flush IF và ID.

### Timing Considerations
Việc dùng Adder và Comparator chuyên dụng riêng rẽ với thân ALU khổng lồ giúp giảm bớt chiều sâu mạch logic tổ hợp, đưa tín hiệu Mispredict ra sớm nhất có thể.

---

## AGU (Address Generation Unit)

### Chức Năng
Tính toán địa chỉ truy xuất bộ nhớ cho lệnh Load/Store (`rs1` + `imm`). Tách biệt với ALU chính.

### Bảng Tín Hiệu
Tương tự một bộ cộng 32-bit cơ bản.

### Nguyên Lý Hoạt Động
- Chỉ nhận Base Address và Offset, trả ra Memory Address cho LSU.
- Tối ưu hóa phân tải, tránh fan-out quá lớn cho ALU.

---

## LSU (Load/Store Unit) Front-End & Back-End

### Chức Năng
Giao tiếp giữa Pipeline và DCache/Bộ nhớ. Căn chỉnh dữ liệu, mở rộng dấu cho Load và định dạng byte mask cho Store.

### Bảng Tín Hiệu (LSU Back-End)
| Signal | Dir | Width | Description |
| ------ | --- | ----- | ----------- |
| req | in | 1 | |
| we | in | 1 | 1=Store, 0=Load |
| size | in | 2 | 00=B, 01=H, 10=W |
| addr | in | 32 | Địa chỉ từ AGU |
| wdata | in | 32 | Dữ liệu cần ghi |
| rdata | out | 32 | Dữ liệu đọc đã xử lý |
| mem_fault| out| 1 | Lỗi Misaligned |

### Nguyên Lý Hoạt Động
- **Store**: Sử dụng Byte Enable (`be`) dựa vào 2 bit cuối của `addr`. Dịch dữ liệu ghi vào đúng vị trí byte.
- **Load**: Đọc Word từ DCache. Dựa vào 2 bit cuối `addr` để trích xuất byte/half-word. Thực hiện Zero-Extend (LBU, LHU) hoặc Sign-Extend (LB, LH).
- Kiểm tra tính Alignment: Báo `mem_fault` nếu Word không chia hết cho 4, Half không chia hết cho 2.

### Hazard / Exception Interaction
Báo Exception (Address Misaligned) lên Exception Controller.

---

## MMU (Memory Management Unit)

### Chức Năng
Kiểm tra các vùng nhớ hợp lệ (Physical Memory Protection - PMP) hoặc dịch địa chỉ (Tùy chọn, thường bỏ qua trong MCU, nhưng nếu có sẽ chặn tín hiệu `req` nếu vi phạm).

---

## DCache (Data Cache)

### Chức Năng
Đệm dữ liệu từ Main Memory cho tầng MEM.

### Nguyên Lý Hoạt Động
Giống ICache nhưng hỗ trợ Write. Xử lý cache miss bằng cách stall toàn bộ pipeline (`ready` = 0) cho đến khi dữ liệu fill xong từ bus.

---

## Multiply Unit & Divide Unit (M Extension)

### Chức Năng
Thực thi nhân (MUL, MULH...) và chia (DIV, REM...).

### Nguyên Lý Hoạt Động
- Multiplier: Có thể dùng Radix-4 Booth (để tiết kiệm diện tích) trong vài cycle.
- Divider: Dùng Non-Restoring Division (khoảng 32 cycle).
- Báo cờ `busy` về Scoreboard/Issue Logic để stall tầng ID không cho issue lệnh mới trong quá trình tính.

---

## CSR Unit & CSR File

### Chức Năng
Quản lý tập thanh ghi Control and Status (MSTATUS, MEPC, MCAUSE...). Xử lý các lệnh nguyên tử CSRRW, CSRRS, CSRRC.

### Bảng Tín Hiệu
| Signal | Dir | Width | Description |
| ------ | --- | ----- | ----------- |
| csr_addr | in | 12 | |
| csr_cmd | in | 2 | RW, RS, RC |
| wdata | in | 32 | Dữ liệu cập nhật |
| rdata | out | 32 | Dữ liệu nguyên thủy |
| trap_req | in | 1 | Xử lý trap |
| cause | in | 32 | Exception code |
| epc | in | 32 | PC lưu lại |
| mtvec | out | 32 | PC của handler vector |

### Nguyên Lý Hoạt Động
- CSR File là nơi tập trung các cấu hình ngắt và trạng thái máy.
- Mọi lệnh CSR thực hiện đọc giá trị cũ và ghi đè giá trị mới theo mặt nạ bit trong cùng chu kỳ EX/MEM.

### Hazard / Exception Interaction
Cập nhật `mepc`, `mcause` khi xảy ra exception. Vô hiệu hóa ngắt toàn cục khi vào Trap Handler.

---

## Writeback Arbiter

### Chức Năng
Mux quyết định chọn nguồn nào để ghi về Register File ở tầng WB.

### Bảng Tín Hiệu
Nhận `alu_result`, `mem_rdata`, `csr_rdata`, `pc+4`. Tùy theo cờ `wb_sel` từ ID truyền xuống để output ra `wb_data`. Lý do tồn tại module này là gom các kết quả lại thành một đường truyền duy nhất trước khi vòng về ID stage để tối ưu routing định tuyến.

---

## Exception Controller & Interrupt Controller

### Chức Năng
Phát hiện, thu thập và ưu tiên hóa các lỗi và ngắt.

### Nguyên Lý Hoạt Động
- Exception đồng bộ (Illegal Inst, Misaligned, Page Fault) được trì hoãn (deferred) theo instruction tới tầng WB để đảm bảo In-Order trap (các lệnh trước nó phải hoàn thành an toàn).
- Ngắt ngoài (Timer, External) được ưu tiên lấy mẫu (sample) giữa các ranh giới lệnh.
- Khi Trap xảy ra, phát cờ `flush_req` xóa toàn bộ pipeline, và gửi Trap thông tin xuống CSR Unit.

---

## Pipeline Controller

### Chức Năng
Phân phát tín hiệu Stall và Flush đồng bộ trên toàn CPU.

### Nguyên Lý Hoạt Động
- Gom tất cả các cờ (`load_use`, `muldiv_busy`, `dcache_miss`, `mispredict`, `exception`).
- Tính toán và phát ra cờ `stall_if`, `stall_id`, `stall_ex`, `flush_id`, v.v. để kiểm soát các thanh ghi flip-flop của Pipeline Register.

---

# 5. Luồng Thực Thi Theo Từng Loại Lệnh

## ALU Instructions
*(ADD, SUB, AND, OR, XOR, SLT...)*
- **IF**: Lấy lệnh, dự đoán PC+4.
- **ID**: Giải mã opcode, đọc `rs1`, `rs2`. Kiểm tra Hazard. Phát lệnh.
- **EX**: Dữ liệu đi qua Forwarding Mux vào ALU. Tính toán ra kết quả ngay.
- **MEM**: Lệnh đi xuyên qua (Pass-through). Kết quả ALU chạy thẳng tới WB.
- **WB**: Chọn dữ liệu ALU, ghi kết quả vào `rd`.

## Load Instructions
*(LB, LH, LW, LBU, LHU)*
- **IF**: Lấy lệnh.
- **ID**: Giải mã, đọc `rs1` (base address) và imm offset.
- **EX**: AGU cộng `rs1` + `imm` ra địa chỉ. Phát yêu cầu Load.
- **MEM**: DCache nhận yêu cầu. LSU Back-end đọc dữ liệu, trích xuất mask và Sign-Extend theo đúng size.
- **WB**: Chọn dữ liệu Load (mem_rdata), ghi vào `rd`.

## Store Instructions
*(SB, SH, SW)*
- **IF**: Lấy lệnh.
- **ID**: Giải mã, đọc `rs1` (base), `imm`, và `rs2` (data to store).
- **EX**: AGU tính địa chỉ. `rs2` truyền xuống theo pipe.
- **MEM**: Dựa theo 2 bit cuối địa chỉ, xoay (shift) dữ liệu `rs2` vào đúng vị trí và xuất mask Byte Enable. Ghi vào DCache.
- **WB**: Bỏ qua (Retire, không ghi register).

## Branch Instructions
*(BEQ, BNE, BLT...)*
- **IF**: Fetch lệnh. Predictor dự đoán (ví dụ Taken), dùng Target từ BTB nạp vào PC tiếp theo.
- **ID**: Đọc `rs1`, `rs2`.
- **EX**: Branch Unit so sánh `rs1` và `rs2`. Tính toán đích thật sự.
  - Nếu đúng (Hit): Không làm gì thêm, pipeline trơn tru.
  - Nếu sai (Mispredict): Báo cờ `mispredict`.
- **MEM**: Pipeline Controller nhận Mispredict. Gửi tín hiệu Flush IF, ID. PC được ép quay lại đường đúng.
- **WB**: Bỏ qua.

## Jump Instructions
*(JAL, JALR)*
- **IF**: Lấy lệnh.
- **ID**: Tính Return Address = `PC+4`. JAL không cần chờ rs1. JALR thì cần.
- **EX**: Tính đích đến = `rs1` + `imm` (với JALR) hoặc `PC` + `imm`.
- **MEM**: Pass-through Return Address.
- **WB**: Ghi Return Address (`PC+4`) vào `rd`.

## M Extension
*(MUL, MULH, DIV, REM)*
- **IF & ID**: Tương tự ALU. Issue logic nhận thấy đây là lệnh Multi-cycle, bật cờ stall pipeline (IF và ID đứng chờ).
- **EX**: Lệnh đẩy vào khối MUL/DIV. Tính toán trong N cycles. Khi hoàn tất, cờ `done` hạ stall.
- **MEM & WB**: Ghi kết quả như ALU bình thường.

## CSR Instructions
*(CSRRW, CSRRS, CSRRC)*
- **IF & ID**: Giải mã.
- **EX**: Đọc `rs1` / `imm`. Yêu cầu CSR Unit thực hiện Read-Modify-Write.
- **MEM**: CSR data đi xuyên qua.
- **WB**: Ghi CSR Data cũ vào thanh ghi `rd`.

## Exception
*(Illegal Instruction, Misaligned, Page Fault)*
- Lỗi được gắn (tag) kèm theo Instruction chạy dọc pipeline.
- Khi lệnh lỗi rơi xuống WB, thay vì ghi `rd`, nó gửi báo cáo qua Trap Controller. Trap Controller Flush các lệnh đằng sau nó, nạp `mtvec` vào PC và chuyển mode chạy qua Machine Mode.

## Interrupt
*(External, Timer, Software)*
- Ngắt ngoài là dị bộ (Asynchronous). Trap Controller đợi lệnh hiện tại ở WB Commit xong thì chèn một Trap ảo (Pseudo-Exception) để thực hiện lưu Context và nhày vào `mtvec`.

---

# 6. Hazard Handling

## RAW (Read After Write)
- **Phát hiện**: Tại Scoreboard (tầng ID) khi Đích `rd` của các lệnh trước trùng nguồn `rs1/rs2`.
- **Xử lý**:
  - Dùng Bypass (Forwarding) network để lấy kết quả tính ở ngõ ra ALU/MEM đẩy vòng lên ngõ vào ALU. Pipeline KHÔNG bị stall.

## Load-Use Hazard
- **Phát hiện**: Scoreboard nhận thấy lệnh trước mặt (ở EX) là LOAD, có `rd` trùng nguồn.
- **Xử lý**:
  - Stall 1 cycle. IF và ID dừng lại, LOAD ở EX tiến sang MEM. Sang chu kỳ kế, dữ liệu bộ nhớ sẵn sàng ở ngõ ra MEM và được Forward thẳng về ngõ vào ALU của lệnh đang chờ.

## WAW (Write After Write) & WAR (Write After Read)
- Nhờ đặc điểm phát hành đơn in-order thuần túy, và việc đọc toán hạng tại một chu kỳ cố định, ghi kết quả tại một chu kỳ cố định, hệ thống **không gặp** lỗi WAR và WAW.

## CSR Hazard
- Tương tự Data Hazard nhưng cho các thanh ghi hệ thống. Các lệnh CSR thường hoạt động như một Memory Barrier (hàng rào bộ nhớ), có thể gây flush cục bộ hoặc stall triệt để đến khi pipeline trống.

## Branch Hazard (Control Hazard)
- **Phát hiện**: Tại EX khi Branch Result khác Branch Prediction.
- **Xử lý**: Mispredict gây phạt (Penalty) 2 cycles vì phải flush 2 lệnh đang theo sau tại ID và IF.
- **Forwarding**: Lệnh so sánh Branch độc lập ở EX cũng sử dụng Forwarding network chung của ALU để nhận dữ liệu mới nhất.

## MUL/DIV Hazard
- Structural Hazard khi khối tính không nhận thêm lệnh (Unpipelined Divider). Giải quyết bằng Pipeline Stall tại Issue stage.

---

# 7. Branch Prediction Subsystem

Hệ thống được thiết kế ghép đôi để khử Control Hazard:
- **Predictor (BHT - Branch History Table)**: Một mảng SRAM/Register chứa các Counter bão hòa 2-bit, lập chỉ mục bằng các bit thấp của PC. Trả về khả năng Nhảy/Không Nhảy.
- **BTB (Branch Target Buffer)**: Trực tiếp lưu đích đến (Target).
- **Luồng cập nhật (Update Logic)**: Tại EX stage, bất chấp dự đoán thế nào, kết quả luôn được ghi ngược (Feedback) về Predictor và BTB để rèn luyện (Train) model dự đoán cho các lần tiếp theo.
- **Recovery Logic**: Khi Mispredict, PC được nạp từ EX, và Controller sẽ clear (xoá bit valid) của các thanh ghi IF/ID Pipeline.

---

# 8. Exception & Interrupt Flow

Luồng đầy đủ:
1. Nguồn sinh lỗi kích hoạt cờ (Ví dụ Decoder giương cờ `ill_inst_req`).
2. Gói tín hiệu lệnh chứa cờ exception tiếp tục chảy từ ID -> EX -> MEM -> WB.
3. Nếu lệnh bị flush trên đường đi (bởi một branch mispredict trước đó), exception được hủy bỏ.
4. Tới WB stage, lệnh bắt đầu quá trình Retire. Cờ báo lỗi kích hoạt Exception Controller.
5. Exception Controller thông báo với CSR Unit nạp thông số lỗi vào các CSR file (`mcause`, `mepc`, `mtval`).
6. Exception Controller kích hoạt Pipeline Controller để Flush toàn bộ IF, ID, EX, MEM.
7. Đặt ngõ Mux PC tiếp theo ở IF Unit là giá trị lấy từ `mtvec`. Xử lý exception bắt đầu.

---

# 9. Timing & Datapath Optimization Notes

- **Dedicated Branch Adder**: Sử dụng để tính Branch Target (PC + imm) ngay lập tức khi vào tầng EX. Không chia sẻ ALU cho thao tác này giúp tiết kiệm path-delay của ngõ vào ALU Mux.
- **Dedicated Branch Comparator**: Tương tự, so sánh được thực hiện độc lập, giúp có kết quả Mispredict cực sớm, làm nhẹ tải (fan-out) cho mạch ALU, đảm bảo cycle EX chạy được ở xung nhịp rất cao.
- **AGU (Address Generation Unit)**: Đặt một bộ cộng riêng (chỉ bằng một mảng cell full-adder rất nhẹ) để tính địa chỉ truy xuất bộ nhớ cho LSU. Điều này tách bạch hoàn toàn đường dữ liệu Data-Path của Memory Operation và ALU Operation, thuận lợi lớn cho Place & Route.
- **Scoreboard tại Decode Stage**: Logic phát hiện Hazard và tạo cờ lựa chọn Forward Mux (fwd_sel) được hoàn tất ngay chu kỳ ID. Tới chu kỳ EX, Forward Mux chỉ việc chạy lệnh `Select` lập tức mà không phải tốn thời gian tính toán kiểm tra logic tại EX, tối ưu đường trễ.
- **Writeback Arbiter**: Đặt như một module tổng hợp dữ liệu riêng ở cuối tầng MEM giúp cô lập hoàn toàn logic định tuyến (routing) phức tạp của chặng Writeback, dễ debug và review tín hiệu.
