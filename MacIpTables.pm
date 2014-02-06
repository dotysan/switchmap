package MacIpTables;

use strict;
use Log::Log4perl qw(get_logger);
use Socket;

my %MacIpAddr;         # hash of IP addresses indexed by MAC addresses
my %MacHostName;       # hash of host names indexed by MAC addresses
my @AllSwitchNames;

#
# If you don't have HP OpenView, you have to get MAC-to-IP and
# MAC-to-HOSTNAME mappings some other way.  This function gets
# MAC-to-IP mappings from the MacList file, which is a stateful
# database of known MAC/IP information gleaned from router ARP caches.
# At sites that don't have OpenView, a cron job regularly runs the
# GetArp script to keep the MacList file up to date.  This function
# fills a hash named MacIpAddr.  It also uses DNS to reverse-resolve
# each IP address into a name, to fill a hash named MacHostName.
#
# Note that there can be several entries in the file for a single MAC
# address, for several reasons.  It could be that a machine has
# changed IP addresses, so there's an old entry and a new one.  It may
# be that some machines have the same MAC address on more than one
# port, as some Suns or cluster machines may do.  It's too much of a
# pain to deal with this problem, but we can at least make the code
# select the most recent of multiple entries, which is better than
# nothing.
#
sub GetMacTablesFromFiles () {
  my $logger = get_logger('log2');
  my $logger6 = get_logger('log6');
  $logger->debug("called");

  $logger->info("reading MAC/IP table from $Constants::MacListFile");
  open MACLIST, "<$Constants::MacListFile" or do {
    $logger->fatal("Couldn't open $Constants::MacListFile for reading, $!, have you run GetArp.pl?");
    exit;
  };
  my $MacIpCount = 0;
  my %MostRecentTime;
  while (<MACLIST>) {
    my ($mac, $ipaddr, $time) = split;
    if ((!defined $mac) or
        (!defined $ipaddr) or
        (!defined $time)) {
      $logger->warn("Unable to parse line $! in $Constants::MacListFile, skipping this line");
      next;
    }
    $logger6->debug("mac=\"$mac\", ipaddr=\"$ipaddr\", time=\"$time\"");
    if ((!exists $MostRecentTime{$mac}) or   # if this MAC hasn't been seen before or
        ($time > $MostRecentTime{$mac})) {   #    this MAC's time is more recent
      $MacIpAddr{$mac} = $ipaddr;
      $MostRecentTime{$mac} = $time;
      $MacIpCount++;
    }
  }
  close MACLIST;
  $logger->info("got $MacIpCount MAC-IPs");

  $logger->debug("returning");
}


sub GetHostNames () {
  my $logger = get_logger('log2');
  my $logger5 = get_logger('log5');
  $logger->debug("called");

  $logger->info("getting DNS names for the IP addresses");
  my $MacHostNameCount = 0;
  my $NoHostNameCount = 0;
  foreach my $mac (keys %MacIpAddr) {
    my $ipaddr = $MacIpAddr{$mac};
    # Before reading this comment, see the comment about 20 lines
    # below this one, about $findBrokenDnsServers.  When the DNS
    # server for a subnet is down, the DNS lookup of each address on
    # that subnet times-out, individually, which makes SwitchMap look
    # hung.  To avoid this, I manually set $DnsIsBroken to 1 and I set
    # the following pattern representing the subnet.  Then the code
    # skips gethostbyaddr calls for the broken IP range.  Perhaps
    # there is a more elegant solution than this, but it works.
    my $DnsIsBroken = 0;
    if (($DnsIsBroken)  and
        ($ipaddr =~ /198.17.196.(\d+)/)) {
      $MacHostName{$mac} = 'tmp37-' . $1;
      $MacHostNameCount++;
      $logger->warn("Hard-coding DNS name for IP address =\"$ipaddr\"");
    } else {
      # If your DNS seems broken, try set $findBrokenDnsServers to 1
      # and then run SwitchMap with the "-d 2" command-line option.
      # It'll tell you about each attempt to resolve an IP addresses
      # into a name, and you'll notice which IP addresses pause for a
      # long time before they time out.  Then you can fix the DNS
      # problem, or use the $DnsIsBroken hack (about 20 lines above
      # this line) to mitigate the problem.
      my $findBrokenDnsServers = 0;
      if ($findBrokenDnsServers) {
        $logger->info("calling DNS to reverse-resolve $ipaddr..."); # extra
        $logger5->warn("Getting DNS name for IP address =\"$ipaddr\""); # extra
      }
      my $DnsName = gethostbyaddr Socket::inet_aton($ipaddr), AF_INET;
      if (defined $DnsName) {
        $MacHostName{$mac} = $DnsName;
        $MacHostNameCount++;
        if ($findBrokenDnsServers) {
          $logger5->info("got \"$DnsName\""); # extra
        }
      } else {
        $NoHostNameCount++;
        if ($findBrokenDnsServers) {
          $logger5->info("failed!"); # extra
        }
      }
    }
  }
  $logger->info("got $MacHostNameCount hostnames with $NoHostNameCount misses");

  $logger->debug("returning");
}


#
# The ScanOvtopodumpArray function is passed an array containing the
# output of an "ovtopodump" command from an HP OpenView machine.  It
# parses the array and fills in the three "MacTables" data structures
#
sub ScanOvtopodumpArray ($) {
  my $OvtopodumpArrayRef = shift; # passed in
  my $logger = get_logger('log4');
  $logger->debug("called");

  #
  # Skip lines before the NODES section.
  #
  my $OARline;
  do {
    $OARline = shift @$OvtopodumpArrayRef;
    if (!defined $OARline) {
      $logger->fatal("Couldn't find NODES line in ovtopodump output");
      exit;
    }
  } while ($OARline ne "NODES:\n");

  my @Oids = CiscoMibConstants::getCiscoSysObjectIDs();
  my %Ips;
  my %Nodes;
  my %ManagedIps;
  my %ManagedNodes;
  my @SwNames;
  while ($_ = shift(@$OvtopodumpArrayRef)) {
    chop;
    last if $_ eq '';

    my ($type, $nodename, $status, $ipaddr, $MacOrOid) = (split)[1,2,3,4,5];
    next if $type ne 'IP';
    next if !defined $MacOrOid;
    if (length $MacOrOid == 14) {             # if it's a MAC address
      $MacOrOid = lc substr $MacOrOid, 2;     # lowercase & strip leading "0x"
      $MacIpAddr{$MacOrOid} = $ipaddr;
      $MacHostName{$MacOrOid} = ($ipaddr eq $nodename) ? '' : $nodename;
    } elsif ($MacOrOid =~ /^[0-9\.]+$/) {     # else if it's an SNMP OID
      $MacOrOid =~ s/^\.//;                   # remove leading period, if any
      if (grep(/^$MacOrOid$/, @Oids) == 1) {  # if it begins with one of the masks we seek
        if (grep (/^$nodename$/, @ThisSite::SkipTheseSwitches) != 1) {
          push @SwNames, $nodename if $status ne 'Unmanaged';
        }
      }
    }
  }
  @AllSwitchNames = sort @SwNames;

  $logger->debug("returning");
}


#
# Execute an "ovtopodump -Lo" command on a machine that's running HP
# OpenView Network Node Manager, and scan the output for MAC/hostname
# information.  Populate the MacIpAddr and MacHostName hashes and the
# AllSwitchNames array.
#
sub GetMacTablesFromOpenView () {
  my $logger = get_logger('log2');
  $logger->debug("called");

  $logger->info("Getting MAC/name info from HP Network Node Manager on $ThisSite::OpenViewHost...");
  #
  # Read the output of an OpenView "ovtopodump" command into
  # @OvtopodumpArray.  If OpenView is running on the local host, just
  # execute the ovtopodump command.  If it's running on another
  # machine, fork an ssh process connected to the other machine.
  #
  if ($ThisSite::OpenViewHost eq 'localhost') {
    open FORK, "/opt/OV/bin/ovtopodump -Lo |";
  } else {
    open FORK, "/usr/bin/ssh $ThisSite::SshKeyOption $ThisSite::OpenViewHost /opt/OV/bin/ovtopodump -Lo |";
  }
  my @OvtopodumpArray = <FORK>;
  close FORK;

  if ($#OvtopodumpArray == -1) {
    $logger->fatal("dump of OpenView database yielded zero records - are OV processes running on $ThisSite::OpenViewHost?  Dying.");
    exit;
  }
  #
  # Scan the output for lines that contain SNMP object identifiers that
  # are unique to Cisco switches.  Generate a list named AllSwitchNames
  # that contains the names of the switches.
  #
  ScanOvtopodumpArray(\@OvtopodumpArray);
  $logger->info("got $#AllSwitchNames devices");

  $logger->debug("returning");
}


#
# Get the list of Mac-to-IP address mappings, and the list of host
# names, and the list of switches.  Get this data from HP Openview or
# from config files.
#
sub initialize ($) {
  my $doDns = shift;            # whether to fill MacHostName or not
  my $logger = get_logger('log1');
  $logger->debug("called");

  $logger->info("getting switch names and MAC/IP relationships...");
  if ($ThisSite::GetMacIpAddrFromHpOpenView or $ThisSite::GetSwitchListFromHpOpenView) {
    GetMacTablesFromOpenView();
  }

  if (!$ThisSite::GetMacIpAddrFromHpOpenView) {
    GetMacTablesFromFiles();
    # Ok, $doDNS is a real kludge, and here's what it does: If we're
    # being called by ScanSwitch, hostnames aren't needed, and $doDns
    # will be false.  If we're being called by Switchmap, hostnames
    # are needed, and $doDns will be true.  I added $doDNS after I
    # discovered that DNS was being done every time ScanSwitch was
    # run, a real waste of time.
    GetHostNames() if $doDns;
  }

  # strip off, like, ".ucar.edu" from all the host names
  foreach my $Mac (keys %MacHostName) {
    $MacHostName{$Mac} =~ s/$ThisSite::DnsDomain$//;
  }

  my $Source;
  if ($ThisSite::GetSwitchListFromHpOpenView) {
    $Source = 'OpenView';
  } else {
    @AllSwitchNames = @ThisSite::LocalSwitches;
    ThisSite::ReformatSwitchNames(\@AllSwitchNames);
    $Source = 'static array';
  }
  my $NbrSwitches = $#AllSwitchNames + 1;
  $logger->info("got $NbrSwitches switch names from $Source");

  $logger->debug("returning");
}


sub getAllSwitchNames () {
  return @AllSwitchNames;
}


sub getMacIpAddr () {
  return \%MacIpAddr;
}


sub getMacHostName () {
  return \%MacHostName;
}

1;
