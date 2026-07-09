# Verilog Project

## 项目简介

（在此处简要描述你的项目功能）

## 目录结构

```
├── rtl/          # RTL 设计源文件（.v）
├── tb/           # Testbench 仿真测试文件
├── constraints/  # 约束文件（管脚、时序）
├── docs/         # 文档
└── README.md
```

## 工具链

- **Icarus Verilog** — 编译与仿真
- **GTKWave** — 波形查看

## 快速开始

### 编译与仿真

```bash
iverilog -o <输出文件名> <源文件> <testbench文件>
vvp <输出文件名>
```

### 查看波形

```bash
gtkwave <波形文件>.vcd
```

## License

（请在此处添加许可证信息）
