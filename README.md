# eVTOL 悬停控制与能量管理：Simulink 流程最小样例

这个工程的目的不是做一个"能飞的控制器"，而是让你**亲手走完一遍**从需求到证据的链路：

```txt
需求  →  模型  →  仿真  →  需求验证  →  覆盖率  →  代码生成
 │        │        │          │            │           │
 └────────┴────────┴──────────┴────────────┴───────────┘
              所有环节都能一条命令重跑
```

规模刻意做小：一个高度环、一个能量状态机、十条需求。小到你可以在一个下午读完每一行，
又完整到能暴露真实项目里的所有关键问题。

---

## 1. 被仿真的对象

| 项 | 取值 | 说明 |
|---|---|---|
| 机型 | 600 kg 四旋翼 | 总桨盘面积 10.2 m²，单桨半径 0.9 m |
| 动力学 | 一维垂向 | `m·dv/dt = T − m·g − k_d·v`，`dh/dt = v` |
| 执行机构 | 一阶滞后 | 时间常数 0.08 s，推力限幅 0…12 kN |
| 控制器 | PID + 配平前馈 | Kp=3000, Ki=250, Kd=2400，带积分限幅 |
| 能耗 | 动量理论 | `P = T^1.5 / sqrt(2ρA)`，悬停约 90 kW |
| 电池 | 4 kWh（演示用） | 满电悬停约 160 s，用于触发两级告警 |
| 状态机 | Stateflow | NORMAL / CAUTION / WARNING，带 0.03 滞回 |

---

## 2. 快速开始

### 2.1 脚本方式（主线，可复现）

```matlab
cd <工程根目录>
setup                       % 加路径 + 展开参数到 base workspace

P = params();               % 1. 参数（唯一来源）

build_model(P);             % 2. 用代码生成 models/evtol_hover.slx

out = run_sim(P);           % 3. 跑一次仿真
R   = run_requirements_tests(P);   % 4. 逐条需求验证 → 10/10 PASS
run_coverage(P);            % 5. 覆盖率 + HTML 报告
run_codegen(P);             % 6. 生成控制器 C 代码
plot_results(P);            % 7. 出图到 results/figures
```

全部跑完约一到两分钟（主要是若干次 80~150 s 的定步长仿真）。
不想开 GUI 也能看结构：`results/figures/model_diagram.png` 是模型框图的导出图。

### 2.2 GUI 方式（观察与调参）

```matlab
setup                          % 已包含 push_params，参数直接可用
P = params();
open_system(P.mdlName)         % 打开模型，然后点"运行"
```

如果 `setup` 之后又改了参数，或者想带覆盖值进入 GUI：

```matlab
push_params(P, struct('Kp', 1500));   % 覆盖值优先
open_system(P.mdlName);
```

**顺序不能反：先把参数展开到 base workspace，再打开/运行模型。**
否则会报 `函数或变量 'Tend' 无法识别`——因为模型引用的是变量名，
而 `P = params()` 只创建了一个结构体。完整的 GUI 操作说明见第 3 节。

---

## 3. GUI 里怎么看模型

这一节解决一个新手最常撞的墙：**打开模型 → 点运行 → 报"找不到变量"**。

### 3.1 为什么直接双击 .slx 会失败

模型里所有参数都写成**变量名**，而不是具体数字：

| 位置 | 写的是 | 不是 |
|---|---|---|
| 求解器步长 | `Ts` | `0.01` |
| 仿真时长 | `Tend` | `150` |
| Kp 增益 | `Kp` | `3000` |
| 推力上限 | `Tmax` | `12000` |

Simulink 在仿真前会去 **base workspace** 里按名字取这些变量。
`P = params()` 只创建了一个叫 `P` 的结构体，**不会**自动生成 `Ts`、`Tend` 这些独立变量，
于是求解器第一步就失败：

```
计算 'StopTime' 的表达式 'Tend' 时出错。函数或变量 'Tend' 无法识别。
```

### 3.2 正确的打开顺序

```matlab
setup                        % 加路径；若参数不存在会自动 push 一次
P = params();
open_system(P.mdlName)       % 现在点"运行"才有效
```

或者手动控制（推荐，意图更清楚）：

```matlab
P = params();
push_params(P);              % 把字段展开成 base workspace 变量
open_system(P.mdlName);
```

验证参数是否就位：

```matlab
exist('Tend', 'var')         % 返回 1 才算成功
Tend                         % 应显示 150
```

### 3.3 打开之后看什么

| 操作 | 看什么 | 对应文档里的概念 |
|---|---|---|
| 双击 `Controller` | PID 三项并联 + 配平前馈 + 积分限幅 | 第 5 节「需求」、第 7 节建模 |
| 双击 `EnergyMode` | 三个状态、带 0.03 滞回的转移 | 第 5 节「状态机」 |
| 双击 `Kp` / `Ki` 模块 | 增益值写的是 `Kp`，不是 `3000` | 参数化的意义 |
| 双击 `Actuator` | `1/(0.08s+1)`，一阶滞后 | 执行机构不是理想环节 |
| 点「数据查看器」 | 选 `out` 里的信号看波形 | 不必跑 `plot_results` |
| 点「诊断查看器」 | 应为 0 错误 | 报错的第一现场 |

### 3.4 在 GUI 里调参

最直接的闭环：

```matlab
push_params(P, struct('Kp', 1500));   % 改一个数
open_system(P.mdlName);               % 打开/回到模型，点运行
```

观察超调如何变化，再换回来：

```matlab
push_params(P);                       % 恢复标称值
```

**只改 workspace 变量，不去改模型里的模块参数。** 模型里保留 `Kp` 这个符号，
变量的值才是可调的量——这也是参数化的全部意义。

### 3.5 一个必须知道的限制

`build_model(P)` 每次都会**删掉并重建** `models/evtol_hover.slx`。

也就是说：**在 GUI 里拖动的连线、改的模块参数、加的注释，重新 build 后全部丢失。**
模型的真实来源永远是 [src/build_model.m](src/build_model.m)，`.slx` 只是它的产物。

所以：

- 想改结构 → 改 `build_model.m`，然后重新 `build_model(P)`。
- 想改数值 → 改 `params.m`，或在 GUI 里用 `push_params` 临时覆盖。
- 不要指望"在 GUI 里存一下"能保留改动。

如果确实需要 GUI 自由编辑（比如做探索性修改），先关掉重新 build 的习惯，
把 `models/*.slx` 当成手写资产管理——但那样就失去了"模型可由代码重建"的核心优势，
和本工程的定位冲突。这个取舍要想清楚。

---

## 4. 目录结构

```txt
matg/
├── setup.m                      路径设置
├── docs/
│   └── requirements.md          需求基线（唯一来源）
├── src/
│   ├── params.m                 所有参数与路径
│   ├── push_params.m            参数展开到 base workspace（GUI 运行前提）
│   ├── build_model.m            用代码构建 Simulink 模型
│   ├── run_sim.m                一次仿真（支持参数覆盖）
│   └── ensure_dirs.m            生成目录 + 把 Simulink 缓存重定向到 results/
├── tests/
│   └── run_requirements_tests.m 需求验证脚本
├── scripts/
│   ├── run_coverage.m           覆盖率测量与报告
│   ├── run_codegen.m            嵌入式 C 代码生成
│   └── plot_results.m           结果可视化
├── models/                      生成的 .slx（已被 gitignore）
└── results/                     覆盖率报告、生成的代码、图片
```

---

## 5. 每个环节在做什么

| 环节 | 本工程的实现 | 真实型号项目里的对应物 | 关键文件 |
|---|---|---|---|
| 需求 | 10 条带 ID 和可测量判据的需求 | 需求基线、审定基础映射 | `docs/requirements.md` |
| 参数 | 单一函数返回结构体，全链路引用 | 构型管理、标定数据、数据字典 | `src/params.m` |
| 参数装载 | `push_params` 展开到 base workspace | 数据字典、标定文件加载 | `src/push_params.m` |
| 模型 | 脚本构建，纯文本可 diff | 设计模型、模型规范 | `src/build_model.m` |
| 仿真 | 一次调用，可覆盖任意参数 | 工况仿真、蒙特卡洛 | `src/run_sim.m` |
| 验证 | 需求 ID ↔ 用例 ↔ 实测值 | 需求符合性验证矩阵 | `tests/` |
| 覆盖率 | 执行/判定/条件/MC-DC 四项 | DO-178C 表 A-7 结构覆盖证据 | `scripts/run_coverage.m` |
| 代码生成 | 只对控制器子系统生成 C | DO-331 模型化开发、机载软件 | `scripts/run_codegen.m` |

**注意最后一个环节的边界**：只对 `Controller` 子系统生成代码。
机体动力学、能耗模型属于仿真环境，永远不会装机。把"仿真模型"和"机载模型"分开，
是模型化开发里最容易被搞混的一点。

---

## 6. MATLAB 与 Simulink 的分工

理解这条分工，比记住任何 API 都重要：

| | MATLAB | Simulink |
|---|---|---|
| 擅长 | 参数组织、批处理、调参、后处理、测试编排 | 动态系统闭环、状态机、代码生成 |
| 本工程中 | `params` / `run_sim` / 测试断言 / 画图 | 被控对象、控制器、Stateflow |
| 不擅长 | 直观表达反馈回路 | 批量扫参、复杂数据后处理 |

所以本工程的做法是：**Simulink 负责"系统长什么样"，MATLAB 负责"怎么批量地问它问题"**。

---

## 7. 模型是怎么被"写"出来的

`build_model.m` 不是给你一个黑盒 `.slx`，而是把模型当代码写。核心只有五个 API：

```matlab
new_system(mdl)                                   % 新建空模型
add_block('simulink/Math Operations/Gain', path)  % 加模块
set_param(path, 'Gain', 'Kp')                     % 设参数（可以是表达式）
add_line(mdl, 'Kp/1', 'Sum_T/1')                  % 连线
save_system(mdl, file)                            % 存盘
```

Stateflow 稍微特殊，要用对象 API：

```matlab
ch = sfroot.find('-isa','Stateflow.Chart','Name','EnergyMode');
s  = Stateflow.State(ch);   s.LabelString = sprintf('CAUTION\nen: mode = uint8(1);');
t  = Stateflow.Transition(ch); t.Source = s1; t.Destination = s2;
```

**为什么值得这么做**：模型变成纯文本后，可以 code review、可以看 diff、可以在 CI 里重建。
图形界面的模型一旦多人协作，很容易出现"谁的版本才是对的"。

---

## 8. 结果怎么看

### 8.1 需求验证

```txt
--- summary: 10 / 10 passed ---
[PASS] REQ-ALT-001   阶跃超调 <= 10 %                overshoot = 6.93 %
[PASS] REQ-ALT-002   调节时间(±5%) <= 12 s           settling = 7.46 s
[PASS] REQ-ALT-003   质量偏差 +10% 时 60 s 稳态误差 <= 0.05 m   |e(60s)| = 0.0016 m
...
```

每条都给出**实测值**，而不是一句"通过"。审查时看的就是这个。

### 8.2 覆盖率

```txt
Execution   :  22 /  22  (100.0 %)
Decision    :  14 /  19  ( 73.7 %)
Condition   : n/a
MC/DC       : n/a
```

`results/coverage_report.html` 里能看到**具体哪条分支没走到**。

### 8.3 生成的代码

```txt
Controller_Y.T_cmd = ((3000.0 * rtb_Sum_e + Controller_DW.Ki_DSTATE) - 2400.0 *
                      Controller_U.v) + 5886.0;
Controller_DW.Ki_DSTATE += 2.5 * rtb_Sum_e;      // Ki*Ts = 250*0.01
```

注意 `2.5`：离散积分器在生成代码时被折成了"增益 × 采样周期"。
这就是为什么**采样周期是设计参数，不是运行参数**。

---

## 9. 三个刻意保留的"不完美"

这些不是 bug，是真实项目里必然要面对、而小样例没法全部覆盖的东西。
看懂它们，比拿到 100 % 覆盖率更有价值。

### 9.1 决策覆盖率只有 73.7 %

19 条判定里有 5 条没覆盖：都是**告警恢复**的转移（CAUTION→NORMAL、WARNING→CAUTION）。
本工况 SOC 只降不升，这些分支永远不会触发。

> 下一步：增加一个"SOC 回升"场景（换电/充电），或者用 Simulink Test 单独构造用例。

### 9.2 Condition / MC-DC 是 n/a

因为模型里没有**复合布尔条件**（都是单条件的 `soc < 0.30`）。
MC/DC 只有在 `A && B` 这种表达式上才有意义。

> 下一步：把告警判据改成 `soc < 0.15 && h > 0.5`（区分地面与空中），MC/DC 立刻就有数据了。

### 9.3 电池模型是能量积分，不是电池

`SOC = 1 − ∫P dt / E_b` 只是把功率积分成能量。
没有内阻、没有温升、没有老化、没有单体不一致性。

> 下一步：换 Simscape Battery 的等效电路模型。但注意——**热失控必须靠试验，不能靠仿真**。

---

## 10. 扩展路线（按投入产出排序）

1. **把需求接进 Requirements Toolbox**
   `slreq.new` 建需求对象，链接到模型元素，自动生成追溯矩阵。
2. **把脚本测试升级成 Simulink Test**
   把 `run_requirements_tests.m` 里的场景写成 `.mldatx`，用 Test Manager 管理基线。
3. **加故障注入**
   Simulink Fault Analyzer 注入"单电机失效"，看高度响应是否仍满足 REQ-ALT-001。
4. **定点化与 PIL**
   Fixed-Point Designer 把控制器改成定点，用 PIL 对比浮点/定点差异。
5. **参数对象化**
   把 `params.m` 的裸数值换成 `Simulink.Parameter` + 数据字典，为代码生成和标定做准备。

---

## 11. 环境与限制

- 需要：MATLAB R2024b 及以上（本工程在 R2025b 上验证），
  Simulink、Stateflow、Simulink Coverage、Embedded Coder。
- 本工程**未做工具鉴定**（DO-330），IEC Certification Kit 也不在依赖里。
  它是学习流程的样例，不是可交付的适航证据。
- 控制器参数是为演示整定的，不代表任何真实机型的可接受值。
- 模型是一维垂向的，不能用于评估横向稳定性、旋翼失效后的可控性。

---

## 12. 一句话总结

适航工作里的仿真，价值不在于"跑得好看"，而在于**每一条结论都能被追溯到一条需求、一个用例、一次可复现的运行**。
这个工程把这条链压缩到了你可以一晚上读完的规模。
