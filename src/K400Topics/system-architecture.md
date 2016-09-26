# System Architecture

The M4223 mounts to the R420 like all other accessory modules and from the R420's point of view looks like any other serial accessory device with a bi-directional and unidirectional serial port.  In the R420 the M4223 maps into SER3A and SER3B.  Configuration of SER3A is fixed as a network port so the M4223 can interact with the R420.  SER3B though can be configured like any other serial port in the R420.  For example it might be configured as a print port and take a custom print ticket from the R420.  Serial data on SER3A and SER3B is accessible to Lua applications through socket connections through the linux operating system and also through ports 2222 and 2223 on the Ethernet port.

This means that the Lua application on the M4223 interacts with the R420 in exactly the same way as any other external control program.  For example the View400 configuration utility for Windows uses the exactly same process to communicate with the R420 remotely.

Built into the M4223 is a local program that manages multiple connections to SER3A so multiple programs can have their own virtual channels to the R420.  In this way it is possible to have multiple Lua applications running on the M4223 as well as multiple remote connections to other computers with each connection kept independent

This also means that networking multiple R420 instruments using the M4223 is trivial as the interface from the Lua application to the local R420 is exactly the same as a connection to any remote R420.  Applications can be written therefore that maintain a central control process and database across multiple indicators without the complexity of connecting multiple scales and associated control interfaces all to the one indicator.

To make developing applications easy to do on the M4223 Rinstrum has developed a complete set of open source libraries written entirely in Lua referred to as the rinLIB framework.  In addition there are a number of application templates for common classes of applications and a myriad of worked examples
