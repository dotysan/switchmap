package WritePortsDirectory;

use strict;
use Log::Log4perl qw(get_logger :levels);
use WriteUnusedDirectory;
use WritePoePortsFile;
use WriteSuspiciousPortsFile;


sub SpareHeader () {
  return <<EHEAD;
<p>
This web page lists switches that do not have <i>spare ports</i> for
one or more VLANs.
</p>
<p>
<strong>What is a spare port?</strong><br>
A spare port is an inactive port that is configured for a VLAN other
than VLAN&nbsp;1 (remember, VLAN&nbsp;1 is for unused ports).
Spare ports are intentionally configured on real VLANs even though
there may be nothing actually connected to the port.  Spare ports
have switch port labels that say "SPARE".
<p>
<strong>Why have spare ports?</strong><br>
We use spare ports for two reasons:
<ol>
<li>To speed up activations<br>
When a new connection needs to be made to a VLAN, we have to identify
the nearest switch to the site where the connection is needed, find
an unused port on the switch, configure the port onto the VLAN, and
connect a patch cable.  Only then can the new connection be tested.
This process goes faster if there's already a spare port for the
VLAN on the switch.
</li>
<li>To provide on-site laptop access for network engineers<br>
When a network engineer is on-site, physically near a deployed switch,
s/he may need access to the switch's command-line interface.  The
serial console port can be used to execute "show" commands and other
configuration commands, but doesn't provide access to the Internet
for email or to tftp new software into the switch.   By permanently
allocating a known port on each switch as a spare, physical access
to switches is enhanced.
</ol>
<p>
This web page lists, for each switch, the number of ports configured
in each VLAN and and the number of such ports that are inactive.  To
use it, find the switch you want, scan across to the column for the
VLAN you want, and see the total ports configured in the VLAN and the
number of those ports that are inactive (spare).  To find the actual
spare port(s), click on the switch name and manually search by VLAN
number.
<p>
EHEAD
}


sub SpareSubtable ($$$) {
  my $SwitchesRef       = shift;
  my $cut               = shift;
  my $VlanNbrSubListRef = shift;
  my $logger = get_logger('log4');
  $logger->debug("called");

  my $RetVal;
  my $StartingVlan = @$VlanNbrSubListRef[0];
  my $EndingVlan = @$VlanNbrSubListRef[$cut-1];
  $RetVal .= <<ETABLEHEAD;
<table class="Port">
<tr class="tblHead">
<th>&nbsp;Switch&nbsp;</th>
<th colspan="$cut">&nbsp;ports on VLANs $StartingVlan through $EndingVlan (total : unused) &nbsp;</th>
</tr>
<tr class="tblHead"><th>&nbsp;</th><th>
ETABLEHEAD
  $RetVal .= join '<th>', @$VlanNbrSubListRef;
  $RetVal .= "</tr>\n";

  foreach my $Switch (@$SwitchesRef) {
    my $SwitchName = GetName $Switch;
    next if $SwitchName =~ /^---/; # skip it if it's a group name
    $RetVal .= "<tr><td>&nbsp;<a href=\"../switches/$SwitchName.html\">$SwitchName</a>&nbsp;</td>";

    foreach my $VlanNbr (@$VlanNbrSubListRef) {
      my $PortTuple = '&nbsp;';
      my $Color = '';
      if (exists $Switch->{PortCountByVlan}{$VlanNbr}) {
        $PortTuple = $Switch->{PortCountByVlan}{$VlanNbr};
        my $UnusedCount = 0;
        if (exists $Switch->{UnusedPortCountByVlan}{$VlanNbr}) {
          $UnusedCount = $Switch->{UnusedPortCountByVlan}{$VlanNbr};
        }
        $Color = " class=cellWarning" if $UnusedCount == 0;
        $PortTuple .= ':' . $UnusedCount;
      }
      $RetVal .= "<td$Color>$PortTuple</td>";
    }
    $RetVal .= "</tr>\n";
  }
  $RetVal .= <<ETABLETAIL;
</table>
<p>
ETABLETAIL
  $logger->debug("returning");
  return $RetVal;
}


sub SpareTables ($$) {
  my $SwitchesRef = shift; # passed in, list of Switch objects
  my $VlansRef    = shift; # passed in, hash of Vlan objects, indexed by Vlan number
  my $logger = get_logger('log3');
  $logger->debug("called");

  my $RetVal = '';
  my $MaxVlanColumns = 20;
  my @SortedVlanNbrs = sort {$a <=> $b} keys %$VlansRef;
  while (@SortedVlanNbrs) {
    my $cut = $MaxVlanColumns;
    my $NbrSortedVlans = $#SortedVlanNbrs + 1;
    $cut = $NbrSortedVlans if $NbrSortedVlans < $MaxVlanColumns;
    $logger->debug("cut = $cut");
    my @VlanNbrSubList = splice(@SortedVlanNbrs, 0, $cut);
    $RetVal .= SpareSubtable($SwitchesRef, $cut, \@VlanNbrSubList);
  }
  $logger->debug("returning");
  return $RetVal;
}


sub WriteSparePortsFile ($$) {
  my $SwitchesRef = shift; # passed in, list of Switch objects
  my $VlansRef    = shift; # passed in, hash of Vlans indexed by Vlan number
  my $logger = get_logger('log2');
  $logger->debug("called");
  my $SparePortsFileName = File::Spec->catfile($Constants::PortsDirectory, $Constants::SparePortsFile);
  open SPAREPORTSFILE, ">$SparePortsFileName" or do {
    $logger->fatal("Couldn't open $SparePortsFileName for writing, $!");
    exit;
  };
  $logger->info("writing $SparePortsFileName");
  print SPAREPORTSFILE SwitchUtils::HtmlHeader("Spare Port Availability Report");
  print SPAREPORTSFILE SpareHeader();
  print SPAREPORTSFILE SpareTables($SwitchesRef, $VlansRef);
  print SPAREPORTSFILE SwitchUtils::HtmlTrailer();
  close SPAREPORTSFILE;
  SwitchUtils::AllowAllToReadFile $SparePortsFileName;
  $logger->debug("returning");
}


sub WritePortsIndexFile () {
  my $logger = get_logger('log3');
  my $PortsIndexFileName = File::Spec->catfile($Constants::PortsDirectory, 'index.html');
  $logger->debug("called, writing $PortsIndexFileName");

  open PORTSINDEXFILE, ">$PortsIndexFileName" or do {
    $logger->fatal("Couldn't open $PortsIndexFileName for writing, $!");
    exit;
  };
  print PORTSINDEXFILE SwitchUtils::HtmlHeader("Ports");
  print PORTSINDEXFILE <<IDX1;
<ul>
  <li><a href = "unused/index.html">Unused Ports</a></li>
  <li><a href = "$Constants::SparePortsFile">Spare Ports</a></li>
  <li><a href = "gigeportspervlan/index.html">Gigabit Ethernet Ports</a></li>
IDX1

  if ($ThisSite::HasConfRooms) {
    print PORTSINDEXFILE <<IDX2;
  <li><a href = "../conference-search/">Conference room ports</a></li>
IDX2
  }

    print PORTSINDEXFILE <<IDX3;
  <li><a href = "$Constants::PoeFile">Power-over-Ethernet Ports</a></li>
IDX3

  if ($ThisSite::DnsDomain eq '.ucar.edu') { # only if we're at NCAR
    print PORTSINDEXFILE <<IDX4;
  <li><a href = "$Constants::PortLabelAnalysisFile">Port label analysis</a></li>
  <li><a href = "$Constants::SuspiciousFile">Suspicious ports</a></li>
IDX4
  }

  print PORTSINDEXFILE <<IDX5;
</ul>
IDX5
  print PORTSINDEXFILE SwitchUtils::HtmlTrailer();
  close PORTSINDEXFILE;
  SwitchUtils::AllowAllToReadFile $PortsIndexFileName;
  $logger->debug("returning");
}


sub WritePortsDirectory ($$) {
  my $SwitchesRef = shift;   # passed in
  my $VlansRef    = shift;   # passed in
  my $logger = get_logger('log2');
  $logger->debug("called");

  SwitchUtils::SetupDirectory $Constants::PortsDirectory; # create or empty out the directory
  WriteUnusedDirectory::WriteUnusedDirectory($SwitchesRef, $VlansRef);
  WriteSparePortsFile($SwitchesRef, $VlansRef);
  WriteGigePerVlansDirectory::WriteGigePerVlansDirectory($SwitchesRef, $VlansRef);
  WritePoePortsFile::WritePoePortsFile($SwitchesRef);
  WriteSuspiciousPortsFile::WriteSuspiciousPortsFile($SwitchesRef) if $ThisSite::DnsDomain eq '.ucar.edu';  # if we're at NCAR
  WritePortsIndexFile();
  $logger->debug("returning");
}

1;
