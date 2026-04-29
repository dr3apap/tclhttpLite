#!/usr/bin/env tclsh

package provide dr3Utils 1.0

namespace eval ::dr3Utils {
    namespace export readLine readLines _readLine map mapKeyVal getDictVal globPattern isDict
}

proc ::dr3Utils::readLines {channel cb acc {fmt "text"} {size ""}} {
    set fh [open $channel r]
    if { $fmt eq "binary" } {
	fconfigure $fh -translation binary
	set acc [::dr3Utils::_readLine $fh $cb $acc $fmt $size]
	close $fh
	return $acc
    } 
    while {[lassign [::dr3Utils::_readLine $fh $cb $acc $fmt] len lines] eq "" && ($len >= 0) } {
	set acc $lines
    }
    close $fh
    return $acc
}

proc ::dr3Utils::_readLine {channel cb acc {fmt "text"} {size ""}} {
    try { 
	if {$fmt eq "binary"} {
	    if {$size > 0} { 
		set contents [read $channel $size] 
		set len [expr {([string length $contents] == 0) ? -1 : [string length $contents]}]
		return [$cb $len $contents $acc]
	    } else {
		set contents [read $channel] 
		set len [expr {([string length $contents] == 0) ? -1 : [string length $contents]}]
		return [$cb $len $contents $acc]
		
	    }
	} else {
	    if {$size > 0 } {
		set len [gets $channel line]
		set acc [$cb $len $line $acc]
		return [list $len $acc]
	    } else  {
		set len [gets $channel line]
		set acc [$cb $len $line $acc]
		return [list $len $acc]
	    }
	}
    } on error {result options} {
	puts "can't read stream from $channel"
	puts stderr "readLine encouter Error:\n[dict get $options -errorcode]\n[dict get $options -errorinfo]"
	return [list -1 "error"]
    }
}

proc ::dr3Utils::readLine {channel cb {fmt "text"} {size ""}} {
    try { 
	if {$fmt eq "text"} {
	    set len [gets $channel line]
	    if {$len < 0} {
		close $channel
		return [uplevel 1 $cb $len ""]
	    }
	    if {$size ne ""} {
		set line [string range $line 0 [expr {$size  - 1}]]
		close $channel
		return [uplevel 1 $cb $size [append line "\n"]] 
	    } else {
		close $channel
		return [uplevel 1 $cb $len [append line "\n"]]
	    }
	} elseif {[string tolower  $fmt] eq "b"  || [string tolower $fmt] eq "binary"} {
	    fconfigure $channel -translation binary
	    set bin_data [read $channel [strring length $size]]
	    return [uplevel 1 $cb [string length $bin_data] $line]
	}
    } on error {result options} {
	puts "can't read stream from $channel"
	puts stderr "procedure readLine encouter Error:\n[dict get $options -errorcode]\n[dict get $options -errorinfo]"
	return [uplevel 1 $cb -1 "error"]
    } finally {
	close $channel
    } 
}


proc dr3Utils::map {cb list_obj} {
    set res {}
    for {set i 0} {$i < [llength $list_obj]} {incr i} {
	lappend res [uplevel 1 $cb [lindex $list_obj $i] $i $list_obj]
    }
    return $res
}

proc dr3Utils::mapKeyVal {cb list_1 list_2} {
    set res {}
    foreach v1 $list_1  v2 $list_2 {
	set res [dict merge $res [uplevel 1 $cb $v1 $v2]]
    }
    return $res
}

proc dr3Utils::getDictVal {dict k} {
    try {
	return [dict get $dict $k]
    } on error {} {
	return {}
    }
}

#catch {open "adept.log" r} fh options
#puts [::dr3utils::readLines $fh testUpper {}]
proc testUpper {len line acc} {
    return [dict merge $acc [dict create $len [string toupper $line]]]
}

proc test_readLine {len data} {
    return [string toupper $data] 
}

proc dr3Utils::globPattern {pattern {fmt_opts {}}} {
    set pattern  [format "%s" $pattern]
    return [glob {*}$fmt_opts -- $pattern] 
}


proc dr3Utils::isDict {data} {
    if {[catch {dict size $data}]}  {
	return 0 ;#Not a valid dict
    }
    return 1 ;#valid dict
}
