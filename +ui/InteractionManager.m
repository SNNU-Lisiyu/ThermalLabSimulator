classdef InteractionManager < handle
    % InteractionManager 交互管理器
    % 管理实验界面中仪器的点击交互功能
    %
    % 功能：
    %   - 仪器可点击交互：点击仿真图中的温度计/压力表/阀门等触发操作
    %   - 高亮显示可交互区域
    %   - 交互反馈效果

    properties (Access = private)
        Axes                    % 关联的坐标轴
        InteractiveZones        % 可交互区域定义
        HighlightPatches        % 高亮区域图形对象（缓存句柄）
        HoverPatch              % 悬停高亮图形对象句柄
        HoverLabel              % 悬停标签句柄
        TooltipLabel            % 工具提示标签
        HoverZone               % 当前悬停的区域
        Enabled = true          % 是否启用交互
        FeedbackTimers = {}     % 点击反馈定时器列表
        ParentFigure            % 父窗口引用
        OriginalMotionFcn       % 原始鼠标移动回调
        LastMouseMoveTime = 0   % 上次鼠标移动处理时间戳（用于节流）
        ThrottleTicRef          % tic 计时器引用
    end

    properties (Constant)
        % 高亮样式
        HighlightColor = [0.2, 0.6, 1]      % 高亮边框颜色
        HighlightAlpha = 0.15               % 高亮填充透明度
        HoverAlpha = 0.25                   % 悬停时透明度
        ClickFeedbackDuration = 0.15        % 点击反馈持续时间(秒)
    end

    events
        ZoneClicked     % 区域被点击事件
    end

    methods (Access = public)
        function obj = InteractionManager(ax)
            % 构造函数
            % 输入: ax - 要管理的坐标轴对象

            if nargin > 0
                obj.Axes = ax;
                obj.InteractiveZones = struct('id', {}, 'position', {}, ...
                    'label', {}, 'callback', {}, 'enabled', {}, 'cursor', {});
                obj.HighlightPatches = {};
                obj.setupMouseCallbacks();
            end
        end

        function addZone(obj, id, position, label, callback, varargin)
            % 添加可交互区域
            % 输入:
            %   id - 区域唯一标识符
            %   position - [x, y, width, height] 区域位置（数据坐标）
            %   label - 显示的标签/提示文本
            %   callback - 点击时执行的回调函数
            %   varargin - 可选参数：'Enabled', true/false; 'Cursor', 'hand'/'arrow'

            p = inputParser;
            addParameter(p, 'Enabled', true);
            addParameter(p, 'Cursor', 'hand');
            parse(p, varargin{:});

            zone.id = id;
            zone.position = position;  % [x, y, width, height]
            zone.label = label;
            zone.callback = callback;
            zone.enabled = p.Results.Enabled;
            zone.cursor = p.Results.Cursor;

            % 检查是否已存在同ID区域
            existingIdx = find(strcmp({obj.InteractiveZones.id}, id), 1);
            if ~isempty(existingIdx)
                obj.InteractiveZones(existingIdx) = zone;
            else
                obj.InteractiveZones(end+1) = zone;
            end
        end

        function removeZone(obj, id)
            % 移除可交互区域
            idx = find(strcmp({obj.InteractiveZones.id}, id), 1);
            if ~isempty(idx)
                obj.InteractiveZones(idx) = [];
            end
        end

        function clearZones(obj)
            % 清除所有可交互区域
            obj.InteractiveZones = struct('id', {}, 'position', {}, ...
                'label', {}, 'callback', {}, 'enabled', {}, 'cursor', {});
            obj.clearHighlights();
        end

        function setZoneEnabled(obj, id, enabled)
            % 设置区域启用/禁用状态
            idx = find(strcmp({obj.InteractiveZones.id}, id), 1);
            if ~isempty(idx)
                obj.InteractiveZones(idx).enabled = enabled;
            end
        end

        function showHighlights(obj, zoneIds)
            % 显示指定区域的高亮
            % 输入: zoneIds - 区域ID的cell数组，或'all'显示所有

            obj.clearHighlights();

            if ischar(zoneIds) && strcmp(zoneIds, 'all')
                zonesToHighlight = obj.InteractiveZones;
            else
                if ischar(zoneIds)
                    zoneIds = {zoneIds};
                end
                zonesToHighlight = obj.InteractiveZones(ismember({obj.InteractiveZones.id}, zoneIds));
            end

            holdState = ishold(obj.Axes);
            hold(obj.Axes, 'on');
            for i = 1:length(zonesToHighlight)
                zone = zonesToHighlight(i);
                if zone.enabled
                    pos = zone.position;
                    % 创建高亮矩形（缓存句柄）
                    h = patch(obj.Axes, ...
                        [pos(1), pos(1)+pos(3), pos(1)+pos(3), pos(1)], ...
                        [pos(2), pos(2), pos(2)+pos(4), pos(2)+pos(4)], ...
                        obj.HighlightColor, ...
                        'FaceAlpha', obj.HighlightAlpha, ...
                        'EdgeColor', obj.HighlightColor, ...
                        'LineWidth', 2, ...
                        'LineStyle', '--', ...
                        'Tag', ['highlight_' zone.id], ...
                        'PickableParts', 'none');
                    obj.HighlightPatches{end+1} = h;
                end
            end
            if ~holdState, hold(obj.Axes, 'off'); end
        end

        function clearHighlights(obj)
            % 清除所有高亮显示（使用缓存句柄，避免 findobj）
            for i = 1:length(obj.HighlightPatches)
                h = obj.HighlightPatches{i};
                if ~isempty(h) && isvalid(h)
                    delete(h);
                end
            end
            obj.HighlightPatches = {};
        end

        function setEnabled(obj, enabled)
            % 设置整体交互启用/禁用
            obj.Enabled = enabled;
            if ~enabled
                obj.clearHighlights();
            end
        end

        function delete(obj)
            % 析构函数
            obj.clearHighlights();

            % 清理工具提示标签
            if ~isempty(obj.TooltipLabel) && isvalid(obj.TooltipLabel)
                delete(obj.TooltipLabel);
            end

            % 清理所有反馈定时器
            timersToClean = obj.FeedbackTimers;
            obj.FeedbackTimers = {};
            for i = 1:length(timersToClean)
                if ~isempty(timersToClean{i}) && isvalid(timersToClean{i})
                    try
                        timersToClean{i}.StopFcn = '';
                        stop(timersToClean{i});
                        delete(timersToClean{i});
                    catch
                        % 忽略定时器清理错误
                    end
                end
            end

            % 恢复原始鼠标移动回调
            if ~isempty(obj.ParentFigure) && isvalid(obj.ParentFigure)
                try
                    obj.ParentFigure.WindowButtonMotionFcn = obj.OriginalMotionFcn;
                catch
                    % 忽略恢复错误
                end
            end
        end
    end

    methods (Access = private)
        function valid = isAxesValid(obj)
            % isAxesValid 检查坐标轴是否有效
            valid = ~isempty(obj.Axes) && isvalid(obj.Axes);
        end

        function setupMouseCallbacks(obj)
            % 设置鼠标事件回调
            if ~obj.isAxesValid()
                return;
            end

            % 获取父Figure
            fig = ancestor(obj.Axes, 'figure');
            if isempty(fig)
                return;
            end

            % 设置坐标轴的鼠标回调
            obj.Axes.ButtonDownFcn = @(src, evt) obj.onAxesClick(src, evt);

            % 设置Figure级别的鼠标移动回调（用于悬停效果）
            % 保存原始回调以便析构时恢复
            if isprop(fig, 'WindowButtonMotionFcn')
                obj.ParentFigure = fig;
                obj.OriginalMotionFcn = fig.WindowButtonMotionFcn;
                fig.WindowButtonMotionFcn = @(src, evt) obj.onMouseMove(src, evt, obj.OriginalMotionFcn);
            end
        end

        function onAxesClick(obj, ~, evt)
            % 坐标轴点击事件处理
            if ~obj.Enabled
                return;
            end

            % 获取点击位置（数据坐标）
            clickPoint = evt.IntersectionPoint(1:2);

            % 查找点击的区域
            clickedZone = obj.findZoneAtPoint(clickPoint);

            if ~isempty(clickedZone) && clickedZone.enabled
                % 提供点击反馈
                obj.showClickFeedback(clickedZone);

                % 触发回调
                if ~isempty(clickedZone.callback) && isa(clickedZone.callback, 'function_handle')
                    try
                        clickedZone.callback(clickedZone.id);
                    catch ME
                        warning('InteractionManager:CallbackError', ...
                            '区域 %s 的回调执行失败: %s', clickedZone.id, ME.message);
                    end
                end

                % 触发事件
                notify(obj, 'ZoneClicked', ui.InteractionEventData(clickedZone.id, clickPoint));
            end
        end

        function onMouseMove(obj, src, ~, existingFcn)
            % 鼠标移动事件处理（用于悬停效果）

            % 先执行已有的回调
            if ~isempty(existingFcn)
                try
                    existingFcn(src, []);
                catch ME
                    utils.Logger.logDebug(ME.message, 'InteractionManager:OriginalMotionFcn');
                end
            end

            if ~obj.Enabled || ~obj.isAxesValid()
                return;
            end

            % 节流：最小30ms间隔，避免高频鼠标事件消耗性能
            if ~isempty(obj.ThrottleTicRef)
                if toc(obj.ThrottleTicRef) < 0.03
                    return;
                end
            end
            obj.ThrottleTicRef = tic;

            % 获取鼠标在坐标轴中的位置
            try
                mousePoint = obj.getMousePositionInAxes(src);
                if isempty(mousePoint)
                    obj.updateHover([]);
                    return;
                end

                % 查找悬停的区域
                hoveredZone = obj.findZoneAtPoint(mousePoint);
                obj.updateHover(hoveredZone);
            catch ME
                utils.Logger.logDebug(ME.message, 'InteractionManager:MouseMove');
            end
        end

        function point = getMousePositionInAxes(obj, fig)
            % 获取鼠标在坐标轴数据坐标中的位置
            point = [];

            if ~obj.isAxesValid()
                return;
            end

            % 获取坐标轴位置（像素）
            axPos = getpixelposition(obj.Axes, true);

            % 获取鼠标位置（像素，相对于Figure）
            mousePos = fig.CurrentPoint;

            % 检查是否在坐标轴范围内
            if mousePos(1) < axPos(1) || mousePos(1) > axPos(1) + axPos(3) || ...
               mousePos(2) < axPos(2) || mousePos(2) > axPos(2) + axPos(4)
                return;
            end

            % 转换为归一化坐标（相对于坐标轴）
            normX = (mousePos(1) - axPos(1)) / axPos(3);
            normY = (mousePos(2) - axPos(2)) / axPos(4);

            % 转换为数据坐标
            xLim = obj.Axes.XLim;
            yLim = obj.Axes.YLim;

            point = [xLim(1) + normX * (xLim(2) - xLim(1)), ...
                     yLim(1) + normY * (yLim(2) - yLim(1))];
        end

        function zone = findZoneAtPoint(obj, point)
            % 查找指定点所在的区域
            zone = [];

            for i = 1:length(obj.InteractiveZones)
                z = obj.InteractiveZones(i);
                pos = z.position;

                % 检查点是否在区域内
                if point(1) >= pos(1) && point(1) <= pos(1) + pos(3) && ...
                   point(2) >= pos(2) && point(2) <= pos(2) + pos(4)
                    zone = z;
                    return;  % 返回第一个匹配的区域
                end
            end
        end

        function updateHover(obj, zone)
            % 更新悬停状态
            if isempty(zone)
                if ~isempty(obj.HoverZone)
                    % 离开之前的悬停区域
                    obj.hideHoverHighlight();
                    obj.HoverZone = [];
                    obj.updateCursor('arrow');
                end
                return;
            end

            if isempty(obj.HoverZone) || ~strcmp(obj.HoverZone.id, zone.id)
                % 进入新的悬停区域
                obj.hideHoverHighlight();
                obj.HoverZone = zone;

                if zone.enabled
                    obj.showHoverHighlight(zone);
                    obj.updateCursor(zone.cursor);
                else
                    obj.updateCursor('arrow');
                end
            end
        end

        function showHoverHighlight(obj, zone)
            % 显示悬停高亮
            if ~obj.isAxesValid()
                return;
            end

            pos = zone.position;

            holdState = ishold(obj.Axes);
            hold(obj.Axes, 'on');
            obj.HoverPatch = patch(obj.Axes, ...
                [pos(1), pos(1)+pos(3), pos(1)+pos(3), pos(1)], ...
                [pos(2), pos(2), pos(2)+pos(4), pos(2)+pos(4)], ...
                obj.HighlightColor, ...
                'FaceAlpha', obj.HoverAlpha, ...
                'EdgeColor', obj.HighlightColor, ...
                'LineWidth', 2.5, ...
                'Tag', 'hover_highlight', ...
                'PickableParts', 'none');

            % 显示标签提示
            centerX = pos(1) + pos(3)/2;
            topY = pos(2) + pos(4) + 0.02;
            obj.HoverLabel = text(obj.Axes, centerX, topY, zone.label, ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'bottom', ...
                'FontSize', 10, ...
                'FontWeight', 'bold', ...
                'Color', obj.HighlightColor, ...
                'BackgroundColor', [1, 1, 1], ...
                'EdgeColor', obj.HighlightColor, ...
                'Margin', 3, ...
                'Tag', 'hover_label');
            if ~holdState, hold(obj.Axes, 'off'); end
        end

        function hideHoverHighlight(obj)
            % 隐藏悬停高亮（使用缓存句柄，避免 findobj）
            if ~isempty(obj.HoverPatch) && isvalid(obj.HoverPatch)
                delete(obj.HoverPatch);
            end
            obj.HoverPatch = [];
            if ~isempty(obj.HoverLabel) && isvalid(obj.HoverLabel)
                delete(obj.HoverLabel);
            end
            obj.HoverLabel = [];
        end

        function showClickFeedback(obj, zone)
            % 显示点击反馈效果
            if ~obj.isAxesValid()
                return;
            end

            pos = zone.position;

            holdState = ishold(obj.Axes);
            hold(obj.Axes, 'on');
            % 创建闪烁效果
            feedbackPatch = patch(obj.Axes, ...
                [pos(1), pos(1)+pos(3), pos(1)+pos(3), pos(1)], ...
                [pos(2), pos(2), pos(2)+pos(4), pos(2)+pos(4)], ...
                [1, 1, 0.5], ...  % 黄色闪烁
                'FaceAlpha', 0.4, ...
                'EdgeColor', [1, 0.8, 0], ...
                'LineWidth', 3, ...
                'Tag', 'click_feedback', ...
                'PickableParts', 'none');
            if ~holdState, hold(obj.Axes, 'off'); end

            % 延迟删除反馈效果，存储定时器引用以便管理
            t = timer('StartDelay', obj.ClickFeedbackDuration, ...
                'TimerFcn', @(~,~) obj.removeClickFeedback(feedbackPatch), ...
                'StopFcn', @(tmr,~) obj.cleanupTimer(tmr));
            obj.FeedbackTimers{end+1} = t;
            start(t);
        end

        function cleanupTimer(obj, tmr)
            % cleanupTimer 清理完成的定时器
            if isvalid(tmr)
                delete(tmr);
            end
            % 从列表中移除
            obj.FeedbackTimers = obj.FeedbackTimers(cellfun(@isvalid, obj.FeedbackTimers));
        end

        function removeClickFeedback(~, feedbackPatch)
            % 移除点击反馈效果
            if isvalid(feedbackPatch)
                delete(feedbackPatch);
            end
        end

        function updateCursor(obj, cursorType)
            % 更新鼠标指针
            if ~obj.isAxesValid()
                return;
            end

            fig = ancestor(obj.Axes, 'figure');
            if ~isempty(fig) && isvalid(fig)
                switch cursorType
                    case 'hand'
                        fig.Pointer = 'hand';
                    case 'arrow'
                        fig.Pointer = 'arrow';
                    otherwise
                        fig.Pointer = 'arrow';
                end
            end
        end
    end
end
