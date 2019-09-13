# csgo_statsRec
A statistics recording plugin for CS:GO servers

This plugin records statistics for players on CS:GO servers and displays it on a menu


Installation:

You need to use MySQL for that plugin to work. Copy and paste this on your "databases.cfg" file, 
it should be located on "server/csgo/addons/sourcemod/configs/databases.cfg

"Databases"
{
  "statsrec"
  {
    "driver"    "mysql"
    "host"      "localhost"
    "database"  "statsrec"
    "user"      ""
    "pass"      ""
  }
}

Compile the .sp file using SPEdit (https://github.com/JulienKluge/Spedit/releases/download/1.2.0.3/speditInstaller1.2.0.3.exe).
Put the .smx file on your "plugins" server folder. It should be located on: "server/csgo/addons/sourcemod/plugins".
