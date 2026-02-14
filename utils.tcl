package provide httpLiteUtils 1.0
package require Tcl 8.6
namespace eval ::httpLiteUtils {
    namespace export setHeaders getHeaders body status 
    variable res_headers {}  
    variable httpLite_statuscode_message [dict create]
    variable tmp_statuscode {
	# Informational Messages
	100 {continue}
	101 {switching protocols}
	102 processing
	103 {early hints}
	# Successful Messages
	200 {OK}
	201 {created}
	202 {accepted}
	203 {non authorative information}
	204 {no content}
	205 {reset content}
	206 {partial content}
	207 {multi status}       ;#(WebDAV)
	208 {already reported}   ;#(WebDAV)
	226 {im used}            ;#(HTTP Delta encoding)
	# Redirection Messages
	300 {multiple choices}
	301 {moved permanently}
	302 {found}
	303 {see other}
	304 {not modified}
	305 {use proxy}
	307 {temporary redirect}
	308 {permanent redirect}
	# Client Error Responses
	400 {bad request}
	401 {unauthorized}
	402 {paymetn required}
	403 {forbidden}
	404 {not found}
	405 {method not allowed}
	406 {not acceptable}
	407 {proxy aunthentication required}
	408 {request timeout}
	409 {conflict}
	410 {gone}
	411 {length required}
	412 {precondition failed}
	413 {content too large}
	414 {uri too long}
	415 {unsupported media type}
	416 {range not satisfiable}
	417 {expectation failed}
	418 {im a teapot}
	421 {misdirect request}
	422 {unproccessable content} ;#(WebDAV)
	423 {locked}                 ;#(WebDAV) 
	424 {failed dependency}      ;#(wecDAV)
	425 {too early}
        426 {upgrade required}
	428 {precondition required}
	429 {too many requests}
	431 {request header fields too large}
	451 {unavailable for legal reasons}
	# Server Error Responses
	500 {internal server error}
	501 {not implemented}
	502 {bad gateway}
	503 {service unavailable}
	504 {gateway timeout}
	505 {http version not supported}
	506 {variant also negotiates}
	507 {insufficient storage} ;#(WebDAV)
	508 {loop detected}        ;#(WebDAV)
	510 {not extended}
	511 {newtwork authentication required}
    }
    # Stauscode with message built on initialization
    proc createStatusCodeandMessage {} {
	variable tmp_statuscode
	variable httpLite_statuscode_message
	foreach {k v} $tmp_statuscode  {
	    dict set httpLite_statuscode_message $k $v 
	}
    }
 # Response Utilities
 namespace eval ::res {
	namespace export status json setHeaders getHeaders end
    }
    createStatusCodeandMessage
}

# Send the Response back to the client
proc ::httpLiteUtils::end {{body ""} {format ""}} {
     upvar ::private::httpLite_channel channel
     variable res_headers
    puts "INSIDE HTTPLITEUTILS::END: PRIVATE-CHN:$channel \
RESPONSE->HEADERS: $res_headers"
    if {$body ne ""} {
	httpLiteSendResHeaders $channel $res_headers
	set transform_res_body [::httpLiteUtils::body $body $format]
        puts $channel ""
        puts $channel $transform_res_body
        flush $channel
    } else {
      httpLiteSendResHeaders $channel $res_headers
      puts $channel "" 
      flush $channel
    }
}

# User interface [res::setHeadaders] is
# use to configure the headers table 
proc ::httpLiteUtils::setHeaders {headers_dict} {
    variable res_headers
    # Set headers for the current response
    foreach {k v} $headers_dict {
	puts "Key:$k => Value:$v"
	if {[dict exists $res_headers $k]} {
	    puts "WARNING:KEY $k exist and will be overwriten"
	    # Give the user a way to arbot or continue
	    set res_headers [dict merge $res_headers [dict create $k $v]]
	}
	set res_headers [dict merge $res_headers [dict create $k $v]]
    }
    return $res_headers
}

# User interface [res::getHeaders]
# to retrieve default Response Headers 
# or users configured 
proc ::httpLiteUtils::getHeaders {} {
    variable res_headers
    # Return inernal headers with the one
    # that is set through <::utils::setResHeaders>
    return $res_headers
}

proc ::httpLiteSendResHeaders {channel res_headers} {
    # This need to be called internally after all headers
    # has been set
    #set res_headers ::httpLite::Utils::res_headers
    #upvar ::private::httpLite_channel channel
    if {[dict exists $res_headers res_line]} {
	 set res_line [dict get $res_headers res_line]
	 puts "SENDING RESPONSE: $res_line"
	 puts $channel $res_line
    } else {
	error "Please use the command \[httpLiteUtils::status \
<args statu_code> ?status_message \
to set the RESPONSE-LINE"
    }
    foreach {k v} $res_headers {
	if {$k eq "res_line"} continue
	puts "SENDING RESPONSE: {$k:$v}"
	puts $channel [format "%s: %s" $k $v]
    }
}


### User interface res message
# Overload to set the status code message or one shot
# to attached a message to a statuscode
#proc ::utils::message {}

# User interface res status
proc ::httpLiteUtils::status {status_code {message ""}} {
    variable httpLite_statuscode_message
    variable channel
    
    set status_message [expr {[dict exists $httpLite_statuscode_message $status_code] ? \
				  [dict get $httpLite_statuscode_message $status_code]:$message}]
    puts [httpLiteUtils::setHeaders [dict create res_line [format "HTTP/1.1 %s %s" $status_code $status_message]]]
}

# User interface res body
proc ::httpLiteUtils::body {res_body {transform "stringify"}} {
    set transform_res_body ""
    switch $transform {
	"json" {
	    return  [::httpLiteUtilsJson $res_body]
	}
	"binary" {
	    return [::httpLiteUtilsBinary $res_body]
	}
	default  {
	    return [::httpLiteUtilsStringify $res_body]
	}
	
    }
}

proc ::httpLiteUtilsStringify {json_obj} {
    #TODO: find a way to type the parameter<json_obj>
    # and do amazing transformation to the data before dispatching
    return $json_obj
}

proc ::httpLiteUtilsBinary {binary_obj} {
    #TODO: find a way to type the parameter<binary_obj>
    # and do amazing transformation to the data before dispatching
    return $binary_obj
}

proc ::httpLiteUtilsJson {json_str} {
    #TODO: find a way to type the parameter<json_str>
    # and do amazing transformation to the data before dispatching
   return $json_str
}


proc ::res::status {status_code {message ""}} {
    ::httpLiteUtils::status $status_code $message
}


proc ::res::end {res_body {body_format ""}} {
    ::httpLiteUtils::end $res_body $body_format
    return 0
}

proc ::res::json  {json_str} {
	return httpLiteUtilsJson  $json_str
       
}

proc ::res::setHeaders {dict_header} {
    return [::httpLiteUtils::setHeaders $dict_header]
}

proc ::res::getHeaders {{h_key ""}} {
	
    return [::httpLiteUtils::getHeaders $h_key]
}

proc ::res::stringify {json_obj} {
    return [::httpLiteUtilsStringify $json_obj]
}

proc ::res::binary {binary_obj} {
    return [::httpLiteUtilsBinary $binary_obj]
    
}

