function grtfmi_make_rtw_hook(hookMethod, modelName, rtwRoot, templateMakefile, buildOpts, buildArgs, buildInfo)

switch hookMethod

    case 'after_make'

        current_dir = pwd;

        % remove fmiwrapper.inc for referenced models
        if ~strcmp(current_dir(end-11:end), '_grt_fmi_rtw')
            delete('fmiwrapper.inc');
            return
        end

        if strcmp(get_param(gcs, 'GenCodeOnly'), 'on')
            return
        end

        pathstr = which('grtfmi.tlc');
        [grtfmi_dir, ~, ~] = fileparts(pathstr);
        
        command = get_param(modelName, 'CMakeCommand');
        command = grtfmi_find_cmake(command);
        generator = get_param(modelName, 'CMakeGenerator');
        options = get_param(modelName, 'CMakeOptions');

        disp('### Running CMake generator')
        custom_include = get_param(gcs, 'CustomInclude');
        custom_include = regexp(custom_include, '\s+', 'split');
        custom_source = get_param(gcs, 'CustomSource');
        custom_source = { which(custom_source) };

        if isfield(buildOpts, 'libsToCopy') && ~isempty(buildOpts.libsToCopy)
            [parent_dir, ~, ~] = fileparts(pwd);
            custom_include{end+1} = fullfile(parent_dir, 'slprj', 'grtfmi', '_sharedutils');
            for i = 1:numel(buildOpts.libsToCopy)
                [~, refmodel, ~] = fileparts(buildOpts.libsToCopy{i});
                refmodel = refmodel(1:end-7);
                custom_include{end+1} = fullfile(parent_dir, 'slprj', 'grtfmi', refmodel);
                custom_source{end+1}  = fullfile(parent_dir, 'slprj', 'grtfmi', refmodel, [refmodel '.c']);
            end
        end

        % add S-function sources
        if isfield(buildOpts, 'noninlinedSFcns')
            for i = 1:numel(buildOpts.noninlinedSFcns)
                sfcn = which(buildOpts.noninlinedSFcns{i});
                [sfcn_dir, sfcn_name, ~] = fileparts(sfcn);
                src_file_ext = {'.c', '.cc', '.cpp', '.cxx', '.c++'};
                for j = 1:numel(src_file_ext)
                    ext = src_file_ext{j};
                    if exist(fullfile(sfcn_dir, [sfcn_name ext]), 'file') == 2
                        custom_source{end+1} = fullfile(sfcn_dir, [sfcn_name ext]);
                        break
                    end
                end
            end
        end

        status = system(['"' command '"' ...
        ' -G "' generator '"' ...
        ' -DMODEL='          modelName ...
        ' -DRTW_DIR="'       strrep(pwd,           '\', '/') '"' ...
        ' -DMATLAB_ROOT="'   strrep(matlabroot,    '\', '/') '"' ...
        ' -DCUSTOM_INCLUDE="' build_path_list(custom_include) '"' ...
        ' -DCUSTOM_SOURCE="' build_path_list(custom_source) '"' ...
        ' ' options ...
        ' "'                 strrep(grtfmi_dir,    '\', '/') '"']);
        assert(status == 0, 'Failed to run CMake generator');

        disp('### Building FMU')
        status = system(['"' command '" --build . --config Release']);
        assert(status == 0, 'Failed to build FMU');

        % copy the FMU to the working directory
        copyfile([modelName '.fmu'], '..');
end

end

function list = build_path_list(segments)

list = '';

for i = 1:numel(segments)
  segment = segments{i};
  if ~isempty(segment)
    if isempty(list)
      list = segment;
    else
      list = [segment ';' list];
    end
  end
end

list = strrep(list, '\', '/');

end
