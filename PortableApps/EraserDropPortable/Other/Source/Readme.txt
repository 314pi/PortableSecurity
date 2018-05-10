EraserDrop Portable Launcher
==================================
Copyright 2004-2009 John T. Haller
Copyright 2007-2009 Erik Pilsits

Website: http://PortableApps.com/EraserDropPortable

This software is OSI Certified Open Source Software.
OSI Certified is a certification mark of the Open Source Initiative.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

ABOUT ERASERDROP PORTABLE
=========================
The EraserDrop Portable Launcher allows you to run EraserDrop from a removable
drive whose letter changes as you move it to another computer.  The application can be
entirely self-contained on the drive and then used on any Windows computer.


LICENSE
=======
This code is released under the GPL.  Within the Source directory you will find the code
(EraserDropPortable.nsi) as well as the full GPL license (License.txt).  If you use
the launcher or code in your own product, please give proper and prominent attribution.


INSTALLATION / DIRECTORY STRUCTURE
==================================
By default, the program expects the following directory structure:

-\ <--- Directory with EraserDropPortable.exe
	+\App\
		+\EraserDrop\
	+\Data\
		+\images\
		+\settings\


ERASERDROPPORTABLE.INI CONFIGURATION
====================================
The EraserDrop Portable Launcher will look for an ini file called
EraserDropPortable.ini within its directory (see the Installation/Directory Structure
section above for more details).  If you are happy with the default options, it is not
necessary, though.  The INI file is formatted as follows:

[EraserDropPortable]
DisableSplashScree=false

DisableSplashScreen allows you to disable the splash screen when set to true.


USAGE
=====
See the Readme.txt in the App\EraserDrop folder.