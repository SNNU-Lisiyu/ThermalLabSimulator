classdef Logger
    % Logger 日志工具类
    %
    % 描述:
    %   提供不同级别的日志记录功能，支持控制台和文件输出。
    %
    % 日志级别:
    %   1 - DEBUG   调试信息
    %   2 - INFO    一般信息（默认）
    %   3 - WARNING 警告信息
    %   4 - ERROR   错误信息
    %
    % 使用示例:
    %   utils.Logger.logInfo('系统启动完成');
    %   utils.Logger.logWarning('配置文件未找到', 'Config');
    %   utils.Logger.logError(ME, 'DataProcessing');
    %   utils.Logger.logError('发生错误', 'Context');  % 也支持字符串
    %
    %   % 动态设置日志级别
    %   utils.Logger.setLevel(utils.Logger.LEVEL_DEBUG);
    %
    %   % 启用文件日志
    %   utils.Logger.enableFileLog('app.log');
    %
    % 另见:
    %   MException

    properties (Constant)
        % 日志级别常量
        LEVEL_DEBUG = 1;
        LEVEL_INFO = 2;
        LEVEL_WARNING = 3;
        LEVEL_ERROR = 4;
    end

    methods (Static)
        function level = getLevel()
            % getLevel 获取当前日志级别
            level = utils.Logger.levelManager('get');
        end

        function setLevel(level)
            % setLevel 设置日志级别
            %   level - 日志级别 (1-4 或使用 LEVEL_* 常量)
            %
            % 示例:
            %   utils.Logger.setLevel(utils.Logger.LEVEL_DEBUG);
            if level >= 1 && level <= 4
                utils.Logger.levelManager('set', level);
            else
                warning('Logger:InvalidLevel', '无效的日志级别: %d', level);
            end
        end

        function enableFileLog(filePath)
            % enableFileLog 启用文件日志
            %   filePath - 日志文件路径
            utils.Logger.filePathManager('set', filePath);
        end

        function disableFileLog()
            % disableFileLog 禁用文件日志
            utils.Logger.filePathManager('set', '');
        end

        function path = getLogFilePath()
            % getLogFilePath 获取当前日志文件路径
            path = utils.Logger.filePathManager('get');
        end

        function name = levelToName(level)
            % levelToName 将级别数字转换为名称
            names = {'DEBUG', 'INFO', 'WARNING', 'ERROR'};
            if level >= 1 && level <= 4
                name = names{level};
            else
                name = 'UNKNOWN';
            end
        end

        function logDebug(message, contextInfo)
            % logDebug 调试级别日志
            if utils.Logger.getLevel() <= utils.Logger.LEVEL_DEBUG
                if nargin < 2, contextInfo = ''; end
                utils.Logger.writeLog('DEBUG', message, contextInfo);
            end
        end

        function logInfo(message, contextInfo)
            % logInfo 信息级别日志
            if utils.Logger.getLevel() <= utils.Logger.LEVEL_INFO
                if nargin < 2, contextInfo = ''; end
                utils.Logger.writeLog('INFO', message, contextInfo);
            end
        end

        function logWarning(message, contextInfo)
            % logWarning 警告级别日志
            if utils.Logger.getLevel() <= utils.Logger.LEVEL_WARNING
                if nargin < 2, contextInfo = ''; end
                utils.Logger.writeLog('WARNING', message, contextInfo);
            end
        end

        function logError(msgOrME, contextInfo)
            % logError 错误级别日志
            %   支持字符串消息或 MException 对象
            %
            % 语法:
            %   utils.Logger.logError(message)
            %   utils.Logger.logError(message, context)
            %   utils.Logger.logError(MException, context)
            if nargin < 2, contextInfo = 'Unknown Context'; end

            if isa(msgOrME, 'MException')
                % 处理 MException 对象 - 详细错误报告
                if utils.Logger.getLevel() <= utils.Logger.LEVEL_ERROR
                    utils.Logger.writeErrorReport(msgOrME, contextInfo);
                end
            else
                % 处理字符串消息
                if utils.Logger.getLevel() <= utils.Logger.LEVEL_ERROR
                    utils.Logger.writeLog('ERROR', msgOrME, contextInfo);
                end
            end
        end

        function logStruct(levelName, data, contextInfo)
            % logStruct 记录结构化数据
            %   levelName - 级别名称: 'DEBUG'|'INFO'|'WARNING'|'ERROR'
            %   data      - 结构体或可JSON化的数据
            %   contextInfo - 上下文信息（可选）
            if nargin < 3, contextInfo = ''; end

            % 转换级别名称为数字
            switch upper(levelName)
                case 'DEBUG'
                    level = utils.Logger.LEVEL_DEBUG;
                case 'INFO'
                    level = utils.Logger.LEVEL_INFO;
                case 'WARNING'
                    level = utils.Logger.LEVEL_WARNING;
                case 'ERROR'
                    level = utils.Logger.LEVEL_ERROR;
                otherwise
                    level = utils.Logger.LEVEL_INFO;
            end

            if utils.Logger.getLevel() <= level
                try
                    message = jsonencode(data);
                catch
                    try
                        message = evalc('disp(data)');
                        message = strtrim(message);
                    catch
                        message = '[无法序列化的数据]';
                    end
                end
                utils.Logger.writeLog(upper(levelName), message, contextInfo);
            end
        end
    end

    methods (Static, Access = private)
        function result = levelManager(action, value)
            % levelManager 管理日志级别的 persistent 变量
            persistent currentLevel;
            if isempty(currentLevel)
                currentLevel = utils.Logger.LEVEL_INFO;
            end

            if strcmp(action, 'get')
                result = currentLevel;
            else  % 'set'
                currentLevel = value;
                result = value;
            end
        end

        function result = filePathManager(action, value)
            % filePathManager 管理日志文件路径的 persistent 变量
            persistent logFilePath;
            if isempty(logFilePath)
                logFilePath = '';
            end

            if strcmp(action, 'get')
                result = logFilePath;
            else  % 'set'
                logFilePath = value;
                result = value;
            end
        end

        function writeLog(level, message, contextInfo)
            % writeLog 通用日志写入方法
            timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
            if isempty(contextInfo)
                logLine = sprintf('[%s] [%s] %s', timestamp, level, message);
            else
                logLine = sprintf('[%s] [%s] [%s] %s', timestamp, level, contextInfo, message);
            end

            % 输出到控制台
            fprintf('%s\n', logLine);

            % 输出到文件（如果启用）
            utils.Logger.writeToFile(logLine);
        end

        function writeErrorReport(ME, contextInfo)
            % writeErrorReport 写入详细错误报告
            timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

            lines = {};
            lines{end+1} = '';
            lines{end+1} = '==================== ERROR REPORT ====================';
            lines{end+1} = sprintf('Time: %s', timestamp);
            lines{end+1} = sprintf('Context: %s', contextInfo);
            lines{end+1} = sprintf('Message: %s', ME.message);
            lines{end+1} = sprintf('Identifier: %s', ME.identifier);
            lines{end+1} = '';
            lines{end+1} = 'Stack Trace:';
            for i = 1:length(ME.stack)
                s = ME.stack(i);
                lines{end+1} = sprintf('  > %s (Line %d)', s.name, s.line); %#ok<AGROW>
                lines{end+1} = sprintf('    File: %s', s.file); %#ok<AGROW>
            end
            lines{end+1} = '======================================================';

            % 输出到控制台
            for i = 1:length(lines)
                fprintf('%s\n', lines{i});
            end

            % 输出到文件（如果启用）
            fullReport = strjoin(lines, '\n');
            utils.Logger.writeToFile(fullReport);
        end

        function writeToFile(message)
            % writeToFile 写入日志文件
            logFilePath = utils.Logger.getLogFilePath();
            if ~isempty(logFilePath)
                try
                    fid = fopen(logFilePath, 'a', 'n', 'UTF-8');
                    if fid ~= -1
                        c = onCleanup(@() fclose(fid)); %#ok<NASGU>
                        fprintf(fid, '%s\n', message);
                    end
                catch
                    % 静默处理文件写入错误，避免日志系统自身产生错误
                end
            end
        end
    end
end
