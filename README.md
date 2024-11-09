
# PrecisionLabeler

PrecisionLabeler is a MATLAB-based application for precise data labeling and visualisation. It allows users to scrub through the data or video to apply labels. 

Data are referenced to each other using a nearest-neighbor interpolation method. They are synchronised to a video clip through a user-defined offset to calculate the approximate data time.

## Features

- Visualises video timeline alongside data stream with indicator
- Allows real-time labeling via keyboard inputs
- Allows manual labelling by selecting region of interest
- Automatic timeline synchronisation across multiple sensor times to video time.
- Supports Windows and MacOS MATLAB versions.

## Installation
1. Ensure MATLAB version 2020a or higher is installed.
2. Ensure latest version of VLC is installed. (e.g. >> v=VLC();v.play('somevideo.mpg')) 
    - matlab-vlc from https://gitlab.com/leastrobino/matlab-vlc
    - jason_decode from https://gitlab.com/leastrobino/matlab-json
4. Open MATLAB and navigate to the `Data Labelling Tool (David)` folder.
5. Open `default.ini` and type in the required file paths for all sections. (Check Usage/Examples in `README.me` for instructions)

## Usage/Examples
Before initial startup, the `default.ini` file must be configured.\
Check 'default.ini' in `default.ini File Format` for format guide.\
Read `Function Descriptions` for information on input arguments and functions. </br>
1. **Initialising the tool.**
```matlab
d = DataLabellingTool.init;
```

2. **Loading Configuration Files.**
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
- Load a named preset file (i.e.`my_presetFile.mat`)
```matlab
d.loadFiles("my_presetFile.mat");
```
- manually import files from the gui
```matlab 
d.import()
```
- manually import files with file paths.
```matlab
d.import("C://PATH/TO/FILE")
```


3. **Adding Sensors.**
- Load available sensor files as sensors
```matlab 
d.addSensors
```
- Load a specific sensor file as sensor.
```matlab
d.addSensors("SensorFile1");
```
- Load a specific sensor file as sensor with custom name
```matlab
d.addSensors("SensorFile1", "LeftShank")
```
- Load a specific sensor file as sensor with custom name and specific columns
```matlab
d.addSensors("SensorFile1", "LeftShank", [1 3:10])
```

4. **Plot Sensors.**
- Plot sensors
```matlab 
d.plot("PlotName", "LeftShank", [1 3:10])
```

5. **Play Video.**
- Play in VLC
```matlab
d.play("VideoFile1")
```

### `default.ini` File Format
#### Editable Elements
- **Name of File**: File name of `default.ini` can be changed to any valid file name. (i.e. `defaultV1.ini`).
- **Order of Sections**: The order of sections can be changed without affecting functionality.
- **Keys in Sections**: Keys within sections can be renamed (e.g., `SensorFile1` can be changed to `Shank`).
- **Values**: The values of keys can be customized, such as file paths or specific settings.
- **ClassList**: This can be left empty, and the list can be incomplete or unordered. The `IniFileHandler` will parse only the key-value pairs provided.
- **Number of Keys**: The number of keys within a section is flexible. For example:
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
        - Include drive `C://` into the file path

- **[Offset]**: Contains the offset value, calculated as `Video time - Sensor time`.
    - **Requirements**:
        - Value **must be a number**.
    - **Specificity**:
        - 

- **[LabelFolder]**: Specifies the folder path where output files (e.g., labeled datasets) will be saved.

- **[ClassList]**: Contains user-defined labels that correspond to different actions or states (e.g., Sitting, Walking).

### Additional Customization Options
- **Output Files**: You can change the names of output (save) files using the `changeSaveName()` function.
- **ClassList**: You can modify the `ClassList` dynamically using the `changeClassList()` function.

### `default.ini` Template

Here’s a sample template of the `default.ini` file for reference:

```ini
[SensorFiles]
SensorFile1=/Users/username/path/to/sensor1.csv
SensorFile2=/Users/username/path/to/sensor2.csv
SensorFile3=
SensorFile4=
SensorFile5=

[VideoFiles]
VideoFile1=C:/Users/username/path/to/video1.mp4
VideoFile2=
VideoFile3=
VideoFile4=
VideoFile5=

[Offset]
VideoFile1=4
VideoFile1_SensorFile1=5
VideoFile1_SensorFile2=-10

# Save folder
[LabelFolder]
LabelFolder=/path/to/output/folder

[ClassList]
1=Sitting
2=Standing
3=Walking level
4=Walking uphill
5=Walking downhill
6=Walking upstairs
7=Walking downstairs
```
## Function Descriptions
Section of all public functions and their usages.\
All Publicly Accessible Methods
### Instantiator
```matlab
d = d.init()
```

### Deconstructor
```matlab
d.quit()
```

### Files
- Load `default.ini` as config file.
```matlab
d.loadFiles()
```
- Load specific .ini file
```matlab
d.loadFiles("filePath")
```
- Select multiple (or individual) files to import through GUI
```matlab
d.import()
```
- Manually import files with file paths.
```matlab
d.import("filePath")
d.import("filePath1", "filePath2", ... "filePath99")
```
- Remove imported files with file name.
```matlab
d.removeFiles("fileName")
```
- Save snapshot of current tool config. Named as "preset_DATE_TIME.mat"
```matlab
d.savePreset()
```
- Save snapshot of current tool config. With custom name "fileName_DATE_TIME".
```matlab
d.savePreset("fileName")
```

### Sensors
- Add all sensor files as sensors
```matlab
d.addSensors()
```
- Add 1 specific sensor file as sensor.
```matlab
d.addSensors("sensorFileName")
```
- Add 1 specific sensor file with custom sensor name.
```matlab
d.addSensors("sensorFileName", "newSensorName")
```
- Add 1 specific sensor file of selected columns with custom name
```matlab
d.addSensors("sensorFileName", "newSensorName", columnsInFile)
```

- Remove Sensors
```matlab
d.removeSensors("sensorName")
```

- Change time column in sensors
```matlab
d.changeTimeRow("sensorName", "newCol")
```

### Change Properties
- Change save file names. Prompts for file path.
```matlab
d.changeSaveName()
```

- Change label folder output path. Prompts for folder path.
```matlab
d.changeLabelFolder()
```
### Offset
NOTE: If there is an offset for specific sensors, the uniform offset for all sensors will not be used for the sensor.
- Changing uniform offset for all sensors to a video
```matlab
d.changeOffset("videoName", offset)
```
- Changing individual sensor offset to a video.
```matlab
d.changeOffset("videoName", offset, "sensorName")
```
- Remove offset
```matlab
d.removeOffset("offsetName")
```

### Plots
- Plot from sensors
```matlab
d.plot("plotName", "sensorName", columnsInSensor)
```
- Remove plot from d.Plots structure.
```matlab
d.removePlot("plotName")
```

### Label Files
- Generate new labels for all sensors
```matlab
d.newLabelFile()
```
- Load label file.
```matlab
d.loadLabelFile("filePath")
```
- Save all current labels.
```matlab
d.saveLabelFile()
```

### Videos
- Play video synced to plots.
```matlab
d.play("videoName")
```
- Sync video with sensors
```matlab
d.syncVideo("videoName")
```

### Features
- Select two points on available plots.
```matlab
d.select()
```
- Remove selected two points on available plots.
```matlab
d.deselect()
```
- Edit labels between two points
```matlab
d.edit()
```
- Export all created sensors
```matlab
d.exportFeatures()
```
