# Expose as package
package provide httpLite 1.0                   ;#(Main Package)
package require Tcl 8.6                        ;#(Requirement)
lappend auto_path [file dirname [info script]] ;#(Add to TCL PATH ENV)
package require httpLiteRouter 1.0             ;#(ROuter Version)
# Interface to the Application
namespace eval ::httpLite {
    namespace export listen use get post patch delete
    # Hooks into the internal Routing Routines and States
    namespace eval ::httpLiteRouter {
	namespace ensemble create
	namespace export get post patch delete headers 
    }
    
}

# Internal Low Level Routines and States
namespace eval ::private {
    package require httpLiteUtils 1.0  ;# Version
    variable default_server ""         ;# maybe Workers List?
    variable httpLite_midw {}          ;# Middleware
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
	namespace export setHeaders getHeaders body status
    }
}


proc ::private::server {channel addr port} {
    variable httpLite_channel
    if {$channel ne ""} {
	puts "Server ready on port:$port"
	set httpLite_channel $channel
    }
    set buffer ""
    after 120 update; # This kicks Windows machines for this
    puts "channel : $channel - from Address: $addr Port: $port"
    puts "The default state for blocking is: \
	[chan configure $channel -blocking]"
    puts "The default buffer size is : \
	[fconfigure $channel -buffersize]"
    # Set this channel to be non-blocking.
    set smo [chan configure $channel -blocking 0 -translation auto  -encoding utf-8 -buffersize 1026]
    puts "After fconfigure the state for blocking is:[chan configure $channel -blocking]"
    # Change the buffer size to be smaller
    chan configure $channel -buffersize 2052
    puts "After fconfigure buffer size is: \
	[chan configure $channel -buffersize]\n"
    # When input is available, read it.
    fileevent $channel readable "::private::readLine server $channel buffer"
    
}


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

proc ::httpLite::listen {port server_init {type ""}} {
    set server_channel [::private::createServer $port $type]
    catch {server_channel} msg
    if {$server_channel ne ""} {
	puts "Server: $server_channel"
	puts "Server Initiated!!"
	$server_init
    }  else {
	puts "ERROR: $msg"
    }
    vwait forever
    # TODO: Load balancer <Software load manager<(Hardware with fast timing)>
}


proc ::httpLite::use {cb} {
    set err_midw_match [regexp {^(error)+.*?} $cb] 
    if {$err_midw_match != 0} {
	# Use array instead of list set ::private::httpLite_midw(error) $cb? 
	lappend ::private::httpLite_midw $cb 
	set ::private::err_midw [lsearch $::private::httpLite_midw $cb]
    } else {
	lappend ::private::httpLite_midw $cb
    }
}


proc ::private::next {err} {
    if {err ne ""} {
	if {::private::ERR_MIDW ne ""} {
	    [namespace current][lindex ::private::irmw $::private::ERR_MIDW] $err
	} else {
	    # Handle Error of not finding Error middleware
	}
    } 
    lindex ::private::irmw $::private::next_midw_index
    incr ::private::next_midw_index
}

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


proc ::private::parseReqLine {req_line_str} {
    #puts [format "Current REQ-LINE:=> %s\n" $req_line_str]
    regexp -nocase -all {(?x)(\w+)\s+([^\d_]\w+\:\W{2})?(?:(\W+(?:(?:\w+)?\W?)?)*?)\s+(\W?\w+\W\d+\W\d+)(?:\\r|\\n)?} $req_line_str matched_url req_method req_scheme req_target proto
    return [dict create url $matched_url req_method [string tolower $req_method] req_scheme $req_scheme req_target $req_target proto $proto]
}

proc ::private::parseHeaderLines {header_str} {
    puts [format "Current HEADER-LINE:=> %s\n" $header_str]
    regexp -nocase {(?x)((?:\w+(?:\-+)?)+?(?:\s)*?)\:(.+)(?:\\r|\\n)?} $header_str matched_header header_key header_val
    return [dict create header [dict create header_str $matched_header $header_key $header_val]]
}

proc ::private::parseHostLine {host_header} {
    puts [format "HOsT-LINE:=> %s\n" $host_header]
    regexp -nocase {(?x)((?:\w+\-?)+\:\s*?(?:[^\d_](?:\w{1,4}?\:\W{2}))?(?:\w{3}\.)?(?:\w+\.??\w+))(\:\d+)?(?:\\r|\\n)?} $host_header matched_host host port 
    return [dict create host_header [dict create req_host $matched_host host $host port $port]]
}

proc ::private::parseBodyLines {body_str} {
    regexp -nocase {(?x)(.*)(?:\\r\\n)?} $body_str body
    return [dict create req_body body $body]
    
}

proc ::private::readLine {who channel buffer } {
    upvar $buffer buff
    set req_obj {}
    set res_obj {}
    set ln_num 0 
    set body_begin 0
    set method ""
    while {[set len [gets $channel line]] >= 0 } {
	if {$len > 0} {
	    incr ln_num
	} elseif {$len == 0 && $ln_num == 1} {
	    continue  
	} elseif {$len == 0 && $ln_num > 1} {
	    set body_begin 1
	    continue
	}
	
	if {$ln_num == 1} {
	    set req_obj [dict merge $req_obj [::private::parseReqLine $line]]
	    set method [dict get $req_obj req_method] 
	    set path [dict get $req_obj req_target]
	} elseif {$ln_num == 2} {
	    set req_obj [dict merge $req_obj [::private::parseHostLine $line]]
	} else {
	    set req_obj [dict merge $req_obj [::private::parseHeaderLines $line]]
	}    
	
	if {$body_begin} {
	    set req_obj [dict merge $req_obj [::private::parseBodyLines $line]]
	}
	append buff $line "\n" 
	set len [string length $buff]
    }	
    
    proc defaultNotFound {req res } {
	res::end "<h2>$path NOt Found!!</h2>"
    }
    set curr_route  [dict get $::httpLiteRouter::httpLiteRouter_obj $method]
    set targetHandler [expr {[dict exists $curr_route $path] ? [dict get $curr_route $path ] : $defaultNotFound }]
    regsub -all  {\s} $buff {} temp_buff
    #puts "$temp_buff"
    #puts "EOT is now: $::httpLite::EOT"
    set res_obj "::httpLiteUtils::res"
    $targetHandler $req_obj $res_obj
}

