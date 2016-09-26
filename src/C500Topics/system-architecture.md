# System Architecture


Lua on the C500 runs on the same microcontroller as the C500 firmware. 
It connects to the C500 firmware through a socket connection on ports 2222 and 2223.
This means that the Lua application on the M4223 interacts with the R420 in exactly the same way as any other external control program.  
For example the View500 configuration utility for Windows uses the exactly same process to communicate with the C500 remotely.

The C500 2222 port is capable of accepting multiple simultaneous connections from different programs.
In this way it is possible to have multiple Lua applications running on the C500 as well as multiple remote connections to other computers with each connection kept independent

This also means that networking multiple C500 instruments using Lua is trivial as the interface from the Lua application to the local C500 is exactly the same as a connection to any remote R420.  
Applications can be written therefore that maintain a central control process and database across multiple indicators without the complexity of connecting multiple scales and associated control interfaces all to the one indicator.

To make developing applications easy to do on the C500 Rinstrum has developed a complete set of open source libraries written entirely in Lua referred to as the rinLIB framework.  
In addition there are a number of application templates for common classes of applications and a myriad of worked examples
