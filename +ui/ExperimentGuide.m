classdef ExperimentGuide < handle
    % ExperimentGuide 实验流程引导类
    % 用于规范实验操作顺序，提供操作指引和错误提示
    %
    % 功能：
    %   - 定义实验步骤序列（支持线性和非线性流程）
    %   - 追踪当前进度
    %   - 验证操作顺序
    %   - 提供下一步操作指引
    %   - 显示错误/漏操作提示

    properties (Access = private)
        Steps               % 步骤定义 struct array
        CurrentStepIndex    % 当前步骤索引
        CompletedSteps      % 已完成的步骤ID列表
        ParentFigure        % 父窗口（用于显示提示）
        StatusCallback      % 状态更新回调函数

        % 重复流程支持
        RepeatGroups        % 重复组定义 {groupId, stepIds[], requiredCount}
        RepeatProgress      % 重复进度 containers.Map(groupId -> currentCount)
    end

    properties (Constant)
        % 提示类型
        TIP_INFO = 'info'
        TIP_WARNING = 'warning'
        TIP_ERROR = 'error'
        TIP_SUCCESS = 'success'
    end

    events
        StepCompleted       % 步骤完成事件
        AllStepsCompleted   % 所有步骤完成事件
        OperationError      % 操作错误事件
    end

    methods (Access = public)
        function obj = ExperimentGuide(parentFigure, statusCallback)
            % 构造函数
            % parentFigure - 父窗口句柄（用于显示提示对话框）
            % statusCallback - 状态更新回调 @(message)

            obj.ParentFigure = parentFigure;
            obj.StatusCallback = statusCallback;
            obj.Steps = struct('id', {}, 'name', {}, 'description', {}, ...
                'prerequisites', {}, 'optional', {}, 'group', {}, 'repeatIndex', {});
            obj.CurrentStepIndex = 1;
            obj.CompletedSteps = {};
            obj.RepeatGroups = {};
            obj.RepeatProgress = containers.Map();
        end

        function addStep(obj, id, name, description, varargin)
            % 添加实验步骤
            % id - 步骤唯一标识
            % name - 步骤名称（如 "1. 称量内筒"）
            % description - 步骤详细描述
            % 可选参数：
            %   'Prerequisites', {stepIds} - 前置步骤ID列表
            %   'Optional', true/false - 是否可选步骤
            %   'RepeatGroup', groupId - 所属重复组ID
            %   'RepeatIndex', index - 在重复组中的索引

            % 检查ID唯一性
            if obj.findStepIndex(id) > 0
                warning('ExperimentGuide:DuplicateStep', '步骤ID "%s" 已存在，将更新现有步骤', id);
                obj.removeStep(id);
            end

            p = inputParser;
            addParameter(p, 'Prerequisites', {});
            addParameter(p, 'Optional', false);
            addParameter(p, 'RepeatGroup', '');
            addParameter(p, 'RepeatIndex', 0);
            parse(p, varargin{:});

            step.id = id;
            step.name = name;
            step.description = description;
            step.prerequisites = p.Results.Prerequisites;
            step.optional = p.Results.Optional;
            step.group = p.Results.RepeatGroup;
            step.repeatIndex = p.Results.RepeatIndex;

            obj.Steps(end+1) = step;
        end

        function removeStep(obj, stepId)
            % 移除指定步骤
            idx = obj.findStepIndex(stepId);
            if idx > 0
                obj.Steps(idx) = [];
            end
        end

        function addRepeatGroup(obj, groupId, requiredCount, description)
            % 添加重复组（用于需要重复多次的步骤序列）
            % groupId - 重复组ID
            % requiredCount - 需要完成的次数
            % description - 重复组描述

            % 检查重复组ID唯一性
            existingGroup = obj.findRepeatGroup(groupId);
            if ~isempty(existingGroup)
                warning('ExperimentGuide:DuplicateGroup', '重复组ID "%s" 已存在', groupId);
                return;
            end

            group.id = groupId;
            group.requiredCount = requiredCount;
            group.description = description;

            obj.RepeatGroups{end+1} = group;
            obj.RepeatProgress(groupId) = 0;
        end

        function [canProceed, message] = validateOperation(obj, stepId)
            % 验证操作是否可执行
            % 返回：canProceed - 是否可以执行
            %       message - 提示信息

            % 查找步骤
            stepIdx = obj.findStepIndex(stepId);
            if stepIdx == 0
                canProceed = false;
                message = sprintf('未知的操作步骤: %s', stepId);
                return;
            end

            step = obj.Steps(stepIdx);

            % 检查前置步骤是否完成
            if ~isempty(step.prerequisites)
                missingPrereqs = {};
                for i = 1:length(step.prerequisites)
                    prereqId = step.prerequisites{i};
                    if ~ismember(prereqId, obj.CompletedSteps)
                        prereqIdx = obj.findStepIndex(prereqId);
                        if prereqIdx > 0
                            missingPrereqs{end+1} = obj.Steps(prereqIdx).name; %#ok<AGROW>
                        end
                    end
                end

                if ~isempty(missingPrereqs)
                    canProceed = false;
                    message = sprintf('请先完成以下步骤：\n• %s', strjoin(missingPrereqs, '\n• '));
                    return;
                end
            end

            % 检查是否已完成
            if ismember(stepId, obj.CompletedSteps)
                % 检查是否属于重复组
                if ~isempty(step.group)
                    group = obj.findRepeatGroup(step.group);
                    if ~isempty(group) && obj.RepeatProgress(step.group) < group.requiredCount
                        canProceed = true;
                        currentCount = obj.RepeatProgress(step.group);
                        message = sprintf('第 %d/%d 次测量', currentCount + 1, group.requiredCount);
                        return;
                    end
                end
                canProceed = false;
                message = sprintf('步骤 "%s" 已完成', step.name);
                return;
            end

            canProceed = true;
            message = step.description;
        end

        function completeStep(obj, stepId)
            % 标记步骤完成
            %
            % 更新 CompletedSteps 和 RepeatProgress：
            %   - CompletedSteps 记录“是否达成过”（去重）
            %   - RepeatProgress 记录“完成次数”（可累加）

            % 先更新重复组进度（不受 CompletedSteps 去重影响）
            stepIdx = obj.findStepIndex(stepId);
            if stepIdx > 0
                step = obj.Steps(stepIdx);
                if ~isempty(step.group) && obj.RepeatProgress.isKey(step.group)
                    obj.RepeatProgress(step.group) = obj.RepeatProgress(step.group) + 1;
                end
            end

            % 添加到已完成列表（去重）
            if ~ismember(stepId, obj.CompletedSteps)
                obj.CompletedSteps{end+1} = stepId;
            end

            % 触发事件
            notify(obj, 'StepCompleted');

            % 检查是否全部完成
            if obj.isAllCompleted()
                notify(obj, 'AllStepsCompleted');
            end
        end

        function resetStep(obj, stepId)
            % 重置步骤（用于重复测量）
            idx = find(strcmp(obj.CompletedSteps, stepId), 1);
            if ~isempty(idx)
                obj.CompletedSteps(idx) = [];
            end
        end

        function resetGroup(obj, groupId)
            % 重置重复组
            if obj.RepeatProgress.isKey(groupId)
                obj.RepeatProgress(groupId) = 0;
            end

            % 重置组内所有步骤（通过遍历Steps查找属于该组的步骤）
            for i = 1:length(obj.Steps)
                if strcmp(obj.Steps(i).group, groupId)
                    obj.resetStep(obj.Steps(i).id);
                end
            end
        end

        function reset(obj)
            % 重置所有进度
            obj.CurrentStepIndex = 1;
            obj.CompletedSteps = {};

            keys = obj.RepeatProgress.keys;
            for i = 1:length(keys)
                obj.RepeatProgress(keys{i}) = 0;
            end
        end

        function hint = getNextStepHint(obj)
            % 获取下一步操作提示（简短版本，用于状态栏）
            for i = 1:length(obj.Steps)
                step = obj.Steps(i);
                if ~ismember(step.id, obj.CompletedSteps)
                    % 检查是否可以执行
                    [canDo, ~] = obj.validateOperation(step.id);
                    if canDo
                        hint = sprintf('下一步: %s', step.name);
                        return;
                    end
                end
            end

            % 检查重复组
            for i = 1:length(obj.RepeatGroups)
                group = obj.RepeatGroups{i};
                if obj.RepeatProgress(group.id) < group.requiredCount
                    remaining = group.requiredCount - obj.RepeatProgress(group.id);
                    hint = sprintf('%s (还需%d次)', group.description, remaining);
                    return;
                end
            end

            hint = '所有步骤已完成';
        end

        function progress = getProgress(obj)
            % 获取实验进度
            totalSteps = length(obj.Steps);
            completedCount = length(obj.CompletedSteps);

            % 计算重复组进度
            totalRepeats = 0;
            completedRepeats = 0;
            for i = 1:length(obj.RepeatGroups)
                group = obj.RepeatGroups{i};
                totalRepeats = totalRepeats + group.requiredCount;
                completedRepeats = completedRepeats + min(obj.RepeatProgress(group.id), group.requiredCount);
            end

            % 避免除零
            totalWork = totalSteps + totalRepeats;
            if totalWork == 0
                progress = 1;  % 无步骤视为已完成
            else
                progress = (completedCount + completedRepeats) / totalWork;
            end
        end

        function completed = isAllCompleted(obj)
            % 检查是否所有步骤完成

            % 检查必选步骤
            for i = 1:length(obj.Steps)
                step = obj.Steps(i);
                if ~step.optional && ~ismember(step.id, obj.CompletedSteps)
                    % 如果是重复组步骤，检查是否满足次数
                    if ~isempty(step.group)
                        group = obj.findRepeatGroup(step.group);
                        if isempty(group) || obj.RepeatProgress(step.group) < group.requiredCount
                            completed = false;
                            return;
                        end
                    else
                        completed = false;
                        return;
                    end
                end
            end

            % 检查重复组
            for i = 1:length(obj.RepeatGroups)
                group = obj.RepeatGroups{i};
                if obj.RepeatProgress(group.id) < group.requiredCount
                    completed = false;
                    return;
                end
            end

            completed = true;
        end

        function showOperationError(obj, stepId, errorType)
            % 显示操作错误提示
            % errorType: 'wrong_order' | 'missing_prereq' | 'already_done' | 'not_ready'

            stepIdx = obj.findStepIndex(stepId);
            if stepIdx == 0
                return;
            end
            step = obj.Steps(stepIdx);

            switch errorType
                case 'wrong_order'
                    title = '操作顺序错误';
                    message = sprintf('请按照正确顺序操作。\n\n当前尝试：%s\n\n%s', ...
                        step.name, obj.getNextStepHint());
                    icon = 'warning';

                case 'missing_prereq'
                    [~, prereqMsg] = obj.validateOperation(stepId);
                    title = '前置条件未满足';
                    message = sprintf('无法执行 "%s"\n\n%s', step.name, prereqMsg);
                    icon = 'warning';

                case 'already_done'
                    title = '步骤已完成';
                    if ~isempty(step.group)
                        group = obj.findRepeatGroup(step.group);
                        if ~isempty(group)
                            message = sprintf('"%s" 已完成 %d/%d 次测量。\n\n%s', ...
                                step.name, obj.RepeatProgress(step.group), ...
                                group.requiredCount, obj.getNextStepHint());
                        else
                            message = sprintf('"%s" 已完成。\n\n%s', step.name, obj.getNextStepHint());
                        end
                    else
                        message = sprintf('"%s" 已完成。\n\n%s', step.name, obj.getNextStepHint());
                    end
                    icon = 'info';

                case 'not_ready'
                    title = '条件不满足';
                    message = sprintf('当前无法执行 "%s"。\n\n请检查实验条件是否满足。', step.name);
                    icon = 'warning';

                otherwise
                    title = '操作提示';
                    message = step.description;
                    icon = 'info';
            end

            % 显示提示对话框
            if ~isempty(obj.ParentFigure) && isvalid(obj.ParentFigure)
                uialert(obj.ParentFigure, message, title, 'Icon', icon);
            end

            % 通过回调更新状态栏
            if ~isempty(obj.StatusCallback)
                obj.StatusCallback(sprintf('[%s] %s', title, step.name));
            end

            % 触发错误事件
            notify(obj, 'OperationError');
        end

        function showProgressDialog(obj)
            % 显示实验进度对话框
            if isempty(obj.ParentFigure) || ~isvalid(obj.ParentFigure)
                return;
            end

            % 构建进度信息
            lines = {'【实验进度】', ''};

            for i = 1:length(obj.Steps)
                step = obj.Steps(i);
                if ismember(step.id, obj.CompletedSteps)
                    status = '✓';
                else
                    status = '○';
                end

                if ~isempty(step.group)
                    group = obj.findRepeatGroup(step.group);
                    if ~isempty(group)
                        count = obj.RepeatProgress(step.group);
                        lines{end+1} = sprintf('%s %s (%d/%d)', status, step.name, ...
                            count, group.requiredCount); %#ok<AGROW>
                    else
                        lines{end+1} = sprintf('%s %s', status, step.name); %#ok<AGROW>
                    end
                else
                    lines{end+1} = sprintf('%s %s', status, step.name); %#ok<AGROW>
                end
            end

            lines{end+1} = '';
            lines{end+1} = sprintf('完成进度: %.0f%%', obj.getProgress() * 100);

            uialert(obj.ParentFigure, strjoin(lines, '\n'), '实验进度', 'Icon', 'info');
        end
    end

    methods (Access = private)
        function idx = findStepIndex(obj, stepId)
            % 查找步骤索引
            idx = 0;
            for i = 1:length(obj.Steps)
                if strcmp(obj.Steps(i).id, stepId)
                    idx = i;
                    return;
                end
            end
        end

        function group = findRepeatGroup(obj, groupId)
            % 查找重复组
            group = [];
            for i = 1:length(obj.RepeatGroups)
                if strcmp(obj.RepeatGroups{i}.id, groupId)
                    group = obj.RepeatGroups{i};
                    return;
                end
            end
        end
    end
end
