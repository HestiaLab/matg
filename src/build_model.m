function mdl = build_model(P)
%BUILD_MODEL  用代码构建 Simulink 模型 evtol_hover。
%
%   为什么用脚本建模型而不是直接给一个 .slx？
%     1. 模型结构是纯文本，可 diff、可 review、可版本管理；
%     2. 你能看清每个 block 的参数是怎么被设进去的；
%     3. 任何人 clone 后一条命令就能重建，不会出现"我这儿能跑你那儿不能跑"。
%
%   用法：  P = params(); build_model(P);

mdl = P.mdlName;
ensure_dirs(P);

% ---------- 清理旧模型 ----------
mdlFile = fullfile(P.modelDir, [mdl '.slx']);
if bdIsLoaded(mdl), close_system(mdl, 0); end
if isfile(mdlFile), delete(mdlFile); end
new_system(mdl);

% ---------- 模型级配置 ----------
set_param(mdl, ...
    'SolverType',   'Fixed-step', ...
    'Solver',       'ode4', ...
    'FixedStep',    'Ts', ...
    'StopTime',     'Tend', ...
    'SignalLogging', 'off', ...
    'SavedCharacterEncoding', 'UTF-8');

% =======================================================================
%  1. 控制器子系统：高度 PID + 配平前馈
% =======================================================================
ctrl = [mdl '/Controller'];
add_block('simulink/Ports & Subsystems/Subsystem', ctrl, 'Position', [80 60 300 260]);
clearSubsystem(ctrl);

add_block('simulink/Ports & Subsystems/In1', [ctrl '/h_cmd'], 'Position', [10 23 40 37], 'Port', '1');
add_block('simulink/Ports & Subsystems/In1', [ctrl '/h'],     'Position', [10 78 40 92], 'Port', '2');
add_block('simulink/Ports & Subsystems/In1', [ctrl '/v'],     'Position', [10 143 40 157], 'Port', '3');
add_block('simulink/Ports & Subsystems/Out1', [ctrl '/T_cmd'], 'Position', [300 103 330 117], 'Port', '1');

% 误差 e = h_cmd - h
add_block('simulink/Math Operations/Sum', [ctrl '/Sum_e'], ...
    'Position', [70 30 95 110], 'Inputs', '+-', 'IconShape', 'round');
add_line(ctrl, 'h_cmd/1', 'Sum_e/1', 'autorouting', 'on');
add_line(ctrl, 'h/1',     'Sum_e/2', 'autorouting', 'on');

% 并联 PID 三项
add_block('simulink/Math Operations/Gain', [ctrl '/Kp'], 'Position', [130 25 170 55], 'Gain', 'Kp');
add_block('simulink/Discrete/Discrete-Time Integrator', [ctrl '/Ki'], ...
    'Position', [130 70 170 110], ...
    'gainval', 'Ki', ...
    'SampleTime', 'Ts', ...
    'IntegratorMethod', 'Integration: Forward Euler', ...
    'LimitOutput', 'on', ...
    'UpperSaturationLimit', 'Imax', ...
    'LowerSaturationLimit', 'Imin');
add_block('simulink/Math Operations/Gain', [ctrl '/Kd'], 'Position', [130 140 170 170], 'Gain', 'Kd');

% T_cmd = Kp*e + Ki*∫e - Kd*v + Wff   ('++-+' 的第 3 项取负号)
add_block('simulink/Math Operations/Sum', [ctrl '/Sum_T'], ...
    'Position', [215 30 240 150], 'Inputs', '++-+', 'IconShape', 'round');
add_block('simulink/Sources/Constant', [ctrl '/Wff'], ...
    'Position', [175 185 205 205], 'Value', 'Wff');

add_line(ctrl, 'Sum_e/1', 'Kp/1',   'autorouting', 'on');
add_line(ctrl, 'Sum_e/1', 'Ki/1',   'autorouting', 'on');
add_line(ctrl, 'Kp/1',    'Sum_T/1','autorouting', 'on');
add_line(ctrl, 'Ki/1',    'Sum_T/2','autorouting', 'on');
add_line(ctrl, 'v/1',     'Kd/1',   'autorouting', 'on');
add_line(ctrl, 'Kd/1',    'Sum_T/3','autorouting', 'on');
add_line(ctrl, 'Wff/1',   'Sum_T/4','autorouting', 'on');
add_line(ctrl, 'Sum_T/1', 'T_cmd/1','autorouting', 'on');

% =======================================================================
%  2. 执行机构与机体
% =======================================================================
add_block('simulink/Sources/Step', [mdl '/h_cmd'], ...
    'Position', [30 63 60 87], ...
    'Time', 'tStep', 'Before', '0', 'After', 'hCmd');

add_block('simulink/Discontinuities/Saturation', [mdl '/Sat_T'], ...
    'Position', [345 70 375 100], ...
    'UpperLimit', 'Tmax', 'LowerLimit', 'Tmin');

% 电机 + 桨的一阶滞后：推力不会瞬间变化
add_block('simulink/Continuous/Transfer Fcn', [mdl '/Actuator'], ...
    'Position', [415 65 465 105], ...
    'Numerator', '[1]', 'Denominator', '[tau 1]');

% m*dv/dt = T_act - m*g - kd*v
add_block('simulink/Math Operations/Sum', [mdl '/Sum_F'], ...
    'Position', [510 60 535 150], 'Inputs', '+--', 'IconShape', 'round');
add_block('simulink/Sources/Constant', [mdl '/Weight'], ...
    'Position', [420 240 480 270], 'Value', 'm*g');
add_block('simulink/Math Operations/Gain', [mdl '/kd'], ...
    'Position', [510 265 550 295], 'Gain', 'kd');
add_block('simulink/Math Operations/Gain', [mdl '/Gain_1_m'], ...
    'Position', [570 90 610 120], 'Gain', '1/m');

add_block('simulink/Continuous/Integrator', [mdl '/v'], 'Position', [650 90 680 120], 'InitialCondition', '0');
add_block('simulink/Continuous/Integrator', [mdl '/h'], 'Position', [740 40 770 70], 'InitialCondition', '0');

add_line(mdl, 'h_cmd/1',   'Controller/1', 'autorouting', 'on');
add_line(mdl, 'Controller/1', 'Sat_T/1',   'autorouting', 'on');
add_line(mdl, 'Sat_T/1',   'Actuator/1',   'autorouting', 'on');
add_line(mdl, 'Actuator/1','Sum_F/1',      'autorouting', 'on');
add_line(mdl, 'Weight/1',  'Sum_F/2',      'autorouting', 'on');
add_line(mdl, 'kd/1',      'Sum_F/3',      'autorouting', 'on');
add_line(mdl, 'Sum_F/1',   'Gain_1_m/1',   'autorouting', 'on');
add_line(mdl, 'Gain_1_m/1','v/1',          'autorouting', 'on');
add_line(mdl, 'v/1',       'h/1',          'autorouting', 'on');
add_line(mdl, 'v/1',       'kd/1',         'autorouting', 'on');
add_line(mdl, 'v/1',       'Controller/3', 'autorouting', 'on');
add_line(mdl, 'h/1',       'Controller/2', 'autorouting', 'on');

% =======================================================================
%  3. 能量消耗与 SOC（动量理论：P = T^1.5 / kThrust）
% =======================================================================
add_block('simulink/Math Operations/Math Function', [mdl '/P_electrical'], ...
    'Position', [510 340 545 370], 'Function', 'pow');
add_block('simulink/Sources/Constant', [mdl '/pow15'], ...
    'Position', [445 385 485 405], 'Value', '1.5');
add_block('simulink/Math Operations/Gain', [mdl '/Gain_P2E'], ...
    'Position', [575 345 615 375], 'Gain', '1/kThrust');
add_block('simulink/Continuous/Integrator', [mdl '/E_batt'], ...
    'Position', [650 345 680 375], 'InitialCondition', '0');
add_block('simulink/Math Operations/Gain', [mdl '/Gain_SOC'], ...
    'Position', [710 345 750 375], 'Gain', '-1/Eb');
add_block('simulink/Sources/Constant', [mdl '/one'], ...
    'Position', [710 400 740 420], 'Value', '1');
% SOC = 1 + (-E/Eb)
add_block('simulink/Math Operations/Sum', [mdl '/soc'], ...
    'Position', [790 350 815 410], 'Inputs', '++', 'IconShape', 'round');

add_line(mdl, 'Actuator/1',  'P_electrical/1', 'autorouting', 'on');
add_line(mdl, 'pow15/1',     'P_electrical/2', 'autorouting', 'on');
add_line(mdl, 'P_electrical/1', 'Gain_P2E/1',  'autorouting', 'on');
add_line(mdl, 'Gain_P2E/1',  'E_batt/1',       'autorouting', 'on');
add_line(mdl, 'E_batt/1',    'Gain_SOC/1',     'autorouting', 'on');
add_line(mdl, 'Gain_SOC/1',  'soc/2',          'autorouting', 'on');
add_line(mdl, 'one/1',       'soc/1',          'autorouting', 'on');

% =======================================================================
%  4. 状态机：能量管理模式（Stateflow）
% =======================================================================
build_mode_chart(mdl, P);

% =======================================================================
%  5. 观测点
% =======================================================================
% 注意：To Workspace 的变量名不能用已被用作 block 名的名字，
%       否则 'v/1' 这类连线会因为撞名解析失败。
addToWorkspace(mdl, 'log_h',    'h',    [810 25 880 45]);
addToWorkspace(mdl, 'log_v',    'v',    [650 160 710 180]);
addToWorkspace(mdl, 'log_Tcmd', 'Tcmd', [310 300 370 320]);
addToWorkspace(mdl, 'log_Tsat', 'Tsat', [400 150 460 170]);
addToWorkspace(mdl, 'log_Tact', 'Tact', [400 185 460 205]);
addToWorkspace(mdl, 'log_soc',  'soc',  [860 365 920 385]);
addToWorkspace(mdl, 'log_mode', 'mode', [1030 110 1090 130]);
add_line(mdl, 'h/1',    'log_h/1',    'autorouting', 'on');
add_line(mdl, 'v/1',    'log_v/1',    'autorouting', 'on');
add_line(mdl, 'Controller/1', 'log_Tcmd/1', 'autorouting', 'on');
add_line(mdl, 'Sat_T/1',      'log_Tsat/1', 'autorouting', 'on');
add_line(mdl, 'Actuator/1',   'log_Tact/1', 'autorouting', 'on');
add_line(mdl, 'soc/1',  'log_soc/1', 'autorouting', 'on');
add_line(mdl, 'soc/1',  'EnergyMode/1', 'autorouting', 'on');
add_line(mdl, 'EnergyMode/1', 'log_mode/1', 'autorouting', 'on');

% =======================================================================
%  6. 保存
% =======================================================================
if ~isfolder(P.modelDir), mkdir(P.modelDir); end
save_system(mdl, mdlFile);
fprintf('Model generated: %s\n', mdlFile);
end

% =======================================================================
function clearSubsystem(path)
% 删除 Subsystem 默认自带的 In1 -> Out1
kids = find_system(path, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'Type', 'Block');
for k = 1:numel(kids)
    if ~strcmp(kids{k}, path)
        delete_block(kids{k});
    end
end
end

% =======================================================================
function addToWorkspace(mdl, blkName, varName, pos)
add_block('simulink/Sinks/To Workspace', [mdl '/' blkName], ...
    'Position', pos, ...
    'VariableName', varName, ...
    'SaveFormat', 'timeseries', ...
    'MaxDataPoints', 'inf');
end

% =======================================================================
function build_mode_chart(mdl, P)
chartPath = [mdl '/EnergyMode'];
add_block('sflib/Chart', chartPath, 'Position', [860 60 1000 190]);

rt = sfroot;
ch = rt.find('-isa', 'Stateflow.Chart', 'Name', 'EnergyMode');

% 图数据：输入 soc，输出 mode（0=正常 1=注意 2=警告）
dIn = Stateflow.Data(ch);
dIn.Name = 'soc';
dIn.Scope = 'Input';
dIn.Port = 1;

dOut = Stateflow.Data(ch);
dOut.Name = 'mode';
dOut.Scope = 'Output';
dOut.Port = 1;
dOut.DataType = 'uint8';

% 三个状态
sN = Stateflow.State(ch); sN.Position = [ 20  20 110  60];
sC = Stateflow.State(ch); sC.Position = [155  20 245  60];
sW = Stateflow.State(ch); sW.Position = [155 120 245 165];
sN.LabelString = sprintf('NORMAL\nen: mode = uint8(0);');
sC.LabelString = sprintf('CAUTION\nen: mode = uint8(1);');
sW.LabelString = sprintf('WARNING\nen: mode = uint8(2);');

% 默认转移
dt = Stateflow.Transition(ch);
dt.Destination = sN;
dt.DestinationOClock = 9;
dt.LabelString = '';

% 带滞回的阈值转移
mkTransition(ch, sN, sC, sprintf('soc < %g', P.socCaution));
mkTransition(ch, sC, sN, sprintf('soc > %g', P.socCaution + 0.03));
mkTransition(ch, sC, sW, sprintf('soc < %g', P.socWarning));
mkTransition(ch, sW, sC, sprintf('soc > %g', P.socWarning + 0.03));

ch.Name = 'EnergyMode';
end

function t = mkTransition(ch, src, dst, label)
t = Stateflow.Transition(ch);
t.Source = src;
t.Destination = dst;
t.SourceOClock = 3;
t.DestinationOClock = 9;
t.LabelString = label;
end
