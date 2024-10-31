## v1.3.0 - 31/10/2024
v1.3.0 expands users' ability in changing the tool's property

- Global listeners now declared in from instantiator

- Changed:
    - file import logic. Now you can import files while the plots and video are running

    - offset storing logic. Offsets are now stored in sensors userData

    - selector on plots to sensor logic. Selectors now reference to sensors by CurrentAxes UserData

- Added:
    - changeLabelFolder()
    - changeOffset(videoName, varargin)
    - removeOffset(name)
    - syncVideo(fileName)
        - syncVideo() is done by SensorManager

    - InvalidFolder error handle
    - InvalidFileName error handle

- Major changes to comments. Now giving a more detailed explanation of code.

## v1.2.0 - 27/10/2024
- Fixed d.import()\
    usage:
    ```
    d.import()
    d.import(filePath1, filePath2, ... filePath99)
    ```
    (*.m) file now allows multiple table imports, i.e. One .m file containing multiple tables or timetables

    (*.m) data tables or timetables do not need to be named "Tbl" anymore.
    #### NOTE: only tables or timetables are allowed to be imported.
   - File imports will check for repeated names from existing structure and show warning

- Added d.removeFiles(fileName)
    - fileName refers to the variable name in the structures.
    - no need to specify SensorFile or VideoFile, it will automatically find the file name and delete accordingly

- Minor comment changes

## v1.1.0: - 14/10/2024
- Added minor features
    - d.import(): manual import files
    - d.changeTimeRow(): manual change time row in selected sensor
    - d.changeSaveName(): manual change save name for save version files

- Changed FileHandler loadFile() logic
    - categorise() is no longer a nested function, instead a separate function to load files according to given file type; returns new struct()

## v1.0.0 - 07/10/2024
- Rewrote labelling logic
- Direct labelling on sensors before copying to main ground truth file
- Earlier versions label on main ground truth before labelling on separate sensors.


## [BETA] - 17/09/2024
- Improved communication between classes: Facade, Singleton design
- Improved File handling logic
- Improved error handling
- default.ini file layout
- Labelling is done on a ground truth file and then transferred to the sensor table

## [ALPHA] - 05/09/2024

- Initial release with basic functionality of the program.
- Introduced the core labeling and IMU data features.
