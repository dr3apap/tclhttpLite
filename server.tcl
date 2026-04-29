#!/usr/bin/env tclsh

# Expose as package
package provide httpLite 1.0                   ;#(Main Package)
lappend auto_path [file dirname [info script]] ;#(Add to TCL PATH ENV)
#package require Tcl 8.6                        ;#(Requirement)
package require httpLiteRouter 1.0             ;#(ROuter Version)
package require httpLiteUtils 1.0
package require dr3Utils 1.0
#puts "[info body ::httpLiteUtils::input]"
# Interface to the Application
namespace eval ::httpLite {
    namespace export listen use get post patch delete wsStart wsDone
    # Hooks into the internal Routing routines and states
    # TODO: A routine that return the Router namespace
    namespace eval ::httpLiteRouter {
	namespace ensemble create
	namespace export get post patch delete headers 
    }
}

# General LIBRARY
namespace eval ::dr3Utils {
    namespace ensemble create
}

# HTTPLITE: Internal Low Level Routines and States
namespace eval ::private {
    package require httpLiteUtils 1.0  ;# Version
    variable on_done 0
    variable default_server ""         ;# maybe Workers List?
    variable httpLite_midw {}          ;# Middleware
    variable httpLite_midw_len 0
    variable err_midw ""               ;# Error Middleware Index
    variable next_midw 0               ;# Middleware index "CLOSURE"
    variable req_obj {}                ;# Shared Request object
    variable EOT 0                     ;# End of transmission (SIGNAL PER wORKER?)
    variable blocked 0                 ;# CLOSED CONNECTION
    variable connected 0               ;# (SIGNAL PER WORKER)
    variable httpLite_channel ""       ;# (CHANNEL PER CONNECTION)
    # Utilities for manipulating Response
    namespace eval ::httpLiteUtils {
	namespace ensemble create
	namespace export setHeaders getHeaders body status httpLiteNotify dupKeys
    }
    
}

# Callback for onRequest (This get called when the network card receive data)
# Channel is the IO for buffering request data
proc ::private::server {channel addr port} {
    variable httpLite_channel
    if {$channel ne ""} {
	#puts "Request arrived on port:$port"
	set httpLite_channel $channel
    }
    after 120 update; # This kicks Windows machines for this
    # Set this channel to be non-blocking.
    chan configure $channel -blocking 0 -translation auto  -encoding utf-8 -buffersize 1000000
    #puts "After fconfigure the state for blocking is:[chan configure $channel -blocking]"
    # When input is available, read it.
    fileevent $channel readable "::private::readLine $channel"
    
}


# Generalize server by calling the inernal server 
# Call the internal Server with the server Routine
proc ::private::createServer {port type} {
    #TODO: Generate AES to wrap transactions [::tls::socket -options ]
    switch $type {
	https {
	    return [socket -server ::private::server  $port]
	}
	
	http - 
	default  {
	    return [socket -server ::private::server $port]
	}
    }
}

# Main interface to the server
proc ::httpLite::listen {port server_init {type ""}} {
    set server_channel [::private::createServer $port $type]
    catch {server_channel} msg
    if {$server_channel ne ""} {
	#puts "Server: $server_channel"
	#puts "Server Initiated!!"
	$server_init
    }  else {
	puts "ERROR: $msg"
    }
        vwait forever
    # TODO: Load balancer <Software load manager <(Hardware with fast timing)>>
}

# Routine for adding hooks/callback for server internal states
proc ::httpLite::use {cb} {
    set err_midw_match [regexp {^(error)+.*?} $cb] 
    if {$err_midw_match != 0} {
	if {$::private::err_midw eq ""} {
	    # Use array instead of list set ::private::httpLite_midw(error) $cb? 
	    lappend ::private::httpLite_midw $cb 
	    set ::private::err_midw $::private::httpLite_midw_len ;# Set the Error midware index
	    incr ::private::httpLite_midw_len
	} else {
	    # There can only be one error middware
	    # Gracefully allow user to confirm updating
	    # an error middleware or to abort  
	    ::httpLiteUtils::dupKeys "An Error middleware exist: (u/update? or a/abort?): " "w" 
	}
    } else {
	lappend ::private::httpLite_midw $cb
	incr ::private::httpLite_midw_len
    }
}


# Request Method Routines
proc ::httpLite::get {path cb} {
    httpLiteRouter get $path $cb
}

proc ::httpLite::post {path cb} {
    httpLiteRouter post $path $cb
}

proc ::httpLite::patch {path cb} {
    httpLiteRouter patch $path $cb
}

proc ::httpLite::delete {path cb} {
    httpLiteRouter delete $path $cb
}

proc ::httpLite::headers {path cb} {
    httpLiteRouter headers $path $cb
}

proc ::httpLite::wsDone {} {
    return $::private::on_done
}

# Compute Request Line
proc ::private::parseReqLine {req_line_str} {
    try {
	set req_param {}
	#puts [format "REQ-LINE:=> %s\n" $req_line_str]
	regexp -nocase -all {(?x) (\w+)\s+(?:([^-\d_]\w+)\:[/]{2}(?:[w]{3}/.)?\w+(?:\.\w+)*?)?(/(?:(?:(?:\w|\d|[-])*/?)*(?:\.\w+)*?)*)(?:\?(.+))?\s+(\W?\w+\W\d+\W\d+)(?:\\r|\\n)?} $req_line_str matched_url req_method req_scheme req_target req_param_raw proto
	#puts "MATCHED+REQ+LINE: $matched_url\nTARGET:$req_target\nREQ+PARAM:$req_param_raw\nPROTO:$proto"
	if {[string length $req_param_raw] > 0} {
	    set req_param [private::buildReqParamObj $req_param_raw]
	}
	return [dict create url $matched_url req_method [string tolower $req_method] req_scheme $req_scheme req_target $req_target req_param $req_param proto $proto]
    } on error {result options} {
	puts "<PARAM: req_line_str> can't be empty|NULL" 
	puts stderr "ERROR: [dict get $options -errorinfo]" 
	return {}
    } 
}

# Compute Request Headers
proc ::private::parseHeaderLines {header_str} {
    try {
	#puts [format "Current HEADER-LINE:=> HS:%s\n" $header_str]
	regexp -nocase {(?x) ^(\w+(?:\-?\w+)+?)\:(\s+.+)(?:\\r|\\n)?$} $header_str matched_header header_key header_val
	#puts [format "Current HEADER-LINE:=> %s\n KEY:{%s}:VAL:{%s}" $matched_header $header_key $header_val] 
	#puts [format "Current HEADER-LINE:=> %s\n" $matched_header] 
	return [dict create [string tolower $header_key] $header_val]
    } on error {result options} {
	puts "<PARAM:header_str> is empty|NULL -> end of header" 
	puts stderr "ERROR: [dict get $options -errorinfo]"
	return {}
    }
}

# Compute Host header
proc ::private::parseHostLine {host_header} {
    #puts [format "HOST+LINE:=> %s\n" $host_header]
    regexp -nocase {(?x) ((?:\w+\-?)+\:\s*?(?:[^\d_](?:\w{1,4}?\:\W{2}))?(?:\w{3}\.)?(?:\w+\.??\w+))(\:\d+)?(?:\\r|\\n)?} $host_header matched_host host port 
    return [dict create host_header [dict create req_host $matched_host host $host port $port]]
}

# Compute Request body
proc ::private::parseBodyLines {body_str} {
    regexp -nocase {(?x)(.*)(?:\\r\\n)?} $body_str body
    return [dict create req_body body $body]
}

proc ::private::readLine {channel} {
    lassign [::private::buildReqObj $channel] buff req_obj
    if {$buff eq "" || $req_obj eq ""} {
	return
    }
    set method [dr3Utils getDictVal $req_obj req_method]
    set path [dr3Utils getDictVal $req_obj req_target]
    regsub -all {(?x) ^/|/$} $path {} trimmed_path
    set routes  [dict get $::httpLiteRouter::httpLiteRouter_obj $method]
    set targetHandler [expr {[dict exists $routes $trimmed_path] ? [dict get $routes $trimmed_path ] : "::private::defaultNotFound"}]
    set targetHandler [expr {[string first "public/" $trimmed_path] >= 0 ? [dict get $routes "public"] : $targetHandler}]
    regsub -all  {\s} $buff {} temp_buff
    set res_obj "::httpLiteUtils::res"
    $targetHandler [dict set req_obj req_target $trimmed_path]  $res_obj "::private::next"
}

# Compute request objects
proc ::private::buildReqObj {channel} {
    variable on_done
    set ln_num 0 
    set body_begin 0
    set buff "" 
    set req_obj {}
    while {[set len [gets $channel line]] >= 0 } {
	if {$len > 0} {
	    incr ln_num
	} elseif {$len == 0 && $ln_num == 1} {
	    continue  
	} elseif {$len == 0 && $ln_num ==  2} {
	    continue
	}  elseif {$len  == 0 && $ln_num > 2 }   {
	    set body_begin 1
	    continue
	} 
	if {$ln_num == 1} {
	    set req_obj [dict merge $req_obj [::private::parseReqLine $line]]
	} elseif {$ln_num == 2} {
	    set req_obj [dict merge $req_obj [::private::parseHostLine $line]]
	} elseif {($ln_num > 2) && (!$body_begin)} {
	    #puts "HEADER+LINE: $line"
	    set req_obj [private::buildReqHeader $req_obj [::private::parseHeaderLines $line]]
	}  else {
	    set req_obj [dict merge $req_obj [::private::parseBodyLines $line]]
	}   
	append buff $line "\n" 
	set len [string length $buff]
    }
    if {$len < 0} {
	set on_done 1
	after idle "close $channel"
    }
    return [list $buff $req_obj]
}	

# Default not found route Routine
proc ::private::defaultNotFound {req res {next ""} } {
    proc mapkv {k v} {
	return  [dict create $k $v]
    }
    if {[set path [dict get $req req_target]]  eq "/favicon.ico"} {
	if {[set icon_path [glob -nocomplain -types f *favicon{.png,jpeg,ico}*]] ne {}} {
	    set icon [read [open $icon_path r]]
	    res::setHeaders [dr3Utils::mapKeyVal mapkv {"content-type" "content-length"} [list "image/x-icon"  [string length $icon]]]
	    res::status 200
	    res::end $icon
	    return 0
	    
	} else {
	    res::setHeaders [dr3Utils::mapKeyVal mapkv {"content-type" "content-length"} [list "image/x-icon" 0]]
	    res::status 204
	    res::end ""
	    return 0
	}
    }
    set message "<h3>Bad Request!!</h3>"
    set len [string length $message]
    res::setHeaders [dr3Utils::mapKeyVal mapkv {"content-type" "content-length"} [list "text/html" [string length $message]]]
    res::status 400
    res::end $message
    return 0
}

# Iterator routine for next hooks/callback
proc ::private::next { {err ""}} {
    upvar req req
    upvar res res
    ::httpLiteUtils::notify "INSIDE-NEXT: REQ:->$req RES:->$res"
    if {$err ne ""} {
	if {$private::err_midw ne ""} {
	    set err_cb [lindex $::private::httpLite_midw $::private::err_midw]
	    $err_cb $err $req $res
	    return "<MIDDLEWARE $err_cb $::private::err_midw>"
	}  else {
	    ::httpLiteUtils::notify "<No registered \"ERROR MIDDLEWARE\">" "error" 
	}
    } else {
	if {($::private::next_midw == $::private::err_midw) && ([expr {[incr ::private::next_midw] < $::private::httpLite_midw_len}]) } {
	    set midw_cb [lindex $::private::httpLite_midw $::private::next_midw]
	    $midw_cb $req $res
	    incr ::private::next_midw 
	    return "<MIDDLEWARE $midw_cb $::private::next_midw>"
	} elseif {[expr { $::private::next_midw >= $::private::httpLite_midw_len }]} {
	    ::httpLiteUtils::notify "Middleware out of Bound!!" "error"
	    return "<MIDDLEWARE NULL $::private::httpLite_midw_len>"
	} else {
	    set midw_cb [lindex $::private::httpLite_midw $::private::next_midw]
	    $midw_cb $req $res
	    incr ::private::next_midw 
	    return "<MIDDLEWARE $midw_cb $::private::next_midw>"
	}
    }
    
}

# compute Req-Header
proc ::private::buildReqHeader {req_obj header_dict} {
    if {[dict exists $req_obj header]} {
	set t [dict merge $req_obj [dict create header [dict merge [dict get $req_obj header] $header_dict ]]]
	return $t
    } else {
	return [dict merge $req_obj [dict create header $header_dict]]
    }
    
}
