# pgptool-launcher

pgptool.exe is a Windows executable that uses Java installation details returned from [JavaInfo.dll](https://github.com/Bill-Stewart/JavaInfo) to run the [PGPTool](https://pgptool.github.io/) Java application.

## AUTHOR

Bill Stewart - bstewart at iname dot com

## LICENSE

**pgptool-launcher** is covered by the GNU Lesser Public License (LGPL). See the file `LICENSE` for details.

## DOWNLOAD

https://github.com/Bill-Stewart/pgptool-launcher/releases

## USAGE

All that is required is to put the following files in the same directory:

* `JavaInfo.dll`
* `pgptool.exe`
* `pgptoolgui-`_version_`.jar`

(Where _version_ is the latest version of the PGPTool jar file)

## REMARKS

The pgptool.exe program does the following:

* Locates the latest pgptoolgui-_version_.jar in its directory
* Checks if Java is installed on the system, and if it is at least version 8
* Gets the path to javaw.exe, and executes PGPTool with the following command line:

  `"`_java_path_`\bin\javaw.exe" -jar "`_path_to_jar_`"`

If pgptool.exe runs into any problems, it displays a GUI dialog box with an explanation.
