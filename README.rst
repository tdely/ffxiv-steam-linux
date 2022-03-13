FFXIV for Steam on Linux
====

This is a shell script for running the Steam version of Final Fantasy XIV on
Linux. Place the script in the location you wish to keep your Wine prefix:
the script will be run from this place both to install and to launch FFXIV.

Commands
----

**install** will set up a Wine/Proton installation and prefix using
GloriousEggroll's proton-ge-custom build, into which it:

* installs required runtime libraries using winetricks
* installs DXVK
* symlinks the compatibility Steam folder used by ordinary Proton
* disables breaking cutscenes
* installs XIVLauncher

The script will not install while the prefix destination exists, and will abort
on any error encountered.

**run** launches XIVLauncher in the prefix.

**info** prints out some DXVK environment variables relevant to *run* and status
of the prefix.

Requirements
----

* winetricks
* curl
* steam
