set opt(nn)			34		;# number of nodes
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
set nof_tcps 100/3
set nof_senders 12

# the total (theoretical) load
set rho 0.8
set rho_cl [expr ($rho/$nof_senders)]
#flow interarrival time
set mean_intarrtime [expr ($pktsize+40)*8.0*$filesize/(11000000*$rho_cl)]
puts "1/la = $mean_intarrtime"

for {set ii 0} {$ii < $opt(nn)} {incr ii} {
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
for {set access 3} {$access < $nn} {incr access 4} {
    set i1 [expr $access - 1]
    set i2 [expr $access - 2]
    set i3 [expr $access - 3]
    $ns duplex-link $node_($i1) $node_($access) 10Mb 10ms DropTail
    $ns queue-limit $node_($i1) $node_($access) 100

    $ns duplex-link $node_($i2) $node_($access) 10Mb 10ms DropTail
    $ns queue-limit $node_($i1) $node_($access) 100


    $ns duplex-link $node_($i3) $node_($access) 10Mb 10ms DropTail
    $ns queue-limit $node_($i1) $node_($access) 100

    if {$access < 16} {
        $ns duplex-link $node_($access) $node_([expr $nn - 2]) 100Mb "[expr [expr [expr $access/3]%3]*5]ms" DropTail
        $ns queue-limit $node_($access) $node_([expr $nn - 2]) 100
    }
    if {$access > 16} {
        $ns duplex-link $node_($access) $node_([expr $nn - 1]) 100Mb "[expr [expr [expr $access/3]%3]*5]ms" DropTail
        $ns queue-limit $node_($access) $node_([expr $nn - 1]) 100
    }
}
# Bottleneck Link between the nodes
$ns duplex-link $node_([expr $nn - 2]) $node_([expr $nn - 1]) 10Mb 30ms DropTail

for {set jj 0} {$jj < 100/3} {incr jj} {
    for {set ii 3} {$ii < $nn/2} {incr ii 4} {
        set tcpClass [expr $ii/3]
        for {set dec 3} {$dec >= 0} {incr dec -1} {
            set tcp [new Agent/TCP/Reno]
            $tcp set packetSize_ $pktsize
            $tcp set class_ $tcpClass
            $tcp set window_ $maxwnd
            $ns attach-agent $node_([expr $ii - $dec]) $tcp
            set sink [new Agent/TCPSink]
            $ns attach-agent $node_([expr $ii - $dec + 16]) $sink
            $ns connect $tcp $sink
            $tcp set fid_ [expr 100*[expr $ii - $dec] + $jj]
            lappend tcp_s([expr $ii - $dec]) $tcp
            lappend tcp_d([expr $ii - $dec + 16]) $sink
            set ftp_local [new Application/FTP]
            $ftp_local attach-agent $tcp
            $ftp_local set type_ FTP
            lappend ftp([expr $ii - $dec]) $ftp_local
            lappend freelist([expr $ii - $dec]) $jj
        }
    }
}
# $ns at 50 "[start_flow 0 50]"
# $ns at 50 "[start_flow 1 50]"
# $ns at 50 "[start_flow 2 50]"
# $ns at 50 "[start_flow 3 50]"

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
# # Call the finish procedure after end of simulation time
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
