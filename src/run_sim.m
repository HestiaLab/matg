function out = run_sim(P, vars)
%RUN_SIM  运行一次仿真，可通过 vars 覆盖任意参数。
%
%   out = run_sim(P)                              % 标称工况
%   out = run_sim(P, struct('m', 660))            % 质量 +10%
%
%   vars 中的字段名必须与模型里引用的变量名一致（见 params.m）。

if nargin < 2, vars = struct(); end

mdl = P.mdlName;
ensure_dirs(P);
mdlFile = fullfile(P.modelDir, [mdl '.slx']);
if ~isfile(mdlFile)
    build_model(P);
end
if ~bdIsLoaded(mdl)
    load_system(mdlFile);
end

% 参数进入 base workspace（模型按变量名解析）；vars 中的覆盖值优先
push_params(P, vars);

% To Workspace 的变量会以属性形式出现在 SimulationOutput 里：
%   out.h, out.v, out.Tcmd, out.Tact, out.soc, out.mode
out = sim(mdl);
end
