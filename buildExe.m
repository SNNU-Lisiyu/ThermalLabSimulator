% buildExe.m - 打包热学实验虚拟仿真系统为EXE
% 使用方法: 在MATLAB中运行此脚本

% 加载配置
cfg = buildConfig();

fprintf('========================================\n');
fprintf('%s - EXE打包工具\n', cfg.summary);
fprintf('版本: %s\n', cfg.versionTag);
fprintf('========================================\n\n');

% 检查是否安装了 MATLAB Compiler
if ~license('test', 'Compiler')
    error('未检测到 MATLAB Compiler 许可证。请安装 MATLAB Compiler 后再试。');
end

% 项目路径
projectPath = cfg.projectPath;
originalDir = pwd;
cleanupObj = onCleanup(@() cd(originalDir));  % 确保无论成功与否都还原工作目录
cd(projectPath);
addpath(projectPath);

% 输出目录
outputDir = cfg.outputDir;
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

fprintf('项目路径: %s\n', projectPath);
fprintf('输出目录: %s\n\n', outputDir);

% 收集所有需要的文件
fprintf('正在收集文件...\n');
[mainFile, allFiles] = collectBuildFiles(projectPath, cfg.packages);
fprintf('\n');

% 使用 mcc 命令编译，-e 选项表示不显示控制台窗口
fprintf('正在配置编译选项...\n');

% 开始编译
fprintf('\n正在编译，请稍候（这可能需要几分钟）...\n\n');

% 输出文件名
exeBaseName = sprintf('%s_%s', cfg.appName, cfg.versionTag);

try
    % 使用 mcc 函数调用方式，避免路径引号问题
    % -e : 不显示DOS窗口 (embedded, 隐含 -m)
    % -o : 输出文件名
    % -d : 输出目录
    % -v : 详细输出

    mccArgs = {'-e', ...
        '-o', exeBaseName, ...
        '-d', outputDir, ...
        '-v', mainFile};

    % 添加附加文件
    for i = 1:length(allFiles)
        mccArgs{end+1} = '-a'; %#ok<AGROW>
        mccArgs{end+1} = allFiles{i}; %#ok<AGROW>
    end

    fprintf('正在调用 mcc 编译器...\n');
    fprintf('参数: %s\n\n', strjoin(mccArgs, ' '));

    mcc(mccArgs{:});

    fprintf('\n========================================\n');
    fprintf('编译成功！\n');
    fprintf('========================================\n');
    fprintf('输出文件: %s\n', fullfile(outputDir, [exeBaseName '.exe']));
    fprintf('\n注意: 运行EXE需要安装 MATLAB Runtime。\n');
    fprintf('可以从以下地址下载: \n');
    fprintf('https://www.mathworks.com/products/compiler/matlab-runtime.html\n');

catch ME
    fprintf('\n编译失败: %s\n', ME.message);
    fprintf('\n如果遇到问题，可以尝试使用 Application Compiler 图形界面:\n');
    fprintf('在MATLAB中输入: applicationCompiler\n');
end

fprintf('\n完成。\n');
