package provide httpLiteRouter 1.0 
package require Tcl 8.6
namespace eval ::httpLiteRouter {
    namespace export get post patch delete headers
    variable httpLiteRouter_obj {};# Router object that hold req_target<keys> and target handler<values=cb>
    variable OK 0       ;# confform to TcL exit SUCCESS 
    variable ERROR 1    ;# conform to TCL  exit Error
    variable HLERROR 2  ;# hppLite define Error
}


# Check if we have a [get,post,patch,delete,headers] route object already
# check if the path exists in the route object
# if not add the path and the handler
# if yes update the handler and warn the user of overwriting
# provide a graceful way to continue or abort updating

proc ::httpLiteRouter::get {req_tgt ReqHandler} {
    variable httpLiteRouter_obj
    variable OK
    variable ERROR
    variable HLERROR
    if {[dict exists $httpLiteRouter_obj get]} {
	set get_route [dict get $httpLiteRouter_obj get] 
	if {[dict exists $get_route $req_tgt]} {
	    # Send a warning message for overwriting the key
	    puts "WARNING:Key $req_tgt exist and will be overtide!!"
	    dict set [dict get $httpLiteRouter_obj get] $req_tgt $ReqHandler
	    return OK
	}
	dict set httpLiteRouter_obj get \
	    [dict set get_route $req_tgt $ReqHandler]
	return OK
    }
    dict set  httpLiteRouter_obj get \
		  [dict set {} $req_tgt $ReqHandler]
    return OK
}


proc ::httpLiteRouter::post {req_tgt ReqHandler} {
    variable httpLiteRouter_obj
    variable OK
    variable ERROR
    variable HLERROR
    if {[dict exists httPLite_router_obj get]} {
	set get_route [dict get httpLite_router_obj get] 
	if{[dict exists $get_route $req_tgt]} {
	    # Send a warning message for overwriting the key
	    puts "WARNING:Key $req_tgt exist and will be overtide!!"
	    dict set get_route $req_tgt reqHandler
	    return OK
	}
	dict set get_route $req_tgt reqHandler
	return OK
    }
    dict set [dict set httpLiteRouter_obj get \
		  [dict set $req_tgt $reqHandler]]
    return OK
}

proc ::httpLiteRouter::patch {req_tgt reqHandler} {
    variable httpLiteRouter_obj
    if {[dict exists router_obj $req_tgt] } {
	# Send a warning message for overwriting the key
	puts "WARNING:Key $req_tgt exist and will be overwritten!!"
	dict set router_obj $req_tgt reqHandler
    }
    dict set router_obj $req_tgt reqHandler
}

proc ::httpLiteRouter::delete {req_tgt reqHandler} {
        variable router_obj
    if {[dict exists router_obj $req_tgt] } {
	# Send a warning message for overwriting the key
	puts "WARNING:Key $req_tgt exist and will be overtide!!"
	dict set router_obj $req_tgt reqHandler
    }
    dict set router_obj $req_tgt reqHandler
}

proc ::httpLiteRouter::headers {req_tgt reqHandler} {
        variable router_obj
    if {[dict exists router_obj $req_tgt] } {
	# Send a warning message for overwriting the key
	puts "WARNING:Key $req_tgt exist and will be overtide!!"
	dict set router_obj $req_tgt reqHandler
    }
    dict set router_obj $req_tgt reqHandler
}
