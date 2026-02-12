
# Tcl httpLite: 

A Tcl package/project that simplify low level `socket` interface

## Functionaliy:

It provide functionality for spinning a web server, Api or any server conform to  
one of the socket protocols and families. 
- Uses callback for handling routes **request targets**
   - callback receive two TCL namespaces/objects with commands and variables that hold parsed
   - request data like \[method protocol query_param headers ...\]
- Response: Commands for manipulating responses data like \[setHeaders getHeaders response status ...\]
- Router: Router namespace/object with commands like [get post patch delete headers]
- Load balancer for managing multiple request \(WIP: not implemented yet\)
- Middleware: List of routines/functions that introspect with the request and response objects
- Asynchronously handling of request and response without blocking thread of execution
- Easily configure and serves as a library not as framework \(Just a set of commands and variables absractions\)

## SIMILARITY: 

Similar to NodesJs Express in fact it is modeled after NodeJs Express. 
