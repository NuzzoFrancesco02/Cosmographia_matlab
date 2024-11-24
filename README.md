# Cosmographia Plot: SPICE Mission Visualization Tool

**Cosmographia Plot** is a MATLAB function designed to generate the necessary files for visualizing space missions in **Cosmographia**, using satellite trajectory data. The function automates the creation of SPICE kernels, configuration files, and a simple Cosmoscripting script.

## Key Features
- Automatic creation of mission directories.
- Generation of SPICE kernels (SPK, PCK, LSK).
- Creation of LOAD files and configurations for Cosmographia.
- Generation of a Python script for Cosmoscripting.
- Direct launch of Cosmographia with mission data preloaded.

---

## Requirements
### Required Software
1. **MATLAB R2020b** (or later).

2. **Cosmographia** installed on your system:  
   [Download Cosmographia](https://naif.jpl.nasa.gov/naif/cosmographia_components.html)  
   The path to the Cosmographia executable will be requested the first time the script is run.

3. **MATLAB SPICE Toolkit (MICE)**:  
   [Download MICE](https://naif.jpl.nasa.gov/naif/toolkit_MATLAB.html)  
   Add the following directories to your MATLAB path:  
   - `/mice/src/mice`  
   - `/mice/lib`  

   Example commands to set up the path:  
   ```matlab
   addpath("path/to/your/mice/src/mice")
   savepath
   addpath("path/to/your/mice/lib")
   savepath
   ```

---

### Required Files
Make sure the following files are available in the specified subdirectories:
1. **Time Constants Kernel (LSK)**:  
   Download from [LSK Kernels](https://naif.jpl.nasa.gov/pub/naif/generic_kernels/lsk/)  
   Place in the `/lsk` folder. Windows users should use the `.pc` extension.
   example: latest_leapseconds.tls

3. **Planetary SPK Kernel**:  
   Download from [SPK Kernels](https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/planets/)  
   Place in the `/spk/planets` folder.
   example: example: de435.bsp (it's not on Git)
4. **Binary PCK Kernel**:  
   Download from [PCK Kernels](https://naif.jpl.nasa.gov/pub/naif/generic_kernels/pck/)  
   Place in the `/pck` folder. (example: earth_latest_high_prec.bpc)

### ATTENTION!
All SPICE kernels used must also be added to the spice folder within Cosmographia's data directory. 
Additionally, they must be listed in the spice_kernels.json file. Ensure you locate the Cosmographia data directory, 
add the required SPICE kernels, and update the spice_kernels.json file accordingly.

---

## Usage
### Function Syntax
cosmographia_plot.m and the folders spk/, pck/, lsk/ must be in the same folder!
```matlab
cosmographia_plot(mission_name, sat1, sat2, ...)
```

### Input Details
1. `mission_name` (string): The name of the mission directory to create.  
2. `sat` (struct): A structure containing satellite trajectory data. Example:
   ```matlab
   sat = struct('name', 'sat1', ...
                'id', -1001, ...
                'segid', 'Segment ID', ...
                'dateStart', [2024 11 23 19 00 00], ...
                't', [time_array]', ...
                'r', [position_array]', ...
                'v', [velocity_array]', ...
                'CENTER', 399, ...
                'REF', 'J2000');
   ```

### Example
```matlab
[t, r, v] = propagate_orbit(...);  % Example function for orbital propagation
sat1 = struct('name', 'sat1', 'id', -1001, 'segid', 'Segment1', ...
              'dateStart', [2024 11 23 19 00 00], 't', t, ...
              'r', r, 'v', v, 'CENTER', 399, 'REF', 'J2000');
cosmographia_plot('MyMission', sat1);
```

For multiple satellites:
```matlab
cosmographia_plot('MyMission', sat1, sat2, sat3, ...);
```

---

## Output
The function creates the following:
1. **Mission directory**: Contains all generated files.
2. **SPICE kernels**: `.bsp` files for satellite trajectories.
3. **Cosmoscripting Python script**: Automates Cosmographia setup and visualization.
4. **LOAD file**: Prepares Cosmographia to use the generated kernels.

---

## Notes
1. Ensure all SPICE kernels are correctly placed before running the function.
2. For the first run, you will be prompted to specify the path to the **Cosmographia executable**.

---

## License
This tool is provided "as is" without warranty of any kind. Please check and adhere to the licensing terms of Cosmographia and MICE when using this tool.
