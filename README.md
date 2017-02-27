## Toggl to Navision converter

This utility can be used to convert from Toggl entries to Navision entries

It will take as argument the name of a config file and process the content accordingly

To use this utility, check the **start.bat** file, ths will simply execute the following command:

```
  luajit.exe main.lua 
```

By default the **config.lua** file found in the same folder will be loaded, but this can also 
be specified on the command line such as with:

```
  luajit.exe main.lua C:/path/to/my/config.lua 
```

The config file is were all the user specific config values are speficied, chech its content 
for more explanations.

The most important config elements are:
  - **work_hours**: the number of work hours required for each day, if this threshold is not reached
for a given day in the inputs, this tool will automatically add a **COMPENSATE** entry for that day.
  - **jobFunc**: this function is responsible for extracting the desired Job name from a given toggl entry
  - **phaseFunc**: this function is responsible for extracting the desired Phase name from a given toggl entry

Note that this utility is also able to find complete work days were no entries are provided and will add **COMPENSATE** entry in that case.

Also note that currently vacation handling is not implemented and would still have to be added manually.
