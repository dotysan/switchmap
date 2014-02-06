package GetMacsFromQBridgeMib;
use strict;
use Log::Log4perl qw(get_logger);


# sub GetPortToVlanTableFromQBridgeMib ($$$$$) {
#   my $Switch            = shift;   # passed in
#   my $Session           = shift;   # passed in
#   my $IfToIfNameRef     = shift;   # passed in
#   my $BifNbrToIfNbrRef  = shift;   # passed in
#   my $VlansRef          = shift;   # passed in empty, filled by this function
#   my $logger = get_logger('log4');
#   $logger->debug("called");

#   # get a hash of bitfields, one for each VLAN on the switch
#   my %dot1qVlanCurrentEgressPorts = SwitchUtils::GetVlanBitFields($Session,
#                                                                   'dot1qVlanCurrentEgressPorts');
#   if (%dot1qVlanCurrentEgressPorts) {
#     $logger->debug("got dot1qVlanCurrentEgressPorts bit field from Q-BRIDGE MIB");
#     foreach my $vlan (keys %dot1qVlanCurrentEgressPorts) {
#       $logger->debug("processing vlan $vlan");
# #      $logger->debug("Size of scalar is " . size( $dot1qVlanCurrentEgressPorts{$vlan} ) . " bytes");
# #      if ($vlan == 402) {
#         for (my $bit=1; $bit<4094; $bit++) { # dbg
#           if (vec $dot1qVlanCurrentEgressPorts{$vlan}, $bit, 1) {
#             $logger->debug("bit number $bit of bit vector for vlan $vlan is on");
#           }
#         }
#  #     }
#       foreach my $ifnbr (sort keys %{$IfToIfNameRef}) {
#         my $PortName = $$IfToIfNameRef{$ifnbr};
#         $logger->debug("Portname for interface $ifnbr is \"$PortName\"");
#         if (vec $dot1qVlanCurrentEgressPorts{$vlan}, $ifnbr+1, 1) {
#           $logger->debug("setting VlansRef{$PortName} to $vlan");
#           $$VlansRef{$PortName} = $vlan;
#         }
#       }
#     }
#   } else {
#     $logger->debug("Couldn't get dot1qVlanCurrentEgressPorts from Q-bridge MIB.");
#   }
#   $logger->debug("returning");
#   return;
# }

  #
  # If the switch supports the Q-BRIDGE MIB (802.1q), use it.  I've
  # learned that to process the bitfields in the Q-BRIDGE MIB in
  # Ciscos, I need the BifNbrToIfNbr hash.  Also, there are issues of
  # endian-ness.  Anyway, Foundry switches have a 1-to-1 BifNbrToIfNbr
  # table, so it has no effect.  For some reason, I'm not getting all
  # 24+2+2 ports from the Foundry - I'm just getting 1-22.
  #
  # my %TmpVlans;
  # GetPortToVlanTableFromQBridgeMib($Switch, $localSession, $IfToIfNameRef, \%BifNbrToIfNbr, \%TmpVlans);
  # foreach my $vlan (sort keys %TmpVlans) {
  #   $logger->debug("-------------TmpVlans{$vlan} = \"$TmpVlans{$vlan}\"");
  # }


sub GetMacsFromQBridgeMib($$$$) {
  my $Switch        = shift;
  my $Session       = shift;
  my $IfToIfNameRef = shift;
  my $PortsRef      = shift;
  my $logger = get_logger('log5');
  $logger->debug("called");

  #
  # Get the table that maps bridge interface numbers to ifEntry numbers.
  #
  my %BifNbrToIfNbr;
  # $localSession->debug(DEBUG_ALL);
  my $status = SwitchUtils::GetSnmpTable($Session,               # SNMP session
                                         'dot1dBasePortIfIndex', # table name
                                         $Constants::INTERFACE,  # table type
                                         \%BifNbrToIfNbr);       # returned table contents
  # $localSession->debug(DEBUG_NONE);
  if ($status != $Constants::SUCCESS) {
    $logger->debug("returning, couldn't get dot1dBasePortIfIndex (BifNbrToIfNbr) table");
    return;
  }

#  SwitchUtils::DbgPrintHash('BifNbrToIfNbr', \%BifNbrToIfNbr);  # dbg


  my $TableName = 'dot1qTpFdbTable';
  if (!exists $Constants::SnmpOids{$TableName}) {
    $logger->fatal("Internal error: Unknown SNMP OID $TableName");
    exit;
  }
  my $TableOid = $Constants::SnmpOids{$TableName};

  my $Table = $Session->get_table($TableOid);
  if (!defined $Table) {
    $logger->debug("Couldn't get $TableName table: " . $Session->error() .
                   ", SNMP error status: " . $Session->error_status() .
                   ", SNMP error index: " . $Session->error_index);
    $logger->debug("returning");
    return;
  }

  my %ports;
  my %statuses;
  foreach my $Oid (keys %{$Table}) {
    $logger->debug("\$Oid = $Oid");
    $Oid =~/\.(\d+)\.(\d+)\.(\d+\.\d+\.\d+\.\d+\.\d+\.\d+)$/;
    my $vlanId = $2;
    my $macPattern = $3;
    my $PortOrStatus = $Table->{$Oid};
    my $tmpMacString = sprintf '%02x%02x%02x%02x%02x%02x', split(/\./, $macPattern);
    if ($1 eq '2') {            # 2 means that $PortOrStatus holds a "port number"
      my $PortNbr = $PortOrStatus;
      $logger->debug("\$1 = \"$1, vlanId = \"$vlanId\", mac = \"$tmpMacString\", Port = \"$PortNbr\"");
      $ports{$macPattern} = $PortNbr;
    } elsif ($1 eq '3') {       # 3 means that $PortOrStatus holds a "status"
      my $Status = $PortOrStatus;
      my $StatusString = '';
      if ($Status eq '1') {
        $StatusString = 'other';
        $logger->debug("unexpected 'other' status!");
      } elsif ($Status eq '2') {
        $StatusString = 'invalid';
        $logger->debug("unexpected 'invalid' status!");
      } elsif ($Status eq '3') {
        $StatusString = 'learned';
      } elsif ($Status eq '4') {
        $StatusString = 'self';
        $logger->debug("unexpected 'self' status!");
      } elsif ($Status eq '5') {
        $StatusString = 'mgmt';
        $logger->debug("unexpected 'mgmt' status!");
      } else {
        $logger->warn("illegal status!");
      }
      if ($Status eq '3') {   # 3 means 'learned'
        $logger->debug("\$1 = \"$1, vlanId = \"$vlanId\", mac = \"$tmpMacString\", Status = $StatusString");
        $statuses{$macPattern} = $Status;
      }
    }
  }

  my $SwitchName = GetName $Switch;
  foreach my $mac (keys %ports) {
    my $tmpMacString = sprintf '%02x%02x%02x%02x%02x%02x', split(/\./, $mac);
    next if !exists $statuses{$mac};
    next if $statuses{$mac} != 3; # 3 means "learned"
    my $portNbr = $ports{$mac};
    my $IfNbr = $BifNbrToIfNbr{$portNbr};
#    $logger->debug("\$mac = \"$tmpMacString, \$portNbr = $portNbr\", \$IfNbr = $IfNbr\n");  # dbg
    if (!defined $IfNbr) {
      $logger->warn("for $SwitchName, got bridge interface number $ports{$mac} for $mac, but couldn't map it to an SNMP ifIndex, skipping this MAC");
    } else {
      if (!exists $$IfToIfNameRef{$IfNbr}) {
        $logger->warn("Warning: no interface name for SNMP ifIndex $IfNbr on $SwitchName, skipping $tmpMacString");
      } else {
        my $PortName = $$IfToIfNameRef{$IfNbr};
        my $Port = $$PortsRef{$PortName};
        $logger->debug("Adding $tmpMacString to Port->{Mac} hash for port $PortName");
        $Port->AddMac($tmpMacString);
      }
    }
  }

  $logger->debug("returning at bottom");
  return;
}

1;
