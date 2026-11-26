function plot_results(P, vars)
%PLOT_RESULTS  运行一次仿真并把关键信号画成图，保存到 results/figures。
%
%   plot_results()                         % 标称工况
%   plot_results(P, struct('m', 660))      % 质量 +10%
%
%   图 1：高度跟踪 + 推力 + SOC/模式
%   图 2：阶跃响应局部放大（看超调与调节时间）

if nargin < 1, P = params(); end
if nargin < 2, vars = struct(); end

out = run_sim(P, vars);

figDir = fullfile(P.outDir, 'figures');
if ~isfolder(figDir), mkdir(figDir); end

t   = out.h.Time;
h   = out.h.Data;
v   = out.v.Data;
Tc  = out.Tcmd.Data;
Ts  = out.Tsat.Data;
Ta  = out.Tact.Data;
soc = out.soc.Data;
md  = double(out.mode.Data);

% ---------------- 图 1：总览 ----------------
f1 = figure('Visible', 'off', 'Position', [100 100 900 700], 'Color', 'w');

subplot(3,1,1);
plot(t, h, 'LineWidth', 1.4); hold on;
yline(P.hCmd, 'k--', 'Command');
grid on; ylabel('Altitude [m]');
title(sprintf('Hover altitude hold (m = %g kg)', getVar(vars, 'm', P.m)));

subplot(3,1,2);
plot(t, Tc, 'Color', [0.6 0.6 0.6]); hold on;
plot(t, Ts, 'b', 'LineWidth', 1.2);
plot(t, Ta, 'r', 'LineWidth', 1.0);
yline(P.Tmax, 'k:', 'T_{max}');
grid on; ylabel('Thrust [N]');
legend({'command (pre-limit)', 'command (limited)', 'actual'}, 'Location', 'southeast');

subplot(3,1,3);
yyaxis left
plot(t, soc * 100, 'LineWidth', 1.4);
ylabel('SOC [%]'); ylim([0 105]);
yyaxis right
stairs(t, md, 'LineWidth', 1.2);
ylabel('mode'); ylim([-0.2 2.2]); yticks([0 1 2]); yticklabels({'NORMAL','CAUTION','WARNING'});
grid on; xlabel('Time [s]');

exportgraphics(f1, fullfile(figDir, 'overview.png'), 'Resolution', 150);
close(f1);

% ---------------- 图 2：阶跃响应 ----------------
f2 = figure('Visible', 'off', 'Position', [100 100 800 380], 'Color', 'w');
mask = t >= P.tStep - 0.5 & t <= P.tStep + 25;
plot(t(mask), h(mask), 'LineWidth', 1.5); hold on;
yline(P.hCmd, 'k--');
yline(P.hCmd * 1.05, 'g:');
yline(P.hCmd * 0.95, 'g:');
grid on;
xlabel('Time [s]'); ylabel('Altitude [m]');
title('Step response (\pm5% band)');
legend({'h', 'command', '+5%', '-5%'}, 'Location', 'southeast');

exportgraphics(f2, fullfile(figDir, 'step_response.png'), 'Resolution', 150);
close(f2);

% ---------------- 图 3：模型框图（方便不看 GUI 时也能看结构） ----------------
try
    open_system(P.mdlName);
    print(['-s' P.mdlName], '-dpng', '-r120', fullfile(figDir, 'model_diagram.png'));
catch err
    warning('plot_results:diagram', '模型框图导出失败: %s', err.message);
end

fprintf('Figures written to %s\n', figDir);
end

function v = getVar(s, name, default)
if isfield(s, name), v = s.(name); else, v = default; end
end
