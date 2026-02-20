# ThermalLabSimulator - AI 编码指南

## 项目概述

MATLAB 热学实验虚拟仿真系统 (v3.0)，使用 `uifigure`/`uigridlayout` 构建响应式 GUI。支持 6 个热学实验模块，可编译为独立 EXE。

## 架构

### 包结构 (MATLAB Namespace)

- `+experiments/` - 实验模块，继承 `ExperimentBase`（含 6 个实验子类）
- `+core/` - 全局配置（`AppConfig.m` 存放版本号 `Version`、实验列表等，是唯一的版本真值源）
- `+ui/` - UI 组件
  - `StyleConfig.m` - 颜色、字号、工具方法（`FontSizeSmall=11`）
  - `ExperimentGuide.m` - 步骤引导系统（步骤定义、前置条件、RepeatGroups）
  - `InteractionManager.m` - 交互高亮管理
  - `InteractionEventData.m` - 交互事件数据类
- `+utils/` - 工具函数（`Logger.m` 日志系统）

### 核心模式

```matlab
% 实验类必须继承 ExperimentBase 并实现:
classdef Exp3_X_Name < experiments.ExperimentBase
    methods (Access = protected)
        function setupExperimentUI(obj)  % 必须实现：构建实验界面
        end
    end
end
```

### 实验生命周期

1. `show()` → `createMainWindow()` → `showInfoPanel()` (实验说明)
2. 用户点击"开始实验" → `startExperiment()` → `showExperimentPanel()` → `setupExperimentUI()`
3. 实验完成 → `completeExperiment()` → `showDiscussionPanel()` (思考题)
4. 切换讨论/实验 → `restoreExperimentUI()` (恢复图形和状态)
5. 关闭窗口 → `onClose()` → `onCleanup()` (子类重写释放资源)

## 关键约定

### 实验属性设置 (构造函数中)

```matlab
obj.ExpNumber = '实验3-X';
obj.ExpTitle = '实验名称';
obj.ExpPurpose = '实验目的...';
obj.ExpInstruments = '仪器列表...';
obj.ExpPrinciple = '原理说明（支持 T₁ 等 Unicode 下标）';
obj.ExpContent = '操作步骤...';
obj.ExpQuestions = {'问题1', '答案1'; '问题2', '答案2'};
```

### 样式应用

```matlab
ui.StyleConfig.applyButtonStyle(btn, 'primary');   % primary/secondary/success/warning/danger
ui.StyleConfig.applyAxesStyle(ax);                 % 坐标轴统一样式
ui.StyleConfig.centerWindow([1200, 800]);          % 窗口居中定位
ui.StyleConfig.getImagePath('logo.png');           % 资源路径（兼容部署环境）
```

### 面板布局 (setupExperimentUI)

基类已创建三个面板供子类使用:

- `obj.MainPanel` - 左侧实验操作区 (仿真、图表)
- `obj.ControlPanel` - 右上控制面板 (参数输入)
- `obj.DataPanel` - 右下数据面板 (表格、结果)

### ExperimentGuide 集成（必须）

每个实验子类**必须**在步骤方法中集成引导系统，否则引导面板不会推进：

```matlab
function myStepMethod(obj)
    % 1. 前置校验
    [canProceed, ~] = obj.checkOperationValid('step_id');
    if ~canProceed, return; end

    % 2. 执行步骤逻辑
    % ... 业务代码 ...

    % 3. 完成步骤 + 提示下一步
    obj.ExpGuide.completeStep('step_id');
    obj.showNextStepHint();
end
```

对于 RepeatGroup（多次测量），使用动态 step_id：

```matlab
stepId = sprintf('measure_%d', obj.MeasureCount + 1);
obj.ExpGuide.completeStep(stepId);
```

### findobj 安全规范

**所有** `findobj` 调用必须添加空值检查，防止 UI 组件不存在时崩溃：

```matlab
lbl = findobj(obj.ControlPanel, 'Tag', 'MyLabel');
if ~isempty(lbl), lbl.Text = 'new value'; end
```

**禁止**使用 `parent.Children(end)` 来定位组件——MATLAB 的 Children 顺序是反向创建顺序，非常脆弱。应使用 `findobj` + Tag 或 Text 属性：

```matlab
% ✗ 不要这样做
instGrid.Children(end).Tag = 'MyTag';

% ✓ 正确做法
lbl = findobj(instGrid, 'Text', '目标文字');
if ~isempty(lbl), lbl.Tag = 'MyTag'; end
```

### 按钮初始状态

"完成实验"按钮初始状态**必须**为 `'disabled'`，在最后一个计算/分析步骤完成后才启用：

```matlab
obj.BtnComplete = obj.createExpButton(btnGrid, '完成实验', ...
    @(~,~) obj.completeExperiment(), 'disabled', row, col);
```

### 资源清理

使用 Timer 或外部资源时**必须**重写 `onCleanup()`:

```matlab
function onCleanup(obj)
    if ~isempty(obj.RecordTimer) && isvalid(obj.RecordTimer)
        stop(obj.RecordTimer);
        delete(obj.RecordTimer);
    end
end
```

### restoreExperimentUI 规范

从讨论页面返回时，`restoreExperimentUI()` 必须恢复完整状态，不能仅调用 `setupExperimentUI`：

```matlab
function restoreExperimentUI(obj)
    obj.setupExperimentUI();
    obj.drawApparatus();             % 重绘仪器图
    % 恢复温度/读数显示
    obj.TempDisplay.Text = sprintf('%.1f °C', obj.CurrentTemp);
    % 恢复数据曲线
    if ~isempty(obj.DataX)
        obj.updateCurve();
    end
end
```

### 局部变量命名

避免局部变量名与类属性名冲突（MATLAB 会产生编译警告）。直接写 `obj.propName` 赋值，不要用同名中间变量：

```matlab
% ✗ 会警告："存在一个名为 't_A' 的属性"
t_A = obj.CoolingTime(idx);
obj.t_A = t_A;

% ✓ 直接赋值
obj.t_A = obj.CoolingTime(idx);
```

## 常用命令

| 操作              | 命令               |
| ----------------- | ------------------ |
| 启动系统          | `startup; main`    |
| 编译 EXE          | `buildExe`         |
| 含 Runtime 安装包 | `buildWithRuntime` |

## 新增实验检查清单

1. 在 `+experiments/` 创建 `Exp3_X_Name.m`，继承 `ExperimentBase`
2. 构造函数设置 `ExpNumber`, `ExpTitle`, `ExpPurpose` 等属性
3. 实现 `setupExperimentUI()` 构建界面
4. 实现 `setupExperimentGuide()` 定义步骤、前置条件、RepeatGroups
5. **每个步骤方法**中调用 `checkOperationValid` / `completeStep` / `showNextStepHint`
6. 所有 `findobj` 调用添加 `if ~isempty(...)` 防护
7. "完成实验"按钮初始状态设为 `'disabled'`
8. 实现 `restoreExperimentUI()` 恢复完整图形和数据状态
9. Timer/文件句柄等资源需在 `onCleanup()` 中释放
10. 在 `core.AppConfig.ExperimentList` 添加条目: `{'实验3-X', '名称', 'Exp3_X_Name'}`

## 注意事项

- 版本号唯一真值源：`core.AppConfig.Version`，其他位置动态读取，禁止硬编码
- 最低支持 MATLAB R2020a (`uigridlayout` 依赖)
- 颜色使用 RGB 归一化值 `[0-1, 0-1, 0-1]`
- 部署环境资源路径通过 `ctfroot` 解析，使用 `StyleConfig.getImagePath()` 获取
- 窗口使用 `Tag` 属性标识，通过 `findobj('Tag', ...)` 查找和关闭
- `drawApparatus` 等绑定到 `uiaxes` 的绘图方法中，`hold(ax, 'on')` 后必须有对应的 `hold(ax, 'off')`
- 死代码（声明但未使用的属性/方法）应及时清理，避免维护负担
