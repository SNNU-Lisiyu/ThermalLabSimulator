classdef ExperimentBase < handle
    % ExperimentBase 实验基类
    % 所有实验模块继承此类，提供统一的界面结构和交互逻辑
    %
    % 使用响应式布局（uigridlayout），支持窗口缩放

    properties (Access = protected)
        % 窗口句柄
        Figure

        % 主布局容器（响应式）
        MainGrid            % 主窗口的根布局
        ContentPanel        % 内容区域容器

        % 主要面板
        HeaderPanel         % 顶部标题栏
        InfoPanel           % 实验信息面板（实验前显示）
        MainPanel           % 主实验区域
        ControlPanel        % 控制面板
        DataPanel           % 数据面板
        StatusPanel         % 状态栏
        DiscussionPanel     % 思考讨论面板（实验后显示）

        % 实验状态
        ExperimentStarted = false
        ExperimentCompleted = false
        ExperimentUIInitialized = false  % UI是否已初始化（用于返回实验时判断）
        IsClosing = false               % 窗口是否正在关闭（防止重入）

        % 实验引导系统
        ExpGuide            % 实验引导对象 (ui.ExperimentGuide)
        ExpStage = 0        % 实验阶段状态（各子类定义具体含义）

        % 缓存的UI控件句柄（避免频繁findobj）
        StatusLabel         % 状态栏标签句柄
        ExportBtn           % 导出数据按钮句柄

        % 数据表格
        DataTable           % 数据记录表 (uitable)

        % 面板容器（用于实验↔讨论可见性切换，避免销毁重建）
        ExperimentContainer % 实验内容包裹面板 (uipanel)

        % 实验信息
        ExpNumber = ''      % 实验编号
        ExpTitle = ''       % 实验名称
        ExpPurpose = ''     % 实验目的
        ExpInstruments = '' % 实验仪器
        ExpPrinciple = ''   % 实验原理
        ExpContent = ''     % 实验内容
        ExpQuestions = {}   % 思考题 {问题, 答案; ...}
    end

    methods (Access = public)
        function obj = ExperimentBase()
            % 构造函数
        end

        function show(obj)
            % 显示实验界面
            utils.Logger.logInfo(sprintf('启动实验: %s %s', obj.ExpNumber, obj.ExpTitle), class(obj));
            obj.createMainWindow();
            obj.showInfoPanel();  % 默认先显示实验信息
        end

        function close(obj)
            % 关闭实验界面
            % 注意：直接 delete 窗口，避免 close(Figure) 触发 CloseRequestFcn
            %       导致 onClose 被重复调用
            if obj.IsClosing
                return;  % 防止重入
            end
            if obj.isFigureValid()
                obj.onClose();
            end
        end

        function delete(obj)
            % 析构函数，确保资源释放
            obj.close();
        end
    end

    methods (Access = protected)
        function createMainWindow(obj)
            % 创建主窗口（响应式布局）

            % 关闭已存在的窗口
            existingFig = findobj('Tag', ['Exp_' obj.ExpNumber]);
            if ~isempty(existingFig)
                close(existingFig);
            end

            % 创建窗口（启用 Resize）
            obj.Figure = uifigure('Name', [obj.ExpNumber ' ' obj.ExpTitle], ...
                'Tag', ['Exp_' obj.ExpNumber], ...
                'Position', ui.StyleConfig.centerWindow(ui.StyleConfig.ExpWindowSize), ...
                'Color', ui.StyleConfig.BackgroundColor, ...
                'CloseRequestFcn', @(~,~) obj.onClose(), ...
                'Resize', 'on');

            % 创建主布局（3行：标题栏、内容区、状态栏）
            obj.MainGrid = uigridlayout(obj.Figure, [3, 1], ...
                'RowHeight', {50, '1x', 30}, ...
                'ColumnWidth', {'1x'}, ...
                'BackgroundColor', ui.StyleConfig.BackgroundColor, ...
                'Padding', [0, 0, 0, 0], ...
                'RowSpacing', 0);

            % 创建顶部标题栏
            obj.createHeaderPanel();

            % 创建内容区域容器
            obj.ContentPanel = uipanel(obj.MainGrid, ...
                'BackgroundColor', ui.StyleConfig.BackgroundColor, ...
                'BorderType', 'none');
            obj.ContentPanel.Layout.Row = 2;
            obj.ContentPanel.Layout.Column = 1;

            % 创建状态栏
            obj.createStatusPanel();
        end

        function createHeaderPanel(obj)
            % 创建顶部标题栏（响应式）
            obj.HeaderPanel = uipanel(obj.MainGrid, ...
                'BackgroundColor', ui.StyleConfig.PrimaryColor, ...
                'BorderType', 'none');
            obj.HeaderPanel.Layout.Row = 1;
            obj.HeaderPanel.Layout.Column = 1;

            % 标题栏内部布局
            headerGrid = uigridlayout(obj.HeaderPanel, [1, 4], ...
                'ColumnWidth', {'1x', '2x', 100, 120}, ...
                'RowHeight', {'1x'}, ...
                'BackgroundColor', ui.StyleConfig.PrimaryColor, ...
                'Padding', [20, 8, 15, 8], ...
                'ColumnSpacing', 10);

            % 实验标题
            titleLabel = uilabel(headerGrid, ...
                'Text', [obj.ExpNumber ' ' obj.ExpTitle], ...
                'FontName', ui.StyleConfig.FontFamily, ...
                'FontSize', ui.StyleConfig.FontSizeHeader, ...
                'FontWeight', 'bold', ...
                'FontColor', ui.StyleConfig.TextLight);
            titleLabel.Layout.Row = 1;
            titleLabel.Layout.Column = [1, 2];

            % 返回主页按钮
            backBtn = uibutton(headerGrid, ...
                'Text', '返回主页', ...
                'BackgroundColor', ui.StyleConfig.PanelColor, ...
                'FontName', ui.StyleConfig.FontFamily, ...
                'FontSize', ui.StyleConfig.FontSizeNormal, ...
                'FontColor', ui.StyleConfig.PrimaryColor, ...
                'ButtonPushedFcn', @(~,~) obj.returnToMain());
            backBtn.Layout.Row = 1;
            backBtn.Layout.Column = 4;

            % 导出数据按钮（初始禁用，有数据后亮起）
            obj.ExportBtn = uibutton(headerGrid, ...
                'Text', '导出数据', ...
                'BackgroundColor', [0.75 0.75 0.75], ...
                'FontName', ui.StyleConfig.FontFamily, ...
                'FontSize', ui.StyleConfig.FontSizeNormal, ...
                'FontColor', [0.5 0.5 0.5], ...
                'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) obj.exportData());
            obj.ExportBtn.Layout.Row = 1;
            obj.ExportBtn.Layout.Column = 3;
        end

        function createStatusPanel(obj)
            % 创建底部状态栏（响应式）
            obj.StatusPanel = uipanel(obj.MainGrid, ...
                'BackgroundColor', ui.StyleConfig.BackgroundColor, ...
                'BorderType', 'none');
            obj.StatusPanel.Layout.Row = 3;
            obj.StatusPanel.Layout.Column = 1;

            % 状态栏内部布局
            statusGrid = uigridlayout(obj.StatusPanel, [1, 1], ...
                'ColumnWidth', {'1x'}, ...
                'RowHeight', {'1x'}, ...
                'BackgroundColor', ui.StyleConfig.BackgroundColor, ...
                'Padding', [20, 5, 20, 5]);

            obj.StatusLabel = uilabel(statusGrid, ...
                'Text', core.AppConfig.StatusReady, ...
                'Tag', 'StatusLabel', ...
                'FontName', ui.StyleConfig.FontFamily, ...
                'FontSize', ui.StyleConfig.FontSizeStatus, ...
                'FontWeight', 'bold', ...
                'FontColor', ui.StyleConfig.TextSecondary);
            obj.StatusLabel.Layout.Row = 1;
            obj.StatusLabel.Layout.Column = 1;
        end

        function showInfoPanel(obj)
            % 显示实验信息面板（实验前）- 使用HTML实现滚动

            % 清除之前的面板
            obj.clearContentPanels();

            % 在 ContentPanel 中创建信息面板布局
            obj.InfoPanel = uigridlayout(obj.ContentPanel, [2, 1], ...
                'RowHeight', {'1x', 60}, ...
                'ColumnWidth', {'1x'}, ...
                'BackgroundColor', ui.StyleConfig.PanelColor, ...
                'Padding', [30, 10, 30, 10], ...
                'RowSpacing', 10);

            % 使用 uihtml 实现可滚动的内容区域
            htmlContent = obj.buildInfoHTML();
            infoHTML = uihtml(obj.InfoPanel, ...
                'HTMLSource', htmlContent);
            infoHTML.Layout.Row = 1;
            infoHTML.Layout.Column = 1;

            % 底部按钮区域（响应式居中）
            btnGrid = uigridlayout(obj.InfoPanel, [1, 3], ...
                'ColumnWidth', {'1x', 150, '1x'}, ...
                'RowHeight', {40}, ...
                'BackgroundColor', ui.StyleConfig.PanelColor, ...
                'Padding', [0, 10, 0, 10]);
            btnGrid.Layout.Row = 2;
            btnGrid.Layout.Column = 1;

            % 开始实验按钮
            startBtn = uibutton(btnGrid, ...
                'Text', core.AppConfig.StartExpBtnText, ...
                'FontName', ui.StyleConfig.FontFamily, ...
                'FontSize', ui.StyleConfig.FontSizeButton, ...
                'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) obj.startExperiment());
            startBtn.Layout.Row = 1;
            startBtn.Layout.Column = 2;
            ui.StyleConfig.applyButtonStyle(startBtn, 'primary');
        end

        function htmlContent = buildInfoHTML(obj)
            % 构建实验信息的HTML内容

            % 获取颜色配置并转换为 Hex
            primaryColorHex = obj.rgbToHex(ui.StyleConfig.PrimaryColor);
            textColorHex = obj.rgbToHex(ui.StyleConfig.TextPrimary);
            panelColorHex = obj.rgbToHex(ui.StyleConfig.PanelColor);

            % 获取基础样式
            fontFamily = ui.StyleConfig.FontFamily;

            % 转换文本中的换行符为HTML换行
            purpose = strrep(obj.ExpPurpose, newline, '<br>');
            instruments = strrep(obj.ExpInstruments, newline, '<br>');
            principle = strrep(obj.ExpPrinciple, newline, '<br>');
            content = strrep(obj.ExpContent, newline, '<br>');

            % 处理下标
            principle = obj.formatSubscripts(principle);
            content = obj.formatSubscripts(content);

            % 使用 cell 数组拼接 HTML，更清晰易维护
            lines = {
                '<!DOCTYPE html>';
                '<html>';
                '<head>';
                '<meta charset="UTF-8">';
                '<style>';
                'body {';
                ['    font-family: "' fontFamily '", "Microsoft YaHei", sans-serif;'];
                '    font-size: 14px;';
                ['    color: ' textColorHex ';'];
                '    padding: 20px 30px;';
                '    margin: 0;';
                ['    background-color: ' panelColorHex ';'];
                '    line-height: 1.8;';
                '    overflow-y: auto;';
                '    height: 100%;';
                '    box-sizing: border-box;';
                '}';
                '.section-title {';
                '    font-size: 15px;';
                '    font-weight: bold;';
                ['    color: ' primaryColorHex ';'];
                '    margin-top: 15px;';
                '    margin-bottom: 8px;';
                '}';
                '.section-content {';
                '    margin-bottom: 10px;';
                '    text-align: justify;';
                '}';
                '::-webkit-scrollbar {';
                '    width: 10px;';
                '}';
                '::-webkit-scrollbar-track {';
                '    background: #f1f1f1;';
                '    border-radius: 5px;';
                '}';
                '::-webkit-scrollbar-thumb {';
                '    background: #c1c1c1;';
                '    border-radius: 5px;';
                '}';
                '::-webkit-scrollbar-thumb:hover {';
                '    background: #a1a1a1;';
                '}';
                '</style>';
                '</head>';
                '<body>';
                '<div class="section-title">【实验目的】</div>';
                ['<div class="section-content">' purpose '</div>'];
                '<div class="section-title">【实验仪器】</div>';
                ['<div class="section-content">' instruments '</div>'];
                '<div class="section-title">【实验原理】</div>';
                ['<div class="section-content">' principle '</div>'];
                '<div class="section-title">【实验内容】</div>';
                ['<div class="section-content">' content '</div>'];
                '</body>';
                '</html>'
            };

            htmlContent = strjoin(lines, newline);
        end

        function hex = rgbToHex(~, rgb)
            % rgbToHex 将RGB数组转换为Hex颜色字符串
            hex = sprintf('#%02x%02x%02x', round(rgb * 255));
        end

        function text = formatSubscripts(~, text)
            % formatSubscripts 将常见下标/上标标记转换为 HTML 格式
            %   支持格式：
            %     H_2O  → H<sub>2</sub>O     （单字符下标）
            %     C_{p}  → C<sub>p</sub>      （花括号包裹的下标）
            %     T^2   → T<sup>2</sup>       （单字符上标）
            %     e^{-x} → e<sup>-x</sup>     （花括号包裹的上标）
            if isempty(text)
                text = '';
                return;
            end

            % 花括号下标：X_{abc} → X<sub>abc</sub>
            text = regexprep(text, '_(\{([^}]+)\})', '<sub>$2</sub>');
            % 单字符下标：X_a → X<sub>a</sub>（排除已处理的 HTML 标签）
            text = regexprep(text, '_([A-Za-z0-9])', '<sub>$1</sub>');

            % 花括号上标：X^{abc} → X<sup>abc</sup>
            text = regexprep(text, '\^(\{([^}]+)\})', '<sup>$2</sup>');
            % 单字符上标：X^a → X<sup>a</sup>
            text = regexprep(text, '\^([A-Za-z0-9])', '<sup>$1</sup>');
        end

        function showExperimentPanel(obj)
            % 显示实验主界面（响应式布局）

            % 从讨论页面返回：直接切换可见性，无需销毁重建
            if ~isempty(obj.ExperimentContainer) && isvalid(obj.ExperimentContainer)
                if ~isempty(obj.DiscussionPanel) && isvalid(obj.DiscussionPanel)
                    delete(obj.DiscussionPanel);
                    obj.DiscussionPanel = [];
                end
                obj.ExperimentContainer.Visible = 'on';
                obj.updateStatus(core.AppConfig.StatusRunning);
                return;
            end

            % 首次进入实验：清除信息面板
            obj.clearContentPanels();

            % 创建实验内容包裹面板（后续切换时隐藏/显示此面板）
            obj.ExperimentContainer = uipanel(obj.ContentPanel, ...
                'BorderType', 'none', ...
                'BackgroundColor', ui.StyleConfig.BackgroundColor, ...
                'Units', 'normalized', ...
                'Position', [0 0 1 1]);

            % 创建实验区域的主布局（左右分栏）
            expGrid = uigridlayout(obj.ExperimentContainer, [1, 2], ...
                'ColumnWidth', {'2.2x', '1x'}, ...
                'RowHeight', {'1x'}, ...
                'BackgroundColor', ui.StyleConfig.BackgroundColor, ...
                'Padding', [15, 15, 15, 15], ...
                'ColumnSpacing', 15);

            % 左侧：实验操作区
            obj.MainPanel = uipanel(expGrid, ...
                'Title', core.AppConfig.ExpAreaTitle, ...
                'BackgroundColor', ui.StyleConfig.PanelColor, ...
                'FontName', ui.StyleConfig.FontFamily, ...
                'FontSize', ui.StyleConfig.FontSizeNormal, ...
                'FontWeight', 'bold', ...
                'ForegroundColor', ui.StyleConfig.TextPrimary);
            obj.MainPanel.Layout.Row = 1;
            obj.MainPanel.Layout.Column = 1;

            % 右侧：控制和数据面板（上下分栏）
            rightGrid = uigridlayout(expGrid, [2, 1], ...
                'RowHeight', {'0.45x', '0.55x'}, ...
                'ColumnWidth', {'1x'}, ...
                'BackgroundColor', ui.StyleConfig.BackgroundColor, ...
                'Padding', [0, 0, 0, 0], ...
                'RowSpacing', 15);
            rightGrid.Layout.Row = 1;
            rightGrid.Layout.Column = 2;

            % 右侧上部：控制面板
            obj.ControlPanel = uipanel(rightGrid, ...
                'Title', core.AppConfig.ControlAreaTitle, ...
                'BackgroundColor', ui.StyleConfig.PanelColor, ...
                'FontName', ui.StyleConfig.FontFamily, ...
                'FontSize', ui.StyleConfig.FontSizeNormal, ...
                'FontWeight', 'bold', ...
                'ForegroundColor', ui.StyleConfig.TextPrimary);
            obj.ControlPanel.Layout.Row = 1;
            obj.ControlPanel.Layout.Column = 1;

            % 右侧下部：数据面板
            obj.DataPanel = uipanel(rightGrid, ...
                'Title', core.AppConfig.DataAreaTitle, ...
                'BackgroundColor', ui.StyleConfig.PanelColor, ...
                'FontName', ui.StyleConfig.FontFamily, ...
                'FontSize', ui.StyleConfig.FontSizeNormal, ...
                'FontWeight', 'bold', ...
                'ForegroundColor', ui.StyleConfig.TextPrimary);
            obj.DataPanel.Layout.Row = 2;
            obj.DataPanel.Layout.Column = 1;

            % 调用子类的具体实现
            obj.setupExperimentUI();
            obj.ExperimentUIInitialized = true;

            % 更新状态
            obj.updateStatus(core.AppConfig.StatusRunning);
        end

        function showDiscussionPanel(obj)
            % 显示思考讨论面板（实验后）- 响应式布局

            % 隐藏实验面板（保留所有UI状态，不销毁）
            if ~isempty(obj.ExperimentContainer) && isvalid(obj.ExperimentContainer)
                obj.ExperimentContainer.Visible = 'off';
            else
                obj.clearContentPanels();
            end

            % 创建讨论面板主布局
            obj.DiscussionPanel = uigridlayout(obj.ContentPanel, [3, 1], ...
                'RowHeight', {50, '1x', 60}, ...
                'ColumnWidth', {'1x'}, ...
                'BackgroundColor', ui.StyleConfig.PanelColor, ...
                'Padding', [50, 20, 50, 20], ...
                'RowSpacing', 10);

            % 标题
            titleLabel = uilabel(obj.DiscussionPanel, ...
                'Text', core.AppConfig.DiscussionTitle, ...
                'FontName', ui.StyleConfig.FontFamily, ...
                'FontSize', ui.StyleConfig.FontSizeTitle, ...
                'FontWeight', 'bold', ...
                'FontColor', ui.StyleConfig.PrimaryColor, ...
                'HorizontalAlignment', 'center');
            titleLabel.Layout.Row = 1;
            titleLabel.Layout.Column = 1;

            % 问题区域（可滚动）
            questionPanel = uipanel(obj.DiscussionPanel, ...
                'BackgroundColor', ui.StyleConfig.PanelColor, ...
                'BorderType', 'none', ...
                'Scrollable', 'on');
            questionPanel.Layout.Row = 2;
            questionPanel.Layout.Column = 1;

            % 检查问题数量
            numQuestions = size(obj.ExpQuestions, 1);
            if numQuestions == 0
                % 显示"暂无思考题"提示（使用 gridlayout 保持响应式）
                emptyGrid = uigridlayout(questionPanel, [1, 1], ...
                    'RowHeight', {'1x'}, ...
                    'ColumnWidth', {'1x'}, ...
                    'BackgroundColor', ui.StyleConfig.PanelColor, ...
                    'Padding', [0, 0, 0, 0]);
                noQuestionLabel = uilabel(emptyGrid, ...
                    'Text', '暂无思考题', ...
                    'FontName', ui.StyleConfig.FontFamily, ...
                    'FontSize', ui.StyleConfig.FontSizeSubheader, ...
                    'FontColor', ui.StyleConfig.TextSecondary, ...
                    'HorizontalAlignment', 'center');
                noQuestionLabel.Layout.Row = 1;
                noQuestionLabel.Layout.Column = 1;
            else
                % 问题内容布局（每个问题占用3行：问题、答案面板、按钮）
                questionGrid = uigridlayout(questionPanel, [numQuestions * 3, 1], ...
                    'RowHeight', repmat({'fit'}, 1, numQuestions * 3), ...
                    'ColumnWidth', {'1x'}, ...
                    'BackgroundColor', ui.StyleConfig.PanelColor, ...
                    'Padding', [30, 10, 30, 10], ...
                    'RowSpacing', 10);

                % 显示每个问题
                for i = 1:numQuestions
                    question = obj.ExpQuestions{i, 1};
                    answer = obj.ExpQuestions{i, 2};
                    baseRow = (i - 1) * 3 + 1;

                    % 问题标签
                    qLabel = uilabel(questionGrid, ...
                        'Text', sprintf('问题 %d：%s', i, question), ...
                        'FontName', ui.StyleConfig.FontFamily, ...
                        'FontSize', ui.StyleConfig.FontSizeSubheader - 1, ...
                        'FontWeight', 'bold', ...
                        'FontColor', ui.StyleConfig.TextPrimary, ...
                        'WordWrap', 'on');
                    qLabel.Layout.Row = baseRow;
                    qLabel.Layout.Column = 1;

                    % 答案面板（默认隐藏）
                    answerPanel = uipanel(questionGrid, ...
                        'BackgroundColor', ui.StyleConfig.LightBackground, ...
                        'BorderType', 'line', ...
                        'Visible', 'off', ...
                        'Tag', sprintf('AnswerPanel_%d', i));
                    answerPanel.Layout.Row = baseRow + 1;
                    answerPanel.Layout.Column = 1;

                    % 答案内部布局
                    answerGrid = uigridlayout(answerPanel, [1, 1], ...
                        'RowHeight', {'fit'}, ...
                        'ColumnWidth', {'1x'}, ...
                        'BackgroundColor', ui.StyleConfig.LightBackground, ...
                        'Padding', [15, 10, 15, 10]);

                    aLabel = uilabel(answerGrid, ...
                        'Text', ['答案：' answer], ...
                        'FontName', ui.StyleConfig.FontFamily, ...
                        'FontSize', ui.StyleConfig.FontSizeButton, ...
                        'FontColor', ui.StyleConfig.TextPrimary, ...
                        'WordWrap', 'on');
                    aLabel.Layout.Row = 1;
                    aLabel.Layout.Column = 1;

                    % 显示答案按钮容器
                    btnContainer = uigridlayout(questionGrid, [1, 2], ...
                        'ColumnWidth', {200, '1x'}, ...
                        'RowHeight', {35}, ...
                        'BackgroundColor', ui.StyleConfig.PanelColor, ...
                        'Padding', [0, 0, 0, 15]);
                    btnContainer.Layout.Row = baseRow + 2;
                    btnContainer.Layout.Column = 1;

                    showBtn = uibutton(btnContainer, ...
                        'Text', core.AppConfig.ShowAnswerBtnText, ...
                        'FontName', ui.StyleConfig.FontFamily, ...
                        'FontSize', ui.StyleConfig.FontSizeCaption, ...
                        'Tag', sprintf('ShowBtn_%d', i), ...
                        'UserData', answerPanel, ...
                        'ButtonPushedFcn', @(btn,~) obj.showAnswer(btn));
                    showBtn.Layout.Row = 1;
                    showBtn.Layout.Column = 1;
                    ui.StyleConfig.applyButtonStyle(showBtn, 'secondary');
                end
            end

            % 底部按钮区域（响应式居中）
            btnGrid = uigridlayout(obj.DiscussionPanel, [1, 5], ...
                'ColumnWidth', {'1x', 140, 20, 140, '1x'}, ...
                'RowHeight', {40}, ...
                'BackgroundColor', ui.StyleConfig.PanelColor, ...
                'Padding', [0, 10, 0, 10]);
            btnGrid.Layout.Row = 3;
            btnGrid.Layout.Column = 1;

            % 返回实验按钮
            backExpBtn = uibutton(btnGrid, ...
                'Text', core.AppConfig.ReturnExpBtnText, ...
                'FontSize', ui.StyleConfig.FontSizeButton, ...
                'ButtonPushedFcn', @(~,~) obj.showExperimentPanel());
            backExpBtn.Layout.Row = 1;
            backExpBtn.Layout.Column = 2;
            ui.StyleConfig.applyButtonStyle(backExpBtn, 'secondary');

            % 返回主页按钮
            homeBtn = uibutton(btnGrid, ...
                'Text', core.AppConfig.ReturnHomeBtnText, ...
                'FontSize', ui.StyleConfig.FontSizeButton, ...
                'ButtonPushedFcn', @(~,~) obj.returnToMain());
            homeBtn.Layout.Row = 1;
            homeBtn.Layout.Column = 4;
            ui.StyleConfig.applyButtonStyle(homeBtn, 'primary');
        end

        function showAnswer(~, btn)
            % 显示答案
            answerPanel = btn.UserData;
            answerPanel.Visible = 'on';
            btn.Enable = 'off';
            btn.Text = core.AppConfig.AnswerShownText;
        end

        function clearContentPanels(obj)
            % clearContentPanels 清除内容面板中的所有子组件
            if ~isempty(obj.ContentPanel) && isvalid(obj.ContentPanel)
                children = obj.ContentPanel.Children;
                for i = 1:length(children)
                    if isvalid(children(i))
                        delete(children(i));
                    end
                end
            end

            % 重置面板引用
            obj.InfoPanel = [];
            obj.MainPanel = [];
            obj.ControlPanel = [];
            obj.DataPanel = [];
            obj.DiscussionPanel = [];
            obj.ExperimentContainer = [];
        end

        function startExperiment(obj)
            % 开始实验
            obj.ExperimentStarted = true;
            obj.showExperimentPanel();
        end

        function completeExperiment(obj)
            % 完成实验
            obj.ExperimentCompleted = true;
            obj.showDiscussionPanel();
        end

        function enableExportButton(obj)
            % 启用导出数据按钮（有数据时调用）
            if ~isempty(obj.ExportBtn) && isvalid(obj.ExportBtn) && strcmp(obj.ExportBtn.Enable, 'off')
                obj.ExportBtn.Enable = 'on';
                obj.ExportBtn.BackgroundColor = [0.18 0.80 0.44];
                obj.ExportBtn.FontColor = [1 1 1];
            end
        end

        function disableExportButton(obj)
            % 禁用导出数据按钮（重置时调用）
            if ~isempty(obj.ExportBtn) && isvalid(obj.ExportBtn)
                obj.ExportBtn.Enable = 'off';
                obj.ExportBtn.BackgroundColor = [0.75 0.75 0.75];
                obj.ExportBtn.FontColor = [0.5 0.5 0.5];
            end
        end

        function updateStatus(obj, message)
            % 更新状态栏
            if ~obj.isFigureValid()
                return;
            end

            if isempty(obj.StatusPanel) || ~isvalid(obj.StatusPanel)
                return;
            end

            if ~isempty(obj.StatusLabel) && isvalid(obj.StatusLabel)
                obj.StatusLabel.Text = message;
            end
        end

        function valid = isFigureValid(obj)
            % isFigureValid 检查窗口是否有效
            valid = ~isempty(obj.Figure) && isvalid(obj.Figure);
        end

        function returnToMain(obj)
            % 返回主页
            obj.close();
            try
                main();
            catch ME
                warning('ExperimentBase:ReturnFailed', '返回主页失败: %s', ME.message);
            end
        end

        function onClose(obj)
            % 窗口关闭回调
            if obj.IsClosing
                return;  % 防止重入
            end
            obj.IsClosing = true;

            utils.Logger.logInfo(sprintf('关闭实验: %s', obj.ExpNumber), class(obj));
            % 调用子类清理方法（如果实现）
            obj.onCleanup();

            % 清除内容面板引用
            obj.clearContentPanels();

            % 删除窗口
            if obj.isFigureValid()
                delete(obj.Figure);
            end
        end

        function onCleanup(obj) %#ok<MANU>
            % 子类可重写此方法进行资源清理
            % 示例：停止计时器、关闭文件句柄、释放硬件连接等
            % 注意：子类无需调用 super.onCleanup()
        end

        function safeTimerCallback(obj, callbackFcn)
            % safeTimerCallback Timer回调安全包装器
            % 用 try-catch 包装 timer 回调，防止异常导致 timer 静默停止、UI 卡死
            % 用法：'TimerFcn', @(~,~) obj.safeTimerCallback(@obj.updateHeating)
            try
                if obj.isFigureValid()
                    callbackFcn();
                end
            catch ME
                utils.Logger.logError(ME, sprintf('%s.TimerCallback', class(obj)));
                obj.updateStatus(sprintf('内部错误: %s', ME.message));
            end
        end

        function restoreExperimentUI(obj)
            % 子类可重写此方法，用于从讨论页面返回时恢复实验界面
            % 默认行为：重新调用 setupExperimentUI（子类可覆盖以保持状态）
            obj.setupExperimentUI();
        end

        %% ---- 实验引导公共方法 ----

        function [canProceed, message] = checkOperationValid(obj, stepId)
            % checkOperationValid 检查操作是否满足前置条件
            % 如果 ExpGuide 未初始化，默认允许所有操作
            if isempty(obj.ExpGuide)
                canProceed = true;
                message = '';
                return;
            end
            [canProceed, message] = obj.ExpGuide.validateOperation(stepId);
            if canProceed
                utils.Logger.logDebug(sprintf('[%s] 执行操作: %s', obj.ExpNumber, stepId), class(obj));
            else
                obj.ExpGuide.showOperationError(stepId, 'missing_prereq');
                utils.Logger.logDebug(sprintf('[%s] 操作被拒: %s - %s', obj.ExpNumber, stepId, message), class(obj));
            end
        end

        function showNextStepHint(obj)
            % showNextStepHint 显示下一步操作提示
            if ~isempty(obj.ExpGuide)
                hint = obj.ExpGuide.getNextStepHint();
                obj.updateStatus(hint);
            end
        end

        %% ---- UI 创建辅助方法 ----

        function lbl = createSimpleLabel(~, parent, text, align, color, row, col)
            % createSimpleLabel 简单标签创建辅助函数
            lbl = uilabel(parent, 'Text', text, ...
                'HorizontalAlignment', align, ...
                'FontColor', color);
            if nargin >= 6, lbl.Layout.Row = row; end
            if nargin >= 7, lbl.Layout.Column = col; end
        end

        function lbl = createInstrumentDisplay(~, parent, titleText, valueText, color, row, col)
            % createInstrumentDisplay 创建仪器读数显示组件
            container = uigridlayout(parent, [2, 1], ...
                'RowHeight', {20, '1x'}, 'Padding', [0,0,0,0], 'RowSpacing', 0, ...
                'BackgroundColor', ui.StyleConfig.PanelColor);
            container.Layout.Row = row;
            if nargin > 6
                container.Layout.Column = col;
            end

            uilabel(container, 'Text', titleText, 'HorizontalAlignment', 'center', ...
                'FontSize', 11, 'FontColor', ui.StyleConfig.TextSecondary);
            lbl = uilabel(container, 'Text', valueText, 'HorizontalAlignment', 'center', ...
                'FontName', ui.StyleConfig.FontFamilyMono, 'FontSize', 18, ...
                'FontWeight', 'bold', 'FontColor', color);
        end

        function btn = createExpButton(~, parent, text, callback, style, row, col)
            % createExpButton 创建实验操作按钮
            btn = uibutton(parent, 'Text', text, 'ButtonPushedFcn', callback);
            btn.Layout.Row = row;
            if nargin > 6
                btn.Layout.Column = col;
            end
            ui.StyleConfig.applyButtonStyle(btn, style);
        end

        %% ---- 工具方法 ----

        function safeStopTimer(~, timerObj)
            % safeStopTimer 安全停止并删除 timer 对象
            if ~isempty(timerObj) && isvalid(timerObj)
                stop(timerObj);
                delete(timerObj);
            end
        end

        function disableAllButtons(~, btnCellArray)
            % disableAllButtons 批量禁用按钮并应用禁用样式
            for i = 1:length(btnCellArray)
                if ~isempty(btnCellArray{i}) && isvalid(btnCellArray{i})
                    btnCellArray{i}.Enable = 'off';
                    ui.StyleConfig.applyButtonStyle(btnCellArray{i}, 'disabled');
                end
            end
        end

        function safeSetText(~, uiComponent, text)
            % safeSetText 安全设置 UI 组件文本
            if ~isempty(uiComponent) && isvalid(uiComponent)
                uiComponent.Text = text;
            end
        end

        function logOperation(obj, operation, detail)
            % logOperation 记录实验操作日志
            if nargin < 3
                utils.Logger.logInfo(sprintf('[%s] %s', obj.ExpNumber, operation), class(obj));
            else
                utils.Logger.logInfo(sprintf('[%s] %s: %s', obj.ExpNumber, operation, detail), class(obj));
            end
        end

        function exportData(obj)
            % exportData 导出实验数据到 CSV 文件
            try
                % 检查是否有数据
                if isempty(obj.DataTable) || ~isvalid(obj.DataTable) || isempty(obj.DataTable.Data)
                    uialert(obj.Figure, '没有可导出的数据，请先进行实验。', '导出提示');
                    return;
                end

                % 文件保存对话框
                defaultName = sprintf('%s_%s_数据.csv', obj.ExpNumber, ...
                    char(datetime('now', 'Format', 'yyyyMMdd_HHmmss')));
                [fileName, filePath] = uiputfile( ...
                    {'*.csv', 'CSV文件 (*.csv)'; '*.xlsx', 'Excel文件 (*.xlsx)'}, ...
                    '导出实验数据', defaultName);
                if isequal(fileName, 0)
                    return;
                end
                fullPath = fullfile(filePath, fileName);

                % 获取数据表内容
                colNames = obj.DataTable.ColumnName;
                rawData = obj.DataTable.Data;

                % 获取实验结果摘要
                summary = obj.getExportSummary();

                % 写入文件
                [~, ~, ext] = fileparts(fullPath);
                if strcmp(ext, '.xlsx')
                    obj.writeExcelExport(fullPath, colNames, rawData, summary);
                else
                    obj.writeCsvExport(fullPath, colNames, rawData, summary);
                end

                utils.Logger.logInfo(sprintf('数据导出: %s', fullPath), class(obj));
                obj.updateStatus(sprintf('数据已导出到: %s', fullPath));
            catch ME
                uialert(obj.Figure, ...
                    sprintf('导出失败: %s', ME.message), '导出错误');
            end
        end

        function summary = getExportSummary(obj)
            % getExportSummary 获取实验结果摘要（子类可覆写）
            % 返回 Nx2 cell 数组: {名称, 值; ...}
            summary = {'实验', [obj.ExpNumber ' ' obj.ExpTitle]; ...
                       '时间', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'))};
        end
    end

    methods (Access = private)
        function writeCsvExport(~, fullPath, colNames, rawData, summary)
            % 写入 CSV 文件
            fid = fopen(fullPath, 'w', 'n', 'UTF-8');
            if fid == -1
                error('无法创建文件: %s', fullPath);
            end
            cleanupObj = onCleanup(@() fclose(fid));

            % 写入 BOM
            fwrite(fid, [0xEF 0xBB 0xBF], 'uint8');

            % 写入结果摘要
            fprintf(fid, '=== 实验结果摘要 ===\n');
            for i = 1:size(summary, 1)
                fprintf(fid, '%s,%s\n', summary{i,1}, summary{i,2});
            end
            fprintf(fid, '\n');

            % 写入数据表头
            fprintf(fid, '=== 实验数据 ===\n');
            headerLine = strjoin(colNames, ',');
            fprintf(fid, '%s\n', headerLine);

            % 写入数据行
            for i = 1:size(rawData, 1)
                row = rawData(i, :);
                rowStrs = cellfun(@(x) num2str(x), row, 'UniformOutput', false);
                fprintf(fid, '%s\n', strjoin(rowStrs, ','));
            end
        end

        function writeExcelExport(~, fullPath, colNames, rawData, summary)
            % 写入 Excel 文件
            % 摘要部分
            summaryHeader = {'实验结果摘要', ''};
            writecell([summaryHeader; summary], fullPath, 'Sheet', '结果摘要');
            % 数据部分
            dataWithHeader = [colNames'; rawData];
            writecell(dataWithHeader, fullPath, 'Sheet', '实验数据');
        end
    end

    methods (Abstract, Access = protected)
        % 子类必须实现：设置实验界面
        setupExperimentUI(obj)
    end
end
