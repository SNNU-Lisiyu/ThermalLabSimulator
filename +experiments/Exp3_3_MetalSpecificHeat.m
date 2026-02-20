classdef Exp3_3_MetalSpecificHeat < experiments.ExperimentBase
    % Exp3_3_MetalSpecificHeat 实验3-3 冷却法测量金属比热容
    % 用冷却法测量金属比热容，学会观察金属的冷却规律

    properties (Access = private)
        % UI组件
        SimulationAxes      % 仿真显示区域
        TempTimeAxes        % 温度-时间曲线

        % 仪器显示
        VoltmeterDisplay    % 数字电压表显示（热电偶测温）
        BalanceDisplay      % 天平显示
        TimerDisplay        % 计时器显示
        SampleDisplay       % 当前样品显示

        % 交互管理器
        InteractionMgr      % 仪器点击交互管理器

        % 动画与交互控制
        AnimationTimer      % 动画计时器
        HeatingPhase = 0    % 加热动画相位
        WaitingForHeater = false    % 等待放置加热器
        WaitingForCooling = false   % 等待开始冷却(移走加热器)

        % 缓存的UI句柄（避免findobj）
        CachedVoltmeterText     % 图中电压表读数文本
        CachedTempDisplay       % 对应温度显示标签
        CachedCoolingStatus     % 冷却状态标签

        % 缓存的参数与结果标签（避免findobj）
        CachedMassFeLabel       % 铁质量显示标签
        CachedMassCuLabel       % 铜质量显示标签
        CachedMassAlLabel       % 铝质量显示标签
        CachedResultFe          % 铁比热容结果标签
        CachedErrorFe           % 铁误差标签
        CachedResultAl          % 铝比热容结果标签
        CachedErrorAl           % 铝误差标签
        CachedUncertaintyFe     % 铁不确定度标签
        CachedUncertaintyAl     % 铝不确定度标签

        % 控制按钮
        BtnWeighFe          % 称量铁样品
        BtnWeighCu          % 称量铜样品
        BtnWeighAl          % 称量铝样品
        BtnSetupThermocouple % 安装热电偶
        BtnHeatSample       % 加热样品
        BtnStartCooling     % 开始冷却
        BtnRecordFe         % 记录铁的散热时间
        BtnRecordCu         % 记录铜的散热时间
        BtnRecordAl         % 记录铝的散热时间
        BtnChangeSample     % 更换样品按钮
        BtnCalculate        % 计算比热容
        BtnComplete         % 完成实验

        % 实验数据
        RoomTemp = 20           % 室温 T_0 (°C)
        CurrentTemp = 20        % 当前温度 (°C)
        CurrentVoltage = 0      % 当前电压读数 (mV)

        % 样品数据
        MassFe = 0              % 铁样品质量 (g)
        MassCu = 0              % 铜样品质量 (g)
        MassAl = 0              % 铝样品质量 (g)
        CurrentSample = ''      % 当前测量的样品

        % 散热时间数据（从102°C冷却到98°C的时间）
        CoolingTimesFe = []     % 铁的5次散热时间
        CoolingTimesCu = []     % 铜的5次散热时间
        CoolingTimesAl = []     % 铝的5次散热时间

        % 平均散热时间
        AvgTimeFe = 0
        AvgTimeCu = 0
        AvgTimeAl = 0

        % 时间记录
        TimeData = []           % 时间数据 (s)
        TempData = []           % 温度数据 (°C)
        RecordTimer             % 记录计时器
        ElapsedTime = 0         % 已过时间 (s)
        IsRecording = false     % 是否正在记录
        IsCooling = false       % 是否正在冷却
        CoolingStartTime = 0    % 开始冷却时间
        CoolingEndTime = 0      % 结束冷却时间

        % 计算结果
        C_Fe = 0                % 铁的比热容测量值
        C_Al = 0                % 铝的比热容测量值
    end

    properties (Constant)
        % 标准比热容 (cal/(g·°C))
        C_Cu_standard = 0.092   % 铜的比热容标准值
        C_Fe_standard = 0.107   % 铁的比热容标准值
        C_Al_standard = 0.215   % 铝的比热容标准值

        % 不确定度参数
        U_mass = 0.001          % 质量不确定度 (g)
        U_B = 0.01              % 计时仪器不确定度 (s)

        % 热电偶参数（铜-康铜热电偶）
        VoltageAt100C = 4.072   % 100°C对应的电压 (mV)
        VoltageAt102C = 4.157   % 102°C对应的电压 (mV)
        VoltageAt98C = 3.988    % 98°C对应的电压 (mV)
        VoltageTarget = 4.927   % 加热目标电压 (mV)

        % 模拟参数
        HeatingRate = 0.05      % 加热时电压上升速率 (mV/0.1s)
        CoolRateFe = 0.000280   % 铁的冷却速率
        CoolRateCu = 0.000240   % 铜的冷却速率（标准样品）
        CoolRateAl = 0.000170   % 铝的冷却速率

        % 实验阶段常量
        STAGE_INIT = 0
        STAGE_WEIGHED = 1
        STAGE_THERMOCOUPLE = 2
        STAGE_HEATING = 3
        STAGE_COOLING = 4
        STAGE_DATA_DONE = 5
        STAGE_CALCULATED = 6
    end

    methods (Access = public)
        function obj = Exp3_3_MetalSpecificHeat()
            % 构造函数
            obj@experiments.ExperimentBase();

            % 设置实验基本信息
            obj.ExpNumber = '实验3-3';
            obj.ExpTitle = '冷却法测量金属比热容';

            % 实验目的
            obj.ExpPurpose = ['1. 学会用冷却法测量金属比热容' newline ...
                '2. 观察金属的冷却规律'];

            % 实验仪器
            obj.ExpInstruments = ['FB312金属比热容测量仪（主机、升降台、热源、铜-康铜热电偶、加盖防风筒）、电子天平、金属样品（铜、铁、铝）'];

            % 实验原理
            obj.ExpPrinciple = [
                '【比热容与热传递】' newline ...
                '比热容是物质的重要属性之一，属于热学基本测量的内容。在热学实验中，常用冷却法' ...
                '或混合法测量物质的比热容。本实验以铜为标准样品，用冷却法测量铁、铝两种样品的比热容。' newline newline ...
                '【牛顿冷却定律】' newline ...
                '当物体温度与环境温度形成一定温差时，由热传递规律可知，物体的内能将随时间发生变化。' ...
                '物体从周围环境吸收热量或者放出热量，当物体温度与所处环境温度相同时，物体与周围环境的热交换结束。' newline newline ...
                '本实验研究物体在200℃以下的温度变化。温度不高时，物体热辐射很小，可以忽略；' ...
                '如果物体没有与良导体直接接触，热传导部分也可以忽略，只需观测热物体与周围环境进行的对流过程。' ...
                '此时物体温度下降的速率称为冷却速率。' newline newline ...
                '把质量为M₁、比热容为C₁的物体从室温T₀加热到温度T₁(T₁>T₀)后，将其放在室内环境中，' ...
                '让物体在周围的空气中自然冷却。若在Δt时间内，物体的温度下降了ΔT，则物体所散失的热量为：' newline ...
                '    ΔQ = C₁M₁ΔT                                    (3-3-1)' newline newline ...
                '物体的散热速率ΔQ/Δt与冷却速率ΔT/Δt成正比，即：' newline ...
                '    ΔQ/Δt = C₁M₁(ΔT/Δt)                            (3-3-2)' newline newline ...
                '式中，C₁为物体的比热容，物体的散热速率ΔQ/Δt与温差T₁-T₀及周围环境有关。' ...
                '当以对流为主要热交换方式时，根据牛顿冷却定律有：' newline ...
                '    ΔQ/Δt = α₁S₁(T₁-T₀)ᵐ                           (3-3-3)' newline newline ...
                '式中，α₁为热交换系数，S₁为样品表面积，m为常数。由式(3-3-2)和(3-3-3)可得：' newline ...
                '    C₁M₁(ΔT/Δt) = α₁S₁(T₁-T₀)ᵐ                     (3-3-4)' newline newline ...
                '【比热容计算方法】' newline ...
                '保持周围环境的温度T₀恒定不变，选取形状尺寸都相同的标准样品和被测样品。在此条件下，' ...
                '两样品有热交换系数α₁=α₂，面积S₁=S₂，并使两样品的散热温度相同，即T₁=T₂=T。' newline ...
                '则质量为M₂、比热容为C₂的物体的散热速率为：' newline ...
                '    C₂M₂(ΔT/Δt)₂ = α₂S₂(T₂-T₀)ᵐ                   (3-3-5)' newline newline ...
                '若已知标准样品的比热容为C₁，由式(3-3-4)和式(3-3-5)可得待测样品的比热容C₂为：' newline ...
                '    C₂ = C₁·[M₁(ΔT/Δt)₁]/[M₂(ΔT/Δt)₂] = C₁·M₁(Δt)₂/[M₂(Δt)₁]   (3-3-6)' newline newline ...
                '式中，M₁、C₁为已知标准样品（铜）的质量和比热容，M₂为待测样品的质量。'];

            % 实验内容
            obj.ExpContent = [
                '1. 称量样品质量' newline ...
                '   ① 选取长度、直径相同、表面光滑的三种金属样品（铜、铁、铝）' newline ...
                '   ② 用电子天平称出三种样品的质量M。由M_Cu > M_Fe > M_Al判断出样品的类别' newline newline ...
                '2. 安装热电偶' newline ...
                '   ① 如图3-3-1所示，先将热电偶从防风容器底端慢慢穿过' newline ...
                '   ② 再将长30mm、直径5mm带孔的小圆柱形待测样品套在热电偶上' newline ...
                '   ③ 热电偶的冷端放在冰水混合物内，把冷端引线接到数字表的负端，热端引线接到数字表的正端' newline newline ...
                '3. 加热样品' newline ...
                '   ① 将可移动的75W的模拟电炉慢慢地放入防风容器内，并将被测样品全部套在模拟电炉内的热电偶上' newline ...
                '   ② 先不要打开热源开关，将数字仪表后面的电源打开，首先调节数字表上的调零旋钮，使窗口数字显示为"000"字样' newline ...
                '   ③ 接通数字表上的热源开关，随时观察数字显示窗口' newline newline ...
                '4. 记录散热时间' newline ...
                '   ① 当显示"4.927mV"时，关闭热源开关，将模拟电炉移走' newline ...
                '   ② 用盖子盖住筒口，让样品在容器内自然冷却' newline ...
                '   ③ 当数字表热电动势值降为4.157mV（此时热电偶分度值对应的温度为102℃）时，开始用秒表记录时间' newline ...
                '   ④ 当数字表上热电势值降为3.988mV（热电偶分度值对应的温度为98℃）时，停止计时，从秒表中读出散热时间' newline ...
                '   ⑤ 按铁、铜、铝次序依次重复测量5次，将对应的时间填入表3-3-1中' newline newline ...
                '5. 计算比热容' newline ...
                '   ① 以铜为标准样品，已知C₁=C_Cu=0.092 cal/(g·°C)，1 cal=4.1868 J' newline ...
                '   ② 铁的比热容C₂=C₁·M₁(Δt)₂/[M₂(Δt)₁]' newline ...
                '   ③ 铝的比热容C₃=C₁·M₁(Δt)₃/[M₃(Δt)₁]'];

            % 思考讨论
            obj.ExpQuestions = {
                '如果热电偶冷端为室内温度时，能否找到具有相同的比热容的示值？', ...
                ['如果热电偶冷端为室内温度而非0°C（冰水混合物），会影响热电偶的温度测量：' newline ...
                '1. 热电偶测量的是冷热端之间的温差对应的电动势' newline ...
                '2. 如果冷端温度不是0°C，需要进行冷端补偿才能得到正确的温度值' newline ...
                '3. 但在本实验中，我们关注的是相同温度范围内的冷却时间' newline ...
                '4. 只要保持冷端温度恒定，仍然可以用相同的电压范围来判断温度范围' newline ...
                '5. 因此，可以找到对应的比热容值，但需要重新标定电压-温度对应关系'];

                '分析存在误差的原因有哪些方面？', ...
                ['存在误差的主要原因包括：' newline ...
                '1. 样品形状和尺寸差异：实际样品可能存在微小的形状差异，影响表面积' newline ...
                '2. 表面状态差异：不同金属表面的粗糙度和氧化程度不同，影响热交换系数α' newline ...
                '3. 环境温度波动：实验过程中室温可能有微小变化' newline ...
                '4. 计时误差：人工按秒表存在反应时间误差' newline ...
                '5. 热电偶读数误差：数字表的分辨率和读数判断存在误差' newline ...
                '6. 热平衡问题：样品内部温度分布可能不均匀'];

                '为什么可以用热电势的一段电势范围值代替一段温度示值，请加以解释？', ...
                ['可以用电势范围代替温度范围的原因：' newline ...
                '1. 热电偶的热电势与温度之间存在单调递增关系' newline ...
                '2. 在一定温度范围内（如98°C-102°C），电势与温度近似呈线性关系' newline ...
                '3. 由于ΔT/Δt中ΔT是固定的（102°C-98°C=4°C），所以只需要测量相同电势变化所需的时间' newline ...
                '4. 这样可以避免温度换算带来的误差，直接比较散热时间即可'];
                };

            % 初始化温度
            obj.CurrentTemp = obj.RoomTemp;
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
                    'RowHeight', {'1x', 140, 195}, ...
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
                title(obj.SimulationAxes, '金属比热容测量仪结构示意图', ...
                    'FontName', ui.StyleConfig.FontFamily, 'Color', ui.StyleConfig.TextPrimary);

                % 温度-时间曲线区域
                obj.TempTimeAxes = uiaxes(plotGrid);
                obj.TempTimeAxes.Layout.Row = 1;
                obj.TempTimeAxes.Layout.Column = 2;
                ui.StyleConfig.applyAxesStyle(obj.TempTimeAxes);
                title(obj.TempTimeAxes, '散热时间记录', ...
                    'FontName', ui.StyleConfig.FontFamily, 'Color', ui.StyleConfig.TextPrimary);
                xlabel(obj.TempTimeAxes, '测量次数');
                ylabel(obj.TempTimeAxes, '散热时间 \Delta t (s)');
                xlim(obj.TempTimeAxes, [0.5, 5.5]);
                ylim(obj.TempTimeAxes, [0, 100]);

                % 绘制初始装置
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

                % 仪器布局 (1行4列) - 调整为4列
                instGrid = uigridlayout(instrumentPanel, [1, 4], ...
                    'ColumnWidth', {'1x', '1x', '1x', '1x'}, ...
                    'Padding', [5, 5, 5, 5], ...
                    'ColumnSpacing', 15, ...
                    'BackgroundColor', ui.StyleConfig.PanelColor);

                % 天平 (1, 1)
                obj.BalanceDisplay = obj.createInstrumentDisplay(instGrid, '电子天平', ...
                    '0.000 g', ui.StyleConfig.BalanceColor, 1, 1);

                % 计时器 (1, 2) - 接管原电压表位置
                % 包装计时器显示，添加倍速标签
                timerContainer = uigridlayout(instGrid, [2, 1], ...
                    'RowHeight', {20, '1x'}, 'Padding', [0,0,0,0], 'RowSpacing', 0, ...
                    'BackgroundColor', ui.StyleConfig.PanelColor);
                timerContainer.Layout.Row = 1; timerContainer.Layout.Column = 2;

                uilabel(timerContainer, 'Text', '计时器 (5倍速)', 'HorizontalAlignment', 'center', ...
                    'FontSize', 11, 'FontColor', ui.StyleConfig.TextSecondary);
                obj.TimerDisplay = uilabel(timerContainer, 'Text', '00.00 s', 'HorizontalAlignment', 'center', ...
                    'FontName', ui.StyleConfig.FontFamilyMono, 'FontSize', 16, ...
                    'FontWeight', 'bold', 'FontColor', [0, 0, 0.8]);

                % 对应温度 (1, 3)
                tempContainer = uigridlayout(instGrid, [2, 1], ...
                    'RowHeight', {20, '1x'}, 'Padding', [0,0,0,0], 'RowSpacing', 0, ...
                    'BackgroundColor', ui.StyleConfig.PanelColor);
                tempContainer.Layout.Row = 1; tempContainer.Layout.Column = 3;

                obj.createSimpleLabel(tempContainer, '对应温度', 'center', ui.StyleConfig.TextSecondary);
                obj.CachedTempDisplay = obj.createSimpleLabel(tempContainer, '--', 'center', [0.8, 0, 0]);
                obj.CachedTempDisplay.FontSize = 16;
                obj.CachedTempDisplay.FontWeight = 'bold';
                obj.CachedTempDisplay.Tag = 'TempDisplay';

                % 样品显示 (1, 4)
                obj.SampleDisplay = obj.createInstrumentDisplay(instGrid, '当前样品', ...
                    '无', ui.StyleConfig.PrimaryColor, 1, 4);

                % 状态显示的"待开始"移至样品显示下方或其他位置？
                % 原代码中 obj.TimerDisplay 和 lblStatus 都在第5列 statusContainer
                % 现已移除第5列，将 lblStatus 集成到样品显示下方
                % 但 createInstrumentDisplay 是固定布局。
                % 修改样品显示容器以包含状态文本

                % 重新创建SampleDisplay容器以包含状态
                delete(obj.SampleDisplay.Parent); % 删除上面createInstrumentDisplay创建的容器

                sampleContainer = uigridlayout(instGrid, [3, 1], ...
                    'RowHeight', {20, '1x', 20}, 'Padding', [0,0,0,0], 'RowSpacing', 0, ...
                    'BackgroundColor', ui.StyleConfig.PanelColor);
                sampleContainer.Layout.Row = 1; sampleContainer.Layout.Column = 4;

                uilabel(sampleContainer, 'Text', '当前样品', 'HorizontalAlignment', 'center', ...
                    'FontSize', 11, 'FontColor', ui.StyleConfig.TextSecondary);

                obj.SampleDisplay = uilabel(sampleContainer, 'Text', '无', 'HorizontalAlignment', 'center', ...
                    'FontName', ui.StyleConfig.FontFamilyMono, 'FontSize', 16, ...
                    'FontWeight', 'bold', 'FontColor', ui.StyleConfig.PrimaryColor);

                obj.CachedCoolingStatus = uilabel(sampleContainer, 'Text', '待开始', 'HorizontalAlignment', 'center', ...
                    'FontSize', 11, 'FontWeight', 'bold', 'FontColor', [0.5, 0.5, 0.5]);
                obj.CachedCoolingStatus.Tag = 'CoolingStatus';


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

                % 第一行：准备与安装
                obj.BtnWeighFe = obj.createExpButton(btnGrid, '1.称量铁样品', @(~,~) obj.weighSample('Fe'), 'primary', 1, 1);
                obj.BtnWeighCu = obj.createExpButton(btnGrid, '2.称量铜样品', @(~,~) obj.weighSample('Cu'), 'disabled', 1, 2);
                obj.BtnWeighAl = obj.createExpButton(btnGrid, '3.称量铝样品', @(~,~) obj.weighSample('Al'), 'disabled', 1, 3);
                obj.BtnSetupThermocouple = obj.createExpButton(btnGrid, '4.安装热电偶', @(~,~) obj.setupThermocouple(), 'disabled', 1, 4);
                obj.BtnHeatSample = obj.createExpButton(btnGrid, '5.加热样品', @(~,~) obj.heatSample(), 'disabled', 1, 5);
                obj.BtnStartCooling = obj.createExpButton(btnGrid, '6.开始冷却', @(~,~) obj.startCooling(), 'disabled', 1, 6);

                % 第二行：记录与计算
                obj.BtnRecordFe = obj.createExpButton(btnGrid, '记录铁(Δt)', @(~,~) obj.recordCoolingTime('Fe'), 'disabled', 2, 1);
                obj.BtnRecordCu = obj.createExpButton(btnGrid, '记录铜(Δt)', @(~,~) obj.recordCoolingTime('Cu'), 'disabled', 2, 2);
                obj.BtnRecordAl = obj.createExpButton(btnGrid, '记录铝(Δt)', @(~,~) obj.recordCoolingTime('Al'), 'disabled', 2, 3);

                % 更换样品按钮
                obj.BtnChangeSample = obj.createExpButton(btnGrid, '更换样品', @(~,~) obj.changeSample(), 'secondary', 2, 4);
                obj.BtnChangeSample.Enable = 'off';

                obj.BtnCalculate = obj.createExpButton(btnGrid, '7.计算比热容', @(~,~) obj.calculateResult(), 'disabled', 2, 5);

                % 第三行：完成和重置
                obj.BtnComplete = obj.createExpButton(btnGrid, '完成实验', @(~,~) obj.completeExperiment(), 'disabled', 3, 5);
                resetBtn = uibutton(btnGrid, 'Text', '重置实验', ...
                    'ButtonPushedFcn', @(~,~) obj.resetExperiment());
                resetBtn.Layout.Row = 3;
                resetBtn.Layout.Column = 6;
                ui.StyleConfig.applyButtonStyle(resetBtn, 'warning');

                % 提示标签（每种样品需测5次）
                lblNote = uilabel(btnGrid, 'Text', '（每种样品需测5次）', ...
                    'FontName', ui.StyleConfig.FontFamily, ...
                    'FontSize', ui.StyleConfig.FontSizeCaption, ...
                    'FontColor', ui.StyleConfig.TextSecondary, ...
                    'HorizontalAlignment', 'center');
                lblNote.Layout.Row = 3; lblNote.Layout.Column = [1, 5];


                % ==================== 右侧面板 ====================

                % ---------- 参数控制面板 (右上) ----------
                controlGrid = ui.StyleConfig.createControlPanelGrid(obj.ControlPanel, 7);

                % 标题行
                titleLabel = ui.StyleConfig.createPanelTitle(controlGrid, '实验参数');
                titleLabel.Layout.Row = 1;
                titleLabel.Layout.Column = [1, 2];

                paramLabels = {'铁(Fe)质量 M₁:', '铜(Cu)质量 M₂:', '铝(Al)质量 M₃:'};
                massLabelProps = {'CachedMassFeLabel', 'CachedMassCuLabel', 'CachedMassAlLabel'};

                for i = 1:length(paramLabels)
                    % 简化标签文本以防重叠
                    simpleLabel = paramLabels{i};
                    simpleLabel = strrep(simpleLabel, '质量 ', ''); % 去掉"质量 "两字缩短长度

                    l = ui.StyleConfig.createParamLabel(controlGrid, simpleLabel);
                    l.Layout.Row = i + 1;
                    l.Layout.Column = 1;

                    v = ui.StyleConfig.createParamValue(controlGrid, '待测量');
                    v.Layout.Row = i + 1;
                    v.Layout.Column = 2;
                    obj.(massLabelProps{i}) = v;
                end

                % 标准比热容显示
                stdLabels = {'标准比热容:', ...
                    sprintf('铜: %.3f', obj.C_Cu_standard), ...
                    sprintf('铁: %.3f', obj.C_Fe_standard), ...
                    sprintf('铝: %.3f', obj.C_Al_standard)};

                for i = 1:4
                    l = uilabel(controlGrid, 'Text', stdLabels{i}, ...
                         'FontName', ui.StyleConfig.FontFamily, ...
                         'FontSize', ui.StyleConfig.PanelLabelFontSize, ...
                         'FontColor', ui.StyleConfig.TextSecondary, ...
                         'BackgroundColor', ui.StyleConfig.PanelColor);
                    if i > 1, l.FontName = ui.StyleConfig.FontFamilyMono; end
                    l.Layout.Row = i + 3; l.Layout.Column = [1, 2];
                end

                % ---------- 实验数据面板 (右下) ----------
                dataPanelGrid = ui.StyleConfig.createDataPanelGrid(obj.DataPanel, '1x', 140);

                % 标题行
                dataTitleLabel = ui.StyleConfig.createPanelTitle(dataPanelGrid, '实验数据');
                dataTitleLabel.Layout.Row = 1;

                % 数据表格
                obj.DataTable = ui.StyleConfig.createDataTable(dataPanelGrid, ...
                    {'样品', '1', '2', '3', '4', '5', '平均'}, ...
                    {40, 45, 45, 45, 45, 45, 60});
                obj.DataTable.Layout.Row = 2;
                obj.DataTable.Data = {'Fe', '', '', '', '', '', ''; ...
                             'Cu', '', '', '', '', '', ''; ...
                             'Al', '', '', '', '', '', ''};
                obj.DataTable.RowName = {};

                % 结果区域
                resultGrid = ui.StyleConfig.createResultGrid(dataPanelGrid, 6);
                resultGrid.Layout.Row = 3;

                resLabels = {'铁的比热容 C₂ =', '铁误差 =', ...
                    '铝的比热容 C₃ =', '铝误差 =', '铁不确定度 U =', '铝不确定度 U ='};
                resultProps = {'CachedResultFe', 'CachedErrorFe', 'CachedResultAl', 'CachedErrorAl', 'CachedUncertaintyFe', 'CachedUncertaintyAl'};

                for i = 1:6
                    lbl = ui.StyleConfig.createResultLabel(resultGrid, resLabels{i});
                    lbl.Layout.Row = i;
                    lbl.Layout.Column = 1;

                    val = ui.StyleConfig.createResultValue(resultGrid, '---');
                    val.Layout.Row = i;
                    val.Layout.Column = 2;
                    obj.(resultProps{i}) = val;
                end

                % 初始化实验引导系统
                obj.setupExperimentGuide();

                % 初始化交互系统
                obj.setupInteraction();

                obj.updateStatus('准备开始实验，请按步骤操作');
                drawnow;

            catch ME
                utils.Logger.logError(ME, 'Exp3_3_MetalSpecificHeat.setupExperimentUI');
                uialert(obj.Figure, sprintf('UI初始化失败:\n%s\nFile: %s\nLine: %d', ...
                    ME.message, ME.stack(1).name, ME.stack(1).line), '程序错误');
            end
        end

        function setupInteraction(obj)
            % 初始化交互管理器
            if isempty(obj.SimulationAxes)
                return;
            end

            obj.InteractionMgr = ui.InteractionManager(obj.SimulationAxes);

            % 定义加热器交互区域 (覆盖加热器及其移动范围)
            % 区域: [x, y, w, h]
            obj.InteractionMgr.addZone('Heater', [0.15, 0.15, 0.30, 0.40], '加热装置', ...
                @(id) obj.onInstrumentClick(id));

            % 启动动画计时器（用于呼吸灯效果等）
            obj.AnimationTimer = timer('ExecutionMode', 'fixedRate', ...
                'Period', 0.2, ...  % 5fps（原0.1s，降频减少绘制压力）
                'TimerFcn', @(~,~) obj.safeTimerCallback(@obj.updateAnimation));
            start(obj.AnimationTimer);
        end

        function updateAnimation(obj)
            % 更新动画状态
            if isempty(obj.Figure) || ~isvalid(obj.Figure)
                if ~isempty(obj.AnimationTimer)
                    stop(obj.AnimationTimer);
                end
                return;
            end

            % 仅在需要动画时更新（避免空闲空转）
            if obj.WaitingForHeater || obj.WaitingForCooling || (obj.IsRecording && obj.ExpStage == obj.STAGE_HEATING)
                obj.HeatingPhase = mod(obj.HeatingPhase + 0.2, 2*pi);
                obj.drawApparatus();
            end
        end

        function onInstrumentClick(obj, name)
            % 处理仪器点击事件
            switch name
                case 'Heater'
                    if obj.WaitingForHeater
                        obj.performHeatingAction();
                    elseif obj.WaitingForCooling
                        obj.performCoolingAction();
                    end
            end
        end

        function performHeatingAction(obj)
            % 执行加热动作
            obj.WaitingForHeater = false;
            obj.ExpStage = obj.STAGE_HEATING;
            obj.IsCooling = false;

            % 启动加热模拟计时器
            obj.IsRecording = true;
            obj.ElapsedTime = 0;

            obj.RecordTimer = timer('ExecutionMode', 'fixedRate', ...
                'Period', 0.2, ...  % 200ms（原0.1s，降频减少绘制压力）
                'TimerFcn', @(~,~) obj.safeTimerCallback(@obj.updateHeating));
            start(obj.RecordTimer);

            obj.drawApparatus();
            obj.updateStatus('加热器已放置。正在加热样品，请等待电压显示达到 4.927 mV...');

            obj.BtnHeatSample.Enable = 'off';
        end

        function performCoolingAction(obj)
            % 执行冷却动作
            obj.WaitingForCooling = false;

            obj.ExpStage = obj.STAGE_COOLING;
            obj.IsCooling = true;
            obj.CoolingStartTime = 0;
            obj.CoolingEndTime = 0;

            % 更新状态显示（使用缓存句柄）
            if ~isempty(obj.CachedCoolingStatus) && isvalid(obj.CachedCoolingStatus)
                obj.CachedCoolingStatus.Text = '冷却中';
                obj.CachedCoolingStatus.FontColor = [0, 0.6, 0];
            end

            % 启动冷却模拟计时器
            obj.IsRecording = true;
            obj.ElapsedTime = 0;
            obj.TimerDisplay.Text = '00.00 s';

            obj.RecordTimer = timer('ExecutionMode', 'fixedRate', ...
                'Period', 0.2, ...  % 200ms更新一次（原50ms过快导致卡顿）
                'TimerFcn', @(~,~) obj.safeTimerCallback(@obj.updateCooling));
            start(obj.RecordTimer);

            obj.drawApparatus();
            obj.updateStatus('加热器已移走，加盖冷却中。当电压降至 4.157 mV (102°C) 时自动开始计时...');

            obj.BtnStartCooling.Enable = 'off';

            % 此时不启用记录按钮，必须等待冷却完成
            obj.BtnRecordFe.Enable = 'off';
            obj.BtnRecordCu.Enable = 'off';
            obj.BtnRecordAl.Enable = 'off';
        end

        function drawApparatus(obj)
            % 绘制金属比热容测量仪结构示意图（参考图3-3-1）
            ax = obj.SimulationAxes;
            cla(ax);
            hold(ax, 'on');

            % 设置背景
            set(ax, 'Color', [0.98, 0.98, 0.98]);

            % === 升降台（底座）===
            rectangle(ax, 'Position', [0.08, 0.05, 0.42, 0.06], ...
                'FaceColor', [0.5, 0.5, 0.5], ...
                'EdgeColor', [0.3, 0.3, 0.3], ...
                'LineWidth', 2);
            % 升降台纹理
            for i = 1:6
                x = 0.10 + i * 0.06;
                plot(ax, [x, x], [0.05, 0.11], 'Color', [0.4, 0.4, 0.4], 'LineWidth', 1);
            end

            % === 防风容器（E）- 双层结构 ===
            % 外层容器壁（左）
            rectangle(ax, 'Position', [0.10, 0.11, 0.04, 0.58], ...
                'FaceColor', [0.75, 0.75, 0.75], ...
                'EdgeColor', [0.4, 0.4, 0.4], ...
                'LineWidth', 1.5);
            % 外层容器壁（右）
            rectangle(ax, 'Position', [0.44, 0.11, 0.04, 0.58], ...
                'FaceColor', [0.75, 0.75, 0.75], ...
                'EdgeColor', [0.4, 0.4, 0.4], ...
                'LineWidth', 1.5);
            % 外层容器底
            rectangle(ax, 'Position', [0.10, 0.11, 0.38, 0.04], ...
                'FaceColor', [0.75, 0.75, 0.75], ...
                'EdgeColor', [0.4, 0.4, 0.4], ...
                'LineWidth', 1.5);

            % 内部空腔（空气隔热层）
            rectangle(ax, 'Position', [0.14, 0.15, 0.30, 0.50], ...
                'FaceColor', [0.95, 0.95, 0.92], ...
                'EdgeColor', 'none');

            % === 盖子 ===
            rectangle(ax, 'Position', [0.08, 0.69, 0.42, 0.05], ...
                'FaceColor', [0.6, 0.6, 0.6], ...
                'EdgeColor', [0.3, 0.3, 0.3], ...
                'LineWidth', 2);
            % 盖子上的孔（热电偶穿过）
            rectangle(ax, 'Position', [0.27, 0.69, 0.04, 0.05], ...
                'FaceColor', [0.4, 0.4, 0.4], ...
                'EdgeColor', [0.3, 0.3, 0.3], ...
                'LineWidth', 1);

            % === 热电偶支架（D）===
            % 垂直支撑杆
            rectangle(ax, 'Position', [0.28, 0.74, 0.02, 0.18], ...
                'FaceColor', [0.3, 0.3, 0.3], ...
                'EdgeColor', [0.2, 0.2, 0.2], ...
                'LineWidth', 1);
            % 横杆（T形顶部）
            rectangle(ax, 'Position', [0.22, 0.90, 0.14, 0.03], ...
                'FaceColor', [0.3, 0.3, 0.3], ...
                'EdgeColor', [0.2, 0.2, 0.2], ...
                'LineWidth', 1);

            % === 热电偶（C）===
            % 热电偶主杆 - 细长的探针
            rectangle(ax, 'Position', [0.285, 0.20, 0.015, 0.72], ...
                'FaceColor', [0.55, 0.45, 0.35], ...
                'EdgeColor', [0.4, 0.3, 0.2], ...
                'LineWidth', 1);
            % 热电偶测温端（底部）
            plot(ax, 0.2925, 0.20, 'o', 'MarkerSize', 6, ...
                'MarkerFaceColor', [0.7, 0.5, 0.3], ...
                'MarkerEdgeColor', [0.4, 0.3, 0.2], 'LineWidth', 1.5);

            % === 样品（B）- 圆柱形金属样品 ===
            if obj.ExpStage >= obj.STAGE_THERMOCOUPLE && ~isempty(obj.CurrentSample)
                sampleColor = obj.getSampleColor(obj.CurrentSample);
                % 样品主体（圆柱形）
                rectangle(ax, 'Position', [0.24, 0.28, 0.11, 0.20], ...
                    'FaceColor', sampleColor, ...
                    'EdgeColor', [0.2, 0.2, 0.2], ...
                    'LineWidth', 2, ...
                    'Curvature', [0.3, 0.15]);
                % 样品高光效果
                rectangle(ax, 'Position', [0.25, 0.30, 0.03, 0.16], ...
                    'FaceColor', [1, 1, 1], ...
                    'EdgeColor', 'none', ...
                    'FaceAlpha', 0.2);
                % 样品标签
                text(ax, 0.295, 0.38, obj.CurrentSample, 'FontSize', 12, ...
                    'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
                    'Color', [1, 1, 1]);
            end

            % === 热源（A）- 可移动电炉 ===
            % 当处于加热阶段，或正在等待放置/移走加热器时显示
            if (obj.ExpStage >= obj.STAGE_HEATING && obj.ExpStage < obj.STAGE_COOLING) || obj.WaitingForHeater
                % 电炉外壳
                heaterPos = [0.18, 0.18, 0.22, 0.35];

                % 如果是等待放置状态，可以画得稍微偏一点或者透明一点，这里简化为原位显示但加高亮提示

                rectangle(ax, 'Position', heaterPos, ...
                    'FaceColor', [0.85, 0.55, 0.45], ...
                    'EdgeColor', [0.6, 0.3, 0.2], ...
                    'LineWidth', 2);
                % 电炉内部（发热区）
                rectangle(ax, 'Position', [0.20, 0.20, 0.18, 0.31], ...
                    'FaceColor', [0.95, 0.7, 0.6], ...
                    'EdgeColor', 'none');
                % 发热丝（螺旋状）
                for i = 1:8
                    y = 0.22 + i * 0.035;
                    % 绘制波浪形发热丝
                    xWire = linspace(0.21, 0.37, 20);
                    % 添加动态脉动效果
                    phaseOffset = i * 0.5; % 相位差
                    pulseAmp = 0;
                    if obj.IsRecording && obj.ExpStage == obj.STAGE_HEATING
                        % 加热中：动态波浪
                         pulseAmp = 0.002 * sin(obj.HeatingPhase + phaseOffset);
                    end

                    yWire = y + 0.008 * sin(linspace(0, 4*pi, 20)) + pulseAmp;

                    if obj.IsRecording && obj.ExpStage == obj.STAGE_HEATING
                        % 加热中：颜色在橙红和亮红之间脉动
                        redIntensity = 0.8 + 0.2 * sin(obj.HeatingPhase * 2);
                        wireColor = [1, redIntensity * 0.4, 0.1];
                    else
                        wireColor = [0.7, 0.4, 0.3];
                    end
                    plot(ax, xWire, yWire, 'Color', wireColor, 'LineWidth', 2);
                end
            end

            % === 数字电压表（G）===
            % 电压表外壳
            rectangle(ax, 'Position', [0.58, 0.42, 0.35, 0.22], ...
                'FaceColor', [0.15, 0.15, 0.15], ...
                'EdgeColor', [0.1, 0.1, 0.1], ...
                'LineWidth', 2, ...
                'Curvature', [0.05, 0.05]);
            % 显示屏边框
            rectangle(ax, 'Position', [0.61, 0.50, 0.29, 0.11], ...
                'FaceColor', [0.08, 0.12, 0.08], ...
                'EdgeColor', [0.3, 0.35, 0.3], ...
                'LineWidth', 2);
            % 显示数值
            voltageStr = sprintf('%.3f', obj.CurrentVoltage);
            obj.CachedVoltmeterText = text(ax, 0.755, 0.555, voltageStr, ...
                'FontSize', 16, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center', ...
                'Color', [0.2, 1, 0.2], ...
                'FontName', 'Consolas', ...
                'Tag', 'VoltmeterTextInDiagram');
            % mV单位
            text(ax, 0.88, 0.555, 'mV', 'FontSize', 10, ...
                'FontWeight', 'bold', 'Color', [0.2, 1, 0.2]);
            % 电压表标签
            text(ax, 0.755, 0.45, '数字电压表', 'FontSize', 9, ...
                'HorizontalAlignment', 'center', 'Color', [0.7, 0.7, 0.7]);
            % 输入端子
            rectangle(ax, 'Position', [0.88, 0.44, 0.04, 0.04], ...
                'FaceColor', [0.3, 0.3, 0.3], 'EdgeColor', [0.5, 0.5, 0.5]);
            text(ax, 0.95, 0.46, '+', 'FontSize', 10, 'Color', [0.8, 0.2, 0.2]);
            rectangle(ax, 'Position', [0.88, 0.50, 0.04, 0.04], ...
                'FaceColor', [0.3, 0.3, 0.3], 'EdgeColor', [0.5, 0.5, 0.5]);
            text(ax, 0.95, 0.52, '-', 'FontSize', 10, 'Color', [0.2, 0.2, 0.8]);

            % === 冰水混合物容器（F）===
            % 容器
            rectangle(ax, 'Position', [0.60, 0.08, 0.25, 0.25], ...
                'FaceColor', [0.85, 0.92, 1], ...
                'EdgeColor', [0.4, 0.6, 0.8], ...
                'LineWidth', 2);
            % 水面
            rectangle(ax, 'Position', [0.61, 0.09, 0.23, 0.18], ...
                'FaceColor', [0.7, 0.85, 1], ...
                'EdgeColor', 'none');
            % 冰块（多个不规则形状）
            icePositions = [0.63, 0.15, 0.06, 0.05;
                            0.71, 0.12, 0.05, 0.06;
                            0.78, 0.14, 0.04, 0.05;
                            0.65, 0.21, 0.05, 0.04];
            for i = 1:size(icePositions, 1)
                rectangle(ax, 'Position', icePositions(i,:), ...
                    'FaceColor', [0.92, 0.96, 1], ...
                    'EdgeColor', [0.7, 0.85, 0.95], ...
                    'LineWidth', 1, ...
                    'Curvature', [0.3, 0.3]);
            end
            % 冷端探头（浸入冰水）
            plot(ax, [0.72, 0.72], [0.27, 0.33], 'Color', [0.2, 0.2, 0.8], 'LineWidth', 3);
            plot(ax, 0.72, 0.27, 'o', 'MarkerSize', 5, ...
                'MarkerFaceColor', [0.3, 0.3, 0.6], 'MarkerEdgeColor', [0.2, 0.2, 0.5]);

            % === 连接导线 ===
            % 优化走线，避免与文字遮挡，美观规整

            % 热端引线（红色）- 走上方路线
            % 路径：热电偶出口(0.30,0.74) -> 上移至支架下方(0.89) -> 右移至最右侧(0.96) -> 下移至正极高度(0.46) -> 左移接入
            plot(ax, [0.30, 0.30, 0.96, 0.96, 0.92], ...
                 [0.74, 0.89, 0.89, 0.46, 0.46], ...
                'Color', [0.85, 0.2, 0.2], 'LineWidth', 2);

            % 冷端引线（蓝色）- 走下方路线
            % 路径：冰水探头(0.72,0.33) -> 上移出水面(0.38) -> 右移至最右侧(0.96) -> 上移至负极高度(0.52) -> 左移接入
            plot(ax, [0.72, 0.72, 0.96, 0.96, 0.92], ...
                 [0.33, 0.38, 0.38, 0.52, 0.52], ...
                'Color', [0.2, 0.2, 0.85], 'LineWidth', 2);

            % === 标注（参考教材图3-3-1）===
            % 调整标注位置，避免被仪器和导线遮挡
            text(ax, 0.45, 0.96, 'D-热电偶支架', 'FontSize', 9, 'Color', ui.StyleConfig.TextPrimary, 'HorizontalAlignment', 'right');
            text(ax, 0.45, 0.82, 'C-热电偶', 'FontSize', 9, 'Color', ui.StyleConfig.TextPrimary, 'HorizontalAlignment', 'right');

            % 将E-防风容器标注移至左侧，完全避开电压表区域
            text(ax, 0.06, 0.60, 'E-防风容器', 'FontSize', 9, 'Color', ui.StyleConfig.TextPrimary);

            % A和B移至左下侧
            text(ax, 0.46, 0.38, 'B-样品', 'FontSize', 9, 'Color', ui.StyleConfig.TextPrimary, 'HorizontalAlignment', 'right');
            text(ax, 0.46, 0.22, 'A-热源', 'FontSize', 9, 'Color', ui.StyleConfig.TextPrimary, 'HorizontalAlignment', 'right');

            text(ax, 0.755, 0.68, 'G-数字电压表', 'FontSize', 9, ...
                'HorizontalAlignment', 'center', 'Color', ui.StyleConfig.TextPrimary);
            text(ax, 0.725, 0.04, 'F-冰水混合物', 'FontSize', 9, ...
                'HorizontalAlignment', 'center', 'Color', ui.StyleConfig.TextPrimary);

            % === 交互提示 ===
            if obj.WaitingForHeater || obj.WaitingForCooling
                % 计算呼吸灯透明度
                alpha = 0.3 + 0.2 * sin(obj.HeatingPhase * 3);

                % 绘制高亮区域 (围绕加热器)
                highlightPos = [0.16, 0.16, 0.26, 0.39];
                rectangle(ax, 'Position', highlightPos, ...
                    'FaceColor', [1, 1, 0], ...
                    'EdgeColor', [1, 0.8, 0], ...
                    'LineWidth', 2, ...
                    'FaceAlpha', alpha, ...
                    'LineStyle', '--', ...
                    'PickableParts', 'none');

                % 提示文字
                if obj.WaitingForHeater
                    msg = '点击此处放入加热器';
                else
                    msg = '点击此处移走加热器';
                end
                text(ax, 0.29, 0.45, msg, ...
                    'FontSize', 12, 'FontWeight', 'bold', ...
                    'Color', [0.8, 0.2, 0], ...
                    'HorizontalAlignment', 'center', ...
                    'BackgroundColor', [1, 1, 1, 0.8], ...
                    'Margin', 3, ...
                    'PickableParts', 'none');
            end

            % 关键修复：设置所有绘图对象不拦截点击事件，使点击能穿透到Axes被InteractionManager捕获
            set(ax.Children, 'PickableParts', 'none');

            hold(ax, 'off');
            xlim(ax, [0.05, 1]);
            ylim(ax, [0, 1]);
            ax.XTick = [];
            ax.YTick = [];
        end

        function color = getSampleColor(~, sample)
            % 根据样品类型返回颜色
            switch sample
                case 'Fe'
                    color = [0.5, 0.5, 0.55];  % 铁 - 银灰色
                case 'Cu'
                    color = [0.8, 0.5, 0.2];   % 铜 - 紫铜色
                case 'Al'
                    color = [0.85, 0.85, 0.88]; % 铝 - 银白色
                otherwise
                    color = [0.7, 0.7, 0.7];
            end
        end

        function weighSample(obj, sample)
            % 称量样品
            stepId = sprintf('weigh_%s', sample);
            [canProceed, ~] = obj.checkOperationValid(stepId);
            if ~canProceed, return; end

            switch sample
                case 'Fe'
                    obj.MassFe = 65 + rand()*5;  % 65-70g（铁密度最大）
                    obj.BalanceDisplay.Text = sprintf('%.3f g', obj.MassFe);

                    obj.safeSetText(obj.CachedMassFeLabel, sprintf('%.3f g', obj.MassFe));

                    obj.updateStatus(sprintf('铁样品质量: %.3f g', obj.MassFe));

                    obj.BtnWeighFe.Enable = 'off';
                    obj.BtnWeighCu.Enable = 'on';
                    ui.StyleConfig.applyButtonStyle(obj.BtnWeighCu, 'primary');

                    if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep('weigh_Fe'); end
                    obj.showNextStepHint();

                case 'Cu'
                    obj.MassCu = 75 + rand()*5;  % 75-80g（铜密度最大）
                    obj.BalanceDisplay.Text = sprintf('%.3f g', obj.MassCu);

                    obj.safeSetText(obj.CachedMassCuLabel, sprintf('%.3f g', obj.MassCu));

                    obj.updateStatus(sprintf('铜样品质量: %.3f g (M_Cu > M_Fe)', obj.MassCu));

                    obj.BtnWeighCu.Enable = 'off';
                    obj.BtnWeighAl.Enable = 'on';
                    ui.StyleConfig.applyButtonStyle(obj.BtnWeighAl, 'primary');

                    if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep('weigh_Cu'); end
                    obj.showNextStepHint();

                case 'Al'
                    obj.MassAl = 22 + rand()*3;  % 22-25g（铝密度最小）
                    obj.BalanceDisplay.Text = sprintf('%.3f g', obj.MassAl);

                    obj.safeSetText(obj.CachedMassAlLabel, sprintf('%.3f g', obj.MassAl));

                    obj.updateStatus(sprintf('铝样品质量: %.3f g (M_Cu > M_Fe > M_Al，验证样品)', obj.MassAl));
                    obj.ExpStage = obj.STAGE_WEIGHED;

                    obj.BtnWeighAl.Enable = 'off';
                    obj.BtnSetupThermocouple.Enable = 'on';
                    ui.StyleConfig.applyButtonStyle(obj.BtnSetupThermocouple, 'primary');

                    if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep('weigh_Al'); end
                    obj.showNextStepHint();
            end
        end

        function setupThermocouple(obj)
            % 安装热电偶
            [canProceed, ~] = obj.checkOperationValid('setup_thermocouple');
            if ~canProceed, return; end

            obj.ExpStage = obj.STAGE_THERMOCOUPLE;
            obj.CurrentSample = 'Fe';  % 先测铁
            obj.SampleDisplay.Text = '铁(Fe)';

            obj.CurrentVoltage = 0;

            % 更新图中电压表显示
            if ~isempty(obj.CachedVoltmeterText) && isvalid(obj.CachedVoltmeterText)
                obj.CachedVoltmeterText.String = '0.000';
            end

            obj.drawApparatus();
            obj.updateStatus('热电偶已安装，铁样品已套在热电偶上，冷端放入冰水混合物中');

            obj.BtnSetupThermocouple.Enable = 'off';
            obj.BtnHeatSample.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnHeatSample, 'primary');

            obj.updateStatus('热电偶已安装。请点击"5.加热样品"按钮进行下一步');
            obj.drawApparatus();

            if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep('setup_thermocouple'); end
            obj.showNextStepHint();
        end

        function heatSample(obj)
            % 加热样品按钮回调
            index = obj.getCurrentMeasurementIndex();
            stepId = sprintf('heat_%s_%d', obj.CurrentSample, index);
            [canProceed, ~] = obj.checkOperationValid(stepId);
            if ~canProceed, return; end

            obj.WaitingForHeater = true;
            obj.updateStatus('请点击图中的加热器（红色炉体），将其放入防风容器中开始加热');
            obj.drawApparatus();

            % 交互开始后禁用按钮
            obj.BtnHeatSample.Enable = 'off';
        end

        function updateHeating(obj)
            % 更新加热过程
            if ~obj.IsRecording
                return;
            end

            if isempty(obj.Figure) || ~isvalid(obj.Figure)
                obj.stopRecording();
                return;
            end

            % 模拟加热：电压逐渐上升（速率×2补偿定时器降频）
            obj.CurrentVoltage = obj.CurrentVoltage + obj.HeatingRate * 2 + randn()*0.005;
            obj.CurrentVoltage = min(obj.CurrentVoltage, obj.VoltageTarget + 0.01);

            % 更新显示
            % obj.VoltmeterDisplay.Text = sprintf('%.3f mV', obj.CurrentVoltage); % 已移除

            % 更新图中数字电压表读数（使用缓存句柄）
            if ~isempty(obj.CachedVoltmeterText) && isvalid(obj.CachedVoltmeterText)
                obj.CachedVoltmeterText.String = sprintf('%.3f', obj.CurrentVoltage);
            end

            % 计算对应温度
            tempValue = obj.voltageToTemp(obj.CurrentVoltage);
            if ~isempty(obj.CachedTempDisplay) && isvalid(obj.CachedTempDisplay)
                obj.CachedTempDisplay.Text = sprintf('%.1f', tempValue);
            end

            % 达到目标电压
            if obj.CurrentVoltage >= obj.VoltageTarget
                obj.stopRecording();
                obj.updateStatus('加热完成！电压达到 4.927 mV，请点击"开始冷却"');

                % 完成加热步骤
                index = obj.getCurrentMeasurementIndex();
                heatStepId = sprintf('heat_%s_%d', obj.CurrentSample, index);
                if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep(heatStepId); end
                obj.showNextStepHint();

                obj.BtnStartCooling.Enable = 'on';
                ui.StyleConfig.applyButtonStyle(obj.BtnStartCooling, 'primary');
            end
        end

        function startCooling(obj)
            % 开始冷却交互
            index = obj.getCurrentMeasurementIndex();
            coolStepId = sprintf('cool_%s_%d', obj.CurrentSample, index);
            [canProceed, ~] = obj.checkOperationValid(coolStepId);
            if ~canProceed, return; end

            obj.WaitingForCooling = true;
            obj.updateStatus('请点击图中的加热器（红色炉体），将其移出并开始冷却');
            obj.drawApparatus();

            % 禁用按钮
            obj.BtnStartCooling.Enable = 'off';
        end

        function updateCooling(obj)
            % 更新冷却过程
            if ~obj.IsRecording
                return;
            end

            if isempty(obj.Figure) || ~isvalid(obj.Figure)
                obj.stopRecording();
                return;
            end

            % 根据不同样品的比热容计算冷却速率
            % 比热容越大，冷却越慢
            % 电压范围: 4.157 mV (102°C) -> 3.988 mV (98°C)，差值 = 0.169 mV
            % 目标散热时间：铁约30s，铜约35s（标准），铝约50s
            switch obj.CurrentSample
                case 'Fe'
                    coolingRate = obj.CoolRateFe;  % 铁: ~30秒
                case 'Cu'
                    coolingRate = obj.CoolRateCu;  % 铜: ~35秒（标准样品）
                case 'Al'
                    coolingRate = obj.CoolRateAl;  % 铝: ~50秒（比热容最大，冷却最慢）
                otherwise
                    coolingRate = obj.CoolRateCu;
            end

            % 模拟冷却：电压逐渐下降（添加微小噪声，但不影响整体趋势）
            % 为了加快实验速度，时间流速设为5倍
            timeScale = 5;

            noise = randn() * 0.000005;  % 很小的噪声
            obj.CurrentVoltage = obj.CurrentVoltage - (coolingRate * timeScale * 4) + noise;
            obj.CurrentVoltage = max(obj.CurrentVoltage, 0);

            % 更新显示
            % obj.VoltmeterDisplay.Text = sprintf('%.3f mV', obj.CurrentVoltage); % 已移除

            % 更新图中数字电压表读数（使用缓存句柄）
            if ~isempty(obj.CachedVoltmeterText) && isvalid(obj.CachedVoltmeterText)
                obj.CachedVoltmeterText.String = sprintf('%.3f', obj.CurrentVoltage);
            end

            % 计算对应温度
            tempValue = obj.voltageToTemp(obj.CurrentVoltage);
            if ~isempty(obj.CachedTempDisplay) && isvalid(obj.CachedTempDisplay)
                obj.CachedTempDisplay.Text = sprintf('%.1f', tempValue);
            end

            % 检测是否到达102°C（4.157 mV）开始计时
            if obj.CoolingStartTime == 0 && obj.CurrentVoltage <= obj.VoltageAt102C
                obj.CoolingStartTime = obj.ElapsedTime;
                obj.updateStatus('温度达到102°C，开始计时！等待降至98°C...');
            end

            % 先更新时间 (加速流逝)
            obj.ElapsedTime = obj.ElapsedTime + 0.2 * timeScale;

            % 如果已开始计时，更新秒表
            if obj.CoolingStartTime > 0 && obj.CoolingEndTime == 0
                elapsedCooling = obj.ElapsedTime - obj.CoolingStartTime;
                obj.TimerDisplay.Text = sprintf('%.2f s', elapsedCooling);
            end

            % 检测是否到达98°C（3.988 mV）停止计时
            if obj.CoolingStartTime > 0 && obj.CoolingEndTime == 0 && obj.CurrentVoltage <= obj.VoltageAt98C
                obj.CoolingEndTime = obj.ElapsedTime;
                obj.stopRecording();

                coolingTime = obj.CoolingEndTime - obj.CoolingStartTime;
                obj.updateStatus(sprintf('温度降至98°C，散热时间: %.2f s，请点击记录按钮保存数据', coolingTime));

                % 更新状态显示（使用缓存句柄）
                if ~isempty(obj.CachedCoolingStatus) && isvalid(obj.CachedCoolingStatus)
                    obj.CachedCoolingStatus.Text = '已完成';
                    obj.CachedCoolingStatus.FontColor = [0.8, 0.4, 0];
                end

                % 完成冷却步骤
                index = obj.getCurrentMeasurementIndex();
                coolStepId = sprintf('cool_%s_%d', obj.CurrentSample, index);
                if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep(coolStepId); end
                obj.showNextStepHint();

                % 冷却完成，启用对应的记录按钮
                switch obj.CurrentSample
                    case 'Fe'
                        obj.BtnRecordFe.Enable = 'on';
                        ui.StyleConfig.applyButtonStyle(obj.BtnRecordFe, 'primary');
                    case 'Cu'
                        obj.BtnRecordCu.Enable = 'on';
                        ui.StyleConfig.applyButtonStyle(obj.BtnRecordCu, 'primary');
                    case 'Al'
                        obj.BtnRecordAl.Enable = 'on';
                        ui.StyleConfig.applyButtonStyle(obj.BtnRecordAl, 'primary');
                end
            end
        end

        function recordCoolingTime(obj, sample)
            % 记录散热时间
            % 检查是否通过正常冷却流程获得数据
            if obj.CoolingEndTime <= 0 || obj.CoolingStartTime <= 0
                uialert(obj.Figure, '请先进行完整的加热和冷却过程！', '操作错误');
                return;
            end

            index = obj.getCurrentMeasurementIndex(sample);
            recordStepId = sprintf('record_%s_%d', sample, index);
            [canProceed, ~] = obj.checkOperationValid(recordStepId);
            if ~canProceed, return; end

            coolingTime = obj.CoolingEndTime - obj.CoolingStartTime;

            % 添加一些随机误差模拟实际测量（保证正值）
            coolingTime = coolingTime + abs(randn()*0.3);

            switch sample
                case 'Fe'
                    obj.CoolingTimesFe(end+1) = coolingTime;
                    count = length(obj.CoolingTimesFe);
                    obj.DataTable.Data{1, count+1} = sprintf('%.2f', coolingTime);
                    obj.enableExportButton();

                    if count >= 5
                        obj.AvgTimeFe = mean(obj.CoolingTimesFe);
                        obj.DataTable.Data{1, 7} = sprintf('%.2f', obj.AvgTimeFe);
                        obj.BtnRecordFe.Enable = 'off';

                        % 测量完成，启用更换样品按钮
                        obj.updateStatus(sprintf('铁的5次测量完成，平均Δt=%.2fs。请点击"更换样品"进行下一项', obj.AvgTimeFe));
                        obj.BtnChangeSample.Enable = 'on';
                        ui.StyleConfig.applyButtonStyle(obj.BtnChangeSample, 'primary');
                    else
                        obj.updateStatus(sprintf('铁第%d次记录: %.2fs，请继续测量（共需5次）', count, coolingTime));
                        % 记录一次后禁用按钮，强制重新加热
                        obj.BtnRecordFe.Enable = 'off';
                        obj.BtnHeatSample.Enable = 'on';
                        ui.StyleConfig.applyButtonStyle(obj.BtnHeatSample, 'primary');
                    end

                case 'Cu'
                    obj.CoolingTimesCu(end+1) = coolingTime;
                    count = length(obj.CoolingTimesCu);
                    obj.DataTable.Data{2, count+1} = sprintf('%.2f', coolingTime);

                    if count >= 5
                        obj.AvgTimeCu = mean(obj.CoolingTimesCu);
                        obj.DataTable.Data{2, 7} = sprintf('%.2f', obj.AvgTimeCu);
                        obj.BtnRecordCu.Enable = 'off';

                        % 测量完成，启用更换样品按钮
                        obj.updateStatus(sprintf('铜的5次测量完成，平均Δt=%.2fs。请点击"更换样品"进行下一项', obj.AvgTimeCu));
                        obj.BtnChangeSample.Enable = 'on';
                        ui.StyleConfig.applyButtonStyle(obj.BtnChangeSample, 'primary');
                    else
                        obj.updateStatus(sprintf('铜第%d次记录: %.2fs，请继续测量（共需5次）', count, coolingTime));
                        % 记录一次后禁用按钮，强制重新加热
                        obj.BtnRecordCu.Enable = 'off';
                        obj.BtnHeatSample.Enable = 'on';
                        ui.StyleConfig.applyButtonStyle(obj.BtnHeatSample, 'primary');
                    end

                case 'Al'
                    obj.CoolingTimesAl(end+1) = coolingTime;
                    count = length(obj.CoolingTimesAl);
                    obj.DataTable.Data{3, count+1} = sprintf('%.2f', coolingTime);

                    if count >= 5
                        obj.AvgTimeAl = mean(obj.CoolingTimesAl);
                        obj.DataTable.Data{3, 7} = sprintf('%.2f', obj.AvgTimeAl);
                        obj.BtnRecordAl.Enable = 'off';
                        obj.ExpStage = obj.STAGE_DATA_DONE;
                        obj.updateStatus(sprintf('铝的5次测量完成，平均Δt=%.2fs。所有数据收集完成，可以计算比热容', obj.AvgTimeAl));
                        obj.BtnCalculate.Enable = 'on';
                        ui.StyleConfig.applyButtonStyle(obj.BtnCalculate, 'primary');
                    else
                        obj.updateStatus(sprintf('铝第%d次记录: %.2fs，请继续测量（共需5次）', count, coolingTime));
                        % 记录一次后禁用按钮，强制重新加热
                        obj.BtnRecordAl.Enable = 'off';
                        obj.BtnHeatSample.Enable = 'on';
                        ui.StyleConfig.applyButtonStyle(obj.BtnHeatSample, 'primary');
                    end
            end

            % 完成记录步骤
            if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep(recordStepId); end
            obj.showNextStepHint();

            % 更新散热时间图表
            obj.updateCoolingChart();

            % 重置冷却状态
            obj.IsCooling = false;
            obj.CoolingStartTime = 0;
            obj.CoolingEndTime = 0;
            obj.CurrentVoltage = 0;
            obj.TimerDisplay.Text = '00.00 s';

            % 安全更新图中电压表
            if ~isempty(obj.CachedVoltmeterText) && isvalid(obj.CachedVoltmeterText)
                obj.CachedVoltmeterText.String = '0.000';
            end

            if ~isempty(obj.CachedCoolingStatus) && isvalid(obj.CachedCoolingStatus)
                obj.CachedCoolingStatus.Text = '待开始';
                obj.CachedCoolingStatus.FontColor = [0.5, 0.5, 0.5];
            end

            obj.drawApparatus();
        end

        function updateCoolingChart(obj)
            % 更新散热时间图表
            if isempty(obj.TempTimeAxes) || ~isvalid(obj.TempTimeAxes)
                return;
            end

            cla(obj.TempTimeAxes);
            hold(obj.TempTimeAxes, 'on');

            x = 1:5;

            % 绘制铁的数据
            if ~isempty(obj.CoolingTimesFe)
                nFe = length(obj.CoolingTimesFe);
                bar(obj.TempTimeAxes, x(1:nFe) - 0.25, obj.CoolingTimesFe, 0.2, ...
                    'FaceColor', [0.5, 0.5, 0.55], 'EdgeColor', [0.3, 0.3, 0.3]);
            end

            % 绘制铜的数据
            if ~isempty(obj.CoolingTimesCu)
                nCu = length(obj.CoolingTimesCu);
                bar(obj.TempTimeAxes, x(1:nCu), obj.CoolingTimesCu, 0.2, ...
                    'FaceColor', [0.8, 0.5, 0.2], 'EdgeColor', [0.5, 0.3, 0.1]);
            end

            % 绘制铝的数据
            if ~isempty(obj.CoolingTimesAl)
                nAl = length(obj.CoolingTimesAl);
                bar(obj.TempTimeAxes, x(1:nAl) + 0.25, obj.CoolingTimesAl, 0.2, ...
                    'FaceColor', [0.85, 0.85, 0.88], 'EdgeColor', [0.5, 0.5, 0.5]);
            end

            % 动态图例（仅为已有数据的组添加图例）
            legendEntries = {};
            if ~isempty(obj.CoolingTimesFe), legendEntries{end+1} = 'Fe (铁)'; end
            if ~isempty(obj.CoolingTimesCu), legendEntries{end+1} = 'Cu (铜)'; end
            if ~isempty(obj.CoolingTimesAl), legendEntries{end+1} = 'Al (铝)'; end
            if ~isempty(legendEntries)
                legend(obj.TempTimeAxes, legendEntries, ...
                    'Location', 'northeast', 'FontSize', 9);
            end

            hold(obj.TempTimeAxes, 'off');
            xlim(obj.TempTimeAxes, [0.5, 5.5]);

            % 动态调整Y轴范围
            allTimes = [obj.CoolingTimesFe, obj.CoolingTimesCu, obj.CoolingTimesAl];
            if ~isempty(allTimes)
                ylim(obj.TempTimeAxes, [0, max(allTimes)*1.2]);
            else
                ylim(obj.TempTimeAxes, [0, 100]);
            end

            xlabel(obj.TempTimeAxes, '测量次数');
            ylabel(obj.TempTimeAxes, '散热时间 Δt (s)');
            title(obj.TempTimeAxes, '散热时间记录', 'FontName', ui.StyleConfig.FontFamily);
        end

        function temp = voltageToTemp(~, voltage)
            % 将电压转换为温度（简化的线性近似）
            % 在100°C附近，电压-温度关系近似线性
            % 4.072 mV ≈ 100°C
            temp = 100 + (voltage - 4.072) / 0.04;  % 约0.04 mV/°C
        end

        function calculateResult(obj)
            % 计算比热容
            [canProceed, ~] = obj.checkOperationValid('calculate');
            if ~canProceed, return; end

            % 使用公式 C₂ = C₁ * M₁ * (Δt)₂ / [M₂ * (Δt)₁]
            % 其中 C₁ 为铜的比热容（标准值），M₁ 为铜的质量

            % 铁的比热容
            % C_Fe = C_Cu * M_Cu * Δt_Fe / (M_Fe * Δt_Cu)
            obj.C_Fe = obj.C_Cu_standard * obj.MassCu * obj.AvgTimeFe / (obj.MassFe * obj.AvgTimeCu);

            % 铝的比热容
            % C_Al = C_Cu * M_Cu * Δt_Al / (M_Al * Δt_Cu)
            obj.C_Al = obj.C_Cu_standard * obj.MassCu * obj.AvgTimeAl / (obj.MassAl * obj.AvgTimeCu);

            % 计算相对误差
            errorFe = abs(obj.C_Fe - obj.C_Fe_standard) / obj.C_Fe_standard * 100;
            errorAl = abs(obj.C_Al - obj.C_Al_standard) / obj.C_Al_standard * 100;

            % 更新显示
            obj.safeSetText(obj.CachedResultFe, sprintf('%.3f cal/(g·°C)', obj.C_Fe));
            obj.safeSetText(obj.CachedErrorFe, sprintf('%.2f%%', errorFe));
            obj.safeSetText(obj.CachedResultAl, sprintf('%.3f cal/(g·°C)', obj.C_Al));
            obj.safeSetText(obj.CachedErrorAl, sprintf('%.2f%%', errorAl));

            % 计算不确定度
            obj.calculateUncertainty();

            obj.ExpStage = obj.STAGE_CALCULATED;
            obj.logOperation('计算完成', sprintf('C_Fe=%.4f, C_Al=%.4f', obj.C_Fe, obj.C_Al));
            obj.updateStatus(sprintf('计算完成！铁: C=%.3f cal/(g·°C) (误差%.2f%%), 铝: C=%.3f cal/(g·°C) (误差%.2f%%)', ...
                obj.C_Fe, errorFe, obj.C_Al, errorAl));

            obj.BtnCalculate.Enable = 'off';
            obj.BtnComplete.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnComplete, 'success');

            if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep('calculate'); end
            obj.showNextStepHint();
        end

        function calculateUncertainty(obj)
            % 计算不确定度
            % 根据误差传递公式 (3-3-7) 和 (3-3-8)
            % ΔC₂/C₂ = ΔM₁/M₁ + ΔM₂/M₂ + Δ(Δt)₁/(Δt)₁ + Δ(Δt)₂/(Δt)₂

            % 计算散热时间的不确定度
            % U_Δt = sqrt(sum((Δt_i - Δt_avg)²)/(n-1) + U_B²)

            % 铁的散热时间不确定度
            if length(obj.CoolingTimesFe) >= 5
                stdFe = std(obj.CoolingTimesFe);
                U_dt_Fe = sqrt(stdFe^2/5 + obj.U_B^2);
            else
                U_dt_Fe = obj.U_B;
            end

            % 铜的散热时间不确定度
            if length(obj.CoolingTimesCu) >= 5
                stdCu = std(obj.CoolingTimesCu);
                U_dt_Cu = sqrt(stdCu^2/5 + obj.U_B^2);
            else
                U_dt_Cu = obj.U_B;
            end

            % 铝的散热时间不确定度
            if length(obj.CoolingTimesAl) >= 5
                stdAl = std(obj.CoolingTimesAl);
                U_dt_Al = sqrt(stdAl^2/5 + obj.U_B^2);
            else
                U_dt_Al = obj.U_B;
            end

            % 铁的相对不确定度
            % ε_C_Fe = sqrt((U_M_Cu/M_Cu)² + (U_M_Fe/M_Fe)² + (U_dt_Fe/Δt_Fe)² + (U_dt_Cu/Δt_Cu)²)
            eps_C_Fe = sqrt((obj.U_mass/obj.MassCu)^2 + (obj.U_mass/obj.MassFe)^2 + ...
                (U_dt_Fe/obj.AvgTimeFe)^2 + (U_dt_Cu/obj.AvgTimeCu)^2);
            U_C_Fe = obj.C_Fe * eps_C_Fe;

            % 铝的相对不确定度
            eps_C_Al = sqrt((obj.U_mass/obj.MassCu)^2 + (obj.U_mass/obj.MassAl)^2 + ...
                (U_dt_Al/obj.AvgTimeAl)^2 + (U_dt_Cu/obj.AvgTimeCu)^2);
            U_C_Al = obj.C_Al * eps_C_Al;

            % 更新显示
            obj.safeSetText(obj.CachedUncertaintyFe, sprintf('%.4f cal/(g·°C) (ε=%.2f%%)', U_C_Fe, eps_C_Fe*100));
            obj.safeSetText(obj.CachedUncertaintyAl, sprintf('%.4f cal/(g·°C) (ε=%.2f%%)', U_C_Al, eps_C_Al*100));
        end

        function stopRecording(obj)
            % 停止记录
            obj.IsRecording = false;
            obj.safeStopTimer(obj.RecordTimer);
            obj.RecordTimer = [];
        end

        function resetExperiment(obj)
            % 重置实验
            obj.logOperation('重置实验');
            obj.stopRecording();

            % 重置数据
            obj.CurrentTemp = obj.RoomTemp;
            obj.CurrentVoltage = 0;
            obj.MassFe = 0;
            obj.MassCu = 0;
            obj.MassAl = 0;
            obj.CurrentSample = '';
            obj.CoolingTimesFe = [];
            obj.CoolingTimesCu = [];
            obj.CoolingTimesAl = [];
            obj.AvgTimeFe = 0;
            obj.AvgTimeCu = 0;
            obj.AvgTimeAl = 0;
            obj.TimeData = [];
            obj.TempData = [];
            obj.ElapsedTime = 0;
            obj.IsRecording = false;
            obj.IsCooling = false;
            obj.WaitingForHeater = false;
            obj.WaitingForCooling = false;
            obj.CoolingStartTime = 0;
            obj.CoolingEndTime = 0;
            obj.ExpStage = obj.STAGE_INIT;
            obj.C_Fe = 0;
            obj.C_Al = 0;
            obj.ExperimentCompleted = false;

            % 重置显示
            obj.BalanceDisplay.Text = '0.000 g';
            obj.TimerDisplay.Text = '00.00 s';

            % 安全更新图中电压表（使用缓存句柄）
            if ~isempty(obj.CachedVoltmeterText) && isvalid(obj.CachedVoltmeterText)
                obj.CachedVoltmeterText.String = '0.000';
            end
            obj.SampleDisplay.Text = '无';

            if ~isempty(obj.CachedTempDisplay) && isvalid(obj.CachedTempDisplay)
                obj.CachedTempDisplay.Text = '--';
            end

            if ~isempty(obj.CachedCoolingStatus) && isvalid(obj.CachedCoolingStatus)
                obj.CachedCoolingStatus.Text = '待开始';
                obj.CachedCoolingStatus.FontColor = [0.5, 0.5, 0.5];
            end

            % 重置表格
            obj.DataTable.Data = {'Fe', '', '', '', '', '', ''; ...
                                  'Cu', '', '', '', '', '', ''; ...
                                  'Al', '', '', '', '', '', ''};
            obj.disableExportButton();
            massLabels = {obj.CachedMassFeLabel, obj.CachedMassCuLabel, obj.CachedMassAlLabel};
            for i = 1:length(massLabels)
                obj.safeSetText(massLabels{i}, '待测量');
            end

            % 重置结果显示
            resultLabels = {obj.CachedResultFe, obj.CachedErrorFe, obj.CachedResultAl, obj.CachedErrorAl, obj.CachedUncertaintyFe, obj.CachedUncertaintyAl};
            for i = 1:length(resultLabels)
                obj.safeSetText(resultLabels{i}, '待计算');
            end

            % 重置图表
            cla(obj.TempTimeAxes);
            xlim(obj.TempTimeAxes, [0.5, 5.5]);
            ylim(obj.TempTimeAxes, [0, 100]);
            xlabel(obj.TempTimeAxes, '测量次数');
            ylabel(obj.TempTimeAxes, '散热时间 Δt (s)');
            title(obj.TempTimeAxes, '散热时间记录');

            % 重置装置图
            obj.drawApparatus();

            % 重置按钮
            obj.BtnWeighFe.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnWeighFe, 'primary');
            obj.BtnWeighCu.Enable = 'off';
            obj.BtnWeighAl.Enable = 'off';
            obj.BtnSetupThermocouple.Enable = 'off';
            obj.BtnHeatSample.Enable = 'off';
            obj.BtnStartCooling.Enable = 'off';
            obj.BtnRecordFe.Enable = 'off';
            obj.BtnRecordCu.Enable = 'off';
            obj.BtnRecordAl.Enable = 'off';
            obj.BtnCalculate.Enable = 'off';
            obj.BtnComplete.Enable = 'off';

            % 重置实验引导
            if ~isempty(obj.ExpGuide)
                obj.ExpGuide.reset();
            end

            obj.updateStatus('实验已重置，请按步骤重新操作');
        end

        function changeSample(obj)
            % 切换到下一个样品逻辑
            [canProceed, ~] = obj.checkOperationValid('change_sample');
            if ~canProceed, return; end

            % 清除高亮
            if ~isempty(obj.SimulationAxes) && isvalid(obj.SimulationAxes)
                set(obj.SimulationAxes.Children, 'PickableParts', 'none');
                obj.drawApparatus();
            end

            switch obj.CurrentSample
                case 'Fe'
                    % 铁 -> 铜
                    obj.CurrentSample = 'Cu';
                    obj.SampleDisplay.Text = '铜(Cu)';
                    obj.updateStatus('已切换至铜样品。请加热铜样品');

                    % 启用加热按钮
                    obj.BtnHeatSample.Enable = 'on';
                    ui.StyleConfig.applyButtonStyle(obj.BtnHeatSample, 'primary');

                    % 禁用自己，等待铜测量完成
                    obj.BtnChangeSample.Enable = 'off';
                    ui.StyleConfig.applyButtonStyle(obj.BtnChangeSample, 'secondary');

                case 'Cu'
                    % 铜 -> 铝
                    obj.CurrentSample = 'Al';
                    obj.SampleDisplay.Text = '铝(Al)';
                    obj.updateStatus('已切换至铝样品。请加热铝样品');

                    % 启用加热按钮
                    obj.BtnHeatSample.Enable = 'on';
                    ui.StyleConfig.applyButtonStyle(obj.BtnHeatSample, 'primary');

                    % 禁用自己，铝是最后一个，且做完直接计算，不再需要该按钮
                    obj.BtnChangeSample.Enable = 'off';
                    ui.StyleConfig.applyButtonStyle(obj.BtnChangeSample, 'secondary');

                case 'Al'
                     % 理论上不会到这里，因为Al做完直接走计算流程
            end

            % 强制更新图表
            obj.updateCoolingChart();
        end
    end

    methods (Access = protected)
        function onCleanup(obj)
            % 清理资源
            obj.stopRecording();
            if ~isempty(obj.InteractionMgr)
                delete(obj.InteractionMgr);
                obj.InteractionMgr = [];
            end
            obj.safeStopTimer(obj.AnimationTimer);
            obj.AnimationTimer = [];
        end
    end

    methods (Access = private)
        function restoreDisplayState(obj)
            % 恢复仪器读数和图形
            obj.drawApparatus();

            % 恢复天平显示
            if obj.MassFe > 0 || obj.MassCu > 0 || obj.MassAl > 0
                lastMass = max([obj.MassFe, obj.MassCu, obj.MassAl]);
                obj.BalanceDisplay.Text = sprintf('%.3f g', lastMass);
            end

            % 恢复电压表显示
            if obj.CurrentVoltage > 0
                if ~isempty(obj.CachedVoltmeterText) && isvalid(obj.CachedVoltmeterText)
                    obj.CachedVoltmeterText.String = sprintf('%.3f', obj.CurrentVoltage);
                end
            end

            % 恢复当前样品显示
            if ~isempty(obj.CurrentSample)
                obj.SampleDisplay.Text = obj.CurrentSample;
            end

            % 恢复表格数据
            if ~isempty(obj.DataTable) && isvalid(obj.DataTable)
                obj.restoreTableData();
            end
        end

        function restoreTableData(obj)
            % 恢复表格中已测量的数据
            timesData = {obj.CoolingTimesFe, obj.CoolingTimesCu, obj.CoolingTimesAl};
            for s = 1:3
                times = timesData{s};
                for j = 1:length(times)
                    obj.DataTable.Data{s, j+1} = sprintf('%.2f', times(j));
                end
            end
        end

        function restoreButtonStates(obj)
            % 根据当前实验阶段恢复按钮状态

            % 先禁用所有操作按钮
            allBtns = {obj.BtnWeighFe, obj.BtnWeighCu, obj.BtnWeighAl, ...
                       obj.BtnSetupThermocouple, obj.BtnHeatSample, ...
                       obj.BtnStartCooling, obj.BtnRecordFe, obj.BtnRecordCu, ...
                       obj.BtnRecordAl, obj.BtnChangeSample, ...
                       obj.BtnCalculate, obj.BtnComplete};
            obj.disableAllButtons(allBtns);

            switch obj.ExpStage
                case obj.STAGE_INIT
                    % 称量阶段 — 根据已称量的样品判断
                    if obj.MassAl > 0
                        obj.BtnSetupThermocouple.Enable = 'on';
                        ui.StyleConfig.applyButtonStyle(obj.BtnSetupThermocouple, 'primary');
                    elseif obj.MassCu > 0
                        obj.BtnWeighAl.Enable = 'on';
                        ui.StyleConfig.applyButtonStyle(obj.BtnWeighAl, 'primary');
                    elseif obj.MassFe > 0
                        obj.BtnWeighCu.Enable = 'on';
                        ui.StyleConfig.applyButtonStyle(obj.BtnWeighCu, 'primary');
                    else
                        obj.BtnWeighFe.Enable = 'on';
                        ui.StyleConfig.applyButtonStyle(obj.BtnWeighFe, 'primary');
                    end
                case obj.STAGE_WEIGHED
                    obj.BtnSetupThermocouple.Enable = 'on';
                    ui.StyleConfig.applyButtonStyle(obj.BtnSetupThermocouple, 'primary');
                case obj.STAGE_THERMOCOUPLE
                    obj.BtnHeatSample.Enable = 'on';
                    ui.StyleConfig.applyButtonStyle(obj.BtnHeatSample, 'primary');
                case {obj.STAGE_HEATING, obj.STAGE_COOLING}
                    % 加热/冷却循环中 — 恢复到可操作的最近状态
                    if obj.IsCooling
                        % 正在冷却中,等待冷却完成
                    else
                        % 默认恢复到加热按钮
                        obj.BtnHeatSample.Enable = 'on';
                        ui.StyleConfig.applyButtonStyle(obj.BtnHeatSample, 'primary');
                    end
                case obj.STAGE_DATA_DONE
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
            obj.safeStopTimer(obj.AnimationTimer);
            obj.AnimationTimer = [];
            obj.setupExperimentUI();
            % 恢复显示状态
            obj.restoreDisplayState();
            % 恢复按钮状态
            obj.restoreButtonStates();
        end

        function summary = getExportSummary(obj)
            % 获取实验结果摘要
            summary = getExportSummary@experiments.ExperimentBase(obj);
            errFe = abs(obj.C_Fe - obj.C_Fe_standard) / obj.C_Fe_standard * 100;
            errAl = abs(obj.C_Al - obj.C_Al_standard) / obj.C_Al_standard * 100;
            summary = [summary; ...
                {'铁比热容 (cal/g·°C)', sprintf('%.4f', obj.C_Fe)}; ...
                {'铁相对误差', sprintf('%.2f%%', errFe)}; ...
                {'铝比热容 (cal/g·°C)', sprintf('%.4f', obj.C_Al)}; ...
                {'铝相对误差', sprintf('%.2f%%', errAl)}; ...
                {'铁平均散热时间 (s)', sprintf('%.2f', obj.AvgTimeFe)}; ...
                {'铜平均散热时间 (s)', sprintf('%.2f', obj.AvgTimeCu)}; ...
                {'铝平均散热时间 (s)', sprintf('%.2f', obj.AvgTimeAl)}];
        end
    end

    methods (Access = private)
        function setupExperimentGuide(obj)
            % 初始化实验引导系统（含重复测量）
            obj.ExpGuide = ui.ExperimentGuide(obj.Figure, @(msg) obj.updateStatus(msg));

            % === 阶段1：称量样品 ===
            obj.ExpGuide.addStep('weigh_Fe', '1. 称量铁样品', ...
                '使用电子天平称量铁样品质量');
            obj.ExpGuide.addStep('weigh_Cu', '2. 称量铜样品', ...
                '使用电子天平称量铜样品质量（铜为标准样品）', ...
                'Prerequisites', {'weigh_Fe'});
            obj.ExpGuide.addStep('weigh_Al', '3. 称量铝样品', ...
                '使用电子天平称量铝样品质量（验证M_Cu > M_Fe > M_Al）', ...
                'Prerequisites', {'weigh_Cu'});

            % === 阶段2：安装热电偶 ===
            obj.ExpGuide.addStep('setup_thermocouple', '4. 安装热电偶', ...
                '将热电偶穿过防风容器，冷端放入冰水混合物', ...
                'Prerequisites', {'weigh_Al'});

            % === 阶段3：铁样品测量（5次重复） ===
            obj.ExpGuide.addRepeatGroup('Fe_measurement', 5, '铁样品测量');
            for i = 1:5
                stepId = sprintf('heat_Fe_%d', i);
                obj.ExpGuide.addStep(stepId, sprintf('加热铁样品(第%d次)', i), ...
                    '加热铁样品至目标温度4.927mV', ...
                    'Prerequisites', {obj.getPrereqForMeasurement('Fe', i)}, ...
                    'RepeatGroup', 'Fe_measurement', 'RepeatIndex', i);

                coolStepId = sprintf('cool_Fe_%d', i);
                obj.ExpGuide.addStep(coolStepId, sprintf('冷却铁样品(第%d次)', i), ...
                    '开始冷却并记录102°C→98°C散热时间', ...
                    'Prerequisites', {stepId}, ...
                    'RepeatGroup', 'Fe_measurement', 'RepeatIndex', i);

                recordStepId = sprintf('record_Fe_%d', i);
                obj.ExpGuide.addStep(recordStepId, sprintf('记录铁散热时间(第%d次)', i), ...
                    '记录本次散热时间数据', ...
                    'Prerequisites', {coolStepId}, ...
                    'RepeatGroup', 'Fe_measurement', 'RepeatIndex', i);
            end

            % === 阶段4：铜样品测量（5次重复） ===
            obj.ExpGuide.addRepeatGroup('Cu_measurement', 5, '铜样品测量');
            for i = 1:5
                stepId = sprintf('heat_Cu_%d', i);
                obj.ExpGuide.addStep(stepId, sprintf('加热铜样品(第%d次)', i), ...
                    '加热铜样品至目标温度4.927mV', ...
                    'Prerequisites', {obj.getPrereqForMeasurement('Cu', i)}, ...
                    'RepeatGroup', 'Cu_measurement', 'RepeatIndex', i);

                coolStepId = sprintf('cool_Cu_%d', i);
                obj.ExpGuide.addStep(coolStepId, sprintf('冷却铜样品(第%d次)', i), ...
                    '开始冷却并记录102°C→98°C散热时间', ...
                    'Prerequisites', {stepId}, ...
                    'RepeatGroup', 'Cu_measurement', 'RepeatIndex', i);

                recordStepId = sprintf('record_Cu_%d', i);
                obj.ExpGuide.addStep(recordStepId, sprintf('记录铜散热时间(第%d次)', i), ...
                    '记录本次散热时间数据', ...
                    'Prerequisites', {coolStepId}, ...
                    'RepeatGroup', 'Cu_measurement', 'RepeatIndex', i);
            end

            % === 阶段5：铝样品测量（5次重复） ===
            obj.ExpGuide.addRepeatGroup('Al_measurement', 5, '铝样品测量');
            for i = 1:5
                stepId = sprintf('heat_Al_%d', i);
                obj.ExpGuide.addStep(stepId, sprintf('加热铝样品(第%d次)', i), ...
                    '加热铝样品至目标温度4.927mV', ...
                    'Prerequisites', {obj.getPrereqForMeasurement('Al', i)}, ...
                    'RepeatGroup', 'Al_measurement', 'RepeatIndex', i);

                coolStepId = sprintf('cool_Al_%d', i);
                obj.ExpGuide.addStep(coolStepId, sprintf('冷却铝样品(第%d次)', i), ...
                    '开始冷却并记录102°C→98°C散热时间', ...
                    'Prerequisites', {stepId}, ...
                    'RepeatGroup', 'Al_measurement', 'RepeatIndex', i);

                recordStepId = sprintf('record_Al_%d', i);
                obj.ExpGuide.addStep(recordStepId, sprintf('记录铝散热时间(第%d次)', i), ...
                    '记录本次散热时间数据', ...
                    'Prerequisites', {coolStepId}, ...
                    'RepeatGroup', 'Al_measurement', 'RepeatIndex', i);
            end

            % === 阶段6：计算 ===
            obj.ExpGuide.addStep('calculate', '7. 计算比热容', ...
                '根据公式计算铁和铝的比热容', ...
                'Prerequisites', {'record_Al_5'});
        end

        function prereq = getPrereqForMeasurement(~, sample, index)
            % 获取当前测量步骤的前置条件
            if index == 1
                % 第一次测量
                switch sample
                    case 'Fe'
                        prereq = 'setup_thermocouple';  % 铁的第一次测量需要安装热电偶
                    case 'Cu'
                        prereq = 'record_Fe_5';  % 铜的第一次测量需要完成铁的测量
                    case 'Al'
                        prereq = 'record_Cu_5';  % 铝的第一次测量需要完成铜的测量
                end
            else
                % 后续测量需要上一次记录完成
                prereq = sprintf('record_%s_%d', sample, index - 1);
            end
        end

        function index = getCurrentMeasurementIndex(obj, sample)
            % 获取当前样品的测量序号（即将进行第几次测量）
            if nargin < 2
                sample = obj.CurrentSample;
            end
            switch sample
                case 'Fe'
                    index = length(obj.CoolingTimesFe) + 1;
                case 'Cu'
                    index = length(obj.CoolingTimesCu) + 1;
                case 'Al'
                    index = length(obj.CoolingTimesAl) + 1;
                otherwise
                    index = 1;
            end
        end
    end
end
