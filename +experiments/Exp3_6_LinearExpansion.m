classdef Exp3_6_LinearExpansion < experiments.ExperimentBase
    % Exp3_6_LinearExpansion 实验3-6 金属线胀系数的测量
    % 用数字千分表法测量金属管的线胀系数

    properties (Access = private)
        % UI组件
        SimulationAxes      % 仿真显示区域
        LTCurveAxes         % L-t曲线区域

        % 仪器显示
        ThermometerDisplay  % 温度计显示
        DialGaugeDisplay    % 千分表显示（mm）
        HeaterDisplay       % 加热器状态显示

        % 控制按钮
        BtnSetup            % 安装样品
        BtnSetParams        % 设置参数
        BtnStartHeat        % 开始加热
        BtnRecord           % 记录数据
        BtnStopHeat         % 停止加热
        BtnAnalyze          % 数据分析
        BtnCalculate        % 计算结果
        BtnComplete         % 完成实验

        % 结果标签（缓存，避免 findobj）
        LblResultAlpha      % 线胀系数结果标签
        LblResultError      % 相对误差结果标签

        % 实验参数
        SampleMaterial = '黄铜'     % 样品材料
        SampleLength = 500.00       % 样品初始长度 L1 (mm)
        TempStart = 25              % 起始温度 (°C)
        TempEnd = 80                % 终止温度 (°C)
        TempStep = 5                % 温度间隔 (°C)
        HeatPower = 75              % 加热功率百分比 (%)

        % 当前状态
        CurrentTemp                 % 当前温度 (°C)
        CurrentLength               % 当前长度 (mm)
        IsHeating = false           % 是否正在加热
        HeatingTimer                % 加热计时器
        LastRecordTemp = 0          % 上次记录时的温度（用于自动采样）
        MeasurementNoise = 0.02     % 测量噪声系数（模拟仪器误差）

        % 实验数据
        TempData = []               % 温度数据 (°C)
        LengthData = []             % 长度数据 (mm)
        RecordCount = 0             % 记录次数

        % 计算结果
        Alpha_measured = 0          % 测得线胀系数
        Alpha_standard = 0          % 标准值
        SlopeK = 0                  % 斜率K
        RelativeError = 0           % 相对误差

        % 缓存的曲线图句柄（增量更新）
        LTPlotHandle                % L-t曲线 plot 句柄
        LTCurveInitialized = false

        % 动态图形元素句柄（用于增量更新，避免全量重绘）
        HdlSampleRect              % 样品矩形
        HdlThermColumn             % 温度计液柱
        HdlGaugePointer            % 千分表指针
        HdlHeaterRect              % 加热器矩形
    end

    properties (Constant)
        % ==================== 常量定义 ====================
        % 仪器尺寸
        THERMO_H_MIN = 0.68;
        THERMO_H_MAX = 0.92;
        THERMO_H_RANGE = 0.24;
        GAUGE_X = 0.78;
        GAUGE_Y = 0.81;

        % 颜色
        COLOR_HEATER_ACTIVE = [0.95, 0.4, 0.15];
        COLOR_HEATER_INACTIVE = [0.7, 0.7, 0.7];
        COLOR_GOLD = [0.85, 0.65, 0.30];
        COLOR_RED_HOT = [0.95, 0.45, 0.20];

        % 物理参数 - 各材料线胀系数标准值 (×10^-5 /°C)
        ALPHA_BRASS = 1.67;      % 黄铜
        ALPHA_IRON = 1.18;       % 铁
        ALPHA_ALUMINUM = 2.31;   % 铝

        % 模拟参数
        HEAT_RATE_BASE = 0.3;
        NOISE_TEMP = 0.05;
        NOISE_GAUGE = 0.001;

        % 实验阶段常量
        STAGE_INIT = 0
        STAGE_SETUP = 1
        STAGE_HEATING = 2
        STAGE_ANALYZED = 3
        STAGE_CALCULATED = 4
    end

    methods (Access = public)
        function obj = Exp3_6_LinearExpansion()
            % 构造函数
            obj@experiments.ExperimentBase();

            % 设置实验基本信息
            obj.ExpNumber = '实验3-6';
            obj.ExpTitle = '金属线胀系数的测量';

            % 实验目的
            obj.ExpPurpose = ['1. 测定固体样品的线胀系数' newline ...
                '2. 掌握微小位移量的测量方法：千分表法和光杠杆法'];

            % 实验仪器
            obj.ExpInstruments = '金属线膨胀系数测定仪、光杠杆、望远镜尺组、游标卡尺等';

            % 实验原理
            obj.ExpPrinciple = [
                '【线胀系数定义】' newline ...
                '绝大多数物体都具有"热胀冷缩"的性质，在常压下温度变化会使物体内部分子热运动加剧或减弱，' ...
                '从而使得分子间距增大或减小，表现为宏观体积的增大或缩小。' newline newline ...
                '固体受热后在一维方向上的膨胀称为线膨胀。线胀系数α定义为固体温度上升1°C时，' ...
                '其线度伸长量与0°C的线度L₀之比，设固体温度升高到t°C时的长度为L，则线胀系数为：' newline ...
                '    α = (L - L₀) / (L₀·t)                    (3-6-1)' newline newline ...
                '【线胀系数的测量公式】' newline ...
                '根据公式(3-6-1)测定线胀系数时，线度L₀的测量不易实现。下面推导初温不为0°C时的表达式。' newline newline ...
                '若固体温度由t₁°C升到t₂°C，其长度分别为L₁、L₂，则由上式可得：' newline ...
                '    L₁ = L₀(1 + α·t₁)                        (3-6-2)' newline ...
                '    L₂ = L₀(1 + α·t₂)                        (3-6-3)' newline newline ...
                '上式两边分别相除得：' newline ...
                '    L₁/L₂ = (1 + α·t₁)/(1 + α·t₂)            (3-6-4)' newline newline ...
                '将上式整理后得：' newline ...
                '    α = (L₂ - L₁) / (L₁t₂ - L₂t₁) ≈ ΔL / (L₁·Δt)    (3-6-5)' newline newline ...
                '式中，ΔL = L₂ - L₁ 为微小伸长量。' newline newline ...
                '【千分表法测量】' newline ...
                '用数字千分表法进行实验时，对温度t₁和t₂，长度L₁和L₂测量后，就可由式(3-6-5)求出线胀系数值。' newline newline ...
                '记录温度与数字千分表对应的数据（即t和L），根据：' newline ...
                '    ΔL = αL₁Δt = KΔt                         (3-6-8)' newline newline ...
                '则线胀系数α为：' newline ...
                '    α = K / L₁                               (3-6-9)' newline newline ...
                '用表中t与L的数据作L-t图线，求直线斜率K的值，即可计算出材料的线胀系数值α。'];

            % 实验内容
            obj.ExpContent = [
                '1. 用数字千分表法测量黄铜（或铁、铝）管的线胀系数' newline newline ...
                '（1）操作步骤' newline ...
                '① 按测试仪器说明书的要求安装仪器设备，给加热器水箱注入2/3的软性水（含较少可溶性钙、镁化合物的水）。' newline ...
                '② 设置仪器测量参数：' newline ...
                '   1) Range：[25~80°C]，测量温度区间从起始温度25°C到终止温度80°C。' newline ...
                '   2) Step：[5°C]，采样温度间隔为5°C，即样品温度每变化5°C，仪器采样一次。' newline ...
                '   3) Mode：[Rise]，测量方式为样品升温时测量。' newline ...
                '   4) Heat Power：[75%]，加热功率为全功率的75%，即700W×75%=525W。' newline ...
                '③ 启动水泵开关，使水在系统中循环起来后，先按加热键，再按测量开始键。' newline ...
                '④ 记录温度与数字千分表对应的数据（即tᵢ及Lᵢ）直到仪器自动停止。' newline ...
                '⑤ 浏览仪器自动采集的所有数据，并记录仪器自动计算的平均线胀系数。' newline ...
                '⑥ 对水循环加热系统进行冷却（排出热水、加注冷水进行循环）。' newline newline ...
                '（2）数据记录及处理' newline ...
                '① 通过数字千分表读取样品在不同温度下的线膨胀长度，并记录在表中。' newline ...
                '② 用表中tᵢ与Lᵢ的数据作L-t图线，求直线斜率K的值。' newline ...
                '③ 根据公式 α = K/L₁ 计算线胀系数。' newline ...
                '④ 已知L₁=50.00cm，Δt=5°C，α标准=1.67×10⁻⁵°C⁻¹，将L-t图线中求得的K值代入公式即可计算出材料的线胀系数值α，' ...
                '与理论值进行比较，求出相应材料线胀系数的百分误差。'];

            % 思考讨论
            obj.ExpQuestions = {
                '调节光杠杆的过程是什么？在调节中要特别注意哪些问题？', ...
                ['调节光杠杆的过程：' newline ...
                '1. 将光杠杆放在仪器平台上，其后足尖放在金属棒的顶端，前足尖放入平台的凹槽内' newline ...
                '2. 光杠杆的镜面在铅直方向，在光杠杆前1.5~2.0m处放置望远镜及直尺' newline ...
                '3. 调节望远镜，看到平面镜中直尺的像（仔细聚焦以消除叉丝与直尺像之间的视差）' newline ...
                '4. 读出十字叉丝在直尺上的位置x₁' newline newline ...
                '注意事项：' newline ...
                '1. 确保光杠杆三个足尖稳定放置，不要晃动' newline ...
                '2. 镜面要保持垂直，以获得清晰的刻度像' newline ...
                '3. 望远镜与平面镜要在同一水平面上'];

                '分析本实验中各物理量的测量结果，哪一个对实验结果误差影响较大？', ...
                ['影响实验结果误差的物理量分析：' newline ...
                '1. 微小伸长量ΔL的测量：由于ΔL非常小（约0.1mm量级），测量的相对误差较大，对结果影响最显著' newline ...
                '2. 温度测量：温度计的精度和热平衡时间会影响结果' newline ...
                '3. 样品初始长度L₁：测量相对容易，误差较小' newline ...
                '4. 综上，微小伸长量ΔL的测量对实验结果误差影响最大，因此选择高精度的千分表或光杠杆法至关重要'];

                '如何利用牛顿环法、毛细管法和光的衍射法测量材料的线膨胀变化量？', ...
                ['其他测量线膨胀变化量的方法：' newline ...
                '1. 牛顿环法：利用牛顿环干涉条纹的变化来测量微小位移，当样品膨胀时会改变透镜与平面之间的间隙，从而改变干涉条纹' newline ...
                '2. 毛细管法：利用液体在毛细管中的液面变化来放大和测量微小的体积或长度变化' newline ...
                '3. 光的衍射法：利用单缝衍射或其他衍射现象，当缝宽因热膨胀而变化时，衍射条纹的位置和间距会发生变化，从而可以测量微小的长度变化'];
                };

            % 初始化状态
            obj.CurrentTemp = obj.TempStart;
            obj.CurrentLength = obj.SampleLength;
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
                    'RowHeight', {'1x', 140, 180}, ...
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
                title(obj.SimulationAxes, '金属线膨胀系数测定仪', ...
                    'FontName', ui.StyleConfig.FontFamily, 'Color', ui.StyleConfig.TextPrimary);

                % L-t曲线区域
                obj.LTCurveAxes = uiaxes(plotGrid);
                obj.LTCurveAxes.Layout.Row = 1;
                obj.LTCurveAxes.Layout.Column = 2;
                ui.StyleConfig.applyAxesStyle(obj.LTCurveAxes);
                title(obj.LTCurveAxes, 'L-t 曲线', ...
                    'FontName', ui.StyleConfig.FontFamily, 'Color', ui.StyleConfig.TextPrimary);
                xlabel(obj.LTCurveAxes, '温度 t (°C)');
                ylabel(obj.LTCurveAxes, '长度变化 ΔL (mm)');
                xlim(obj.LTCurveAxes, [20, 85]);
                ylim(obj.LTCurveAxes, [0, 0.5]);

                % 绘制初始图形
                obj.drawApparatus();

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

                % Temp
                obj.ThermometerDisplay = obj.createInstrumentDisplay(instGrid, '温度', ...
                    sprintf('%.2f °C', obj.CurrentTemp), ui.StyleConfig.ErrorColor, 1, 1);

                % Gauge
                obj.DialGaugeDisplay = obj.createInstrumentDisplay(instGrid, '千分表', ...
                    '0.000 mm', ui.StyleConfig.SuccessColor, 1, 2);

                % Heater
                obj.HeaterDisplay = obj.createInstrumentDisplay(instGrid, '加热器', ...
                    '关闭', ui.StyleConfig.TextSecondary, 1, 3);

                % Sample Info
                % Refactored to avoid index reference error on Children(end) and fix layout assignment
                sampleInfoText = sprintf('样品材料: %s  |  初始长度 L₁ = %.2f mm', obj.SampleMaterial, obj.SampleLength);
                lblInfo = obj.createSimpleLabel(instGrid, sampleInfoText, 'center', ui.StyleConfig.TextSecondary);
                lblInfo.Layout.Row = 2;
                lblInfo.Layout.Column = [1, 3];


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

                % 按钮网格布局 (3行4列)
                btnGrid = uigridlayout(btnPanel, [3, 4], ...
                    'ColumnWidth', repmat({'1x'}, 1, 4), ...
                    'RowHeight', {'1x', '1x', '1x'}, ...
                    'Padding', [5, 5, 5, 5], ...
                    'RowSpacing', 5, 'ColumnSpacing', 5);

                % Row 1
                obj.BtnSetup = obj.createExpButton(btnGrid, '1.安装样品', @(~,~) obj.setupSample(), 'primary', 1, 1);
                obj.BtnSetParams = obj.createExpButton(btnGrid, '2.设置参数', @(~,~) obj.setParameters(), 'disabled', 1, 2);
                obj.BtnStartHeat = obj.createExpButton(btnGrid, '3.开始加热', @(~,~) obj.startHeating(), 'disabled', 1, 3);
                obj.BtnRecord = obj.createExpButton(btnGrid, '4.记录数据', @(~,~) obj.recordData(), 'disabled', 1, 4);

                % Row 2
                obj.BtnStopHeat = obj.createExpButton(btnGrid, '5.停止加热', @(~,~) obj.stopHeating(), 'disabled', 2, 1);
                obj.BtnAnalyze = obj.createExpButton(btnGrid, '6.数据分析', @(~,~) obj.analyzeData(), 'disabled', 2, 2);
                obj.BtnCalculate = obj.createExpButton(btnGrid, '7.计算结果', @(~,~) obj.calculateResult(), 'disabled', 2, 3);
                % Row 3
                obj.BtnComplete = obj.createExpButton(btnGrid, '完成实验', @(~,~) obj.completeExperiment(), 'disabled', 3, 3);

                % 重置按钮
                resetBtn = uibutton(btnGrid, 'Text', '重置实验', ...
                    'ButtonPushedFcn', @(~,~) obj.resetExperiment());
                resetBtn.Layout.Row = 3;
                resetBtn.Layout.Column = 4;
                ui.StyleConfig.applyButtonStyle(resetBtn, 'warning');


                % ==================== 右侧面板 ====================

                % ---------- 参数控制面板 (右上) ----------
                controlGrid = ui.StyleConfig.createControlPanelGrid(obj.ControlPanel, 7);

                % 标题行
                lblHeader = ui.StyleConfig.createPanelTitle(controlGrid, '实验参数');
                lblHeader.Layout.Row = 1;
                lblHeader.Layout.Column = [1, 2];

                paramLabels = {'样品材料:', '初始长度 L₁:', '起始温度:', ...
                    '终止温度:', '温度间隔:', '加热功率:'};
                paramValues = {obj.SampleMaterial, ...
                    sprintf('%.2f mm', obj.SampleLength), ...
                    sprintf('%d °C', obj.TempStart), ...
                    sprintf('%d °C', obj.TempEnd), ...
                    sprintf('%d °C', obj.TempStep), ...
                    sprintf('%d%%', obj.HeatPower)};
                paramTags = {'MaterialLabel', 'LengthLabel', 'TempStartLabel', ...
                    'TempEndLabel', 'TempStepLabel', 'PowerLabel'};

                for i = 1:length(paramLabels)
                    l = ui.StyleConfig.createParamLabel(controlGrid, paramLabels{i});
                    l.Layout.Row = i + 1;
                    l.Layout.Column = 1;

                    v = ui.StyleConfig.createParamValue(controlGrid, paramValues{i});
                    v.Layout.Row = i + 1;
                    v.Layout.Column = 2;
                    if ~isempty(paramTags{i})
                        v.Tag = paramTags{i};
                    end
                end

                % ---------- 实验数据面板 (右下) ----------
                dataPanelGrid = ui.StyleConfig.createDataPanelGrid(obj.DataPanel, '1x', 100);

                % Title
                lblData = ui.StyleConfig.createPanelTitle(dataPanelGrid, '实验数据');
                lblData.Layout.Row = 1;

                % 数据表格
                obj.DataTable = ui.StyleConfig.createDataTable(dataPanelGrid, ...
                    {'序号', '温度 t (°C)', '长度变化 ΔL (mm)'}, {50, 100, 120});
                obj.DataTable.Layout.Row = 2;
                obj.DataTable.Data = {};
                obj.DataTable.RowName = {};

                % 结果区域
                resultGrid = ui.StyleConfig.createResultGrid(dataPanelGrid, 3);
                resultGrid.Layout.Row = 3;

                % Title
                lblRes = ui.StyleConfig.createResultLabel(resultGrid, '计算结果');
                lblRes.Layout.Row = 1;
                lblRes.Layout.Column = [1, 2];
                lblRes.FontWeight = 'bold';
                lblRes.HorizontalAlignment = 'center';

                % Alpha
                lbl1 = ui.StyleConfig.createResultLabel(resultGrid, '线胀系数 α =');
                lbl1.Layout.Row = 2;
                lbl1.Layout.Column = 1;
                lblAlpha = ui.StyleConfig.createResultValue(resultGrid, '待计算');
                lblAlpha.Layout.Row = 2;
                lblAlpha.Layout.Column = 2;
                obj.LblResultAlpha = lblAlpha;

                % Error
                lbl2 = ui.StyleConfig.createResultLabel(resultGrid, '相对误差 =');
                lbl2.Layout.Row = 3;
                lbl2.Layout.Column = 1;
                lblError = ui.StyleConfig.createResultValue(resultGrid, '待计算');
                lblError.Layout.Row = 3;
                lblError.Layout.Column = 2;
                obj.LblResultError = lblError;

                % 初始化实验引导系统
                obj.setupExperimentGuide();

                obj.updateStatus('准备开始实验，请按步骤操作');
                drawnow;

            catch ME
                utils.Logger.logError(ME, 'Exp3_6_LinearExpansion.setupExperimentUI');
                uialert(obj.Figure, sprintf('UI初始化失败:\n%s\nFile: %s\nLine: %d', ...
                    ME.message, ME.stack(1).name, ME.stack(1).line), '程序错误');
            end
        end

        function drawApparatus(obj)
            % 绘制金属线膨胀系数测定仪示意图（改进版）
            ax = obj.SimulationAxes;
            cla(ax);
            hold(ax, 'on');

            % 设置背景
            set(ax, 'Color', ui.StyleConfig.SimulationBgColor);

            % ========== 底座 ==========
            rectangle(ax, 'Position', [0.08, 0.08, 0.84, 0.08], ...
                'FaceColor', [0.55, 0.55, 0.55], ...
                'EdgeColor', [0.35, 0.35, 0.35], ...
                'LineWidth', 2);

            % ========== 左侧支架 ==========
            rectangle(ax, 'Position', [0.10, 0.16, 0.06, 0.50], ...
                'FaceColor', [0.65, 0.65, 0.65], ...
                'EdgeColor', [0.4, 0.4, 0.4], ...
                'LineWidth', 1.5);

            % ========== 右侧支架 ==========
            rectangle(ax, 'Position', [0.84, 0.16, 0.06, 0.50], ...
                'FaceColor', [0.65, 0.65, 0.65], ...
                'EdgeColor', [0.4, 0.4, 0.4], ...
                'LineWidth', 1.5);

            % ========== 加热管外壳（灰色外壳）==========
            rectangle(ax, 'Position', [0.14, 0.38, 0.72, 0.20], ...
                'FaceColor', [0.82, 0.82, 0.82], ...
                'EdgeColor', [0.5, 0.5, 0.5], ...
                'LineWidth', 2);

            % ========== 金属样品管 ==========
            sampleColor = obj.tempToColor(obj.CurrentTemp);
            obj.HdlSampleRect = rectangle(ax, 'Position', [0.16, 0.42, 0.68, 0.12], ...
                'FaceColor', sampleColor, ...
                'EdgeColor', [0.6, 0.5, 0.25], ...
                'LineWidth', 2);

            % 样品材料标注（在样品上）
            text(ax, 0.50, 0.48, obj.SampleMaterial, ...
                'FontName', ui.StyleConfig.FontFamily, ...
                'FontSize', 12, ...
                'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center', ...
                'Color', [0.2, 0.15, 0.05]);

            % ========== 温度计（左上方，参考Exp3_1风格）==========
            % 温度计支架
            plot(ax, [0.22, 0.22], [0.56, 0.68], 'Color', [0.4, 0.4, 0.4], 'LineWidth', 2);

            % 温度计主体（玻璃管）- 外层灰色边框
            plot(ax, [0.22, 0.22], [0.68, 0.94], 'Color', [0.4, 0.4, 0.4], 'LineWidth', 4);
            % 温度计主体（玻璃管）- 内层浅色
            plot(ax, [0.22, 0.22], [0.68, 0.94], 'Color', [0.9, 0.9, 0.95], 'LineWidth', 2);

            % 温度计红色液柱（根据温度变化高度，范围0-100°C）
            % 液柱高度: 0°C对应0.68, 100°C对应0.92
            bulbHeight = obj.THERMO_H_MIN + (obj.CurrentTemp / 100) * (obj.THERMO_H_MAX - obj.THERMO_H_MIN);
            bulbHeight = max(obj.THERMO_H_MIN, min(obj.THERMO_H_MAX, bulbHeight));
            obj.HdlThermColumn = plot(ax, [0.22, 0.22], [obj.THERMO_H_MIN, bulbHeight], 'r-', 'LineWidth', 2);

            % 温度计球部
            plot(ax, 0.22, obj.THERMO_H_MIN, 'ro', 'MarkerSize', 7, 'MarkerFaceColor', 'r');

            % 温度计标注
            text(ax, 0.22, 0.97, '温度计', ...
                'FontName', ui.StyleConfig.FontFamily, ...
                'FontSize', 9, ...
                'HorizontalAlignment', 'center', ...
                'Color', ui.StyleConfig.TextPrimary);

            % ========== 千分表（右上方）==========
            % 千分表支架
            plot(ax, [0.78, 0.78], [0.58, 0.70], 'Color', [0.4, 0.4, 0.4], 'LineWidth', 3);

            % 千分表表盘（圆角矩形）
            rectangle(ax, 'Position', [0.68, 0.70, 0.20, 0.22], ...
                'FaceColor', [1, 1, 1], ...
                'EdgeColor', [0.3, 0.3, 0.3], ...
                'LineWidth', 2, ...
                'Curvature', [0.15, 0.15]);

            % 千分表刻度线
            centerX = obj.GAUGE_X;
            centerY = obj.GAUGE_Y;
            % 横线
            plot(ax, [centerX - 0.07, centerX + 0.07], [centerY, centerY], ...
                'Color', [0.3, 0.3, 0.3], 'LineWidth', 1);
            % 竖线
            plot(ax, [centerX, centerX], [centerY - 0.06, centerY + 0.06], ...
                'Color', [0.3, 0.3, 0.3], 'LineWidth', 1);

            % 千分表指针（根据膨胀量旋转）
            deltaL = obj.CurrentLength - obj.SampleLength;
            % 0.5mm 对应 180度旋转
            angle = (deltaL / 0.5) * pi;
            angle = min(pi, max(-pi/4, angle));
            ptrLen = 0.055;
            obj.HdlGaugePointer = plot(ax, [centerX, centerX + ptrLen*sin(angle)], ...
                     [centerY, centerY + ptrLen*cos(angle)], ...
                'Color', [0.85, 0.1, 0.1], 'LineWidth', 2);
            % 指针中心点
            plot(ax, centerX, centerY, 'ko', 'MarkerSize', 4, 'MarkerFaceColor', 'k');

            % 千分表探针（向下连接到样品）
            plot(ax, [0.78, 0.78], [0.54, 0.70], 'Color', [0.45, 0.45, 0.45], 'LineWidth', 2);

            % 千分表标注
            text(ax, 0.78, 0.96, '千分表', ...
                'FontName', ui.StyleConfig.FontFamily, ...
                'FontSize', 9, ...
                'HorizontalAlignment', 'center', ...
                'Color', ui.StyleConfig.TextPrimary);

            % ========== 加热器（底部中央）==========
            if obj.IsHeating
                heaterColor = obj.COLOR_HEATER_ACTIVE;
                heaterEdge = [0.8, 0.2, 0.1];
            else
                heaterColor = obj.COLOR_HEATER_INACTIVE;
                heaterEdge = [0.5, 0.5, 0.5];
            end
            obj.HdlHeaterRect = rectangle(ax, 'Position', [0.42, 0.22, 0.16, 0.08], ...
                'FaceColor', heaterColor, ...
                'EdgeColor', heaterEdge, ...
                'LineWidth', 1.5, ...
                'Curvature', [0.3, 0.4]);

            % 加热器标注
            text(ax, 0.50, 0.18, '加热器', ...
                'FontName', ui.StyleConfig.FontFamily, ...
                'FontSize', 9, ...
                'HorizontalAlignment', 'center', ...
                'Color', ui.StyleConfig.TextPrimary);

            hold(ax, 'off');
            xlim(ax, [0, 1]);
            ylim(ax, [0, 1]);
            ax.XTick = [];
            ax.YTick = [];
        end

        function updateDynamicDisplay(obj)
            % 增量更新动态元素，避免全量重绘 drawApparatus
            % 仅更新：样品颜色、温度计液柱、千分表指针、加热器颜色
            if isempty(obj.HdlSampleRect) || ~isvalid(obj.HdlSampleRect) || ...
               isempty(obj.HdlThermColumn) || ~isvalid(obj.HdlThermColumn) || ...
               isempty(obj.HdlGaugePointer) || ~isvalid(obj.HdlGaugePointer) || ...
               isempty(obj.HdlHeaterRect) || ~isvalid(obj.HdlHeaterRect)
                obj.drawApparatus();
                return;
            end

            % 更新样品颜色
            sampleColor = obj.tempToColor(obj.CurrentTemp);
            set(obj.HdlSampleRect, 'FaceColor', sampleColor);

            % 更新温度计液柱高度
            bulbHeight = obj.THERMO_H_MIN + (obj.CurrentTemp / 100) * (obj.THERMO_H_MAX - obj.THERMO_H_MIN);
            bulbHeight = max(obj.THERMO_H_MIN, min(obj.THERMO_H_MAX, bulbHeight));
            set(obj.HdlThermColumn, 'YData', [obj.THERMO_H_MIN, bulbHeight]);

            % 更新千分表指针角度
            deltaL = obj.CurrentLength - obj.SampleLength;
            angle = (deltaL / 0.5) * pi;
            angle = min(pi, max(-pi/4, angle));
            ptrLen = 0.055;
            centerX = obj.GAUGE_X;
            centerY = obj.GAUGE_Y;
            set(obj.HdlGaugePointer, 'XData', [centerX, centerX + ptrLen*sin(angle)], ...
                'YData', [centerY, centerY + ptrLen*cos(angle)]);

            % 更新加热器颜色
            if obj.IsHeating
                set(obj.HdlHeaterRect, 'FaceColor', obj.COLOR_HEATER_ACTIVE, 'EdgeColor', [0.8, 0.2, 0.1]);
            else
                set(obj.HdlHeaterRect, 'FaceColor', obj.COLOR_HEATER_INACTIVE, 'EdgeColor', [0.5, 0.5, 0.5]);
            end
        end

    end

    methods (Static, Access = private)
        function color = tempToColor(temp)
            % 根据温度返回金属颜色（黄铜色渐变）
            normalizedTemp = (temp - 20) / 80;  % 归一化 20-100°C
            normalizedTemp = max(0, min(1, normalizedTemp));

            % 从黄铜色渐变到橙红色
            baseColor = [0.85, 0.65, 0.30];
            hotColor = [0.95, 0.45, 0.20];

            color = baseColor + normalizedTemp * (hotColor - baseColor);
        end
    end

    methods (Access = private)
        function setupSample(obj)
            % 安装样品
            [canProceed, ~] = obj.checkOperationValid('setup');
            if ~canProceed, return; end

            obj.ExpStage = obj.STAGE_SETUP;
            obj.CurrentTemp = obj.TempStart;
            obj.CurrentLength = obj.SampleLength;

            obj.drawApparatus();
            obj.updateStatus(sprintf('样品已安装：%s管，长度 %.2f mm', obj.SampleMaterial, obj.SampleLength));

            obj.BtnSetup.Enable = 'off';
            obj.BtnSetParams.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnSetParams, 'primary');

            obj.ExpGuide.completeStep('setup');
            obj.showNextStepHint();
        end

        function setParameters(obj)
            % 设置实验参数（使用默认参数）
            [canProceed, ~] = obj.checkOperationValid('set_params');
            if ~canProceed, return; end

            obj.updateStatus(sprintf('参数已设置：温度范围 %d~%d°C，间隔 %d°C，功率 %d%%', ...
                obj.TempStart, obj.TempEnd, obj.TempStep, obj.HeatPower));

            % 设置标准值
            switch obj.SampleMaterial
                case '黄铜'
                    obj.Alpha_standard = obj.ALPHA_BRASS;
                case '铁'
                    obj.Alpha_standard = obj.ALPHA_IRON;
                case '铝'
                    obj.Alpha_standard = obj.ALPHA_ALUMINUM;
                otherwise
                    obj.Alpha_standard = obj.ALPHA_BRASS;
            end

            obj.BtnSetParams.Enable = 'off';
            obj.BtnStartHeat.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnStartHeat, 'primary');

            obj.ExpGuide.completeStep('set_params');
            obj.showNextStepHint();
        end

        function startHeating(obj)
            % 开始加热
            [canProceed, ~] = obj.checkOperationValid('start_heat');
            if ~canProceed, return; end

            obj.IsHeating = true;
            obj.ExpStage = obj.STAGE_HEATING;
            obj.HeaterDisplay.Text = '加热中';
            obj.HeaterDisplay.FontColor = [0.9, 0.3, 0];
            obj.LastRecordTemp = obj.TempStart;  % 初始化上次记录温度

            % 创建加热计时器
            obj.HeatingTimer = timer('ExecutionMode', 'fixedRate', ...
                'Period', 0.3, ...
                'TimerFcn', @(~,~) obj.safeTimerCallback(@obj.updateHeating));
            start(obj.HeatingTimer);

            obj.updateStatus(sprintf('开始加热，将在每 %d°C 自动采样...', obj.TempStep));

            obj.BtnStartHeat.Enable = 'off';
            obj.BtnRecord.Enable = 'on';
            obj.BtnStopHeat.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnRecord, 'secondary');
            ui.StyleConfig.applyButtonStyle(obj.BtnStopHeat, 'warning');

            obj.ExpGuide.completeStep('start_heat');
            obj.showNextStepHint();
        end

        function updateHeating(obj)
            % 更新加热过程
            if ~obj.IsHeating
                return;
            end

            % 检查窗口有效性
            if isempty(obj.Figure) || ~isvalid(obj.Figure)
                obj.stopHeating();
                return;
            end

            % 温度上升模拟（考虑功率和热容）
            heatRate = obj.HEAT_RATE_BASE * (obj.HeatPower / 100);
            obj.CurrentTemp = obj.CurrentTemp + heatRate + randn() * obj.NOISE_TEMP;

            % 计算膨胀量 ΔL = α * L1 * ΔT（添加测量噪声模拟真实实验）
            alpha = obj.Alpha_standard * 1e-5;  % 转换单位
            deltaT = obj.CurrentTemp - obj.TempStart;
            % 添加随机测量误差（千分表精度约±0.001mm）
            measurementError = randn() * obj.NOISE_GAUGE * obj.MeasurementNoise * 50;
            obj.CurrentLength = obj.SampleLength + alpha * obj.SampleLength * deltaT + measurementError;

            % 更新显示
            obj.ThermometerDisplay.Text = sprintf('%.2f °C', obj.CurrentTemp);
            deltaL = obj.CurrentLength - obj.SampleLength;
            obj.DialGaugeDisplay.Text = sprintf('%.3f mm', deltaL);

            % 增量更新仪器图（避免全量重绘）
            obj.updateDynamicDisplay();

            % 自动采样：当温度变化达到设定间隔时自动记录
            if obj.CurrentTemp >= obj.LastRecordTemp + obj.TempStep
                obj.autoRecordData();
            end

            % 检查是否达到终止温度
            if obj.CurrentTemp >= obj.TempEnd
                obj.stopHeating();
                obj.updateStatus('已达到终止温度，加热自动停止，请进行数据分析');
                % 自动启用分析按钮
                if length(obj.TempData) >= 3
                    obj.BtnAnalyze.Enable = 'on';
                    ui.StyleConfig.applyButtonStyle(obj.BtnAnalyze, 'primary');
                end
            end
        end

        function autoRecordData(obj)
            % 自动记录数据（按温度间隔）
            obj.RecordCount = obj.RecordCount + 1;

            % 记录带有测量误差的数据
            recordTemp = obj.CurrentTemp + randn() * 0.1;  % 温度计误差±0.1°C
            obj.TempData(end+1) = recordTemp;

            % 长度变化带有仪器误差
            deltaL = obj.CurrentLength - obj.SampleLength;
            % 添加系统误差和随机误差
            deltaL = deltaL * (1 + randn() * obj.MeasurementNoise);
            obj.LengthData(end+1) = deltaL;

            obj.LastRecordTemp = obj.CurrentTemp;

            % 更新表格
            newRow = {obj.RecordCount, sprintf('%.2f', recordTemp), sprintf('%.4f', deltaL)};
            obj.DataTable.Data = [obj.DataTable.Data; newRow];
            obj.enableExportButton();

            % 更新曲线
            obj.updateLTCurve();

            obj.updateStatus(sprintf('自动记录第 %d 点：t = %.2f°C, ΔL = %.4f mm', ...
                obj.RecordCount, recordTemp, deltaL));

            % 首次记录时完成引导步骤
            if obj.RecordCount == 1 && ~isempty(obj.ExpGuide)
                obj.ExpGuide.completeStep('record');
                obj.showNextStepHint();
            end
        end

        function recordData(obj)
            % 手动触发一次记录，之后自动按温度间隔记录
            [canProceed, ~] = obj.checkOperationValid('record');
            if ~canProceed, return; end

            % 手动记录一次当前数据
            obj.autoRecordData();

            % 触发后禁用按钮，后续由自动采样接管
            obj.BtnRecord.Enable = 'off';

            obj.updateStatus(sprintf('已记录第 %d 点，后续将每 %d°C 自动采样', ...
                obj.RecordCount, obj.TempStep));

            % 完成引导步骤
            if ~isempty(obj.ExpGuide)
                obj.ExpGuide.completeStep('record');
            end
            obj.showNextStepHint();
        end

        function updateLTCurve(obj)
            % 更新L-t曲线（增量更新）
            if isempty(obj.LTCurveAxes) || ~isvalid(obj.LTCurveAxes)
                return;
            end

            if isempty(obj.TempData)
                return;
            end

            if ~obj.LTCurveInitialized || isempty(obj.LTPlotHandle) || ~isvalid(obj.LTPlotHandle)
                % 首次绘制
                cla(obj.LTCurveAxes);
                hold(obj.LTCurveAxes, 'on');

                obj.LTPlotHandle = plot(obj.LTCurveAxes, obj.TempData, obj.LengthData, 'bo', ...
                    'MarkerSize', 8, 'MarkerFaceColor', 'b', 'LineWidth', 1.5);

                hold(obj.LTCurveAxes, 'off');
                xlabel(obj.LTCurveAxes, '温度 t (°C)');
                ylabel(obj.LTCurveAxes, '长度变化 ΔL (mm)');
                title(obj.LTCurveAxes, 'L-t 曲线', 'FontName', ui.StyleConfig.FontFamily);
                obj.LTCurveInitialized = true;
            else
                % 增量更新
                set(obj.LTPlotHandle, 'XData', obj.TempData, 'YData', obj.LengthData);
            end

            % 自动调整坐标轴范围
            xlim(obj.LTCurveAxes, [obj.TempStart - 5, max(obj.TempData) + 5]);
            ylim(obj.LTCurveAxes, [0, max(obj.LengthData) * 1.2 + 0.01]);
        end

        function stopHeating(obj)
            % 停止加热
            obj.IsHeating = false;
            obj.safeStopTimer(obj.HeatingTimer);
            obj.HeatingTimer = [];

            % 更新显示
            if ~isempty(obj.HeaterDisplay) && isvalid(obj.HeaterDisplay)
                obj.HeaterDisplay.Text = '已停止';
                obj.HeaterDisplay.FontColor = [0.5, 0.5, 0.5];
            end

            obj.drawApparatus();
            obj.updateStatus('加热已停止');

            obj.BtnRecord.Enable = 'off';
            obj.BtnStopHeat.Enable = 'off';

            % 完成引导步骤
            if ~isempty(obj.ExpGuide)
                obj.ExpGuide.completeStep('stop_heat');
                obj.showNextStepHint();
            end

            % 如果有足够数据，启用分析按钮
            if length(obj.TempData) >= 3
                obj.BtnAnalyze.Enable = 'on';
                ui.StyleConfig.applyButtonStyle(obj.BtnAnalyze, 'primary');
            end
        end

        function analyzeData(obj)
            % 数据分析 - 线性回归
            [canProceed, ~] = obj.checkOperationValid('analyze');
            if ~canProceed, return; end

            if length(obj.TempData) < 2
                uialert(obj.Figure, '数据点不足，无法进行分析', '提示');
                return;
            end

            obj.ExpStage = obj.STAGE_ANALYZED;

            % 线性回归：ΔL = K * (t - t1)，其中 K = α * L1
            % 使用 polyfit 进行一次多项式拟合
            p = polyfit(obj.TempData, obj.LengthData, 1);
            obj.SlopeK = p(1);  % 斜率 K (mm/°C)

            % 绘制拟合直线
            cla(obj.LTCurveAxes);
            hold(obj.LTCurveAxes, 'on');

            % 数据点
            plot(obj.LTCurveAxes, obj.TempData, obj.LengthData, 'bo', ...
                'MarkerSize', 8, 'MarkerFaceColor', 'b', 'LineWidth', 1.5);

            % 拟合直线
            tFit = linspace(min(obj.TempData), max(obj.TempData), 100);
            lFit = polyval(p, tFit);
            plot(obj.LTCurveAxes, tFit, lFit, 'r-', 'LineWidth', 2);

            % 添加斜率标注
            text(obj.LTCurveAxes, mean(obj.TempData), max(obj.LengthData) * 0.8, ...
                sprintf('K = %.6f mm/°C', obj.SlopeK), ...
                'FontName', ui.StyleConfig.FontFamily, ...
                'FontSize', 12, ...
                'Color', [0.8, 0, 0]);

            hold(obj.LTCurveAxes, 'off');
            xlabel(obj.LTCurveAxes, '温度 t (°C)');
            ylabel(obj.LTCurveAxes, '长度变化 ΔL (mm)');
            title(obj.LTCurveAxes, 'L-t 曲线（含拟合直线）', 'FontName', ui.StyleConfig.FontFamily);
            legend(obj.LTCurveAxes, {'实验数据', '拟合直线'}, 'Location', 'northwest');

            obj.updateStatus(sprintf('线性回归完成，斜率 K = %.6f mm/°C', obj.SlopeK));

            obj.BtnAnalyze.Enable = 'off';
            obj.BtnCalculate.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnCalculate, 'primary');

            obj.ExpGuide.completeStep('analyze');
            obj.showNextStepHint();
        end

        function calculateResult(obj)
            % 计算线胀系数
            [canProceed, ~] = obj.checkOperationValid('calculate');
            if ~canProceed, return; end

            % α = K / L1 (单位转换)
            % K 的单位是 mm/°C, L1 的单位是 mm
            % 所以 α 的单位是 1/°C
            obj.Alpha_measured = obj.SlopeK / obj.SampleLength;

            % 转换为 ×10^-5 /°C
            alphaMeasured_e5 = obj.Alpha_measured * 1e5;

            % 计算相对误差
            obj.RelativeError = abs(alphaMeasured_e5 - obj.Alpha_standard) / obj.Alpha_standard * 100;

            % 更新结果显示
            obj.safeSetText(obj.LblResultAlpha, sprintf('%.2f×10⁻⁵ /°C', alphaMeasured_e5));
            obj.safeSetText(obj.LblResultError, sprintf('%.2f%%', obj.RelativeError));

            obj.ExpStage = obj.STAGE_CALCULATED;
            obj.logOperation('计算完成', sprintf('α=%.4f×10⁻⁵/°C, 误差=%.2f%%', alphaMeasured_e5, obj.RelativeError));
            obj.updateStatus(sprintf('计算完成！α = %.2f×10⁻⁵ /°C，标准值 %.2f×10⁻⁵ /°C，相对误差 %.2f%%', ...
                alphaMeasured_e5, obj.Alpha_standard, obj.RelativeError));

            obj.BtnCalculate.Enable = 'off';
            obj.BtnComplete.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnComplete, 'success');

            obj.ExpGuide.completeStep('calculate');
            obj.showNextStepHint();
        end

        function resetExperiment(obj)
            % 重置实验
            obj.logOperation('重置实验');
            obj.stopHeating();

            % 重置数据
            obj.CurrentTemp = obj.TempStart;
            obj.CurrentLength = obj.SampleLength;
            obj.TempData = [];
            obj.LengthData = [];
            obj.RecordCount = 0;
            obj.Alpha_measured = 0;
            obj.SlopeK = 0;
            obj.RelativeError = 0;
            obj.ExpStage = obj.STAGE_INIT;
            obj.IsHeating = false;
            obj.LastRecordTemp = 0;
            obj.ExperimentCompleted = false;
            obj.LTCurveInitialized = false;

            % 重置显示
            obj.ThermometerDisplay.Text = sprintf('%.2f °C', obj.CurrentTemp);
            obj.DialGaugeDisplay.Text = sprintf('%.3f mm', 0);
            obj.HeaterDisplay.Text = '关闭';
            obj.HeaterDisplay.FontColor = [0.5, 0.5, 0.5];
            obj.DataTable.Data = {};
            obj.disableExportButton();

            % 重置结果
            obj.safeSetText(obj.LblResultAlpha, '待计算');
            obj.safeSetText(obj.LblResultError, '待计算');

            % 重置曲线
            cla(obj.LTCurveAxes);
            xlim(obj.LTCurveAxes, [20, 85]);
            ylim(obj.LTCurveAxes, [0, 0.5]);
            xlabel(obj.LTCurveAxes, '温度 t (°C)');
            ylabel(obj.LTCurveAxes, '长度变化 ΔL (mm)');
            title(obj.LTCurveAxes, 'L-t 曲线', 'FontName', ui.StyleConfig.FontFamily);

            % 重置仪器图
            obj.drawApparatus();

            % 重置按钮
            obj.BtnSetup.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnSetup, 'primary');
            obj.BtnSetParams.Enable = 'off';
            obj.BtnStartHeat.Enable = 'off';
            obj.BtnRecord.Enable = 'off';
            obj.BtnStopHeat.Enable = 'off';
            obj.BtnAnalyze.Enable = 'off';
            obj.BtnCalculate.Enable = 'off';
            obj.BtnComplete.Enable = 'off';

            % 重置实验引导
            if ~isempty(obj.ExpGuide)
                obj.ExpGuide.reset();
            end

            obj.updateStatus('实验已重置，请按步骤重新操作');
        end
    end

    methods (Access = protected)
        function onCleanup(obj)
            % 清理资源
            obj.safeStopTimer(obj.HeatingTimer);
            obj.HeatingTimer = [];
        end
    end

    methods (Access = private)
        function restoreButtonStates(obj)
            % 根据当前实验阶段恢复按钮状态

            % 先禁用所有按钮
            allBtns = {obj.BtnSetup, obj.BtnSetParams, obj.BtnStartHeat, ...
                       obj.BtnRecord, obj.BtnStopHeat, obj.BtnAnalyze, ...
                       obj.BtnCalculate, obj.BtnComplete};
            obj.disableAllButtons(allBtns);

            switch obj.ExpStage
                case obj.STAGE_INIT
                    obj.BtnSetup.Enable = 'on';
                    ui.StyleConfig.applyButtonStyle(obj.BtnSetup, 'primary');
                case obj.STAGE_SETUP
                    obj.BtnSetParams.Enable = 'on';
                    ui.StyleConfig.applyButtonStyle(obj.BtnSetParams, 'primary');
                case obj.STAGE_HEATING
                    % 加热记录中
                    if obj.IsHeating
                        obj.BtnRecord.Enable = 'on';
                        ui.StyleConfig.applyButtonStyle(obj.BtnRecord, 'secondary');
                        obj.BtnStopHeat.Enable = 'on';
                        ui.StyleConfig.applyButtonStyle(obj.BtnStopHeat, 'warning');
                    else
                        obj.BtnAnalyze.Enable = 'on';
                        ui.StyleConfig.applyButtonStyle(obj.BtnAnalyze, 'primary');
                    end
                case obj.STAGE_ANALYZED
                    obj.BtnCalculate.Enable = 'on';
                    ui.StyleConfig.applyButtonStyle(obj.BtnCalculate, 'primary');
                case obj.STAGE_CALCULATED
                    obj.BtnComplete.Enable = 'on';
                    ui.StyleConfig.applyButtonStyle(obj.BtnComplete, 'success');
            end
        end
    end

    methods (Access = protected)
        function restoreExperimentUI(obj)
            % 从讨论页面返回时恢复实验界面
            obj.LTCurveInitialized = false;
            obj.setupExperimentUI();
            % 恢复仪器读数和图形
            obj.drawApparatus();
            obj.ThermometerDisplay.Text = sprintf('%.2f °C', obj.CurrentTemp);
            deltaL = obj.CurrentLength - obj.SampleLength;
            obj.DialGaugeDisplay.Text = sprintf('%.3f mm', deltaL);
            % 恢复 L-t 曲线
            if ~isempty(obj.TempData)
                obj.updateLTCurve();
            end
            % 恢复按钮状态
            obj.restoreButtonStates();
        end

        function summary = getExportSummary(obj)
            % 获取实验结果摘要
            summary = getExportSummary@experiments.ExperimentBase(obj);
            summary = [summary; ...
                {'材料', obj.SampleMaterial}; ...
                {'线胀系数 α (×10⁻⁵/°C)', sprintf('%.4f', obj.Alpha_measured * 1e5)}; ...
                {'标准值 (×10⁻⁵/°C)', sprintf('%.2f', obj.Alpha_standard)}; ...
                {'相对误差', sprintf('%.2f%%', obj.RelativeError)}; ...
                {'斜率 K (mm/°C)', sprintf('%.6f', obj.SlopeK)}; ...
                {'样品长度 (mm)', sprintf('%.1f', obj.SampleLength)}];
        end
    end

    methods (Access = private)
        function setupExperimentGuide(obj)
            % 初始化实验引导系统
            obj.ExpGuide = ui.ExperimentGuide(obj.Figure, @(msg) obj.updateStatus(msg));

            % 定义实验步骤
            obj.ExpGuide.addStep('setup', '1. 安装样品', ...
                '将金属管安装在支架上，连接温度计和千分表');
            obj.ExpGuide.addStep('set_params', '2. 设置参数', ...
                '设置测量温度范围和间隔', ...
                'Prerequisites', {'setup'});
            obj.ExpGuide.addStep('start_heat', '3. 开始加热', ...
                '接通加热器电源开始加热', ...
                'Prerequisites', {'set_params'});
            obj.ExpGuide.addStep('record', '4. 记录数据', ...
                '在每个温度点记录千分表读数', ...
                'Prerequisites', {'start_heat'});
            obj.ExpGuide.addStep('stop_heat', '5. 停止加热', ...
                '达到目标温度后停止加热', ...
                'Prerequisites', {'record'});
            obj.ExpGuide.addStep('analyze', '6. 数据分析', ...
                '用最小二乘法线性拟合L-t曲线', ...
                'Prerequisites', {'stop_heat'});
            obj.ExpGuide.addStep('calculate', '7. 计算结果', ...
                '计算线胀系数α', ...
                'Prerequisites', {'analyze'});
        end

    end
end
