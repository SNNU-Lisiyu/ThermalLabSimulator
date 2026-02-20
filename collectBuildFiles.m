function [mainFile, additionalFiles] = collectBuildFiles(projectPath, packages)
    % collectBuildFiles - 收集构建所需文件
    %
    % 输入:
    %   projectPath - 项目根目录
    %   packages    - 包目录列表 (如 {'+ui', '+experiments'})
    %
    % 输出:
    %   mainFile        - 主入口文件路径
    %   additionalFiles - 附加文件列表 (cell array)

    mainFile = fullfile(projectPath, 'main.m');
    if ~isfile(mainFile)
        error('ThermalLabSimulator:BuildError', ...
            '主入口文件不存在: %s', mainFile);
    end
    additionalFiles = {};

    % 直接添加包目录（让 MATLAB Compiler 递归处理）
    % 这一步至关重要，因为 main.m 使用了 feval 动态加载实验类，
    % 编译器无法自动分析出这些依赖，必须显式包含。
    for p = 1:length(packages)
        pkgPath = fullfile(projectPath, packages{p});
        if exist(pkgPath, 'dir')
            additionalFiles{end+1} = pkgPath; %#ok<AGROW>
        end
    end

    % 添加资源目录
    resourcesDir = fullfile(projectPath, 'resources');
    if exist(resourcesDir, 'dir')
        additionalFiles{end+1} = resourcesDir;
    end

    % 输出统计
    fprintf('  主文件: %s\n', mainFile);
    fprintf('  附加目录: %d 个\n', length(additionalFiles));
    for i = 1:length(additionalFiles)
        fprintf('    + %s\n', additionalFiles{i});
    end
end
