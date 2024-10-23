
# PrecisionLabeller
PrecisionLabeller is a MATLAB-based application for precise data labelling and visualisation. It allows users to scrub through the data or video to apply labels. 

Data are referenced to each other using a nearest-neighbor interpolation method. They are synchronised to a video clip through a user-defined offset to calculate the approximate data time.

# Features
- Visualises video timeline alongside data stream with indicator
- Allows real-time labeling via keyboard inputs
- Allows manual labelling by selecting region of interest
- Automatic timeline synchronisation across multiple sensor times to video time.
- Supports Windows and MacOS MATLAB versions.

# Installation
Ensure MATLAB version 2020a or higher is installed.
#### 1. Download the required version folder from 
#### 2. Open MATLAB and add downloaded folder path to current workspace
```matlab
addpath("/path/to/version_folder");
```
#### 3. Create a `default.ini` file and type in the required file paths for all sections. (Check Usage/Examples in `README.me` for instructions)

# Usage/Examples
Before initial startup, the `default.ini` file must be configured. Check 'default.1.ini' in `READ.me` for format guide.
#### 1. **Initialising the tool.**
```matlab
d = DataLabellingTool.init;
```
#### 2. **Loading Configuration Files.**
- Load the default `default.ini` file.
    ```matlab 
    d.loadFiles % defaults filepath to default.ini;
    ```
- Load a specific .ini file (i.e.`my_defaultV1.ini`).
    ```matlab
    d.loadFiles("defaultV1.ini");
    ```
- Load a preset file (i.e.`preset.mat`)
    ```matlab
    d.loadFiles("preset.mat");
    ```
- Load a preset file (i.e.`my_presetFile.mat`)
    ```matlab
    d.loadFiles("my_presetFile.mat");
    ```

#### 3. **Adding Sensors.**


## `default.ini` File Format
#### Editable Elements
- **Name of File**: File name of `default.ini` can be changed to any valid file name. (i.e. `defaultV1.ini`).

- **Order of Sections**: The order of sections can be changed without affecting functionality.

- **Keys in Sections**: Keys within sections can be renamed (e.g., `SensorFile1` can be changed to `Shank`).

- **Values**: The values of keys can be customized, such as file paths or specific settings.

- **ClassList**: This can be left empty, and the list can be incomplete or unordered. The `IniFileHandler` will parse only the key-value pairs provided.

- **Number of Keys**: The number of keys within a section is flexible. 
For example:
    ```ini
    [SensorFiles]
    ShankL1 = Person1LeftShank.csv
    ThighL2 = Person2LeftThigh.csv
    ShankL3 = Person3LeftShank.csv
    ...
    ShankR99 = Person99RightShank.csv
    ```
    - All 99 file paths will be parsed.
    - **Note**: No limit testing has been performed, but in theory, the program should function normally with any number of keys.

#### Headers
    `[]`: Denotes a section in the `INI` file.
    `#`: Denotes a comment. Anything following `#` on a line will be ignored.
    `=`: Separates keys from values. The `IniFileHandler` only parses lines that contain `=`. The `:` symbol is not supported.

### Section Breakdown
**NOTE**: Only **[SensorFiles]**, **[VideoFiles]**, **[Offset]**, **[LabelFolder]**, **[ClassList]** sections are allowed. Any other section headers are ignored.
- **[SensorFiles]**: Contains file paths to your sensor CSV files.
    - **Requirements**:
        - Files **must be `.csv`**.
        - The CSV files **must include a `Time (s)` variable** as the timer. The `IniFileHandler` is hardcoded to use `Time (s)` as the time variable for generating new save files.
  
- **[VideoFiles]**: Contains file paths to your video files.
    - **Requirements**:
        - Files **must be `.mp4`**.

- **[Offset]**: Contains the offset value, calculated as `Video time - Sensor time`.
    - **Requirements**:
        - Value **must be a number**.
    - **Specificity**:
        - Name as `VIDEONAME_SENSORFILENAME`
            - i.e. `VideoFile1_SensorFile1 = 5` to add a 5 second offset to SensorFile1.
        - Name `VIDEONAME`
            - i.e. `VideoFile1 = 5` to apply a 5 second offset to all sensor files.

- **[LabelFolder]**: Specifies the folder path where output files (e.g., labeled datasets) will be saved.

- **[ClassList]**: Contains user-defined labels that correspond to different actions or states (e.g., Sitting, Walking).

### Additional Customization Options
- **Output Files**: You can change the names of output (save) files using the `changeSaveName()` function.
- **ClassList**: You can modify the `ClassList` dynamically using the `changeClassList()` function.

### `default.ini` Template

Here’s a sample template of the `default.ini` file for reference:

```ini
# Comment lines with #
# Commenting from the middle of the line is not allowed.

[SensorFiles]
# Sensor Names can be changed
SensorFile1=/Users/username/path/to/sensor1.csv
SensorFile2=/Users/username/path/to/sensor2.csv
SensorFile3=
SensorFile4=
SensorFile5=

[VideoFiles]
# Video Names can be changed
# Drive origin must be explicity added in file path, i.e. C:/ or D:/...
# File paths without drive origin cannot be parsed by VLC
VideoFile1=C:/Users/username/path/to/video1.mp4
VideoFile2=
VideoFile3=
VideoFile4=
VideoFile5=

[Offset]
# Offset = Video_Time - Data_Time
# VIDEOFILE_SENSORFILE1 = OFFSET to apply offset for specific sensor
# VIDEOFILE = OFFSET to apply offset to all sensors for this video
VideoOffset=4

[LabelFolder]
# Output save folder
LabelFolder=/Users/username/path/to/output/folder

[ClassList]
1=Sitting
2=Standing
3=Walking level
4=Walking uphill
5=Walking downhill
6=Walking upstairs
7=Walking downstairs
```
## Functions
