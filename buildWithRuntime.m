% buildWithRuntime.m - 构建内嵌Runtime的安装包

% 加载配置
cfg = buildConfig();

fprintf('========================================\n');
fprintf('%s - 内嵌Runtime构建工具\n', cfg.summary);
fprintf('版本: %s\n', cfg.version);
fprintf('========================================\n\n');

if ~license('test', 'Compiler')
    error('未检测到 MATLAB Compiler 许可证');
end

% 项目路径
projectPath = cfg.projectPath;
originalDir = pwd;
cleanupObj = onCleanup(@() cd(originalDir));  % 确保无论成功与否都还原工作目录
cd(projectPath);
addpath(projectPath);

% 输出目录
outputDir = cfg.installerBuildDir;
installerDir = cfg.installerDir;

if ~exist(outputDir, 'dir'), mkdir(outputDir); end
if ~exist(installerDir, 'dir'), mkdir(installerDir); end

fprintf('构建目录: %s\n', outputDir);
fprintf('安装包目录: %s\n\n', installerDir);

% 收集文件
fprintf('正在收集文件...\n');
[mainFile, additionalFiles] = collectBuildFiles(projectPath, cfg.packages);
fprintf('\n');

% 编译EXE
exeFile = fullfile(outputDir, [cfg.appName '.exe']);

if exist(exeFile, 'file')
    reply = input('已存在EXE，重新编译？(y/N): ', 's');
    needCompile = ~isempty(reply) && lower(reply(1)) == 'y';
else
    needCompile = true;
end

if needCompile
    fprintf('【步骤 1/2】编译中...\n');
    mccArgs = {'-e', '-m', '-o', cfg.appName, '-d', outputDir, '-v', mainFile};
    for i = 1:length(additionalFiles)
        mccArgs{end+1} = '-a'; %#ok<AGROW>
        mccArgs{end+1} = additionalFiles{i}; %#ok<AGROW>
    end
    mcc(mccArgs{:});
    fprintf('编译成功！\n\n');
else
    fprintf('【步骤 1/2】跳过编译\n\n');
end

% 创建安装包
fprintf('【步骤 2/2】创建安装包...\n');

% 搜索 Runtime 安装包
runtimeFound = false;
localRuntime = '';

% 检查环境变量
envPath = getenv('MW_RUNTIME_INSTALLER_PATH');
if ~isempty(envPath) && exist(envPath, 'file')
    localRuntime = envPath;
    runtimeFound = true;
    fprintf('使用环境变量指定的Runtime: %s\n', localRuntime);
end

% 搜索常见下载目录
if ~runtimeFound
    searchDirs = cfg.runtimeSearchPaths;

    for i = 1:length(searchDirs)
        if exist(searchDirs{i}, 'dir')
            runtimeFiles = dir(fullfile(searchDirs{i}, 'MATLAB_Runtime_*.zip'));
            if ~isempty(runtimeFiles)
                localRuntime = fullfile(searchDirs{i}, runtimeFiles(end).name);
                runtimeFound = true;
                fprintf('找到本地Runtime: %s\n', localRuntime);
                break;
            end
        end
    end
end

if runtimeFound
    setenv('MW_RUNTIME_INSTALLER_PATH', localRuntime);
else
    fprintf('未找到本地Runtime，尝试下载...\n');
    fprintf('提示: 可设置环境变量 MW_RUNTIME_INSTALLER_PATH 指定Runtime路径\n');
    try
        compiler.runtime.download;
    catch
        error('请先下载Runtime: compiler.runtime.download');
    end
end

oldDir = pwd;
cd(outputDir);

% 确定构建结果文件（优先使用 buildresult.json）
buildResultFile = fullfile(outputDir, 'buildresult.json');
mcrProductsFile = fullfile(outputDir, 'requiredMCRProducts.txt');

if exist(buildResultFile, 'file')
    runtimeFile = buildResultFile;
elseif exist(mcrProductsFile, 'file')
    runtimeFile = mcrProductsFile;
else
    cd(oldDir);
    error('ThermalLabSimulator:BuildError', ...
        '找不到构建结果文件，请先编译EXE。');
end

try
    compiler.package.installer([cfg.appName '.exe'], runtimeFile, ...
        'ApplicationName', cfg.appName, ...
        'RuntimeDelivery', 'installer', ...
        'OutputDir', installerDir, ...
        'InstallerName', [cfg.appName '_Setup'], ...
        'Shortcut', [cfg.appName '.exe'], ...
        'Version', cfg.version, ...
        'AuthorName', cfg.authorName, ...
        'Summary', cfg.summary, ...
        'DefaultInstallationDir', cfg.defaultInstallDir);

    cd(oldDir);
    fprintf('\n完成！安装包: %s\n', installerDir);
catch ME
    cd(oldDir);
    fprintf('\n安装包创建失败: %s\n', ME.message);
    fprintf('EXE位置: %s\n', exeFile);
    fprintf('可用图形界面: applicationCompiler\n');
end
