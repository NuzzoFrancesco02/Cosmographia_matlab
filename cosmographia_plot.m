function cosmographia_plot(mission_name, varargin)
%% COSMOGRAPHIA_PLOT
% ------------------
% Function to create and manage mission directories for visualization in Cosmographia.
% This function takes mission details and spacecraft trajectory data as input, processes
% the required SPICE kernels, and generates the necessary files for Cosmographia to
% visualize the mission. Note: all spacecraft must share the same CENTER (focus).
%
% INPUTS:
%   mission_name (string): The name of the mission directory to be created. 
%   varargin (structs): One or more satellite structures, each containing the following fields:
%   
%       sat = struct( 'name', str,          % Satellite name (e.g., 'ssc1').
%                     'id', double,        % Unique ID for the satellite.
%                     'segid', str,        % Segment identifier for the SPICE file.
%                     'dateStart', [1x6],  % Start date of the trajectory ([YYYY MM DD hh mm ss]).
%                     't', [Nx1],          % Array of time points (seconds from the start date).
%                     'r', [Nx3],          % Array of position vectors (km).
%                     'v', [Nx3],          % Array of velocity vectors (km/s).
%                     'CENTER', double,    % Center ID (e.g., 399 for Earth).
%                     'REF', str);         % Reference frame (e.g., 'J2000').
%
% OUTPUTS:
%   None. The function generates all necessary directories and files interactively.
%
% USAGE EXAMPLES:
%   % Example with a single satellite:
%   >> [t, r, v] = propagate_orbit(); 
%      % Obtain the trajectory data through propagation.
%   >> sat = struct('name', 'ssc1', 'id', -1001, 'segid', 'ssc1_seg', ...
%                   'dateStart', [2024 11 23 19 00 00], 't', t, ...
%                   'r', r, 'v', v, 'CENTER', 399, 'REF', 'J2000');
%   >> cosmographia_plot('mission_name', sat);
%
%   % Example with multiple satellites:
%   >> cosmographia_plot('mission_name', sat1, sat2, sat3, ...);
%
% FUNCTIONALITY:
% 1. Creates a mission directory (with conflict management if the name already exists).
% 2. Generates SPICE kernels (SPK, PCK, LSK) for satellite trajectories.
% 3. Creates LOAD and configuration files for Cosmographia.
% 4. Automatically generates a Python script for Cosmoscripting.
% 5. Launches Cosmographia with the generated mission data.
%
% REQUIREMENTS:
%   - MATLAB R2020b or later.
%   - Cosmographia installed: https://naif.jpl.nasa.gov/naif/cosmographia_components.html
%     (The executable path will be requested on the first run).
%   - MICE toolkit for MATLAB: https://naif.jpl.nasa.gov/naif/toolkit_MATLAB.html
%     Add the following paths to your MATLAB environment:
%        >> addpath("path/to/your/mice/src/mice")
%        >> addpath("path/to/your/mice/lib")
%        >> savepath
%   - Generic SPICE kernels:
%       - LSK: A .tls file (Windows users must use the .pc version): 
%         https://naif.jpl.nasa.gov/pub/naif/generic_kernels/lsk/
%               example: latest_leapseconds.tls
%       - SPK: A .bsp file for planetary positions:
%         https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/planets/
%               example: de435.bsp
%       - PCK: A .bpc file for planetary constants:
%         https://naif.jpl.nasa.gov/pub/naif/generic_kernels/pck/
%               example: earth_latest_high_prec.bpc
%   
% WARNING!!! All the SPICE kernels used must be added in the "spice" folder
% of Cosmographia and listed inside the `spice_kernels.json` file. 
% You need to search for the Cosmographia data folder and modify it accordingly.
%
%   - File system access permissions are required for creating directories 
%     and writing files.
%
% NOTES:
%   - Ensure that the trajectory data is accurate and consistent for all satellites.
%   - This function assumes that all satellites share the same CENTER 
%     (e.g., Earth for Earth-centered missions).
%   - The generated Python script uses Cosmoscripting to set up and display 
%     the mission in Cosmographia.
%
% AUTHORS:
%   Francesco Nuzzo
% ------------------

    
    % Version of Cosmographia
    version = "1.0"; 
    
    %
    try
        cspice_kclear
    catch
        error(['Add mice to your path, try with:', newline, ...
       '>>    addpath("path/to/your/mice/src/mice")', newline, ...
       '>>    savepath', newline, ...
       '>>    addpath("path/to/your/mice/lib")', newline, ...
       '>>    savepath']);
    end
    % Input check function 
    input_check(varargin);
    
    % Field check function 
    fields_check(varargin);
    
    % Loading bar setup
    h = waitbar(0, 'Initializing...', 'Name', 'Creating files...');
    total_steps = 7; % Total steps in the process

    % Step 1: Create folder
    waitbar(1 / total_steps, h, "Creating folder '" + strrep(mission_name, '_', '\_') + "'...");
    
    % Check if the folder already exists
    if isfolder(mission_name)
        % Message asking if the user wants to overwrite the existing folder
        str = "''" + mission_name + "''" + " folder already exists. Overwrite?";
        
        % Dialog to ask user if they want to overwrite or not
        answer = questdlg(str, mission_name, 'Yes', 'No', 'Cancel', 'Cancel');
        
        % If user clicks Yes, remove the folder and recreate it
        if strcmp(answer, 'Yes')
            rmdir(mission_name, 's'); % Remove folder and its contents
            mkdir(mission_name); % Create a new folder
        % If user clicks No, create a new folder with a suffix (e.g., mission_name_1)
        elseif strcmp(answer, 'No')
            flag = 0; 
            j = 1;
            while flag == 0
                if ~isfolder(mission_name + "_" + num2str(j)) % Check if folder doesn't exist
                    flag = 1;
                    mission_name = mission_name + "_" + num2str(j); % Modify folder name with suffix
                    mkdir(mission_name); % Create the folder
                end
                j = j + 1;
            end
        % If user cancels, close the loading bar and exit
        elseif strcmp(answer, 'Cancel') || isempty(answer)
            close(h); % Close the loading bar
            return;
        end
    else
        % If folder doesn't exist, create it
        mkdir(mission_name);
    end

    % Pause for 0.2 seconds before moving to the next step
    pause(0.2)
    
    % Step 2: Create LOAD files
    waitbar(1 / total_steps, h, 'Creating LOAD files...');
    create_load(version, mission_name); % Function to create LOAD files
    pause(0.2)

    % Prepare list of required SPICE files (satellite trajectories)
    require = {};
    for j = 1 : length(varargin)
        require = [require ['sat', num2str(j), '_traj.bsp']]; % Add required SPICE file for each satellite
    end
    
    % Step 3: Create SPICE files
    waitbar(2 / total_steps, h, 'Creating SPICE files...');
    create_spice(version, mission_name, require); % Function to create SPICE files
    pause(0.2)

    % Step 4: Create Spacecraft files
    waitbar(3 / total_steps, h, 'Creating Spacecraft files...');
    str_centers = create_spacecraft(version, mission_name, varargin); % Function to create spacecraft files
    pause(0.2)

    % Step 5: Create SPK files
    waitbar(4 / total_steps, h, 'Creating SPK files...');
    pause(0.2)
    create_spk(mission_name, varargin); % Function to create SPK files

    % Step 6: Create Cosmos scripting files
    waitbar(5 / total_steps, h, 'Creating Python script...');
    pause(0.2)
    createCosmoscriptingScript(mission_name, str_centers, varargin); % Function to create Cosmos script

    % Step 7: Start Cosmographia application
    waitbar(6 / total_steps, h, 'Starting Cosmographia...');
    pause(0.2)
    cosmographia_exec(mission_name); % Function to execute Cosmographia

    % Display success message once all files have been created
    disp('All files have been successfully created.');

    % Close the loading bar
    close(h);
    
end
function cosmographia_exec(mission_name)
    % Check if the file `cosmo_path.txt` exists
    if isfile('cosmo_path.txt')
        % If it exists, read the saved path
        fileID = fopen('cosmo_path.txt', 'r');
        answer = textscan(fileID, '%s');
        fclose(fileID);
    else
        % If the file does not exist, ask the user for the path and create the file
        answer = char(inputdlg('Enter the path to the Cosmographia executable folder', 'First execution', 1));
        
        % Check if the user provided a path
        if isempty(answer)
            disp('No path entered. Exiting function.');
            return;
        end
        
        % Save the path in the file `cosmo_path.txt`
        fileID = fopen('cosmo_path.txt', 'w');
        if fileID == -1
            error('Unable to create the file cosmo_path.txt.');
        end
        fprintf(fileID, string(answer)); % Save the path as a string
        fclose(fileID);
    end
    
    % Get the current directory path
    old_path = char(pwd);
    
    % Check if mission_name is a string
    if isstring(mission_name)
        mis_name = char(mission_name); % Convert mission_name to a char array if it is a string
    else
        mis_name = mission_name;
    end
    
    % Detect the operating system
    if ispc
        % Command for Windows
        executable = 'Cosmographia.exe'; % Windows executable
        command = sprintf('cd /d "%s" && %s -p "%s\\%s\\cosmoscript.py" "%s\\%s\\load.json"', ...
            char(answer{1}), executable, old_path, mis_name, old_path, mis_name);
    elseif isunix
        % Command for Linux/macOS
        executable = './Cosmographia'; % Linux/macOS executable
        command = sprintf('cd "%s" && %s -p "%s/%s/cosmoscript.py" "%s/%s/load.json" &', ...
            char(answer{1}), executable, old_path, mis_name, old_path, mis_name);
    else
        error('Unsupported operating system.');
    end
    
    % Execute the command
    system(command);
end

function createCosmoscriptingScript(mission_name, str_centers, varargin)
    % Change to the mission folder
    cd(mission_name)
    
    % Initialize an empty array for storing the start dates
    min_dates = [];
    
    % Loop through each trajectory and collect start dates
    for j = 1:length(varargin{1})
        min_dates = [min_dates datetime(varargin{1}{j}.dateStart)];
    end
    
    % Find the earliest (minimum) start date
    min_dates = min(min_dates);
    
    % Convert the minimum date to a datetime format
    dt = datetime(min_dates);
    
    % Convert the datetime to string in the required format
    startTime = upper(datestr(dt, 'yyyy-mm-dd HH:MM:SS.FFF UTC')); % Uppercase for the month

    % Create a Python script for controlling Cosmographia using cosmoscripting
    % The arguments 'startTime', 'trajectories', and 'center' need to be passed as input
    
    % Define the name of the Python script
    pythonScriptName = 'cosmoscript.py';
    
    % Open the file for writing
    fileID = fopen(pythonScriptName, 'w');
    
    % Write the header of the Python script
    fprintf(fileID, 'import cosmoscripting\n\n');
    fprintf(fileID, 'cosmo = cosmoscripting.Cosmo()\n\n');
    
    % Write the initial setup section
    fprintf(fileID, '########################################\n');
    fprintf(fileID, '# Initial setup\n\n');
    fprintf(fileID, 'trajectories=[');
    
    % Loop through the trajectories and write them to the Python script
    for j = 1:length(varargin{1})
        fprintf(fileID, "'%s'", varargin{1}{j}.name);
        if j ~= length(varargin{1})
            fprintf(fileID, ',');
        end
    end
    fprintf(fileID, ']\n');
    
    % Set up Cosmographia display options
    fprintf(fileID, 'cosmo.showFullScreen()\n');
    fprintf(fileID, 'cosmo.setTime(%s)\n', strcat(strcat("'", startTime), "'")); % Use the startTime variable
    fprintf(fileID, 'cosmo.hideToolBar()\n');
    fprintf(fileID, 'cosmo.hideSpiceMessages()\n');
    fprintf(fileID, 'cosmo.hideEcliptic()\n');
    fprintf(fileID, 'cosmo.hideCenterIndicator()\n');
    fprintf(fileID, 'cosmo.hideLabels()\n');
    fprintf(fileID, 'cosmo.hidePlanetOrbits()\n\n');
    
    % Loop to show each trajectory in the Python script
    fprintf(fileID, 'for traj in trajectories:\n');
    fprintf(fileID, '\tcosmo.showTrajectory(traj)\n');
    
    % Write the center-related code (set the central object, select it, set camera)
    fprintf(fileID, 'cosmo.setCentralObject(%s)\n', strcat(strcat("'", str_centers{1}), "'"));
    fprintf(fileID, 'cosmo.selectObject(%s)\n', strcat(strcat("'", str_centers{1}), "'"));
    fprintf(fileID, 'cosmo.setCameraToInertialFrame()\n');
    fprintf(fileID, 'cosmo.setCameraToInertialFrame()\n');
    fprintf(fileID, 'cosmo.setCameraPosition( [ -18763.520461, -3770.166644, 8500.870754 ] )\n');
    fprintf(fileID, 'cosmo.setCameraOrientation( [ 0.692937, 0.376302, -0.383892, -0.480481 ] )\n');
    
    % Show labels in the view
    fprintf(fileID, 'cosmo.showLabels()\n\n');
    
    % Write the initial scene section
    fprintf(fileID, '########################################\n');
    fprintf(fileID, '# Begin scene\n\n');
    
    % Fade in the scene, wait for the specified time, set time rate and unpause
    fprintf(fileID, 'cosmo.fadeIn(1)\n');
    fprintf(fileID, 'cosmo.wait(2)\n');
    fprintf(fileID, 'cosmo.wait(1)\n');
    fprintf(fileID, 'cosmo.setTimeRate(1000)\n');
    fprintf(fileID, 'cosmo.unpause()\n');
    
    % Close the Python file
    fclose(fileID);
    
    % Inform the user that the Python script was created successfully
    disp(['Python script generated successfully: ', pythonScriptName]);
    
    % Change back to the previous directory
    cd('..')
end
function create_spk(mission_name, varargin)
    % Change to the 'lsk' directory where kernel files are stored
    cd("lsk")
    
    % Select the appropriate file based on the operating system
    if ismac || isunix
        files = dir(fullfile(['*', 'tls']));  % For UNIX or macOS, search for '.tls' files
    elseif ispc
        files = dir(fullfile(['*', 'pc']));   % For Windows, search for '.pc' files
    end
    
    % If no files are found, display an error message and return
    if isempty(files)
        cd("../")
        close all;
        error('Error: No files found with the specified extension.');
    else
        selected_file = fullfile(files(1).name); % Select the first file found
    end
    
    % Load the selected kernel file using CSPICE
    cspice_furnsh(selected_file);
    
    % Change to the 'spk/planets' directory to load SPK files for the planets
    cd("../spk/planets")
    files = dir(fullfile(['*', 'bsp']));  % Look for '.bsp' files
    if isempty(files)
        cd("../../")
        error('Error: No files found with the specified extension.');
    else
        selected_file = fullfile(files(1).name); % Select the first '.bsp' file found
    end
    
    % Load the selected SPK file using CSPICE
    cspice_furnsh(selected_file);
    
    % Change to the mission directory where the SPK files will be created
    cd("../../" + mission_name)
    
    % Loop through each trajectory to generate SPK files
    for j = 1 : length(varargin{1})
        try
            DEGREE = 1;  % Degree of the polynomial for the trajectory
            dt = datetime(varargin{1}{j}.dateStart);  % Get the start date of the trajectory
        
            % Convert the start date to a string in the required format
            utc_time = upper(datestr(dt, 'yyyy mmm dd HH:MM:SS'));  % Uppercase the month for Cosmographia
            et = cspice_str2et(utc_time);  % Convert UTC time to Ephemeris Time (ET)
            DISCRETEEPOCHS = varargin{1}{j}.t + et;  % Add time offsets to ET
            
            % States (position in km, velocity in km/s)
            DISCRETESTATES = [ varargin{1}{j}.r varargin{1}{j}.v ]';  % Position and velocity
            
            % Create and open the SPK file
            spk_file = ['sat', num2str(j), '_traj.bsp'];  % File name based on the satellite number
            if iscell(varargin{1}{j}.segid)
                varargin{1}{j}.segid = strjoin(varargin{1}{j}.segid);  % Join segment ID if it's a cell array
            end
            if isstring(varargin{1}{j}.segid)
                varargin{1}{j}.segid = char(varargin{1}{j}.segid);  % Convert to char if it's a string
            end
            
            % Open the SPK file for writing
            handle = cspice_spkopn(spk_file, varargin{1}{j}.segid, 10);
            N_DISCRETE = length(varargin{1}{j}.t);  % Number of discrete time points
            
            % Write the data to the SPK file
            if iscell(varargin{1}{j}.REF)
                varargin{1}{j}.REF = strjoin(varargin{1}{j}.REF);  % Join reference frame if it's a cell array
            end
            if isstring(varargin{1}{j}.REF)
                varargin{1}{j}.REF = char(varargin{1}{j}.REF);  % Convert to char if it's a string
            end
            
            % Write the state vectors (position, velocity) to the SPK file
            cspice_spkw09( handle, varargin{1}{j}.id, varargin{1}{j}.CENTER, varargin{1}{j}.REF, ...
                            DISCRETEEPOCHS(1), DISCRETEEPOCHS(N_DISCRETE), varargin{1}{j}.segid, DEGREE, ...
                            DISCRETESTATES, DISCRETEEPOCHS);
            
            % Close the SPK file
            cspice_dafcls(handle);
            disp('File closed.');
            
            % Wait for the system to synchronize the state
            pause(1);
            sats = varargin{1};
            
            % Call a helper function (commented out) to process the SPK file
            try_bsp(j, sats{j});
        catch
            close all
            cd("..")
            error("Error while creating ''sat" + num2str(j) + "_traj.bsp")
        end
    end
    
    % Clear all loaded CSPICE kernels
    cspice_kclear;
    
    % Go back to the previous directory
    cd("..")
    
end
function try_bsp(j, varargin)
    try
        % Load the coverage information of the SPK file
        cover = cspice_spkcov(['sat', num2str(j), '_traj.bsp'], varargin{1}.id, 1000);
        
        % Extract the start and end times from the coverage
        start_time = cspice_timout(cover(1), 'YYYY MON DD HR:MN:SC.###');
        end_time = cspice_timout(cover(2), 'YYYY MON DD HR:MN:SC.###');
        
        % Print the coverage information of the SPK file
        fprintf(['Coverage of SPK file sat', num2str(j), '_traj.bsp:\n']);
        fprintf('Start: %s\n', start_time);
        fprintf('End:   %s\n', end_time);
        
        % Load the SPK file
        cspice_furnsh(['sat', num2str(j), '_traj.bsp']);
        
        % Search for the segment descriptor
        [handle, descr, segid, found] = cspice_spksfs(varargin{1}.id, cover(1));
    
        % If no segment is found, display an error and clear kernels
        if ~found
            cspice_kclear
            txt = sprintf('No SPK segment found for body %d', varargin{1}.id);
            error(txt)
        end
    
        % Unpack the descriptor of the current segment
        ND = 2;  % Number of double-precision values in the descriptor
        NI = 6;  % Number of integer values in the descriptor
        [dc, ic] = cspice_dafus(descr, ND, NI);  % Unpack the descriptor into two arrays
    
        % Get the frame name
        frname = cspice_frmnam(ic(3));  % Get the frame name using the integer ID
    
        % Print the segment information
        fprintf('Body        = %d\n', ic(1));
        fprintf('Center      = %d\n', ic(2));
        fprintf('Frame       = %s\n', frname);
        fprintf('Data type   = %d\n', ic(4));
        fprintf('Start ET    = %f\n', dc(1));
        fprintf('Stop ET     = %f\n', dc(2));
        fprintf('Segment ID  = %s\n\n', segid);

    catch
        % Error handling (currently commented out)
        close all;
        cd("..")
        cspice_kclear;
        error("Error while reading .bsp, usually solved by restarting a Matlab session")
    end
end
function create_load(version, mission_name)
    % Change the current directory to the mission_name folder
    cd(mission_name);

    % Define the required files for the mission catalog
    require = {'spice.json','spacecraft.json'};  % Required files for the mission

    % Create a structure to hold information for the JSON
    jsonStruct = struct( ...
        'version', version, ...  % Mission version
        'name', strcat(mission_name,' Catalog'), ...  % Name of the mission catalog
        'require', {require}  ... % List of required files, passed as a cell array
    );

    % Encode the structure into a JSON format
    jsonString = jsonencode(jsonStruct, 'PrettyPrint', true);  % Create a nicely formatted JSON string

    % Open the 'load.json' file for writing
    fid = fopen('load.json', 'w');
    if fid == -1  % Check if there was an error opening the file
        cd('..');  % Go back to the main folder
        close all;  % Close any open figure windows
        error('Impossible to open file for writing: %s','load.json');  % Show an error if the file cannot be opened
    end

    % Write the JSON string to the file
    fwrite(fid, jsonString, 'char');
    fclose(fid);  % Close the file

    % Go back to the main folder after completing the operation
    cd('..');
end
function create_spice(version, mission_name, require)
    % Change the current directory to the mission_name folder
    cd(mission_name);

    % Create a structure with information for the JSON file
    jsonStruct = struct( ...
        'version', version, ...  % Mission version
        'name', strcat(mission_name,' Catalog'), ...  % Name of the mission catalog
        'spiceKernels', {require} ... % List of required SPICE kernels, passed as a cell array
    );

    % Encode the structure into a JSON format
    jsonString = jsonencode(jsonStruct, 'PrettyPrint', true);  % Create a nicely formatted JSON string

    % Open the 'spice.json' file for writing
    fid = fopen('spice.json', 'w');
    if fid == -1  % Check if there was an error opening the file
        cd('..');  % Go back to the main folder
        close all;  % Close any open figure windows
        error('Impossible to open file for writing: %s','spice.json');  % Show an error if the file cannot be opened
    end

    % Write the JSON string to the file
    fwrite(fid, jsonString, 'char');
    fclose(fid);  % Close the file

    % Go back to the main folder after completing the operation
    cd('..');
end
function str_centers = create_spacecraft(version, mission_name, varargin)
    % createMissionJSON - Creates a JSON file based on a complex template
    %
    % Input:
    %   version         - (string) The version number of Cosmographia
    %   mission_name    - (string) The common name for the mission set in JSON
    %   spacecraftParams - (struct) Specific parameters for the spacecraft
    %   outputFile      - (string) The name of the JSON file to save
    %
    % Output:
    %   A JSON file is saved in the specified directory.

    outputFile = 'spacecraft.json';
    % Create the base structure following the JSON template
    spacecrafts = [];
    
    % Load the leap seconds kernel to handle time properly
    cd('lsk');
    cspice_furnsh('latest_leapseconds.tls');  % Load leap second kernel
    cd('..');
    cd(mission_name);  % Change directory to the mission folder
    
    fade = int32(1);  % Set fade value (likely used for color coding)
    
    % Generate a color matrix based on the number of spacecraft
    color = generateColorMatrix(length(varargin{1}), "parula");
    str_centers = {};  % Initialize an empty cell array for storing spacecraft centers

    for j = 1:length(varargin{1})  % Loop through each spacecraft
        dt = datetime(varargin{1}{j}.dateStart);  % Convert start date to datetime object
        
        % Convert the start time into the required format (uppercase month)
        startTime = upper(datestr(dt, 'yyyy-mm-dd HH:MM:SS.FFF UTC'));
        
        % Convert start time to ephemeris time (ET) and calculate end time
        et = cspice_str2et(startTime) + varargin{1}{j}.t(end);  % Add duration to start time
        endTime = cspice_et2utc(et, 'C', 3);  % Convert ET to UTC
        endTime = datetime(endTime, 'InputFormat', 'yyyy MMM dd HH:mm:ss.SSS');
        endTime = datestr(endTime, 'yyyy-mm-dd HH:MM:SS.FFF UTC');  % Format the end time

        % Calculate the mission duration
        duration = find_duration(startTime, endTime);

        % Create a spacecraft item based on the parameters
        [struct_sc, str_center] = createSpacecraftItem(varargin{1}{j}, startTime, endTime, color(j,:)', duration, fade);

        % Append the created spacecraft to the list
        spacecrafts = [spacecrafts struct_sc];
        str_centers = [str_centers, str_center];
    end

    % Clear the SPICE kernels
    cspice_kclear;
    
    % Ensure spacecrafts is a cell array (in case there's only one spacecraft)
    if numel(spacecrafts) == 1
        spacecrafts = {spacecrafts};  % Force spacecrafts to be a cell array
    end

    % Create the final JSON structure
    jsonStruct = struct( ...
        'version', version, ...
        'name', strcat(mission_name, '_s/c'), ...  % Name for spacecraft catalog
        'items', {spacecrafts} ...  % List of spacecraft
    );

    % Encode the structure as a pretty-printed JSON string
    jsonString = jsonencode(jsonStruct, 'PrettyPrint', true);

    % Open the spacecraft.json file for writing
    fid = fopen(outputFile, 'w');
    if fid == -1  % If there's an error opening the file
        cd('..');
        close all;
        error('Unable to open file for writing: %s', outputFile);  % Show an error message
    end

    % Write the JSON string to the file
    fwrite(fid, jsonString, 'char');
    fclose(fid);  % Close the file

    % Display a success message
    disp(['JSON successfully saved to: ', outputFile]);
    
    % Change back to the previous directory
    cd('..');
end

function colorMatrix = generateColorMatrix(numColors, colormapName)
    % generateColorMatrix - Generates a matrix of colors based on a colormap
    %
    % Input:
    %   numColors    - (integer) The number of colors to generate
    %   colormapName - (string) The name of the colormap (e.g., 'jet', 'hsv', 'parula')
    %
    % Output:
    %   colorMatrix  - (matrix) A matrix of RGB color values

    % Check if the colormap exists
    if ~exist(colormapName, 'file')
        close all;
        error('Color map "%s" does not exist. Try with "jet", "hsv", "parula", etc.', colormapName);
    end

    % Generate the colormap with the specified number of colors
    cmapFunction = str2func(colormapName);  % Get the function handle for the colormap
    colorMatrix = cmapFunction(numColors);  % Generate the color matrix
end
function dur = find_duration(tstart, tend)
    % find_duration - Calculates the duration between two times in days
    %
    % Input:
    %   tstart - (string) The start time in 'yyyy-mm-dd HH:MM:SS.FFF UTC' format
    %   tend   - (string) The end time in 'yyyy-mm-dd HH:MM:SS.FFF UTC' format
    %
    % Output:
    %   dur    - (string) The duration between tstart and tend in days

    % Remove " UTC" from the time strings
    tstart = replace(tstart, ' UTC', '');
    tend = replace(tend, ' UTC', '');

    % Convert times to date vectors
    date2 = datevec(tend);
    date1 = datevec(tstart);
    
    % Calculate the difference between the two dates
    t_diff = date2 - date1;

    % Initialize duration as 1 day
    dur = 1;
    
    % If the day difference is non-zero, calculate the full duration in days
    if abs(t_diff(3)) > 0
        dur = abs(t_diff(1)) * 365 + abs(t_diff(2)) * 30 + abs(t_diff(3));
    end
    
    % Return the duration as a string
    dur = [num2str(dur), ' d'];
end
function [spacecraftItem, center] = createSpacecraftItem(sat, startTime, endTime, color, duration, fade)
    % createSpacecraftItem - Creates a spacecraft item for the JSON structure
    %
    % Input:
    %   sat       - (struct) A structure containing spacecraft information
    %   startTime - (string) The start time of the spacecraft's trajectory
    %   endTime   - (string) The end time of the spacecraft's trajectory
    %   color     - (array) RGB color for labeling and trajectory plotting
    %   duration  - (string) Duration of the spacecraft's mission (in days)
    %   fade      - (integer) Fade effect value for the trajectory plot
    %
    % Output:
    %   spacecraftItem - (struct) The spacecraft item with all relevant properties
    %   center         - (string) The center of the spacecraft's trajectory

    % Get the center of the spacecraft from SPICE
    [center, found] = cspice_bodc2n(sat.CENTER);  % Get center body name
    if ~found
        error('Center not found');
    end
    
    % Convert center to lowercase and capitalize the first letter of each word
    center = lower(center);
    center = regexprep(center, '(\<\w)', '${upper($1)}');

    % Create the spacecraft item structure
    spacecraftItem = struct( ...
        'class', 'spacecraft', ...
        'name', sat.name, ...  % Name of the spacecraft
        'startTime', startTime, ...
        'endTime', endTime, ...
        'center', num2str(center), ...
        'trajectory', struct( ...
            'type', 'Spice', ...
            'target', num2str(sat.id), ...
            'center', num2str(center) ...
        ), ...
        'label', struct( ...
            'color', color ...  % Color for the spacecraft label
        ), ...
        'trajectoryPlot', struct( ...
            'color', color, ...
            'lineWidth', 4, ...
            'sampleCount', 2000, ...
            'lead', '1 s', ...
            'duration', duration, ...
            'fade', fade ...
        ) ...
    );
end
function fields_check(varargin)
    % fields_check - Verifies that the fields of the satellite structures have correct types and sizes
    %
    % Input:
    %   varargin - A variable number of input arguments containing satellite data
    %
    % Output:
    %   Throws an error if any field of the satellite structure is invalid

    % Loop through all satellite structures in the input
    for j = 1 : length(varargin{1})
        % Check if the 'name' field is a string or character array
        name = varargin{1}{j}.name;
        if ~isstring(name) && ~ischar(name)
            close all;
            error(['name field of sat #', num2str(j), ' is not a string or char!']);
        end
        if isstring(name)
            varargin{1}{j}.name = char(varargin{1}{j}.name);  % Convert string to char array
        end

        % Check if the 'id' field is numeric
        id = varargin{1}{j}.id;
        if ~isnumeric(id)
            close all;
            error(['id field of sat #', num2str(j), ' is not an integer!']);
        end

        % Check if the 'segid' field is a string or character array
        segid = varargin{1}{j}.segid;
        if ~isstring(segid) && ~ischar(segid)
            close all;
            error(['segid field of sat #', num2str(j), ' is not a string or char!']);
        end
        if isstring(segid)
            varargin{1}{j}.segid = char(varargin{1}{j}.segid);  % Convert string to char array
        end

        % Check if 't' (time vector) is a column vector
        t = varargin{1}{j}.t;
        l = length(t);
        if size(t,1) ~= l || size(t,2) ~= 1
            close all;
            error(['time vector of sat #', num2str(j), ' must be a column vector: [', num2str(l), 'x1]!']);
        end

        % Check if 'r' (position vector) has 3 columns
        r = varargin{1}{j}.r;
        if size(r,2) ~= 3
            close all;
            error(['position vector of sat #', num2str(j), ' must be a [', num2str(l), 'x3] vector!']);
        end

        % Check if 'v' (velocity vector) has 3 columns
        v = varargin{1}{j}.v;
        if size(r,2) ~= 3
            close all;
            error(['velocity vector of sat #', num2str(j), ' must be a [', num2str(l), 'x3] vector!']);
        end

        % Check that position and velocity vectors have the same number of rows
        if size(r,1) ~= l || size(v,1) ~= l
            close all;
            error(['Check that position and velocity vectors of sat #', num2str(j), ' have dimensions [', num2str(l), 'x3]!']);
        end

        % Check if 'CENTER' field is numeric
        CENTER = varargin{1}{j}.CENTER;
        if ~isnumeric(CENTER)
            close all;
            error(['CENTER field of sat #', num2str(j), ' is not an integer!']);
        end

        % Check if 'REF' field is a string or character array
        REF = varargin{1}{j}.REF;
        if ~isstring(REF) && ~ischar(REF)
            close all;
            error(['REF field of sat #', num2str(j), ' is not a string or char!']);
        end
        if isstring(REF)
            varargin{1}{j}.REF = char(varargin{1}{j}.REF);  % Convert string to char array
        end

        % Validate the 'dateStart' field
        dateStart = varargin{1}{j}.dateStart;
        date_check(dateStart);  % Call date_check function to validate the date format
    end
end
function date_check(date)
    % date_check - Verifies if the date vector is in the correct format
    %
    % Input:
    %   date - A vector representing a date with the format [yyyy, mm, dd, hh, mm, ss.ss]
    %
    % Output:
    %   Throws an error if the date vector does not have length 6

    % Check if the length of the date vector is 6
    if length(date) ~= 6
        close all;  % Close all open windows
        error('\nDate vector is in the wrong format, use [yyyy, mm, dd, hh, mm, ss.ss]');
    end
end
function sameStructure = compareStructs(struct1, struct2)
    % compareStructs - Compares two structures to check if they have the same fields
    %
    % Input:
    %   struct1 - First structure to compare
    %   struct2 - Second structure to compare
    %
    % Output:
    %   sameStructure - A boolean (true/false) indicating if the two structures have the same fields

    % Extract the field names of both structures
    fields1 = fieldnames(struct1);
    fields2 = fieldnames(struct2);
    
    % Check if the fields are the same (order does not matter)
    if isequal(sort(fields1), sort(fields2))
        sameStructure = true;  % The structures have the same fields
    else
        sameStructure = false;  % The structures have different fields
    end
end
function input_check(varargin)
    % input_check - Validates if each input argument is a valid satellite structure.
    %
    % Input:
    %   varargin - A variable number of input arguments. Each argument is expected 
    %              to be a structure representing a satellite with fields like 
    %              'name', 'id', 'segid', 'dateStart', 't', 'r', 'v', 'CENTER', and 'REF'.
    %
    % Output:
    %   Throws an error and closes all open windows if any input argument is not
    %   a valid satellite structure.

    % Define the template structure for a satellite
    sat = struct('name', [], 'id', [], 'segid', [], 'dateStart', [], 't', [], 'r', [], 'v', [], 'CENTER', [], 'REF', []);
    
    % Iterate through each input argument
    for j = 1 : nargin
        % Check if the current argument matches the satellite structure template
        if ~compareStructs(sat, varargin{1,1}{1,j})
            close all;  % Close all open windows if the structure doesn't match
            error(['Structure sat #', num2str(j), ' is not a valid satellite structure!']);
        end
    end
end

%
