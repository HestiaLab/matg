function setup()
%SETUP  把工程目录加入 MATLAB 搜索路径，并准备好 GUI 运行所需的参数变量。
%
%  在工程根目录执行一次即可：
%     >> setup
%     >> P = params();
%     >> open_system(P.mdlName)   % 现在可以直接点"运行"

root = fileparts(mfilename('fullpath'));
dirs = {'src', 'tests', 'scripts', 'models'};
for k = 1:numel(dirs)
    addpath(fullfile(root, dirs{k}));
end

% GUI 里点"运行"之前，参数变量必须已存在于 base workspace；
% 没有的话直接帮你展开一次，省掉一个常见错误。
P = params();
if ~evalin('base', 'exist(''Tend'',''var'') == 1')
    push_params(P);
    fprintf('已把 params 展开到 base workspace（GUI 可直接运行）。\n');
end

fprintf('Paths added:\n');
for k = 1:numel(dirs)
    fprintf('  %s\n', fullfile(root, dirs{k}));
end
end
