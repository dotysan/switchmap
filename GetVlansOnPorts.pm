package GetVlansOnPorts;

use strict;
use Log::Log4perl qw(get_logger);
#use Portically;
#use Data::Dumper;


# This subroutine parses the long string which is the content of the
# vlanTrunkPortVlansEnabled OID.  It consists of a 128-byte list,
# translated to hexadecimal by Net::SNMP.  It works as follows (small
# example):
# Result from SNMP query:
# 00 00 14 80 02 80 62 (spaces added for readability, note that these numbers are in hex!)
# These hex numbers are translated to binary. Example: 14 hex = 20 dec = 00010100
# Each location set to 1 means that VLAN is active. So for the string above:
# 0      7   8      15 16      23 24      31 32      39 40      47 48      55
# 00000000   00000000   00010100   10000000   00000010   10000000   01100010
# So in this case, VLANs 19, 21, 24, 38, 40, 49, 50 and 54 are defined on the trunk.
# This subroutine transforms the hex string to a string of VLAN numbers.
# Trunks without VLANs explicitly defined on them look like 0x7ffffff (and ff until the end)
# for vlanTrunkPortVlansEnabled and like 0xffffff (and ff until the end) for 2k, 3k and 4k.
sub ParseTrunkVlanString ($$@) {
  my $VlanString                = shift;
  my $VlanCounter               = shift;
  my $portCollectionVlanNumbers = shift;
  my $logger = get_logger('log7');
  $logger->debug("called");

  $VlanString = substr($VlanString,2);     # strip off leading "0x"
  my $sixChars = substr($VlanString,0,6);
  if (($sixChars ne "7fffff") and
      ($sixChars ne "ffffff")) {
#    $logger->debug("VlanString = \"$VlanString\""); # dbg

    # split into pieces of 2 hex digits and convert to binary
    for (my $i=0; $i<256; $i+=2) {
      my $byte = hex(substr($VlanString,$i,2));
      my $mask = 128;
      for (my $j=0; $j<8; $j++) {
        if ($byte & $mask) {
          push @$portCollectionVlanNumbers, $VlanCounter + $j;
        }
        $mask = $mask >> 1; 
      }
      $VlanCounter += 8;
    }
  }
  $logger->debug("returning");
}


sub SetVlansOnOnePort {
  my $TrunkVlans = shift;       # passed in array of hashes
  my $Port       = shift;
  my $logger = get_logger('log7');
  $logger->debug("called");

  my @portCollectionVlanNumbers = ();
  for (my $portCollection=0; $portCollection<=3; $portCollection++) {
    my $portIfNbr = $Port->{IfNbr};
    my $TrunkVlan = $TrunkVlans->[$portCollection];
    my $VlanString = $TrunkVlan->{$portIfNbr};
    next if !defined $VlanString;
    next if $VlanString eq '';           # Trunks with VLANs on them can have empty $VlanStrings if no VLANs from that range are defined
    next if $VlanString =~ /@/;          # dunno why, but sometimes this has a bunch of nulls and an @ character
    next if length($VlanString) != 258;  # 258 = 256 + 2 characters for the leading "0x"
    ParseTrunkVlanString($VlanString, $portCollection*1024, \@portCollectionVlanNumbers);
  }
  if ($#portCollectionVlanNumbers != -1) {
    $Port->{VlansOnTrunk} = join(', ', @portCollectionVlanNumbers);
  }
  $logger->debug("returning");
}


sub SetVlansOnPorts {
  my $TrunkVlans = shift;   # passed in array of hashes
  my $Switch     = shift;   # the "Ports" in the Switch structure are modified by this subroutine
  my $logger = get_logger('log6');
  $logger->debug("called");

  foreach my $PortName (keys %{$Switch->{Ports}}) {
    $logger->debug("PortName = \"$PortName\"");
    my $Port = $Switch->{Ports}{$PortName};
    if ($Port->{IsTrunking}) {
      SetVlansOnOnePort($TrunkVlans, $Port);
    }
  }
  $logger->debug("returning");
}


sub GetTrunkVlans ($$@) {
  my $Session      = shift;   # passed in
  my $SwitchName   = shift;   # passed in
  my $TrunkVlans   = shift;   # array of hashes, filled by this subroutine
  my $logger = get_logger('log6');
  $logger->debug("called");

  my $status = $Constants::SUCCESS;

  my @oids = ('vlanTrunkPortVlansEnabled',
              'vlanTrunkPortVlansEnabled2k',
              'vlanTrunkPortVlansEnabled3k',
              'vlanTrunkPortVlansEnabled4k');

  $Session->translate(1);    # turn on translation into human-readable text

  for (my $portCollection=0; $portCollection<=3; $portCollection++) {
    my $oid = $oids[$portCollection];
    my $hash = {};
    my $status = SwitchUtils::GetSnmpTable($Session,
                                           $oid,
                                           $Constants::INTERFACE,
                                           $hash);
    if ($status == $Constants::SUCCESS) {
      #SwitchUtils::DbgPrintHash('TrunkVlans', $hash);
      $TrunkVlans->[$portCollection] = $hash;
    } else {
      $logger->warn("Couldn't get the $oid table from $SwitchName\n");
      last;
    }
  }

  $Session->translate(0);   # turn translation back off

  $logger->debug("returning");
  return $status;
}


sub GetVlansOnPorts ($$) {
  my $Switch  = shift;
  my $Session = shift;
  my $logger = get_logger('log5');
  $logger->debug("called");

  my @TrunkVlans; # array of hashes, each hash is indexed by ifNbr, and the values are long hex strings
  my $SwitchName = GetName $Switch;

  my $status = GetTrunkVlans($Session, $SwitchName, \@TrunkVlans);
  if ($status == $Constants::SUCCESS) {
    SetVlansOnPorts(\@TrunkVlans, $Switch);
  }
  $logger->debug("returning");
}

1;
