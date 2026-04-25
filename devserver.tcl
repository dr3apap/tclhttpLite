#! /usr/bin/env tclsh
package provide devServer 1.0
lappend auto_path [file dirname [info script]]
# Requirement
package require httpLite 1.0 
package require dr3Utils 1.0
package require Tcl 8.6

namespace eval ::devServer {
    variable files_to_watch {}
    variable monitor_files {}
    variable base_dir {}
    variable PORT 33000
    namespace eval ::httpLite {
	namespace ensemble create
    }
    namespace eval ::dr3Utils {
	namespace ensemble create
    }
    namespace eval ::devServer::helpers {}
    namespace export devStart onModify devServerUse
}

proc devServer::defaultCb {} {
    }

# Main interface: Start Development server with default 
# Statics path/routes  and routes handlers 
proc devServer::devStart {{port ""} {cb ""} {base_dir ""}} {
    global devServer::PORT
    set port [expr {$port ne "" ? $port : $::devServer::PORT}]
    set ::devServer::base_dir [expr {$::devServer::base_dir ne "" ? $::devServer::base_dir : $base_dir}]
    httpLiteRouter get "" devServer::_handleReq
    httpLiteRouter get "public" devServer::_handleReq
    httpLiteRouter get "favicon.ico" devServer::_handleReq
    devServer::helpers::watch puts
    if {$cb ne ""} {
	httpLite listen $port $cb
	return 0
    }
    
     httpLite listen $port devServer::defaultCb
    return 0
}		   

# Default internal request handler
proc devServer::_handleReq {req res {next}} {
    variable files_to_watch
    if {[dr3Utils getDictVal $req req_method] ne "get"} {
	    return [devServer::_notFound $res]
    }
    set path [dr3Utils getDictVal $req req_target]
    if { $path eq ""} {
	return [devServer::helpers::getLandingPage $res]
    } elseif { $path eq "favicon.ico" } {
	return [devServer::_handleFav $res]
    } else {
	return [devServer::_createResponse $res $path]
    }
}
# Compute response objects
proc devServer::_createResponse {res path} {
    variable files_to_watch
    set mime_type ""
   regexp -nocase -all {(?x) ^/?(\w+(?:/\w+)*)/((?:\w|\W|\d)+?).(\w+)$} $path matched_path dir asset_name asset_type
    regsub -all {(?x) ^/?public/.*} $dir "public" matched
    if {$matched eq "public"} {
	set full_path [file join [pwd] $path]
	if {[file exists $full_path]} {
	    devServer::helpers::getFilesToWatch $full_path $asset_type
	    switch $asset_type {
		ico {
		    return [devServer::_handleFav $res]
		}
		apng -
		png -
		jpg -
		jpeg -
		jfif -
		pjpeg -
		pjp -
		svg -
		webp -
		bmp -
		cur -
		tif -
		tiff - 
		gif -
		png {
		    set mime_type [list [format "image/%s" $asset_type] "binary" $asset_type]
		}
		mp3 -
		m4a -
		wav -
		oggf -
		oga -
		opus -
		webm -
		flac -
		aif -
		aiff -
		mp4 {
		    set mime_type [list [format "audio/%s" $asset_type] "binary" $asset_type]
		}
		css -
		txt -
		md -
		mu -
		org -
		html {
		    set mime_type [list [format "text/%s" $asset_type] "text" $asset_type]
		}
		js {
		    set mime_type [list "application/javascript" "text" $asset_type]
		}
		default {
		    set mime_type {"text/plain" "plain"}
		}
	    }
	    puts "MIME_TYPE: $mime_type"
	    set size [file size $path]
	    return [devServer::_sendResponse $res $path $mime_type]
	} else {
	    return [devServer::_notFound $res]
	}
    } else {
	return [devServer::_notFound $res]
    }
}

# pass to the internal/low-level assets/resources handler
# Retrieving data from "DATABASE/FILES"
proc devServer::_getContent {len data acc} {
    append acc $data
    return $acc
}

# Send Response to client
proc devServer::_sendResponse {res fh content_type {size ""} } {
    lassign $content_type mime_type fmt stem
    set size [file size $fh] 
    set contents  [dr3Utils readLines $fh devServer::_getContent {} $fmt $size] 
    set keys {"content-type" "content-length"} 
    proc mapkv {k v} {
	return  [dict create $k $v]
    }
    res::setHeaders [dr3Utils mapKeyVal mapkv $keys [list $mime_type [string length $contents]]] 
    
    res::status 200
    res::end $contents [expr {$fmt eq "binary" ? $fmt : {}}]
    return 0
}
# Default path not found handler
proc devServer::_notFound {res} {
    set message "<h3>Not Found!!</h3>" 
    proc mapkv {k v} {
	return  [dict create $k $v]
    }
    res::setHeaders [dr3Utils mapKeyVal mapkv {"content-type" "connection" "content-length"} [list "text/html" "close" [string length $message]]]
    res::status 400
    res::end $message 
    return 0
}
# Default favicon/Icon handler
proc devServer::_handleFav {res {dir ""}} {
    proc mapkv {k v} {
	return  [dict create $k $v]
    }
    if {[set icon_path [dr3Utils globPattern {-nocomplain -types f} {*favicon{.png,jpeg,ico}*}]] ne {}} {
	puts "icon_path"
	set size [file size $icon_path]
	set icon [dr3Utils readLines $icon_path devServer::_getContent {} "binary" $size]
	res::setHeaders [dr3Utils mapKeyVal mapkv {"content-type" "content-length"} [list "image/x-icon" $size]]
	res::status 200
	res::end $icon "binary"
	return 0

    } else {
	res::setHeaders [dr3Utils mapKeyVal mapkv {"content-type" "content-length"} [list "text/plain" 0]]
	res::status 204
	res::end "binary" 
	return 0
    }
    
    
}

# Compute list of files to watch for changes
proc devServer::helpers::getFilesToWatch {file fmt} {
    variable ::devServer::files_to_watch
    # A copy of files
    switch $fmt {
	"css" -
	"js" -
	"html" {
	    set ::devServer::files_to_watch [lappend ::devServer::files_to_watch $file] 
	    ::devServer::helpers::watchFiles
	}
	
    } 
}

# Return next state of the Development server 
proc devServer::helpers::webServerTrans {curr_web_server_state } {
    #lassign $curr_web_server_state start watch modify restart
    switch $curr_web_server_state {
	"START" {return "WATCH"}
	"WATCH" {return "MODIFIED"}
	"MODIFIED" {return "REFRESH"}
	"REFRESH" {return "START"}
	default {
	    return "START"
	}
    }
}

# Compute file changes
proc devServer::helpers::watch {cb} {
    # TODO: Accept interval {interval {start end}} for checking
    # modified files
    variable ::devServer::monitor_files
    if {$::devServer::monitor_files eq {}} {
	after 5000 devServer::helpers::watch $cb
    }
    foreach {file curr_mtime} $::devServer::monitor_files  {
	if {[set new_mtime [file mtime $file]] > $curr_mtime} {
	    dict set ::devServer::monitor_files $file $new_mtime
	    #puts "{NT:$new_mtime OT:$curr_mtime }"
	    devServer::helpers::refresh
	    $cb $file 
	}
    }
    after 3000 devServer::helpers::watch $cb
}
# Compute files been watch 
proc devServer::helpers::watchFiles {} {
    variable ::devServer::monitor_files
    variable ::devServer::files_to_watch
    foreach {file}  $::devServer::files_to_watch {
	if {[dict exists $::devServer::monitor_files $file ]} {
	    continue
	}
	dict set ::devServer::monitor_files $file [file mtime $file] 
    }
}

# Webserver state transition 
proc devServer::helpers::processWebServerState {curr_server_state} {
    variable ::dreDevServer::file_to_watch
    switch [devServer::helpers::webServerTrans $next_server_state] {
	"START" {
	    #[devServer:: $files_to_watch]
	    [devServer::helpers::getFilesToWatch $::dreDevServer::files_to_watch]
	}
	
	"MODIFIED" {
	    [devServer::helpers::refresh $::dreDevServer::files_to_watch]
	    
	}
    }
}    

# Compute landing page/Root page (html)
proc devServer::helpers::getLandingPage {res} {
    if {$::devServer::base_dir ne ""} {
	set resources [dr3Utils globPattern {-nocomplain -nocase -directory -types f} {*.html}] 
	if {$resources ne ""} {
	    puts "REQPATH: $base_dir"
	    set full_path [file join $base_dir [lindex $resources 0]]
	    devServer::helpers::getFilesToWatch $base_dir "html"
	    return [devServer::_sendResponse $res $base_dir {"text/html" "text" "html"}]
	}
	return [devServer::_notFound $res]
    } else { 
	set resources [dr3Utils globPattern {-nocomplain -nocase -directory -types f} {*.html}] 
	if {$resources ne ""} {
	    set full_path [file join [pwd] [lindex $resources 0]]
	    puts "REQPATH: $full_path"
	    devServer::helpers::getFilesToWatch $full_path "html"
	    return [devServer::_sendResponse $res $full_path {"text/html" "text" "html"}]
	}
	return [devServer::_notFound $res]
    }
    
}
# Refresh state page when file is modified
proc devServer::helpers::refresh {{base_dir ""}} {
    global PORT
    set host "http://localhost"
    # webserver get base_dir
    try { 
	exec firefox [expr {$base_dir ne "" ? [format "%s:%s%s" $host $PORT $base_dir] : [format "%s:%s" $host $PORT]}] 
    } on error {result options} {
	puts "[dict get $options -errorinfo]"
    }
}
