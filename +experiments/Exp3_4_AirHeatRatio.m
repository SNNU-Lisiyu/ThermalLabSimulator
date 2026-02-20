classdef Exp3_4_AirHeatRatio < experiments.ExperimentBase
    % Exp3_4_AirHeatRatio 实验3-4 空气比热容比的测量
    % 用绝热膨胀法测量空气的比热容比γ

    properties (Access = private)
        % UI组件
        SimulationAxes      % 仿真显示区域
        PVCurveAxes         % P-V曲线

        % 仪器显示
        PressureDisplay     % 压强显示 (数字电压表)
        TempDisplay         % 温度显示 (数字电压表)
        AtmPressureDisplay  % 大气压强显示

        % 控制按钮
        BtnPreheat          % 预热
        BtnMeasureP0        % 测量大气压
        BtnOpenValve        % 打开放气阀
        BtnZeroPressure     % 调零
        BtnPumpAir          % 打气
        BtnWaitStable1      % 等待稳定(状态I)
        BtnReleaseAir       % 迅速放气
        BtnWaitStable2      % 等待稳定(状态III)
        BtnRecordData       % 记录数据
        BtnCalculate        % 计算γ
        BtnNextMeasure      % 下一次测量
        BtnComplete         % 完成实验

        % 参数显示标签（缓存，避免 findobj）
        LblP0               % 大气压强值标签
        LblDeltaP1           % 状态I压强差值标签
        LblDeltaP2           % 状态III压强差值标签
        LblP1                % 状态I压强值标签
        LblP2                % 状态III压强值标签
        LblGamma             % 比热容比值标签
        LblValveStatus       % 阀门状态标签
        LblResultGamma       % 结果γ值标签
        LblResultError       % 结果误差标签

        % 实验数据
        RoomTemp = 20           % 室温 (°C)
        P0 = 101325             % 大气压强 (Pa)
        P0_mV = 0               % 大气压强对应电压值 (mV)

        % 当前状态
        CurrentPressure_mV = 0  % 当前压强电压值 (mV)
        CurrentTemp_mV = 0      % 当前温度电压值 (mV)
        CurrentTemp = 20        % 当前温度 (°C)

        % 状态参数
        DeltaP1_mV = 0          % 状态I压强差 (mV)
        DeltaP2_mV = 0          % 状态III压强差 (mV)
        P1 = 0                  % 状态I压强 (Pa)
        P2 = 0                  % 状态III压强 (Pa)

        IsPreheated = false     % 是否已预热
        IsZeroed = false        % 是否已调零
        ValveOpen = true        % 放气阀状态(true=开)
        AirPumped = false       % 是否已打气

        % 数据记录
        MeasurementCount = 0    % 测量次数
        MeasureData = []        % 测量数据: [P0, DeltaP1, DeltaP2, P1, P2, gamma]

        % 动画计时器
        AnimTimer               % 动画计时器
        AnimPhase = 0           % 动画当前步数
        AnimCancelled = false   % 动画是否被取消（用于阻止 StopFcn 回调）

        % 计算结果
        Gamma_measured = 0      % 测得的γ值
    end

    properties (Constant)
        % 物理常数
        PRESSURE_SENSITIVITY = 0.05  % 压力传感器灵敏度 kPa/mV
        TEMP_SENSITIVITY = 5         % 温度传感器灵敏度 mV/K
        Gamma_standard = 1.402       % 空气比热容比理论值

        % 实验阶段常量
        STAGE_INIT = 0
        STAGE_PREHEATED = 1
        STAGE_ZEROED = 2
        STAGE_PUMPED = 3
        STAGE_STABLE1 = 4
        STAGE_RELEASED = 5
        STAGE_VALVE_CLOSED = 6
        STAGE_STABLE2 = 7
    end

    methods (Access = public)
        function obj = Exp3_4_AirHeatRatio()
            % 构造函数
            obj@experiments.ExperimentBase();

            % 设置实验基本信息
            obj.ExpNumber = '实验3-4';
            obj.ExpTitle = '空气比热容比的测量';

            % 实验目的
            obj.ExpPurpose = ['1. 观察热力学过程中气体的状态变化' newline ...
                '2. 用绝热膨胀法测量空气的比热容比' newline ...
                '3. 学习用硅压力传感器和电流型集成温度传感器测压强和温度的原理和方法'];

            % 实验仪器
            obj.ExpInstruments = ['贮气瓶、硅压力传感器、电流型集成温度传感器AD590、数字电压表、电阻(5kΩ)、稳压电源(6V)、导线(3根)、福廷式气压计'];

            % 实验原理
            obj.ExpPrinciple = [
                '【比热容比定义】' newline ...
                '理想气体的定压比热容Cp和定容比热容Cv之比 γ = Cp/Cv 称为气体的比热容比，又称气体的绝热指数，' ...
                '它是一个常用的物理量，在热力学理论及工程技术的应用中起着重要的作用。' newline newline ...
                '【实验原理】' newline ...
                '空气比热容比测量装置由贮气瓶、进气阀、放气阀、打气球、硅压力传感器PT14和' ...
                '电流型集成温度传感器AD590等组成。' newline newline ...
                '实验过程包含以下热力学状态变化：' newline ...
                '① 初始状态A(P₀, Vₐ, T₀)：瓶内气体与大气同温同压' newline ...
                '② 绝热压缩至状态B(Pᵦ, V₁, T₁)：打气充气，压强增大，温度升高' newline ...
                '③ 等容放热至状态I：C(P₁, V₁, T₀)：与外界热交换达到室温' newline ...
                '④ 绝热膨胀至状态II：D(P₀, V₂, T₂)：迅速放气，温度降低' newline ...
                '⑤ 等容吸热至状态III：E(P₂, V₂, T₀)：与外界热交换回到室温' newline newline ...
                '【计算公式】' newline ...
                '根据绝热方程和理想气体状态方程，可得：' newline ...
                '    γ = (ln P₁ - ln P₀) / (ln P₁ - ln P₂)' newline newline ...
                '由于压力传感器测量的是压强差，所以：' newline ...
                '    P₁ = P₀ + ΔP₁，P₂ = P₀ + ΔP₂' newline ...
                '其中 ΔP₁ 和 ΔP₂ 由数字电压表读数乘以0.05 kPa/mV得到。' newline newline ...
                '【理论值】' newline ...
                '室温时干燥空气中：氧气(O₂)约占21%，氮气(N₂)约占78%，氩气(Ar)约占1%' newline ...
                '空气比热容比的理论值为：γ理论 ≈ 1.402'];

            % 实验内容
            obj.ExpContent = [
                '1. 连接实验装置' newline ...
                '   按图3-4-1连接好实验装置及测试电路，启动测量仪器，预热10~15 min。' newline newline ...
                '2. 测量大气压强' newline ...
                '   由福廷式气压计测量大气压强P₀。' newline newline ...
                '3. 调零' newline ...
                '   打开放气阀，使贮气瓶与大气相通，通过调零旋钮使记录压强的数字电压表显示为0.0 mV，' ...
                '   记录(0, T₀)。' newline newline ...
                '4. 打气并记录状态I' newline ...
                '   ④ 关闭放气阀、打开进气阀，用打气球慢慢地将原处于环境压强P₀、室温T₀状态下的' ...
                '   空气经进气阀压入贮气瓶内，当记录压强的数字电压表示数在130~150 mV时，即可停止打气，' ...
                '   同时关闭进气阀。待系统稳定后，即数字电压表上压强的示数不再发生变化时，记录(ΔP₁, T₀)。' newline newline ...
                '5. 放气并记录状态III' newline ...
                '   ⑤ 迅速打开放气阀，听到嘭的一声，瓶内气体与大气相通，待瓶内压强降至P₀，即放气' ...
                '   声消失时，立刻关闭放气阀。待系统稳定后，即瓶内气体温度上升到室温T₀时，' ...
                '   数字电压表上压强的示数不再发生变化时，记录(ΔP₂, T₀)。' newline newline ...
                '6. 计算空气比热容比' newline ...
                '   ⑥ 将P₀(Pa)、ΔP₁(mV)、ΔP₂(mV)代入公式中，求出P₁和P₂的值，并计算空气的γ值。' newline newline ...
                '7. 重复测量' newline ...
                '   ⑦ 重复实验步骤③~⑤，测量6次，计算空气比热容比γ的平均值。' newline ...
                '   将实验结果γ与γ理论做比较，计算相对误差。'];

            % 思考讨论
            obj.ExpQuestions = {
                '如何检查系统是否漏气？如有漏气，对实验结果有何影响？', ...
                ['检查漏气的方法：' newline ...
                '1. 关闭所有阀门后，观察压强电压表示数是否缓慢下降' newline ...
                '2. 在各连接处涂抹肥皂水，观察是否有气泡产生' newline newline ...
                '漏气的影响：' newline ...
                '1. 如果系统漏气，在等待稳定过程中气体会持续泄漏' newline ...
                '2. 测得的P₁会偏小，导致计算的γ值偏小' newline ...
                '3. 严重漏气会使实验无法进行'];

                '本实验中测量温度为什么要用集成温度传感器？它有什么优点？可否用水银温度计来代替？', ...
                ['使用集成温度传感器AD590的原因和优点：' newline ...
                '1. 响应速度快，可以测量快速变化的温度' newline ...
                '2. 精度高，灵敏度达到5 mV/K' newline ...
                '3. 体积小，可直接置于贮气瓶内' newline ...
                '4. 可以实现电信号输出，便于数据记录' newline newline ...
                '不能用水银温度计代替，因为：' newline ...
                '1. 水银温度计响应太慢，无法跟踪快速变化的温度' newline ...
                '2. 水银温度计无法直接给出电信号' newline ...
                '3. 需要测量的温度变化很小（约0.02 K），水银温度计精度不够'];

                '本实验中，为何放气声消失时，必须迅速关闭放气阀？提早关闭或者推迟关闭，对实验结果会有什么影响？', ...
                ['必须在放气声消失时迅速关闭放气阀的原因：' newline ...
                '放气声消失表示瓶内压强刚好降至大气压P₀，此时对应状态II（绝热膨胀终态）。' newline newline ...
                '提早关闭的影响：' newline ...
                '1. 瓶内压强高于P₀，不是理想的绝热膨胀终态' newline ...
                '2. 会使测得的P₂偏大，导致γ值偏小' newline newline ...
                '推迟关闭的影响：' newline ...
                '1. 外界空气会进入瓶内，破坏绝热条件' newline ...
                '2. 瓶内气体已开始与外界换热，不再是纯绝热过程' newline ...
                '3. 会使实验结果产生系统误差'];

                '对状态变化:C(P₁,V₁,T₀)→D(P₀,V₂,T₂)→E(P₂,V₂,T₀)，分别选择参量(P,V)和(V,T)，推导比热容比的计算式。', ...
                ['选择参量(P,V)推导：' newline ...
                '绝热过程：P₁V₁^γ = P₀V₂^γ  ①' newline ...
                '等容过程：P₀/T₂ = P₂/T₀  ②' newline ...
                '由①②消去V，得：(P₁/P₀)^(γ-1) = (P₂/P₀)^γ' newline ...
                '取对数：γ = (lnP₁ - lnP₀)/(lnP₁ - lnP₂)' newline newline ...
                '选择参量(V,T)推导：' newline ...
                '绝热过程：T₀V₁^(γ-1) = T₂V₂^(γ-1)  ③' newline ...
                '等容过程：V₂不变' newline ...
                '由等温过程：P₁V₁ = P₀Vₐ，P₂V₂ = P₀Vₐ（Vₐ为初态体积）' newline ...
                '结合③式，可得：γ = T₀(lnP₁ - lnP₀) / [T₀(lnP₁ - lnP₂)]' newline ...
                '化简得：γ = (lnP₁ - lnP₀)/(lnP₁ - lnP₂)'];
                };

            % 初始化温度
            obj.CurrentTemp = obj.RoomTemp;
            obj.CurrentTemp_mV = obj.RoomTemp * obj.TEMP_SENSITIVITY;
        end
    end

    methods (Access = protected)
        function setupExperimentUI(obj)
            % 设置实验界面
            try
                % 设置父面板属性以支持Grid布局
                obj.MainPanel.AutoResizeChildren = 'off';
                obj.ControlPanel.AutoResizeChildren = 'off';
                obj.DataPanel.AutoResizeChildren = 'off';

                % ==================== 主实验区域（左侧）====================
                % 使用 3行1列 布局：[绘图区; 仪器区; 操作区]
                mainLayout = uigridlayout(obj.MainPanel, [3, 1], ...
                    'RowHeight', {'1x', 130, 180}, ...
                    'Padding', [10, 10, 10, 10], ...
                    'RowSpacing', 10, ...
                    'BackgroundColor', ui.StyleConfig.PanelColor);

                % ---------- 1. 绘图区域 (1行2列) ----------
                plotGrid = uigridlayout(mainLayout, [1, 2], ...
                    'ColumnWidth', {'1x', '1x'}, ...
                    'Padding', [0, 0, 0, 0], ...
                    'ColumnSpacing', 10, ...
                    'BackgroundColor', ui.StyleConfig.PanelColor);
                plotGrid.Layout.Row = 1;
                plotGrid.Layout.Column = 1;

                % 仿真显示区域
                obj.SimulationAxes = uiaxes(plotGrid);
                obj.SimulationAxes.Layout.Row = 1;
                obj.SimulationAxes.Layout.Column = 1;
                obj.SimulationAxes.XTick = [];
                obj.SimulationAxes.YTick = [];
                obj.SimulationAxes.Box = 'on';
                obj.SimulationAxes.Color = ui.StyleConfig.SimulationBgColor;
                title(obj.SimulationAxes, '空气比热容比测量装置', ...
                    'FontName', ui.StyleConfig.FontFamily, 'Color', ui.StyleConfig.TextPrimary);

                % P-V曲线区域
                obj.PVCurveAxes = uiaxes(plotGrid);
                obj.PVCurveAxes.Layout.Row = 1;
                obj.PVCurveAxes.Layout.Column = 2;
                ui.StyleConfig.applyAxesStyle(obj.PVCurveAxes);
                title(obj.PVCurveAxes, 'P-V状态变化图', ...
                    'FontName', ui.StyleConfig.FontFamily, 'Color', ui.StyleConfig.TextPrimary);
                xlabel(obj.PVCurveAxes, '体积 V');
                ylabel(obj.PVCurveAxes, '压强 P');

                % 绘制初始图形
                obj.drawApparatus();
                obj.drawPVDiagram();

                % ---------- 2. 仪器读数区域 ----------
                instrumentPanel = uipanel(mainLayout, ...
                    'Title', '仪器读数', ...
                    'FontName', ui.StyleConfig.FontFamily, ...
                    'FontSize', ui.StyleConfig.FontSizeNormal, ...
                    'FontWeight', 'bold', ...
                    'BackgroundColor', ui.StyleConfig.PanelColor, ...
                    'ForegroundColor', ui.StyleConfig.TextPrimary, ...
                    'AutoResizeChildren', 'off');
                instrumentPanel.Layout.Row = 2;
                instrumentPanel.Layout.Column = 1;

                % 仪器布局 (2行3列)
                instGrid = uigridlayout(instrumentPanel, [2, 3], ...
                    'ColumnWidth', {'1x', '1x', '1x'}, ...
                    'RowHeight', {'1x', 30}, ...
                    'Padding', [5, 5, 5, 5], ...
                    'RowSpacing', 5, 'ColumnSpacing', 10, ...
                    'BackgroundColor', ui.StyleConfig.PanelColor);

                % G1: 压强显示
                obj.PressureDisplay = obj.createInstrumentDisplay(instGrid, '压强显示', '0.0 mV', ...
                    ui.StyleConfig.ThermometerColor, 1, 1);

                % G2: 温度显示
                obj.TempDisplay = obj.createInstrumentDisplay(instGrid, '温度显示', ...
                    sprintf('%.1f mV', obj.CurrentTemp_mV), ui.StyleConfig.BalanceColor, 1, 2);

                % G3: 大气压强
                obj.AtmPressureDisplay = obj.createInstrumentDisplay(instGrid, '大气压强', ...
                    '待测量', ui.StyleConfig.VoltmeterColor, 1, 3);

                % G4: 室温显示
                roomTempText = sprintf('室温 T₀: %.1f°C (%.1f K)', obj.RoomTemp, obj.RoomTemp + 273.15);
                obj.createSimpleLabel(instGrid, roomTempText, 'left', ui.StyleConfig.TextSecondary, 2, 1);

                % G5: 阀门状态
                lblValve = obj.createSimpleLabel(instGrid, '放气阀: 开', 'center', [0.2, 0.6, 0.2], 2, 2);
                obj.LblValveStatus = lblValve;

                % G6: 灵敏度说明
                obj.createSimpleLabel(instGrid, '压力灵敏度: 0.05 kPa/mV', 'right', ui.StyleConfig.TextSecondary, 2, 3);



                % ---------- 3. 操作按钮区域 ----------
                btnPanel = uipanel(mainLayout, ...
                    'Title', '实验操作', ...
                    'FontName', ui.StyleConfig.FontFamily, ...
                    'FontSize', ui.StyleConfig.FontSizeNormal, ...
                    'FontWeight', 'bold', ...
                    'BackgroundColor', ui.StyleConfig.PanelColor, ...
                    'ForegroundColor', ui.StyleConfig.TextPrimary, ...
                    'AutoResizeChildren', 'off');
                btnPanel.Layout.Row = 3;
                btnPanel.Layout.Column = 1;

                % 按钮网格布局 (3行5列)
                btnGrid = uigridlayout(btnPanel, [3, 5], ...
                    'ColumnWidth', repmat({'1x'}, 1, 5), ...
                    'RowHeight', {'1x', '1x', '1x'}, ...
                    'Padding', [5, 5, 5, 5], ...
                    'RowSpacing', 5, 'ColumnSpacing', 5);


                % Row 1
                obj.BtnPreheat = obj.createExpButton(btnGrid, '1.预热仪器', @(~,~) obj.preheatInstrument(), 'primary', 1, 1);
                obj.BtnMeasureP0 = obj.createExpButton(btnGrid, '2.测量大气压', @(~,~) obj.measureAtmPressure(), 'disabled', 1, 2);
                obj.BtnOpenValve = obj.createExpButton(btnGrid, '3.打开放气阀', @(~,~) obj.openValve(), 'disabled', 1, 3);
                obj.BtnZeroPressure = obj.createExpButton(btnGrid, '4.调零', @(~,~) obj.zeroPressure(), 'disabled', 1, 4);
                obj.BtnPumpAir = obj.createExpButton(btnGrid, '5.关阀打气', @(~,~) obj.pumpAir(), 'disabled', 1, 5);

                % Row 2
                obj.BtnWaitStable1 = obj.createExpButton(btnGrid, '6.等待稳定I', @(~,~) obj.waitStable1(), 'disabled', 2, 1);
                obj.BtnReleaseAir = obj.createExpButton(btnGrid, '7.迅速放气', @(~,~) obj.releaseAir(), 'disabled', 2, 2);
                obj.BtnWaitStable2 = obj.createExpButton(btnGrid, '8.等待稳定III', @(~,~) obj.waitStable2(), 'disabled', 2, 3);
                obj.BtnRecordData = obj.createExpButton(btnGrid, '9.记录数据', @(~,~) obj.recordData(), 'disabled', 2, 4);
                obj.BtnCalculate = obj.createExpButton(btnGrid, '10.计算γ值', @(~,~) obj.calculateGamma(), 'disabled', 2, 5);

                % Row 3
                obj.BtnNextMeasure = obj.createExpButton(btnGrid, '继续测量', @(~,~) obj.nextMeasurement(), 'secondary', 3, 1);
                obj.BtnNextMeasure.Enable = 'off';

                obj.BtnComplete = obj.createExpButton(btnGrid, '完成实验', @(~,~) obj.completeExperiment(), 'disabled', 3, 4);

                % 重置按钮
                resetBtn = uibutton(btnGrid, 'Text', '重置实验', ...
                    'ButtonPushedFcn', @(~,~) obj.resetExperiment());
                resetBtn.Layout.Row = 3;
                resetBtn.Layout.Column = 5;
                ui.StyleConfig.applyButtonStyle(resetBtn, 'warning');


                % ==================== 右侧面板 ====================

                % ---------- 参数控制面板 (右上) ----------
                controlGrid = ui.StyleConfig.createControlPanelGrid(obj.ControlPanel, 7);

                % 标题
                titleLbl = ui.StyleConfig.createPanelTitle(controlGrid, '实验参数');
                titleLbl.Layout.Row = 1;
                titleLbl.Layout.Column = [1, 2];

                paramLabels = {'大气压强 P₀:', '状态I压强差 ΔP₁:', '状态III压强差 ΔP₂:', ...
                    '状态I压强 P₁:', '状态III压强 P₂:', '比热容比 γ:'};

                paramValueHandles = cell(1, length(paramLabels));
                for i = 1:length(paramLabels)
                    l = ui.StyleConfig.createParamLabel(controlGrid, paramLabels{i});
                    l.Layout.Row = i + 1;
                    l.Layout.Column = 1;

                    v = ui.StyleConfig.createParamValue(controlGrid, '待测量');
                    v.Layout.Row = i + 1;
                    v.Layout.Column = 2;
                    paramValueHandles{i} = v;
                end
                obj.LblP0 = paramValueHandles{1};
                obj.LblDeltaP1 = paramValueHandles{2};
                obj.LblDeltaP2 = paramValueHandles{3};
                obj.LblP1 = paramValueHandles{4};
                obj.LblP2 = paramValueHandles{5};
                obj.LblGamma = paramValueHandles{6};

                % ---------- 实验数据面板 (右下) ----------
                dataPanelGrid = ui.StyleConfig.createDataPanelGrid(obj.DataPanel, '1x', 100);

                % Title
                titleData = ui.StyleConfig.createPanelTitle(dataPanelGrid, '实验数据');
                titleData.Layout.Row = 1;

                % 数据表格
                obj.DataTable = ui.StyleConfig.createDataTable(dataPanelGrid, ...
                    {'序号', 'ΔP₁(mV)', 'ΔP₂(mV)', 'P₁(Pa)', 'P₂(Pa)', 'γ'}, ...
                    {40, 60, 60, 70, 70, 60});
                obj.DataTable.Layout.Row = 2;
                obj.DataTable.Data = {};
                obj.DataTable.RowName = {};

                % 结果区域
                resultGrid = ui.StyleConfig.createResultGrid(dataPanelGrid, 3);
                resultGrid.Layout.Row = 3;

                % Title 和 标准值显示
                titleRes = ui.StyleConfig.createResultLabel(resultGrid, '计算结果');
                titleRes.Layout.Row = 1;
                titleRes.Layout.Column = 1;
                titleRes.FontWeight = 'bold';
                titleRes.HorizontalAlignment = 'center';

                stdText = sprintf('(理论值 γ = %.3f)', obj.Gamma_standard);
                stdLbl = ui.StyleConfig.createResultLabel(resultGrid, stdText);
                stdLbl.Layout.Row = 1;
                stdLbl.Layout.Column = 2;
                stdLbl.HorizontalAlignment = 'left';

                % Gamma Avg
                lbl1 = ui.StyleConfig.createResultLabel(resultGrid, 'γ平均 =');
                lbl1.Layout.Row = 2;
                lbl1.Layout.Column = 1;
                gammaVal = ui.StyleConfig.createResultValue(resultGrid, '待计算');
                gammaVal.Layout.Row = 2;
                gammaVal.Layout.Column = 2;
                obj.LblResultGamma = gammaVal;

                % Error
                lbl2 = ui.StyleConfig.createResultLabel(resultGrid, '相对误差 =');
                lbl2.Layout.Row = 3;
                lbl2.Layout.Column = 1;
                errVal = ui.StyleConfig.createResultValue(resultGrid, '待计算');
                errVal.Layout.Row = 3;
                errVal.Layout.Column = 2;
                obj.LblResultError = errVal;

                % 初始化实验引导系统
                obj.setupExperimentGuide();

                obj.updateStatus('准备开始实验，请按步骤操作');
                drawnow;

            catch ME
                utils.Logger.logError(ME, 'Exp3_4_AirHeatRatio.setupExperimentUI');
                uialert(obj.Figure, sprintf('UI初始化失败:\n%s\nFile: %s\nLine: %d', ...
                    ME.message, ME.stack(1).name, ME.stack(1).line), '程序错误');
            end
        end

        function drawApparatus(obj)
            % 绘制实验装置示意图（优化版）
            ax = obj.SimulationAxes;
            cla(ax);
            hold(ax, 'on');

            % 设置背景
            ax.Color = [0.98, 0.98, 0.98];

            % 定义颜色
            wireColorTemp = [0.2, 0.6, 0.2];      % 温度传感器导线 (绿)
            wireColorPress = [0.2, 0.4, 0.8];     % 压力传感器导线 (蓝)
            wireColorPower = [0.8, 0.3, 0.3];     % 电源线 (红)
            pipeColor = [0.6, 0.6, 0.6];          % 管道颜色
            glassColor = [0.8, 0.9, 0.95];        % 玻璃瓶颜色
            gasColorNormal = [0.9, 0.95, 1.0];    % 常态气体
            gasColorCompressed = [0.75, 0.85, 1.0]; % 压缩气体

            % 确定瓶内气体颜色
            if obj.AirPumped && ~obj.ValveOpen
                currentGasColor = gasColorCompressed;
            else
                currentGasColor = gasColorNormal;
            end

            % ==================== 1. 仪器外壳与布局 ====================

            % --- 左侧电子架 (虚拟面板) ---
            % 稳压电源区域 (左上 -> 下移至中部，避开打气球)
            posPower = [0.02, 0.45, 0.14, 0.18];
            rectangle(ax, 'Position', posPower, 'Curvature', 0.1, ...
                'FaceColor', [0.9, 0.9, 0.9], 'EdgeColor', [0.4, 0.4, 0.4]);

            % 数字电压表(温度)区域 (左中 -> 下移至底部)
            posTempMeter = [0.02, 0.15, 0.14, 0.20];
            rectangle(ax, 'Position', posTempMeter, 'Curvature', 0.1, ...
                'FaceColor', [0.2, 0.2, 0.25], 'EdgeColor', 'none');

            % --- 右侧电子架 ---
            % 数字电压表(压强)区域 (右中)
            posPressMeter = [0.84, 0.35, 0.14, 0.20];
            rectangle(ax, 'Position', posPressMeter, 'Curvature', 0.1, ...
                'FaceColor', [0.2, 0.2, 0.25], 'EdgeColor', 'none');


            % ==================== 2. 气路系统 ====================

            % 定义中心储气瓶位置
            bottleW = 0.35; bottleH = 0.55;
            bottleX = 0.5 - bottleW/2; bottleY = 0.15;
            bottleNeckW = 0.08; bottleNeckH = 0.08;

            % 瓶塞几何参数
            stopperH = 0.04;
            stopperY = bottleY + bottleH + bottleNeckH - 0.02; % 瓶塞底部Y
            stopperTopY = stopperY + stopperH;                 % 瓶塞顶部Y

            % 瓶塞中心点
            cNeckX = 0.5;
            cNeckY = stopperTopY;

            % --- 顶部主管道 ---
            pipeY = cNeckY + 0.05;  % 管道水平高度
            pipeX_Left = 0.18;      % 管道左端(打气球)
            pipeX_Right = 0.75;     % 管道右端(放气口)

            % 绘制横向主管道
            plot(ax, [pipeX_Left, pipeX_Right], [pipeY, pipeY], 'Color', pipeColor, 'LineWidth', 6);
            % 管道内芯
            plot(ax, [pipeX_Left, pipeX_Right], [pipeY, pipeY], 'Color', [0.85, 0.85, 0.85], 'LineWidth', 2);

            % --- 竖向连接管 (连接瓶子) ---
            plot(ax, [cNeckX, cNeckX], [cNeckY, pipeY], 'Color', pipeColor, 'LineWidth', 6);
            plot(ax, [cNeckX, cNeckX], [cNeckY, pipeY], 'Color', [0.85, 0.85, 0.85], 'LineWidth', 2);

            % T型接头覆盖
            plot(ax, cNeckX, pipeY, 'o', 'MarkerSize', 8, 'MarkerFaceColor', pipeColor, 'MarkerEdgeColor', 'none');

            % --- 储气瓶 (大肚瓶) ---
            % 瓶身
            rectangle(ax, 'Position', [bottleX, bottleY, bottleW, bottleH], ...
                'Curvature', [0.2, 0.2], 'FaceColor', currentGasColor, ...
                'EdgeColor', glassColor, 'LineWidth', 2, 'LineStyle', '-');
            % 瓶颈
            rectangle(ax, 'Position', [0.5-bottleNeckW/2, bottleY+bottleH, bottleNeckW, bottleNeckH], ...
                'FaceColor', currentGasColor, 'EdgeColor', glassColor, 'LineWidth', 2);
            % 瓶塞
            rectangle(ax, 'Position', [0.5-0.045, stopperY, 0.09, stopperH], ...
                'Curvature', 0.2, 'FaceColor', [0.4, 0.35, 0.3], 'EdgeColor', 'none');

            % --- 气路组件 ---

            % 1. 打气球 (最左侧)
            pumpX = pipeX_Left - 0.04; pumpY = pipeY;
            % 绘制球体
            theta = linspace(0, 2*pi, 100);
            fill(ax, pumpX + 0.035*cos(theta), pumpY + 0.035*sin(theta), ...
                [0.2, 0.2, 0.2], 'EdgeColor', 'none');
            % 喷嘴连接
            plot(ax, [pumpX, pipeX_Left], [pumpY, pipeY], 'Color', [0.2,0.2,0.2], 'LineWidth', 4);
            text(ax, pumpX, pumpY-0.06, '打气球', 'HorizontalAlignment', 'center', 'FontSize', 9);

            % 2. 进气阀 (左侧管路)
            valveInX = pipeX_Left + 0.12;
            % 阀体
            rectangle(ax, 'Position', [valveInX-0.02, pipeY-0.02, 0.04, 0.04], ...
                 'FaceColor', [0.7,0.7,0.7], 'EdgeColor', [0.4,0.4,0.4]);
            % 旋钮 (进气单向阀，通常无需操作，此处画为常态)
            plot(ax, [valveInX, valveInX], [pipeY, pipeY+0.04], 'Color', [0.4,0.4,0.4], 'LineWidth', 2);
            text(ax, valveInX, pipeY+0.06, '进气阀', 'HorizontalAlignment','center', 'FontSize', 8, 'Color', [0.4,0.4,0.4]);

            % 3. 放气阀 (右侧管路)
            valveOutX = pipeX_Right - 0.08;
            % 阀体
            rectangle(ax, 'Position', [valveOutX-0.025, pipeY-0.025, 0.05, 0.05], ...
                 'FaceColor', [0.8,0.8,0.8], 'EdgeColor', [0.4,0.4,0.4]);
            % 旋钮 handle
            if obj.ValveOpen
                handleAngle = 0; % 竖直为通/水平为通? 通常水平是顺管道方向开
                handleColor = [0.2, 0.7, 0.2];
            else
                handleAngle = pi/2; % 垂直管道为关
                handleColor = [0.8, 0.2, 0.2];
            end
            % 绘制旋钮
            knobLen = 0.04;
            plot(ax, [valveOutX - knobLen*cos(handleAngle), valveOutX + knobLen*cos(handleAngle)], ...
                 [pipeY + 0.04 - knobLen*sin(handleAngle), pipeY + 0.04 + knobLen*sin(handleAngle)], ...
                 'Color', handleColor, 'LineWidth', 5);
            % 旋钮杆
            plot(ax, [valveOutX, valveOutX], [pipeY, pipeY+0.04], 'Color', [0.5,0.5,0.5], 'LineWidth', 2);

            text(ax, valveOutX, pipeY+0.08, '放气阀', 'HorizontalAlignment','center', 'FontSize', 9, 'FontWeight','bold');

            % 4. 放气口 (最右侧)
            % 弯头向下
            plot(ax, [pipeX_Right, pipeX_Right], [pipeY, pipeY-0.03], 'Color', pipeColor, 'LineWidth', 6);
            plot(ax, [pipeX_Right, pipeX_Right], [pipeY, pipeY-0.03], 'Color', [0.9,0.9,0.9], 'LineWidth', 2);
            % 箭头指示
            if obj.ValveOpen && obj.ExpStage == obj.STAGE_RELEASED
                text(ax, pipeX_Right + 0.02, pipeY-0.02, '>>>', 'Rotation', -90, 'Color', 'r', 'FontSize', 10, 'FontWeight', 'bold');
            end

            % 打气动画指示 (空气进入瓶中)
            if obj.ExpStage == obj.STAGE_PUMPED
                 % 在瓶颈处画向下箭头
                 arrowX = 0.5; arrowY = bottleY + bottleH;
                 fill(ax, [arrowX-0.02, arrowX+0.02, arrowX], [arrowY, arrowY, arrowY-0.04], ...
                      [0.2, 0.6, 1.0], 'EdgeColor', 'none');
            end


            % ==================== 3. 瓶内传感器系统 ====================

            % 传感器位置
            sensorPX = 0.58; sensorPY = 0.45; % 压力传感器 (右侧)
            sensorTX = 0.42; sensorTY = 0.35; % 温度传感器 (左侧)

            % --- 压力传感器 (PT14) ---
            rectangle(ax, 'Position', [sensorPX-0.03, sensorPY-0.03, 0.06, 0.06], ...
                'Curvature', 0.2, 'FaceColor', [0.9, 0.9, 0.95], 'EdgeColor', [0.2, 0.4, 0.8]);
            text(ax, sensorPX, sensorPY, 'P', 'HorizontalAlignment', 'center', ...
                'Color', [0.2, 0.4, 0.8], 'FontWeight', 'bold');

            % --- 温度传感器 (AD590) ---
            % 金属管壳
            rectangle(ax, 'Position', [sensorTX-0.015, sensorTY-0.04, 0.03, 0.08], ...
                'Curvature', 0.5, 'FaceColor', [0.95, 0.95, 0.9], 'EdgeColor', [0.4, 0.4, 0.4]);
            text(ax, sensorTX, sensorTY, 'T', 'HorizontalAlignment', 'center', ...
                'Color', [0.2, 0.6, 0.2], 'FontWeight', 'bold');


            % ==================== 4. 电路连接 (正交走线) ====================

            % 分散瓶塞上的穿孔位置，避免重叠
            entryTempX = 0.46;    % 温度传感器入孔 (绿)
            entryPowerX = 0.49;   % 电源线入孔 (红)
            entryPressX = 0.54;   % 压力传感器入孔 (蓝)

            % --- 压力传感器线路 (蓝) ---
            % 路径: 传感器 -> 瓶塞入孔 -> 横向连接到右侧仪表
            % 线段1: 传感器竖直向上
            plot(ax, [sensorPX, sensorPX], [sensorPY+0.03, 0.55], 'Color', wireColorPress, 'LineWidth', 1.5);
            % 线段2: 斜向/横向汇聚到瓶塞入口? 内部可以斜线，外部正交
            plot(ax, [sensorPX, entryPressX], [0.55, stopperY], 'Color', wireColorPress, 'LineWidth', 1.5); % 瓶内斜线
            % 线段3: 穿在瓶塞中
            plot(ax, [entryPressX, entryPressX], [stopperY, stopperTopY], 'Color', wireColorPress, 'LineWidth', 1.5, 'LineStyle', ':');
            % 线段4: 瓶塞顶 -> 右侧压强表
            meterInY = 0.45; % 压强表输入端高度
            % 路径: 顶 -> 右折 -> 下 -> 右
            plot(ax, [entryPressX, entryPressX, 0.82, 0.82], ...
                 [stopperTopY, stopperTopY+0.02, stopperTopY+0.02, meterInY], ...
                 'Color', wireColorPress, 'LineWidth', 1.5);

            % --- 温度传感器线路 (绿: 信号线, 红: 电源线) ---
            % 电源与电阻位置
            pwrPlusX = posPower(1) + posPower(3)*0.85;  % 电源正极X
            pwrPlusY = posPower(2) + posPower(4)*0.25;  % 电源正极Y

            resistorX = 0.22;             % 电阻X位置 (放在电源和瓶子之间)
            resistorY = pwrPlusY - 0.02;  % 电阻Y位置

            % 1. 红线路径: 电源[+] -> 电阻 -> 瓶塞 -> 传感器
            % 电源 -> 电阻
            plot(ax, [pwrPlusX, pwrPlusX, resistorX], [pwrPlusY, resistorY, resistorY], ...
                 'Color', wireColorPower, 'LineWidth', 1.5);

            % 绘制电阻
            fill(ax, [resistorX-0.015, resistorX+0.015, resistorX+0.015, resistorX-0.015], ...
                 [resistorY-0.01, resistorY-0.01, resistorY+0.01, resistorY+0.01], ...
                 [0.9, 0.85, 0.8], 'EdgeColor', [0.6, 0.4, 0.2]);
            text(ax, resistorX, resistorY+0.02, '5kΩ', 'HorizontalAlignment', 'center', 'FontSize', 8);

            % 电阻 -> 瓶塞入孔 (先水平走到瓶下, 再向上? 不, 直接水平走再向上)
            % 路径: 电阻 -> 右 -> 上 -> 瓶塞入孔
            midX = 0.30; % 中间转折X
            plot(ax, [resistorX+0.015, midX, midX, entryPowerX, entryPowerX], ...
                 [resistorY, resistorY, stopperTopY+0.04, stopperTopY+0.04, stopperY], ...
                 'Color', wireColorPower, 'LineWidth', 1.5);

            % 瓶内: 瓶塞 -> 传感器[+]
            plot(ax, [entryPowerX, sensorTX+0.01], [stopperY, sensorTY+0.04], ...
                 'Color', wireColorPower, 'LineWidth', 1.5); % 瓶内斜线直连


            % 2. 绿线路径: 传感器 -> 瓶塞 -> 温度表
            % 瓶内: 传感器 -> 瓶塞
            plot(ax, [sensorTX-0.01, entryTempX], [sensorTY+0.04, stopperY], ...
                 'Color', wireColorTemp, 'LineWidth', 1.5);

            % 瓶外: 瓶塞 -> 温度表 (正交)
            tempMeterInY = posTempMeter(2) + posTempMeter(4)*0.8; % 温度表输入高度
            % 路径: 瓶塞顶 -> 上 -> 左 -> 下 -> 温度表
            plot(ax, [entryTempX, entryTempX, midX-0.02, midX-0.02, posTempMeter(1)+posTempMeter(3)], ...
                 [stopperY, stopperTopY+0.06, stopperTopY+0.06, tempMeterInY, tempMeterInY], ...
                 'Color', wireColorTemp, 'LineWidth', 1.5);

            % --- 稳压电源面板 ---
            % 屏幕
            rectangle(ax, 'Position', [posPower(1)+0.02, posPower(2)+0.08, posPower(3)-0.04, 0.05], ...
                'FaceColor', [0.2, 0.25, 0.2], 'EdgeColor', 'none');
            text(ax, posPower(1)+posPower(3)/2, posPower(2)+0.105, '6.00 V', ...
                'Color', 'g', 'FontName', 'Consolas', 'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
            text(ax, posPower(1)+posPower(3)/2, posPower(2)+0.04, '稳压电源', ...
                'Color', [0.3, 0.3, 0.3], 'HorizontalAlignment', 'center', 'FontSize', 9);
            % 接线柱
            plot(ax, pwrPlusX, pwrPlusY, 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 4);
            text(ax, pwrPlusX+0.01, pwrPlusY, '+', 'Color', 'r', 'FontSize', 10, 'FontWeight', 'bold');

            % --- 温度电压表 ---
            % 屏幕
            rectangle(ax, 'Position', [posTempMeter(1)+0.015, posTempMeter(2)+0.03, posTempMeter(3)-0.03, 0.12], ...
                'FaceColor', [0.1, 0.15, 0.1], 'EdgeColor', [0.4, 0.4, 0.4]);
            % 读数
            text(ax, posTempMeter(1)+posTempMeter(3)/2, posTempMeter(2)+0.09, sprintf('%.1f', obj.CurrentTemp_mV), ...
                'Color', [0, 1, 0], 'FontName', 'Consolas', 'HorizontalAlignment', 'center', 'FontSize', 14, 'FontWeight', 'bold');
            text(ax, posTempMeter(1)+posTempMeter(3)/2, posTempMeter(2)+0.01, '温度(mV)', ...
                'Color', 'w', 'HorizontalAlignment', 'center', 'FontSize', 8);

            % --- 压强电压表 ---
            % 屏幕
            rectangle(ax, 'Position', [posPressMeter(1)+0.015, posPressMeter(2)+0.03, posPressMeter(3)-0.03, 0.12], ...
                'FaceColor', [0.1, 0.15, 0.1], 'EdgeColor', [0.4, 0.4, 0.4]);
            % 读数
            text(ax, posPressMeter(1)+posPressMeter(3)/2, posPressMeter(2)+0.09, sprintf('%.1f', obj.CurrentPressure_mV), ...
                'Color', [0, 1, 0], 'FontName', 'Consolas', 'HorizontalAlignment', 'center', 'FontSize', 14, 'FontWeight', 'bold');
            text(ax, posPressMeter(1)+posPressMeter(3)/2, posPressMeter(2)+0.01, '压强(mV)', ...
                'Color', 'w', 'HorizontalAlignment', 'center', 'FontSize', 8);


            % ==================== 6. 环境与其他 ====================

            % 桌面
            % plot(ax, [0, 1], [0.1, 0.1], 'k-', 'LineWidth', 1);

            % 空气标签
            % text(ax, 0.5, 0.3, 'Air', 'Color', [0.4, 0.6, 0.8], 'FontSize', 20, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Rotation', 0, 'FontName', 'Arial');

            % 恢复坐标轴设置
            xlim(ax, [0, 1]);
            ylim(ax, [0, 1]);
            axis(ax, 'off');
            hold(ax, 'off');
        end

        function drawPVDiagram(obj)
            % 绘制P-V状态变化图
            ax = obj.PVCurveAxes;
            cla(ax);
            hold(ax, 'on');

            % 设置坐标范围
            xlim(ax, [0.5, 1.5]);
            ylim(ax, [0.8, 1.4]);

            % 绘制坐标轴标签
            xlabel(ax, '体积 V (归一化)');
            ylabel(ax, '压强 P (归一化)');

            % 参考线
            yline(ax, 1, 'k--', 'P₀', 'Alpha', 0.5, 'LineWidth', 1);

            if obj.ExpStage >= obj.STAGE_STABLE1
                % 状态点
                V1 = 0.7;  % 状态I的体积（压缩后）
                V2 = 1.0;  % 状态II、III的体积
                VA = 1.2;  % 初始体积

                P0_norm = 1;
                P1_norm = obj.P1 / obj.P0;
                P2_norm = obj.P2 / obj.P0;

                if obj.P1 > 0
                    P1_norm = max(1.01, min(1.35, P1_norm));
                else
                    P1_norm = 1.15;
                end
                if obj.P2 > 0
                    P2_norm = max(1.001, min(1.1, P2_norm));
                else
                    P2_norm = 1.03;
                end

                % 绘制状态点
                % A: 初始状态
                plot(ax, VA, P0_norm, 'ko', 'MarkerSize', 8, 'MarkerFaceColor', 'k');
                text(ax, VA + 0.05, P0_norm, 'A', 'FontSize', 10, 'FontWeight', 'bold');

                % C: 状态I (P1, V1, T0)
                plot(ax, V1, P1_norm, 'bo', 'MarkerSize', 8, 'MarkerFaceColor', 'b');
                text(ax, V1 - 0.08, P1_norm + 0.03, 'C(I)', 'FontSize', 10, 'FontWeight', 'bold', 'Color', 'b');

                if obj.ExpStage >= obj.STAGE_VALVE_CLOSED
                    % D: 状态II (P0, V2, T2) - 绝热膨胀后
                    plot(ax, V2, P0_norm, 'go', 'MarkerSize', 8, 'MarkerFaceColor', 'g');
                    text(ax, V2 + 0.03, P0_norm - 0.05, 'D(II)', 'FontSize', 10, 'FontWeight', 'bold', 'Color', 'g');

                    % 绘制绝热膨胀曲线 C->D
                    V_adiabatic = linspace(V1, V2, 50);
                    % P*V^gamma = const
                    gamma_approx = 1.4;
                    P_adiabatic = P1_norm * (V1 ./ V_adiabatic).^gamma_approx;
                    plot(ax, V_adiabatic, P_adiabatic, 'g-', 'LineWidth', 2);
                end

                if obj.ExpStage >= obj.STAGE_STABLE2
                    % E: 状态III (P2, V2, T0)
                    plot(ax, V2, P2_norm, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
                    text(ax, V2 + 0.03, P2_norm + 0.03, 'E(III)', 'FontSize', 10, 'FontWeight', 'bold', 'Color', 'r');

                    % 绘制等容吸热线 D->E
                    plot(ax, [V2, V2], [P0_norm, P2_norm], 'r-', 'LineWidth', 2);
                end

                % 添加图例说明
                text(ax, 0.55, 1.35, '状态变化:', 'FontSize', 9, 'FontWeight', 'bold');
                text(ax, 0.55, 1.30, 'C→D: 绝热膨胀', 'FontSize', 8, 'Color', 'g');
                text(ax, 0.55, 1.25, 'D→E: 等容吸热', 'FontSize', 8, 'Color', 'r');
            else
                % 初始状态：显示理论曲线
                text(ax, 0.75, 1.2, '等待实验数据...', 'FontSize', 12, 'Color', [0.5, 0.5, 0.5]);
            end

            hold(ax, 'off');
            title(ax, 'P-V状态变化图', 'FontName', ui.StyleConfig.FontFamily);
        end

        function preheatInstrument(obj)
            % 预热仪器（约15秒动画展示温度波动→稳定过程）
            [canProceed, ~] = obj.checkOperationValid('preheat');
            if ~canProceed, return; end

            obj.IsPreheated = true;
            obj.ExpStage = obj.STAGE_PREHEATED;
            obj.BtnPreheat.Enable = 'off';
            obj.updateStatus('仪器预热中，请等待温度稳定...');

            % 15步 × 1秒 ≈ 15秒预热动画
            obj.stopAnimation();
            obj.AnimCancelled = false;
            obj.AnimPhase = 0;
            obj.AnimTimer = timer('ExecutionMode', 'fixedRate', ...
                'Period', 1.0, ...
                'TasksToExecute', 15, ...
                'TimerFcn', @(~,~) obj.safeTimerCallback(@obj.preheatAnimStep), ...
                'StopFcn', @(tmr,~) obj.onAnimTimerDone(tmr, @obj.onPreheatComplete));
            start(obj.AnimTimer);
        end

        function preheatAnimStep(obj)
            % 预热动画单步：温度从偏低平滑上升到室温（模拟仪器冷启动升温）
            obj.AnimPhase = obj.AnimPhase + 1;
            if ~isvalid(obj.Figure), return; end

            step = obj.AnimPhase;
            % 从 RoomTemp-3°C 平滑上升到 RoomTemp
            offset = 3 * exp(-step / 4);
            obj.CurrentTemp = obj.RoomTemp - offset;
            obj.CurrentTemp_mV = obj.CurrentTemp * obj.TEMP_SENSITIVITY;

            % 统一更新所有显示
            tempStr = sprintf('%.1f mV', obj.CurrentTemp_mV);
            obj.TempDisplay.Text = tempStr;

            progress = round(step / 15 * 100);
            obj.updateStatus(sprintf('仪器预热中... %d%%  温度: %s', progress, tempStr));
            obj.drawApparatus();
        end

        function onPreheatComplete(obj)
            % 预热完成回调
            if obj.AnimCancelled || ~isvalid(obj.Figure), return; end

            % 最终温度稳定在室温
            obj.CurrentTemp = obj.RoomTemp;
            obj.CurrentTemp_mV = obj.CurrentTemp * obj.TEMP_SENSITIVITY;
            obj.TempDisplay.Text = sprintf('%.1f mV', obj.CurrentTemp_mV);
            obj.drawApparatus();

            obj.updateStatus('仪器预热完成，温度已稳定');
            obj.BtnMeasureP0.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnMeasureP0, 'primary');
            if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep('preheat'); end
            obj.showNextStepHint();
        end

        function measureAtmPressure(obj)
            % 测量大气压强
            [canProceed, ~] = obj.checkOperationValid('measure_p0');
            if ~canProceed, return; end

            % 模拟福廷式气压计测量（添加随机误差）
            obj.P0 = 101325 + randn() * 200;  % 标准大气压附近
            obj.AtmPressureDisplay.Text = sprintf('%.0f Pa', obj.P0);

            % 更新参数显示
            obj.safeSetText(obj.LblP0, sprintf('%.0f Pa', obj.P0));

            obj.updateStatus(sprintf('大气压强 P₀ = %.0f Pa', obj.P0));

            obj.BtnMeasureP0.Enable = 'off';
            obj.BtnOpenValve.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnOpenValve, 'primary');

            if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep('measure_p0'); end
            obj.showNextStepHint();
        end

        function openValve(obj)
            % 打开放气阀
            [canProceed, ~] = obj.checkOperationValid('open_valve');
            if ~canProceed, return; end

            obj.ValveOpen = true;
            obj.CurrentPressure_mV = 0;
            obj.PressureDisplay.Text = '0.0 mV';

            % 更新阀门状态显示
            if ~isempty(obj.LblValveStatus) && isvalid(obj.LblValveStatus)
                obj.LblValveStatus.Text = '放气阀: 开';
                obj.LblValveStatus.FontColor = [0.2, 0.6, 0.2];
            end

            obj.drawApparatus();
            obj.updateStatus('放气阀已打开，瓶内与大气相通');

            obj.BtnOpenValve.Enable = 'off';
            obj.BtnZeroPressure.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnZeroPressure, 'primary');

            if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep('open_valve'); end
            obj.showNextStepHint();
        end

        function zeroPressure(obj)
            % 调零
            [canProceed, ~] = obj.checkOperationValid('zero_pressure');
            if ~canProceed, return; end

            obj.IsZeroed = true;
            obj.ExpStage = obj.STAGE_ZEROED;
            obj.CurrentPressure_mV = 0;
            obj.PressureDisplay.Text = '0.0 mV';

            obj.updateStatus('压强电压表已调零，记录初始状态(0, T₀)');

            obj.BtnZeroPressure.Enable = 'off';
            obj.BtnPumpAir.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnPumpAir, 'primary');

            if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep('zero_pressure'); end
            obj.showNextStepHint();
        end

        function pumpAir(obj)
            % 关阀打气
            pumpStepId = sprintf('pump_%d', obj.MeasurementCount + 1);
            [canProceed, ~] = obj.checkOperationValid(pumpStepId);
            if ~canProceed, return; end

            obj.ValveOpen = false;
            obj.AirPumped = true;
            obj.ExpStage = obj.STAGE_PUMPED;
            obj.BtnPumpAir.Enable = 'off';

            % 更新阀门状态
            if ~isempty(obj.LblValveStatus) && isvalid(obj.LblValveStatus)
                obj.LblValveStatus.Text = '放气阀: 关';
                obj.LblValveStatus.FontColor = [0.7, 0.2, 0.2];
            end

            % 模拟打气过程：压强逐渐上升到130-150 mV
            targetPressure = 130 + rand() * 20;  % 130-150 mV

            % 非阻塞动画显示压强上升
            obj.animatePressureChange(0, targetPressure, 1.5, ...
                @() obj.onPumpAirComplete(targetPressure, pumpStepId));
        end

        function onPumpAirComplete(obj, targetPressure, pumpStepId)
            % 打气动画完成回调
            if ~isvalid(obj.Figure), return; end

            obj.CurrentPressure_mV = targetPressure;
            obj.PressureDisplay.Text = sprintf('%.1f mV', obj.CurrentPressure_mV);

            % 温度会因绝热压缩而升高
            obj.CurrentTemp = obj.RoomTemp + 2 + rand();  % 温度升高约2-3°C
            obj.CurrentTemp_mV = obj.CurrentTemp * obj.TEMP_SENSITIVITY;
            obj.TempDisplay.Text = sprintf('%.1f mV', obj.CurrentTemp_mV);

            obj.drawApparatus();
            obj.updateStatus(sprintf('打气完成，压强 = %.1f mV，等待系统稳定', obj.CurrentPressure_mV));

            obj.BtnWaitStable1.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnWaitStable1, 'primary');

            if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep(pumpStepId); end
            obj.showNextStepHint();
        end

        function waitStable1(obj)
            % 等待状态I稳定（等容放热）
            waitStepId = sprintf('wait1_%d', obj.MeasurementCount + 1);
            [canProceed, ~] = obj.checkOperationValid(waitStepId);
            if ~canProceed, return; end

            obj.ExpStage = obj.STAGE_STABLE1;
            obj.BtnWaitStable1.Enable = 'off';
            obj.updateStatus('等待系统达到热平衡(状态I)...');

            % 非阻塞模拟等容放热过程：温度回到室温
            obj.animateTempChange(obj.CurrentTemp, obj.RoomTemp, 1.5, ...
                @() obj.onWaitStable1Complete(waitStepId));
        end

        function onWaitStable1Complete(obj, waitStepId)
            % 状态I稳定回调
            if ~isvalid(obj.Figure), return; end

            obj.CurrentTemp = obj.RoomTemp;
            obj.CurrentTemp_mV = obj.CurrentTemp * obj.TEMP_SENSITIVITY;
            obj.TempDisplay.Text = sprintf('%.1f mV', obj.CurrentTemp_mV);

            % 记录状态I的压强差
            obj.DeltaP1_mV = obj.CurrentPressure_mV;
            obj.P1 = obj.P0 + obj.DeltaP1_mV * obj.PRESSURE_SENSITIVITY * 1000;  % kPa -> Pa

            % 更新显示
            obj.safeSetText(obj.LblDeltaP1, sprintf('%.1f mV', obj.DeltaP1_mV));
            obj.safeSetText(obj.LblP1, sprintf('%.0f Pa', obj.P1));

            obj.drawPVDiagram();
            obj.updateStatus(sprintf('状态I稳定：ΔP₁ = %.1f mV, P₁ = %.0f Pa', obj.DeltaP1_mV, obj.P1));

            obj.BtnReleaseAir.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnReleaseAir, 'primary');

            if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep(waitStepId); end
            obj.showNextStepHint();
        end

        function releaseAir(obj)
            % 迅速放气（绝热膨胀）
            releaseStepId = sprintf('release_%d', obj.MeasurementCount + 1);
            [canProceed, ~] = obj.checkOperationValid(releaseStepId);
            if ~canProceed, return; end

            obj.ValveOpen = true;
            obj.ExpStage = obj.STAGE_RELEASED;
            obj.BtnReleaseAir.Enable = 'off';

            % 更新阀门状态
            if ~isempty(obj.LblValveStatus) && isvalid(obj.LblValveStatus)
                obj.LblValveStatus.Text = '放气阀: 开';
                obj.LblValveStatus.FontColor = [0.2, 0.6, 0.2];
            end

            obj.updateStatus('迅速放气中...听到"嘭"的一声！');

            % 非阻塞绝热膨胀动画：压强迅速降至大气压
            obj.animatePressureChange(obj.CurrentPressure_mV, 0, 0.3, ...
                @() obj.onReleaseAnimComplete(releaseStepId));
        end

        function onReleaseAnimComplete(obj, releaseStepId)
            % 放气动画完成，开始关阀延迟
            if ~isvalid(obj.Figure), return; end

            obj.CurrentPressure_mV = 0;
            obj.PressureDisplay.Text = '0.0 mV';

            % 绝热膨胀后温度降低
            obj.CurrentTemp = obj.RoomTemp - 3 - rand() * 2;  % 降低3-5°C
            obj.CurrentTemp_mV = obj.CurrentTemp * obj.TEMP_SENSITIVITY;
            obj.TempDisplay.Text = sprintf('%.1f mV', obj.CurrentTemp_mV);

            % 非阻塞延迟关闭放气阀
            obj.stopAnimation();
            obj.AnimCancelled = false;
            obj.AnimTimer = timer('StartDelay', 0.3, ...
                'TimerFcn', @(~,~) obj.safeTimerCallback(@() obj.onReleaseValveClose(releaseStepId)));
            start(obj.AnimTimer);
        end

        function onReleaseValveClose(obj, releaseStepId)
            % 关闭阀门回调
            if obj.AnimCancelled || ~isvalid(obj.Figure), return; end

            obj.ValveOpen = false;
            if ~isempty(obj.LblValveStatus) && isvalid(obj.LblValveStatus)
                obj.LblValveStatus.Text = '放气阀: 关';
                obj.LblValveStatus.FontColor = [0.7, 0.2, 0.2];
            end

            obj.drawApparatus();
            obj.ExpStage = obj.STAGE_VALVE_CLOSED;
            obj.drawPVDiagram();
            obj.updateStatus('放气完成，阀门已关闭，等待系统回到室温');

            obj.BtnWaitStable2.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnWaitStable2, 'primary');

            if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep(releaseStepId); end
            obj.showNextStepHint();
        end

        function waitStable2(obj)
            % 等待状态III稳定（等容吸热）
            waitStepId = sprintf('wait2_%d', obj.MeasurementCount + 1);
            [canProceed, ~] = obj.checkOperationValid(waitStepId);
            if ~canProceed, return; end

            obj.BtnWaitStable2.Enable = 'off';
            obj.updateStatus('等待系统达到热平衡(状态III)...');

            % 非阻塞模拟等容吸热过程
            obj.animateTempChange(obj.CurrentTemp, obj.RoomTemp, 1.5, ...
                @() obj.onWaitStable2Complete(waitStepId));
        end

        function onWaitStable2Complete(obj, waitStepId)
            % 状态III稳定回调
            if ~isvalid(obj.Figure), return; end

            obj.CurrentTemp = obj.RoomTemp;
            obj.CurrentTemp_mV = obj.CurrentTemp * obj.TEMP_SENSITIVITY;
            obj.TempDisplay.Text = sprintf('%.1f mV', obj.CurrentTemp_mV);

            % 等容吸热后压强会有所上升
            obj.DeltaP2_mV = obj.DeltaP1_mV * 0.28 + randn() * 2;
            obj.DeltaP2_mV = max(5, obj.DeltaP2_mV);

            obj.CurrentPressure_mV = obj.DeltaP2_mV;
            obj.PressureDisplay.Text = sprintf('%.1f mV', obj.CurrentPressure_mV);

            obj.P2 = obj.P0 + obj.DeltaP2_mV * obj.PRESSURE_SENSITIVITY * 1000;

            % 更新显示
            obj.safeSetText(obj.LblDeltaP2, sprintf('%.1f mV', obj.DeltaP2_mV));
            obj.safeSetText(obj.LblP2, sprintf('%.0f Pa', obj.P2));

            obj.ExpStage = obj.STAGE_STABLE2;
            obj.drawApparatus();
            obj.drawPVDiagram();
            obj.updateStatus(sprintf('状态III稳定：ΔP₂ = %.1f mV, P₂ = %.0f Pa', obj.DeltaP2_mV, obj.P2));

            obj.BtnRecordData.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnRecordData, 'primary');

            if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep(waitStepId); end
            obj.showNextStepHint();
        end

        function recordData(obj)
            % 记录数据
            recordStepId = sprintf('record_%d', obj.MeasurementCount + 1);
            [canProceed, ~] = obj.checkOperationValid(recordStepId);
            if ~canProceed, return; end

            obj.MeasurementCount = obj.MeasurementCount + 1;

            % 完成记录步骤
            if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep(recordStepId); end
            obj.showNextStepHint();

            % 计算本次γ值（含除零保护）
            logP1_P2 = log(obj.P1) - log(obj.P2);
            if abs(logP1_P2) < 1e-10
                gamma = NaN;
                obj.updateStatus('警告：P1≈P2，无法计算有效γ值，请重新测量');
            else
                gamma = (log(obj.P1) - log(obj.P0)) / logP1_P2;
            end

            % 存储数据
            newData = [obj.P0, obj.DeltaP1_mV, obj.DeltaP2_mV, obj.P1, obj.P2, gamma];
            obj.MeasureData = [obj.MeasureData; newData];

            % 更新表格
            newRow = {obj.MeasurementCount, sprintf('%.1f', obj.DeltaP1_mV), ...
                sprintf('%.1f', obj.DeltaP2_mV), sprintf('%.0f', obj.P1), ...
                sprintf('%.0f', obj.P2), sprintf('%.4f', gamma)};
            obj.DataTable.Data = [obj.DataTable.Data; newRow];
            obj.enableExportButton();

            % 更新γ显示
            obj.safeSetText(obj.LblGamma, sprintf('%.4f', gamma));

            obj.updateStatus(sprintf('第%d次测量完成，γ = %.4f', obj.MeasurementCount, gamma));

            obj.BtnRecordData.Enable = 'off';

            if obj.MeasurementCount >= 6
                obj.BtnCalculate.Enable = 'on';
                ui.StyleConfig.applyButtonStyle(obj.BtnCalculate, 'primary');
                obj.BtnComplete.Enable = 'on';
                ui.StyleConfig.applyButtonStyle(obj.BtnComplete, 'success');
            else
                obj.BtnNextMeasure.Enable = 'on';
                ui.StyleConfig.applyButtonStyle(obj.BtnNextMeasure, 'primary');
                obj.BtnCalculate.Enable = 'on';
            end
        end

        function nextMeasurement(obj)
            % 进行下一次测量
            nextStepId = sprintf('pump_%d', obj.MeasurementCount + 1);
            [canProceed, ~] = obj.checkOperationValid(nextStepId);
            if ~canProceed, return; end

            obj.ExpStage = obj.STAGE_ZEROED;
            obj.DeltaP1_mV = 0;
            obj.DeltaP2_mV = 0;
            obj.P1 = 0;
            obj.P2 = 0;
            obj.AirPumped = false;
            obj.CurrentPressure_mV = 0;
            obj.PressureDisplay.Text = '0.0 mV';

            % 重置阀门状态
            obj.ValveOpen = true;
            if ~isempty(obj.LblValveStatus) && isvalid(obj.LblValveStatus)
                obj.LblValveStatus.Text = '放气阀: 开';
                obj.LblValveStatus.FontColor = [0.2, 0.6, 0.2];
            end

            % 重置参数显示
            paramLbls = {obj.LblP0, obj.LblDeltaP1, obj.LblDeltaP2, obj.LblP1, obj.LblP2, obj.LblGamma};
            paramDefaults = {'待测量', '待测量', '待测量', '待计算', '待计算', '待计算'};
            for i = 1:length(paramLbls)
                obj.safeSetText(paramLbls{i}, paramDefaults{i});
            end

            obj.drawApparatus();
            obj.drawPVDiagram();

            obj.updateStatus(sprintf('准备第%d次测量，请按步骤操作', obj.MeasurementCount + 1));

            obj.BtnNextMeasure.Enable = 'off';
            obj.BtnCalculate.Enable = 'off';
            obj.BtnPumpAir.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnPumpAir, 'primary');
        end

        function calculateGamma(obj)
            % 计算平均γ值
            [canProceed, ~] = obj.checkOperationValid('calculate');
            if ~canProceed, return; end

            if isempty(obj.MeasureData)
                return;
            end

            gammaValues = obj.MeasureData(:, 6);
            obj.Gamma_measured = mean(gammaValues);

            % 计算相对误差
            relError = abs(obj.Gamma_measured - obj.Gamma_standard) / obj.Gamma_standard * 100;

            % 更新结果显示
            obj.safeSetText(obj.LblResultGamma, sprintf('%.4f', obj.Gamma_measured));
            obj.safeSetText(obj.LblResultError, sprintf('%.2f%%', relError));

            obj.logOperation('计算完成', sprintf('γ=%.4f, 误差=%.2f%%', obj.Gamma_measured, relError));
            obj.updateStatus(sprintf('计算完成！γ平均 = %.4f，相对误差 = %.2f%%', ...
                obj.Gamma_measured, relError));

            obj.BtnCalculate.Enable = 'off';
            obj.BtnNextMeasure.Enable = 'off';
            obj.BtnComplete.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnComplete, 'success');

            if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep('calculate'); end
            obj.showNextStepHint();
        end

        function animatePressureChange(obj, startP, endP, duration, onComplete)
            % 非阻塞动画显示压强变化
            steps = 10;
            dt = max(0.02, duration / steps);
            pressures = linspace(startP, endP, steps);

            obj.stopAnimation();
            obj.AnimCancelled = false;
            obj.AnimPhase = 0;

            obj.AnimTimer = timer('ExecutionMode', 'fixedRate', ...
                'Period', dt, ...
                'TasksToExecute', steps, ...
                'TimerFcn', @(~,~) obj.safeTimerCallback(@() obj.animStepPressure(pressures)), ...
                'StopFcn', @(tmr,~) obj.onAnimTimerDone(tmr, onComplete));
            start(obj.AnimTimer);
        end

        function animStepPressure(obj, pressures)
            % 压强动画单步回调
            obj.AnimPhase = obj.AnimPhase + 1;
            if obj.AnimPhase <= length(pressures) && isvalid(obj.Figure)
                obj.CurrentPressure_mV = pressures(obj.AnimPhase);
                obj.PressureDisplay.Text = sprintf('%.1f mV', obj.CurrentPressure_mV);
                obj.drawApparatus();
            end
        end

        function animateTempChange(obj, startT, endT, duration, onComplete)
            % 非阻塞动画显示温度变化
            steps = 10;
            dt = max(0.02, duration / steps);
            temps = linspace(startT, endT, steps);

            obj.stopAnimation();
            obj.AnimCancelled = false;
            obj.AnimPhase = 0;

            obj.AnimTimer = timer('ExecutionMode', 'fixedRate', ...
                'Period', dt, ...
                'TasksToExecute', steps, ...
                'TimerFcn', @(~,~) obj.safeTimerCallback(@() obj.animStepTemp(temps)), ...
                'StopFcn', @(tmr,~) obj.onAnimTimerDone(tmr, onComplete));
            start(obj.AnimTimer);
        end

        function animStepTemp(obj, temps)
            % 温度动画单步回调
            obj.AnimPhase = obj.AnimPhase + 1;
            if obj.AnimPhase <= length(temps) && isvalid(obj.Figure)
                obj.CurrentTemp = temps(obj.AnimPhase);
                obj.CurrentTemp_mV = obj.CurrentTemp * obj.TEMP_SENSITIVITY;
                obj.TempDisplay.Text = sprintf('%.1f mV', obj.CurrentTemp_mV);
            end
        end

        function onAnimTimerDone(obj, tmr, onComplete)
            % 动画计时器完成回调
            try
                if isvalid(tmr), delete(tmr); end
            catch
            end
            if ~obj.AnimCancelled && ~isempty(onComplete) && isvalid(obj) && ~obj.IsClosing
                if isvalid(obj.Figure)
                    onComplete();
                end
            end
            obj.AnimCancelled = false;
        end

        function resetExperiment(obj)
            % 重置实验
            obj.logOperation('重置实验');
            obj.stopAnimation();

            % 重置所有数据
            obj.ExpStage = obj.STAGE_INIT;
            obj.IsPreheated = false;
            obj.IsZeroed = false;
            obj.ValveOpen = true;
            obj.AirPumped = false;
            obj.CurrentPressure_mV = 0;
            obj.CurrentTemp = obj.RoomTemp;
            obj.CurrentTemp_mV = obj.RoomTemp * obj.TEMP_SENSITIVITY;
            obj.DeltaP1_mV = 0;
            obj.DeltaP2_mV = 0;
            obj.P1 = 0;
            obj.P2 = 0;
            obj.MeasurementCount = 0;
            obj.MeasureData = [];
            obj.Gamma_measured = 0;
            obj.ExperimentCompleted = false;

            % 重置显示
            obj.PressureDisplay.Text = '0.0 mV';
            obj.TempDisplay.Text = sprintf('%.1f mV', obj.CurrentTemp_mV);
            obj.AtmPressureDisplay.Text = '待测量';
            obj.DataTable.Data = {};
            obj.disableExportButton();
            paramLbls = {obj.LblP0, obj.LblDeltaP1, obj.LblDeltaP2, obj.LblP1, obj.LblP2, obj.LblGamma};
            paramDefaults = {'待测量', '待测量', '待测量', '待计算', '待计算', '待计算'};
            for i = 1:length(paramLbls)
                obj.safeSetText(paramLbls{i}, paramDefaults{i});
            end

            % 重置结果显示
            obj.safeSetText(obj.LblResultGamma, '待计算');
            obj.safeSetText(obj.LblResultError, '待计算');

            % 重置阀门状态
            if ~isempty(obj.LblValveStatus) && isvalid(obj.LblValveStatus)
                obj.LblValveStatus.Text = '放气阀: 开';
                obj.LblValveStatus.FontColor = [0.2, 0.6, 0.2];
            end

            % 重置按钮状态
            obj.BtnPreheat.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnPreheat, 'primary');
            obj.BtnMeasureP0.Enable = 'off';
            obj.BtnOpenValve.Enable = 'off';
            obj.BtnZeroPressure.Enable = 'off';
            obj.BtnPumpAir.Enable = 'off';
            obj.BtnWaitStable1.Enable = 'off';
            obj.BtnReleaseAir.Enable = 'off';
            obj.BtnWaitStable2.Enable = 'off';
            obj.BtnRecordData.Enable = 'off';
            obj.BtnCalculate.Enable = 'off';
            obj.BtnNextMeasure.Enable = 'off';
            obj.BtnComplete.Enable = 'off';

            % 重绘图形
            obj.drawApparatus();
            obj.drawPVDiagram();

            % 重置实验引导
            if ~isempty(obj.ExpGuide)
                obj.ExpGuide.reset();
            end

            obj.updateStatus('实验已重置，请按步骤重新操作');
        end

        function stopAnimation(obj)
            % 停止动画计时器（设置取消标志阻止完成回调）
            obj.AnimCancelled = true;
            obj.safeStopTimer(obj.AnimTimer);
            obj.AnimTimer = [];
        end
    end

    methods (Access = protected)
        function onCleanup(obj)
            % 清理资源
            obj.stopAnimation();
        end
    end

    methods (Access = private)
        function restoreButtonStates(obj)
            % 根据当前实验阶段恢复按钮状态

            % 先禁用所有按钮
            allBtns = {obj.BtnPreheat, obj.BtnMeasureP0, obj.BtnOpenValve, ...
                       obj.BtnZeroPressure, obj.BtnPumpAir, obj.BtnWaitStable1, ...
                       obj.BtnReleaseAir, obj.BtnWaitStable2, obj.BtnRecordData, ...
                       obj.BtnCalculate, obj.BtnNextMeasure, obj.BtnComplete};
            obj.disableAllButtons(allBtns);

            switch obj.ExpStage
                case obj.STAGE_INIT
                    obj.BtnPreheat.Enable = 'on';
                    ui.StyleConfig.applyButtonStyle(obj.BtnPreheat, 'primary');
                case obj.STAGE_PREHEATED
                    % 预热完成阶段 — 根据子状态判断
                    if obj.IsPreheated && ~obj.IsZeroed
                        obj.BtnMeasureP0.Enable = 'on';
                        ui.StyleConfig.applyButtonStyle(obj.BtnMeasureP0, 'primary');
                    end
                case obj.STAGE_ZEROED
                    obj.BtnPumpAir.Enable = 'on';
                    ui.StyleConfig.applyButtonStyle(obj.BtnPumpAir, 'primary');
                case obj.STAGE_PUMPED
                    obj.BtnWaitStable1.Enable = 'on';
                    ui.StyleConfig.applyButtonStyle(obj.BtnWaitStable1, 'primary');
                case obj.STAGE_STABLE1
                    obj.BtnReleaseAir.Enable = 'on';
                    ui.StyleConfig.applyButtonStyle(obj.BtnReleaseAir, 'primary');
                case obj.STAGE_RELEASED
                    % 放气后立刻到6,理论上不会停留
                    obj.BtnWaitStable2.Enable = 'on';
                    ui.StyleConfig.applyButtonStyle(obj.BtnWaitStable2, 'primary');
                case obj.STAGE_VALVE_CLOSED
                    obj.BtnWaitStable2.Enable = 'on';
                    ui.StyleConfig.applyButtonStyle(obj.BtnWaitStable2, 'primary');
                case obj.STAGE_STABLE2
                    obj.BtnRecordData.Enable = 'on';
                    ui.StyleConfig.applyButtonStyle(obj.BtnRecordData, 'primary');
            end

            % 如果所有测量完成且已计算,启用完成按钮
            if obj.ExperimentCompleted
                obj.BtnComplete.Enable = 'on';
                ui.StyleConfig.applyButtonStyle(obj.BtnComplete, 'success');
            end
        end
    end

    methods (Access = protected)
        function restoreExperimentUI(obj)
            % 从讨论页面返回时恢复实验界面
            obj.setupExperimentUI();
            % 恢复显示状态
            obj.drawApparatus();
            obj.drawPVDiagram();
            % 恢复按钮状态
            obj.restoreButtonStates();
        end

        function summary = getExportSummary(obj)
            % 获取实验结果摘要
            summary = getExportSummary@experiments.ExperimentBase(obj);
            relError = abs(obj.Gamma_measured - obj.Gamma_standard) / obj.Gamma_standard * 100;
            summary = [summary; ...
                {'比热容比 γ', sprintf('%.4f', obj.Gamma_measured)}; ...
                {'标准值', sprintf('%.3f', obj.Gamma_standard)}; ...
                {'相对误差', sprintf('%.2f%%', relError)}; ...
                {'测量次数', sprintf('%d', obj.MeasurementCount)}];
        end
    end

    methods (Access = private)
        function setupExperimentGuide(obj)
            % 初始化实验引导系统（含重复测量）
            obj.ExpGuide = ui.ExperimentGuide(obj.Figure, @(msg) obj.updateStatus(msg));

            % 定义实验步骤
            obj.ExpGuide.addStep('preheat', '1. 仪器预热', ...
                '打开电源预热15分钟');
            obj.ExpGuide.addStep('measure_p0', '2. 测量大气压', ...
                '记录大气压强P₀', ...
                'Prerequisites', {'preheat'});
            obj.ExpGuide.addStep('open_valve', '3. 打开放气阀', ...
                '连通容器内外大气', ...
                'Prerequisites', {'measure_p0'});
            obj.ExpGuide.addStep('zero_pressure', '4. 调零', ...
                '调节仪表零点', ...
                'Prerequisites', {'open_valve'});

            % 6次重复测量
            obj.ExpGuide.addRepeatGroup('measurement', 6, '压强测量（共需6次）');
            for i = 1:6
                pumpId = sprintf('pump_%d', i);
                waitId1 = sprintf('wait1_%d', i);
                releaseId = sprintf('release_%d', i);
                waitId2 = sprintf('wait2_%d', i);
                recordId = sprintf('record_%d', i);

                prereq = 'zero_pressure';
                if i > 1
                    prereq = sprintf('record_%d', i-1);
                end

                obj.ExpGuide.addStep(pumpId, sprintf('打气(第%d次)', i), ...
                    '用打气球向容器内打气', ...
                    'Prerequisites', {prereq}, ...
                    'RepeatGroup', 'measurement', 'RepeatIndex', i);
                obj.ExpGuide.addStep(waitId1, sprintf('等待稳定I(第%d次)', i), ...
                    '等待压强和温度稳定', ...
                    'Prerequisites', {pumpId}, ...
                    'RepeatGroup', 'measurement', 'RepeatIndex', i);
                obj.ExpGuide.addStep(releaseId, sprintf('放气(第%d次)', i), ...
                    '迅速打开放气阀', ...
                    'Prerequisites', {waitId1}, ...
                    'RepeatGroup', 'measurement', 'RepeatIndex', i);
                obj.ExpGuide.addStep(waitId2, sprintf('等待稳定III(第%d次)', i), ...
                    '等待温度恢复室温', ...
                    'Prerequisites', {releaseId}, ...
                    'RepeatGroup', 'measurement', 'RepeatIndex', i);
                obj.ExpGuide.addStep(recordId, sprintf('记录数据(第%d次)', i), ...
                    '记录P₁和P₂值', ...
                    'Prerequisites', {waitId2}, ...
                    'RepeatGroup', 'measurement', 'RepeatIndex', i);
            end

            obj.ExpGuide.addStep('calculate', '6. 计算γ', ...
                '根据公式计算空气比热容比', ...
                'Prerequisites', {'record_6'});
        end

    end
end
