lappend auto_path [file dirname [info script]] 
package require httpLiteUtils 1.0
package require Tcl 8.6
package provide httpLiteRouter 1.0 
namespace eval ::httpLiteRouter {
    namespace export get post patch delete headers
    namespace import ::httpLiteUtils::input
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

proc ::httpLiteRouter::dupKeys {msg type method route_obj}  {
    variable httpLiteRouter_obj 
    upvar reqHandler reqHandler
    upvar req_tgt req_tgt
    puts "R->OBJECT:$route_obj"
    puts "Handler:$reqHandler Target:$req_tgt Router:$httpLiteRouter_obj"
    # get the user input<ADVISE>
    set advise [string tolower [::httpLiteUtils::input $msg $type -n "u|update" "|" "a|abort"]]
    if {$advise eq "u" || $advise eq "update"} {
	dict set httpLiteRouter_obj $method [dict set $route_obj $req_tgt $reqHandler]
	puts "ROUTER: $httpLiteRouter_obj"
    } elseif {$advise eq "a" || $advise eq "abort"} {
	puts "Aborting!!"
    }    
} 

proc ::httpLiteRouter::get {req_tgt reqHandler} {
    variable httpLiteRouter_obj
    variable OK
    if {[dict exists $httpLiteRouter_obj get]} {
	set get_route [dict get $httpLiteRouter_obj get] 
	if {[dict exists $get_route $req_tgt]} {
	    # Send a warning message for overwriting the key
	   ::httpLiteRouter::dupKeys "Route -> $req_tgt exist (u/update? or a/abort?): " "w" get $get_route 
	    return OK
	}
	dict set httpLiteRouter_obj get [dict set get_route $req_tgt $reqHandler]
	return OK
    }
    dict set  httpLiteRouter_obj get [dict set {} $req_tgt $reqHandler]
    return OK
}


proc ::httpLiteRouter::post {req_tgt reqHandler} {
    variable httpLiteRouter_obj
    variable OK
    if {[dict exists $httpLiteRouter_obj post]} {
	set post_route [dict get $httpLiteRouter_obj post] 
	if {[dict exists $post_route $req_tgt]} {
	    # Send a warning message for overwriting the key
	   ::httpLiteRouter::dupKeys "Route -> $req_tgt exist (u/update? or a/abort?): " "w" post $post_route
	    return OK
	}
	dict set httpLiteRouter_obj post [dict set post_route $req_tgt $reqHandler]
	return OK
    }
    dict set httpLiteRouter_obj post [dict set {} $req_tgt $reqHandler]
    return OK
}

proc ::httpLiteRouter::patch {req_tgt reqHandler} {
    variable httpLiteRouter_obj
    variable OK
    if {[dict exists $httpLiteRouter_obj patch]} {
	set patch_route [dict get $httpLiteRouter_obj patch] 
	if {[dict exists $patch_route $req_tgt]} {
	    # Send a warning message for overwriting the key
	    ::httpLiteRouter::dupKeys "Route -> $req_tgt exist (u/update? or a/abort?): " "w" patch $patch_route
	    return OK
	}
	dict set httpLiteRouter_obj patch [dict set patch_route $req_tgt $reqHandler]
	return OK
    }
    dict set httpLiteRouter_obj patch [dict set {} $req_tgt $reqHandler]
    return OK
}

proc ::httpLiteRouter::delete {req_tgt reqHandler} {
    variable httpLiteRouter_obj
    variable OK
    if {[dict exists $httpLiteRouter_obj delete]} {
	set delete_route [dict get $httpLiteRouter_obj delete] 
	if {[dict exists $delete_route $req_tgt]} {
	    # Send a warning message for overwriting the key
	    ::httpLiteRouter::dupKeys "ROUTE $req_tgt exist (u/update? or a/abort?): " "w" delete $delete_route
	    return OK
	}
	dict set httpLiteRouter_obj delete [dict set delete_route $req_tgt $reqHandler]
	return OK
    }
    dict set httpLiteRouter_obj delete [dict set {} $req_tgt $reqHandler]
    return OK
}

proc ::httpLiteRouter::headers {req_tgt reqHandler} {
    variable httpLiteRouter_obj
    variable OK
    if {[dict exists $httpLiteRouter_obj headers]} {
	set headers_route [dict get $httpLiteRouter_obj headers] 
	if {[dict exists $headers_route $req_tgt]} {
	    # Send a warning message for overwriting the key
	    ::httpLiteRouter::dupKeys "ROUTE $req_tgt exist (u/update? or a/abort?): " "w"  headers $headers_route
	    return OK
	}
	dict set httpLiteRouter_obj headers [dict set headers_route $req_tgt $reqHandler]
	return OK
    }
    dict set  httpLiteRouter_obj headers [dict set {} $req_tgt $reqHandler]
    return OK
}

# TestS: route/hadlers, duplicates and router object
# ---------------------------------------------------
#puts [::httpLiteRouter::get "/get" handleGet]
#puts [::httpLiteRouter::get "/get" getHandler]
#puts [::httpLiteRouter::post "/post" handlePost]
#puts [::httpLiteRouter::post "/post" postHandler]
#puts [::httpLiteRouter::headers "/headers" handleHeaders]
#puts [::httpLiteRouter::headers "/headers" headersHandler]
#puts [::httpLiteRouter::delete "/delete" handleDelete]
#puts [::httpLiteRouter::delete "/delete" deleteHandler]
#puts [::httpLiteRouter::patch "/patch" handlePatch]
#puts [::httpLiteRouter::patch "/patch" patchHandler]
#puts $::httpLiteRouter::httpLiteRouter_obj
