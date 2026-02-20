classdef StyleConfig
    % StyleConfig 统一样式配置类
    % 定义热学实验虚拟仿真系统的全局样式

    properties (Constant)
        % ==================== 颜色配置 ====================
        % 主色调
        PrimaryColor = [0, 118, 206] / 255;      % #0076CE 蓝色
        SecondaryColor = [0, 150, 136] / 255;    % #009688 青色
        AccentColor = [255, 107, 0] / 255;       % #FF6B00 橙色

        % 背景色
        BackgroundColor = [248, 249, 250] / 255; % #F8F9FA 极浅灰（近白）
        PanelColor = [255, 255, 255] / 255;      % #FFFFFF 白色
        DarkBackground = [33, 37, 41] / 255;     % #212529 深色
        LightBackground = [242, 250, 255] / 255; % #F2FAFF 浅蓝背景（用于高亮/答案区域）

        % 文字颜色
        TextPrimary = [33, 37, 41] / 255;        % #212529 主文字
        TextSecondary = [108, 117, 125] / 255;   % #6C757D 次要文字
        TextLight = [255, 255, 255] / 255;       % #FFFFFF 浅色文字（用于深色背景）

        % 状态颜色
        SuccessColor = [40, 167, 69] / 255;      % #28A745 成功绿
        WarningColor = [255, 193, 7] / 255;      % #FFC107 警告黄
        ErrorColor = [220, 53, 69] / 255;        % #DC3545 错误红
        InfoColor = [23, 162, 184] / 255;        % #17A2B8 信息蓝
        DisabledColor = [173, 181, 189] / 255;   % #ADB5BD 禁用灰
        ErrorFieldBg = [255, 240, 240] / 255;    % #FFF0F0 错误输入框背景
        GridColor = [204, 204, 204] / 255;       % #CCCCCC 坐标轴网格颜色

        % 仪器显示颜色
        ThermometerColor = [0.8, 0, 0];          % 温度计显示红色
        BalanceColor = [0, 0.5, 0];              % 天平显示绿色
        SimulationBgColor = [0.98, 0.98, 0.98];  % 仿真区域背景色
        VoltmeterColor = [0, 0, 0.8];            % 电压表显示蓝色
        AmmeterColor = [0.8, 0.4, 0];            % 电流表显示橙色

        % ==================== 尺寸配置 ====================
        % 窗口尺寸
        MainWindowSize = [1200, 800];            % 主界面尺寸
        ExpWindowSize = [1400, 900];             % 实验界面尺寸
        GuideWindowSize = [600, 450];            % 实验须知窗口尺寸

        % 布局尺寸
        HeaderHeight = 100;                      % 顶部栏高度
        FooterHeight = 40;                       % 底部栏高度

        % 字体大小
        FontSizeTitle = 24;                      % 标题
        FontSizeLarge = 32;                      % 大标题（主界面）
        FontSizeHeader = 18;                     % 二级标题
        FontSizeSubheader = 16;                  % 三级标题
        FontSizeButton = 14;                     % 按钮文字
        FontSizeNormal = 12;                     % 正文
        FontSizeSmall = 11;                      % 小字（表格/坐标轴）
        FontSizeCaption = 13;                    % 说明文字
        FontSizeStatus = 16;                     % 状态栏/引导文字

        % 组件尺寸
        ButtonHeight = 40;                       % 按钮高度
        ButtonWidth = 150;                       % 按钮宽度
        ButtonWidthSmall = 120;                  % 小按钮宽度
        InputHeight = 30;                        % 输入框高度
        PanelPadding = 15;                       % 面板内边距
        ComponentSpacing = 10;                   % 组件间距

        % ==================== 实验面板布局配置 ====================
        % 控制面板（参数区）布局
        ControlPanelPadding = [10, 5, 10, 5];    % [上, 右, 下, 左] 内边距
        ControlPanelRowSpacing = 5;              % 行间距
        ControlPanelColumnSpacing = 5;           % 列间距
        ControlPanelColumnWidth = {'fit', '1x'}; % 列宽配置 [标签列, 值列]
        ControlPanelRowHeight = 28;              % 标准行高
        ControlPanelTitleHeight = 30;            % 标题行高度

        % 数据面板布局
        DataPanelPadding = [10, 5, 10, 5];       % [上, 右, 下, 左] 内边距
        DataPanelRowSpacing = 5;                 % 行间距
        DataPanelColumnSpacing = 5;              % 列间距
        DataPanelTitleHeight = 30;               % 标题行高度
        DataPanelResultRowHeight = 22;           % 结果行高度

        % 面板字体配置
        PanelTitleFontSize = 14;                 % 面板标题字号
        PanelLabelFontSize = 12;                 % 参数/结果标签字号
        PanelValueFontSize = 12;                 % 参数/结果值字号
        TableFontSize = 10;                      % 表格字体大小

        % 窗口布局常量
        WindowMargin = 50;                       % 窗口边距
        WindowMinX = 10;                         % 窗口最小X偏移
        WindowMinY = 40;                         % 窗口最小Y偏移（预留任务栏）

        % 坐标轴样式常量
        GridAlpha = 0.5;                         % 网格透明度
        AxesLineWidth = 0.8;                     % 坐标轴线宽

        % ==================== 字体配置 ====================
        % 备注：MATLAB R2019b+ 支持在常量中调用静态方法
        FontFamily = ui.StyleConfig.getSystemFont();       % 默认字体
        FontFamilyMono = 'Consolas';             % 等宽字体（数据显示）
    end

    properties (Constant, Access = private)
        % 资源子目录名称（用于 getResourceSubPath）
        ImageSubdir = 'images';
        DataSubdir = 'data';
    end

    methods (Static)
        function font = getSystemFont()
            if ispc
                font = 'Microsoft YaHei UI';
            elseif ismac
                font = 'PingFang SC';
            else
                font = 'SansSerif';
            end
        end

        function font = getFontFamily()
            % getFontFamily 获取应用默认字体（方法形式）
            %   提供方法调用方式，与 FontFamily 常量等价
            %   新代码建议使用此方法以避免潜在兼容性问题
            font = ui.StyleConfig.FontFamily;
        end

        function applyButtonStyle(btn, type)
            % applyButtonStyle 应用按钮样式
            %
            % 输入:
            %   btn  - uibutton 对象
            %   type - 样式类型: 'primary'|'secondary'|'success'|'warning'|'danger'|'disabled'
            %
            % 示例:
            %   ui.StyleConfig.applyButtonStyle(btn, 'success');

            % 输入验证
            if nargin < 1 || isempty(btn)
                warning('StyleConfig:InvalidInput', '按钮对象不能为空');
                return;
            end

            if ~isgraphics(btn)
                warning('StyleConfig:InvalidButton', '无效的图形对象');
                return;
            end

            % 检查必要属性是否存在
            if ~isprop(btn, 'BackgroundColor') || ~isprop(btn, 'FontColor')
                warning('StyleConfig:InvalidButton', '对象缺少必要的样式属性');
                return;
            end

            if nargin < 2 || isempty(type)
                type = 'primary';
            end

            btn.FontName = ui.StyleConfig.FontFamily;
            btn.FontSize = ui.StyleConfig.FontSizeNormal;
            btn.FontWeight = 'bold';

            switch type
                case 'primary'
                    btn.BackgroundColor = ui.StyleConfig.PrimaryColor;
                    btn.FontColor = ui.StyleConfig.TextLight;
                case 'secondary'
                    btn.BackgroundColor = ui.StyleConfig.SecondaryColor;
                    btn.FontColor = ui.StyleConfig.TextLight;
                case 'success'
                    btn.BackgroundColor = ui.StyleConfig.SuccessColor;
                    btn.FontColor = ui.StyleConfig.TextLight;
                case 'warning'
                    btn.BackgroundColor = ui.StyleConfig.WarningColor;
                    btn.FontColor = ui.StyleConfig.TextPrimary;
                case 'danger'
                    btn.BackgroundColor = ui.StyleConfig.ErrorColor;
                    btn.FontColor = ui.StyleConfig.TextLight;
                case 'disabled'
                    btn.BackgroundColor = ui.StyleConfig.DisabledColor;
                    btn.FontColor = ui.StyleConfig.TextLight;
                    btn.Enable = 'off';
                otherwise
                    % 默认使用 primary 样式
                    btn.BackgroundColor = ui.StyleConfig.PrimaryColor;
                    btn.FontColor = ui.StyleConfig.TextLight;
            end
        end

        function applyPanelStyle(panel)
            % 应用面板样式
            panel.BackgroundColor = ui.StyleConfig.PanelColor;
            panel.FontName = ui.StyleConfig.FontFamily;
            panel.FontSize = ui.StyleConfig.FontSizeNormal;
            panel.ForegroundColor = ui.StyleConfig.TextPrimary;
        end

        function applyLabelStyle(label, type)
            % 应用标签样式
            % label - uilabel 对象
            % type  - 样式类型: 'title'|'header'|'subheader'|'normal'|'small'

            if nargin < 2 || isempty(type)
                type = 'normal';
            end

            label.FontName = ui.StyleConfig.FontFamily;
            label.FontColor = ui.StyleConfig.TextPrimary;

            switch type
                case 'title'
                    label.FontSize = ui.StyleConfig.FontSizeTitle;
                    label.FontWeight = 'bold';
                case 'header'
                    label.FontSize = ui.StyleConfig.FontSizeHeader;
                    label.FontWeight = 'bold';
                case 'subheader'
                    label.FontSize = ui.StyleConfig.FontSizeSubheader;
                    label.FontWeight = 'bold';
                case 'normal'
                    label.FontSize = ui.StyleConfig.FontSizeNormal;
                    label.FontWeight = 'normal';
                case 'small'
                    label.FontSize = ui.StyleConfig.FontSizeSmall;
                    label.FontWeight = 'normal';
                    label.FontColor = ui.StyleConfig.TextSecondary;
            end
        end

        function applyEditFieldStyle(ef, type)
            % 应用输入框样式
            % ef   - uieditfield 对象
            % type - 样式类型: 'normal'|'readonly'|'error'

            if nargin < 2 || isempty(type)
                type = 'normal';
            end

            ef.FontName = ui.StyleConfig.FontFamily;
            ef.FontSize = ui.StyleConfig.FontSizeNormal;
            ef.FontColor = ui.StyleConfig.TextPrimary;
            ef.BackgroundColor = ui.StyleConfig.PanelColor;

            switch type
                case 'normal'
                    % 默认样式
                case 'readonly'
                    ef.Editable = 'off';
                    ef.BackgroundColor = ui.StyleConfig.BackgroundColor;
                case 'error'
                    ef.BackgroundColor = ui.StyleConfig.ErrorFieldBg;
            end
        end

        function applyTableStyle(table)
            % 应用表格样式
            table.FontName = ui.StyleConfig.FontFamilyMono;
            table.FontSize = ui.StyleConfig.TableFontSize;
            table.BackgroundColor = ui.StyleConfig.PanelColor;
            table.ForegroundColor = ui.StyleConfig.TextPrimary;
            table.RowStriping = 'on';
        end

        function grid = createControlPanelGrid(parent, numRows)
            % createControlPanelGrid 创建统一的控制面板网格布局
            %
            % 输入:
            %   parent  - 父容器（通常是 ControlPanel）
            %   numRows - 总行数（包含标题行，第1行为标题）
            %
            % 输出:
            %   grid - uigridlayout 对象
            %
            % 示例:
            %   controlGrid = ui.StyleConfig.createControlPanelGrid(obj.ControlPanel, 7);

            rowHeights = cell(1, numRows);
            rowHeights{1} = ui.StyleConfig.ControlPanelTitleHeight;
            for i = 2:numRows
                rowHeights{i} = ui.StyleConfig.ControlPanelRowHeight;
            end

            grid = uigridlayout(parent, [numRows, 2]);
            grid.ColumnWidth = ui.StyleConfig.ControlPanelColumnWidth;
            grid.RowHeight = rowHeights;
            grid.Padding = ui.StyleConfig.ControlPanelPadding;
            grid.RowSpacing = ui.StyleConfig.ControlPanelRowSpacing;
            grid.ColumnSpacing = ui.StyleConfig.ControlPanelColumnSpacing;
            grid.BackgroundColor = ui.StyleConfig.PanelColor;
        end

        function grid = createDataPanelGrid(parent, tableHeight, resultHeight)
            % createDataPanelGrid 创建统一的数据面板网格布局
            %
            % 输入:
            %   parent       - 父容器（通常是 DataPanel）
            %   tableHeight  - 数据表格高度 ('1x' 或具体像素值)
            %   resultHeight - 结果区域高度（像素值）
            %
            % 输出:
            %   grid - uigridlayout 对象
            %
            % 示例:
            %   dataPanelGrid = ui.StyleConfig.createDataPanelGrid(obj.DataPanel, '1x', 120);

            grid = uigridlayout(parent, [3, 1]);
            grid.RowHeight = {ui.StyleConfig.DataPanelTitleHeight, tableHeight, resultHeight};
            grid.Padding = ui.StyleConfig.DataPanelPadding;
            grid.RowSpacing = ui.StyleConfig.DataPanelRowSpacing;
            grid.BackgroundColor = ui.StyleConfig.PanelColor;
        end

        function label = createPanelTitle(parent, text)
            % createPanelTitle 创建统一的面板标题标签
            %
            % 输入:
            %   parent - 父容器
            %   text   - 标题文本
            %
            % 输出:
            %   label - uilabel 对象

            label = uilabel(parent);
            label.Text = text;
            label.FontName = ui.StyleConfig.FontFamily;
            label.FontSize = ui.StyleConfig.PanelTitleFontSize;
            label.FontWeight = 'bold';
            label.FontColor = ui.StyleConfig.PrimaryColor;
            label.BackgroundColor = ui.StyleConfig.PanelColor;
            label.HorizontalAlignment = 'center';
        end

        function label = createParamLabel(parent, text)
            % createParamLabel 创建统一的参数标签
            %
            % 输入:
            %   parent - 父容器
            %   text   - 标签文本
            %
            % 输出:
            %   label - uilabel 对象

            label = uilabel(parent);
            label.Text = text;
            label.FontName = ui.StyleConfig.FontFamily;
            label.FontSize = ui.StyleConfig.PanelLabelFontSize;
            label.FontColor = ui.StyleConfig.TextSecondary;
            label.BackgroundColor = ui.StyleConfig.PanelColor;
            label.HorizontalAlignment = 'right';
        end

        function label = createParamValue(parent, initialText)
            % createParamValue 创建统一的参数值显示标签
            %
            % 输入:
            %   parent      - 父容器
            %   initialText - 初始显示文本
            %
            % 输出:
            %   label - uilabel 对象

            if nargin < 2
                initialText = '--';
            end

            label = uilabel(parent);
            label.Text = initialText;
            label.FontName = ui.StyleConfig.FontFamilyMono;
            label.FontSize = ui.StyleConfig.PanelValueFontSize;
            label.FontWeight = 'bold';
            label.FontColor = ui.StyleConfig.TextPrimary;
            label.BackgroundColor = ui.StyleConfig.PanelColor;
            label.HorizontalAlignment = 'left';
        end

        function label = createResultLabel(parent, text)
            % createResultLabel 创建统一的结果标签
            %
            % 输入:
            %   parent - 父容器
            %   text   - 标签文本
            %
            % 输出:
            %   label - uilabel 对象

            label = uilabel(parent);
            label.Text = text;
            label.FontName = ui.StyleConfig.FontFamily;
            label.FontSize = ui.StyleConfig.PanelLabelFontSize;
            label.FontColor = ui.StyleConfig.TextSecondary;
            label.BackgroundColor = ui.StyleConfig.PanelColor;
            label.HorizontalAlignment = 'right';
        end

        function label = createResultValue(parent, initialText)
            % createResultValue 创建统一的结果值显示标签
            %
            % 输入:
            %   parent      - 父容器
            %   initialText - 初始显示文本
            %
            % 输出:
            %   label - uilabel 对象

            if nargin < 2
                initialText = '--';
            end

            label = uilabel(parent);
            label.Text = initialText;
            label.FontName = ui.StyleConfig.FontFamilyMono;
            label.FontSize = ui.StyleConfig.PanelValueFontSize;
            label.FontWeight = 'bold';
            label.FontColor = ui.StyleConfig.SuccessColor;
            label.BackgroundColor = ui.StyleConfig.PanelColor;
            label.HorizontalAlignment = 'left';
        end

        function grid = createResultGrid(parent, numRows)
            % createResultGrid 创建统一的结果区域网格布局
            %
            % 输入:
            %   parent  - 父容器
            %   numRows - 结果行数
            %
            % 输出:
            %   grid - uigridlayout 对象

            rowHeights = cell(1, numRows);
            for i = 1:numRows
                rowHeights{i} = ui.StyleConfig.DataPanelResultRowHeight;
            end

            grid = uigridlayout(parent, [numRows, 2]);
            grid.ColumnWidth = {'fit', '1x'};
            grid.RowHeight = rowHeights;
            grid.Padding = [5, 5, 5, 5];
            grid.RowSpacing = ui.StyleConfig.DataPanelRowSpacing;
            grid.ColumnSpacing = ui.StyleConfig.DataPanelColumnSpacing;
            grid.BackgroundColor = ui.StyleConfig.LightBackground;
        end

        function table = createDataTable(parent, columnNames, columnWidths)
            % createDataTable 创建统一样式的数据表格
            %
            % 输入:
            %   parent       - 父容器
            %   columnNames  - 列名 cell 数组
            %   columnWidths - 列宽配置 cell 数组（可选）
            %
            % 输出:
            %   table - uitable 对象

            table = uitable(parent);
            table.ColumnName = columnNames;
            if nargin >= 3 && ~isempty(columnWidths)
                table.ColumnWidth = columnWidths;
            end
            table.RowName = {};
            table.FontName = ui.StyleConfig.FontFamilyMono;
            table.FontSize = ui.StyleConfig.TableFontSize;
            table.BackgroundColor = ui.StyleConfig.PanelColor;
            table.ForegroundColor = ui.StyleConfig.TextPrimary;
            table.RowStriping = 'on';
        end

        function applyAxesStyle(ax)
            % 应用坐标轴样式
            % ax - uiaxes 或 axes 对象

            ax.FontName = ui.StyleConfig.FontFamily;
            ax.FontSize = ui.StyleConfig.FontSizeSmall;
            ax.Color = ui.StyleConfig.PanelColor;
            ax.XColor = ui.StyleConfig.TextPrimary;
            ax.YColor = ui.StyleConfig.TextPrimary;
            ax.GridColor = ui.StyleConfig.GridColor;
            ax.GridAlpha = ui.StyleConfig.GridAlpha;
            ax.GridLineStyle = '-';
            ax.MinorGridLineStyle = ':';
            ax.Box = 'on';
            ax.LineWidth = ui.StyleConfig.AxesLineWidth;
            grid(ax, 'on');
        end

        function pos = centerWindow(windowSize)
            % 计算窗口居中位置
            % 处理多显示器和小屏幕场景

            screenSize = get(0, 'ScreenSize');
            screenWidth = screenSize(3);
            screenHeight = screenSize(4);

            % 预留边距（任务栏等）
            margin = ui.StyleConfig.WindowMargin;
            maxWidth = screenWidth - margin;
            maxHeight = screenHeight - margin;

            % 如果窗口尺寸超出屏幕，按比例缩放
            winWidth = windowSize(1);
            winHeight = windowSize(2);
            if winWidth > maxWidth || winHeight > maxHeight
                scale = min(maxWidth / winWidth, maxHeight / winHeight);
                winWidth = floor(winWidth * scale);
                winHeight = floor(winHeight * scale);
            end

            % 居中计算
            x = (screenWidth - winWidth) / 2;
            y = (screenHeight - winHeight) / 2;

            % 确保窗口不会超出屏幕边界（处理负坐标）
            x = max(ui.StyleConfig.WindowMinX, x);
            y = max(ui.StyleConfig.WindowMinY, y);  % 底部预留任务栏空间

            pos = [x, y, winWidth, winHeight];
        end

        function path = getResourcePath(filename)
            % 获取资源文件完整路径
            basePath = fileparts(fileparts(mfilename('fullpath')));
            path = fullfile(basePath, 'resources', filename);
        end

        function path = getDataPath(filename)
            % getDataPath 获取数据资源完整路径
            %   支持开发环境和部署环境
            path = ui.StyleConfig.getResourceSubPath(ui.StyleConfig.DataSubdir, filename);
        end

        function path = getImagePath(filename)
            % getImagePath 获取图片资源完整路径
            %   支持开发环境和部署环境
            path = ui.StyleConfig.getResourceSubPath(ui.StyleConfig.ImageSubdir, filename);
        end
    end

    methods (Static, Access = private)
        function path = getResourceSubPath(subdir, filename)
            % getResourceSubPath 获取资源子目录文件的完整路径（内部方法）
            %
            % 输入:
            %   subdir   - 资源子目录名称 ('images', 'data' 等)
            %   filename - 文件名
            %
            % 输出:
            %   path - 文件完整路径

            if isdeployed
                % 部署环境：按优先级尝试多个可能的路径
                possiblePaths = {
                    fullfile(ctfroot, 'resources', subdir, filename);
                    fullfile(ctfroot, subdir, filename);
                    fullfile(ctfroot, filename)
                };

                for i = 1:length(possiblePaths)
                    if isfile(possiblePaths{i})
                        path = possiblePaths{i};
                        return;
                    end
                end
                % 未找到文件，返回默认路径（调用方需处理文件不存在情况）
                path = possiblePaths{1};
            else
                % 开发环境：直接使用项目相对路径
                basePath = fileparts(fileparts(mfilename('fullpath')));
                path = fullfile(basePath, 'resources', subdir, filename);
            end
        end
    end
end
