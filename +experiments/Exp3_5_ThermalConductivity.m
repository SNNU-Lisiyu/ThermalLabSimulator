classdef Exp3_5_ThermalConductivity < experiments.ExperimentBase
    % Exp3_5_ThermalConductivity 实验3-5 稳态法测量非良导体的导热系数
    % 用稳态平板法测量硬铝、硅橡胶、胶木板等非良导体的导热系数

    properties (Access = private)
        % UI组件
        SimulationAxes      % 仿真显示区域（仪器示意图）
        CoolingAxes         % 冷却曲线区域

        % 仪器显示
        TempDisplay_T1      % 上铜盘温度显示 (加热盘)
        TempDisplay_T2      % 下铜盘温度显示 (散热盘)
        TimerDisplay        % 计时器显示

        % 控制按钮
        BtnMeasureSize      % 测量尺寸
        BtnMeasureMass      % 测量质量
        BtnStartHeating     % 开始加热
        BtnWaitSteady       % 等待稳态
        BtnRecordSteady     % 记录稳态温度
        BtnStartCooling     % 开始冷却记录
        BtnStopCooling      % 停止冷却记录
        BtnCalculate        % 计算导热系数
        BtnComplete         % 完成实验

        % 样品选择
        SampleDropdown      % 样品下拉菜单

        % 参数显示标签（缓存，避免 findobj）
        Lbl_h_A             % 样品厚度值标签
        Lbl_R_A             % 样品半径值标签
        Lbl_h_B             % 下铜盘厚度值标签
        Lbl_R_B             % 下铜盘半径值标签
        Lbl_m_B             % 下铜盘质量值标签
        LblResultLambda     % 导热系数结果标签
        LblResultError      % 相对误差结果标签

        % 实验数据 - 尺寸参数
        h_A = 7.0           % 样品厚度 (mm)
        R_A = 65.0          % 样品半径 (mm)
        h_B = 10.0          % 下铜盘厚度 (mm)
        R_B = 65.0          % 下铜盘半径 (mm)
        m_B = 0.810         % 下铜盘质量 (kg)

        % 温度数据
        T1 = 25             % 上铜盘温度 (°C) - 加热盘
        T2 = 25             % 下铜盘温度 (°C) - 散热盘
        T_set = 80          % 设定温度 (°C)
        RoomTemp = 20       % 室温 (°C)

        % 冷却曲线数据
        CoolingTime = []    % 冷却时间 (s)
        CoolingTemp = []    % 冷却温度 (°C)

        % 稳态数据
        T1_steady = 0       % 稳态时上铜盘温度
        T2_steady = 0       % 稳态时下铜盘温度

        % 计时器
        HeatingTimer        % 加热计时器
        CoolingTimer        % 冷却计时器
        ElapsedTime = 0     % 已过时间 (s)
        IsHeating = false   % 是否正在加热
        IsCooling = false   % 是否正在冷却记录

        % 样品参数（不同材料）
        SampleType = '硅橡胶'
        SampleList = {'硅橡胶', '胶木板', '硬铝片'}

        % 计算结果
        dT_dt = 0           % 冷却速率 (°C/s) 在T2处
        Lambda = 0          % 测得导热系数 W/(m·K)
        t_A = 0             % 图解法求得的 t_A
        t_B = 0             % 图解法求得的 t_B
        T_A = 0             % 对应的 T_A
        T_B = 0             % 对应的 T_B

        % 缓存的曲线图句柄（增量更新）
        CoolingPlotHandle       % 冷却曲线 plot 句柄
        CoolingSteadyLine       % T2稳态参考线
        CoolingCurveInitialized = false

        % 动态图形元素句柄（用于增量更新，避免全量重绘）
        HdlUpperDisk            % 上铜盘主体
        HdlUpperDiskSide        % 上铜盘侧面
        HdlLowerDisk            % 下铜盘主体
        HdlLowerDiskSide        % 下铜盘侧面
        HdlT1Text               % T1温度文本
        HdlT2Text               % T2温度文本
    end

    properties (Constant)
        % 物理常数
        c_copper = 385      % 铜的比热容 J/(kg·K) = 3.805×10^2 J/(kg·°C)

        % 各材料的参考导热系数 W/(m·K) - 索引对应SampleList
        % 注：本实验适用于非良导体，硬铝片为薄片样品（导热系数已修正）
        Lambda_ref_values = [0.25, 0.20, 2.5]  % 硅橡胶, 胶木板, 硬铝片

        % 模拟参数
        Tau1 = 30           % 上铜盘加热时间常数
        Tau2 = 50           % 下铜盘加热时间常数

        % 实验阶段常量
        STAGE_INIT = 0
        STAGE_MEASURED = 1
        STAGE_HEATING = 2
        STAGE_STEADY = 3
        STAGE_COOLING = 4
        STAGE_COOL_DONE = 5
        STAGE_CALCULATED = 6
    end

    methods (Access = public)
        function obj = Exp3_5_ThermalConductivity()
            % 构造函数
            obj@experiments.ExperimentBase();

            % 设置实验基本信息
            obj.ExpNumber = '实验3-5';
            obj.ExpTitle = '稳态法测量非良导体的导热系数';

            % 实验目的
            obj.ExpPurpose = ['1. 了解热传导的物理过程' newline ...
                '2. 掌握稳态平板法测非良导体导热系数的原理与方法' newline ...
                '3. 学习用作图法求冷却速率'];

            % 实验仪器
            obj.ExpInstruments = ['导热系数测量仪(YBF-2型)、保温杯、冰、游标卡尺、' ...
                '测试样品(硬铝、硅橡胶、胶木板)'];

            % 实验原理
            obj.ExpPrinciple = [
                '【傅里叶热传导定律】' newline ...
                '当物体内部有温度梯度存在时，就有热量从高温传递到低温，这种现象称为热传导。' newline ...
                '傅里叶指出，在dt时间内通过dS面积的热量dQ，正比于物体内的温度梯度dT/dz：' newline ...
                '  dQ/dt = -λ(dT/dz)dS    式(3-5-1)' newline ...
                '其中λ为导热系数，单位是W/(m·K)，"-"号表示热量由高温区域传向低温区域。' newline newline ...
                '【稳态平板法原理】' newline ...
                '用稳态平板法测量非良导体的导热系数时，在上、下铜盘间放入被测材料，构成三明治结构。' newline ...
                '上铜盘外接电源作为热源，样品侧面近似绝热。当上、下铜盘温度保持不变时，系统达到稳态。' newline newline ...
                '此时测量上、下铜盘的温度分别为T₁和T₂，样品的厚度为h_A，则样品内部的温度梯度为：' newline ...
                '  dT/dz = (T₁ - T₂)/h_A    式(3-5-2)' newline newline ...
                '由此可得样品的传热速率为：' newline ...
                '  dQ/dt = -λ·(T₁ - T₂)/h_A·S_A    式(3-5-3)' newline ...
                '其中S_A = πR_A²为样品表面的面积。' newline newline ...
                '【冷却速率的测量】' newline ...
                '在稳态传热条件下，上铜盘的加热速率等于下铜盘的散热速率。' newline ...
                '由于样品不断向散热铜盘传热，下铜盘的冷却速率无法直接测量。' newline ...
                '通过测量下铜盘单独在空气中的冷却速率来间接求得。' newline newline ...
                '记录下铜盘在T₂附近的自然冷却曲线，用作图法求出在T₂点的冷却速率：' newline ...
                '  dT''/dt|_{T₂} = (T_A - T_B)/(t_A - t_B)    式(3-5-6)' newline newline ...
                '考虑到散热面积的不同，有：' newline ...
                '  dT/dt|_{T₂} = (R_B + 2h_B)/(2(R_B + h_B))·dT''/dt|_{T₂}    式(3-5-5)' newline newline ...
                '【导热系数计算公式】' newline ...
                '联立上述公式，可得导热系数λ的计算公式：' newline ...
                '  λ = (m_B·c_铜·h_A·(R_B + 2h_B))/(2πR_A²(T₁ - T₂)(R_B + h_B))' newline ...
                '       · (T_A - T_B)/(t_A - t_B)    式(3-5-7)'];

            % 实验内容
            obj.ExpContent = [
                '1. 实验准备及注意事项' newline ...
                '   实验前保证电源插座良好接地；电路连接好后才能打开电源；严禁带电插拔电缆。' newline newline ...
                '2. 测量尺寸和质量' newline ...
                '   用游标卡尺测量样品厚度h_A、直径2R_A、下铜盘厚度h_B、直径2R_B。' newline ...
                '   用电子天平测量下铜盘质量m_B。' newline newline ...
                '3. 建立稳恒态' newline ...
                '   ① 把样品安装在加热盘和散热盘中间，将热电偶分别插入铜盘圆孔里。' newline ...
                '   ② 打开电源，设定加热盘温度为80℃。' newline ...
                '   ③ 观察上、下盘温度变化，若每3min变化ΔT≤0.1℃，则达到稳恒态。' newline ...
                '   ④ 记录此时加热盘和散热盘的温度T₁和T₂。' newline newline ...
                '4. 下铜盘的自然冷却速率' newline ...
                '   读取稳定时的T₁和T₂后，拿走样品，让散热盘与加热盘下表面接触，' newline ...
                '   加热下铜盘使其温度比T₂高8℃左右，再移去加热盘。' newline ...
                '   让下铜盘自然冷却，每隔30s记录温度，直到比T₂低8℃左右。' newline ...
                '   根据数据作冷却曲线，用作图法求T₂附近的冷却速率。' newline newline ...
                '5. 计算导热系数' newline ...
                '   利用测量数据，根据公式(3-5-7)求出待测材料的导热系数。'];

            % 思考讨论
            obj.ExpQuestions = {
                '本实验产生误差的来源有哪些？', ...
                ['本实验误差来源主要包括：' newline ...
                '1. 温度测量误差：热电偶的测量精度、接触不良等' newline ...
                '2. 尺寸测量误差：游标卡尺的精度限制' newline ...
                '3. 稳态判断误差：实际可能未完全达到稳态' newline ...
                '4. 侧面散热：样品侧面并非完全绝热，存在热量损失' newline ...
                '5. 接触热阻：样品与铜盘之间存在接触热阻' newline ...
                '6. 冷却速率测定误差：作图法的精度有限' newline ...
                '7. 环境温度波动：室温变化会影响散热条件'];

                '用非良导体导热系数实验仪能否测量良导体的导热系数？', ...
                ['理论上不适合测量良导体，原因如下：' newline ...
                '1. 良导体导热系数大，热量传递快，难以建立明显的温度梯度' newline ...
                '2. 上下铜盘温差(T₁-T₂)会非常小，测量相对误差大' newline ...
                '3. 达到稳态的时间会很长' newline ...
                '4. 测量精度要求更高' newline ...
                '对于良导体，通常采用动态法或其他专门方法测量。'];
            };

            % 初始化温度为室温
            obj.T1 = obj.RoomTemp;
            obj.T2 = obj.RoomTemp;
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
                title(obj.SimulationAxes, '导热系数测量仪示意图', ...
                    'FontName', ui.StyleConfig.FontFamily, 'Color', ui.StyleConfig.TextPrimary);

                % 冷却曲线区域
                obj.CoolingAxes = uiaxes(plotGrid);
                obj.CoolingAxes.Layout.Row = 1;
                obj.CoolingAxes.Layout.Column = 2;
                ui.StyleConfig.applyAxesStyle(obj.CoolingAxes);
                title(obj.CoolingAxes, '下铜盘自然冷却曲线', ...
                    'FontName', ui.StyleConfig.FontFamily, 'Color', ui.StyleConfig.TextPrimary);
                xlabel(obj.CoolingAxes, '时间 t (s)');
                ylabel(obj.CoolingAxes, '温度 T (°C)');
                xlim(obj.CoolingAxes, [0, 600]);
                ylim(obj.CoolingAxes, [20, 60]);

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
                    'RowHeight', {'1x', 40}, ...
                    'Padding', [5, 5, 5, 5], ...
                    'RowSpacing', 5, 'ColumnSpacing', 10, ...
                    'BackgroundColor', ui.StyleConfig.PanelColor);

                % T1
                obj.TempDisplay_T1 = obj.createInstrumentDisplay(instGrid, '上盘温度 T₁', ...
                    sprintf('%.1f °C', obj.T1), ui.StyleConfig.ErrorColor, 1, 1);

                % T2
                obj.TempDisplay_T2 = obj.createInstrumentDisplay(instGrid, '下盘温度 T₂', ...
                    sprintf('%.1f °C', obj.T2), ui.StyleConfig.SuccessColor, 1, 2);

                % Timer
                obj.TimerDisplay = obj.createInstrumentDisplay(instGrid, '计时', ...
                    '00:00', ui.StyleConfig.PrimaryColor, 1, 3);

                % Row 2: Misc info
                % Room/Set Temp Group
                miscInfoGrid = uigridlayout(instGrid, [2, 1], 'Padding', [0,0,0,0], 'RowSpacing', 0, ...
                     'BackgroundColor', ui.StyleConfig.PanelColor);
                miscInfoGrid.Layout.Row = 2; miscInfoGrid.Layout.Column = 1;
                obj.createSimpleLabel(miscInfoGrid, sprintf('室温: %.1f°C', obj.RoomTemp), 'center', ui.StyleConfig.TextSecondary, 1, 1);
                obj.createSimpleLabel(miscInfoGrid, sprintf('设定温度: %.1f°C', obj.T_set), 'center', ui.StyleConfig.TextSecondary, 2, 1);

                % Sample Selector
                sampleGroup = uigridlayout(instGrid, [1, 2], 'Padding', [0,0,0,0], 'ColumnWidth', {'fit', '1x'}, ...
                    'BackgroundColor', ui.StyleConfig.PanelColor);
                sampleGroup.Layout.Row = 2; sampleGroup.Layout.Column = 2;

                % Explicit variable assignment using helper to prevent indexing ambiguity
                lblSample = obj.createSimpleLabel(sampleGroup, '样品:', 'right', ui.StyleConfig.TextPrimary, 1, 1);
                lblSample.FontWeight = 'bold';

                obj.SampleDropdown = uidropdown(sampleGroup, ...
                    'Items', obj.SampleList, ...
                    'Value', obj.SampleType, ...
                    'ValueChangedFcn', @(dd,~) obj.onSampleChanged(dd.Value));


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
                obj.BtnMeasureSize = obj.createExpButton(btnGrid, '1.测量尺寸', @(~,~) obj.measureSize(), 'primary', 1, 1);
                obj.BtnMeasureMass = obj.createExpButton(btnGrid, '2.测量质量', @(~,~) obj.measureMass(), 'disabled', 1, 2);
                obj.BtnStartHeating = obj.createExpButton(btnGrid, '3.开始加热', @(~,~) obj.startHeating(), 'disabled', 1, 3);
                obj.BtnWaitSteady = obj.createExpButton(btnGrid, '4.等待稳态', @(~,~) obj.waitSteadyState(), 'disabled', 1, 4);

                % Row 2
                obj.BtnRecordSteady = obj.createExpButton(btnGrid, '5.记录稳态', @(~,~) obj.recordSteadyState(), 'disabled', 2, 1);
                obj.BtnStartCooling = obj.createExpButton(btnGrid, '6.开始冷却', @(~,~) obj.startCooling(), 'disabled', 2, 2);
                obj.BtnStopCooling = obj.createExpButton(btnGrid, '7.停止记录', @(~,~) obj.stopCooling(), 'disabled', 2, 3);
                obj.BtnCalculate = obj.createExpButton(btnGrid, '8.计算导热系数', @(~,~) obj.calculateResult(), 'disabled', 2, 4);

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
                titleParam = ui.StyleConfig.createPanelTitle(controlGrid, '实验参数');
                titleParam.Layout.Row = 1;
                titleParam.Layout.Column = [1, 2];

                paramLabels = {'样品厚度 h_A:', '样品半径 R_A:', ...
                    '下铜盘厚度 h_B:', '下铜盘半径 R_B:', '下铜盘质量 m_B:', ...
                    '铜比热容 c_铜:'};
                paramValues = {'待测量', '待测量', '待测量', '待测量', '待测量', ...
                    sprintf('%d J/(kg·K)', obj.c_copper)};

                % 用临时 cell 收集参数值标签，再分配给属性
                paramValueHandles = cell(1, length(paramLabels));
                for i = 1:length(paramLabels)
                    l = ui.StyleConfig.createParamLabel(controlGrid, paramLabels{i});
                    l.Layout.Row = i + 1;
                    l.Layout.Column = 1;

                    v = ui.StyleConfig.createParamValue(controlGrid, paramValues{i});
                    v.Layout.Row = i + 1;
                    v.Layout.Column = 2;
                    paramValueHandles{i} = v;
                end
                obj.Lbl_h_A = paramValueHandles{1};
                obj.Lbl_R_A = paramValueHandles{2};
                obj.Lbl_h_B = paramValueHandles{3};
                obj.Lbl_R_B = paramValueHandles{4};
                obj.Lbl_m_B = paramValueHandles{5};

                % ---------- 实验数据面板 (右下) ----------
                dataPanelGrid = ui.StyleConfig.createDataPanelGrid(obj.DataPanel, '1x', 100);

                % Title
                titleData = ui.StyleConfig.createPanelTitle(dataPanelGrid, '实验数据');
                titleData.Layout.Row = 1;

                % 数据表格
                obj.DataTable = ui.StyleConfig.createDataTable(dataPanelGrid, ...
                    {'时间(s)', '温度(°C)'}, {100, 100});
                obj.DataTable.Layout.Row = 2;
                obj.DataTable.Data = {};
                obj.DataTable.RowName = {};

                % 结果区域
                resultGrid = ui.StyleConfig.createResultGrid(dataPanelGrid, 3);
                resultGrid.Layout.Row = 3;

                % Title
                titleRes = ui.StyleConfig.createResultLabel(resultGrid, '计算结果');
                titleRes.Layout.Row = 1;
                titleRes.Layout.Column = [1, 2];
                titleRes.FontWeight = 'bold';
                titleRes.HorizontalAlignment = 'center';

                % Lambda
                lbl1 = ui.StyleConfig.createResultLabel(resultGrid, '导热系数 λ =');
                lbl1.Layout.Row = 2;
                lbl1.Layout.Column = 1;
                lambdaVal = ui.StyleConfig.createResultValue(resultGrid, '待计算');
                lambdaVal.Layout.Row = 2;
                lambdaVal.Layout.Column = 2;
                obj.LblResultLambda = lambdaVal;

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
                utils.Logger.logError(ME, 'Exp3_5_ThermalConductivity.setupExperimentUI');
                uialert(obj.Figure, sprintf('UI初始化失败:\n%s\nFile: %s\nLine: %d', ...
                    ME.message, ME.stack(1).name, ME.stack(1).line), '程序错误');
            end
        end

        function drawApparatus(obj)
            % 绘制导热系数测量仪示意图
            ax = obj.SimulationAxes;
            cla(ax);
            hold(ax, 'on');

            % 背景 - 浅灰渐变效果
            ax.Color = [0.95, 0.96, 0.97];

            % === 颜色定义 ===
            copperColor = [0.85, 0.55, 0.25];    % 铜色
            copperDark = [0.6, 0.35, 0.15];      % 铜色深
            copperLight = [0.95, 0.75, 0.45];    % 铜色亮
            sampleColor = [0.75, 0.78, 0.85];    % 样品颜色
            steelColor = [0.7, 0.72, 0.75];      % 钢色
            steelDark = [0.5, 0.52, 0.55];       % 钢色深

            % === 根据温度计算动态颜色 ===
            % 上铜盘（加热盘）
            if obj.T1 > 50
                t1_ratio = min(1, (obj.T1 - 50) / 50);
                upperColor = copperColor .* (1 - t1_ratio * 0.4) + [1, 0.35, 0.1] .* t1_ratio * 0.5;
                upperColorDark = copperDark .* (1 - t1_ratio * 0.3) + [0.7, 0.2, 0.05] .* t1_ratio * 0.4;
            else
                upperColor = copperColor;
                upperColorDark = copperDark;
            end

            % 下铜盘（散热盘）
            if obj.T2 > 35
                t2_ratio = min(1, (obj.T2 - 35) / 35);
                lowerColor = copperColor .* (1 - t2_ratio * 0.25) + [0.95, 0.6, 0.35] .* t2_ratio * 0.3;
                lowerColorDark = copperDark .* (1 - t2_ratio * 0.2) + [0.65, 0.35, 0.15] .* t2_ratio * 0.25;
            else
                lowerColor = copperColor;
                lowerColorDark = copperDark;
            end

            % === 绘制仪器主体结构 ===

            % --- 支撑立柱（左右两侧）---
            % 左立柱
            rectangle(ax, 'Position', [0.12, 0.15, 0.06, 0.72], ...
                'Curvature', [0.1, 0.02], ...
                'FaceColor', steelColor, ...
                'EdgeColor', steelDark, ...
                'LineWidth', 1.5);
            % 左立柱高光
            rectangle(ax, 'Position', [0.125, 0.15, 0.015, 0.72], ...
                'Curvature', [0.1, 0.02], ...
                'FaceColor', [0.85, 0.87, 0.9], ...
                'EdgeColor', 'none');

            % 右立柱
            rectangle(ax, 'Position', [0.82, 0.15, 0.06, 0.72], ...
                'Curvature', [0.1, 0.02], ...
                'FaceColor', steelColor, ...
                'EdgeColor', steelDark, ...
                'LineWidth', 1.5);
            % 右立柱高光
            rectangle(ax, 'Position', [0.825, 0.15, 0.015, 0.72], ...
                'Curvature', [0.1, 0.02], ...
                'FaceColor', [0.85, 0.87, 0.9], ...
                'EdgeColor', 'none');

            % --- 底座 ---
            rectangle(ax, 'Position', [0.08, 0.08, 0.84, 0.09], ...
                'Curvature', [0.03, 0.1], ...
                'FaceColor', [0.35, 0.38, 0.42], ...
                'EdgeColor', [0.2, 0.22, 0.25], ...
                'LineWidth', 2);
            % 底座顶部高光
            rectangle(ax, 'Position', [0.08, 0.155, 0.84, 0.015], ...
                'Curvature', [0.03, 0.5], ...
                'FaceColor', [0.5, 0.52, 0.55], ...
                'EdgeColor', 'none');

            % --- 顶部横梁 ---
            rectangle(ax, 'Position', [0.1, 0.84, 0.8, 0.05], ...
                'Curvature', [0.02, 0.1], ...
                'FaceColor', steelColor, ...
                'EdgeColor', steelDark, ...
                'LineWidth', 1.5);

            % === 加热盘（上铜盘 A）===
            % 主体 - 3D效果
            % 侧面（厚度）
            obj.HdlUpperDiskSide = rectangle(ax, 'Position', [0.22, 0.66, 0.56, 0.03], ...
                'Curvature', [0.02, 0.1], ...
                'FaceColor', upperColorDark, ...
                'EdgeColor', 'none');
            % 顶面
            obj.HdlUpperDisk = rectangle(ax, 'Position', [0.22, 0.69, 0.56, 0.11], ...
                'Curvature', [0.03, 0.08], ...
                'FaceColor', upperColor, ...
                'EdgeColor', upperColorDark, ...
                'LineWidth', 2);
            % 高光
            rectangle(ax, 'Position', [0.25, 0.74, 0.35, 0.04], ...
                'Curvature', [0.5, 0.5], ...
                'FaceColor', copperLight .* [1, 0.95, 0.9], ...
                'EdgeColor', 'none');

            % 加热盘标签
            text(ax, 0.5, 0.745, sprintf('加热盘 A'), ...
                'HorizontalAlignment', 'center', ...
                'FontName', ui.StyleConfig.FontFamily, ...
                'FontSize', 9, 'Color', [0.3, 0.15, 0.05], 'FontWeight', 'bold');

            % 温度T1指示
            obj.HdlT1Text = text(ax, 0.72, 0.745, sprintf('T₁=%.1f°C', obj.T1), ...
                'HorizontalAlignment', 'center', ...
                'FontName', ui.StyleConfig.FontFamily, ...
                'FontSize', 8, 'Color', [0.5, 0.1, 0.05], 'FontWeight', 'bold');

            % === 样品盘 ===
            % 侧面
            rectangle(ax, 'Position', [0.22, 0.52, 0.56, 0.02], ...
                'Curvature', [0.02, 0.1], ...
                'FaceColor', sampleColor .* 0.85, ...
                'EdgeColor', 'none');
            % 主体
            rectangle(ax, 'Position', [0.22, 0.54, 0.56, 0.12], ...
                'Curvature', [0.02, 0.05], ...
                'FaceColor', sampleColor, ...
                'EdgeColor', [0.5, 0.52, 0.58], ...
                'LineWidth', 1.5);
            % 样品纹理线条
            for i = 1:4
                y_line = 0.555 + i * 0.022;
                plot(ax, [0.26, 0.74], [y_line, y_line], ...
                    'Color', [0.65, 0.68, 0.75], 'LineWidth', 0.5, 'LineStyle', ':');
            end
            % 样品标签
            text(ax, 0.5, 0.60, sprintf('样品: %s', obj.SampleType), ...
                'HorizontalAlignment', 'center', ...
                'FontName', ui.StyleConfig.FontFamily, ...
                'FontSize', 9, 'Color', [0.25, 0.28, 0.35], 'FontWeight', 'bold');

            % === 散热盘（下铜盘 B）===
            % 侧面
            obj.HdlLowerDiskSide = rectangle(ax, 'Position', [0.22, 0.35, 0.56, 0.03], ...
                'Curvature', [0.02, 0.1], ...
                'FaceColor', lowerColorDark, ...
                'EdgeColor', 'none');
            % 顶面
            obj.HdlLowerDisk = rectangle(ax, 'Position', [0.22, 0.38, 0.56, 0.14], ...
                'Curvature', [0.03, 0.08], ...
                'FaceColor', lowerColor, ...
                'EdgeColor', lowerColorDark, ...
                'LineWidth', 2);
            % 高光
            rectangle(ax, 'Position', [0.25, 0.44, 0.35, 0.04], ...
                'Curvature', [0.5, 0.5], ...
                'FaceColor', copperLight, ...
                'EdgeColor', 'none');

            % 散热盘标签
            text(ax, 0.5, 0.455, sprintf('散热盘 B'), ...
                'HorizontalAlignment', 'center', ...
                'FontName', ui.StyleConfig.FontFamily, ...
                'FontSize', 9, 'Color', [0.3, 0.15, 0.05], 'FontWeight', 'bold');

            % 温度T2指示
            obj.HdlT2Text = text(ax, 0.72, 0.455, sprintf('T₂=%.1f°C', obj.T2), ...
                'HorizontalAlignment', 'center', ...
                'FontName', ui.StyleConfig.FontFamily, ...
                'FontSize', 8, 'Color', [0.5, 0.25, 0.1], 'FontWeight', 'bold');

            % === 热电偶探头 ===
            % T1热电偶（插入加热盘侧面）
            plot(ax, [0.78, 0.88], [0.72, 0.72], 'Color', [0.2, 0.5, 0.8], 'LineWidth', 2.5);
            plot(ax, 0.78, 0.72, 'o', 'MarkerSize', 5, 'MarkerFaceColor', [0.9, 0.3, 0.2], ...
                'MarkerEdgeColor', [0.6, 0.2, 0.1]);

            % T2热电偶（插入散热盘侧面）
            plot(ax, [0.78, 0.88], [0.43, 0.43], 'Color', [0.2, 0.5, 0.8], 'LineWidth', 2.5);
            plot(ax, 0.78, 0.43, 'o', 'MarkerSize', 5, 'MarkerFaceColor', [0.2, 0.6, 0.9], ...
                'MarkerEdgeColor', [0.1, 0.4, 0.6]);

            % === 热传导方向箭头 ===
            if obj.T1 > obj.T2 + 2
                % 绘制多条热流线
                for i = 1:3
                    x_pos = 0.35 + (i-1) * 0.15;
                    % 波浪形热流线
                    y_pts = linspace(0.67, 0.52, 20);
                    x_wave = x_pos + 0.01 * sin(linspace(0, 2*pi, 20));
                    plot(ax, x_wave, y_pts, 'Color', [0.9, 0.4, 0.2, 0.6], 'LineWidth', 1.5);
                end
                % 主箭头
                quiver(ax, 0.08, 0.65, 0, -0.18, 0, ...
                    'Color', [0.85, 0.25, 0.15], 'LineWidth', 2.5, ...
                    'MaxHeadSize', 1.2);
                text(ax, 0.05, 0.56, 'Q', ...
                    'FontName', ui.StyleConfig.FontFamily, ...
                    'FontSize', 10, 'Color', [0.85, 0.25, 0.15], 'FontWeight', 'bold');
            end

            % === 尺寸标注 ===
            annotColor = [0.3, 0.3, 0.5];

            % h_A 样品厚度标注（左侧）
            plot(ax, [0.19, 0.21], [0.54, 0.54], 'Color', annotColor, 'LineWidth', 1);
            plot(ax, [0.19, 0.21], [0.66, 0.66], 'Color', annotColor, 'LineWidth', 1);
            plot(ax, [0.20, 0.20], [0.54, 0.66], 'Color', annotColor, 'LineWidth', 1);
            plot(ax, [0.195, 0.205], [0.58, 0.58], 'Color', annotColor, 'LineWidth', 1);
            plot(ax, [0.195, 0.205], [0.62, 0.62], 'Color', annotColor, 'LineWidth', 1);
            text(ax, 0.195, 0.60, 'h_A', ...
                'HorizontalAlignment', 'right', ...
                'FontName', ui.StyleConfig.FontFamily, 'FontSize', 8, ...
                'Color', annotColor, 'FontAngle', 'italic');

            % R_A/R_B 半径标注（底部）
            plot(ax, [0.22, 0.78], [0.33, 0.33], 'Color', annotColor, 'LineWidth', 1);
            plot(ax, [0.22, 0.22], [0.32, 0.34], 'Color', annotColor, 'LineWidth', 1);
            plot(ax, [0.78, 0.78], [0.32, 0.34], 'Color', annotColor, 'LineWidth', 1);
            text(ax, 0.5, 0.31, '2R', ...
                'HorizontalAlignment', 'center', ...
                'FontName', ui.StyleConfig.FontFamily, 'FontSize', 8, ...
                'Color', annotColor, 'FontAngle', 'italic');

            % === 状态显示 ===
            if obj.IsHeating
                statusText = '● 加热中...';
                statusColor = [0.9, 0.3, 0.2];
            elseif obj.IsCooling
                statusText = '● 冷却记录中...';
                statusColor = [0.2, 0.6, 0.9];
            elseif obj.ExpStage >= obj.STAGE_STEADY
                statusText = '✓ 已达稳态';
                statusColor = [0.2, 0.7, 0.3];
            else
                statusText = '○ 待命';
                statusColor = [0.5, 0.5, 0.6];
            end

            % 状态背景框
            % 用背景色混合模拟透明度（alpha=0.15）
            bgColor = ax.Color;
            statusBgColor = statusColor * 0.15 + bgColor * 0.85;
            rectangle(ax, 'Position', [0.3, 0.91, 0.4, 0.06], ...
                'Curvature', [0.3, 0.5], ...
                'FaceColor', statusBgColor, ...
                'EdgeColor', statusColor, ...
                'LineWidth', 1.5);
            text(ax, 0.5, 0.94, statusText, ...
                'HorizontalAlignment', 'center', ...
                'FontName', ui.StyleConfig.FontFamily, ...
                'FontSize', 10, 'Color', statusColor, 'FontWeight', 'bold');

            % === 图例说明 ===
            % 小图例框
            % 用背景色混合模拟透明度（alpha=0.8）
            legendBgColor = [1, 1, 1] * 0.8 + bgColor * 0.2;
            rectangle(ax, 'Position', [0.02, 0.18, 0.08, 0.12], ...
                'Curvature', [0.1, 0.1], ...
                'FaceColor', legendBgColor, ...
                'EdgeColor', [0.7, 0.7, 0.7], ...
                'LineWidth', 0.5);
            % T1图例
            plot(ax, 0.04, 0.27, 'o', 'MarkerSize', 4, 'MarkerFaceColor', [0.9, 0.3, 0.2], ...
                'MarkerEdgeColor', [0.6, 0.2, 0.1]);
            text(ax, 0.055, 0.27, 'T₁', 'FontSize', 7, 'Color', [0.4, 0.4, 0.4]);
            % T2图例
            plot(ax, 0.04, 0.21, 'o', 'MarkerSize', 4, 'MarkerFaceColor', [0.2, 0.6, 0.9], ...
                'MarkerEdgeColor', [0.1, 0.4, 0.6]);
            text(ax, 0.055, 0.21, 'T₂', 'FontSize', 7, 'Color', [0.4, 0.4, 0.4]);

            hold(ax, 'off');
            xlim(ax, [0, 1]);
            ylim(ax, [0.05, 1]);
            ax.XTick = [];
            ax.YTick = [];
        end

        function onSampleChanged(obj, sampleName)
            % 样品选择改变
            obj.SampleType = sampleName;
            obj.drawApparatus();
            obj.updateStatus(sprintf('已选择样品: %s', sampleName));
        end

        function measureSize(obj)
            % 测量尺寸（模拟游标卡尺测量）
            [canProceed, ~] = obj.checkOperationValid('measure_size');
            if ~canProceed, return; end

            % 添加随机测量误差
            obj.h_A = 7.0 + randn() * 0.05;   % mm
            obj.R_A = 65.0 + randn() * 0.1;   % mm
            obj.h_B = 10.0 + randn() * 0.05;  % mm
            obj.R_B = 65.0 + randn() * 0.1;   % mm

            % 更新显示
            obj.safeSetText(obj.Lbl_h_A, sprintf('%.2f mm', obj.h_A));
            obj.safeSetText(obj.Lbl_R_A, sprintf('%.2f mm', obj.R_A));
            obj.safeSetText(obj.Lbl_h_B, sprintf('%.2f mm', obj.h_B));
            obj.safeSetText(obj.Lbl_R_B, sprintf('%.2f mm', obj.R_B));

            obj.ExpStage = obj.STAGE_MEASURED;
            obj.updateStatus(sprintf('尺寸测量完成: h_A=%.2fmm, R_A=%.2fmm, h_B=%.2fmm, R_B=%.2fmm', ...
                obj.h_A, obj.R_A, obj.h_B, obj.R_B));

            obj.BtnMeasureSize.Enable = 'off';
            obj.BtnMeasureMass.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnMeasureMass, 'primary');

            obj.ExpGuide.completeStep('measure_size');
            obj.showNextStepHint();
        end

        function measureMass(obj)
            % 测量质量（模拟电子天平）
            [canProceed, ~] = obj.checkOperationValid('measure_mass');
            if ~canProceed, return; end

            obj.m_B = 0.810 + randn() * 0.002;  % kg

            m_B_lbl = obj.Lbl_m_B;
            if ~isempty(m_B_lbl) && isvalid(m_B_lbl), m_B_lbl.Text = sprintf('%.3f kg', obj.m_B); end

            obj.updateStatus(sprintf('质量测量完成: m_B = %.3f kg', obj.m_B));

            obj.BtnMeasureMass.Enable = 'off';
            obj.BtnStartHeating.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnStartHeating, 'primary');

            obj.ExpGuide.completeStep('measure_mass');
            obj.ExpGuide.completeStep('select_sample');
            obj.showNextStepHint();
        end

        function updateDynamicDisplay(obj)
            % 增量更新动态元素（铜盘颜色和温度文本），避免全量重绘
            % 检查句柄是否有效
            if isempty(obj.HdlUpperDisk) || isempty(obj.HdlT1Text) || ...
               ~isvalid(obj.HdlUpperDisk) || ~isvalid(obj.HdlT1Text)
                obj.drawApparatus();  % 回退到全量重绘
                return;
            end

            % 颜色常量
            copperColor = [0.85, 0.55, 0.25];
            copperDark = [0.6, 0.35, 0.15];

            % 上铜盘颜色（根据T1）
            if obj.T1 > 50
                t1_ratio = min(1, (obj.T1 - 50) / 50);
                upperColor = copperColor .* (1 - t1_ratio * 0.4) + [1, 0.35, 0.1] .* t1_ratio * 0.5;
                upperColorDark = copperDark .* (1 - t1_ratio * 0.3) + [0.7, 0.2, 0.05] .* t1_ratio * 0.4;
            else
                upperColor = copperColor;
                upperColorDark = copperDark;
            end

            % 下铜盘颜色（根据T2）
            if obj.T2 > 35
                t2_ratio = min(1, (obj.T2 - 35) / 35);
                lowerColor = copperColor .* (1 - t2_ratio * 0.25) + [0.95, 0.6, 0.35] .* t2_ratio * 0.3;
                lowerColorDark = copperDark .* (1 - t2_ratio * 0.2) + [0.65, 0.35, 0.15] .* t2_ratio * 0.25;
            else
                lowerColor = copperColor;
                lowerColorDark = copperDark;
            end

            % 更新上铜盘
            set(obj.HdlUpperDisk, 'FaceColor', upperColor, 'EdgeColor', upperColorDark);
            set(obj.HdlUpperDiskSide, 'FaceColor', upperColorDark);
            set(obj.HdlT1Text, 'String', sprintf('T₁=%.1f°C', obj.T1));

            % 更新下铜盘
            set(obj.HdlLowerDisk, 'FaceColor', lowerColor, 'EdgeColor', lowerColorDark);
            set(obj.HdlLowerDiskSide, 'FaceColor', lowerColorDark);
            set(obj.HdlT2Text, 'String', sprintf('T₂=%.1f°C', obj.T2));
        end

        function startHeating(obj)
            % 开始加热
            [canProceed, ~] = obj.checkOperationValid('start_heating');
            if ~canProceed, return; end

            obj.IsHeating = true;
            obj.ExpStage = obj.STAGE_HEATING;
            obj.ElapsedTime = 0;

            % 创建加热计时器
            obj.HeatingTimer = timer('ExecutionMode', 'fixedRate', ...
                'Period', 0.2, ...
                'TimerFcn', @(~,~) obj.safeTimerCallback(@obj.updateHeating));
            start(obj.HeatingTimer);

            obj.updateStatus('开始加热，请等待系统达到稳态...');

            obj.BtnStartHeating.Enable = 'off';
            obj.SampleDropdown.Enable = 'off';  % 加热后不能换样品

            obj.ExpGuide.completeStep('start_heating');
            obj.showNextStepHint();
        end

        function updateHeating(obj)
            % 更新加热过程
            if ~obj.IsHeating
                return;
            end

            % 检查窗口是否有效
            if isempty(obj.Figure) || ~isvalid(obj.Figure)
                obj.stopHeating();
                return;
            end

            obj.ElapsedTime = obj.ElapsedTime + 0.2;

            % 更新计时器显示（加速模拟：0.2s = 10s）
            simTime = obj.ElapsedTime * 50;
            mins = floor(simTime / 60);
            secs = mod(floor(simTime), 60);
            obj.TimerDisplay.Text = sprintf('%02d:%02d', mins, secs);

            % 模拟加热过程（指数趋近）
            % T1 趋近于设定温度
            obj.T1 = obj.T_set + (obj.RoomTemp - obj.T_set) * exp(-obj.ElapsedTime / obj.Tau1);

            % T2 趋近于稳态温度（比T1低，取决于样品导热系数）
            lambda_ref = obj.getLambdaRef();
            % 根据材料导热系数设置合理的稳态温差
            if lambda_ref < 0.5
                deltaT_target = 35;  % 非良导体温差大
            elseif lambda_ref < 5
                deltaT_target = 20;
            else
                deltaT_target = 8;
            end
            T2_steady_target = obj.T_set - deltaT_target;
            T2_steady_target = max(T2_steady_target, obj.RoomTemp + 5);
            obj.T2 = T2_steady_target + (obj.RoomTemp - T2_steady_target) * exp(-obj.ElapsedTime / obj.Tau2);

            % 添加微小波动
            obj.T1 = obj.T1 + randn() * 0.05;
            obj.T2 = obj.T2 + randn() * 0.05;

            % 更新温度显示
            obj.TempDisplay_T1.Text = sprintf('%.1f °C', obj.T1);
            obj.TempDisplay_T2.Text = sprintf('%.1f °C', obj.T2);

            % 增量更新仪器图（仅更新动态元素，避免全量重绘）
            obj.updateDynamicDisplay();

            % 检查是否接近稳态（加热一段时间后启用等待稳态按钮）
            if obj.ElapsedTime > 20 && ~strcmp(obj.BtnWaitSteady.Enable, 'on')
                obj.BtnWaitSteady.Enable = 'on';
                ui.StyleConfig.applyButtonStyle(obj.BtnWaitSteady, 'primary');
            end
        end

        function waitSteadyState(obj)
            % 等待稳态（加速到稳态）
            [canProceed, ~] = obj.checkOperationValid('wait_steady');
            if ~canProceed, return; end

            obj.stopHeating();

            % 设置为稳态温度
            % 根据导热系数公式反推合理的稳态温差
            % λ = (m_B * c_铜 * h_A * (R_B + 2h_B)) / (2πR_A²(T1-T2)(R_B + h_B)) * dT'/dt
            % 需要设置合理的T1-T2使得计算结果接近参考值

            lambda_ref = obj.getLambdaRef();
            obj.T1 = obj.T_set + randn() * 0.2;

            % 根据材料导热系数设置合理的稳态温差
            % 非良导体温差大，良导体温差小
            if lambda_ref < 0.5
                % 硅橡胶、胶木板等非良导体：温差约30-40°C
                deltaT = 35 + randn() * 2;
            elseif lambda_ref < 5
                % 中等导热：温差约15-25°C
                deltaT = 20 + randn() * 2;
            else
                % 较好导热：温差约5-10°C
                deltaT = 8 + randn() * 1;
            end

            obj.T2 = obj.T1 - deltaT;
            obj.T2 = max(obj.T2, obj.RoomTemp + 5);

            % 更新显示
            obj.TempDisplay_T1.Text = sprintf('%.1f °C', obj.T1);
            obj.TempDisplay_T2.Text = sprintf('%.1f °C', obj.T2);

            obj.ExpStage = obj.STAGE_STEADY;
            obj.drawApparatus();

            obj.updateStatus(sprintf('系统已达稳态: T₁=%.1f°C, T₂=%.1f°C。请记录稳态温度。', obj.T1, obj.T2));

            obj.BtnWaitSteady.Enable = 'off';
            obj.BtnRecordSteady.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnRecordSteady, 'primary');

            obj.ExpGuide.completeStep('wait_steady');
            obj.showNextStepHint();
        end

        function recordSteadyState(obj)
            % 记录稳态温度
            [canProceed, ~] = obj.checkOperationValid('record_steady');
            if ~canProceed, return; end

            obj.T1_steady = obj.T1;
            obj.T2_steady = obj.T2;

            obj.updateStatus(sprintf('稳态温度已记录: T₁=%.2f°C, T₂=%.2f°C。接下来进行冷却曲线测量。', ...
                obj.T1_steady, obj.T2_steady));

            obj.BtnRecordSteady.Enable = 'off';
            obj.BtnStartCooling.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnStartCooling, 'primary');

            obj.ExpGuide.completeStep('record_steady');
            obj.showNextStepHint();
        end

        function startCooling(obj)
            % 开始冷却记录
            [canProceed, ~] = obj.checkOperationValid('start_cooling');
            if ~canProceed, return; end

            % 模拟：移走样品，加热下铜盘到T2+8°C，然后自然冷却
            obj.T2 = obj.T2_steady + 8;  % 加热到比T2高8°C
            obj.TempDisplay_T2.Text = sprintf('%.1f °C', obj.T2);

            obj.IsCooling = true;
            obj.ExpStage = obj.STAGE_COOLING;
            obj.ElapsedTime = 0;
            obj.CoolingTime = [];
            obj.CoolingTemp = [];

            % 创建冷却计时器
            obj.CoolingTimer = timer('ExecutionMode', 'fixedRate', ...
                'Period', 0.5, ...
                'TimerFcn', @(~,~) obj.safeTimerCallback(@obj.updateCooling));
            start(obj.CoolingTimer);

            obj.updateStatus('开始记录冷却曲线，每30秒自动记录一次...');

            obj.BtnStartCooling.Enable = 'off';
            obj.BtnStopCooling.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnStopCooling, 'primary');

            obj.ExpGuide.completeStep('start_cooling');
            obj.showNextStepHint();
        end

        function updateCooling(obj)
            % 更新冷却记录
            if ~obj.IsCooling
                return;
            end

            % 检查窗口是否有效
            if isempty(obj.Figure) || ~isvalid(obj.Figure)
                obj.stopCoolingTimer();
                return;
            end

            % 更新时间（模拟加速：0.5s = 30s）
            obj.ElapsedTime = obj.ElapsedTime + 30;

            % 更新计时器显示
            mins = floor(obj.ElapsedTime / 60);
            secs = mod(floor(obj.ElapsedTime), 60);
            obj.TimerDisplay.Text = sprintf('%02d:%02d', mins, secs);

            % 牛顿冷却定律模拟
            % 冷却速率需要与导热系数计算公式一致
            % 根据公式反推：dT'/dt 应该使计算的λ接近参考值
            % λ = (m_B * c * h_A * (R_B + 2h_B)) / (2πR_A²(T1-T2)(R_B + h_B)) * |dT'/dt|
            % 因此：|dT'/dt| = λ * 2πR_A²(T1-T2)(R_B + h_B) / (m_B * c * h_A * (R_B + 2h_B))

            lambda_ref = obj.getLambdaRef();
            h_A_m = obj.h_A / 1000;
            R_A_m = obj.R_A / 1000;
            R_B_m = obj.R_B / 1000;
            h_B_m = obj.h_B / 1000;

            % 计算理论冷却速率（在T2_steady附近）
            deltaT_steady = obj.T1_steady - obj.T2_steady;
            target_dT_dt = lambda_ref * 2 * pi * R_A_m^2 * deltaT_steady * (R_B_m + h_B_m) / ...
                           (obj.m_B * obj.c_copper * h_A_m * (R_B_m + 2*h_B_m));

            % 牛顿冷却：温度越高冷却越快
            temp_ratio = (obj.T2 - obj.RoomTemp) / (obj.T2_steady - obj.RoomTemp);
            temp_ratio = max(0.1, min(2, temp_ratio));  % 限制范围

            % 当前冷却速率（°C/s）
            current_dT_dt = target_dT_dt * temp_ratio;

            % 更新温度（Δt = 30s）
            obj.T2 = obj.T2 - current_dT_dt * 30 + randn() * 0.15;

            % 更新温度显示
            obj.TempDisplay_T2.Text = sprintf('%.1f °C', obj.T2);

            % 记录数据
            obj.CoolingTime(end+1) = obj.ElapsedTime;
            obj.CoolingTemp(end+1) = obj.T2;

            % 更新表格
            newRow = {sprintf('%d', obj.ElapsedTime), sprintf('%.1f', obj.T2)};
            obj.DataTable.Data = [obj.DataTable.Data; newRow];
            obj.enableExportButton();
            obj.updateCoolingCurve();

            % 不再从冷却回调中调用drawApparatus（温度已通过文本更新）

            % 检查是否可以停止（温度降到T2-8°C以下）
            if obj.T2 < obj.T2_steady - 8
                obj.updateStatus('冷却数据收集完成，可以停止记录。');
            end
        end

        function updateCoolingCurve(obj)
            % 更新冷却曲线（增量更新）
            if isempty(obj.CoolingAxes) || ~isvalid(obj.CoolingAxes)
                return;
            end

            if isempty(obj.CoolingTime)
                return;
            end

            if ~obj.CoolingCurveInitialized || isempty(obj.CoolingPlotHandle) || ~isvalid(obj.CoolingPlotHandle)
                % 首次绘制
                cla(obj.CoolingAxes);
                hold(obj.CoolingAxes, 'on');

                obj.CoolingPlotHandle = plot(obj.CoolingAxes, obj.CoolingTime, obj.CoolingTemp, 'b-o', ...
                    'LineWidth', 1.5, 'MarkerSize', 4, 'MarkerFaceColor', 'b');

                obj.CoolingSteadyLine = yline(obj.CoolingAxes, obj.T2_steady, 'r--', ...
                    sprintf('T₂=%.1f°C', obj.T2_steady), ...
                    'LineWidth', 1.5, 'LabelVerticalAlignment', 'bottom');

                hold(obj.CoolingAxes, 'off');
                xlabel(obj.CoolingAxes, '时间 t (s)');
                ylabel(obj.CoolingAxes, '温度 T (°C)');
                title(obj.CoolingAxes, '下铜盘自然冷却曲线', 'FontName', ui.StyleConfig.FontFamily);
                obj.CoolingCurveInitialized = true;
            else
                % 增量更新
                set(obj.CoolingPlotHandle, 'XData', obj.CoolingTime, 'YData', obj.CoolingTemp);
            end

            xlim(obj.CoolingAxes, [0, max(600, max(obj.CoolingTime) + 60)]);
            ylim(obj.CoolingAxes, [obj.RoomTemp, obj.T2_steady + 12]);
        end

        function stopCooling(obj)
            % 停止冷却记录
            [canProceed, ~] = obj.checkOperationValid('stop_cooling');
            if ~canProceed, return; end

            obj.stopCoolingTimer();
            obj.ExpStage = obj.STAGE_COOL_DONE;

            obj.updateStatus('冷却记录完成，可以进行导热系数计算。');

            obj.BtnStopCooling.Enable = 'off';
            obj.BtnCalculate.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnCalculate, 'primary');

            obj.ExpGuide.completeStep('stop_cooling');
            obj.showNextStepHint();
        end

        function calculateResult(obj)
            % 计算导热系数
            [canProceed, ~] = obj.checkOperationValid('calculate');
            if ~canProceed, return; end

            % 数据充分性检查
            if length(obj.CoolingTemp) < 3
                obj.updateStatus('冷却数据不足（至少需要3个数据点），请继续记录。');
                return;
            end

            % 用作图法求冷却速率（找到T2附近的点，求切线斜率）
            T2_target = obj.T2_steady;

            % 找到最接近T2的两个点
            [~, idx] = min(abs(obj.CoolingTemp - T2_target));

            if idx > 1 && idx < length(obj.CoolingTemp)
                % 取idx前后的点计算斜率
                obj.t_A = obj.CoolingTime(idx - 1);
                obj.t_B = obj.CoolingTime(idx + 1);
                obj.T_A = obj.CoolingTemp(idx - 1);
                obj.T_B = obj.CoolingTemp(idx + 1);
            else
                % 边界情况
                if idx == 1
                    obj.t_A = obj.CoolingTime(1);
                    obj.t_B = obj.CoolingTime(2);
                    obj.T_A = obj.CoolingTemp(1);
                    obj.T_B = obj.CoolingTemp(2);
                else
                    obj.t_A = obj.CoolingTime(end-1);
                    obj.t_B = obj.CoolingTime(end);
                    obj.T_A = obj.CoolingTemp(end-1);
                    obj.T_B = obj.CoolingTemp(end);
                end
            end

            % 冷却速率 dT'/dt (在空气中)（含除零保护）
            dt_cooling = obj.t_B - obj.t_A;
            if abs(dt_cooling) < 1e-10
                obj.updateStatus('警告：冷却数据时间间隔过小，无法计算冷却速率');
                return;
            end
            dT_prime_dt = (obj.T_A - obj.T_B) / dt_cooling;

            % 考虑散热面积修正，得到实际冷却速率
            % dT/dt = (R_B + 2h_B) / (2(R_B + h_B)) * dT'/dt
            R_B_m = obj.R_B / 1000;  % 转换为米
            h_B_m = obj.h_B / 1000;
            correction = (R_B_m + 2*h_B_m) / (2*(R_B_m + h_B_m));
            obj.dT_dt = correction * dT_prime_dt;

            % 计算导热系数
            % λ = (m_B * c_铜 * h_A * (R_B + 2h_B)) / (2πR_A²(T1 - T2)(R_B + h_B)) * (T_A - T_B)/(t_A - t_B)
            h_A_m = obj.h_A / 1000;  % 转换为米
            R_A_m = obj.R_A / 1000;

            numerator = obj.m_B * obj.c_copper * h_A_m * (R_B_m + 2*h_B_m);
            tempDiff = obj.T1_steady - obj.T2_steady;
            if abs(tempDiff) < 1e-10
                obj.updateStatus('警告：稳态温差过小，无法计算导热系数');
                return;
            end
            denominator = 2 * pi * R_A_m^2 * tempDiff * (R_B_m + h_B_m);

            obj.Lambda = (numerator / denominator) * abs(dT_prime_dt);

            % 获取参考值
            lambda_ref = obj.getLambdaRef();
            relError = abs(obj.Lambda - lambda_ref) / lambda_ref * 100;

            % 更新结果显示
            obj.safeSetText(obj.LblResultLambda, sprintf('%.3f W/(m·K)', obj.Lambda));
            obj.safeSetText(obj.LblResultError, sprintf('%.1f%%', relError));

            % 在冷却曲线上标注分析
            obj.updateCoolingCurveWithAnalysis();

            obj.logOperation('计算完成', sprintf('λ=%.4f W/(m·K), 误差=%.1f%%', obj.Lambda, relError));
            obj.updateStatus(sprintf('计算完成！λ = %.3f W/(m·K)，相对误差 = %.1f%%', obj.Lambda, relError));
            obj.ExpStage = obj.STAGE_CALCULATED;

            obj.BtnCalculate.Enable = 'off';
            obj.BtnComplete.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnComplete, 'success');

            obj.ExpGuide.completeStep('calculate');
            obj.showNextStepHint();
        end

        function updateCoolingCurveWithAnalysis(obj)
            % 在冷却曲线上添加分析标注
            cla(obj.CoolingAxes);
            hold(obj.CoolingAxes, 'on');

            % 绘制数据曲线
            plot(obj.CoolingAxes, obj.CoolingTime, obj.CoolingTemp, 'b-o', ...
                'LineWidth', 1.5, 'MarkerSize', 4, 'MarkerFaceColor', 'b');

            % T2稳态线
            yline(obj.CoolingAxes, obj.T2_steady, 'r--', ...
                sprintf('T₂=%.1f°C', obj.T2_steady), ...
                'LineWidth', 1.5);

            % 标记t_A, T_A点
            plot(obj.CoolingAxes, obj.t_A, obj.T_A, 'gs', ...
                'MarkerSize', 10, 'MarkerFaceColor', 'g');
            text(obj.CoolingAxes, obj.t_A + 10, obj.T_A, ...
                sprintf('(t_A, T_A)'), 'FontName', ui.StyleConfig.FontFamily);

            % 标记t_B, T_B点
            plot(obj.CoolingAxes, obj.t_B, obj.T_B, 'rs', ...
                'MarkerSize', 10, 'MarkerFaceColor', 'r');
            text(obj.CoolingAxes, obj.t_B + 10, obj.T_B, ...
                sprintf('(t_B, T_B)'), 'FontName', ui.StyleConfig.FontFamily);

            % 画切线
            slope = (obj.T_A - obj.T_B) / (obj.t_B - obj.t_A);
            t_line = linspace(obj.t_A - 30, obj.t_B + 30, 50);
            T_line = obj.T_A + slope * (t_line - obj.t_A);
            plot(obj.CoolingAxes, t_line, T_line, 'm--', 'LineWidth', 1.5);

            hold(obj.CoolingAxes, 'off');
            xlim(obj.CoolingAxes, [0, max(obj.CoolingTime) + 60]);
            ylim(obj.CoolingAxes, [min(obj.CoolingTemp) - 2, max(obj.CoolingTemp) + 2]);
            xlabel(obj.CoolingAxes, '时间 t (s)');
            ylabel(obj.CoolingAxes, '温度 T (°C)');
            title(obj.CoolingAxes, '冷却曲线（含分析）', 'FontName', ui.StyleConfig.FontFamily);
        end

        function stopHeating(obj)
            % 停止加热计时器
            obj.IsHeating = false;
            obj.safeStopTimer(obj.HeatingTimer);
            obj.HeatingTimer = [];
        end

        function stopCoolingTimer(obj)
            % 停止冷却计时器
            obj.IsCooling = false;
            obj.safeStopTimer(obj.CoolingTimer);
            obj.CoolingTimer = [];
        end

        function resetExperiment(obj)
            % 重置实验
            obj.logOperation('重置实验');
            obj.stopHeating();
            obj.stopCoolingTimer();

            % 重置数据
            obj.T1 = obj.RoomTemp;
            obj.T2 = obj.RoomTemp;
            obj.T1_steady = 0;
            obj.T2_steady = 0;
            obj.CoolingTime = [];
            obj.CoolingTemp = [];
            obj.ElapsedTime = 0;
            obj.ExpStage = obj.STAGE_INIT;
            obj.Lambda = 0;
            obj.dT_dt = 0;
            obj.ExperimentCompleted = false;
            obj.CoolingCurveInitialized = false;

            % 重置显示
            obj.TempDisplay_T1.Text = sprintf('%.1f °C', obj.T1);
            obj.TempDisplay_T2.Text = sprintf('%.1f °C', obj.T2);
            obj.TimerDisplay.Text = '00:00';
            obj.DataTable.Data = {};
            obj.disableExportButton();
            paramLbls = {obj.Lbl_h_A, obj.Lbl_R_A, obj.Lbl_h_B, obj.Lbl_R_B, obj.Lbl_m_B};
            for i = 1:length(paramLbls)
                obj.safeSetText(paramLbls{i}, '待测量');
            end

            obj.safeSetText(obj.LblResultLambda, '待计算');
            obj.safeSetText(obj.LblResultError, '待计算');

            % 重置曲线
            cla(obj.CoolingAxes);
            xlim(obj.CoolingAxes, [0, 600]);
            ylim(obj.CoolingAxes, [20, 60]);
            title(obj.CoolingAxes, '下铜盘自然冷却曲线');
            xlabel(obj.CoolingAxes, '时间 t (s)');
            ylabel(obj.CoolingAxes, '温度 T (°C)');

            % 重置仪器图
            obj.drawApparatus();

            % 重置按钮
            obj.BtnMeasureSize.Enable = 'on';
            ui.StyleConfig.applyButtonStyle(obj.BtnMeasureSize, 'primary');
            obj.BtnMeasureMass.Enable = 'off';
            obj.BtnStartHeating.Enable = 'off';
            obj.BtnWaitSteady.Enable = 'off';
            obj.BtnRecordSteady.Enable = 'off';
            obj.BtnStartCooling.Enable = 'off';
            obj.BtnStopCooling.Enable = 'off';
            obj.BtnCalculate.Enable = 'off';
            obj.BtnComplete.Enable = 'off';

            obj.SampleDropdown.Enable = 'on';

            % 重置实验引导
            if ~isempty(obj.ExpGuide)
                obj.ExpGuide.reset();
            end

            obj.updateStatus('实验已重置，请按步骤重新操作');
        end
    end

    methods (Access = protected)
        function onCleanup(obj)
            % 关闭时清理资源
            obj.stopHeating();
            obj.stopCoolingTimer();
        end
    end

    methods (Access = private)
        function lambda_ref = getLambdaRef(obj)
            % 根据当前样品类型获取参考导热系数
            idx = find(strcmp(obj.SampleList, obj.SampleType), 1);
            if isempty(idx)
                idx = 1;  % 默认使用第一个
            end
            lambda_ref = obj.Lambda_ref_values(idx);
        end

        function restoreButtonStates(obj)
            % 根据当前实验阶段恢复按钮状态

            % 先禁用所有按钮
            allBtns = {obj.BtnMeasureSize, obj.BtnMeasureMass, obj.BtnStartHeating, ...
                       obj.BtnWaitSteady, obj.BtnRecordSteady, obj.BtnStartCooling, ...
                       obj.BtnStopCooling, obj.BtnCalculate, obj.BtnComplete};
            obj.disableAllButtons(allBtns);
            obj.SampleDropdown.Enable = 'off';

            switch obj.ExpStage
                case obj.STAGE_INIT
                    obj.BtnMeasureSize.Enable = 'on';
                    ui.StyleConfig.applyButtonStyle(obj.BtnMeasureSize, 'primary');
                    obj.SampleDropdown.Enable = 'on';
                case obj.STAGE_MEASURED
                    obj.BtnMeasureMass.Enable = 'on';
                    ui.StyleConfig.applyButtonStyle(obj.BtnMeasureMass, 'primary');
                case obj.STAGE_HEATING
                    % 加热中 — 如果 ElapsedTime > 20 则可等待稳态
                    if obj.ElapsedTime > 20
                        obj.BtnWaitSteady.Enable = 'on';
                        ui.StyleConfig.applyButtonStyle(obj.BtnWaitSteady, 'primary');
                    end
                case obj.STAGE_STEADY
                    obj.BtnRecordSteady.Enable = 'on';
                    ui.StyleConfig.applyButtonStyle(obj.BtnRecordSteady, 'primary');
                case obj.STAGE_COOLING
                    obj.BtnStopCooling.Enable = 'on';
                    ui.StyleConfig.applyButtonStyle(obj.BtnStopCooling, 'primary');
                case obj.STAGE_COOL_DONE
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
            obj.CoolingCurveInitialized = false;
            obj.setupExperimentUI();
            % 恢复仪器图和温度显示
            obj.drawApparatus();
            obj.TempDisplay_T1.Text = sprintf('%.1f °C', obj.T1);
            obj.TempDisplay_T2.Text = sprintf('%.1f °C', obj.T2);
            % 恢复冷却曲线
            if ~isempty(obj.CoolingTime)
                obj.updateCoolingCurve();
            end
            % 恢复按钮状态
            obj.restoreButtonStates();
        end

        function summary = getExportSummary(obj)
            % 获取实验结果摘要
            summary = getExportSummary@experiments.ExperimentBase(obj);
            lambda_ref = obj.getLambdaRef();
            relError = abs(obj.Lambda - lambda_ref) / lambda_ref * 100;
            summary = [summary; ...
                {'样品类型', obj.SampleType}; ...
                {'导热系数 λ (W/(m·K))', sprintf('%.4f', obj.Lambda)}; ...
                {'参考值 (W/(m·K))', sprintf('%.4f', lambda_ref)}; ...
                {'相对误差', sprintf('%.2f%%', relError)}; ...
                {'稳态温度 T1 (°C)', sprintf('%.1f', obj.T1_steady)}; ...
                {'稳态温度 T2 (°C)', sprintf('%.1f', obj.T2_steady)}; ...
                {'冷却速率 dT/dt (°C/s)', sprintf('%.6f', obj.dT_dt)}];
        end
    end

    methods (Access = private)
        function setupExperimentGuide(obj)
            % 初始化实验引导系统
            obj.ExpGuide = ui.ExperimentGuide(obj.Figure, @(msg) obj.updateStatus(msg));

            % 定义实验步骤
            obj.ExpGuide.addStep('measure_size', '1. 测量尺寸', ...
                '用游标卡尺测量样品和铜盘直径、厚度');
            obj.ExpGuide.addStep('measure_mass', '2. 测量质量', ...
                '用电子天平测量散热盘质量', ...
                'Prerequisites', {'measure_size'});
            obj.ExpGuide.addStep('select_sample', '3. 选择样品', ...
                '选择待测非良导体样品', ...
                'Prerequisites', {'measure_mass'});
            obj.ExpGuide.addStep('start_heating', '4. 开始加热', ...
                '打开加热盘电源开始加热', ...
                'Prerequisites', {'select_sample'});
            obj.ExpGuide.addStep('wait_steady', '5. 等待稳态', ...
                '等待上下铜盘温度稳定', ...
                'Prerequisites', {'start_heating'});
            obj.ExpGuide.addStep('record_steady', '6. 记录稳态温度', ...
                '记录稳态时T₁和T₂', ...
                'Prerequisites', {'wait_steady'});
            obj.ExpGuide.addStep('start_cooling', '7. 开始冷却', ...
                '移走样品，记录散热盘冷却曲线', ...
                'Prerequisites', {'record_steady'});
            obj.ExpGuide.addStep('stop_cooling', '8. 停止冷却', ...
                '冷却曲线记录完成', ...
                'Prerequisites', {'start_cooling'});
            obj.ExpGuide.addStep('calculate', '9. 计算导热系数', ...
                '使用稳态法公式计算λ', ...
                'Prerequisites', {'stop_cooling'});
        end

    end
end
