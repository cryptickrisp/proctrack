#!/usr/bin/perl
#
# ----------------------------------------------------------------------------
# "THE BEER-WARE LICENSE" (Revision 42):
# <krisp@krisp.jp> wrote this file.  As long as you retain this notice you
# can do whatever you want with this stuff. If we meet some day, and you think
# this stuff is worth it, you can buy me a beer in return.   Kris Popendorf
# ----------------------------------------------------------------------------
#

use strict;
use Getopt::Long;
use Time::HiRes qw{time sleep};
use POSIX ":sys_wait_h";
use Pod::Usage;

local $\="\n";

my @track;
my $output;
my ($verbose,$debug,$periodic);
my $pid;
my $timeout=1;
my ($help,$man);
my ($fancy,$native);

shortHelp(1) unless GetOptions("o|output=s"=>\$output,"f|track=s"=>\@track,
			       "v|verbose!"=>\$verbose,"d|debug!"=>\$debug,
			       "p|pid=i"=>\$pid,"t|timeout=f"=>\$timeout,"P|periodic!"=>\$periodic,
			       "help"=>\$help,"man"=>\$man,
			       "n|native!"=>\$native,
			       "F|fancy!"=>\$fancy,
		  );
shortHelp(0) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;

our $useProcTable=(!$native ? ($fancy and eval 'use Proc::ProcessTable; 1'):0);
print "ProcTable is enabled" if ($useProcTable);

$timeout=1 unless $timeout;

my @statvals=qw{pid comm state ppid pgrp session tty_nr tpgid flags minflt cminflt majflt cmajflt utime stime cutime cstime priority nice num_threads itrealvalue starttime vsize rss rsslim startcode endcode startstack kstkesp kstkeip signal blocked sigignore sigcatch wchan nswap cnswap exit_signal processor rt_priority policy delayacct_blkio_ticks guest_time cguest_time};
@track=@statvals if "@track" eq 'all';
@track=map {split(/\W+/)} @track if @track;
@track=qw{utime stime rss vsize t} unless @track;
if($useProcTable) {
  my %ptRename = (vsize => 'size',
		  session => 'sess',
		  tty_nr => 'ttynum',);
  foreach (@track) {
    $_=$ptRename{$_} if exists $ptRename{$_}
  }
}

my $ofh;
$output=">&STDERR" unless $output;
if($output){
  open($ofh,">$output");
}

my $spawn;
if(!$pid){
  if(@ARGV){
    print STDERR "Running: @ARGV" if $debug;
    $spawn="@ARGV";
    if($pid=fork()){
      print STDERR "Spawned $pid. Tracking..." if $debug;
      close STDOUT;
      close STDIN;
    }else{
      exec(@ARGV);
      print STDERR "Failed to exec: @ARGV";
      exit;
    }
  }else{
    fail("Need either an existing PID or a command to run");
  }
}else{
  print STDERR "Tracking $pid" if $debug;
}
my $timestart=time;

while(($spawn and $s{stat}) ? (waitpid($pid,WNOHANG)<=0) : (kill(0,$pid))){
  my $news=procstat($pid);
  if($news){
    $s{seen}=time;
    $news->{t}=$s{seen}-$timestart;
    $news->{at}=$s{seen};
    $s{stat}=$news;
    report() if $periodic;
  }
}continue{
  sleep($timeout);
}

report() unless $periodic; #if periodic we already printed the last report when we got it

sub procstat {
  if($useProcTable){
    my $p=new Proc::ProcessTable(cache_ttys=>1);
    my $t=$p->table;
    die "Broken ProcessTable" unless $t;
    my ($proc)=grep {$_->pid == $pid} @$t;
    return $proc;
  }else{
    open(my $pfh,"/proc/$pid/stat") or return undef;
    my $statline=<$pfh>;
    my @vals=split(/\s+/,$statline);
    #  warn "Expected $#statvals but found $#vals" unless $#statvals==$#vals;
    return {map {$statvals[$_]=>$vals[$_]} 0..(min($#statvals,$#vals))};
  }
}

sub min {
  my ($x,@l)=@_;
  foreach my $y (@l){
    $x=$y if $y<$x;
  }
  return $x;
}

sub report {
  local $"="\t";
  unless($s{stat}){
    warn("Unable to sample pid:$pid");
  }
  my %stat=%{$s{stat}} if ref $s{stat};
  our @show;
  unless(@show){
    @show=@track;
    @show=(sort keys %stat) if $verbose;
    print $ofh "@show";
  }

  my @dat=@stat{@show};
  print $ofh "@dat";
}

sub fail {
  print STDERR "Error: @_";
  exit -1;
}

sub shortHelp {
  print <<ENDTEXT;
Usage: proctrack [-p pid] [options] [command]

Options:
  -p|--pid <pid>      => track this PID
  -o|--output <file>  => output to this file
  -P|--periodic       => sample repeatedly
  -t|--timeout <sec>  => polling frequency
  -f|--track <field1[,field2]> => fields to track
  -v|--verbose        => show everything
  --man               => show full manpage
ENDTEXT
  exit @_;
}

__END__

=head1 NAME

proctrack

=head1 SYNOPSIS

proctrack [-p pid] [options] [command]

=head1 DESCRIPTION

Tracks the vital (or trivial) statistics of a process over its
lifetime, outputting statistics when the process dies or at regular
intervals.

The values provided come from /proc/<pid>/stat or optionally
Proc::ProcessTable if it's available. Two additional columns "at" and
"t" are added reflecting absolute time and time since starting
proctrack respectively.

For a description of what each of that stats is, see L<proc(5)>.
It's useful to note that rss is in pages, and vsize is in bytes.

=head1 OPTIONS

=over

=item -o|--output <file>

Write output to the specified file. Default is to stderr.

=item -v|--verbose

Output B<everything>.

=item -d|--debug

Add debug output to STDERR.

=item -p|--pid <PID>

Track the specified <PID> instead of running a command.

=item -P|--periodic

Output status periodically rather than only at the end.

=item -t|--timeout <seconds>

Time between polling. Note that making this value small will eat
significantly more resources, possibly interferring with the process
you're monitoring.

=item -f|--track <item>

Items to track. Can be specified any number of times, or be a comma
delimited list.

=item -n|--native

Disables the use of Proc::ProcessTable. Proc::ProcessTable is
thoroughly handy in that it parses some of the more eccentric values
in stat (in particular the ones using jiffies) into sane values, but
for the bare essentially this is unnecessary and wastes significant
time (around 0.05s per poll).

=item -F|--fancy

Requests the use of Proc::ProcessTable.

=back

=head1 SEE ALSO

proc(5)
