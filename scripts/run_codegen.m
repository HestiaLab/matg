function run_codegen(P)
%RUN_CODEGEN  从 Controller 子系统生成嵌入式 C 代码。
%
%   这一步对应型号项目里的"模型即设计、代码由模型生成"：
%   改模型 -> 重新生成 -> 代码与模型始终一致，不存在手写代码漂移。
%
%   只对控制器子系统生成代码，而不是整个模型：
%   机体动力学、能量模型属于仿真环境，不会装机。
%
%   用法：  run_codegen();

if nargin < 1, P = params(); end

mdlFile = fullfile(P.modelDir, [P.mdlName '.slx']);
if ~isfile(mdlFile), build_model(P); end
if ~bdIsLoaded(P.mdlName), load_system(mdlFile); end

push_params(P);

% ---------- 生成目录 ----------
ensure_dirs(P);                 % 缓存/代码目录统一重定向到 results/
buildDir = fullfile(P.outDir, 'codegen');

% ---------- 代码生成配置 ----------
cs = getActiveConfigSet(P.mdlName);
set_param(cs, 'SystemTargetFile', 'ert.tlc');   % Embedded Coder
set_param(cs, 'GenCodeOnly', 'on');             % 只生成代码，不编译
set_param(cs, 'TargetLang', 'C');
set_param(cs, 'GenerateComments', 'on');

% ---------- 生成 ----------
slbuild([P.mdlName '/Controller']);

% ---------- 结果 ----------
cFile = fullfile(buildDir, 'Controller_ert_rtw', 'Controller.c');
if ~isfile(cFile)
    error('run_codegen:missing', '未找到生成的 C 文件: %s', cFile);
end

fprintf('\n--- generated files ---\n');
files = dir(fullfile(buildDir, 'Controller_ert_rtw', '*.c'));
for k = 1:numel(files)
    fprintf('  %s\n', fullfile(files(k).folder, files(k).name));
end

fprintf('\n--- Controller.c: 控制器步进函数 ---\n');
txt = fileread(cFile);
lines = splitlines(txt);
startIdx = find(contains(lines, 'void Controller_step'), 1);
if ~isempty(startIdx)
    endIdx = startIdx + find(strcmp(strtrim(lines(startIdx+1:end)), '}'), 1);
    for k = startIdx:min(endIdx, numel(lines))
        fprintf('%s\n', lines{k});
    end
end

close_system(P.mdlName, 0);
end
