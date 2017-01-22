# histoplot #

Create a histogram using Tcl and gnuplot.

## Prerequisites ##

### Tcl ###

Install
using
[ActiveState's installer](http://www.activestate.com/activetcl/downloads))

### Tcl's math::statistics package ###

Install with `teacup install math::statistics`.

### gnuplot ###

The primary download site is [on SourceForge](https://sourceforge.net/projects/gnuplot/files/gnuplot/).

## Example ##

Your data may be a file containing a list of currents in microamps, like:

	170
	187
	178
	186
	186
	200
	176
	160
	177
	192
	179
	186
	216
	175
	174
	173
	193
	186
	181
	196
	172
	171
	202
	187
	179
	177
	192
	166
	170
	171

Let's start our bins at 100uA, end them at 301uA, and have a bin width
of 5uA.  This means 40 bins.  The command to create the histogram
would be:

    tclsh histoplot.tcl -s 100 -e 301 -n 40 -u uA -l "Device current" sample_data.dat

...and the script will create `histogram.eps` in a `histoplot_output`
directory.  Note that this won't look the same as that seen with the
interactive wxt terminal.

[[https://github.com/johnpeck/histoplot/blob/master/example/histogram.png]]


