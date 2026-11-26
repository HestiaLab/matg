function P = params()
%PARAMS  工程参数的唯一来源。
%   模型、脚本、测试、代码生成全部引用这里的字段，
%   避免"模型里写死一个数，测试里写死另一个数"。
%
%   用法：  P = params();

% ---------------- 环境 ----------------
P.g      = 9.81;          % 重力加速度 [m/s^2]
P.rho    = 1.225;         % 空气密度 [kg/m^3]

% ---------------- 机体 ----------------
P.m      = 600;           % 质量 [kg]
P.Wff    = P.m * P.g;     % 前馈配平推力 [N]（按标称质量给出，故意与真实质量解耦）
P.kd     = 6;             % 垂向气动阻尼 [N/(m/s)]
P.nRotor = 4;             % 旋翼数量
P.rotorR = 0.9;           % 单旋翼半径 [m]
P.A      = P.nRotor * pi * P.rotorR^2;    % 总桨盘面积 [m^2]
P.kThrust = sqrt(2 * P.rho * P.A);        % 动量理论: P = T^1.5 / kThrust
P.Tmax   = 12000;         % 最大推力 [N]
P.Tmin   = 0;             % 最小推力 [N]
P.tau    = 0.08;          % 电机+桨一阶滞后时间常数 [s]

% ---------------- 控制器 ----------------
P.Kp   = 3000;            % [N/m]
P.Ki   = 250;             % [N/(m*s)]
P.Kd   = 2400;            % [N/(m/s)]
P.Imin = -4000;           % 积分限幅（抗饱和）[N]
P.Imax =  4000;

% ---------------- 能量 ----------------
P.Eb         = 4 * 3.6e6;   % 电池可用能量 [J]，4 kWh（演示用，非真实机型）
P.socCaution = 0.30;        % 低电量告警阈值
P.socWarning = 0.15;        % 严重低电量阈值

% ---------------- 仿真 ----------------
P.Ts      = 0.01;         % 定步长 [s]
P.Tend    = 150;          % 仿真时长 [s]
P.hCmd    = 5;            % 高度指令 [m]
P.tStep   = 1;            % 指令阶跃时刻 [s]
P.mdlName = 'evtol_hover';

% ---------------- 路径 ----------------
% 以 params.m 所在位置为锚点，保证在任何工作目录下都能运行
P.root     = fileparts(fileparts(mfilename('fullpath')));
P.modelDir = fullfile(P.root, 'models');
P.outDir   = fullfile(P.root, 'results');
end
