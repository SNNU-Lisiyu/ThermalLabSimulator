classdef Exp3_2_ElectricHeat < experiments.ExperimentBase
    % Exp3_2_ElectricHeat 实验3-2 电热当量的测量与散热误差的研究
    % 用热交换法测量热功当量，学会分析散热误差并修正

    properties (Access = private)
        % UI组件
        SimulationAxes      % 仿真显示区域
        TempTimeAxes        % 温度-时间曲线

        % 仪器显示
        ThermometerDisplay  % 温度计显示
        VoltmeterDisplay    % 电压表显示
        AmmeterDisplay      % 电流表显示
        BalanceDisplay      % 天平显示
        TimerDisplay        % 计时器显示

        % 交互管理器
        InteractionMgr      % 仪器点击交互管理器

        % 控制按钮
        BtnWeighCup         % 称量内筒
        BtnPrepareWater     % 准备冷水
        BtnAddWater         % 加入冷水
        BtnWeighWater       % 称量水质量
        BtnReadResistance   % 读取电阻丝质量
        BtnWeighStirrer     % 称量搅拌器
        BtnSetCircuit       % 连接电路
        BtnStartRecord      % 开始记录
        BtnStartHeating     % 开始加热
        BtnStopHeating      % 停止加热
        BtnCalculate        % 计算热功当量
        BtnAnalyzeError     % 散热补偿分析
        BtnComplete         % 完成实验

        % 实验数据
        RoomTemp = 20           % 室温 T_h (°C)
        WaterInitTemp           % 冷水初始温度 (°C)
        CurrentTemp             % 当前温度
        CupMass = 85.6          % 内筒质量 m_2 (g)
        WaterMass = 0           % 水的质量 m_1 (g)
        ResistanceMass = 5.2    % 电阻丝质量 m_3 (g)
        StirrerMass = 12.8      % 搅拌器钢杆质量 m_4 (g)

        % 电学参数
        Voltage = 6.0           % 电压 U (V)
        Current = 1.8           % 电流 I (A)
        IsHeating = false       % 是否正在加热
        HeatingStartTime = 0    % 开始加热时间
        HeatingEndTime = 0      % 停止加热时间
        HeatingDuration = 0     % 加热持续时间 (s)

        % 时间记录
        TimeData = []           % 时间数据 (s)
        TempData = []           % 温度数据 (°C)
        RecordTimer             % 记录计时器
        AnimationTimer          % 动画计时器
        StirrerPhase = 0        % 搅拌动画相位
        ElapsedTime = 0         % 已过时间 (s)
        IsRecording = false     % 是否正在记录
        WaitingForStir = false  % 是否等待用户搅拌开始记录

        % 计算结果
        T1 = 0                  % 初始温度 T_1 (加热开始时)
        T2 = 0                  % 最终温度 T_2 (加热结束时最高温度)
        ElectricWork = 0        % 电功 A (J)
        HeatAbsorbed = 0        % 吸收热量 Q (cal)
        J_measured = 0          % 测得热功当量

        % 散热补偿相关
        S_A = 0                 % 加热阶段高于室温部分面积
        S_B = 0                 % 加热阶段低于室温部分面积
        DeltaQ = 0              % 散热修正量
        J_corrected = 0         % 修正后的热功当量

        % 缓存UI句柄
        CachedHeatingStatus     % 加热状态标签
        CachedWaterMassLabel    % 水质量参数标签
        CachedStirrerMassLabel  % 搅拌器质量参数标签
        CachedResistanceMassLabel % 电阻丝质量参数标签
        CachedVoltageLabel      % 电压参数标签
        CachedCurrentLabel      % 电流参数标签
        CachedResultA           % 结果：电功
        CachedResultQ           % 结果：热量
        CachedResultJ           % 结果：热功当量
        CachedResultError       % 结果：相对误差
        CachedResultJCorrected  % 结果：修正热功当量
        CachedResultErrorCorrected % 结果：修正误差

        % 增量曲线更新缓存
        CurvePlotHandle         % 温度曲线 plot 句柄
        CurveHeatStartLine      % 开始加热参考线
        CurveHeatEndLine        % 停止加热参考线
        CurveRoomLine           % 室温参考线
        CurveInitialized = false
    end

    properties (Constant)
        % 物理常数
        c_water = 1.00          % 水的比热容 c_1 (cal/(g·°C))
        c_copper = 0.092        % 铜的比热容 c_2 (cal/(g·°C)) - 内筒、电阻丝
        c_steel = 0.120         % 钢的比热容 c_3 (cal/(g·°C)) - 搅拌器
        J_standard = 4.186      % 热功当量标准值 (J/cal)

        % 模拟参数
        CoolCoefficient = 0.012     % 自然冷却系数
        WarmCoefficient = 0.003     % 自然升温系数（冷水→室温）
        HeatLossCoefficient = 0.0002 % 加热时散热系数

        % 实验阶段常量
        STAGE_INIT = 0
        STAGE_WEIGHED = 1
        STAGE_WATER_ADDED = 2
        STAGE_CIRCUIT_SET = 3
        STAGE_CALCULATED = 4
        STAGE_ANALYZED = 5
    end

    methods (Access = public)
        function obj = Exp3_2_ElectricHeat()
            % 构造函数
            obj@experiments.ExperimentBase();

            % 设置实验基本信息
            obj.ExpNumber = '实验3-2';
            obj.ExpTitle = '电热当量的测量与散热误差的研究';

            % 实验目的
            obj.ExpPurpose = ['1. 用热交换法测量热功当量' newline ...
                '2. 分析散热误差并修正'];

            % 实验仪器
            obj.ExpInstruments = ['量热器、电流表、电压表、直流稳压电源、秒表、电子天平、冰、水、加热器、精细温度计、计时器'];

            % 实验原理
            obj.ExpPrinciple = [
                '【热功当量的历史背景】' newline ...
                '在没有认识热的本质以前，热量、功、能量的关系并不清楚，所以它们用不同的单位来表示。' ...
                '热量的单位用卡路里，简称卡。焦耳认为热量和功应当有一定的当量关系，即热量的单位卡和功的单位焦耳间有一定的数量关系。' newline ...
                '他从1840年到1878年近40年的时间内，利用电热量热法和机械量热法进行了大量的实验，最终找出了热和功之间的当量关系。' newline newline ...
                '【电热法测热功当量】' newline ...
                '若加在某一导体两端的电压为U(V)，通过的电流为I(A)，则在t(s)内电功为：' newline ...
                '    A = UIt                           (3-2-1)' newline newline ...
                '如果这些电功全部转换为热量，并且使一个盛水的量热器系统的温度由T₁℃上升到T₂℃，' ...
                '则系统所吸收的热量为：' newline ...
                '    Q = [c₁m₁ + c₂(m₂ + m₃) + c₃m₄](T₂ - T₁)    (3-2-2)' newline newline ...
                '式中，m₁、m₂、m₃、m₄分别为水、量热器的内筒、电阻丝、搅拌器钢杆的质量，' ...
                'c₁、c₂、c₃分别为水、铜、钢的比热容，其大小分别为1 cal/(g·°C)、0.092 cal/(g·°C)、0.120 cal/(g·°C)。' newline newline ...
                '由于量热器可近似看作绝热，假定电功全部转化为热量，并被全部吸收，则可以计算出热功当量为：' newline ...
                '    J = A / Q                         (3-2-3)' newline newline ...
                '上式表明，热量以卡为单位时与功的单位之间的数量关系，相当于单位热量的功的数量，单位为J/cal。' ...
                '目前公认的热功当量值为4.1868 J/cal。' newline newline ...
                '【加热过程中的T(t)曲线与散热补偿】' newline ...
                '量热器并非绝热，因此和外部存在能量交换。温度变化时，可以对加热过程中的T(t)曲线进行大致分析。' newline ...
                '在加热过程中，一方面系统吸收电能转化为热量，速率为dQ₂/dt = UI/J；另一方面，系统以散热速率dQ₁/dt和外部进行能量交换。' newline newline ...
                '如果加热过程中不改变U、I，又由于J、Cs不发生改变，则温度变化可以近似为直线，斜率为常数：' newline ...
                '    dT/dt = UI/(JCs)                  (3-2-7)' newline newline ...
                '如果实验过程中环境温度T_h基本不变，选取t=t₁时系统初温T₁和t=t₂时系统末温T₂可使T₂-T_h=T_h-T₁，' ...
                '则整个加热过程中系统与外界的热交换（吸热和散热）大致抵消。'];

            % 实验内容
            obj.ExpContent = [
                '1. 电热当量测量' newline ...
                '   ① 用温度计测量室温，记为T_h；用电子天平称量内筒的质量m₂' newline ...
                '   ② 用冰块与自来水配置冷水，使其温度大约为T_h-15℃，并加入筒内（约2/3杯）' newline ...
                '   ③ 用盛水筒的质量减去m₂得到水的质量m₁' newline ...
                '   ④ 称量搅拌器，其质量记为m₄，在量热器外部直接读出电阻丝质量m₃' newline newline ...
                '2. 连接电路并记录数据' newline ...
                '   ① 按照实验装置连接好实验仪器，注意红"+"、黑"-"与量程选择，不能接反' newline ...
                '   ② 根据电表实际挡位选择电压表量程为"7.5V"或"7V"，电流表量程为"2.5A"或"2A"' newline ...
                '   ③ 确定电路连接无误后，闭合开关，选择调节稳压电源电压和电流旋钮' newline ...
                '   ④ 必要时调节电表挡位，使电表指针偏转大于2/3表盘刻度后，分别记录电压和电流值' newline newline ...
                '3. 加热与温度记录' newline ...
                '   ① 当温度上升至T₁=T_h-10℃时按下秒表开始计时，t₁=0s' newline ...
                '   ② 不断地搅拌并每隔20s记录一次温度' newline ...
                '   ③ 当温度上升至T₂=T_h+10℃时，不论时间间隔记录对应时间t₂' newline ...
                '   ④ 关闭稳压电源，继续搅拌，每隔20s记录一次温度，记录20组数据后停止' newline newline ...
                '4. 计算与误差分析' newline ...
                '   ① 将测量的实验数据代入式(3-2-1)~(3-2-3)计算电功、热量、电热当量的值' newline ...
                '   ② 作T-t曲线，在温度T₂→T₃曲线段上根据式(3-1-7)用作图法求出K/Cs进而得到K' newline ...
                '   ③ 数出直线t=t₁、t=t₂、T''=0和曲线T''(t)所包围的两部分面积S_A、S_B' newline ...
                '   ④ 若两种情况下的格子数相等，则说明t₁→t₂时间范围内散热补偿成立'];

            % 思考讨论
            obj.ExpQuestions = {
                '初温T₁℃是否一定要在通电前测量？可否任意选定？是否一通电就必须计时？', ...
                ['初温T₁的选择：' newline ...
                '1. T₁不一定要在通电前测量，可以在通电过程中选取' newline ...
                '2. 但T₁的选择不是任意的，应满足T₁=T_h-ΔT（如T_h-10℃）' newline ...
                '3. 不是一通电就必须计时，而是当温度达到预设的T₁时才开始计时' newline ...
                '4. 这样选择是为了使加热过程中吸热和散热大致抵消'];

                '按式(3-2-2)计算系统吸收的热量时，若把温度计插入水中部分的体积V(cm³)也考虑在内的话，则其吸收热量0.46V(T₂-T₁)(cal)也应计算出来。试给出这种情况下的实验结果，并比较分析对结果的影响。', ...
                ['考虑温度计吸热的影响：' newline ...
                '1. 温度计（玻璃+水银）的热容约为0.46 cal/(cm³·°C)' newline ...
                '2. 修正后的热量：Q'' = Q + 0.46V(T₂-T₁)' newline ...
                '3. 修正后的热功当量：J'' = A/Q''，会略小于不考虑时的值' newline ...
                '4. 影响大小取决于温度计浸入体积V与总热容的比值' newline ...
                '5. 对于精确测量，这一修正是必要的'];
                };

            % 初始化温度（冷水温度约为室温-15°C）
            obj.WaterInitTemp = obj.RoomTemp - 15 + randn()*0.5;
            obj.CurrentTemp = obj.WaterInitTemp;
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
                    'RowHeight', {'1x', 110, 160}, ...
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
                title(obj.SimulationAxes, '电热当量实验装置示意图', ...
                    'FontName', ui.StyleConfig.FontFamily, 'Color', ui.StyleConfig.TextPrimary);

                % 温度-时间曲线区域
                obj.TempTimeAxes = uiaxes(plotGrid);
                obj.TempTimeAxes.Layout.Row = 1;
                obj.TempTimeAxes.Layout.Column = 2;
                ui.StyleConfig.applyAxesStyle(obj.TempTimeAxes);
                title(obj.TempTimeAxes, '温度-时间曲线', ...
                    'FontName', ui.StyleConfig.FontFamily, 'Color', ui.StyleConfig.TextPrimary);
                xlabel(obj.TempTimeAxes, '时间 t (s)');
                ylabel(obj.TempTimeAxes, '温度 T (°C)');
                xlim(obj.TempTimeAxes, [0, 600]);
                ylim(obj.TempTimeAxes, [0, 35]);

                % 绘制初始装置
                obj.drawApparatus();

                % 初始化交互管理器并设置可点击区域
                obj.setupInteraction();

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

                % 仪器面板布局 (1行5列)
                instGrid = uigridlayout(instrumentPanel, [1, 5], ...
                    'ColumnWidth', {'1x', '1x', '1x', '1x', '0.8x'}, ...
                    'Padding', [5, 5, 5, 5], ...
                    'ColumnSpacing', 5, ...
                    'BackgroundColor', ui.StyleConfig.PanelColor);

                % 温度计
                obj.ThermometerDisplay = obj.createInstrumentDisplay(instGrid, '温度计', ...
                    sprintf('%.2f °C', obj.CurrentTemp), ui.StyleConfig.ThermometerColor, 1, 1);

                % 电压表
                obj.VoltmeterDisplay = obj.createInstrumentDisplay(instGrid, '电压表', ...
                    '0.00 V', ui.StyleConfig.VoltmeterColor, 1, 2);

                % 电流表
                obj.AmmeterDisplay = obj.createInstrumentDisplay(instGrid, '电流表', ...
                    '0.00 A', ui.StyleConfig.AmmeterColor, 1, 3);

                % 电子天平
                obj.BalanceDisplay = obj.createInstrumentDisplay(instGrid, '电子天平', ...
                    '0.00 g', ui.StyleConfig.BalanceColor, 1, 4);

                % 右侧状态区 (5列)
                statusGrid = uigridlayout(instGrid, [3, 1], ...
                    'RowHeight', {'1x', '1x', '1x'}, ...
                    'Padding', [0, 0, 0, 0], ...
                    'RowSpacing', 0, ...
                    'BackgroundColor', ui.StyleConfig.PanelColor);
                statusGrid.Layout.Row = 1;
                statusGrid.Layout.Column = 5;

                % 计时器
                obj.TimerDisplay = uilabel(statusGrid, ...
                    'Text', '00:00', ...
                    'HorizontalAlignment', 'center', ...
                    'FontName', ui.StyleConfig.FontFamilyMono, ...
                    'FontSize', 16, ...
                    'FontWeight', 'bold', ...
                    'FontColor', ui.StyleConfig.PrimaryColor);

                % 室温
                uilabel(statusGrid, ...
                    'Text', sprintf('室温: %.1f°C', obj.RoomTemp), ...
                    'HorizontalAlignment', 'center', ...
                    'FontSize', 10, ...
                    'FontColor', ui.StyleConfig.TextSecondary);

                % 加热状态
                obj.CachedHeatingStatus = uilabel(statusGrid, ...
                    'Text', '未开始', ...
                    'HorizontalAlignment', 'center', ...
                    'FontSize', 11, ...
                    'FontWeight', 'bold', ...
                    'FontColor', [0.5, 0.5, 0.5], ...
                    'Tag', 'HeatingStatus');

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

                % 按钮网格布局 (3行6列)
                btnGrid = uigridlayout(btnPanel, [3, 6], ...
                    'ColumnWidth', repmat({'1x'}, 1, 6), ...
                    'RowHeight', {'1x', '1x', '1x'}, ...
                    'Padding', [5, 5, 5, 5], ...
                    'RowSpacing', 5, 'ColumnSpacing', 5);

                % 第一行：准备阶段
                obj.BtnWeighCup = obj.createExpButton(btnGrid, '1.称量内筒', @(~,~) obj.weighCup(), 'primary', 1, 1);
                obj.BtnPrepareWater = obj.createExpButton(btnGrid, '2.准备冷水', @(~,~) obj.prepareWater(), 'disabled', 1, 2);
                obj.BtnAddWater = obj.createExpButton(btnGrid, '3.加入冷水', @(~,~) obj.addWater(), 'disabled', 1, 3);
                obj.BtnWeighWater = obj.createExpButton(btnGrid, '4.称量水', @(~,~) obj.weighWater(), 'disabled', 1, 4);
                obj.BtnWeighStirrer = obj.createExpButton(btnGrid, '5.称量搅拌器', @(~,~) obj.weighStirrer(), 'disabled', 1, 5);
                obj.BtnReadResistance = obj.createExpButton(btnGrid, '6.读电阻丝', @(~,~) obj.readResistanceMass(), 'disabled', 1, 6);

                % 第二行：记录与加热
                obj.BtnSetCircuit = obj.createExpButton(btnGrid, '7.连接电路', @(~,~) obj.setCircuit(), 'disabled', 2, 1);
                obj.BtnStartRecord = obj.createExpButton(btnGrid, '8.开始记录', @(~,~) obj.startRecording(), 'disabled', 2, 2);
                obj.BtnStartHeating = obj.createExpButton(btnGrid, '9.开始加热', @(~,~) obj.startHeating(), 'disabled', 2, 3);
                obj.BtnStopHeating = obj.createExpButton(btnGrid, '10.停止加热', @(~,~) obj.stopHeating(), 'disabled', 2, 4);
                obj.BtnCalculate = obj.createExpButton(btnGrid, '11.计算结果', @(~,~) obj.calculateResult(), 'disabled', 2, 5);
                obj.BtnAnalyzeError = obj.createExpButton(btnGrid, '12.散热分析', @(~,~) obj.analyzeHeatLoss(), 'disabled', 2, 6);

                % 第三行：完成与重置
                obj.BtnComplete = obj.createExpButton(btnGrid, '完成实验', @(~,~) obj.completeExperiment(), 'disabled', 3, 5);

                resetBtn = uibutton(btnGrid, 'Text', '重置实验', ...
                    'ButtonPushedFcn', @(~,~) obj.resetExperiment());
                resetBtn.Layout.Row = 3;
                resetBtn.Layout.Column = 6;
                ui.StyleConfig.applyButtonStyle(resetBtn, 'warning');

                % ==================== 右侧面板 ====================

                % ---------- 参数控制面板 (右上) ----------
                controlGrid = ui.StyleConfig.createControlPanelGrid(obj.ControlPanel, 8);

                % 标题行
                titleLabel = ui.StyleConfig.createPanelTitle(controlGrid, '实验参数');
                titleLabel.Layout.Row = 1;
                titleLabel.Layout.Column = [1, 2];

                paramLabels = {'室温 T_h:', '水的质量 m₁:', '内筒质量 m₂:', ...
                    '电阻丝 m₃:', '搅拌器 m₄:', '电压 U:', '电流 I:'};
                paramValues = {sprintf('%.1f °C', obj.RoomTemp), '待测量', ...
                    sprintf('%.2f g', obj.CupMass), '待测量', '待测量', ...
                    '待设置', '待设置'};
                paramTags = {'', 'WaterMassLabel', '', 'ResistanceMassLabel', ...
                    'StirrerMassLabel', 'VoltageLabel', 'CurrentLabel'};

                for i = 1:length(paramLabels)
                    l = ui.StyleConfig.createParamLabel(controlGrid, paramLabels{i});
                    l.Layout.Row = i + 1;
                    l.Layout.Column = 1;

                    v = ui.StyleConfig.createParamValue(controlGrid, paramValues{i});
                    v.Layout.Row = i + 1;
                    v.Layout.Column = 2;
                    if ~isempty(paramTags{i})
                        switch paramTags{i}
                            case 'WaterMassLabel',     obj.CachedWaterMassLabel = v;
                            case 'StirrerMassLabel',   obj.CachedStirrerMassLabel = v;
                            case 'ResistanceMassLabel', obj.CachedResistanceMassLabel = v;
                            case 'VoltageLabel',       obj.CachedVoltageLabel = v;
                            case 'CurrentLabel',       obj.CachedCurrentLabel = v;
                        end
                    end
                end

                % ---------- 实验数据面板 (右下) ----------
                dataPanelGrid = ui.StyleConfig.createDataPanelGrid(obj.DataPanel, '1x', 160);

                % 标题行
                dataTitleLabel = ui.StyleConfig.createPanelTitle(dataPanelGrid, '实验数据');
                dataTitleLabel.Layout.Row = 1;

                % 数据表格
                obj.DataTable = ui.StyleConfig.createDataTable(dataPanelGrid, ...
                    {'时间(s)', '温度(°C)', '备注'}, {60, 60, 'auto'});
                obj.DataTable.Layout.Row = 2;
                obj.DataTable.Data = {};

                % 结果区域
                resultGrid = ui.StyleConfig.createResultGrid(dataPanelGrid, 6);
                resultGrid.Layout.Row = 3;

                resLabels = {'电功 A =', '热量 Q =', '热功当量 J =', '相对误差 =', ...
                    '修正后 J'' =', '修正误差 ='};
                resTags = {'ResultA', 'ResultQ', 'ResultJ', 'ResultError', ...
                    'ResultJCorrected', 'ResultErrorCorrected'};

                for i = 1:6
                    l = ui.StyleConfig.createResultLabel(resultGrid, resLabels{i});
                    l.Layout.Row = i;
                    l.Layout.Column = 1;

                    v = ui.StyleConfig.createResultValue(resultGrid, '---');
                    v.Layout.Row = i;
                    v.Layout.Column = 2;
                    switch resTags{i}
                        case 'ResultA',              obj.CachedResultA = v;
                        case 'ResultQ',              obj.CachedResultQ = v;
                        case 'ResultJ',              obj.CachedResultJ = v;
                        case 'ResultError',          obj.CachedResultError = v;
                        case 'ResultJCorrected',     obj.CachedResultJCorrected = v;
                        case 'ResultErrorCorrected', obj.CachedResultErrorCorrected = v;
                    end
                end

                % 初始化实验引导系统
                obj.setupExperimentGuide();

                % 初始状态更新
                obj.updateStatus('准备开始实验，请按步骤操作');
                drawnow;

            catch ME
                uialert(obj.Figure, sprintf('UI初始化失败:\n%s\nFile: %s\nLine: %d', ...
                    ME.message, ME.stack(1).name, ME.stack(1).line), '程序错误');
            end
        end

        function drawApparatus(obj, stirrerOffset)
            % 绘制电热当量实验装置示意图（参考图3-2-1）
            if nargin < 2
                stirrerOffset = 0;
            end

            ax = obj.SimulationAxes;
            cla(ax);
            hold(ax, 'on');

            % === 量热器部分（左侧）===
            % 金属外筒
            rectangle(ax, 'Position', [0.05, 0.08, 0.45, 0.72], ...
                'Curvature', [0.02, 0.02], ...
                'FaceColor', [0.75, 0.75, 0.75], ...
                'EdgeColor', [0.3, 0.3, 0.3], ...
                'LineWidth', 2);

            % 绝热层
            rectangle(ax, 'Position', [0.08, 0.12, 0.39, 0.64], ...
                'FaceColor', [0.92, 0.92, 0.85], ...
                'EdgeColor', [0.6, 0.6, 0.5], ...
                'LineWidth', 1);

            % 金属内套
            rectangle(ax, 'Position', [0.11, 0.15, 0.33, 0.58], ...
                'FaceColor', [0.8, 0.8, 0.8], ...
                'EdgeColor', [0.4, 0.4, 0.4], ...
                'LineWidth', 1.5);

            % 金属内筒
            rectangle(ax, 'Position', [0.14, 0.18, 0.27, 0.52], ...
                'Curvature', [0.02, 0.02], ...
                'FaceColor', [0.85, 0.85, 0.9], ...
                'EdgeColor', [0.3, 0.3, 0.4], ...
                'LineWidth', 1.5);

            % 水（根据实验阶段显示）
            if obj.ExpStage >= obj.STAGE_WATER_ADDED
                waterColor = obj.tempToColor(obj.CurrentTemp);
                rectangle(ax, 'Position', [0.16, 0.20, 0.23, 0.42], ...
                    'FaceColor', waterColor, ...
                    'EdgeColor', 'none');

                % 水面波纹
                for i = 1:3
                    y = 0.60 + i*0.01;
                    plot(ax, linspace(0.17, 0.38, 15), ...
                        y + 0.003*sin(linspace(0, 3*pi, 15)), ...
                        'Color', [0.4, 0.6, 0.85], 'LineWidth', 0.5);
                end
            end

            % 绝热盖
            rectangle(ax, 'Position', [0.08, 0.73, 0.39, 0.06], ...
                'FaceColor', [0.6, 0.6, 0.55], ...
                'EdgeColor', [0.3, 0.3, 0.3], ...
                'LineWidth', 1);

            % 电极（两根）
            plot(ax, [0.18, 0.18], [0.30, 0.82], 'Color', [0.5, 0.3, 0.1], 'LineWidth', 3);
            plot(ax, [0.37, 0.37], [0.30, 0.82], 'Color', [0.5, 0.3, 0.1], 'LineWidth', 3);

            % 电阻丝（加热丝，弯曲形状）
            if obj.IsHeating
                wireColor = [1, 0.3, 0.1];  % 加热时发红
            else
                wireColor = [0.6, 0.6, 0.6];
            end
            xWire = linspace(0.18, 0.37, 30);
            yWire = 0.28 + 0.02*sin(linspace(0, 6*pi, 30));
            plot(ax, xWire, yWire, 'Color', wireColor, 'LineWidth', 2);

            % 温度计
            plot(ax, [0.24, 0.24], [0.25, 0.88], 'Color', [0.4, 0.4, 0.4], 'LineWidth', 4);
            plot(ax, [0.24, 0.24], [0.25, 0.88], 'Color', [0.9, 0.9, 0.95], 'LineWidth', 2);
            % 温度计液柱
            if obj.ExpStage >= obj.STAGE_WEIGHED
                bulbHeight = 0.25 + (obj.CurrentTemp / 50) * 0.5;
                bulbHeight = max(0.25, min(0.75, bulbHeight));
            else
                bulbHeight = 0.35;
            end
            plot(ax, [0.24, 0.24], [0.25, bulbHeight], 'r-', 'LineWidth', 2);
            plot(ax, 0.24, 0.25, 'ro', 'MarkerSize', 6, 'MarkerFaceColor', 'r');

            % 搅拌器
            plot(ax, [0.31, 0.31], [0.76 + stirrerOffset, 0.92 + stirrerOffset], 'k-', 'LineWidth', 3);
            plot(ax, [0.26, 0.36], [0.92 + stirrerOffset, 0.92 + stirrerOffset], 'k-', 'LineWidth', 3);
            plot(ax, [0.31, 0.31], [0.25 + stirrerOffset, 0.76 + stirrerOffset], 'Color', [0.3, 0.3, 0.3], 'LineWidth', 2);
            plot(ax, [0.25, 0.37], [0.28 + stirrerOffset, 0.28 + stirrerOffset], 'Color', [0.3, 0.3, 0.3], 'LineWidth', 2);
            plot(ax, [0.25, 0.37], [0.35 + stirrerOffset, 0.35 + stirrerOffset], 'Color', [0.3, 0.3, 0.3], 'LineWidth', 2);

            % === 电路部分（右侧）===
            % 电流表 (A)
            rectangle(ax, 'Position', [0.70, 0.70, 0.12, 0.12], ...
                'Curvature', [1, 1], ...
                'FaceColor', [1, 1, 0.9], ...
                'EdgeColor', [0.2, 0.2, 0.2], ...
                'LineWidth', 2);
            text(ax, 0.76, 0.76, 'A', 'FontSize', 14, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center', 'Color', ui.StyleConfig.TextPrimary);

            % 电压表 (V)
            rectangle(ax, 'Position', [0.70, 0.45, 0.12, 0.12], ...
                'Curvature', [1, 1], ...
                'FaceColor', [1, 1, 0.9], ...
                'EdgeColor', [0.2, 0.2, 0.2], ...
                'LineWidth', 2);
            text(ax, 0.76, 0.51, 'V', 'FontSize', 14, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center', 'Color', ui.StyleConfig.TextPrimary);

            % 开关 S
            plot(ax, [0.85, 0.85], [0.55, 0.65], 'k-', 'LineWidth', 2);
            if obj.IsHeating
                % 开关闭合
                plot(ax, [0.85, 0.85], [0.65, 0.70], 'k-', 'LineWidth', 2);
            else
                % 开关断开
                plot(ax, [0.85, 0.92], [0.65, 0.72], 'k-', 'LineWidth', 2);
            end
            text(ax, 0.90, 0.62, 'S', 'FontSize', 10, 'Color', ui.StyleConfig.TextPrimary);

            % 电源 E
            plot(ax, [0.85, 0.85], [0.25, 0.35], 'k-', 'LineWidth', 2);
            plot(ax, [0.80, 0.90], [0.35, 0.35], 'k-', 'LineWidth', 3);
            plot(ax, [0.83, 0.87], [0.38, 0.38], 'k-', 'LineWidth', 1.5);
            text(ax, 0.90, 0.30, 'E', 'FontSize', 10, 'Color', ui.StyleConfig.TextPrimary);

            % 连接线
            if obj.ExpStage >= obj.STAGE_CIRCUIT_SET
                lineColor = [0.2, 0.2, 0.8];
            else
                lineColor = [0.5, 0.5, 0.5];
            end
            % 从量热器电极到电路
            plot(ax, [0.18, 0.18, 0.55, 0.55, 0.70], [0.82, 0.88, 0.88, 0.76, 0.76], ...
                'Color', lineColor, 'LineWidth', 1.5);
            plot(ax, [0.82, 0.85], [0.76, 0.76], 'Color', lineColor, 'LineWidth', 1.5);
            plot(ax, [0.85, 0.85], [0.70, 0.76], 'Color', lineColor, 'LineWidth', 1.5);

            plot(ax, [0.37, 0.37, 0.60, 0.60, 0.70], [0.82, 0.95, 0.95, 0.51, 0.51], ...
                'Color', lineColor, 'LineWidth', 1.5);
            plot(ax, [0.82, 0.95, 0.95, 0.85], [0.51, 0.51, 0.25, 0.25], ...
                'Color', lineColor, 'LineWidth', 1.5);
            plot(ax, [0.85, 0.85], [0.35, 0.55], 'Color', lineColor, 'LineWidth', 1.5);

            % === 数字温度计显示（左下角）===
            rectangle(ax, 'Position', [0.02, 0.01, 0.18, 0.08], ...
                'FaceColor', [0.15, 0.15, 0.15], ...
                'EdgeColor', [0.1, 0.1, 0.1], ...
                'LineWidth', 1);
            text(ax, 0.11, 0.05, sprintf('%.1f°C', obj.CurrentTemp), ...
                'FontSize', 10, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center', ...
                'Color', [0.2, 1, 0.2], ...
                'FontName', 'Consolas');

            % === 标注 ===
            text(ax, 0.02, 0.85, '温度计', 'FontSize', 8, 'Color', ui.StyleConfig.TextPrimary);
            text(ax, 0.40, 0.85, '搅拌器', 'FontSize', 8, 'Color', ui.StyleConfig.TextPrimary);
            text(ax, 0.02, 0.50, '绝热盖', 'FontSize', 8, 'Color', ui.StyleConfig.TextPrimary);
            text(ax, 0.50, 0.50, '电极', 'FontSize', 8, 'Color', ui.StyleConfig.TextPrimary);
            text(ax, 0.50, 0.38, '绝热架', 'FontSize', 8, 'Color', ui.StyleConfig.TextPrimary);
            text(ax, 0.50, 0.25, '金属内套', 'FontSize', 8, 'Color', ui.StyleConfig.TextPrimary);
            text(ax, 0.50, 0.18, '金属内筒', 'FontSize', 8, 'Color', ui.StyleConfig.TextPrimary);
            text(ax, 0.50, 0.11, '绝热层', 'FontSize', 8, 'Color', ui.StyleConfig.TextPrimary);
            text(ax, 0.50, 0.04, '金属外筒', 'FontSize', 8, 'Color', ui.StyleConfig.TextPrimary);

            % 关键修复：设置所有绘图对象不拦截点击事件，使点击能穿透到Axes被InteractionManager捕获
            set(ax.Children, 'PickableParts', 'none');

            hold(ax, 'off');
            xlim(ax, [0, 1]);
            ylim(ax, [0, 1]);
            ax.XTick = [];
            ax.YTick = [];
        end

    end

    methods (Static, Access = private)
        function color = tempToColor(temp)
            % 根据温度返回水的颜色
            normalizedTemp = (temp - 5) / 35;  % 归一化到0-1（5-40°C）
            normalizedTemp = max(0, min(1, normalizedTemp));
            r = 0.4 + 0.5 * normalizedTemp;
            g = 0.6 + 0.2 * (1 - abs(normalizedTemp - 0.5) * 2);
            b = 1 - 0.4 * normalizedTemp;
            color = [r, g, b];
        end
    end

    methods (Access = private)
        function weighCup(obj)
            % 称量内筒
            [canProceed, ~] = obj.checkOperationValid('weigh_cup');
            if ~canProceed, return; end

            obj.BalanceDisplay.Text = sprintf('%.2f g', obj.CupMass);
            obj.ExpStage = obj.STAGE_WEIGHED;
            obj.updateStatus(sprintf('内筒质量 m₂ = %.2f g', obj.CupMass));

            obj.BtnWeighCup.Enable = 'off';
            obj.BtnPrepareWater.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnPrepareWater, 'primary');

            if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep('weigh_cup'); end
            obj.showNextStepHint();
        end

        function prepareWater(obj)
            % 准备冷水（温度约为室温-15°C）
            [canProceed, ~] = obj.checkOperationValid('prepare_water');
            if ~canProceed, return; end

            obj.WaterInitTemp = obj.RoomTemp - 15 + randn()*0.5;
            obj.CurrentTemp = obj.WaterInitTemp;
            obj.ThermometerDisplay.Text = sprintf('%.2f °C', obj.CurrentTemp);
            obj.updateStatus(sprintf('冷水已准备，温度约 %.1f°C (低于室温约15°C)', obj.CurrentTemp));

            obj.BtnPrepareWater.Enable = 'off';
            obj.BtnAddWater.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnAddWater, 'primary');

            if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep('prepare_water'); end
            obj.showNextStepHint();
        end

        function addWater(obj)
            % 加入冷水
            [canProceed, ~] = obj.checkOperationValid('add_water');
            if ~canProceed, return; end

            obj.ExpStage = obj.STAGE_WATER_ADDED;
            obj.WaterMass = 180 + rand()*30;  % 180-210g（约2/3杯）
            obj.drawApparatus();
            obj.updateStatus('冷水已加入量热器内筒');

            obj.BtnAddWater.Enable = 'off';
            obj.BtnWeighWater.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnWeighWater, 'primary');

            if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep('add_water'); end
            obj.showNextStepHint();
        end

        function weighWater(obj)
            % 称量水质量
            [canProceed, ~] = obj.checkOperationValid('weigh_water');
            if ~canProceed, return; end

            totalMass = obj.CupMass + obj.WaterMass;
            obj.BalanceDisplay.Text = sprintf('%.2f g', totalMass);

            obj.safeSetText(obj.CachedWaterMassLabel, sprintf('%.2f g', obj.WaterMass));

            obj.updateStatus(sprintf('水的质量 m₁ = %.2f g', obj.WaterMass));

            obj.BtnWeighWater.Enable = 'off';
            obj.BtnWeighStirrer.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnWeighStirrer, 'primary');

            if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep('weigh_water'); end
            obj.showNextStepHint();
        end

        function weighStirrer(obj)
            % 称量搅拌器
            [canProceed, ~] = obj.checkOperationValid('weigh_stirrer');
            if ~canProceed, return; end

            obj.StirrerMass = 12 + rand()*2;  % 12-14g
            obj.BalanceDisplay.Text = sprintf('%.2f g', obj.StirrerMass);

            obj.safeSetText(obj.CachedStirrerMassLabel, sprintf('%.2f g', obj.StirrerMass));

            obj.updateStatus(sprintf('搅拌器质量 m₄ = %.2f g', obj.StirrerMass));

            obj.BtnWeighStirrer.Enable = 'off';
            obj.BtnReadResistance.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnReadResistance, 'primary');

            if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep('weigh_stirrer'); end
            obj.showNextStepHint();
        end

        function readResistanceMass(obj)
            % 读取电阻丝质量（从量热器外部标注读取）
            [canProceed, ~] = obj.checkOperationValid('read_resistance');
            if ~canProceed, return; end

            obj.ResistanceMass = 5.0 + rand()*0.5;  % 5.0-5.5g

            obj.safeSetText(obj.CachedResistanceMassLabel, sprintf('%.2f g', obj.ResistanceMass));

            obj.updateStatus(sprintf('电阻丝质量 m₃ = %.2f g（从量热器外部标注读取）', obj.ResistanceMass));

            obj.BtnReadResistance.Enable = 'off';
            obj.BtnSetCircuit.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnSetCircuit, 'primary');

            if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep('read_resistance'); end
            obj.showNextStepHint();
        end

        function setCircuit(obj)
            % 连接电路
            [canProceed, ~] = obj.checkOperationValid('set_circuit');
            if ~canProceed, return; end

            obj.ExpStage = obj.STAGE_CIRCUIT_SET;

            % 设置电压和电流（模拟调节后的值）
            obj.Voltage = 6.0 + randn()*0.1;
            obj.Current = 1.8 + randn()*0.05;

            obj.VoltmeterDisplay.Text = sprintf('%.2f V', obj.Voltage);
            obj.AmmeterDisplay.Text = sprintf('%.2f A', obj.Current);

            obj.safeSetText(obj.CachedVoltageLabel, sprintf('%.2f V', obj.Voltage));
            obj.safeSetText(obj.CachedCurrentLabel, sprintf('%.2f A', obj.Current));

            obj.drawApparatus();
            obj.updateStatus(sprintf('电路已连接，电压 U = %.2f V，电流 I = %.2f A', obj.Voltage, obj.Current));

            obj.BtnSetCircuit.Enable = 'off';
            obj.BtnStartRecord.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnStartRecord, 'primary');

            if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep('set_circuit'); end
            obj.showNextStepHint();
        end

        function startRecording(obj)
            % 开始记录温度
            [canProceed, ~] = obj.checkOperationValid('start_record');
            if ~canProceed, return; end

            % 进入等待搅拌状态（保持 ExpStage=3，电路已连接）
            obj.WaitingForStir = true;
            obj.ElapsedTime = 0;
            obj.TimeData = [];
            obj.TempData = [];

            obj.updateStatus('请点击搅拌器进行搅拌，开始记录温度');

            obj.BtnStartRecord.Enable = 'off';

            % 启用搅拌器交互
            obj.updateInteractionHint();

            if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep('start_record'); end
            obj.showNextStepHint();
        end

        function updateRecording(obj)
            % 更新温度记录
            if ~obj.IsRecording
                return;
            end

            % 检查窗口有效性
            if isempty(obj.Figure) || ~isvalid(obj.Figure)
                obj.stopRecording();
                return;
            end

            % 更新时间（模拟加速：0.15秒 = 5秒）
            obj.ElapsedTime = obj.ElapsedTime + 5;
            timeSec = obj.ElapsedTime;

            % 更新计时器显示
            mins = floor(timeSec / 60);
            secs = mod(timeSec, 60);
            obj.TimerDisplay.Text = sprintf('%02d:%02d', mins, secs);

            % 计算当前温度（模拟物理过程）
            if ~obj.IsHeating
                % 未加热时：根据阶段判断
                if obj.HeatingEndTime > 0
                    % 加热结束后：自然冷却
                    dT = -obj.CoolCoefficient * (obj.CurrentTemp - obj.RoomTemp) * 5;
                    obj.CurrentTemp = obj.CurrentTemp + dT;
                else
                    % 加热前：轻微升温（假设环境温度略高于冷水温度）
                    dT = obj.WarmCoefficient * (obj.RoomTemp - obj.CurrentTemp) * 5;
                    obj.CurrentTemp = obj.CurrentTemp + dT;
                end
            else
                % 加热中：温度线性上升，同时考虑散热
                % dT/dt = UI/(J*Cs) - K*(T - T_h)/Cs
                % Cs 单位转换：cal/°C -> J/°C
                Cs_cal = obj.WaterMass * obj.c_water + ...
                     obj.CupMass * obj.c_copper + ...
                     obj.ResistanceMass * obj.c_copper + ...
                     obj.StirrerMass * obj.c_steel;  % cal/°C
                Cs_J = Cs_cal * obj.J_standard;  % J/°C

                % 加热速率：dT/dt = P/Cs = UI/Cs (°C/s)
                heatingRate = (obj.Voltage * obj.Current) / Cs_J;
                % 散热系数：设置较小的值使得散热损失可控
                % 由于T1比室温低10°C，T2比室温高10°C，应该使吸散热基本平衡
                dT = (heatingRate - obj.HeatLossCoefficient * (obj.CurrentTemp - obj.RoomTemp)) * 5;
                obj.CurrentTemp = obj.CurrentTemp + dT;
            end

            % 添加随机噪声
            obj.CurrentTemp = obj.CurrentTemp + randn()*0.02;

            % 更新温度显示
            obj.ThermometerDisplay.Text = sprintf('%.2f °C', obj.CurrentTemp);

            % 更新加热状态显示（使用缓存句柄）
            if ~isempty(obj.CachedHeatingStatus) && isvalid(obj.CachedHeatingStatus)
                if obj.IsHeating
                    obj.CachedHeatingStatus.Text = '加热中';
                    obj.CachedHeatingStatus.FontColor = [1, 0.3, 0];
                elseif obj.HeatingEndTime > 0
                    obj.CachedHeatingStatus.Text = '已停止';
                    obj.CachedHeatingStatus.FontColor = [0, 0.6, 0];
                else
                    obj.CachedHeatingStatus.Text = '未开始';
                    obj.CachedHeatingStatus.FontColor = [0.5, 0.5, 0.5];
                end
            end

            % 每15秒记录一次
            if mod(timeSec, 15) < 1
                obj.TimeData(end+1) = timeSec;
                obj.TempData(end+1) = obj.CurrentTemp;

                % 确定备注
                remark = '';
                if obj.IsHeating && abs(timeSec - obj.HeatingStartTime) < 15
                    remark = sprintf('开始加热 T₁=%.2f°C', obj.T1);
                elseif ~obj.IsHeating && obj.HeatingEndTime > 0 && abs(timeSec - obj.HeatingEndTime) < 15
                    remark = sprintf('停止加热 T₂=%.2f°C', obj.T2);
                end

                newRow = {sprintf('%.0f', timeSec), sprintf('%.2f', obj.CurrentTemp), remark};
                obj.DataTable.Data = [obj.DataTable.Data; newRow];
                obj.enableExportButton();
                obj.updateTempCurve();
            end

            % 不再从此处调用drawApparatus，由AnimationTimer统一负责重绘

            % 检查是否应该停止加热（温度达到 T_h + 10°C 时提示用户）
            if obj.IsHeating && obj.CurrentTemp >= obj.RoomTemp + 10
                % 启用停止加热按钮并提示用户
                obj.BtnStopHeating.Enable = 'on';
                ui.StyleConfig.applyButtonStyle(obj.BtnStopHeating, 'primary');
                obj.updateStatus(sprintf('温度已达到 %.2f°C (T_h+10°C)，请点击「停止加热」按钮！', obj.CurrentTemp));
            end

            % 检查是否完成冷却记录（停止加热后记录足够数据）
            if obj.HeatingEndTime > 0 && ~obj.IsHeating
                if (timeSec - obj.HeatingEndTime) >= 150  % 冷却记录约10组数据（150秒）
                    obj.stopRecording();
                    obj.BtnCalculate.Enable = 'on';
                    ui.StyleConfig.applyButtonStyle(obj.BtnCalculate, 'primary');
                    obj.updateStatus('数据记录完成，可以进行计算');
                end
            end
        end

        function updateTempCurve(obj)
            % 更新温度-时间曲线（增量更新）
            if isempty(obj.TempTimeAxes) || ~isvalid(obj.TempTimeAxes)
                return;
            end

            if isempty(obj.TimeData)
                return;
            end

            if ~obj.CurveInitialized || isempty(obj.CurvePlotHandle) || ~isvalid(obj.CurvePlotHandle)
                % 首次绘制或句柄失效时全量重绘
                cla(obj.TempTimeAxes);
                hold(obj.TempTimeAxes, 'on');

                obj.CurvePlotHandle = plot(obj.TempTimeAxes, obj.TimeData, obj.TempData, 'b-o', ...
                    'LineWidth', 1.5, 'MarkerSize', 4, 'MarkerFaceColor', 'b');

                if obj.HeatingStartTime > 0
                    obj.CurveHeatStartLine = xline(obj.TempTimeAxes, obj.HeatingStartTime, 'g--', '开始加热', ...
                        'LineWidth', 1.5, 'LabelVerticalAlignment', 'bottom');
                end

                if obj.HeatingEndTime > 0
                    obj.CurveHeatEndLine = xline(obj.TempTimeAxes, obj.HeatingEndTime, 'r--', '停止加热', ...
                        'LineWidth', 1.5, 'LabelVerticalAlignment', 'bottom');
                end

                obj.CurveRoomLine = yline(obj.TempTimeAxes, obj.RoomTemp, 'k--', ...
                    sprintf('T_h = %.1f°C', obj.RoomTemp), ...
                    'LineWidth', 1, 'Alpha', 0.7);

                hold(obj.TempTimeAxes, 'off');
                xlabel(obj.TempTimeAxes, '时间 t (s)');
                ylabel(obj.TempTimeAxes, '温度 T (°C)');
                title(obj.TempTimeAxes, '温度-时间曲线', 'FontName', ui.StyleConfig.FontFamily);
                obj.CurveInitialized = true;
            else
                % 增量更新：仅更新数据
                set(obj.CurvePlotHandle, 'XData', obj.TimeData, 'YData', obj.TempData);

                % 加热开始标记线
                if obj.HeatingStartTime > 0 && (isempty(obj.CurveHeatStartLine) || ~isvalid(obj.CurveHeatStartLine))
                    hold(obj.TempTimeAxes, 'on');
                    obj.CurveHeatStartLine = xline(obj.TempTimeAxes, obj.HeatingStartTime, 'g--', '开始加热', ...
                        'LineWidth', 1.5, 'LabelVerticalAlignment', 'bottom');
                    hold(obj.TempTimeAxes, 'off');
                end

                % 加热结束标记线
                if obj.HeatingEndTime > 0 && (isempty(obj.CurveHeatEndLine) || ~isvalid(obj.CurveHeatEndLine))
                    hold(obj.TempTimeAxes, 'on');
                    obj.CurveHeatEndLine = xline(obj.TempTimeAxes, obj.HeatingEndTime, 'r--', '停止加热', ...
                        'LineWidth', 1.5, 'LabelVerticalAlignment', 'bottom');
                    hold(obj.TempTimeAxes, 'off');
                end
            end

            % 动态调整X轴
            currentMaxTime = max(600, max(obj.TimeData) + 50);
            xlim(obj.TempTimeAxes, [0, currentMaxTime]);

            % 动态调整Y轴
            minT = min(obj.TempData);
            maxT = max(obj.TempData);
            lowerBound = min(0, minT - 5);
            upperBound = max(40, maxT + 5);
            ylim(obj.TempTimeAxes, [lowerBound, upperBound]);
        end

        function startHeating(obj)
            % 开始加热 - 当温度达到 T_h - 10°C 时开始
            [canProceed, ~] = obj.checkOperationValid('start_heating');
            if ~canProceed, return; end

            targetT1 = obj.RoomTemp - 10;  % 目标初温
            if obj.CurrentTemp < targetT1 - 1
                uialert(obj.Figure, sprintf('温度尚未达到目标值\n请等待温度升至 %.1f°C (T_h-10°C) 左右再开始加热\n当前温度: %.1f°C', ...
                    targetT1, obj.CurrentTemp), '提示');
                return;
            elseif obj.CurrentTemp > targetT1 + 3
                % 温度已超过合适范围，建议重置
                selection = uiconfirm(obj.Figure, ...
                    sprintf('当前温度 %.1f°C 已超过最佳开始加热温度 %.1f°C\n\n继续加热可能导致实验误差增大。\n建议重置实验，重新准备冷水。', ...
                    obj.CurrentTemp, targetT1), ...
                    '温度超出范围', ...
                    'Options', {'继续加热', '重置实验'}, ...
                    'DefaultOption', 2, ...
                    'CancelOption', 2, ...
                    'Icon', 'warning');
                if strcmp(selection, '重置实验')
                    obj.resetExperiment();
                    return;
                end
            end

            obj.IsHeating = true;
            obj.HeatingStartTime = obj.ElapsedTime;
            obj.T1 = obj.CurrentTemp;  % 记录初始温度

            obj.drawApparatus();
            obj.updateStatus(sprintf('开始加热，初始温度 T₁ = %.2f°C，请等待温度上升至 T₂ = %.1f°C (T_h+10°C)', ...
                obj.T1, obj.RoomTemp + 10));

            obj.BtnStartHeating.Enable = 'off';

            if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep('start_heating'); end
            obj.showNextStepHint();
        end

        function stopHeating(obj)
            % 停止加热
            obj.IsHeating = false;
            obj.HeatingEndTime = obj.ElapsedTime;
            obj.T2 = obj.CurrentTemp;  % 记录最终温度
            obj.HeatingDuration = obj.HeatingEndTime - obj.HeatingStartTime;

            obj.drawApparatus();
            obj.updateStatus(sprintf('停止加热，最终温度 T₂ = %.2f°C，加热时间 t = %.0f s，继续记录冷却数据', ...
                obj.T2, obj.HeatingDuration));

            obj.BtnStopHeating.Enable = 'off';

            if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep('stop_heating'); end
            obj.showNextStepHint();
        end

        function stopRecording(obj)
            % 停止记录
            obj.IsRecording = false;
            obj.WaitingForStir = false;

            obj.safeStopTimer(obj.RecordTimer);
            obj.RecordTimer = [];

            % 停止动画计时器
            obj.safeStopTimer(obj.AnimationTimer);
            obj.AnimationTimer = [];

            % 重置搅拌器位置
            if ~isempty(obj.SimulationAxes) && isvalid(obj.SimulationAxes)
                obj.drawApparatus(0);
            end

            % 更新交互状态
            obj.updateInteractionHint();
        end

        function calculateResult(obj)
            % 计算热功当量
            [canProceed, ~] = obj.checkOperationValid('calculate');
            if ~canProceed, return; end

            % 找到加热结束后的最高温度作为 T2（考虑热惯性）
            if obj.HeatingEndTime > 0
                % 找出加热结束后一段时间内的最高温度
                postHeatingIdx = obj.TimeData >= obj.HeatingEndTime & ...
                                 obj.TimeData <= obj.HeatingEndTime + 60;
                if any(postHeatingIdx)
                    [maxTemp, ~] = max(obj.TempData(postHeatingIdx));
                    obj.T2 = maxTemp;  % 使用最高温度
                end
            end

            % 电功 A = UIt (J)
            obj.ElectricWork = obj.Voltage * obj.Current * obj.HeatingDuration;

            % 系统热容 Cs = c1*m1 + c2*(m2+m3) + c3*m4
            Cs = obj.c_water * obj.WaterMass + ...
                 obj.c_copper * (obj.CupMass + obj.ResistanceMass) + ...
                 obj.c_steel * obj.StirrerMass;

            % 吸收热量 Q (cal)
            obj.HeatAbsorbed = Cs * (obj.T2 - obj.T1);

            % 热功当量 J = A / Q (J/cal)
            obj.J_measured = obj.ElectricWork / obj.HeatAbsorbed;

            % 相对误差
            relError = abs(obj.J_measured - obj.J_standard) / obj.J_standard * 100;

            % 更新结果显示
            obj.safeSetText(obj.CachedResultA, sprintf('%.2f J', obj.ElectricWork));
            obj.safeSetText(obj.CachedResultQ, sprintf('%.2f cal', obj.HeatAbsorbed));
            obj.safeSetText(obj.CachedResultJ, sprintf('%.3f J/cal', obj.J_measured));
            obj.safeSetText(obj.CachedResultError, sprintf('%.2f%%', relError));

            obj.ExpStage = obj.STAGE_CALCULATED;
            obj.logOperation('计算完成', sprintf('J=%.4f J/cal, 误差=%.2f%%', obj.J_measured, relError));
            obj.updateStatus(sprintf('计算完成！热功当量 J = %.3f J/cal，相对误差 = %.2f%%', ...
                obj.J_measured, relError));

            obj.BtnCalculate.Enable = 'off';
            obj.BtnAnalyzeError.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnAnalyzeError, 'primary');

            if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep('calculate'); end
            obj.showNextStepHint();
        end

        function analyzeHeatLoss(obj)
            % 散热补偿分析
            [canProceed, ~] = obj.checkOperationValid('analyze_error');
            if ~canProceed, return; end

            % 找出加热阶段的数据
            heatingIdx = obj.TimeData >= obj.HeatingStartTime & obj.TimeData <= obj.HeatingEndTime;
            heatingTime = obj.TimeData(heatingIdx);
            heatingTemp = obj.TempData(heatingIdx);

            if isempty(heatingTime)
                obj.updateStatus('加热阶段数据不足，无法进行散热分析');
                return;
            end

            % 计算面积 S_A（温度高于室温部分）和 S_B（温度低于室温部分）
            % 使用数值积分近似
            obj.S_A = 0;
            obj.S_B = 0;

            for i = 1:length(heatingTime)-1
                dt = heatingTime(i+1) - heatingTime(i);
                avgTemp = (heatingTemp(i) + heatingTemp(i+1)) / 2;
                deltaT = avgTemp - obj.RoomTemp;

                if deltaT > 0
                    obj.S_A = obj.S_A + deltaT * dt;
                else
                    obj.S_B = obj.S_B + abs(deltaT) * dt;
                end
            end

            % 从冷却曲线计算散热系数 K
            coolingIdx = obj.TimeData > obj.HeatingEndTime;
            coolingTime = obj.TimeData(coolingIdx);
            coolingTemp = obj.TempData(coolingIdx);

            % 系统热容 (cal/°C)
            Cs = obj.c_water * obj.WaterMass + ...
                 obj.c_copper * (obj.CupMass + obj.ResistanceMass) + ...
                 obj.c_steel * obj.StirrerMass;

            if length(coolingTime) >= 5
                % 对冷却曲线拟合，估算散热速率
                % dQ/dt = K * (T - T_h)
                % Cs * dT/dt = K * (T - T_h)
                % 所以 K = Cs * |dT/dt| / |T - T_h|
                dT = diff(coolingTemp);
                dt = diff(coolingTime);
                avgT = (coolingTemp(1:end-1) + coolingTemp(2:end)) / 2;

                % 线性拟合 dT/dt vs (T - T_h)
                X = avgT - obj.RoomTemp;
                Y = dT ./ dt;
                validIdx = abs(X) > 0.5;  % 避免除零
                if sum(validIdx) >= 3
                    p = polyfit(X(validIdx), Y(validIdx), 1);
                    K_over_Cs = abs(p(1));  % |dT/dt| / |T - T_h| = K/Cs (1/s)
                    K = K_over_Cs * Cs;  % K = (K/Cs) * Cs (cal/(°C·s))
                else
                    K = 0.012 * Cs;  % 默认值
                end
            else
                K = 0.012 * Cs;  % 默认值：散热系数 cal/(°C·s)
            end

            % 散热修正量分析
            % S_A: 高于室温部分的面积（散热）
            % S_B: 低于室温部分的面积（吸热）
            % 当 S_A > S_B 时，散热 > 吸热，实际吸收的热量比测量值多
            % 修正：Q' = Q + K*(S_A - S_B)，但K值需要适当缩小
            % 使用较小的修正系数，避免过度修正
            K_correction = K * 0.1;  % 缩小修正系数
            obj.DeltaQ = K_correction * (obj.S_A - obj.S_B);

            % 修正后的热量
            Q_corrected = obj.HeatAbsorbed + obj.DeltaQ;

            % 修正后的热功当量
            obj.J_corrected = obj.ElectricWork / Q_corrected;

            % 修正后的相对误差
            relErrorCorrected = abs(obj.J_corrected - obj.J_standard) / obj.J_standard * 100;

            % 更新显示
            obj.safeSetText(obj.CachedResultJCorrected, sprintf('%.3f J/cal', obj.J_corrected));
            obj.safeSetText(obj.CachedResultErrorCorrected, sprintf('%.2f%%', relErrorCorrected));

            % 更新曲线，显示散热分析
            obj.updateTempCurveWithAnalysis();

            obj.ExpStage = obj.STAGE_ANALYZED;
            obj.updateStatus(sprintf('散热补偿分析完成！S_A=%.1f, S_B=%.1f, 修正后 J''=%.3f J/cal, 误差=%.2f%%', ...
                obj.S_A, obj.S_B, obj.J_corrected, relErrorCorrected));

            obj.BtnAnalyzeError.Enable = 'off';
            obj.BtnComplete.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnComplete, 'success');

            if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep('analyze_error'); end
            obj.showNextStepHint();
        end

        function updateTempCurveWithAnalysis(obj)
            % 在曲线上添加散热分析标注
            cla(obj.TempTimeAxes);
            hold(obj.TempTimeAxes, 'on');

            % 绘制数据曲线
            plot(obj.TempTimeAxes, obj.TimeData, obj.TempData, 'b-o', ...
                'LineWidth', 1.5, 'MarkerSize', 4, 'MarkerFaceColor', 'b');

            % 室温线
            yline(obj.TempTimeAxes, obj.RoomTemp, 'k--', ...
                sprintf('T_h = %.1f°C', obj.RoomTemp), 'LineWidth', 1.5);

            % 标记加热区间
            if obj.HeatingStartTime > 0 && obj.HeatingEndTime > 0
                xline(obj.TempTimeAxes, obj.HeatingStartTime, 'g-', 't₁', 'LineWidth', 2);
                xline(obj.TempTimeAxes, obj.HeatingEndTime, 'r-', 't₂', 'LineWidth', 2);

                % 填充高于室温的面积 (S_A) - 红色
                heatingIdx = obj.TimeData >= obj.HeatingStartTime & obj.TimeData <= obj.HeatingEndTime;
                heatingTime = obj.TimeData(heatingIdx);
                heatingTemp = obj.TempData(heatingIdx);

                aboveIdx = heatingTemp > obj.RoomTemp;
                if any(aboveIdx)
                    tAbove = heatingTime(aboveIdx);
                    tempAbove = heatingTemp(aboveIdx);
                    fill(obj.TempTimeAxes, [tAbove, fliplr(tAbove)], ...
                        [tempAbove, obj.RoomTemp*ones(size(tempAbove))], ...
                        [1, 0.8, 0.8], 'FaceAlpha', 0.5, 'EdgeColor', 'none');
                end

                % 填充低于室温的面积 (S_B) - 蓝色
                belowIdx = heatingTemp < obj.RoomTemp;
                if any(belowIdx)
                    tBelow = heatingTime(belowIdx);
                    tempBelow = heatingTemp(belowIdx);
                    fill(obj.TempTimeAxes, [tBelow, fliplr(tBelow)], ...
                        [tempBelow, obj.RoomTemp*ones(size(tempBelow))], ...
                        [0.8, 0.8, 1], 'FaceAlpha', 0.5, 'EdgeColor', 'none');
                end
            end

            % 标记关键温度点
            plot(obj.TempTimeAxes, obj.HeatingStartTime, obj.T1, 'gs', ...
                'MarkerSize', 10, 'MarkerFaceColor', 'g');
            text(obj.TempTimeAxes, obj.HeatingStartTime + 20, obj.T1, ...
                sprintf('T₁ = %.2f°C', obj.T1), 'FontSize', 10);

            plot(obj.TempTimeAxes, obj.HeatingEndTime, obj.T2, 'rs', ...
                'MarkerSize', 10, 'MarkerFaceColor', 'r');
            text(obj.TempTimeAxes, obj.HeatingEndTime + 20, obj.T2, ...
                sprintf('T₂ = %.2f°C', obj.T2), 'FontSize', 10);

            % 图例
            text(obj.TempTimeAxes, max(obj.TimeData)*0.7, 32, ...
                sprintf('S_A = %.1f (散热)', obj.S_A), ...
                'FontSize', 10, 'Color', [0.8, 0, 0]);
            text(obj.TempTimeAxes, max(obj.TimeData)*0.7, 30, ...
                sprintf('S_B = %.1f (吸热)', obj.S_B), ...
                'FontSize', 10, 'Color', [0, 0, 0.8]);

            hold(obj.TempTimeAxes, 'off');

            % 动态调整X轴
            currentMaxTime = 600;
            if ~isempty(obj.TimeData)
                currentMaxTime = max(currentMaxTime, max(obj.TimeData)+50);
            end
            xlim(obj.TempTimeAxes, [0, currentMaxTime]);

            % 动态调整Y轴
            currentYLim = [0, 35];
            if ~isempty(obj.TempData)
                minT = min(obj.TempData);
                maxT = max(obj.TempData);
                lowerBound = min(0, minT - 5);
                upperBound = max(40, maxT + 5);
                currentYLim = [lowerBound, upperBound];
            end
            ylim(obj.TempTimeAxes, currentYLim);

            xlabel(obj.TempTimeAxes, '时间 t (s)');
            ylabel(obj.TempTimeAxes, '温度 T (°C)');
            title(obj.TempTimeAxes, '温度-时间曲线（含散热分析）', 'FontName', ui.StyleConfig.FontFamily);
        end

        function resetExperiment(obj)
            % 重置实验
            obj.logOperation('重置实验');
            obj.stopRecording();

            % 重置数据
            obj.WaterInitTemp = obj.RoomTemp - 15 + randn()*0.5;
            obj.CurrentTemp = obj.WaterInitTemp;
            obj.WaterMass = 0;
            obj.TimeData = [];
            obj.TempData = [];
            obj.ElapsedTime = 0;
            obj.IsRecording = false;
            obj.IsHeating = false;
            obj.HeatingStartTime = 0;
            obj.HeatingEndTime = 0;
            obj.HeatingDuration = 0;
            obj.ExpStage = obj.STAGE_INIT;
            obj.T1 = 0;
            obj.T2 = 0;
            obj.ElectricWork = 0;
            obj.HeatAbsorbed = 0;
            obj.J_measured = 0;
            obj.S_A = 0;
            obj.S_B = 0;
            obj.DeltaQ = 0;
            obj.J_corrected = 0;

            % 重置基类状态标志
            obj.ExperimentCompleted = false;

            % 重置显示
            obj.ThermometerDisplay.Text = sprintf('%.2f °C', obj.CurrentTemp);
            obj.VoltmeterDisplay.Text = '0.00 V';
            obj.AmmeterDisplay.Text = '0.00 A';
            obj.BalanceDisplay.Text = '0.00 g';
            obj.TimerDisplay.Text = '00:00';
            obj.DataTable.Data = {};
            obj.disableExportButton();
            paramRefs = {obj.CachedWaterMassLabel, obj.CachedResistanceMassLabel, obj.CachedStirrerMassLabel, obj.CachedVoltageLabel, obj.CachedCurrentLabel};
            defaults = {'待测量', '待测量', '待测量', '待设置', '待设置'};
            for i = 1:length(paramRefs)
                obj.safeSetText(paramRefs{i}, defaults{i});
            end

            % 重置结果显示
            resultRefs = {obj.CachedResultA, obj.CachedResultQ, obj.CachedResultJ, obj.CachedResultError, obj.CachedResultJCorrected, obj.CachedResultErrorCorrected};
            resultDefaults = {'待计算', '待计算', '待计算', '待计算', '待分析', '待分析'};
            for i = 1:length(resultRefs)
                obj.safeSetText(resultRefs{i}, resultDefaults{i});
            end

            % 重置加热状态（使用缓存句柄）
            if ~isempty(obj.CachedHeatingStatus) && isvalid(obj.CachedHeatingStatus)
                obj.CachedHeatingStatus.Text = '未开始';
                obj.CachedHeatingStatus.FontColor = [0.5, 0.5, 0.5];
            end

            % 重置曲线
            obj.CurveInitialized = false;
            cla(obj.TempTimeAxes);
            xlim(obj.TempTimeAxes, [0, 600]);
            ylim(obj.TempTimeAxes, [0, 35]);
            title(obj.TempTimeAxes, '温度-时间曲线');
            xlabel(obj.TempTimeAxes, '时间 t (s)');
            ylabel(obj.TempTimeAxes, '温度 T (°C)');

            % 重置装置图
            obj.drawApparatus();

            % 重置按钮
            obj.BtnWeighCup.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnWeighCup, 'primary');
            obj.BtnPrepareWater.Enable = 'off';
            obj.BtnAddWater.Enable = 'off';
            obj.BtnWeighWater.Enable = 'off';
            obj.BtnWeighStirrer.Enable = 'off';
            obj.BtnReadResistance.Enable = 'off';
            obj.BtnSetCircuit.Enable = 'off';
            obj.BtnStartRecord.Enable = 'off';
            obj.BtnStartHeating.Enable = 'off';
            obj.BtnStopHeating.Enable = 'off';
            obj.BtnCalculate.Enable = 'off';
            obj.BtnAnalyzeError.Enable = 'off';
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
            obj.stopRecording();
            if ~isempty(obj.InteractionMgr) && isvalid(obj.InteractionMgr)
                delete(obj.InteractionMgr);
            end
        end
    end

    methods (Access = private)
        function restoreUIState(obj)
            % 恢复UI组件状态

            % 恢复温度显示
            if ~isempty(obj.ThermometerDisplay) && isvalid(obj.ThermometerDisplay)
                obj.ThermometerDisplay.Text = sprintf('%.2f °C', obj.CurrentTemp);
            end

            % 恢复电压表显示
            if ~isempty(obj.VoltmeterDisplay) && isvalid(obj.VoltmeterDisplay)
                if obj.ExpStage >= obj.STAGE_CIRCUIT_SET
                    obj.VoltmeterDisplay.Text = sprintf('%.2f V', obj.Voltage);
                end
            end

            % 恢复电流表显示
            if ~isempty(obj.AmmeterDisplay) && isvalid(obj.AmmeterDisplay)
                if obj.ExpStage >= obj.STAGE_CIRCUIT_SET
                    obj.AmmeterDisplay.Text = sprintf('%.2f A', obj.Current);
                end
            end

            % 恢复天平显示
            if ~isempty(obj.BalanceDisplay) && isvalid(obj.BalanceDisplay)
                if obj.WaterMass > 0
                    obj.BalanceDisplay.Text = sprintf('%.2f g', obj.CupMass + obj.WaterMass);
                end
            end

            % 恢复计时器显示
            if ~isempty(obj.TimerDisplay) && isvalid(obj.TimerDisplay)
                mins = floor(obj.ElapsedTime / 60);
                secs = mod(floor(obj.ElapsedTime), 60);
                obj.TimerDisplay.Text = sprintf('%02d:%02d', mins, secs);
            end

            % 恢复数据表格
            if ~isempty(obj.DataTable) && isvalid(obj.DataTable) && ~isempty(obj.TimeData)
                tableData = {};
                for i = 1:length(obj.TimeData)
                    tableData{i, 1} = sprintf('%.0f', obj.TimeData(i));
                    tableData{i, 2} = sprintf('%.2f', obj.TempData(i));
                    if obj.HeatingStartTime > 0 && abs(obj.TimeData(i) - obj.HeatingStartTime) < 1
                        tableData{i, 3} = '开始加热';
                    elseif obj.HeatingEndTime > 0 && abs(obj.TimeData(i) - obj.HeatingEndTime) < 1
                        tableData{i, 3} = '停止加热';
                    else
                        tableData{i, 3} = '';
                    end
                end
                obj.DataTable.Data = tableData;
            end

            % 恢复计算结果
            if obj.J_measured > 0
                obj.safeSetText(obj.CachedResultA, sprintf('%.2f J', obj.ElectricWork));
                obj.safeSetText(obj.CachedResultQ, sprintf('%.2f cal', obj.HeatAbsorbed));
                obj.safeSetText(obj.CachedResultJ, sprintf('%.3f J/cal', obj.J_measured));

                relError = abs(obj.J_measured - obj.J_standard) / obj.J_standard * 100;
                obj.safeSetText(obj.CachedResultError, sprintf('%.2f%%', relError));
            end

            if obj.J_corrected > 0
                obj.safeSetText(obj.CachedResultJCorrected, sprintf('%.3f J/cal', obj.J_corrected));

                relErrorC = abs(obj.J_corrected - obj.J_standard) / obj.J_standard * 100;
                obj.safeSetText(obj.CachedResultErrorCorrected, sprintf('%.2f%%', relErrorC));
            end

            % 恢复装置图和曲线
            obj.drawApparatus();
            if ~isempty(obj.TimeData)
                obj.updateTempCurve();
            end

            % 恢复按钮状态
            obj.restoreButtonStates();

            % 更新状态栏
            if obj.ExpStage >= obj.STAGE_ANALYZED
                obj.updateStatus(sprintf('实验已完成！热功当量 J = %.3f J/cal', obj.J_measured));
            else
                obj.updateStatus('已返回实验界面');
            end
        end

        function restoreButtonStates(obj)
            % 根据当前实验阶段恢复按钮状态

            % 先禁用所有按钮
            allBtns = {obj.BtnWeighCup, obj.BtnPrepareWater, obj.BtnAddWater, ...
                       obj.BtnWeighWater, obj.BtnWeighStirrer, obj.BtnReadResistance, ...
                       obj.BtnSetCircuit, obj.BtnStartRecord, obj.BtnStartHeating, ...
                       obj.BtnStopHeating, obj.BtnCalculate, obj.BtnAnalyzeError, obj.BtnComplete};
            obj.disableAllButtons(allBtns);

            % 完成按钮使用绿色样式
            ui.StyleConfig.applyButtonStyle(obj.BtnComplete, 'success');

            % 根据阶段启用对应按钮
            switch obj.ExpStage
                case obj.STAGE_INIT
                    obj.BtnWeighCup.Enable = 'on';
                    ui.StyleConfig.applyButtonStyle(obj.BtnWeighCup, 'primary');
                case {obj.STAGE_WEIGHED, obj.STAGE_WATER_ADDED}
                    % 称量/加水阶段 - 通过引导系统判断当前子步骤
                    if ~isempty(obj.ExpGuide)
                        stepOrder = {'prepare_water','add_water','weigh_water','weigh_stirrer','read_resistance','set_circuit'};
                        btnOrder = {obj.BtnPrepareWater, obj.BtnAddWater, obj.BtnWeighWater, obj.BtnWeighStirrer, obj.BtnReadResistance, obj.BtnSetCircuit};
                        for si = 1:length(stepOrder)
                            [canDo, ~] = obj.ExpGuide.validateOperation(stepOrder{si});
                            if canDo
                                btnOrder{si}.Enable = 'on';
                                ui.StyleConfig.applyButtonStyle(btnOrder{si}, 'primary');
                                break;
                            end
                        end
                    else
                        obj.BtnPrepareWater.Enable = 'on';
                        ui.StyleConfig.applyButtonStyle(obj.BtnPrepareWater, 'primary');
                    end
                case obj.STAGE_CIRCUIT_SET
                    % 电路已连接/记录阶段
                    if ~obj.IsRecording && ~obj.WaitingForStir
                        obj.BtnStartRecord.Enable = 'on';
                        ui.StyleConfig.applyButtonStyle(obj.BtnStartRecord, 'primary');
                    end
                case obj.STAGE_CALCULATED
                    obj.BtnCalculate.Enable = 'on';
                    ui.StyleConfig.applyButtonStyle(obj.BtnCalculate, 'primary');
                otherwise
                    if obj.ExpStage >= obj.STAGE_ANALYZED
                        obj.BtnComplete.Enable = 'on';
                        ui.StyleConfig.applyButtonStyle(obj.BtnComplete, 'success');
                    end
            end
        end
    end

    methods (Access = protected)
        function restoreExperimentUI(obj)
            % 从讨论页面返回时恢复实验界面
            % 重新构建UI但保持所有实验数据状态
            obj.CurveInitialized = false;
            obj.setupExperimentUI();
            obj.restoreUIState();
        end

        function summary = getExportSummary(obj)
            % 获取实验结果摘要
            summary = getExportSummary@experiments.ExperimentBase(obj);
            relError = abs(obj.J_measured - obj.J_standard) / obj.J_standard * 100;
            relErrorCorr = abs(obj.J_corrected - obj.J_standard) / obj.J_standard * 100;
            summary = [summary; ...
                {'电功 A (J)', sprintf('%.4f', obj.ElectricWork)}; ...
                {'热量 Q (cal)', sprintf('%.4f', obj.HeatAbsorbed)}; ...
                {'热功当量 J (J/cal)', sprintf('%.4f', obj.J_measured)}; ...
                {'相对误差', sprintf('%.2f%%', relError)}; ...
                {'修正后 J (J/cal)', sprintf('%.4f', obj.J_corrected)}; ...
                {'修正后相对误差', sprintf('%.2f%%', relErrorCorr)}; ...
                {'标准值 (J/cal)', sprintf('%.3f', obj.J_standard)}];
        end
    end

    methods (Access = private)
        function setupExperimentGuide(obj)
            % 初始化实验引导系统
            obj.ExpGuide = ui.ExperimentGuide(obj.Figure, @(msg) obj.updateStatus(msg));

            % 定义实验步骤
            obj.ExpGuide.addStep('weigh_cup', '1. 称量内筒', ...
                '使用电子天平称量量热器内筒质量');
            obj.ExpGuide.addStep('prepare_water', '2. 准备冷水', ...
                '准备温度低于室温2-3°C的冷水', ...
                'Prerequisites', {'weigh_cup'});
            obj.ExpGuide.addStep('add_water', '3. 加入冷水', ...
                '将冷水倒入量热器内筒', ...
                'Prerequisites', {'prepare_water'});
            obj.ExpGuide.addStep('weigh_water', '4. 称量水质量', ...
                '再次称量以确定水的质量', ...
                'Prerequisites', {'add_water'});
            obj.ExpGuide.addStep('weigh_stirrer', '5. 称量搅拌器', ...
                '称量搅拌器钢杆质量', ...
                'Prerequisites', {'weigh_water'});
            obj.ExpGuide.addStep('read_resistance', '6. 读取电阻丝质量', ...
                '记录电阻丝质量', ...
                'Prerequisites', {'weigh_stirrer'});
            obj.ExpGuide.addStep('set_circuit', '7. 连接电路', ...
                '按电路图连接电路，设置电压和电流', ...
                'Prerequisites', {'read_resistance'});
            obj.ExpGuide.addStep('start_record', '8. 开始记录', ...
                '开始记录温度数据', ...
                'Prerequisites', {'set_circuit'});
            obj.ExpGuide.addStep('start_heating', '9. 开始加热', ...
                '接通电源开始加热', ...
                'Prerequisites', {'start_record'});
            obj.ExpGuide.addStep('stop_heating', '10. 停止加热', ...
                '温度上升到高于室温2-3°C时停止加热', ...
                'Prerequisites', {'start_heating'});
            obj.ExpGuide.addStep('calculate', '11. 计算热功当量', ...
                '根据数据计算热功当量J', ...
                'Prerequisites', {'stop_heating'});
            obj.ExpGuide.addStep('analyze_error', '12. 散热补偿分析', ...
                '使用图解法分析散热修正', ...
                'Prerequisites', {'calculate'});
        end

        function setupInteraction(obj)
            % 设置仪器交互区域
            obj.InteractionMgr = ui.InteractionManager(obj.SimulationAxes);

            % 搅拌器区域（仅覆盖手柄部分）
            % [x, y, w, h]
            obj.InteractionMgr.addZone('stirrer', ...
                [0.25, 0.76, 0.12, 0.20], ...
                '点击搅拌', ...
                @(id) obj.onInstrumentClick(id), ...
                'Enabled', false);

            % 初始化时显示提示
            obj.updateInteractionHint();
        end

        function onInstrumentClick(obj, instrumentId)
            % 仪器点击处理
            switch instrumentId
                case 'stirrer'
                    obj.performStirring();
            end
        end

        function performStirring(obj)
            % 执行搅拌操作
            if obj.WaitingForStir && ~obj.IsRecording
                % 点击搅拌器 -> 开始记录
                obj.WaitingForStir = false;
                obj.IsRecording = true;

                % Start Record Timer
                obj.RecordTimer = timer('ExecutionMode', 'fixedRate', ...
                    'Period', 0.15, ...  % 0.15秒 = 5模拟秒（33x加速）
                    'TimerFcn', @(~,~) obj.safeTimerCallback(@obj.updateRecording));
                start(obj.RecordTimer);

                % Start Animation Timer
                obj.StirrerPhase = 0;
                obj.AnimationTimer = timer('ExecutionMode', 'fixedRate', ...
                    'Period', 0.2, ...  % 5fps（原0.1s，降频减少绘制压力）
                    'TimerFcn', @(~,~) obj.safeTimerCallback(@obj.updateStirrerAnimation));
                start(obj.AnimationTimer);

                obj.updateStatus('记录已开始，请持续搅拌。等待温度上升至 T₁ = T_h - 10°C 时开始加热');

                % Disable stirrer interaction (one-time activation)
                % But keep visual feedback via animation
                if ~isempty(obj.InteractionMgr)
                   obj.InteractionMgr.setZoneEnabled('stirrer', false);
                   obj.updateInteractionHint();
                end

                % Enable "Start Heating"
                obj.BtnStartHeating.Enable = 'on';
                ui.StyleConfig.applyButtonStyle(obj.BtnStartHeating, 'primary');
            end
        end

        function updateStirrerAnimation(obj)
            % 更新搅拌动画
            if isempty(obj.SimulationAxes) || ~isvalid(obj.SimulationAxes)
                return;
            end

            obj.StirrerPhase = obj.StirrerPhase + 0.3;
            offset = 0.05 * sin(obj.StirrerPhase);
            obj.drawApparatus(offset);
        end

        function updateInteractionHint(obj)
            % 更新交互提示
            if isempty(obj.InteractionMgr)
                return;
            end

            % Default disable
            obj.InteractionMgr.setZoneEnabled('stirrer', false);
            obj.InteractionMgr.clearHighlights();

            highlightZones = {};

            if obj.WaitingForStir
                obj.InteractionMgr.setZoneEnabled('stirrer', true);
                highlightZones{end+1} = 'stirrer';
            end

            if ~isempty(highlightZones)
                obj.InteractionMgr.showHighlights(highlightZones);
            end
        end
    end
end
