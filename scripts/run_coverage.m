function run_coverage(P)
%RUN_COVERAGE  测量模型覆盖率，并生成 HTML 报告。
%
%   DO-178C / DO-331 的表格 A-7 要求结构覆盖率证据：
%   DAL A 需要 MC/DC，DAL B 需要判定+条件，DAL C 需要判定覆盖。
%   这里四种指标一起打开，用来观察"测试用例够不够"。
%
%   用法：  run_coverage();

if nargin < 1, P = params(); end
ensure_dirs(P);

mdlFile = fullfile(P.modelDir, [P.mdlName '.slx']);
if ~isfile(mdlFile), build_model(P); end
if ~bdIsLoaded(P.mdlName), load_system(mdlFile); end

% 模型按变量名解析参数
push_params(P);

% ---------- 覆盖率配置 ----------
testObj = cvtest(P.mdlName);
testObj.settings.decision  = 1;   % 判定覆盖
testObj.settings.condition = 1;   % 条件覆盖
testObj.settings.mcdc      = 1;   % MC/DC

fprintf('\nRunning instrumented simulation...\n');
data = cvsim(testObj);

% ---------- 报告 ----------
if ~isfolder(P.outDir), mkdir(P.outDir); end
htmlFile = fullfile(P.outDir, 'coverage_report.html');
cvhtml(htmlFile, data);

fprintf('\n--- coverage summary (%s) ---\n', P.mdlName);
metrics = {'execution',   'Execution';
           'decision',    'Decision';
           'condition',   'Condition';
           'mcdc',        'MC/DC'};
for k = 1:size(metrics, 1)
    [cov, tot] = oneMetric(data, P.mdlName, metrics{k, 1});
    if tot == 0
        fprintf('%-11s : n/a (no statistic of this metric in the model)\n', metrics{k, 2});
    else
        fprintf('%-11s : %3d / %3d  (%.1f %%)\n', ...
            metrics{k, 2}, cov, tot, 100 * cov / tot);
    end
end
fprintf('\nHTML report: %s\n\n', htmlFile);
end

% =======================================================================
function [cov, tot] = oneMetric(data, mdl, metric)
% 各 *info 函数的返回值是 [covered total]
cov = 0; tot = 0;
switch metric
    case 'execution', fn = @executioninfo;
    case 'decision',  fn = @decisioninfo;
    case 'condition', fn = @conditioninfo;
    case 'mcdc',      fn = @mcdcinfo;
    otherwise, return;
end
v = fn(data, mdl);
if isnumeric(v) && numel(v) >= 2
    cov = v(1); tot = v(2);
end
end
