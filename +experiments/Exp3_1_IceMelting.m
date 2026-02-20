classdef Exp3_1_IceMelting < experiments.ExperimentBase
    % Exp3_1_IceMelting 实验3-1 冰融解热的测量
    % 用混合法测量冰的融解热，学会用图解法作散热修正

    properties (Access = private)
        % UI组件
        SimulationAxes      % 仿真显示区域
        TempTimeAxes        % 温度-时间曲线

        % 仪器显示
        ThermometerDisplay  % 温度计显示
        BalanceDisplay      % 天平显示
        TimerDisplay        % 计时器显示

        % 缓存的参数/结果标签
        WaterMassLabel      % 水质量参数标签
        IceMassLabel        % 冰质量参数标签
        ResultLLabel        % 融解热结果标签
        ResultErrorLabel    % 误差结果标签

        % 交互管理器
        InteractionMgr      % 仪器点击交互管理器

        % 控制按钮
        BtnPrepareWater     % 准备热水
        BtnWeighCup         % 称量内筒
        BtnAddWater         % 加入热水
        BtnWeighWater       % 称量水
        BtnWeighIce         % 称量冰块
        BtnStartRecord      % 开始记录
        BtnAddIce           % 投入冰块
        BtnWeighFinal       % 最终称量
        BtnCalculate        % 计算融解热
        BtnComplete         % 完成实验

        % 实验数据
        RoomTemp = 20           % 室温 (°C)
        WaterInitTemp = 36      % 热水初始温度 (°C)
        CurrentTemp             % 当前温度
        CupMass = 52.3          % 内筒+搅拌器质量 (g)
        WaterMass = 0           % 水的质量 (g)
        IceMass = 0             % 冰的质量 (g)

        % 时间记录
        TimeData = []           % 时间数据 (min)
        TempData = []           % 温度数据 (°C)
        RecordTimer             % 记录计时器
        AnimationTimer          % 动画计时器
        StirrerPhase = 0        % 搅拌动画相位
        ElapsedTime = 0         % 已过时间 (s)
        IsRecording = false     % 是否正在记录
        WaitingForStir = false  % 是否等待用户搅拌开始记录
        IceAdded = false        % 是否已投入冰块
        IceAddedTime = 0        % 投入冰块的时间

        % 计算结果
        T_H = 0                 % 修正温度 T_H
        T_F = 0                 % 修正温度 T_F
        L_measured = 0          % 测得融解热

        % 增量曲线更新缓存
        CurvePlotHandle         % 温度曲线 plot 句柄
        CurveIceLine            % 投冰时刻参考线
        CurveRoomLine           % 室温参考线
        CurveInitialized = false
    end

    properties (Constant)
        % 物理常数
        c_water = 1.00          % 水的比热容 (cal/(g·°C))
        c_cup = 0.092           % 内筒+搅拌器比热容 (cal/(g·°C))
        L_standard = 79.7       % 冰融解热标准值 (cal/g)

        % 模拟参数
        CoolCoefficient = 0.02  % 自然冷却系数
        HeatCoefficient = 0.015 % 回温加热系数
        MeltingTau = 1.2        % 融冰时间常数 (min)
        MinEquilibriumTemp = 2  % 最低平衡温度限制 (°C)
        IceAddMinTime = 4.5     % 最早允许投入冰块的时间 (min)

        % 实验阶段常量
        STAGE_INIT = 0
        STAGE_WEIGHED = 1
        STAGE_RECORDING = 2
        STAGE_ICE_MELTING = 3
        STAGE_CALCULATED = 4
    end

    methods (Access = public)
        function obj = Exp3_1_IceMelting()
            % 构造函数
            obj@experiments.ExperimentBase();

            % 设置实验基本信息
            obj.ExpNumber = '实验3-1';
            obj.ExpTitle = '冰融解热的测量';

            % 实验目的
            obj.ExpPurpose = ['1. 学习用混合法测量冰的融解热' newline ...
                '2. 学会用图解法作散热修正'];

            % 实验仪器
            obj.ExpInstruments = ['量热器、水银温度计(0~50.00℃)、电子天平、冰、水、电热杯、保温杯、秒表'];

            % 实验原理
            obj.ExpPrinciple = [
                '【融解热定义】' newline ...
                '单位质量的固体物质在熔点时从固态全部变成液态所需要的热量叫作该物质的融解热，' ...
                '用L表示，单位是cal/g。' newline newline ...
                '【混合法测量】' newline ...
                '冰融解热测量的基本思路是把待测系统S₁和一个已知热容的系统S₂混合起来，并设法' ...
                '使它们形成一个与外界没有热量交换的孤立系统。' newline ...
                '这样S₁所吸收或放出的热量，全部由S₂' ...
                '放出或吸收。由于系统S₂在实验过程中所传递的热量是可以通过质量、热容和温度的改变计算出来，' newline ...
                '从而就得到了待测系统S₁在实验过程中所传递的热量。' newline newline ...
                '将质量为M、温度为0℃的冰放入量热器中，设冰全部融解后水温降为T_D，则：' newline ...
                '    ML + McT_D = (mc + m₁c₁)(T_B - T_D)' newline newline ...
                '其中m为水的质量，c为水的比热容，m₁、c₁为量热器内筒(含搅拌器)的质量和比热容，' ...
                'T_B为投入冰块时水的温度。' newline newline ...
                '【牛顿冷却规律与散热修正】' newline ...
                '量热器并非绝热，存在与外部的热量交换。根据牛顿冷却规律：' newline ...
                '    dQ₁/dt = K(T - T_h)^α' newline newline ...
                '通过温度-时间曲线的图解法，可以对散热进行修正，得到修正后的融解热计算公式：' newline ...
                '    L = [(mc + m₁c₁)(T_H - T_F)] / M - cT_F' newline newline ...
                '其中T_H和T_F是通过图解法求得的修正温度。'];

            % 实验内容
            obj.ExpContent = [
                '1. 准备冰和热水' newline ...
                '   提前用实验室的冰柜冻好实验用的冰。取若干小冰块放在保温杯里备用。' newline ...
                '   给电热杯装上水，插上电源，将水烧热备用。' newline newline ...
                '2. 称衡质量和测量水温' newline ...
                '   ① 用电子天平称出量热器内筒(连同搅拌器)的质量m₁' newline ...
                '   ② 记录室温t₀，把热水倒入量热器内筒，调试水温约比室温高16℃左右' newline ...
                '   ③ 再称衡其质量，从而得到水的质量m' newline ...
                '   ④ 用电子天平称出所需的冰块质量，冰和水的比例约为1:3' newline ...
                '   ⑤ 装好量热器，用搅拌器连续搅拌水，每隔0.5min记一次水温，共测5min' newline newline ...
                '3. 投入冰块' newline ...
                '   ⑥ 当温度测量进行到第5min时，将冰块投入量热器内筒，记录此时水温T₁' newline ...
                '   注意：冰从保温杯中取出后要用毛巾将其擦干才能投入量热器' newline ...
                '   ⑦ 投入冰块后，立即继续搅拌，仍然每隔0.5min记录一次水温' newline ...
                '   ⑧ 温度达到最低点后再继续测量水温4~5min' newline ...
                '   ⑨ 取出内筒再次称衡质量，从而求得融入水中的冰的质量M' newline newline ...
                '4. 图解法求修正温度' newline ...
                '   作T-t图，用修正方法求修正温度T_H和T_F' newline newline ...
                '5. 计算冰的融解热' newline ...
                '   把数据代入公式计算融解热L的值，并求与公认值79.7(cal/g)的百分误差'];

            % 思考讨论
            obj.ExpQuestions = {
                '为什么冰和水的质量要有一定的比例？如果冰投入太多，会产生什么后果？', ...
                ['冰和水的质量比例（约1:3）的设计考虑：' newline ...
                '1. 如果冰太多，热水不足以将冰全部融化，实验无法完成' newline ...
                '2. 冰太多会导致最终温度过低（甚至低于室温太多），增加散热修正的复杂性' newline ...
                '3. 冰太少则温度变化不明显，测量误差增大' newline ...
                '4. 合适的比例使得最终温度接近室温，可以减小散热误差'];

                '试证明图3-1-2中若T_D > T_h，修正式(3-1-17)依然成立。', ...
                ['当T_D > T_h（即融冰后水温高于室温）时：' newline ...
                '1. 在整个实验过程中，系统始终向环境散热' newline ...
                '2. 图解法中的面积S_BGC和S_CPD的符号会发生变化' newline ...
                '3. 但由于修正公式的推导是基于能量守恒，无论系统吸热还是放热，' ...
                '   只要S_BHK = S_KFD的条件满足，修正式仍然成立' newline ...
                '4. 这说明图解修正法具有普适性，不依赖于最终温度与室温的相对大小'];
                };

            % 初始化温度
            obj.CurrentTemp = obj.WaterInitTemp;
        end
    end

    methods (Access = protected)
        function setupExperimentUI(obj)
            % 设置实验界面
            try
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
                obj.SimulationAxes.XTick = [];
                obj.SimulationAxes.YTick = [];
                obj.SimulationAxes.Box = 'on';
                obj.SimulationAxes.Color = ui.StyleConfig.SimulationBgColor;
                title(obj.SimulationAxes, '量热器示意图', ...
                    'FontName', ui.StyleConfig.FontFamily, 'Color', ui.StyleConfig.TextPrimary);

                % 温度-时间曲线区域
                obj.TempTimeAxes = uiaxes(plotGrid);
                ui.StyleConfig.applyAxesStyle(obj.TempTimeAxes);
                title(obj.TempTimeAxes, '温度-时间曲线', ...
                    'FontName', ui.StyleConfig.FontFamily, 'Color', ui.StyleConfig.TextPrimary);
                xlabel(obj.TempTimeAxes, '时间 t (min)');
                ylabel(obj.TempTimeAxes, '温度 T (°C)');
                xlim(obj.TempTimeAxes, [0, 15]);
                ylim(obj.TempTimeAxes, [5, 40]);

                % 绘制初始量热器
                obj.drawCalorimeter();

                % 初始化交互管理器并设置可点击区域
                obj.setupInteraction();

                % 初始化实验引导系统
                obj.setupExperimentGuide();

                % ---------- 2. 仪器读数区域 ----------
                instrumentPanel = uipanel(mainLayout, ...
                    'Title', '仪器读数', ...
                    'FontName', ui.StyleConfig.FontFamily, ...
                    'FontSize', ui.StyleConfig.FontSizeNormal, ...
                    'FontWeight', 'bold', ...
                    'BackgroundColor', ui.StyleConfig.PanelColor, ...
                    'ForegroundColor', ui.StyleConfig.TextPrimary);

                % 仪器面板布局 (1行4列)
                instGrid = uigridlayout(instrumentPanel, [1, 4], ...
                    'ColumnWidth', {'1x', '1x', '1x', '0.8x'}, ...
                    'Padding', [10, 5, 10, 5], ...
                    'ColumnSpacing', 10, ...
                    'BackgroundColor', ui.StyleConfig.PanelColor);

                % 设置父容器在主布局中的位置
                instrumentPanel.Layout.Row = 2;
                instrumentPanel.Layout.Column = 1;

                % 温度计显示
                obj.ThermometerDisplay = obj.createInstrumentDisplay(instGrid, '温度计', '20.00 °C', ui.StyleConfig.ThermometerColor, 1, 1);

                % 电子天平显示
                obj.BalanceDisplay = obj.createInstrumentDisplay(instGrid, '电子天平', '0.00 g', ui.StyleConfig.BalanceColor, 1, 2);

                % 计时器显示
                obj.TimerDisplay = obj.createInstrumentDisplay(instGrid, '计时器', '00:00', ui.StyleConfig.PrimaryColor, 1, 3);

                % 室温显示
                lRoom = uilabel(instGrid, ...
                    'Text', sprintf('室温: %.1f°C', obj.RoomTemp), ...
                    'FontName', ui.StyleConfig.FontFamily, ...
                    'FontSize', ui.StyleConfig.FontSizeNormal, ...
                    'FontColor', ui.StyleConfig.TextSecondary, ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'center');
                lRoom.Layout.Row = 1;
                lRoom.Layout.Column = 4;

                % ---------- 3. 操作按钮区域 ----------
                btnPanel = uipanel(mainLayout, ...
                    'Title', '实验操作', ...
                    'FontName', ui.StyleConfig.FontFamily, ...
                    'FontSize', ui.StyleConfig.FontSizeNormal, ...
                    'FontWeight', 'bold', ...
                    'BackgroundColor', ui.StyleConfig.PanelColor, ...
                    'ForegroundColor', ui.StyleConfig.TextPrimary);
                btnPanel.Layout.Row = 3;
                btnPanel.Layout.Column = 1;

                % 按钮网格布局 (3行5列)
                btnGrid = uigridlayout(btnPanel, [3, 5], ...
                    'ColumnWidth', repmat({'1x'}, 1, 5), ...
                    'RowHeight', {'1x', '1x', '1x'}, ...
                    'Padding', [5, 5, 5, 5], ...
                    'RowSpacing', 5, 'ColumnSpacing', 5);

                obj.BtnWeighCup = obj.createExpButton(btnGrid, '1. 称量内筒', @(~,~) obj.weighCup(), 'primary', 1, 1);
                obj.BtnPrepareWater = obj.createExpButton(btnGrid, '2. 准备热水', @(~,~) obj.prepareWater(), 'disabled', 1, 2);
                obj.BtnAddWater = obj.createExpButton(btnGrid, '3. 倒入热水', @(~,~) obj.addWater(), 'disabled', 1, 3);
                obj.BtnWeighWater = obj.createExpButton(btnGrid, '4. 称量水质量', @(~,~) obj.weighWater(), 'disabled', 1, 4);
                obj.BtnWeighIce = obj.createExpButton(btnGrid, '5. 称量冰块', @(~,~) obj.weighIce(), 'disabled', 1, 5);

                % 第二行按钮
                obj.BtnStartRecord = obj.createExpButton(btnGrid, '6. 开始记录', @(~,~) obj.startRecording(), 'disabled', 2, 1);
                obj.BtnAddIce = obj.createExpButton(btnGrid, '7. 投入冰块', @(~,~) obj.addIce(), 'disabled', 2, 2);
                obj.BtnWeighFinal = obj.createExpButton(btnGrid, '8. 最终称量', @(~,~) obj.weighFinal(), 'disabled', 2, 3);
                obj.BtnCalculate = obj.createExpButton(btnGrid, '9. 计算融解热', @(~,~) obj.calculateResult(), 'disabled', 2, 4);

                % 第三行 (完成和重置按钮)
                obj.BtnComplete = obj.createExpButton(btnGrid, '完成实验', @(~,~) obj.completeExperiment(), 'disabled', 3, 4);
                resetBtn = uibutton(btnGrid, 'Text', '重置实验', ...
                    'ButtonPushedFcn', @(~,~) obj.resetExperiment());
                resetBtn.Layout.Row = 3;
                resetBtn.Layout.Column = 5;
                ui.StyleConfig.applyButtonStyle(resetBtn, 'warning');

                % ==================== 右侧面板 ====================

                % ---------- 参数控制面板 (右上) ----------
                controlGrid = ui.StyleConfig.createControlPanelGrid(obj.ControlPanel, 7);

                % 标题行
                titleLabel = ui.StyleConfig.createPanelTitle(controlGrid, '实验参数');
                titleLabel.Layout.Row = 1;
                titleLabel.Layout.Column = [1, 2];

                % 参数行
                paramLabels = {'室温 t₀:', '内筒质量 m₁:', '内筒比热 c₁:', ...
                    '水的质量 m:', '冰的质量 M:', '水的比热 c:'};
                paramValues = {sprintf('%.1f °C', obj.RoomTemp), ...
                    sprintf('%.2f g', obj.CupMass), ...
                    sprintf('%.3f cal/(g·°C)', obj.c_cup), ...
                    '待测量', '待测量', ...
                    sprintf('%.2f cal/(g·°C)', obj.c_water)};
                paramTags = {'', '', '', 'WaterMassLabel', 'IceMassLabel', ''};

                for i = 1:length(paramLabels)
                    l = ui.StyleConfig.createParamLabel(controlGrid, paramLabels{i});
                    l.Layout.Row = i + 1;
                    l.Layout.Column = 1;

                    v = ui.StyleConfig.createParamValue(controlGrid, paramValues{i});
                    v.Layout.Row = i + 1;
                    v.Layout.Column = 2;
                    switch paramTags{i}
                        case 'WaterMassLabel', obj.WaterMassLabel = v;
                        case 'IceMassLabel',   obj.IceMassLabel = v;
                    end
                end

                % ---------- 实验数据面板 (右下) ----------
                dataGrid = ui.StyleConfig.createDataPanelGrid(obj.DataPanel, '1x', 100);

                % 标题行
                dataTitleLabel = ui.StyleConfig.createPanelTitle(dataGrid, '实验数据');
                dataTitleLabel.Layout.Row = 1;

                % 数据表格
                obj.DataTable = ui.StyleConfig.createDataTable(dataGrid, ...
                    {'时间(min)', '温度(°C)', '备注'}, {80, 80, 'auto'});
                obj.DataTable.Layout.Row = 2;
                obj.DataTable.Data = {};

                % 结果区域
                resultGrid = ui.StyleConfig.createResultGrid(dataGrid, 2);
                resultGrid.Layout.Row = 3;

                lbl1 = ui.StyleConfig.createResultLabel(resultGrid, '融解热 L =');
                lbl1.Layout.Row = 1; lbl1.Layout.Column = 1;
                val1 = ui.StyleConfig.createResultValue(resultGrid, '待计算');
                val1.Layout.Row = 1; val1.Layout.Column = 2;
                obj.ResultLLabel = val1;

                lbl2 = ui.StyleConfig.createResultLabel(resultGrid, '相对误差 =');
                lbl2.Layout.Row = 2; lbl2.Layout.Column = 1;
                val2 = ui.StyleConfig.createResultValue(resultGrid, '待计算');
                val2.Layout.Row = 2; val2.Layout.Column = 2;
                obj.ResultErrorLabel = val2;

                obj.updateStatus('准备开始实验，请按步骤操作');

                % 强制刷新布局
                drawnow;

            catch ME
                % 错误捕获：弹窗显示具体错误信息
                uialert(obj.Figure, sprintf('UI初始化失败:\n%s\nFile: %s\nLine: %d', ...
                    ME.message, ME.stack(1).name, ME.stack(1).line), '程序错误');
            end
        end

        function drawCalorimeter(obj, stirrerOffset)
            % 绘制量热器示意图（参考图3-1-1）
            if nargin < 2
                stirrerOffset = 0;
            end

            ax = obj.SimulationAxes;
            cla(ax);
            hold(ax, 'on');

            % 外筒（带斜线阴影效果）
            rectangle(ax, 'Position', [0.1, 0.08, 0.8, 0.75], ...
                'Curvature', [0.02, 0.02], ...
                'FaceColor', [0.85, 0.85, 0.85], ...
                'EdgeColor', [0.3, 0.3, 0.3], ...
                'LineWidth', 2);

            % 外筒内部空白（隔热层）
            rectangle(ax, 'Position', [0.15, 0.12, 0.7, 0.67], ...
                'FaceColor', [0.95, 0.95, 0.95], ...
                'EdgeColor', 'none');

            % 内筒
            rectangle(ax, 'Position', [0.22, 0.15, 0.56, 0.55], ...
                'Curvature', [0.02, 0.02], ...
                'FaceColor', [0.75, 0.88, 1], ...
                'EdgeColor', [0.2, 0.2, 0.2], ...
                'LineWidth', 1.5);

            % 水（如果有）
            waterTop = 0.55;  % 水面高度
            if obj.ExpStage >= obj.STAGE_RECORDING
                % 水温变化用颜色表示
                waterColor = obj.tempToColor(obj.CurrentTemp);
                rectangle(ax, 'Position', [0.24, 0.17, 0.52, waterTop - 0.17], ...
                    'FaceColor', waterColor, ...
                    'EdgeColor', 'none');

                % 水面波纹
                for i = 1:3
                    y = waterTop - 0.02 + i*0.01;
                    plot(ax, linspace(0.26, 0.74, 20), ...
                        y + 0.005*sin(linspace(0, 4*pi, 20)), ...
                        'Color', [0.4, 0.6, 0.85], 'LineWidth', 0.5);
                end
            end

            % 盖子/支架
            rectangle(ax, 'Position', [0.18, 0.7, 0.64, 0.08], ...
                'FaceColor', [0.7, 0.7, 0.7], ...
                'EdgeColor', [0.3, 0.3, 0.3], ...
                'LineWidth', 1);

            % 温度计（浸入水中）
            % 温度计主体（玻璃管）
            plot(ax, [0.38, 0.38], [0.25, 0.9], 'Color', [0.4, 0.4, 0.4], 'LineWidth', 4);
            plot(ax, [0.38, 0.38], [0.25, 0.9], 'Color', [0.9, 0.9, 0.95], 'LineWidth', 2);
            % 温度计红色液柱（根据温度变化高度，范围0-50°C）
            if obj.ExpStage >= obj.STAGE_WEIGHED
                % 液柱高度: 0°C对应0.25, 50°C对应0.75
                bulbHeight = 0.25 + (obj.CurrentTemp / 50) * 0.5;
                bulbHeight = max(0.25, min(0.75, bulbHeight));
            else
                bulbHeight = 0.35;  % 默认室温约20°C
            end
            plot(ax, [0.38, 0.38], [0.25, bulbHeight], 'r-', 'LineWidth', 2);
            % 温度计球部
            plot(ax, 0.38, 0.25, 'ro', 'MarkerSize', 7, 'MarkerFaceColor', 'r');

            % 搅拌器（T型结构）
            % 手柄
            plot(ax, [0.62, 0.62], [0.72 + stirrerOffset, 0.92 + stirrerOffset], 'k-', 'LineWidth', 3);
            % 横杆（手柄顶部）
            plot(ax, [0.57, 0.67], [0.92 + stirrerOffset, 0.92 + stirrerOffset], 'k-', 'LineWidth', 3);
            % 搅拌杆（垂直向下进入水中）
            plot(ax, [0.62, 0.62], [0.25 + stirrerOffset, 0.72 + stirrerOffset], 'Color', [0.3, 0.3, 0.3], 'LineWidth', 2);
            % 搅拌叶片
            plot(ax, [0.55, 0.69], [0.28 + stirrerOffset, 0.28 + stirrerOffset], 'Color', [0.3, 0.3, 0.3], 'LineWidth', 2);
            plot(ax, [0.55, 0.69], [0.35 + stirrerOffset, 0.35 + stirrerOffset], 'Color', [0.3, 0.3, 0.3], 'LineWidth', 2);

            % 标注
            text(ax, 0.92, 0.5, '外筒', 'FontName', ui.StyleConfig.FontFamily, 'FontSize', 10, 'Color', ui.StyleConfig.TextPrimary);
            text(ax, 0.78, 0.4, '内筒', 'FontName', ui.StyleConfig.FontFamily, 'FontSize', 10, 'Color', ui.StyleConfig.TextPrimary);
            text(ax, 0.15, 0.5, '温度计', 'FontName', ui.StyleConfig.FontFamily, 'FontSize', 9, 'Color', ui.StyleConfig.TextPrimary);
            text(ax, 0.68, 0.5, '搅拌器', 'FontName', ui.StyleConfig.FontFamily, 'FontSize', 9, 'Color', ui.StyleConfig.TextPrimary);

            % 如果有冰块
            if obj.IceAdded && obj.CurrentTemp < obj.RoomTemp + 5
                % 绘制冰块（漂浮在水中）
                icePositions = [0.32, 0.45; 0.48, 0.42; 0.58, 0.46];
                for i = 1:size(icePositions, 1)
                    x = icePositions(i, 1);
                    y = icePositions(i, 2);
                    rectangle(ax, 'Position', [x, y, 0.08, 0.06], ...
                        'FaceColor', [0.85, 0.95, 1], ...
                        'EdgeColor', [0.5, 0.7, 0.9], ...
                        'LineWidth', 1, ...
                        'Curvature', [0.2, 0.2]);
                end
            end

            % 关键修复：设置所有绘图对象不拦截点击事件，使点击能穿透到Axes被InteractionManager捕获
            set(ax.Children, 'PickableParts', 'none');

            hold(ax, 'off');
            xlim(ax, [0, 1.05]);
            ylim(ax, [0, 1]);
            ax.XTick = [];
            ax.YTick = [];
        end

    end

    methods (Static, Access = private)
        function color = tempToColor(temp)
            % 根据温度返回颜色（范围0-50°C）
            % 低温蓝色，高温红色
            normalizedTemp = temp / 50;  % 归一化到0-1（0-50°C）
            normalizedTemp = max(0, min(1, normalizedTemp));
            % 蓝(0°C) -> 浅蓝(20°C) -> 淡红(40°C) -> 红(50°C)
            r = 0.3 + 0.7 * normalizedTemp;
            g = 0.5 + 0.3 * (1 - abs(normalizedTemp - 0.4) * 2);
            b = 1 - 0.6 * normalizedTemp;
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
            obj.updateStatus(sprintf('内筒+搅拌器质量: %.2f g', obj.CupMass));
            obj.updateInteractionHint();

            obj.BtnWeighCup.Enable = 'off';
            obj.BtnPrepareWater.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnPrepareWater, 'primary');

            if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep('weigh_cup'); end
            obj.showNextStepHint();
        end

        function prepareWater(obj)
            % 准备热水
            [canProceed, ~] = obj.checkOperationValid('prepare_water');
            if ~canProceed, return; end

            obj.WaterInitTemp = obj.RoomTemp + 16 + randn()*0.5;
            obj.CurrentTemp = obj.WaterInitTemp;
            obj.ThermometerDisplay.Text = sprintf('%.2f °C', obj.CurrentTemp);
            obj.updateStatus(sprintf('热水已准备好，温度: %.2f°C', obj.CurrentTemp));

            obj.BtnPrepareWater.Enable = 'off';
            obj.BtnAddWater.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnAddWater, 'primary');

            if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep('prepare_water'); end
            obj.showNextStepHint();
        end

        function addWater(obj)
            % 倒入热水
            [canProceed, ~] = obj.checkOperationValid('add_water');
            if ~canProceed, return; end

            obj.ExpStage = obj.STAGE_RECORDING;
            obj.WaterMass = 150 + rand()*20;  % 150-170g
            obj.drawCalorimeter();
            obj.updateStatus('热水已倒入量热器');
            obj.updateInteractionHint();

            obj.BtnAddWater.Enable = 'off';
            obj.BtnWeighWater.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnWeighWater, 'primary');

            if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep('add_water'); end
            obj.showNextStepHint();
        end

        function weighWater(obj)
            % 称量水
            [canProceed, ~] = obj.checkOperationValid('weigh_water');
            if ~canProceed, return; end

            totalMass = obj.CupMass + obj.WaterMass;
            obj.BalanceDisplay.Text = sprintf('%.2f g', totalMass);

            % 更新显示
            obj.safeSetText(obj.WaterMassLabel, sprintf('%.2f g', obj.WaterMass));

            obj.updateStatus(sprintf('水的质量: %.2f g', obj.WaterMass));

            obj.BtnWeighWater.Enable = 'off';
            obj.BtnWeighIce.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnWeighIce, 'primary');

            if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep('weigh_water'); end
            obj.showNextStepHint();
        end

        function weighIce(obj)
            % 称量冰块（冰水比约1:3）
            [canProceed, ~] = obj.checkOperationValid('weigh_ice');
            if ~canProceed, return; end

            obj.IceMass = obj.WaterMass / 3 + randn()*5;
            obj.BalanceDisplay.Text = sprintf('%.2f g', obj.IceMass);

            % 更新显示
            obj.safeSetText(obj.IceMassLabel, sprintf('%.2f g', obj.IceMass));

            obj.updateStatus(sprintf('冰的质量: %.2f g (冰水比约1:3)', obj.IceMass));

            obj.BtnWeighIce.Enable = 'off';
            obj.BtnStartRecord.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnStartRecord, 'primary');

            if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep('weigh_ice'); end
            obj.showNextStepHint();
        end

        function startRecording(obj)
            % 开始记录温度 - 显示搅拌器高亮，等待用户点击搅拌器后才真正开始
            [canProceed, ~] = obj.checkOperationValid('start_record');
            if ~canProceed, return; end

            % 进入等待搅拌状态
            obj.WaitingForStir = true;
            obj.ExpStage = obj.STAGE_RECORDING;
            obj.ElapsedTime = 0;
            obj.TimeData = [];
            obj.TempData = [];

            obj.updateStatus('请点击搅拌器开始搅拌，搅拌后将自动开始记录温度');

            obj.BtnStartRecord.Enable = 'off';

            % 显示搅拌器高亮
            obj.updateInteractionHint();

            if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep('start_record'); end
            obj.showNextStepHint();
        end

        function updateRecording(obj)
            % 更新温度记录
            if ~obj.IsRecording
                return;
            end

            % 检查窗口是否仍然有效
            if isempty(obj.Figure) || ~isvalid(obj.Figure)
                obj.stopRecording();
                return;
            end

            % 更新时间（模拟加速：0.5秒 = 0.5分钟）
            obj.ElapsedTime = obj.ElapsedTime + 0.5;
            timeMin = obj.ElapsedTime;

            % 更新计时器显示
            mins = floor(timeMin);
            secs = round((timeMin - mins) * 60);
            obj.TimerDisplay.Text = sprintf('%02d:%02d', mins, secs);

            % 计算当前温度（模拟物理过程）
            if ~obj.IceAdded
                % 投冰前：自然冷却（牛顿冷却）
                dT = -obj.CoolCoefficient * (obj.CurrentTemp - obj.RoomTemp);
                obj.CurrentTemp = obj.CurrentTemp + dT;
            else
                % 投冰后 - 基于热平衡的物理模拟
                timeSinceIce = timeMin - obj.IceAddedTime;

                % 计算理论平衡温度（考虑融解热）
                % 热量守恒: (mc + m1c1)(T_H - T_eq) = ML + Mc(T_eq - 0)
                % 解出: T_eq = [(mc + m1c1)*T_H - M*L] / [(mc + m1c1) + Mc]
                m = obj.WaterMass;
                m1 = obj.CupMass;
                c = obj.c_water;
                c1 = obj.c_cup;
                M = obj.IceMass;
                L = obj.L_standard;  % 使用标准值进行模拟

                heatCapacity = m*c + m1*c1;
                T_eq = (heatCapacity * obj.T_H - M * L) / (heatCapacity + M * c);
                T_eq = max(T_eq, obj.MinEquilibriumTemp);  % 确保不低于最低平衡温度

                if timeSinceIce < 4
                    % 融冰阶段：快速降温到平衡温度
                    % 使用指数衰减模型，确保温度能够接近 T_eq
                    obj.CurrentTemp = T_eq + (obj.T_H - T_eq) * exp(-timeSinceIce / obj.MeltingTau);
                else
                    % 融冰完成后：缓慢向室温回升（牛顿加热）
                    % 从上一时刻的温度开始缓慢回升
                    dT = obj.HeatCoefficient * (obj.RoomTemp - obj.CurrentTemp);
                    obj.CurrentTemp = obj.CurrentTemp + dT;
                end
            end

            % 添加随机噪声
            obj.CurrentTemp = obj.CurrentTemp + randn()*0.05;

            % 更新温度显示
            obj.ThermometerDisplay.Text = sprintf('%.2f °C', obj.CurrentTemp);

            % 每0.5分钟记录一次
            if mod(timeMin, 0.5) < 0.01 || mod(timeMin, 0.5) > 0.49
                obj.TimeData(end+1) = timeMin;
                obj.TempData(end+1) = obj.CurrentTemp;

                % 更新表格
                remark = '';
                if obj.IceAdded && abs(timeMin - obj.IceAddedTime) < 0.1
                    remark = '投入冰块';
                end
                newRow = {sprintf('%.1f', timeMin), sprintf('%.2f', obj.CurrentTemp), remark};
                obj.DataTable.Data = [obj.DataTable.Data; newRow];
                obj.enableExportButton();

                % 更新曲线图
                obj.updateTempCurve();
            end

            % 不再从此处调用drawCalorimeter，由AnimationTimer统一负责重绘

            % 动态更新冰块投放区域的可用性
            if ~obj.IceAdded && obj.ElapsedTime >= obj.IceAddMinTime
                if ~isempty(obj.InteractionMgr)
                    obj.InteractionMgr.setZoneEnabled('ice_zone', true);
                end
            end

            % 检查是否可以结束
            if obj.IceAdded && timeMin - obj.IceAddedTime > 6
                obj.BtnWeighFinal.Enable = 'on';
                ui.StyleConfig.applyButtonStyle(obj.BtnWeighFinal, 'primary');
            end
        end

        function updateTempCurve(obj)
            % 更新温度-时间曲线（增量更新，避免cla全量重绘）
            if isempty(obj.TempTimeAxes) || ~isvalid(obj.TempTimeAxes)
                return;
            end

            if isempty(obj.TimeData)
                return;
            end

            % 增量更新：首次创建图形对象，后续仅更新数据
            if ~obj.CurveInitialized || isempty(obj.CurvePlotHandle) || ~isvalid(obj.CurvePlotHandle)
                % 首次绘制或句柄失效时全量重绘
                cla(obj.TempTimeAxes);
                hold(obj.TempTimeAxes, 'on');

                obj.CurvePlotHandle = plot(obj.TempTimeAxes, obj.TimeData, obj.TempData, 'b-o', ...
                    'LineWidth', 1.5, 'MarkerSize', 4, 'MarkerFaceColor', 'b');

                if obj.IceAdded
                    obj.CurveIceLine = xline(obj.TempTimeAxes, obj.IceAddedTime, 'r--', '投入冰块', ...
                        'LineWidth', 1.5, 'LabelVerticalAlignment', 'bottom');
                end

                obj.CurveRoomLine = yline(obj.TempTimeAxes, obj.RoomTemp, 'g--', ...
                    sprintf('室温 %.1f°C', obj.RoomTemp), ...
                    'LineWidth', 1, 'Alpha', 0.7);

                hold(obj.TempTimeAxes, 'off');
                obj.CurveInitialized = true;
            else
                % 增量更新：仅更新数据
                set(obj.CurvePlotHandle, 'XData', obj.TimeData, 'YData', obj.TempData);

                % 添加投冰标记线（首次投冰时）
                if obj.IceAdded && (isempty(obj.CurveIceLine) || ~isvalid(obj.CurveIceLine))
                    hold(obj.TempTimeAxes, 'on');
                    obj.CurveIceLine = xline(obj.TempTimeAxes, obj.IceAddedTime, 'r--', '投入冰块', ...
                        'LineWidth', 1.5, 'LabelVerticalAlignment', 'bottom');
                    hold(obj.TempTimeAxes, 'off');
                end
            end

            % 动态调整X轴范围
            currentMaxTime = max(15, max(obj.TimeData) + 2);
            xlim(obj.TempTimeAxes, [0, currentMaxTime]);

            % 动态调整Y轴范围
            minT = min(obj.TempData);
            maxT = max(obj.TempData);
            lowerBound = min(5, minT - 2);
            upperBound = max(40, maxT + 2);
            ylim(obj.TempTimeAxes, [lowerBound, upperBound]);
        end

        function addIce(obj)
            % 投入冰块
            [canProceed, ~] = obj.checkOperationValid('add_ice');
            if ~canProceed, return; end

            if obj.ElapsedTime < obj.IceAddMinTime
                uialert(obj.Figure, '请等待至少5分钟后再投入冰块', '提示');
                return;
            end

            obj.IceAdded = true;
            obj.IceAddedTime = obj.ElapsedTime;
            obj.ExpStage = obj.STAGE_ICE_MELTING;

            % 记录投冰时的温度
            obj.T_H = obj.CurrentTemp;

            obj.updateStatus(sprintf('已投入冰块，温度开始下降。投冰温度: %.2f°C', obj.T_H));
            obj.drawCalorimeter();
            obj.updateInteractionHint();

            obj.BtnAddIce.Enable = 'off';

            if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep('add_ice'); end
            obj.showNextStepHint();
        end

        function weighFinal(obj)
            % 最终称量
            [canProceed, ~] = obj.checkOperationValid('weigh_final');
            if ~canProceed, return; end

            obj.stopRecording();

            % 计算最终质量（冰全部融化）
            finalMass = obj.CupMass + obj.WaterMass + obj.IceMass;
            obj.BalanceDisplay.Text = sprintf('%.2f g', finalMass);

            obj.updateStatus('实验数据记录完成，可以进行计算');

            obj.BtnWeighFinal.Enable = 'off';
            obj.BtnCalculate.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnCalculate, 'primary');

            if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep('weigh_final'); end
            obj.showNextStepHint();
        end

        function stopRecording(obj)
            % 停止记录
            obj.IsRecording = false;

            % 停止数据记录计时器
            obj.safeStopTimer(obj.RecordTimer);
            obj.RecordTimer = [];

            % 停止动画计时器
            obj.safeStopTimer(obj.AnimationTimer);
            obj.AnimationTimer = [];

            % 重置搅拌器位置
            if ~isempty(obj.SimulationAxes) && isvalid(obj.SimulationAxes)
                obj.drawCalorimeter(0);
            end
        end

        function calculateResult(obj)
            % 计算融解热
            [canProceed, ~] = obj.checkOperationValid('calculate');
            if ~canProceed, return; end

            % 找到最低温度点
            [minTemp, ~] = min(obj.TempData);
            obj.T_F = minTemp;

            % 使用简化的修正公式计算
            % L = [(mc + m1c1)(T_H - T_F)] / M - c*T_F
            m = obj.WaterMass;
            m1 = obj.CupMass;
            c = obj.c_water;
            c1 = obj.c_cup;
            M = obj.IceMass;

            obj.L_measured = ((m*c + m1*c1) * (obj.T_H - obj.T_F)) / M - c * obj.T_F;

            % 计算相对误差
            relError = abs(obj.L_measured - obj.L_standard) / obj.L_standard * 100;

            % 更新结果显示
            obj.safeSetText(obj.ResultLLabel, sprintf('%.2f cal/g', obj.L_measured));
            obj.safeSetText(obj.ResultErrorLabel, sprintf('%.2f%%', relError));

            % 在曲线上标注关键点
            obj.updateTempCurveWithAnalysis();

            obj.logOperation('计算完成', sprintf('L=%.2f cal/g, 误差=%.2f%%', obj.L_measured, relError));
            obj.updateStatus(sprintf('计算完成！融解热 L = %.2f cal/g，相对误差 = %.2f%%', ...
                obj.L_measured, relError));
            obj.ExpStage = obj.STAGE_CALCULATED;
            obj.updateInteractionHint();

            obj.BtnCalculate.Enable = 'off';

            % 启用完成实验按钮
            obj.BtnComplete.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnComplete, 'success');

            if ~isempty(obj.ExpGuide), obj.ExpGuide.completeStep('calculate'); end
            obj.showNextStepHint();
        end

        function updateTempCurveWithAnalysis(obj)
            % 在曲线上添加分析标注
            cla(obj.TempTimeAxes);
            hold(obj.TempTimeAxes, 'on');

            % 绘制数据曲线
            plot(obj.TempTimeAxes, obj.TimeData, obj.TempData, 'b-o', ...
                'LineWidth', 1.5, 'MarkerSize', 4, 'MarkerFaceColor', 'b');

            % 标记投冰时刻
            xline(obj.TempTimeAxes, obj.IceAddedTime, 'r--', 'LineWidth', 1.5);

            % 标记T_H
            plot(obj.TempTimeAxes, obj.IceAddedTime, obj.T_H, 'rs', ...
                'MarkerSize', 10, 'MarkerFaceColor', 'r');
            text(obj.TempTimeAxes, obj.IceAddedTime + 0.3, obj.T_H, ...
                sprintf('T_H = %.2f°C', obj.T_H), ...
                'FontName', ui.StyleConfig.FontFamily);

            % 标记T_F（最低点）
            [~, minIdx] = min(obj.TempData);
            plot(obj.TempTimeAxes, obj.TimeData(minIdx), obj.T_F, 'gs', ...
                'MarkerSize', 10, 'MarkerFaceColor', 'g');
            text(obj.TempTimeAxes, obj.TimeData(minIdx) + 0.3, obj.T_F, ...
                sprintf('T_F = %.2f°C', obj.T_F), ...
                'FontName', ui.StyleConfig.FontFamily);

            % 室温线
            yline(obj.TempTimeAxes, obj.RoomTemp, 'g--', ...
                sprintf('室温 %.1f°C', obj.RoomTemp), ...
                'LineWidth', 1, 'Alpha', 0.7);

            hold(obj.TempTimeAxes, 'off');

            % 动态调整X轴范围，确保能显示最新数据
            currentMaxTime = 15;
            if ~isempty(obj.TimeData)
                currentMaxTime = max(currentMaxTime, max(obj.TimeData) + 2);
            end
            xlim(obj.TempTimeAxes, [0, currentMaxTime]);

            % 动态调整Y轴范围，确保数据不被截断
            currentYLim = [5, 40];
            if ~isempty(obj.TempData)
                minT = min(obj.TempData);
                maxT = max(obj.TempData);
                % 留出上下边距
                lowerBound = min(5, minT - 2);
                upperBound = max(40, maxT + 2);
                currentYLim = [lowerBound, upperBound];
            end
            ylim(obj.TempTimeAxes, currentYLim);

            xlabel(obj.TempTimeAxes, '时间 t (min)');
            ylabel(obj.TempTimeAxes, '温度 T (°C)');
            title(obj.TempTimeAxes, '温度-时间曲线（含分析）', 'FontName', ui.StyleConfig.FontFamily);
        end

        function resetExperiment(obj)
            % 重置实验
            obj.logOperation('重置实验');
            obj.stopRecording();

            % 重置数据
            obj.CurrentTemp = obj.WaterInitTemp;
            obj.WaterMass = 0;
            obj.IceMass = 0;
            obj.TimeData = [];
            obj.TempData = [];
            obj.ElapsedTime = 0;
            obj.IsRecording = false;
            obj.WaitingForStir = false;
            obj.IceAdded = false;
            obj.IceAddedTime = 0;
            obj.ExpStage = obj.STAGE_INIT;
            obj.T_H = 0;
            obj.T_F = 0;
            obj.L_measured = 0;
            obj.CurveInitialized = false;

            % 重置实验引导系统
            if ~isempty(obj.ExpGuide)
                obj.ExpGuide.reset();
            end

            % 重置基类状态标志（允许重新初始化UI）
            obj.ExperimentCompleted = false;

            % 重置显示
            obj.ThermometerDisplay.Text = sprintf('%.2f °C', obj.CurrentTemp);
            obj.BalanceDisplay.Text = '0.00 g';
            obj.TimerDisplay.Text = '00:00';
            obj.DataTable.Data = {};
            obj.disableExportButton();
            obj.safeSetText(obj.WaterMassLabel, '待测量');
            obj.safeSetText(obj.IceMassLabel, '待测量');
            obj.safeSetText(obj.ResultLLabel, '待计算');
            obj.safeSetText(obj.ResultErrorLabel, '待计算');

            % 重置曲线
            cla(obj.TempTimeAxes);
            xlim(obj.TempTimeAxes, [0, 15]);
            ylim(obj.TempTimeAxes, [5, 40]);
            title(obj.TempTimeAxes, '温度-时间曲线');
            xlabel(obj.TempTimeAxes, '时间 t (min)');
            ylabel(obj.TempTimeAxes, '温度 T (°C)');

            % 重置量热器
            obj.drawCalorimeter();

            % 重置按钮
            obj.BtnWeighCup.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnWeighCup, 'primary');
            obj.BtnPrepareWater.Enable = 'off';
            obj.BtnAddWater.Enable = 'off';
            obj.BtnWeighWater.Enable = 'off';
            obj.BtnWeighIce.Enable = 'off';
            obj.BtnStartRecord.Enable = 'off';
            obj.BtnAddIce.Enable = 'off';
            obj.BtnWeighFinal.Enable = 'off';
            obj.BtnCalculate.Enable = 'off';
            obj.BtnComplete.Enable = 'off';

            % 更新交互状态
            obj.updateInteractionHint();

            obj.updateStatus('实验已重置，请按步骤重新操作');
        end
    end

    methods (Access = protected)
        function onCleanup(obj)
            % 关闭时停止计时器（重写基类方法）
            obj.stopRecording();

            % 清理交互管理器
            if ~isempty(obj.InteractionMgr) && isvalid(obj.InteractionMgr)
                delete(obj.InteractionMgr);
            end
        end
    end

    methods (Access = private)
        function setupInteraction(obj)
            % 设置仪器交互区域
            % 创建交互管理器
            obj.InteractionMgr = ui.InteractionManager(obj.SimulationAxes);

            % 定义可交互的仪器区域 - 仅保留搅拌器和冰块投放区
            % 温度计和量热器不提供点击交互

            % 搅拌器区域（仅覆盖手柄部分）
            obj.InteractionMgr.addZone('stirrer', ...
                [0.55, 0.70, 0.14, 0.25], ...  % 搅拌器手柄部分（盖子以上）
                '点击搅拌', ...
                @(id) obj.onInstrumentClick(id), ...
                'Enabled', false);

            % 冰块投放区域（水面附近）- 仅在投冰阶段启用
            obj.InteractionMgr.addZone('ice_zone', ...
                [0.26, 0.42, 0.12, 0.15], ...  % 水面左侧区域
                '点击投入冰块', ...
                @(id) obj.onInstrumentClick(id), ...
                'Enabled', false);

            % 初始化时显示提示
            obj.updateInteractionHint();
        end

        function onInstrumentClick(obj, instrumentId)
            % 仪器点击处理 - 仅处理搅拌器和冰块投放
            switch instrumentId
                case 'stirrer'
                    % 搅拌操作 - 仅在有水时可用
                    obj.performStirring();

                case 'ice_zone'
                    % 冰块投放操作
                    obj.performIceAction();
            end
        end

        function performStirring(obj)
            % 执行搅拌操作
            if obj.WaitingForStir && ~obj.IsRecording
                % 第一次搅拌 - 启动记录
                obj.WaitingForStir = false;
                obj.IsRecording = true;

                % 创建计时器(数据记录)
                obj.RecordTimer = timer('ExecutionMode', 'fixedRate', ...
                    'Period', 0.5, ...  % 每0.5秒更新一次（模拟加速）
                    'TimerFcn', @(~,~) obj.safeTimerCallback(@obj.updateRecording));
                start(obj.RecordTimer);

                % 创建动画计时器(搅拌视觉效果)
                obj.StirrerPhase = 0;
                % 设为0.1s周期(10fps)，速度较慢
                obj.AnimationTimer = timer('ExecutionMode', 'fixedRate', ...
                    'Period', 0.2, ...  % 5fps（原0.1s，降频减少绘制压力）
                    'TimerFcn', @(~,~) obj.safeTimerCallback(@obj.updateStirrerAnimation));
                start(obj.AnimationTimer);

                % 立即禁用搅拌器交互（只可点击一次）
                if ~isempty(obj.InteractionMgr)
                   obj.InteractionMgr.setZoneEnabled('stirrer', false);
                   % 移除高亮
                   obj.updateInteractionHint();
                end

                obj.updateStatus('搅拌开始，温度记录已启动，每0.5min自动记录');

                % 启用投冰按钮
                obj.BtnAddIce.Enable = 'on';
                ui.StyleConfig.applyButtonStyle(obj.BtnAddIce, 'primary');
            end
        end


        function performIceAction(obj)
            % 冰块投放操作
            if obj.ExpStage == obj.STAGE_RECORDING && obj.IsRecording && ~obj.IceAdded
                if obj.ElapsedTime >= obj.IceAddMinTime
                    obj.addIce();
                else
                    remaining = obj.IceAddMinTime - obj.ElapsedTime;
                    obj.updateStatus(sprintf('请等待 %.1f 分钟后再投入冰块', remaining));
                end
            elseif obj.IceAdded
                obj.updateStatus('冰块已投入，请等待融化完成');
            else
                obj.updateStatus('请先开始温度记录');
            end
        end

        function updateStirrerAnimation(obj)
            % 更新搅拌动画帧
            if isempty(obj.SimulationAxes) || ~isvalid(obj.SimulationAxes)
                return;
            end

            % 更新相位
            obj.StirrerPhase = obj.StirrerPhase + 0.3; % 每次增加约0.3弧度

            % 计算偏移量 (sin波形)
            offset = 0.05 * sin(obj.StirrerPhase);

            % 重绘量热器
            obj.drawCalorimeter(offset);
        end

        function updateInteractionHint(obj)
            % 更新交互提示 - 仅控制搅拌器和冰块区域
            if isempty(obj.InteractionMgr)
                return;
            end

            % 默认全部禁用
            obj.InteractionMgr.setZoneEnabled('stirrer', false);
            obj.InteractionMgr.setZoneEnabled('ice_zone', false);

            % 清除之前的高亮
            obj.InteractionMgr.clearHighlights();

            % 要高亮显示的区域
            highlightZones = {};

            % 等待搅拌开始记录时，搅拌器可用且高亮
            if obj.WaitingForStir
                obj.InteractionMgr.setZoneEnabled('stirrer', true);
                highlightZones{end+1} = 'stirrer';
            end

            % 记录进行中
            if obj.IsRecording
                % 搅拌器已不可用，不需要处理它

                % 如果正在记录且时间满足且未投冰，启用冰块投放区
                if ~obj.IceAdded && obj.ElapsedTime >= obj.IceAddMinTime
                    obj.InteractionMgr.setZoneEnabled('ice_zone', true);
                    highlightZones{end+1} = 'ice_zone';
                end
            end

            % 显示可交互区域的高亮
            if ~isempty(highlightZones)
                obj.InteractionMgr.showHighlights(highlightZones);
            end
        end

        function restoreUIState(obj)
            % 恢复UI组件状态（根据当前实验数据）

            % 恢复温度显示
            if ~isempty(obj.ThermometerDisplay) && isvalid(obj.ThermometerDisplay)
                obj.ThermometerDisplay.Text = sprintf('%.2f °C', obj.CurrentTemp);
            end

            % 恢复天平显示
            if ~isempty(obj.BalanceDisplay) && isvalid(obj.BalanceDisplay)
                if obj.ExpStage >= obj.STAGE_CALCULATED
                    finalMass = obj.CupMass + obj.WaterMass + obj.IceMass;
                    obj.BalanceDisplay.Text = sprintf('%.2f g', finalMass);
                elseif obj.IceMass > 0
                    obj.BalanceDisplay.Text = sprintf('%.2f g', obj.IceMass);
                elseif obj.WaterMass > 0
                    obj.BalanceDisplay.Text = sprintf('%.2f g', obj.CupMass + obj.WaterMass);
                else
                    obj.BalanceDisplay.Text = sprintf('%.2f g', obj.CupMass);
                end
            end

            % 恢复计时器显示
            if ~isempty(obj.TimerDisplay) && isvalid(obj.TimerDisplay)
                mins = floor(obj.ElapsedTime);
                secs = round((obj.ElapsedTime - mins) * 60);
                obj.TimerDisplay.Text = sprintf('%02d:%02d', mins, secs);
            end

            % 恢复参数显示
            if obj.WaterMass > 0
                obj.safeSetText(obj.WaterMassLabel, sprintf('%.2f g', obj.WaterMass));
            end
            if obj.IceMass > 0
                obj.safeSetText(obj.IceMassLabel, sprintf('%.2f g', obj.IceMass));
            end

            % 恢复计算结果显示
            if obj.L_measured > 0
                obj.safeSetText(obj.ResultLLabel, sprintf('%.2f cal/g', obj.L_measured));
                relError = abs(obj.L_measured - obj.L_standard) / obj.L_standard * 100;
                obj.safeSetText(obj.ResultErrorLabel, sprintf('%.2f%%', relError));
            end

            % 恢复数据表格
            if ~isempty(obj.DataTable) && isvalid(obj.DataTable) && ~isempty(obj.TimeData)
                tableData = {};
                for i = 1:length(obj.TimeData)
                    remark = '';
                    if obj.IceAdded && abs(obj.TimeData(i) - obj.IceAddedTime) < 0.1
                        remark = '投入冰块';
                    end
                    tableData{i, 1} = sprintf('%.1f', obj.TimeData(i));
                    tableData{i, 2} = sprintf('%.2f', obj.TempData(i));
                    tableData{i, 3} = remark;
                end
                obj.DataTable.Data = tableData;
            end

            % 恢复温度曲线
            if ~isempty(obj.TimeData)
                if obj.ExpStage >= obj.STAGE_CALCULATED
                    obj.updateTempCurveWithAnalysis();
                else
                    obj.updateTempCurve();
                end
            end

            % 恢复量热器显示
            obj.drawCalorimeter();

            % 恢复按钮状态
            obj.restoreButtonStates();

            % 恢复交互状态
            obj.updateInteractionHint();

            % 更新状态栏
            if obj.ExpStage >= obj.STAGE_CALCULATED
                obj.updateStatus(sprintf('实验已完成！融解热 L = %.2f cal/g', obj.L_measured));
            else
                obj.updateStatus('已返回实验界面');
            end
        end

        function restoreButtonStates(obj)
            % 根据当前实验阶段恢复按钮状态

            % 先禁用所有按钮
            allBtns = {obj.BtnWeighCup, obj.BtnPrepareWater, obj.BtnAddWater, ...
                       obj.BtnWeighWater, obj.BtnWeighIce, obj.BtnStartRecord, ...
                       obj.BtnAddIce, obj.BtnWeighFinal, obj.BtnCalculate, obj.BtnComplete};
            obj.disableAllButtons(allBtns);

            % 根据阶段启用对应按钮
            switch obj.ExpStage
                case obj.STAGE_INIT
                    obj.BtnWeighCup.Enable = 'on';
                    ui.StyleConfig.applyButtonStyle(obj.BtnWeighCup, 'primary');

                case obj.STAGE_WEIGHED
                    % 称量阶段：通过引导系统判断子状态
                    if ~isempty(obj.ExpGuide)
                        [canAdd, ~] = obj.ExpGuide.validateOperation('add_water');
                        if canAdd
                            % prepare_water 已完成，下一步是 add_water
                            obj.BtnAddWater.Enable = 'on';
                            ui.StyleConfig.applyButtonStyle(obj.BtnAddWater, 'primary');
                        else
                            obj.BtnPrepareWater.Enable = 'on';
                            ui.StyleConfig.applyButtonStyle(obj.BtnPrepareWater, 'primary');
                        end
                    else
                        obj.BtnPrepareWater.Enable = 'on';
                        ui.StyleConfig.applyButtonStyle(obj.BtnPrepareWater, 'primary');
                    end

                case obj.STAGE_RECORDING
                    % 记录阶段
                    if ~obj.IsRecording && ~obj.IceAdded
                        obj.BtnStartRecord.Enable = 'on';
                        ui.StyleConfig.applyButtonStyle(obj.BtnStartRecord, 'primary');
                    elseif obj.IsRecording && ~obj.IceAdded
                        obj.BtnAddIce.Enable = 'on';
                        ui.StyleConfig.applyButtonStyle(obj.BtnAddIce, 'primary');
                    end

                case obj.STAGE_ICE_MELTING
                    % 融冰阶段
                    obj.BtnWeighFinal.Enable = 'on';
                    ui.StyleConfig.applyButtonStyle(obj.BtnWeighFinal, 'primary');

                case obj.STAGE_CALCULATED
                    % 实验完成 - 启用完成按钮
                    obj.BtnComplete.Enable = 'on';
                    ui.StyleConfig.applyButtonStyle(obj.BtnComplete, 'success');
            end
        end
    end

    methods (Access = protected)
        function restoreExperimentUI(obj)
            % 从讨论页面返回时恢复实验界面
            % 重新构建UI但保持所有实验数据状态
            obj.CurveInitialized = false;

            % 重新构建UI框架
            obj.setupExperimentUI();

            % 恢复各UI组件的状态
            obj.restoreUIState();
        end

        function summary = getExportSummary(obj)
            % 获取实验结果摘要
            summary = getExportSummary@experiments.ExperimentBase(obj);
            relError = abs(obj.L_measured - obj.L_standard) / obj.L_standard * 100;
            summary = [summary; ...
                {'融解热 L (cal/g)', sprintf('%.2f', obj.L_measured)}; ...
                {'标准值 (cal/g)', sprintf('%.2f', obj.L_standard)}; ...
                {'相对误差', sprintf('%.2f%%', relError)}; ...
                {'修正温度 T_H (°C)', sprintf('%.2f', obj.T_H)}; ...
                {'修正温度 T_F (°C)', sprintf('%.2f', obj.T_F)}];
        end
    end

    methods (Access = private)
        function setupExperimentGuide(obj)
            % 初始化实验引导系统
            obj.ExpGuide = ui.ExperimentGuide(obj.Figure, @(msg) obj.updateStatus(msg));

            % 定义实验步骤序列
            obj.ExpGuide.addStep('weigh_cup', '1. 称量内筒', ...
                '用电子天平称量量热器内筒（含搅拌器）的质量');

            obj.ExpGuide.addStep('prepare_water', '2. 准备热水', ...
                '将水加热至比室温高约16°C', ...
                'Prerequisites', {'weigh_cup'});

            obj.ExpGuide.addStep('add_water', '3. 倒入热水', ...
                '将热水倒入量热器内筒', ...
                'Prerequisites', {'prepare_water'});

            obj.ExpGuide.addStep('weigh_water', '4. 称量水质量', ...
                '再次称量以计算水的质量', ...
                'Prerequisites', {'add_water'});

            obj.ExpGuide.addStep('weigh_ice', '5. 称量冰块', ...
                '称量冰块质量（冰水质量比约1:3）', ...
                'Prerequisites', {'weigh_water'});

            obj.ExpGuide.addStep('start_record', '6. 开始记录', ...
                '开始记录温度，每0.5分钟记录一次', ...
                'Prerequisites', {'weigh_ice'});

            obj.ExpGuide.addStep('add_ice', '7. 投入冰块', ...
                '在第5分钟时投入冰块（需先记录5分钟）', ...
                'Prerequisites', {'start_record'});

            obj.ExpGuide.addStep('weigh_final', '8. 最终称量', ...
                '冰融化后取出内筒称量（需投冰后6分钟）', ...
                'Prerequisites', {'add_ice'});

            obj.ExpGuide.addStep('calculate', '9. 计算融解热', ...
                '根据图解法计算冰的融解热', ...
                'Prerequisites', {'weigh_final'});
        end

    end
end
