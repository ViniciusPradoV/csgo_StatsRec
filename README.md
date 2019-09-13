# csgo_statsRec
A statistics recording plugin for CS:GO servers

This plugin records statistics for players on CS:GO servers and displays it on a menu


# Installation:

1. *Only works on MySQL*. Add this database entry to your "databases.cfg" file, 
it should be located on "server/csgo/addons/sourcemod/configs/databases.cfg"

```
"Databases"
{
	"statsrec"
	{
		"driver"         "mysql"
		"host"           "localhost"
		"database"       "statsrec"
		"user"           "root"
		"pass"           ""
	}
}
```

2. Compile the .sp file using SPEdit (https://github.com/JulienKluge/Spedit).
3. Put the generated .smx file on your "plugins" server folder. It should be located on: "server/csgo/addons/sourcemod/plugins".

# CVars - Console Variables

### csgo_statsrec_enabled

 Controls if plugin is enabled - Set "1" to enable and "0" to disable
 
 
# Console Commands

### sm_mystats

Displays a menu with player stats, as seen in the image below

![csgo_statsRec_menu](https://i.imgur.com/1Qj52IJ.jpg)
