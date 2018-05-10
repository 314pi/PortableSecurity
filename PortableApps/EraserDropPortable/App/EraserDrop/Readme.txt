EraserDrop 2.1.1 Readme
=======================


Move Target:
============
Move the drop target by holding the LEFT SHIFT key, LEFT-CLICKING the target, and dragging.


Wipe Progress:
==============
Hover the mouse over the tray icon to see the percent of the job completed.


Context Menu:
=============
Right-click to open the context menu - Tasks -> | Options -> | Reload | Hide | Terminate All Jobs | Help | About... | Exit


Main Menu:
==========
==> Reload
Reloads the drop target image.

==> Hide
Hide the drop target.  Show the target via hotkey (if you set it) or by clicking the tray icon.

==> Terminate All Jobs
Terminates the currently running job and removes all jobs from the queue.

==> Help
Open this help file.


Tasks:
======
==> Wipe Recycle Bin
Securely wipe the contents of all Recycle Bins.

==> Wipe Free Space...
Securely wipe the selected drive's free space.


Options:
========
[==> Option (default: 0 = false | 1 = true)]
[Description]

==> Eraser Method (Pseudorandom 1 Pass)
Controls how Eraser will wipe the file(s) and folder(s).

==> Warn Before Erasing (1)
Issue a warning before erasing.

==> Show Erasing Report (1)
A report will be shown after wiping completes.  The report will always be shown if there are
any errors.

==> Show Tray Tips (1)
Tray tips will be shown when the wipe begins and ends.

==> Flash Tray Icon (1)
Tray icon will flash while a wipe is in progress.

==> Animate GUI (0)
GUI will fade in and out while a wipe is in progress.

==> Always On Top (1)
Keep the drop target on top of other windows.

==> Set Hotkey... (none)
Set the hotkey that will show / hide the target.

Leave this field blank to disable the hotkey.

Be careful using the WIN (#) key in hotkeys.  This key may conflict with system hotkeys, or
just not work at all.

For other special keys, see the AutoIt3 documentation:
http://www.autoitscript.com/autoit3/docs/appendix/SendKeys.htm

==> Change Target Image...
Create your own target image by placing your custom PNG graphic in the 'Data\images'
directory and selecting it from the file dialog.

==> Reset Target Image
Reset the drop target to the default image.


Commandline Arguments:
======================
==> exit
Exits an existing EraserDrop instance (scripting).