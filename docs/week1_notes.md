# Week 1 Notes (7/24–7/27)

- HDLBits 必做题清完:异步复位 DFF、D 锁存器、计数器、移位寄存器;generate/genvar 相关题留到第2段学完再回头做。
- 无板期间把 Day 2 的消抖 FSM 改成纯仿真闭环:四状态(IDLE/PRESS_CHECK/PRESSED/RELEASE_CHECK)+ 参数化计数器,三段式写法,自检 testbench 一次 PASS(毛刺全滤掉,单次按下恰好一个脉冲)。上板部分等板子到手补。
- 踩坑 1:`localparam` 不能在实例化时被 `#()` 覆盖——testbench 要改的时序常量必须声明成模块头的 `parameter`,状态编码这类不该被外部改的才用 `localparam`。
- 踩坑 2:VS Code 文件名旁的 U 是 git untracked 标记,不是"未保存";未保存看标签页的白点。另外 `.gitignore` 漏了 `*.vcd`,差点把波形文件提交进仓库,已补规则。
- Git Bash 里 `$display` 的中文输出会显示成 GBK 乱码,不影响仿真结果;以后 testbench 打印统一用英文省事。
