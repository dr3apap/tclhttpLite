#!/usr/bin/env tclsh
lappend auto_path [file dirname [info script]]
package require devServer 1.0 
set PORT 22000
namespace eval ::devServer {
    namespace ensemble create
}
proc devServerInit {} {
    global PORT
    puts "DevServer running on $PORT!!"
}

devServer devStart
