set opt(nn)			6		;# number of nodes
set opt(seed)		10
set opt(stop)		5000		;# simulation time
set ns		[new Simulator]

# Opening Trace file
set tracefd     [open simple.tr w]
$ns trace-all $tracefd

set namfd [open out.nam w]
$ns namtrace-all $namfd

set simstart 10
set simend $opt(stop)


#Random variable
set rng [new RNG]
$rng seed $opt(seed)

set maxwnd 1000 ; # TCP Window Size
set pktsize 1460 ; # Pkt size in bytes (1500 - IP header - TCP header)
set filesize 500 ; #As count of packets

# maximum number of tcps per class
set nof_tcps 100
set nof_senders 4

# the total (theoretical) load
set rho 0.8
set rho_cl [expr ($rho/$nof_senders)]
#flow interarrival time
set mean_intarrtime [expr ($pktsize+40)*8.0*$filesize/(11000000*$rho_cl)]
puts "1/la = $mean_intarrtime"

for {set ii 0} {$ii < $nof_senders} {incr ii} {
    #contains the delay results for each class
    set delres($ii) {}
    #contains the number of active flows as a function of time
    set nlist($ii) {}
    #contains the free flows
    set freelist($ii) {}
    #contains information of the reserved flows
    set reslist($ii) {}
    set tcp_s($ii) {}
    set tcp_d($ii) {}
}


###########################################
# Routine performed for each completed file transfer
Agent/TCP instproc done {} {
    global ns freelist reslist ftp rng filesize mean_intarrtime nof_tcps \
        simstart simend delres nlist nof_senders

    #flow-ID of the TCP flow
    set flind [$self set fid_]

    #the class is determined by the flow-ID and total number of tcp-sources
    set sender [expr int(floor($flind/$nof_tcps))]
    set ind [expr $flind-$sender*$nof_tcps]
    lappend nlist($sender) [list [$ns now] [llength $reslist($sender)]]

    for {set nn 0} {$nn < [llength $reslist($sender)]} {incr nn} {
        set tmp [lindex $reslist($sender) $nn]
        set tmpind [lindex $tmp 0]
        if {$tmpind == $ind} {
            set mm $nn
            set starttime [lindex $tmp 1]
        }
    }

    set reslist($sender) [lreplace $reslist($sender) $mm $mm]
    lappend freelist($sender) $ind

    set tt [$ns now]
    if {$starttime > $simstart && $tt < $simend} {
        lappend delres($sender) [expr $tt-$starttime]
    }

    if {$tt > $simend} {
        $ns at $tt "$ns halt"
    }
}


###########################################
# Routine performed for each new flow arrival
proc start_flow {sender produceTime} {
    global ns freelist reslist ftp tcp_s tcp_d rng nof_tcps filesize mean_intarrtime simend nof_senders
    #you have to create the variables tcp_s (tcp source) and tcp_d (tcp destination)
    set freeflows [llength $freelist($sender)]
    set resflows [llength $reslist($sender)]
    lappend nlist($sender) [list $produceTime $resflows]

    if {$freeflows == 0} {
        puts "Sender $sender: At $produceTime, nof of free TCP sources == 0!!!"
    }
    if {$freeflows != 0} {
        #take the first index from the list of free flows
        set ind [lindex $freelist($sender) 0]
        set cur_fsize [expr ceil([$rng exponential $filesize])]

        [lindex $tcp_s($sender) $ind] reset
        [lindex $tcp_d($sender) $ind] reset
        $ns at $produceTime "[lindex $ftp($sender) $ind] produce $cur_fsize"

        set freelist($sender) [lreplace $freelist($sender) 0 0]
        lappend reslist($sender) [list $ind $produceTime $cur_fsize]

        set newarrtime [expr $produceTime+[$rng exponential $mean_intarrtime]]
        $ns at $newarrtime "[start_flow $sender $newarrtime]"

        if {$produceTime > $simend} {
            $ns at $produceTime "$ns halt"
        }
    }
}

for {set i 0} {$i < $opt(nn) } {incr i} {
    set node_($i) [$ns node]
}

#Sender/receivers location
set nn $opt(nn)

#Create links between the nodes
$ns duplex-link $node_(0) $node_(4) 100Mb 10ms DropTail
$ns duplex-link $node_(1) $node_(4) 100Mb 40ms DropTail
$ns duplex-link $node_(2) $node_(4) 100Mb 70ms DropTail
$ns duplex-link $node_(3) $node_(4) 100Mb 100ms DropTail

# Bottleneck Link between the nodes
$ns duplex-link $node_(4) $node_(5) 10Mb 10ms DropTail

$ns queue-limit $node_(0) $node_(4) 100000
$ns queue-limit $node_(1) $node_(4) 100000
$ns queue-limit $node_(2) $node_(4) 100000
$ns queue-limit $node_(3) $node_(4) 100000
$ns queue-limit $node_(4) $node_(5) 100000

# create a random variable that follows the uniform distribution
set loss_random_variable [new RandomVariable/Uniform]
$loss_random_variable set min_ 0 # the range of the random variable;
$loss_random_variable set max_ 100
set loss_module [new ErrorModel]
$loss_module drop-target [new Agent/Null]
$loss_module set rate_ 10
$loss_module ranvar $loss_random_variable

$ns lossmodel $loss_module $node_(4) $node_(5)

for {set jj 0} {$jj < 100} {incr jj} {
    for {set ii 0} {$ii < $nn - 2} {incr ii} {
        set tcp [new Agent/TCP]
        $tcp set packetSize_ $pktsize
        $tcp set class_ 2
        $tcp set window_ $maxwnd
        $ns attach-agent $node_($ii) $tcp
        set sink [new Agent/TCPSink]
        $ns attach-agent $node_(5) $sink
        $ns connect $tcp $sink
        $tcp set fid_ [expr 100*$ii + $jj]
        lappend tcp_s($ii) $tcp
        lappend tcp_d($ii) $sink
        set ftp_local [new Application/FTP]
        $ftp_local attach-agent $tcp
        $ftp_local set type_ FTP
        lappend ftp($ii) $ftp_local
        lappend freelist($ii) $jj
    }
}
$ns at 50 "[start_flow 0 50]"
$ns at 50 "[start_flow 1 50]"
$ns at 50 "[start_flow 2 50]"
$ns at 50 "[start_flow 3 50]"

proc finish {} {
    global ns namfd tracefd
    $ns flush-trace
    #Close the NAM trace file
    close $namfd
    close $tracefd
    #Execute NAM on the trace file
    exec nam out.nam &
    exit 0
}
# Call the finish procedure after end of simulation time
$ns at $simend "finish"
$ns run
############# Add your code from here ################

# create all TCP flows
# - attach them to access nodes
# - configure the parameters (flow id, packet size)
# - flow numbering assumed to be the following
#   - class 1 id's: 0...nof_tcps-1
#   - class 2 id's: nof_tcps...(2*nof_tcps)-1, etc.
# - create an FTP application on top of each TCP
# - remember to insert each new connection in freelist
#
# - Schedule the first flow arrivals for each class
#
# and Finally process the collected result
