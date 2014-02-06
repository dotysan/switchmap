package GetMacsFromCiscoMibs;
use strict;
use Log::Log4perl qw(get_logger);


sub getPortNameOfBif($$$$$$$) {
  my $Bif              = shift;
  my $localSession     = shift;
  my $Mac              = shift;
  my $VlanNbr          = shift;
  my $Switch           = shift;
  my $BifNbrToIfNbrRef = shift;
  my $IfToIfNameRef    = shift;
  my $logger = get_logger('log7');
  $logger->debug("called");
  $logger->debug("Mac = \"$Mac\", Bif = \"$Bif\"");
  return '' if $Bif == 0; # dunno what this Bif is, but it seems bogus

  # In Cisco Catalyst IOS version 7.6(1), there was a bug: when doing
  # GETNEXTs to get the dot1dBasePortIfIndex table, the returned table
  # was incomplete.  For a given bridge interface number, there may be
  # no mapping to a mib-2 ifEntry.  If this happens, do an explicit
  # GET on the dot1dBasePortIfIndex table using the bridge ifIndex.
  # The GET will work even though the GETNEXT failed.

  if ((!exists $BifNbrToIfNbrRef->{$Bif}) and ($Switch->GetChassisModel !~ /1912C/)) {
    $logger->debug("Bif $Bif doesn't exist in BifNbrToIfNbr, trying the hack");
    my $ValueOid = $Constants::SnmpOids{dot1dBasePortIfIndex} . '.' . $Bif;
    my $result = $localSession->get_request(-varbindlist => [$ValueOid]);
    if ((defined $result) and
        ($result->{$ValueOid} ne 'noSuchObject') and
        ($result->{$ValueOid} ne 'noSuchInstance')) {
      $BifNbrToIfNbrRef->{$Bif} = $result->{$ValueOid};
    }
  }

  # It should exist now.
  if (!exists $BifNbrToIfNbrRef->{$Bif}) {
    # It may be one of 4 weird numbers that show up sometimes.  The weird
    # numbers occur consistently on several different switches, so they are
    # something special.  Perhaps they relate to the 4 reserved VLAN
    # numbers that occur in Cisco switches.  Anyway, if it's not one of the
    # weird numbers, complain.
    if (($Bif != 897) and
        ($Bif != 961) and
        ($Bif != 1793) and
        ($Bif != 1921)) {
      $logger->warn("Warning: $Switch->{Name}, vlan $VlanNbr, MAC $Mac has bridge interface $Bif, which has no ifIndex, skipping this MAC");
    }
    return '';
  }

  my $IfNbr = $BifNbrToIfNbrRef->{$Bif};
  if (!exists $$IfToIfNameRef{$IfNbr}) {
    my $SwitchName = GetName $Switch;
    $logger->warn("Warning: no interface name for SNMP ifIndex $IfNbr on $SwitchName, skipping $Mac");
    return '';
  }
  my $PortName = $$IfToIfNameRef{$IfNbr};
  $logger->debug("returning PortName = \"$PortName\"");
  return $PortName;
}


sub GetOneVlanBridgeTable ($$$$$$) {
  my $localSession              = shift;
  my $Switch                    = shift;
  my $VlanNbr                   = shift;
  my $IfToIfNameRef             = shift;
  my $PortsRef                  = shift;
  my $IfNbrsThatAreSwitchingRef = shift;
  my $logger = get_logger('log7');
  $logger->debug("called");

  my $status;

#
# Jorg Spatschil sent email asking me to add code to SwitchMap to
# support switches that use VTP.  I added the following code as a
# start, to learn if any of our switches do VTP.  It revealed that
# only our 4 Nexus switches have the vtpVlanState table, and the
# tables are empty.  I told Jorg about it in an email, and left this
# fragment in place in SwitchMap version 13.0 in case Jorg or I pursue
# supporting switches that run VTP.  It's disabled for now.
#
  my $AddingVtpSupport = 1;
  if ($AddingVtpSupport) {
    $logger->info("for debugging: see if we can get the vtpVlanState table");
    my %vtpVlanState;
    $status = SwitchUtils::GetSnmpTable($localSession, # SNMP session
                                        'vtpVlanState', # table name
                                        $Constants::INTERFACE, # table type
                                        \%vtpVlanState); # returned table contents
    if ($status != $Constants::SUCCESS) {
      my $SwitchName = GetName $Switch;
      $logger->info("for debugging: got the vtpVlanState table for switch $SwitchName");
      SwitchUtils::DbgPrintHash('vtpVlanState', \%vtpVlanState);
    }
  }


  $logger->info("getting MAC info for vlan $VlanNbr");
  #
  # Get the table that maps bridge interface numbers to ifEntry
  # numbers.
  #
  my %BifNbrToIfNbr;
  # $localSession->debug(DEBUG_ALL);
  $status = SwitchUtils::GetSnmpTable($localSession,                    # SNMP session
                                      'dot1dBasePortIfIndex',           # table name
                                      $Constants::INTERFACE,            # table type
                                      \%BifNbrToIfNbr);                 # returned table contents
  # $localSession->debug(DEBUG_NONE);
  if ($status != $Constants::SUCCESS) {
    if ($VlanNbr != 1) {
      $logger->warn("$Switch->{FullName}: couldn't get dot1dBasePortIfIndex table for VLAN $VlanNbr");
      $logger->warn("$Switch->{FullName}: ...perhaps VLAN $VlanNbr is assigned to a port, but is not defined.");
    }
    # Here we choose to return WARNING instead of FAILURE, because it's not a fatal error if
    # an undefined VLAN is assigned to a port.  If we return FAILURE, we'd stop the program
    # from trying to process the other VLANs on the switch.
    return $Constants::WARNING;
  }

#  SwitchUtils::DbgPrintHash('BifNbrToIfNbr', \%BifNbrToIfNbr);
  my $NbrDot1dBasePortIfIndex = keys %BifNbrToIfNbr;
  $logger->debug("$Switch->{FullName}: got the dot1dBasePortIfIndex table for VLAN $VlanNbr, containing $NbrDot1dBasePortIfIndex values");
  foreach my $BifNbr (keys %BifNbrToIfNbr) {
    #      $logger->debug("\%BifNbrToIfNbr{$BifNbr} = \"$BifNbrToIfNbr{$BifNbr}\"");
    $IfNbrsThatAreSwitchingRef->{$BifNbrToIfNbr{$BifNbr}}++;
  }
  my $NbrIfNbrsThatAreSwitching = keys %$IfNbrsThatAreSwitchingRef;
  $logger->debug("$Switch->{FullName}: updated IfNbrsThatAreSwitchingRef hash, it now contains $NbrIfNbrsThatAreSwitching values");

  #
  # Get the bridge table for this VLAN.  In the returned hash, the
  # key is a MAC address and the value is a bridge interface number.
  #
  my %MacToBifNbr;
  $status = SwitchUtils::GetSnmpTable($localSession,                       # SNMP session
                                      'dot1dTpFdbPort',                    # table name
                                      $Constants::MAC_ADDRESS,             # table type
                                      \%MacToBifNbr);                      # returned table contents
  # yes, we're ignoring the returned status here
  # SwitchUtils::DbgPrintHash('MacToBifNbr', \%MacToBifNbr);
  my $NbrDotTpFdbPort = keys %MacToBifNbr;
  $logger->debug("$Switch->{FullName}: got the dot1dTpFdbPort table (MACs) for VLAN $VlanNbr, containing $NbrDotTpFdbPort values");

  #
  # We have the bridge table in %MacToBifNbr.  For each entry in the
  # table, call Port->AddMac.  This loop takes care of mapping the
  # bridge interface numbers into an SNMP mib-2 ifEntry number.
  #
  foreach my $Mac (keys %MacToBifNbr) {
    my $PortName = getPortNameOfBif($MacToBifNbr{$Mac}, $localSession, $Mac, $VlanNbr, $Switch, \%BifNbrToIfNbr, $IfToIfNameRef);
    next if $PortName eq '';

    #
    # Gigabit Ethernet ports which are part of an Etherchannel have
    # interface names like "GEC-9/14,10/14", which means the
    # etherchannel ports are 9/14 and 10/14.  Similarly, FastEthernet
    # ports that are part of an Etherchannel have interface names like
    # "FEC-9/14,10/14".  We handle those specially here.
    #
    if ($PortName =~ /^(F|G)EC-([0-9\/,]+)/) {
      foreach my $PName (split ',', $2) {
        my $Port = $$PortsRef{$PName};
        if (!exists $Switch->{IfMacs}{$Mac}) {   # if it's not one of the switch's own MACs
          $logger->debug("Adding $Mac to Port->{Mac} hash for etherchannel port $PortName");
          $Port->AddMac($Mac);
        }
      }
    } else {
      if ($PortName =~ /,/) {
        $logger->warn("unexpected comma in port name, switch $Switch->{Name}, vlan $VlanNbr, PortName \"$PortName\"");
      }
    }

    my $Port = $$PortsRef{$PortName};
    if (!exists $Switch->{IfMacs}{$Mac}) {   # if it's not one of the switch's own MACs
      $logger->debug("Adding $Mac to Port->{Mac} hash for port $PortName");
      $Port->AddMac($Mac);
    }
  }
  $logger->debug("returning");
  return $Constants::SUCCESS;
}


#
# Devices that support the standard bridge MIB (RFC4188) allow SNMP
# applications to download the device's bridge table.  Cisco switches
# support the MIB, but if the switch is configured with VLANs, there's
# a twist.  If the switch is configured with VLANs, you can't get the
# bridge table with one simple SNMP "getnext" loop.  Instead, you have
# to do multiple getnext loops, one for each VLAN.  Each time, to tell
# the switch which bridge table you want, you must append the VLAN
# number to the community string.  Cisco calls this "community string
# indexing".  See
#
# http://www.cisco.com/en/US/customer/tech/tk648/tk362/technologies_tech_note09186a00801576ff.shtml
#
# That URL applies to high-end switches.  For low-end switches like
# 1900-2820, the community string is defined as described in this
# fragment of an email from a Cisco engineer:
#
#   If you configured the switch with a read community as "pete".
#   Then polling dot1dTpFdbPort via SNMP using "pete" will only give
#   you VLAN 1 stats.  If you want to poll dot1dTpFdbPort for VLAN 6,
#   then you need to change the community string to "pete6" in your
#   snmpwalk command.
#
# In Foundry switches, the comment for the deprecated
# snMacStationVLanId variable describes a different strategy - before
# reading the standard dot1dTpFdbTable table, you use a SNMP SET to
# set the snMacStationVLanId to the VLAN you want.  Not sure yet if it
# works - it's deprecated and it requires SNMP write access to the
# switch.  The comment recommends using the VLAN-aware dot1qTpFdbTable
# described in RFC 2674 instead of snMacStationVLanId.
#
sub GetVlanCommunity ($$) {
  my $Switch  = shift;
  my $VlanNbr = shift;
  my $VlanCommunity = $Switch->{SnmpCommunityString};
  if ($Switch->{ChassisModel} !~ /1912C/) {
    $VlanCommunity .= "\@";
  }
  $VlanCommunity .= $VlanNbr;
  return $VlanCommunity;
}


sub GetOneVlanBridgeTableWithLocalSession ($$$$$) {
  my $Switch                    = shift;
  my $VlanNbr                   = shift;
  my $IfToIfNameRef             = shift;
  my $PortsRef                  = shift;
  my $IfNbrsThatAreSwitchingRef = shift;
  my $logger = get_logger('log6');
  $logger->debug("called");

  #
  # SNMP communities are per-VLAN, so we need an SNMP session for each
  # VLAN
  my $VlanCommunity = GetVlanCommunity($Switch, $VlanNbr);
  $logger->debug("opening a per-VLAN SNMP session to $Switch->{FullName} for VLAN $VlanNbr...");
  my ($localSession, $Error) = Net::SNMP->session(
                                                   -version    => 'snmpv2c',
                                                   -timeout    => 5,
                                                   -hostname   => $Switch->{FullName},
                                                   -community  => $VlanCommunity,
                                                   -maxmsgsize => 5000,
                                                   -translate  => [-octetstring => 0x0]
                                                  );
  if (!$localSession) {
    $logger->warn("couldn't open SNMP session to $Switch->FullName for VLAN $VlanNbr: $Error");
    return $Constants::FAILURE;
  }

  my $status = GetOneVlanBridgeTable($localSession, $Switch, $VlanNbr, $IfToIfNameRef, $PortsRef, $IfNbrsThatAreSwitchingRef);

  $localSession->close();
  $logger->debug("returning success");
  return $status;
}


sub GetMacsFromCiscoBridgeMibs ($$$$) {
  my $Switch                    = shift;
  my $IfToIfNameRef             = shift;
  my $PortsRef                  = shift;
  my $IfNbrsThatAreSwitchingRef = shift;
  my $logger = get_logger('log5');

  $logger->debug("called");
  foreach my $VNbr (Portically::PortSort keys %{$Switch->{Vlans}}) {
    my $status = GetOneVlanBridgeTableWithLocalSession($Switch, $VNbr, $IfToIfNameRef, $PortsRef, $IfNbrsThatAreSwitchingRef);
    if ($status == $Constants::FAILURE) {
      $logger->debug("Error trying to get the bridge table for VLAN $VNbr, returning failure");
      return $Constants::FAILURE;
    }
  }

  $logger->debug("returning success");
  return $Constants::SUCCESS;
}


sub GetMacsFromCiscoMibs($$$) {
  my $Switch         = shift;
  my $IfToIfNameRef  = shift;
  my $PortsRef       = shift;
  my $logger = get_logger('log5');
  $logger->debug("called");
  #
  # Get the MAC addresses from bridge (CAM) tables.
  #
  my %IfNbrsThatAreSwitching;
  my $status = GetMacsFromCiscoBridgeMibs($Switch, $IfToIfNameRef, $PortsRef, \%IfNbrsThatAreSwitching);

  foreach my $PortName (keys %{$Switch->{Ports}}) {
    my $Port = $Switch->{Ports}{$PortName};
    if ((exists $IfNbrsThatAreSwitching{$Port->{IfNbr}}) or $Port->{IsTrunking}) {
      $Port->{IsSwitching} = 1;
    }
  }
  $logger->debug("returning at bottom");
}

1;
