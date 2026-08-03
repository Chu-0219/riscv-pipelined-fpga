# 第2段笔记（7/28–8/3）

## Day 1 —— 参数化与 generate（full_adder.v / adder_n.v）

- `parameter`：模块对外的"旋钮"，实例化时可用 `#(.WIDTH(32))` 覆盖；`localparam`：模块内部常量，外部不可改。判断标准：**给外面调的用 parameter，纯内部约定用 localparam**（比如 ALU 的操作码编码就必须 localparam，外部改了整个模块就错了）。
- `generate` + `genvar`：编译期复制硬件结构。N 位行波进位加法器 = 用 for-generate 串 N 个全加器，进位链 `c[i+1] → c[i]` 逐级传递。genvar 只存在于编译期，不是运行时变量。
- 成果：WIDTH=8 覆盖测试 23/23 PASS，参考模型比对 `a+b+cin`。

## 7/31（Day 2+3 合并日）—— regfile / sync_ram / alu

### regfile.v：寄存器堆

一句话：reg8 是"一个抽屉"，寄存器堆是"一排带编号的抽屉柜 + 地址选抽屉"。

**reg 数组语法**（今天的新语法，两个方括号位置含义不同）：

```verilog
reg [WIDTH-1:0] rf [0:DEPTH-1];
//  └─每个多宽─┘     └─有几个─┘
```

- `rf[3]`：取 3 号寄存器全部位；`rf[3][5]`：3 号寄存器的第 5 位。`rf` 只是变量名，无语法含义。
- **下标位置决定硬件**：`rf[waddr] <= wdata`（左边）→ 综合成写地址译码器；`assign rdata = rf[raddr]`（右边）→ 综合成 DEPTH 选 1 读 mux。译码器和 mux 都不用手写，工具从下标推断。

**三个设计决策**（写 regfile 真正要想的就这三件事，其余是模板）：

1. **异步读 + 同步写**。读用 `assign`（地址变数据立变），写在 `posedge clk`。为什么：单周期 CPU 要求"读寄存器→ALU→写回"在一拍内完成，读端口不能吃掉一拍；写必须钟控对齐，否则传播中的毛刺值会被写进状态。口诀：**看（读）随时安全，改（写）必须对齐时钟**。
2. **1 写 2 读，地址独立**。R 型指令要同一瞬间读 rs1、rs2，一套读端口一次只能读一个地址，所以硬件上并排两套 mux。
3. **`$clog2(DEPTH)` 自动算地址位宽**。8 深→3 位，32 深→5 位。改 DEPTH 地址宽自动跟，防"改深度忘改地址"的低级 bug。注意**全小写**（今天踩过：$CLog2 / $cLog2 都报 elaboration 错）。

**read-first 行为**（T5 验证过）：同一拍写并读同一地址，读到**旧值**。原因是 NBA 语义——时钟沿上所有 `<=` 右边先按旧值求值，更新最后统一生效。第4周流水线"WB 写 / ID 读同一寄存器"就是这个场景，靠前递解决。

**第4周复用**：参数改 32×32 + 加一行 x0 恒零，其余原样。**此模块要求能空白文件默写**（面试高频手写题）。

### sync_ram.v：同步 RAM

**和 regfile 的三点差异**（对照记忆最有效）：

| 决策点 | regfile | sync_ram | 后果 |
|---|---|---|---|
| 读放哪 | assign（组合） | always @(posedge clk) | 0 拍 vs 1 拍延迟；LUT vs BRAM |
| 端口 | 1写2读独立地址 | 单端口读写共址 | 面积成本 |
| 初始化 | 无 | initial + $readmemh | 程序如何装载 |

**为什么大存储器必须同步读**：Artix-7 的 Block RAM 硬件自带输出触发器、只支持同步读。写异步读的大数组 → 无法映射 BRAM → Vivado 用海量 LUT 硬拼或资源不足。**代码风格决定硬件形态**（和"缺 default 推断锁存器"同类问题）。核心模板 6 行要能默写：

```verilog
always @(posedge clk) begin
    if (we)
        mem[addr] <= din;
    dout <= mem[addr];   // 读无条件、在 if 外面；NBA 语义 → 同拍读写同址拿旧值(read-first)
end
```

**initial 在 RTL 里的唯一豁免**：`initial $readmemh(...)` 给存储器赋初值是综合工具认得的特例——不生成电路，初值直接写进 FPGA 比特流。边界：仅限赋初值这一个用途；ASIC 不适用（没有比特流，上电内容随机）。

**$readmemh 要点**：文本文件、十六进制不带 0x、`@地址` 跳转（@后面也是十六进制）、没写到的单元保持 x。**路径相对 vvp 运行目录**，不是相对 .v 文件——报 "Unable to open" 先 `pwd`。

**INIT_FILE 字符串参数**：parameter 能传字符串，testbench 用 `.INIT_FILE("tb/ram_init.hex")` 注入路径，RTL 零改动——和 debounce 用 parameter 覆盖 CNT_MAX 同一思想。

**第4周复用**：指令存储器 = 这个模块 + 手写机器码 .hex；数据存储器同构。

### alu.v：算术逻辑单元

**ALU 是什么**：CPU 三类部件——存的（regfile/ram）、搬的（mux/PC）、**算的（只有 ALU）**。几乎每条指令都过它：add 显然；`lw x5, 8(x1)` 的地址 x1+8 是它算的；`beq` = 它做减法 + zero 标志。

**硬件本质**：所有运算**同时都在算**，case 选一个输出——case 综合成大 mux，各分支综合成各运算单元。组合 always 必须全路径赋值 → **case 必须有 default**。

**SLT 与 $signed（今天最大的坑，亲手埋过并看测试抓住）**：

- Verilog 向量默认**无符号**，`a < b` 是无符号比较。陷阱实例：`8'hFF < 8'h01` 无符号 = 假（255<1），有符号 = 真（-1<1）。
- `$signed()` 必须**两边都套**——只套一边整个比较静默退回无符号，无任何警告。
- 实验记录：删掉 $signed 后，"SLT basic"(02 vs 05) 依然 PASS——正常值下两种解释答案相同，**只测正常值的用例对这个 bug 是瞎的**；"SLT signed trap"(FF vs 01) 一击即中——用例故意选在**两种解释给出不同答案的分歧点**。这就是定向测试的设计思想：瞄准已知机制，选能打出原形的输入。

**其他要点**：

- 复制拼接：`{(WIDTH-1){1'b0}}` = 复制 7 个零；外层 `{零, 比较结果}` 拼成全宽。SLT 输出 = 高位补零的 0/1。
- 移位量截断 `b[SH_W-1:0]`：对齐 RISC-V 语义（取 rs2 低位），综合的移位器宽度也刚好。注意 `b[2:0]` 是向量切片，`rf[3]` 是数组选元素，语法像但不是一回事。
- `assign zero = (result == 0)`：为第4周 BEQ 留的接口，硬件是一个多输入 NOR。
- 操作码 4 位（8 个操作 3 位够）：为第3段扩到 10 个操作（+SRA/SLTU）留余量。

### testbench 技巧（跨模块通用）

- **`!==` vs `!=`（铁律）**：`!=` 遇 x 返回 x，if 判假，**坏结果被静默放过**；`!==` 把 x 当真实值比，xx≠08 老实报 FAIL。sync_ram 缺 hex 时 12 个 FAIL 能被抓住全靠 `!==`。自检式 testbench 一律 `!==`/`===`。
- **两种 `#1`，理由不同**：时序模块 tb 里的 #1 = 越过 posedge 后的 NBA 更新区（老教训）；组合模块 tb 里的 #1 = 等传播延迟。长得一样，解决的问题不同。
- **组合模块不需要时钟框架**：没有 clk 端口 → 没有周期概念 → 测试节奏 = 摆输入→#1→查输出。写 tb 前先看 DUT 有没有 clk。
- task 可以把"摆激励+等+比对"整个动作封装（alu_tb 的 check），比只封装比对更紧凑；task 能看到模块级信号、能含时序控制。
- 字符串参数本质是位向量：`input [8*24-1:0] msg` = 最多 24 字符，$display 用 %0s。

### 今日错误日志（症状 → 原因 → 防御）

1. **编译报错但满屏 PASS** → iverilog 失败后 vvp 跑的是**旧 sim.out**（跑的还是加法器的测试）→ 防御：`iverilog ... && vvp sim.out`，`&&` 保证编译失败就不执行仿真。
2. `syntax error` 指向文件末尾 → module 结束写成了 `end`，应为 `endmodule` → 见到指向末尾的语法错先查 begin/end/endmodule 配对。
3. `Unable to evaluate parameter ... $CLog2` → 系统函数**大小写敏感**，全小写 $clog2 → 报错会原样回显它看到的名字，和正确拼写逐字符对照比盯自己代码有效（人眼会自动脑补成对的，$cLog2 那次二连错是实证）。
4. `result is not a valid l-value ... declared as wire` → always 块里赋值的输出必须 `output reg` → 看驱动方式定 reg：assign 驱动不带 reg（regfile 的 rdata），always 里赋值带 reg（sync_ram 的 dout、alu 的 result）。
5. `Unable to bind ... OP_AUB` → case 里把 OP_SUB 拼成 OP_AUB → "Unable to bind" 第一反应查拼写。
6. **SLT 分支整个误删**：编译零报错（case 落进 default 输出 0），被 "SLT basic/trap" 两条测试当场按住 → 没有测试它会潜伏到第4周 SLT 指令跑错才爆。**这是"从第一天写自检式测试"的完整答案。**

### 与后续的连接

- 8/2 迷你项目：regfile + alu 直接连起来（读两寄存器→ALU→写回），今天的两块积木马上用。
- 第3段：ALU 扩展 SRA（`>>>` + $signed）/SLTU，对接 ALUControl 编码。
- 第4周：regfile 改 32×32 加 x0；sync_ram 变指令/数据存储器；zero 接 BEQ；read-first 行为在流水线写回时回来（前递）。
