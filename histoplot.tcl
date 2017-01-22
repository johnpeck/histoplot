#!/opt/ActiveTcl-8.6/bin/tclsh
# Hey Emacs, use -*- Tcl -*- mode

set scriptname [file rootname $argv0]
# ---------------- We need the math::statistics package ---------------
package require math::statistics

# ---------------------- Command line parsing -------------------------
package require cmdline
set usage "usage: [file tail $argv0] \[options] filename"
set options {
    {s.arg 0 "Starting bin value"}
    {e.arg end "Ending bin value"}
    {n.arg 100 "Number of bins"}
    {l.arg "No label" "x-axis label"}
    {u.arg "units" "Measurement units"}
}

try {
    array set params [::cmdline::getoptions argv $options $usage]
} trap {CMDLINE USAGE} {msg o} {
    # Trap the usage signal, print the message, and exit the application.
    # Note: Other errors are not caught and passed through to higher levels!
    puts $msg
    exit 1
}

# After cmdline is done, argv will point to the last argument
if {[llength $argv] == 1} {
    set datafile $argv
} else {
    puts [cmdline::usage $options $usage]
    exit 1
}

# ----------------------- Gnuplot settings ----------------------------

# The wxt terminal can keep windows alive after the gnuplot process
# exits.  This allows calling multiple persistent windows which allow
# zooming and annotation.
set gnuplot_terminal wxt

# --------------------------- Functions -------------------------------


proc read_file {filename} {
    # Return a list of lines from a query file
    #
    # The file consists of timestamp lines.  Each line contains the
    # timestamp, followed by a list of Vcc values for each considered
    # sensor.
    if { [catch {open $filename r} fid] } {
	    puts "Could not open file $filename"
	return
    }
    set datafile_list [split [read $fid] "\n"]
    return $datafile_list
}

proc valid_timestamp {timestamp} {
    # Return true if this is a valid unix time stamp
    if {$timestamp > 0 && $timestamp < 1502233206} {
	return true
    } else {
	return false
    }
}

proc valid_current {minlimit maxlimit current} {
    # Return true if the current is between the limits
    if {[expr $current >= $minlimit] && [expr $current <= $maxlimit]} {
	return true
    } else {
	return false
    }
}

proc valid_vcc {vcc_value} {
    # Return true if this is a valid Vcc value
    try {
	if [expr $vcc_value > 0] {
	    return true
	} else {
	    return false
	}
    } trap {TCL PARSE EXPR BADCHAR} {} {
	return false
    }
}

proc get_unixtime {textline} {
    # Return the floating-point unix timestamp given a line of text
    #
    global params
    set textline_list [regexp -all -inline {\S+} $textline]
    if { $params(p) } {
	# Portaterm-style timestamps.  The timestamp is the sixth item
	# in the list.
	set timestamp [lindex $textline_list 6]
    } else {
	# The timestamp is the second item in the list
	set timestamp [lindex $textline_list 1]
    }
    return $timestamp
}

proc mean_current_from_file {directory datafile} {
    # Return the mean current from an extracted datafile -- within the
    # time span specified from the command line
    #
    global params
    set linelist [read_file $directory/$datafile]
    set ilist [list]
    foreach line [lrange $linelist 0 end] {
	set wordlist [regexp -all -inline {\S+} $line]
	set current [lindex $wordlist 0]
	lappend ilist $current
    }
    set mean_value [math::statistics::mean $ilist]
    return $mean_value
}

proc sigma_current_from_file {directory datafile} {
    # Return the standard deviation for the current from an extracted
    # datafile
    #
    global params
    set linelist [read_file $directory/$datafile]
    set ilist [list]
    foreach line [lrange $linelist 0 end] {
	set wordlist [regexp -all -inline {\S+} $line]
	set current [lindex $wordlist 0]
	lappend ilist $current
    }
    set sigma_value [math::statistics::stdev $ilist]
    return $sigma_value
}

proc max_current_from_file {directory datafile} {
    # Return the maximum of the current from an extracted datafile
    #
    global params
    set linelist [read_file $directory/$datafile]
    set ilist [list]
    foreach line [lrange $linelist 0 end] {
	set wordlist [regexp -all -inline {\S+} $line]
	set current [lindex $wordlist 0]
	lappend ilist $current
    }
    set max_value [math::statistics::max $ilist]
    return $max_value
}

proc datalist_from_file {directory datafile} {
    # Return the list of data from the datafile
    #
    global params
    set linelist [read_file $directory/$datafile]
    set ilist [list]
    foreach line [lrange $linelist 0 end] {
	set wordlist [regexp -all -inline {\S+} $line]
	set current [lindex $wordlist 0]
	if [string length $current] {
	    if [valid_current 0 1000 $current] {
		lappend ilist $current    
	    }
	} else {
	    puts "Read invalid current of $current"
	}	 
    }
    return $ilist
}

proc get_binlist {minbin binwidth numbins} {
    global params
    
    set binlist [list]
    for {set i 0} {$i < $numbins} {incr i} {
	lappend binlist [expr $minbin + $i * double($binwidth)]
    }
    return $binlist
}

proc write_binfile {directory binfile binlist datalist} {
    set fot [open ${directory}/${binfile} w]
    set index 0
    set countlist [math::statistics::histogram $binlist $datalist]
    foreach bin $binlist {
	puts $fot "$bin [lindex $countlist $index]"
	incr index
    }
    close $fot 
}

proc stdev_vcc_from_file {directory datafile} {
    # Return the sample standard deviation of Vcc from an extracted
    # datafile
    #
    set linelist [read_file $directory/$datafile]
    set vcclist [list]
    # First line gives column definitions
    foreach line [lrange $linelist 1 end] {
	set wordlist [regexp -all -inline {\S+} $line] 
	lappend vcclist [lindex $wordlist 2]
    }
    set stdev_value [math::statistics::stdev $vcclist]
    return $stdev_value
}

proc activations_from_file {directory datafile} {
    # Return the number of activations from an extracted datafile
    #
    set linelist [read_file $directory/$datafile]
    # First line gives column definitions
    set count 0
    foreach line [lrange $linelist 1 end] {
	if [string length $line] {
	    incr count
	}
    }
    return $count
}

proc days_from_file {directory datafile} {
    # Return the number of days in an extracted datafile
    #
    set linelist [read_file $directory/$datafile]
    # First line gives column definitions
    foreach line [lrange $linelist 1 end] {
	if [string length $line] {
	    set wordlist [regexp -all -inline {\S+} $line]
	    set day [lindex $wordlist 1]
	}
    }
    return $day
}

proc escape_underscores {string_with_underscores} {
    # Return a string with _ replace by \_
    #
    return [string map {_ \\_} $string_with_underscores]
}

proc write_raw_plotscript {output_directory plot_script_name datafile} {
    # Write gnuplot commands to a file
    #
    # Arguments:
    #   output_directory -- Where to write the gnuplot commands (must exist)
    #   plot_script_name -- What to call the gnuplot script
    #   datafile -- File containing list of values
    global argv
    global params
    global gnuplot_terminal
    set outfile $output_directory/$plot_script_name
    # Set the fractional amount of padding to require at the top
    # of the y-axis.  This makes more room for the plot legend.  A
    # value of 1 will give no padding, and a value of 2 will make
    # the padding twice the maximum current value plotted.
    set plot_padding 1.01
    set mean_current [mean_current_from_file $output_directory $datafile]
    set sigma_current [sigma_current_from_file $output_directory $datafile]
    set max_current [max_current_from_file $output_directory $datafile]
    set datalist [datalist_from_file $output_directory $datafile]
    if { [catch {open $outfile w} filepointer] } {
	puts "Could not open $outfile for writing"
	return
    }
    puts $filepointer "reset"
    puts $filepointer "set terminal $gnuplot_terminal size 800,600"
    # Define the normal distribution
    puts $filepointer "regnorm(x,mean,std) = (1/(std*sqrt(2*pi)))*exp(-(x-mean)**2/(2*std**2))"
    puts $filepointer "set samples 500"
    set max_x [expr $mean_current + ($mean_current - $params(s))]    
    if {[string equal $params(e) end]} {
	puts $filepointer "set xrange \[ $params(s) : $max_x \]"
	set binwidth [expr ($max_current - $params(s))/double($params(n))]
    } else {
	puts $filepointer "set xrange \[ $params(s) : $max_x \]"
	set binwidth [expr ($params(e) - $params(s))/double($params(n))]
    }
    
    set binlist [get_binlist $params(s) $binwidth $params(n)]
    write_binfile $output_directory "binned.dat" $binlist $datalist
    puts $filepointer "set format y '%1.0s %c'"
    puts $filepointer "set format x '%0.0s %c'"
    puts $filepointer "set xlabel '$params(l) ($params(u))'"
    puts $filepointer "set ylabel 'Counts'"
    # Draw tic marks at 1, 2, 3, ...
    puts $filepointer "set ytics 1, 1"
    puts $filepointer "set key top left"
    set plot_instruction "using 1:2 with boxes title"
    puts $filepointer "plot 'binned.dat' $plot_instruction '[escape_underscores $argv]' "
    set plot_instruction "replot mean = $mean_current, std = $sigma_current, regnorm(x,mean,std) axes x1y2"
    append plot_instruction " title 'Estimated parent distribution'"
    puts $filepointer $plot_instruction
    set plot_instruction "set label"
    append plot_instruction " 'Points: [llength $datalist]' "
    append plot_instruction " at graph 0.7, graph 0.95"
    puts $filepointer $plot_instruction
    set plot_instruction "set label"
    append plot_instruction " 'Mean: [format "%0.1f" $mean_current] $params(u)' "
    append plot_instruction " at graph 0.7, graph 0.9"
    puts $filepointer $plot_instruction
    set plot_instruction "set label"
    append plot_instruction " 'Standard deviation: [format "%0.1f" $sigma_current] $params(u)' "
    append plot_instruction " at graph 0.7, graph 0.85"
    puts $filepointer $plot_instruction
    puts $filepointer {yaxis_max = GPVAL_Y_MAX}
    puts $filepointer {ydata_max = GPVAL_DATA_Y_MAX}
    puts $filepointer {yaxis_min = GPVAL_Y_MIN}
    puts $filepointer {ydata_min = GPVAL_DATA_Y_MIN}
    puts $filepointer "if (yaxis_max < ($plot_padding * ydata_max)) \{"
    puts $filepointer "  set yrange \[(ydata_min / $plot_padding):($plot_padding * ydata_max)\] "
    puts $filepointer "  replot"
    puts $filepointer "\}"
    puts $filepointer "if (yaxis_min > (ydata_min / $plot_padding)) \{"
    puts $filepointer "  set yrange \[(ydata_min / $plot_padding):($plot_padding * ydata_max)\] "
    puts $filepointer "  replot"
    puts $filepointer "\}"
    puts $filepointer "set output 'histogram.eps'"
    puts $filepointer "set terminal postscript eps color size 6in,4in"
    puts $filepointer "replot"
    puts $filepointer "set terminal wxt size 800,600"
    puts $filepointer "replot"
    close $filepointer
    return $outfile
}


# The output file and plot directory
set plotdir ${scriptname}_output


# Remove the directory if it exists.  Then create a new, empty
# directory.
file delete -force -- $plotdir
file mkdir $plotdir

# pingdict will be a dictionary of hwid : [list of ping times]
set pingdict [dict create]


# Start processing the file
set log_line_list [read_file $datafile]

# Ordered list of HWIDs
set hwid_list [list]

# File list for plotting
set datafile_list [list]

# Loop through each line in the datafile, skipping the first (header)
# line
foreach logline [lrange $log_line_list 1 end] {
    if ![string length $logline] {
	# The line length is zero
	continue
    }
    set linelist [split $logline ","]
    set current [string trim [lindex $linelist 0]]
    if [valid_current 0 500 $current] {
	set fot [open $plotdir/hplot.dat a]
	puts $fot "$current"
	close $fot
    } else {
	# This is a spurious reading
	puts "Saw unusual reading of $current A"
	continue                                	
    }	
}

set plot_script_name hplot.gp
write_raw_plotscript $plotdir $plot_script_name hplot.dat
cd $plotdir
exec gnuplot -persist $plot_script_name


