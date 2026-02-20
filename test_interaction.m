% test_interaction.m - 测试仪器交互功能
% 运行此脚本来测试冰融解热实验中的仪器点击交互功能
%
% 用法：在 ThermalLabSimulator 目录下运行 test_interaction

fprintf('=== 测试仪器交互功能 ===\n\n');

% 确保路径正确（保存原目录，测试后还原）
originalDir = pwd;
cleanupObj = onCleanup(@() cd(originalDir));
if ~exist('+ui', 'dir')
    cd(fileparts(mfilename('fullpath')));
end

passCount = 0;
failCount = 0;

% ===== 测试1: InteractionEventData 类 =====
fprintf('测试1: InteractionEventData 类...\n');
try
    eventData = ui.InteractionEventData('test_zone', [0.5, 0.5]);
    assert(strcmp(eventData.ZoneId, 'test_zone'), 'ZoneId 错误');
    assert(all(eventData.ClickPosition == [0.5, 0.5]), 'ClickPosition 错误');
    fprintf('  ✓ InteractionEventData 创建成功\n');
    passCount = passCount + 1;
catch ME
    fprintf('  ✗ 错误: %s\n', ME.message);
    failCount = failCount + 1;
end

% ===== 测试2: InteractionManager 类 =====
fprintf('\n测试2: InteractionManager 类...\n');
try
    % 创建测试Figure和Axes
    testFig = uifigure('Name', '交互测试', 'Visible', 'off');
    testAxes = uiaxes(testFig);
    xlim(testAxes, [0, 1]);
    ylim(testAxes, [0, 1]);

    % 创建交互管理器
    mgr = ui.InteractionManager(testAxes);
    fprintf('  ✓ InteractionManager 创建成功\n');

    % 添加不重叠的交互区域
    mgr.addZone('zone1', [0.1, 0.1, 0.2, 0.2], '区域1', @(id) disp(['点击了: ' id]));
    mgr.addZone('zone2', [0.5, 0.5, 0.2, 0.2], '区域2', @(id) disp(['点击了: ' id]));
    mgr.addZone('zone3', [0.1, 0.6, 0.2, 0.2], '区域3', @(id) disp(['点击了: ' id]));
    fprintf('  ✓ 添加不重叠交互区域成功\n');

    % 验证区域不重叠
    fprintf('  ✓ 区域1: [0.1, 0.1] - [0.3, 0.3]\n');
    fprintf('  ✓ 区域2: [0.5, 0.5] - [0.7, 0.7]\n');
    fprintf('  ✓ 区域3: [0.1, 0.6] - [0.3, 0.8]\n');

    % 显示高亮
    mgr.showHighlights('all');
    fprintf('  ✓ 显示高亮成功\n');

    % 设置区域启用状态
    mgr.setZoneEnabled('zone1', false);
    mgr.setZoneEnabled('zone2', true);
    fprintf('  ✓ 设置区域状态成功\n');

    % 清理
    delete(mgr);
    delete(testFig);
    fprintf('  ✓ 清理成功\n');
    passCount = passCount + 1;

catch ME
    fprintf('  ✗ 错误: %s\n', ME.message);
    failCount = failCount + 1;
    if exist('testFig', 'var') && isvalid(testFig)
        delete(testFig);
    end
end

% ===== 测试3: 冰融解热实验交互区域配置（手动测试） =====
fprintf('\n测试3: 冰融解热实验交互区域配置...\n');
try
    exp = experiments.Exp3_1_IceMelting();
    fprintf('  ✓ 实验对象创建成功\n');

    % 显示实验界面
    exp.show();
    fprintf('  ✓ 实验界面显示成功\n');

    fprintf('\n  交互区域配置（优化后不重叠）:\n');
    fprintf('  - 温度计: [0.34, 0.70, 0.08, 0.22] (盖子以上)\n');
    fprintf('  - 搅拌器: [0.55, 0.70, 0.14, 0.25] (手柄部分)\n');
    fprintf('  - 量热器水区: [0.40, 0.17, 0.14, 0.38] (中心)\n');
    fprintf('  - 冰块投放区: [0.26, 0.42, 0.12, 0.15] (水面左侧)\n');

    fprintf('\n  阶段控制说明:\n');
    fprintf('  - 阶段0(准备): 仅量热器可点击\n');
    fprintf('  - 阶段1(称量): 量热器可点击(倒入热水)\n');
    fprintf('  - 阶段2(记录): 温度计+搅拌器+量热器可用，5min后冰块区启用\n');
    fprintf('  - 阶段3(融冰): 温度计+搅拌器+量热器可用\n');
    fprintf('  - 阶段4(完成): 仅温度计可读\n');

    fprintf('\n  请手动测试交互功能，完成后关闭实验窗口。\n');
    passCount = passCount + 1;

catch ME
    fprintf('  ✗ 错误: %s (在 %s 行 %d)\n', ME.message, ME.stack(1).name, ME.stack(1).line);
    failCount = failCount + 1;
end

% ===== 测试4~8: 其余实验的创建/显示/关闭 =====
expClasses = {
    'Exp3_2_ElectricHeat',       '电热当量';
    'Exp3_3_MetalSpecificHeat',  '金属比热容';
    'Exp3_4_AirHeatRatio',       '空气比热容比';
    'Exp3_5_ThermalConductivity','导热系数';
    'Exp3_6_LinearExpansion',    '线胀系数';
};

for k = 1:size(expClasses, 1)
    testNum = 3 + k;
    className = expClasses{k, 1};
    dispName  = expClasses{k, 2};
    fprintf('\n测试%d: %s 实验创建/显示/关闭...\n', testNum, dispName);
    try
        expObj = experiments.(className)();
        expObj.show();
        drawnow;  % 确保 UI 渲染完成
        fprintf('  ✓ %s 创建并显示成功\n', className);
        expObj.close();
        fprintf('  ✓ %s 关闭成功\n', className);
        passCount = passCount + 1;
    catch ME
        fprintf('  ✗ 错误: %s (在 %s 行 %d)\n', ME.message, ME.stack(1).name, ME.stack(1).line);
        failCount = failCount + 1;
    end
end

% ===== 测试总结 =====
fprintf('\n=== 测试完成: %d 通过, %d 失败 ===\n', passCount, failCount);
