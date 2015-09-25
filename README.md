cartool
=======

Export images from OS X / iOS .car CoreUI archives. Very rough code, probably tons wrong with it, but still useful.

Once you've downloaded the zip from github, compile it in Xcode to generate the command line tool. Then expand the Products group and right click on the cartool file and locate it in finder. You can then run the tool like so:

open terminal

cd /path/to/cartool

cartool /path/to/Assets.car /path/to/outputDirectory

or

./cartool /path/to/Assets.car /path/to/outputDirectory
