classdef AppConfig
    % AppConfig 应用级全局配置
    % 存放版本信息、机构信息、实验列表等非样式类常量

    properties (Constant)
        % 系统信息
        Version = 'v4.0';
        AppName = '热学实验虚拟仿真系统';
        AppSubtitle = 'Thermal Physics Virtual Simulation Laboratory';
        Organization = '陕师大物理实验教学中心';
        CopyrightYear = '2026';

        % 窗口标识符（用于 findobj 查找）
        MainWindowTag = 'ThermalLabMain';
        GuideWindowTag = 'LabGuidelines';

        % UI 文本配置
        GuideButtonText = '实验须知';
        GuideWindowTitle = '热学实验操作规程';
        SelectExpPrompt = '请选择实验项目';
        EnterExpBtnText = '进入实验';
        GuideConfirmText = '我已知晓';

        % 提示文本
        ExpDevMsg = '正在开发中...';
        ExpLoadFailMsg = '实验模块加载失败: ';
        AlertTitleInfo = '提示';
        AlertTitleError = '错误';

        % 实验界面文本
        StartExpBtnText = '开始实验';
        ReturnExpBtnText = '返回实验';
        ReturnHomeBtnText = '返回主页';
        ExpAreaTitle = '实验操作区';
        ControlAreaTitle = '参数控制';
        DataAreaTitle = '实验数据';
        DiscussionTitle = '思考与讨论';
        ShowAnswerBtnText = '已完成思考，显示答案';
        AnswerShownText = '答案已显示';
        StatusReady = '准备就绪';
        StatusRunning = '实验进行中...';

        % 实验列表定义
        % 格式：{显示编号, 实验名称, 类名/文件名}
        ExperimentList = {
            '实验3-1', '冰融解热的测量', 'Exp3_1_IceMelting';
            '实验3-2', '电热当量的测量与散热误差的研究', 'Exp3_2_ElectricHeat';
            '实验3-3', '冷却法测量金属比热容', 'Exp3_3_MetalSpecificHeat';
            '实验3-4', '空气比热容比的测量', 'Exp3_4_AirHeatRatio';
            '实验3-5', '稳态法测量非良导体的导热系数', 'Exp3_5_ThermalConductivity';
            '实验3-6', '金属线胀系数的测量', 'Exp3_6_LinearExpansion';
        };
    end
end
