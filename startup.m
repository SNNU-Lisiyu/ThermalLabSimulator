function startup()
% startup 项目启动脚本
% 将项目路径添加到 MATLAB 搜索路径
%
% 用法：
%   在 ThermalLabSimulator 目录下运行 startup，然后输入 main 启动系统
%
% 系统要求：
%   MATLAB R2020a 或更高版本（需要 uigridlayout 支持）

% 在部署环境中不执行路径操作
if isdeployed
    return;
end

% MATLAB 版本检查（R2020a = 9.8）
MIN_VERSION = '9.8';
currentVersion = version('-release');
if verLessThan('matlab', MIN_VERSION)
    warning('ThermalLabSimulator:VersionWarning', ...
        '当前 MATLAB 版本 (%s) 可能不兼容，建议使用 R2020a 或更高版本。', ...
        currentVersion);
end

% 获取当前文件夹路径
projectRoot = fileparts(mfilename('fullpath'));

% 检查路径是否已添加，避免重复
pathList = strsplit(path, pathsep);
if ~any(strcmp(pathList, projectRoot))
    addpath(projectRoot);
end

% 提示信息（从 AppConfig 动态读取版本号）
try
    ver = core.AppConfig.Version;
catch
    ver = '';
end

% 初始化日志系统
try
    logDir = fullfile(projectRoot, 'logs');
    if ~exist(logDir, 'dir')
        mkdir(logDir);
    end
    logFile = fullfile(logDir, sprintf('session_%s.log', char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'))));
    utils.Logger.enableFileLog(logFile);
    utils.Logger.logInfo(sprintf('系统启动 %s', ver), 'startup');
catch
    % 日志初始化失败不影响系统运行
end
fprintf('\n');
fprintf('  ╔════════════════════════════════════════╗\n');
fprintf('  ║    热学实验虚拟仿真系统 %-16s║\n', ver);
fprintf('  ╠════════════════════════════════════════╣\n');
fprintf('  ║    输入 main 启动系统                  ║\n');
fprintf('  ╚════════════════════════════════════════╝\n');
fprintf('\n');
end
