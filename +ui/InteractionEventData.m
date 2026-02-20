classdef (ConstructOnLoad) InteractionEventData < event.EventData
    % InteractionEventData 交互事件数据类
    %
    % 描述:
    %   用于在交互管理器和实验模块之间传递交互事件的详细信息。
    %   继承自 event.EventData，可用于 MATLAB 事件系统。
    %
    % 属性:
    %   ZoneId        - 被点击区域的标识符 (char)
    %   ClickPosition - 点击位置坐标 [x, y] (double)
    %
    % 使用示例:
    %   eventData = ui.InteractionEventData('zone1', [100, 200]);
    %   notify(obj, 'ZoneClicked', eventData);
    %
    % 另见:
    %   ui.InteractionManager, event.EventData

    properties
        ZoneId (1,:) char = ''              % 被点击区域的ID
        ClickPosition (1,2) double = [0, 0] % 点击位置 [x, y]
    end

    methods
        function obj = InteractionEventData(zoneId, clickPosition)
            % InteractionEventData 构造函数
            %
            % 语法:
            %   eventData = InteractionEventData(zoneId)
            %   eventData = InteractionEventData(zoneId, clickPosition)
            %
            % 输入:
            %   zoneId        - 区域标识符 (char/string)
            %   clickPosition - 点击位置 [x, y] (可选，默认 [0, 0])

            % 验证并设置 zoneId
            if nargin < 1 || isempty(zoneId)
                obj.ZoneId = '';
            elseif ischar(zoneId) || isstring(zoneId)
                obj.ZoneId = char(zoneId);
            else
                warning('InteractionEventData:InvalidZoneId', ...
                    'zoneId 应为字符串类型');
                obj.ZoneId = '';
            end

            % 验证并设置 clickPosition
            if nargin < 2 || isempty(clickPosition)
                obj.ClickPosition = [0, 0];
            elseif isnumeric(clickPosition) && numel(clickPosition) == 2
                obj.ClickPosition = double(clickPosition(:)');
            else
                warning('InteractionEventData:InvalidPosition', ...
                    'clickPosition 应为 [x, y] 格式的数值数组');
                obj.ClickPosition = [0, 0];
            end
        end

        function str = toString(obj)
            % toString 返回事件数据的字符串表示
            str = sprintf('Zone: %s, Position: [%.1f, %.1f]', ...
                obj.ZoneId, obj.ClickPosition(1), obj.ClickPosition(2));
        end
    end
end
