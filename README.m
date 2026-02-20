% 热学实验虚拟仿真系统
% Thermal Physics Virtual Simulation Laboratory
%
% 版本：3.0
% 日期：2026年2月
%
% 使用方法：
%   1. 将 ThermalLabSimulator 文件夹添加到 MATLAB 路径
%      或运行 startup.m 自动添加路径
%   2. 在命令窗口运行: main
%
% 项目结构：
%   main.m                          - 主入口，启动系统
%   startup.m                       - 项目初始化脚本
%   buildConfig.m                   - 构建配置（版本号、路径等）
%   collectBuildFiles.m             - 构建文件收集工具函数
%   +experiments/                   - 实验模块
%       ExperimentBase.m            - 实验抽象基类
%       Exp3_1_IceMelting.m         - 实验3-1 冰融解热
%       Exp3_2_ElectricHeat.m       - 实验3-2 电热当量
%       Exp3_3_MetalSpecificHeat.m  - 实验3-3 金属比热容
%       Exp3_4_AirHeatRatio.m       - 实验3-4 空气比热容比
%       Exp3_5_ThermalConductivity.m- 实验3-5 热导率
%       Exp3_6_LinearExpansion.m    - 实验3-6 线性膨胀
%   +core/                          - 核心功能
%       AppConfig.m                 - 应用级全局配置（版本、实验列表等）
%   +ui/                            - UI组件
%       StyleConfig.m               - 样式配置（颜色/字体/尺寸常量与工厂方法）
%       ExperimentGuide.m           - 步骤式实验流程控制
%       InteractionManager.m        - uiaxes 鼠标交互系统
%       InteractionEventData.m      - 交互事件数据类
%   +utils/                         - 工具函数
%       Logger.m                    - 4级日志系统（DEBUG/INFO/WARNING/ERROR）
%   resources/                      - 资源文件
%       images/                     - 图片资源 (logo.png)
%       data/                       - 数据文件
%   build/                          - EXE 构建输出目录
%   installer/                      - 安装包构建输出目录
%   buildExe.m                      - 打包为EXE脚本
%   buildWithRuntime.m              - 含Runtime安装包构建脚本
%
% 开发说明：
%   - 新建实验时，继承 experiments.ExperimentBase 类
%   - 实现抽象方法: setupExperimentUI(), calculateResult()
%   - 可覆盖 onCleanup() 进行资源释放 (Timer等)
%   - 遵循 ui.StyleConfig 中的样式规范
%
% 系统要求：
%   - MATLAB R2020a 或更高版本 (需要 uigridlayout 支持)
%   - MATLAB Compiler (仅打包时需要)
%
% 构建发布：
%   - 运行 buildExe 生成独立EXE (需用户安装MATLAB Runtime)
%   - 运行 buildWithRuntime 生成含Runtime的安装包
