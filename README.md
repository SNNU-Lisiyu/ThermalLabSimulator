# 热学实验虚拟仿真系统

**Thermal Physics Virtual Simulation Laboratory**

> 陕师大物理实验教学中心 · v4.0

基于 MATLAB App 框架开发的热学实验虚拟仿真平台，涵盖六个经典热学实验，提供完整的实验操作模拟、数据采集与结果分析功能。

---

## 实验项目

| 编号 | 实验名称 | 模块文件 |
|------|----------|----------|
| 3-1 | 冰融解热的测量 | `Exp3_1_IceMelting.m` |
| 3-2 | 电热当量的测量与散热误差的研究 | `Exp3_2_ElectricHeat.m` |
| 3-3 | 冷却法测量金属比热容 | `Exp3_3_MetalSpecificHeat.m` |
| 3-4 | 空气比热容比的测量 | `Exp3_4_AirHeatRatio.m` |
| 3-5 | 稳态法测量非良导体的导热系数 | `Exp3_5_ThermalConductivity.m` |
| 3-6 | 金属线胀系数的测量 | `Exp3_6_LinearExpansion.m` |

## 快速开始

### 方式一：源码运行（需要 MATLAB）

```matlab
% 1. 在 MATLAB 中打开 ThermalLabSimulator 文件夹
% 2. 运行启动脚本（自动添加路径）
startup
% 3. 启动系统
main
```

### 方式二：独立 EXE 运行

从 [Releases](https://github.com/SNNU-Lisiyu/ThermalLabSimulator/releases) 下载编译好的 EXE 文件，需预先安装对应版本的 MATLAB Runtime。

## 项目结构

```
ThermalLabSimulator/
├── main.m                          # 主入口
├── startup.m                       # 项目初始化（自动添加路径）
├── buildConfig.m                   # 构建配置（版本、路径）
├── buildExe.m                      # 打包 EXE 脚本
├── buildWithRuntime.m              # 含 Runtime 安装包构建
├── collectBuildFiles.m             # 构建文件收集工具
│
├── +experiments/                   # 实验模块
│   ├── ExperimentBase.m            # 实验抽象基类
│   ├── Exp3_1_IceMelting.m         # 冰融解热
│   ├── Exp3_2_ElectricHeat.m       # 电热当量
│   ├── Exp3_3_MetalSpecificHeat.m  # 金属比热容
│   ├── Exp3_4_AirHeatRatio.m       # 空气比热容比
│   ├── Exp3_5_ThermalConductivity.m# 热导率
│   └── Exp3_6_LinearExpansion.m    # 线性膨胀
│
├── +core/                          # 核心功能
│   └── AppConfig.m                 # 全局配置（版本、实验列表）
│
├── +ui/                            # UI 组件
│   ├── StyleConfig.m               # 样式常量与工厂方法
│   ├── ExperimentGuide.m           # 步骤式实验流程控制
│   ├── InteractionManager.m        # uiaxes 鼠标交互系统
│   └── InteractionEventData.m      # 交互事件数据类
│
├── +utils/                         # 工具
│   └── Logger.m                    # 4 级日志（DEBUG/INFO/WARNING/ERROR）
│
└── resources/                      # 资源文件
    ├── images/                     # 图片（logo 等）
    └── data/                       # 数据文件
```

## 系统要求

- **源码运行**：MATLAB R2020a 或更高版本（需 `uigridlayout` 支持）
- **EXE 运行**：对应版本的 MATLAB Runtime
- **构建 EXE**：需安装 MATLAB Compiler

## 开发指南

新增实验模块：

1. 在 `+experiments/` 下创建新类，继承 `experiments.ExperimentBase`
2. 实现抽象方法：`setupExperimentUI()`、`calculateResult()`
3. 可覆盖 `onCleanup()` 释放资源（Timer 等）
4. 遵循 `ui.StyleConfig` 中的样式规范
5. 在 `core.AppConfig.ExperimentList` 中注册新实验

## 构建发布

```matlab
% 生成独立 EXE（用户需安装 MATLAB Runtime）
buildExe

% 生成含 Runtime 的安装包
buildWithRuntime
```

## 许可证

© 2026 陕师大物理实验教学中心
