# NAME

proctrack

# SYNOPSIS

proctrack \[-p pid\] \[options\] \[command\]

# DESCRIPTION

Tracks the vital (or trivial) statistics of a process over its
lifetime, outputting statistics when the process dies or at regular
intervals.

The values provided come from /proc/<pid>/stat or optionally
Proc::ProcessTable if it's available. Two additional columns "at" and
"t" are added reflecting absolute time and time since starting
proctrack respectively.

For a description of what each of that stats is, see [proc(5)](http://man.he.net/man5/proc).
It's useful to note that rss is in pages, and vsize is in bytes.

# OPTIONS

- -o|--output <file>

    Write output to the specified file. Default is to stderr.

- -v|--verbose

    Output **everything**.

- -d|--debug

    Add debug output to STDERR.

- -p|--pid <PID>

    Track the specified <PID> instead of running a command.

- -P|--periodic

    Output status periodically rather than only at the end.

- -t|--timeout <seconds>

    Time between polling. Note that making this value small will eat
    significantly more resources, possibly interferring with the process
    you're monitoring.

- -f|--track <item>

    Items to track. Can be specified any number of times, or be a comma
    delimited list.

- -n|--native

    Disables the use of Proc::ProcessTable. Proc::ProcessTable is
    thoroughly handy in that it parses some of the more eccentric values
    in stat (in particular the ones using jiffies) into sane values, but
    for the bare essentially this is unnecessary and wastes significant
    time (around 0.05s per poll).

- -F|--fancy

    Requests the use of Proc::ProcessTable.

# SEE ALSO

proc(5)
