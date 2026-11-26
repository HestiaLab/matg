function push_params(P, overrides)
%PUSH_PARAMS  把参数结构体展开成 base workspace 里的独立变量。
%
%   模型里的参数全是变量引用（Ts、Tend、Kp、Tmax ...），
%   所以点"运行"之前，这些变量必须已经存在于 base workspace。
%   P = params() 只创建了一个结构体 P，不会自动展开——这就是
%   "找不到变量 Tend" 的直接原因。
%
%   push_params(P)                    % 展开 P 的全部字段
%   push_params(P, struct('m',660))   % 再覆盖部分字段，覆盖值优先
%
%   GUI 工作流：
%     P = params();
%     push_params(P);
%     open_system(P.mdlName);         % 此时点运行才有效
%
%   脚本工作流不需要单独调用：run_sim 内部已经处理。

if nargin < 2, overrides = struct(); end

f = fieldnames(P);
for k = 1:numel(f)
    assignin('base', f{k}, P.(f{k}));
end

f = fieldnames(overrides);
for k = 1:numel(f)
    assignin('base', f{k}, overrides.(f{k}));
end
end
