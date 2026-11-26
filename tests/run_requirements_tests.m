function R = run_requirements_tests(P)
%RUN_REQUIREMENTS_TESTS  逐条需求的自动化验证。
%
%   每条需求（docs/requirements.md）对应一个用例，
%   用例给出「实测值」与「判据」，不通过时返回失败。
%
%   用法：  R = run_requirements_tests();

if nargin < 1, P = params(); end
if ~isfile(fullfile(P.modelDir, [P.mdlName '.slx'])), build_model(P); end

R = struct('id', {}, 'desc', {}, 'pass', {}, 'evidence', {});

fprintf('\n=== eVTOL hover: requirement verification ===\n');

%% ---------------- 高度控制：标称工况 ----------------
out = run_sim(P, struct('Tend', 80));       % 80 s 足够看到稳态
t  = out.h.Time;
h  = out.h.Data;

os = overshootPct(t, h, P.tStep, P.hCmd);
ts = settlingTime(t, h, P.tStep, P.hCmd, 0.05);

R = addResult(R, 'REQ-ALT-001', '阶跃超调 <= 10 %', ...
    os <= 10, sprintf('overshoot = %.2f %%', os));

R = addResult(R, 'REQ-ALT-002', '调节时间(±5%%) <= 12 s', ...
    ts <= 12, sprintf('settling = %.2f s', ts));

%% ---------------- 高度控制：质量失配 ----------------
for factor = [1.10, 0.90]
    outM = run_sim(P, struct('m', P.m * factor, 'Tend', 80));
    hM   = outM.h.Data;
    e60  = abs(P.hCmd - interp1(outM.h.Time, hM, 60));
    R = addResult(R, 'REQ-ALT-003', ...
        sprintf('质量偏差 %+.0f%% 时 60 s 稳态误差 <= 0.05 m', (factor-1)*100), ...
        e60 <= 0.05, sprintf('|e(60s)| = %.4f m', e60));
end

%% ---------------- 执行机构权限 ----------------
T = out.Tsat.Data;      % 限幅后、送往执行机构的推力
inRange = all(T >= P.Tmin - 1e-6) && all(T <= P.Tmax + 1e-6);
R = addResult(R, 'REQ-ALT-004', '限幅后的推力指令始终在 [Tmin, Tmax] 内', ...
    inRange, sprintf('Tsat range = [%.0f, %.0f] N', min(T), max(T)));

% 饱和退出后不得出现极限环：用最后 10 s 的高度波动衡量
tail = h(t >= t(end) - 10);
ripple = max(tail) - min(tail);
R = addResult(R, 'REQ-ALT-005', '饱和后无持续振荡（末 10 s 波动 <= 0.02 m）', ...
    ripple <= 0.02, sprintf('tail ripple = %.4f m', ripple));

%% ---------------- 能量管理状态机 ----------------
outE = run_sim(P, struct('Tend', P.Tend));
tE   = outE.mode.Time;
md   = double(outE.mode.Data(:))';
soc  = outE.soc.Data(:)';

seq = unique(md, 'stable');
R = addResult(R, 'REQ-ENR-001', 'SOC 单调下降时模式按 0->1->2 迁移', ...
    isequal(seq, [0 1 2]), sprintf('mode sequence = %s', mat2str(seq)));

% 不许回跳（本工况 SOC 只降不升）
backward = any(diff(md) < 0);
R = addResult(R, 'REQ-ENR-002', '模式不发生反向跳变', ...
    ~backward, sprintf('backward transitions = %d', sum(diff(md) < 0)));

% 阈值精度：进入 CAUTION 时 SOC 应落在阈值附近（采样误差 < 0.01）
kCaution = find(md == 1, 1);
socAtCaution = soc(kCaution);
R = addResult(R, 'REQ-ENR-003', 'CAUTION 触发点 SOC 与阈值偏差 <= 0.01', ...
    abs(socAtCaution - P.socCaution) <= 0.01, ...
    sprintf('SOC@CAUTION = %.4f (threshold %.2f)', socAtCaution, P.socCaution));

kWarning = find(md == 2, 1);
socAtWarning = soc(kWarning);
R = addResult(R, 'REQ-ENR-004', 'WARNING 触发点 SOC 与阈值偏差 <= 0.01', ...
    abs(socAtWarning - P.socWarning) <= 0.01, ...
    sprintf('SOC@WARNING = %.4f (threshold %.2f)', socAtWarning, P.socWarning));

%% ---------------- 汇总 ----------------
nPass = sum([R.pass]);
fprintf('\n--- summary: %d / %d passed ---\n', nPass, numel(R));
for k = 1:numel(R)
    if R(k).pass, tag = 'PASS'; else, tag = 'FAIL'; end
    fprintf('[%s] %-13s %-46s %s\n', tag, R(k).id, R(k).desc, R(k).evidence);
end
fprintf('\n');
end

% =======================================================================
function R = addResult(R, id, desc, pass, evidence)
R(end+1) = struct('id', id, 'desc', desc, 'pass', logical(pass), 'evidence', evidence);
end

function os = overshootPct(t, y, tStep, cmd)
i0 = find(t >= tStep, 1);
y0 = y(i0);
yf = y(end);
peak = max(y(i0:end));
os = (peak - yf) / abs(yf - y0) * 100;
end

function ts = settlingTime(t, y, tStep, cmd, band)
i0 = find(t >= tStep, 1);
yf = y(end);
tol = band * abs(yf - y(i0));
outside = find(abs(y(i0:end) - yf) > tol, 1, 'last');
if isempty(outside)
    ts = 0;
else
    ts = t(i0 + outside - 1) - tStep;
end
end
