function cfg = buildConfig()
    % buildConfig - 构建配置
    % 统一管理所有构建参数，避免多处硬编码

    cfg = struct();

    % === 应用信息 ===
    cfg.appName = 'ThermalLabSimulator';

    % 从 core.AppConfig 读取版本号以保持一致
    cfg.version = '3.0'; % 默认值
    try
        cfg.version = core.AppConfig.Version;
    catch
        % 如果读取失败，保持默认
    end

    % 生成文件名用版本标签：去除可能的 'v' 前缀后再拼接，避免 'vv3_0'
    versionNum = cfg.version;
    if startsWith(versionNum, 'v') || startsWith(versionNum, 'V')
        versionNum = versionNum(2:end);
    end
    cfg.versionTag = ['v' strrep(versionNum, '.', '_')];  % 用于文件名 (如 v3_0)
    cfg.authorName = '物理实验教学中心';

    % 从 AppConfig 获取摘要（如果可用）
    try
        cfg.summary = core.AppConfig.AppName;
    catch
        cfg.summary = '热学实验虚拟仿真系统';  % 回退默认值
    end

    % === 路径配置 ===
    cfg.projectPath = fileparts(mfilename('fullpath'));
    cfg.outputDir = fullfile(cfg.projectPath, 'build');
    cfg.installerDir = fullfile(cfg.projectPath, 'installer', 'setup');
    cfg.installerBuildDir = fullfile(cfg.projectPath, 'installer', 'build');

    % === 安装配置 ===
    cfg.defaultInstallDir = 'C:\Program Files\ThermalLabSimulator';

    % === 包目录列表 ===
    cfg.packages = {'+ui', '+experiments', '+core', '+utils'};

    % === Runtime 搜索路径 ===
    cfg.runtimeSearchPaths = {
        getenv('MW_RUNTIME_INSTALLER_PATH')
        fullfile(getenv('USERPROFILE'), 'Downloads')
        fullfile(cfg.projectPath, 'runtime')
    };
end
