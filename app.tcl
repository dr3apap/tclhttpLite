#!/usr/bin/env tcls


# A small Application that test the fucntionality of the <httpLite version 1.0 package>           
# Additinal packages <httpLiteRouter version 1.0, httpLiteUtils provided as REQUEST and RESPONSE OBJ>
# Tested functionality:
    # Create a http Server
    # Passed a Callback for server initialization [httpLite listen Args<port> Handler<Cb>]
    # Add a route and route handler via [httpLiteRouter version 1.0 package]
    # Route handler use utilities provided for manipulating REQUEST and RESPONSE PACKETS
    # REQUEST:
           # parsed request packet into request objects:
           # <REQUEST-LINE: req_method: (GET POST PATCH DELETE HEADERS)
           # req_target: (resources path)
           # protocol:   (HTTp/1.1/ HTPP/2 HTTP/3)>
           # <REQUEST-HEADERS-LINE: request_headers: (List/dict of headers keys and valueser request)
           # body: (data jackson,text/html/binary/media/images ... )
   # RESPONSE:
          # Provide routines for:
          # setHeaders
          # getHeaders
          # response status and message
          # response body transformation
          # end response


lappend auto_path [file dirname [info script]]
package require httpLite 1.0
#package require httpLiteRouter 1.0
package require Tcl 8.6

namespace eval ::httpLite {
    namespace ensemble create
}

set PORT 33000       ;# Testing/Development port
set favi_path ""     ;# Used to test /favicon.ico.
proc handleRoot {} {
    global PORT
    puts "Server running on $PORT!!"
}

proc sayHi {req res {next}} {
     set data "<h1>Receive Acknowledgement</h1>"
    if {[dict get $req req_target ] eq "/greeting"} {
	$next
        res::setHeaders [dict create Content-Type text/html Content-Length [string length $data]]
	res::status 200
	res::end $data  
    } else {
	res::status 401
    }
}

proc errorMidw {err req res} {
    res::status 500
    res::end "<h3>Pls try again, Something went wrong</h3>"
}

proc upperRes {req res} {
    #puts "Testing midWare:  [string toupper [dict get $req req_target]]"
    puts "HEY!!!!"
}

proc favRes {req res {next}} {
    global favi_path
    set favi_chan [open $favi_path r]
    set buff "" 
    if {[dict get $req req_target] eq "/favicon.ico"} {
        while {[gets $favi_chan line] > 0} {
	    append buff $line 
	}
	$next
	res::setHeaders [dict create Content-Type image/png Content-Length [string length $buff] Connection close]
        res::status 200
        res::end $buff 
    } else {
	$next "Error"
    }
}

httpLite use upperRes
httpLite use errorMidw 
httpLite use errorTest
httpLiteRouter get "/greeting" sayHi
httpLiteRouter get "/favicon.ico" favRes
httpLite listen $PORT handleRoot
