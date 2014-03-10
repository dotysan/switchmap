package PopulatePorts;
use strict;
#use Data::Dumper;
use Log::Log4perl qw(get_logger);
use Portically;
#use Devel::Size qw(size);
#use Net::SNMP qw(:snmp DEBUG_ALL DEBUG_NONE);
use GetCiscoPortTrunkStatuses;
use GetMacsFromCiscoMibs;
use GetMacsFromQBridgeMib;
use GetVlansOnPorts;
use Port;


# Unlike Switch.pm and Vlan.pm, this file doesn't implement a class.
# It's just a place to modularize the PopulatePorts function and all
# the code that it calls.


#
# Given a speed code that came from a MIB, return a string that's easy
# for a human to understand and is as short as possible so it fits
# nicely into narrow HTML table cells.
#
# Some 10G modules will report ifSpeeds of 4294967295.  This has been seen on
#    Cisco 6509 switches with 10 gig modules WS-X6716-10GE
#    Cisco 6509-E switches with WS-X6704-10GE modules
#    Cisco 3560E switches with 10gig transceivers
#    Cisco 3750 switches with 1 ten gig interface WS-C3750G-16TD-S
#
sub SpeedMap ($) {
  my $SpeedCode = shift;

  return 'none' if ($SpeedCode == 0);
  return 'auto' if ($SpeedCode == 1) or # autoDetect
    ($SpeedCode == 2);                  # autoDetect10100
  return '10G'  if ($SpeedCode == 10) or
    ($SpeedCode == 4294967295);

  my $GIG = 1000000000;
  my $MEG = 1000000;
  my $KILO= 1000;
  return ($SpeedCode / $GIG)  . 'G' if ($SpeedCode % $GIG)  == 0;
  return ($SpeedCode / $MEG)  . 'M' if ($SpeedCode % $MEG)  == 0;
  return ($SpeedCode / $KILO) . 'K' if ($SpeedCode % $KILO) == 0;

  return ($SpeedCode . 'bps') if ($SpeedCode < 10000);
  return ($SpeedCode / $MEG) . 'M';
}


#
# Get the speeds of all the ports.  Get the administrative speed if
# possible.  Then get the operational speed.  Convert the raw SNMP
# speed numbers and/or codes into something a human can understand.
#
sub GetPortSpeeds ($$$$$$) {
  my $Switch         = shift;   # passed in
  my $Session        = shift;   # passed in
  my $IfToIfNameRef  = shift;   # passed in
  my $PortIfIndexRef = shift;   # passed in
  my $AdminSpeedsRef = shift;   # passed in empty, filled in by this function
  my $IfSpeedsRef    = shift;   # passed in empty, filled in by this function
  my $logger = get_logger('log5');
  $logger->debug("called");

  $logger->info("getting portAdminSpeeds (administrative speeds)...");
  my %PortAdminSpeed;
  my $status = SwitchUtils::GetSnmpTable($Session,
                                         'portAdminSpeed',
                                         $Constants::PORT,
                                         \%PortAdminSpeed);
  if ($status != $Constants::SUCCESS) {
    $logger->warn("Couldn't get the portAdminSpeed table from $Switch->{Name}");
  } else {
    foreach my $PortName (keys %PortAdminSpeed) {
      if ((exists $PortIfIndexRef->{$PortName}) and ($PortIfIndexRef->{$PortName} != 0)) {
        $AdminSpeedsRef->{$IfToIfNameRef->{$PortIfIndexRef->{$PortName}}} = SpeedMap($PortAdminSpeed{$PortName});
      }
    }
  }

  $logger->info("getting ifSpeeds (operational speeds)...");
  my %ifSpeed;
  $status = SwitchUtils::GetSnmpTable($Session,
                                      'ifSpeed',
                                      $Constants::INTERFACE,
                                      \%ifSpeed);
  if ($status != $Constants::SUCCESS) { # if we couldn't reach it or it's real slow
    $logger->warn("Couldn't get the ifSpeed table from $Switch->{Name}, skipping");
    return $Constants::FAILURE;
  }
  foreach my $ifNbr (keys %ifSpeed) {
    my $ifName = $$IfToIfNameRef{$ifNbr};
    $IfSpeedsRef->{$ifName} = SpeedMap($ifSpeed{$ifNbr});
  }

  $logger->debug("returning success");
  return $Constants::SUCCESS;
}


#
# Set the Vlan field for each port.
#
sub GetPortNameToVlanTable ($$$$$) {
  my $Switch         = shift;   # passed in
  my $Session        = shift;   # passed in
  my $IfToIfNameRef  = shift;   # passed in
  my $PortIfIndexRef = shift;   # passed in
  my $VlansRef       = shift;   # passed in empty, filled by this function
  my $logger = get_logger('log5');
  $logger->debug("called");

  #
  # On switches that support the Cisco Stack MIB, like 6509s, the
  # port-to-vlan table is in the vlanPortVlan table.
  #
  $logger->info("getting port-to-VLAN mapping table from Cisco Stack MIB...");
  my %vlanPortVlan;
  my $status = SwitchUtils::GetSnmpTable($Session,
                                         'vlanPortVlan',
                                         $Constants::PORT,
                                         \%vlanPortVlan);
  if ($status == $Constants::SUCCESS) {
#    print Dumper(%vlanPortVlan);
    my $NbrPorts = keys %vlanPortVlan;
    $logger->debug("got $NbrPorts values from port-to-VLAN mapping table named vlanPortVlan");
    foreach my $PortName (keys %vlanPortVlan) {
      if ((exists $PortIfIndexRef->{$PortName}) and ($PortIfIndexRef->{$PortName} != 0)) {
        $VlansRef->{$IfToIfNameRef->{$PortIfIndexRef->{$PortName}}} = $vlanPortVlan{$PortName};
      }
    }
  } else {
    my $SwitchName = GetName $Switch;
    # If we made it to here, we couldn't reach the switch or it's real
    # slow or it doesn't do the Cisco Stack MIB.  It might be a Cisco
    # switch that doesn't support the Cisco Stack MIB, like a 3524.
    # On such switches, the port-to-vlan table is in a combination of
    # tables: trunk ports are in the vlanTrunkPortNativeVlan table in
    # the ciscoVtpMIB and non-trunk ports are in the vmVlan table in
    # the ciscoVlanMembershipMIB.  Some 3524s may support neither
    # because no trunks are configured at all.
    $logger->debug("it doesn't support the Cisco Stack MIB, trying the Cisco VTP MIB (vmVlan)");
    my %vmVlan;
    $status = SwitchUtils::GetSnmpTable($Session,
                                        'vmVlan',
                                        $Constants::INTERFACE,
                                        \%vmVlan);
    if ($status == $Constants::SUCCESS) {
      # SwitchUtils::DbgPrintHash('vmVlan', \%vmVlan);
      foreach my $ifNbr (keys %vmVlan) {
        my $PortName = $$IfToIfNameRef{$ifNbr};
        my $tmp = $vmVlan{$ifNbr};
        $logger->debug("$SwitchName: vmVlan table means I'm setting \$\$VlansRef{$PortName} to \$vmVlan{$ifNbr} = $tmp");
        $$VlansRef{$PortName} = $vmVlan{$ifNbr};
      }
    } else {
      # If we made it to here, we couldn't reach the switch or it's real
      # slow or it doesn't do the Cisco Stack MIB or Ciso VTP MIB.  Try
      # the Juniper MIBs.
      $logger->debug("it doesn't support the Cisco VTP MIB, trying the Juniper MIB (jnxExVlanPortAccessMode)");
      my %jnxExVlanPortAccessMode;
      $status = SwitchUtils::GetSnmpTable($Session,
                                          'jnxExVlanPortAccessMode',
                                          $Constants::PORT,
                                          \%jnxExVlanPortAccessMode);
      if ($status == $Constants::SUCCESS) {
        $logger->debug("it supports the Juniper VLAN MIB");

        my %jnxExVlanTag;
        $status = SwitchUtils::GetSnmpTable($Session,
                                            'jnxExVlanTag',
                                            $Constants::INTERFACE,
                                            \%jnxExVlanTag);
        if ($status == $Constants::SUCCESS) {
          $logger->debug("got the jnxExVlanTag table");
          foreach my $vlanId (sort keys %jnxExVlanTag) {
            $logger->debug("\%jnxExVlanTag{$vlanId} = \"$jnxExVlanTag{$vlanId}\"");
          }
        }

        foreach my $vlanPort (sort keys %jnxExVlanPortAccessMode) {
          my ($vlanId, $BifNbr) = split '/', $vlanPort;
          $logger->debug("   \$vlanport = \"$vlanPort\",  vlanId = $vlanId, \$BifNbr = $BifNbr");

          if (exists $$IfToIfNameRef{$BifNbr}) {
            my $PortName = $$IfToIfNameRef{$BifNbr};
            my $vlanNbr = $jnxExVlanTag{$vlanId};
            $logger->debug("   port $PortName is in VLAN $vlanNbr");
            $$VlansRef{$PortName} = $jnxExVlanTag{$vlanId};
          }
        }
      } else {
        $logger->debug("it doesn't support the Juniper MIB, proceeding without Port-to-VLAN information");
      }
    }
  }



# When I get around to fetching VLAN information from Juniper devices,
# I'll look in jnxExVlanTable, jnxExVlanInterfaceTable, and
# jnxExVlanPortGroupTable.  Or, the QBridge MIB?

#
# Perhaps of value is dot1qNumVlans.0, the number of VLANs on the
# switch.  GetPortToMac loops through all the VLANs on the switch.
# Are those contained in the Q-BRIDGE MIB?
#
# And the following also works, suggesting that maybe we can use the
# Q-BRIDGE MIB to access Ciscos as well as Foundry switches.
# snmpwalk -v 2c -c ncar-read ml-16c-c1-gs .1.3.6.1.2.1.17.7.1.1
#
# The mechanism for identifying the VLAN per port is bit maps, with
# bit set for each port that is in a VLAN.  So you get the bitmap for
# each VLAN, and loop through the bits to figure out which ports are
# in the VLAN.  So I should be able to extend GetPortToVlanTable - after
# trying the Cisco MIBs, it can access the Q-BRIDGE MIB.  Then it
# should try the Q-BRIDGE MIB first if it works for Ciscos and
# Foundrys.
#
  my $SwitchName = GetName $Switch;
  $logger->debug("testing a GET of the dot1qNumVlans");
  my $dot1qNumVlans;
  $status = SwitchUtils::GetOneOidValue($Session,
                                        'dot1qNumVlans',
                                        \$dot1qNumVlans);
  if ($status) {
    $logger->debug("GET succeeded, dot1qNumVlans = $dot1qNumVlans on switch $SwitchName");
  } else {
    $logger->debug("GET failed, couldn't get dot1qNumVlans from switch $SwitchName");
  }


# Now try to get the table of native VLAN numbers.  Then for each port
# in the table, if the native VLAN is something other than 1, override
# the VLAN number that's already been set.
  my %vlanTrunkPortNativeVlan;
  $status = SwitchUtils::GetSnmpTable($Session,
                                      'vlanTrunkPortNativeVlan',
                                      $Constants::INTERFACE,
                                      \%vlanTrunkPortNativeVlan);
  if ($status == $Constants::SUCCESS) {
    my $NbrVlans = keys %vlanTrunkPortNativeVlan;
    $logger->debug("got $NbrVlans native VLAN numbers from vlanTrunkPortNativeVlan table");
    foreach my $ifNbr (keys %vlanTrunkPortNativeVlan) {
      if ($vlanTrunkPortNativeVlan{$ifNbr} != 1) {
        my $PortName = $$IfToIfNameRef{$ifNbr};
        $$VlansRef{$PortName} = $vlanTrunkPortNativeVlan{$ifNbr};
      }
    }
  }

  #  This block of code was on attempt to make SwitchMap work on
  #  switches that don't support Cisco MIBs.  Try the Foundry MIBs...
  #
  #  $logger->debug("it doesn't support the Cisco VTP MIB, trying the Foundry MIBs");
  #  my %snSwPortVlanId;
  #  my $status = SwitchUtils::GetSnmpTable($Session,
  #                                          'snSwPortVlanId',
  #                                          $Constants::PORT,
  #                                          \%snSwPortVlanId);
  #  if ($status == $Constant::SUCCESS) {
  ##    This "worked" - the status was "success" but there was simply no returned data.  I can't explain this.
  ##    If you back aff and walk .1.3.6.1.4.1.1991.1.1.3.3, you get all the tables, including snSwPortVlanId.
  ##    Why is SNMP behaving this way?  I gave up and went after the Q-bridge MIB instead...
  #    if (%snSwPortVlanId) {
  #      $logger->fatal("got VLAN data from Foundry MIB, but code to interpret it hasn't been written yet");
  #      exit;
  #      $logger->debug("returning");
  #      return;
  #    } else {
  #      $logger->debug("Got SUCCESS from SNMP function call, but no returned data.");
  #    }
  #  }
  #
  #  If we made it to here, the switch doesn't support either Cisco or
  #  Foundry MIBs.  Try the standard Q-Bridge MIB.  (??????????)  What
  #  if it supports the MIB but is configured to use ISL trunking?
  #
  # $logger->debug("it doesn't support the Foundry MIBs, trying the standard Q-Bridge MIB");
  # my %TmpVlans;
  # GetMacsFromQBridgeMib::GetPortToVlanTableFromQBridgeMib($Switch, $Session, $IfToIfNameRef, \%TmpVlans);
  # if (%TmpVlans) {
  #   foreach my $vlan (sort keys %TmpVlans) {
  #     $logger->debug("-------------TmpVlans{$vlan} = \"$TmpVlans{$vlan}\"");
  #     $logger->fatal("got VLAN data from Q-bridge MIB, but code to interpret it hasn't been written yet");
  #     exit;
  #     $logger->debug("returning");
  #     return;
  #   }
  # }

  $logger->debug("returning");
}


#
# Set the AuxiliaryVlan field for each port.
#
sub GetPortNameToAuxiliaryVlanTable ($$$$$) {
  my $Switch            = shift;   # passed in
  my $Session           = shift;   # passed in
  my $IfToIfNameRef     = shift;   # passed in
  my $PortIfIndexRef    = shift;   # passed in
  my $PortNameToAuxiliaryVlan = shift;   # passed in empty, filled by this function
  my $logger = get_logger('log5');
  $logger->debug("called");

  #
  # On switches that support the Cisco VLAN Membership MIB, like the
  # 6509, the port-to-auxiliary-vlan table is in the vmVoiceVlanId
  # table.  Switches that don't support the Cisco Stack MIB might
  # support the Cisco 2900 MIB, in which case it's in the
  # c2900PortVoiceVlanId table.  If the switch doesn't support the
  # 2900 MIB, like the 5500 named fl2-2076-c1-es at NCAR, then the
  # switch doesn't support auxiliary VLANs at all.
  #
  $logger->info("getting port-to-auxiliary-VLAN mapping table...");
  $logger->info("trying vmVoiceVlanId...");
  my %vmVoiceVlanId;
  my $status = SwitchUtils::GetSnmpTable($Session,
                                         'vmVoiceVlanId',
                                         $Constants::INTERFACE,
                                         \%vmVoiceVlanId);
  if ($status == $Constants::SUCCESS) {
    my $NbrPorts = keys %vmVoiceVlanId;
    $logger->debug("got auxiliary VLAN info for $NbrPorts from vmVoiceVlanId from Cisco VLAN Membership MIB");
    # SwitchUtils::DbgPrintHash('vmVoiceVlanId', \%vmVoiceVlanId);
    foreach my $ifNbr (keys %vmVoiceVlanId) {
      my $PortName = $$IfToIfNameRef{$ifNbr};
      my $AuxVlan = $vmVoiceVlanId{$ifNbr};
#      $logger->debug("got vmVoiceVlanId table, setting \$\$AuxiliarysRef\{$PortName\} to $AuxVlan");
      $$PortNameToAuxiliaryVlan{$PortName} = $AuxVlan if $AuxVlan != 4096;
    }
  } else { # if we couldn't reach it or it's real slow or it doesn't do vmVoiceVlanId
    $logger->debug("no vmVoiceVlanId (no Cisco VLAN Membership MIB), trying c2900PortVoiceVlanId");
    my %c2900PortVoiceVlanId;
    $status = SwitchUtils::GetSnmpTable($Session,
                                        'c2900PortVoiceVlanId',
                                        $Constants::INTERFACE,
                                        \%c2900PortVoiceVlanId);
    if ($status == $Constants::SUCCESS) {
      my $NbrPorts = keys %c2900PortVoiceVlanId;
      $logger->debug("got auxiliary VLAN info for $NbrPorts from c2900PortVoiceVlanId from Cisco c2900 MIB");
      # SwitchUtils::DbgPrintHash('c2900PortVoiceVlanId', \%c2900PortVoiceVlanId);
      foreach my $ifNbr (keys %c2900PortVoiceVlanId) {
        my $PortName = $$IfToIfNameRef{$ifNbr};
        my $AuxVlan = $c2900PortVoiceVlanId{$ifNbr};
#        $logger->debug("got c2900PortVoiceVlanId table, setting \$\$AuxiliarysRef\{$PortName\} to $AuxVlan");
        $$PortNameToAuxiliaryVlan{$PortName} = $AuxVlan if $AuxVlan != 4096;
      }
    } else {
      $logger->debug("no Cisco 2900 MIB, we don't have any Auxiliary VLAN data.");
    }
  }
  $logger->debug("returning");
  return;
}


sub GetPortToLabel ($$$$$) {
  my $Switch         = shift;   # passed in
  my $Session        = shift;   # passed in
  my $IfToIfNameRef  = shift;   # passed in
  my $PortIfIndexRef = shift;   # passed in
  my $LabelsRef      = shift;   # passed in empty, filled by this function
  my $logger = get_logger('log5');
  $logger->debug("called");

  $logger->info("getting port-to-label mapping table...");

  # Try to get the Cisco Stack MIB 'portName' table.  6500s have it.

  my %portName;
  my $status = SwitchUtils::GetSnmpTable($Session,
                                         'portName',
                                         $Constants::PORT,
                                         \%portName);
  if ($status == $Constants::SUCCESS) { # if we got the portName table
    # 3550s have a portName table, but all the entries are empty, and
    # true port labels are found in the ifAlias table.  So use
    # $portNameValid to indicate whether the portName table has
    # non-blank entries.
    my $portNameValid = 0;
    my $count = 0;
    foreach my $PortName (keys %portName) {
      next if (!exists $PortIfIndexRef->{$PortName}) or ($PortIfIndexRef->{$PortName} == 0);
      my $pn = $portName{$PortName};
      $portNameValid = 1 if $pn ne '';
      $pn =~ s/\r//g;
      $pn =~ s/\n//g;
      $LabelsRef->{$IfToIfNameRef->{$PortIfIndexRef->{$PortName}}} = $pn;
      $count++;
    }
    if ($portNameValid) {
      $logger->debug("got $count interface labels from portname table, returning success");
      return $Constants::SUCCESS;
    }
  }

  # If we made it to here, then we couldn't reach it or it's real slow
  # or it doesn't have the portName table.  Try to get the IF MIB
  # 'ifAlias' table.  3524s and 3550s use it.

  my %ifAlias;
  $status = SwitchUtils::GetSnmpTable($Session,
                                      'ifAlias',
                                      $Constants::INTERFACE,
                                      \%ifAlias);
  if ($status == $Constants::SUCCESS) {
    my $count = 0;
    foreach my $ifNbr (keys %ifAlias) {
      my $pn = $ifAlias{$ifNbr};
      $pn =~ s/\r//g;
      $pn =~ s/\n//g;
      my $PortName = $$IfToIfNameRef{$ifNbr};
      $$LabelsRef{$PortName} = $pn;
      $count++;
    }
    $logger->debug("got $count interface labels from ifAlias table, returning success");
    return $Constants::SUCCESS;
  }

  # If we made it to here, then we couldn't reach it or it's real slow
  # or - it doesn't have the portName table and it doesn't have the
  # ifAlias table.  1900s are like this, but they support the ESSWITCH
  # MIB, which has the swPortName table.  Try it.

  my %swPortName;
  $status = SwitchUtils::GetSnmpTable($Session,
                                      'swPortName',
                                      $Constants::INTERFACE,
                                      \%swPortName);
  if ($status == $Constants::SUCCESS) {
    my $count = 0;
    foreach my $IfNbr (keys %swPortName) {
      my $pn = $swPortName{$IfNbr};
      $pn =~ s/\r//g;
      $pn =~ s/\n//g;
      my $PortName = $$IfToIfNameRef{$IfNbr};
      $$LabelsRef{$PortName} = $pn;
      $count++;
    }
    $logger->debug("got $count interface labels from swPortName table, returning success");
    return $Constants::SUCCESS;
  }

  # If we made it to here, then we couldn't reach it or it's real slow
  # or - it doesn't do portName and it doesn't do ifAlias and it
  # doesn't do swPortName.  We give up!

  $logger->warn("Couldn't get the ifAlias, portName or swPortName table from $Switch->{Name}, skipping");
  return $Constants::FAILURE;
}


sub ReadableDot3StatsDuplexStatusStrings ($) {
  my $dot3StatsDuplexStatus = shift;
  my %DuplexMapForDot3Table = (
                               1 => 'unknown',
                               2 => 'half',
                               3 => 'full'
                              );
  return '' if !exists $DuplexMapForDot3Table{$dot3StatsDuplexStatus};
  return $DuplexMapForDot3Table{$dot3StatsDuplexStatus};
}


sub ReadablePortDuplexStrings ($) {
  my $portDuplex = shift;
  my %readablePortDuplexStrings = (
                                   1 => 'half',
                                   2 => 'full',
                                   3 => 'disagree',    # this happens when autonegotiation fails
                                   4 => 'auto'
                                  );
  return '' if !exists $readablePortDuplexStrings{$portDuplex};
  return $readablePortDuplexStrings{$portDuplex};
}


sub ReadableC2900PortDuplexStateStrings ($) {
  my $c2900PortDuplexState = shift;
  my %c2900PortDuplexStateMap = (
                                 0 => 'n/a',           # not defined, but I've seen a switch return it!
                                 1 => 'full',
                                 2 => 'half',
                                 3 => 'auto'
                                );
  return '' if !exists $c2900PortDuplexStateMap{$c2900PortDuplexState};
  return $c2900PortDuplexStateMap{$c2900PortDuplexState};
}


sub ReadableC2900PortDuplexStatusStrings ($) {
  my $c2900PortDuplexStatus = shift;
  my %DuplexMapFor2900and3524 = (
                                 0 => 'n/a',           # not defined, but I've seen a switch return it!
                                 1 => 'a-full',
                                 2 => 'a-half'
                                );
  return '' if !exists $DuplexMapFor2900and3524{$c2900PortDuplexStatus};
  return $DuplexMapFor2900and3524{$c2900PortDuplexStatus};
}


sub ReadableSwPortDuplexStatus ($) {
  my $swPortDuplexStatus = shift;
  my %DuplexMapFor1900 = (
                          1 => 'full',
                          2 => 'half',
                          3 => 'full-flow'
                         );
  return '' if !exists $DuplexMapFor1900{$swPortDuplexStatus};
  return $DuplexMapFor1900{$swPortDuplexStatus};
}


sub ReadablePethPsePortDetectionStatus ($) {
  my $pethPsePortDetectionStatus = shift;
  my %PoEPortDetectionStatusStrings = (
                                       1 => 'disabled',
                                       2 => 'searching',
                                       3 => 'deliveringPower',
                                       4 => 'fault',
                                       5 => 'test',
                                       6 => 'otherFault'
                                      );
  return '' if !exists $PoEPortDetectionStatusStrings{$pethPsePortDetectionStatus};
  return $PoEPortDetectionStatusStrings{$pethPsePortDetectionStatus};
}


sub GetPoEDetectionStatuses ($$$$$) {
  my $Switch                  = shift; # passed in
  my $Session                 = shift; # passed in
  my $IfToIfNameRef           = shift; # passed in
  my $PortIfIndexRef          = shift; # passed in
  my $PoeDetectionStatusesRef = shift; # passed in empty, filled by this function
  my $logger = get_logger('log5');
  $logger->debug("called");

  my $SwitchName = GetName $Switch;
  # Get the Power-over-Ethernet table.
  my %pethPsePortDetectionStatus;
  my $status = SwitchUtils::GetSnmpTable($Session,
                                         'pethPsePortDetectionStatus',
                                         $Constants::PORT,
                                         \%pethPsePortDetectionStatus);
  if ($status == $Constants::SUCCESS) {
    $logger->debug("Power-over-Ethernet MIB found on $SwitchName");
    foreach my $PortName (Portically::PortSort keys %pethPsePortDetectionStatus) {
      my $PDStatus = $pethPsePortDetectionStatus{$PortName};
#      my $PDStatusString = ReadablePethPsePortDetectionStatus($PDStatus);
      if ((exists $PortIfIndexRef->{$PortName}) and ($PortIfIndexRef->{$PortName} != 0)) {
        $PoeDetectionStatusesRef->{$IfToIfNameRef->{$PortIfIndexRef->{$PortName}}} = $PDStatus;
      }
    }
  } else {
    $logger->debug("Power-over-Ethernet MIB not found on $SwitchName, status = $status");
  }
  $logger->debug("returning");
  return $Constants::SUCCESS;
}


sub GetPortToDuplex ($$$$$$) {
  my $Switch         = shift;   # passed in
  my $Session        = shift;   # passed in
  my $IfToIfNameRef  = shift;   # passed in
  my $PortIfIndexRef = shift;   # passed in
  my $AdminSpeedsRef = shift;   # passed in
  my $DuplexRef      = shift;   # passed in empty, filled by this function
  my $logger = get_logger('log5');
  $logger->debug("called");

#
# It would be nice if I could get duplex status from just one table,
# but Cisco stores duplex state in different places on different
# switches.  For example, the Stack MIB gives the administrative
# setting but not the operational setting, so it might give "auto",
# but not "full".  So I get multiple tables, and build strings in
# $Duplex that represent the administrative and operational duplex.
# This following logic wasn't designed, it grew as I made SwitchMap
# work for more and more switches.
#

  my $status;

  # Try to get the dot3StatsDuplexStatus table, which exists in at
  # least 3560s and 4500s.
  $logger->info("trying to get the dot3StatsDuplexStatus table from the EtherLike-MIB...");
  my %dot3StatsDuplexStatus;
  $status = SwitchUtils::GetSnmpTable($Session,
                                      'dot3StatsDuplexStatus',
                                      $Constants::INTERFACE,
                                      \%dot3StatsDuplexStatus);
  if ($status == $Constants::SUCCESS) {
    $logger->info("got dot3StatsDuplexStatus table from EtherLike-MIB.");
    foreach my $ifNbr (keys %dot3StatsDuplexStatus) {
      my $DuplexCode = $dot3StatsDuplexStatus{$ifNbr};
      my $DuplexString = ReadableDot3StatsDuplexStatusStrings($DuplexCode);
      my $PortName = $$IfToIfNameRef{$ifNbr};
#      $logger->debug("setting \$DuplexRef->{$PortName} to $DuplexString from dot3StatsDuplexStatus table");
      $DuplexRef->{$PortName} = $DuplexString if $PortName;
    }
  }

  #
  # Try to get the duplex values from the portDuplex table in the
  # Cisco Stack MIB.  This works for 6509s but not for 3524s or 1900s.
  #
  $logger->info("trying to get the port-to-duplex table from the Cisco Stack MIB...");
  my %portDuplex;
  $status = SwitchUtils::GetSnmpTable($Session,
                                      'portDuplex',
                                      $Constants::PORT,
                                      \%portDuplex);
  if ($status == $Constants::SUCCESS) {
    $logger->info("got the portDuplex table from the Stack MIB.");

    # SwitchUtils::DbgPrintHash('portDuplex', \%portDuplex);
    foreach my $PortName (keys %portDuplex) {
      my $DuplexCode = $portDuplex{$PortName};
      my $DuplexString = ReadablePortDuplexStrings($DuplexCode);
      next if (!exists $PortIfIndexRef->{$PortName}) or ($PortIfIndexRef->{$PortName} == 0);
      my $ifName = $IfToIfNameRef->{$PortIfIndexRef->{$PortName}};
#      $logger->debug("PortName = \"$PortName\", ifName = \"$ifName\", DuplexCode = \"$DuplexCode\", DuplexString = \"$DuplexString\"");
      if (($DuplexString eq 'auto') and (exists $DuplexRef->{$ifName}) and ($DuplexRef->{$ifName} eq 'half')) {
        $DuplexString = 'a-half';
      } elsif (($DuplexString eq 'auto') and (exists $DuplexRef->{$ifName}) and ($DuplexRef->{$ifName} eq 'full')) {
        $DuplexString = 'a-full';
      } elsif (($DuplexString ne 'auto') and (exists $AdminSpeedsRef->{$PortName}) and ($AdminSpeedsRef->{$PortName} eq 'auto')) {
        $DuplexString = 'a-' . $DuplexString;
      }
 #     $logger->debug("setting \$\$DuplexRef{$ifName} to $DuplexString from portDuplex table");
      $DuplexRef->{$ifName} = $DuplexString;
    }
    $logger->debug("returning");
    return $Constants::SUCCESS;
  }

  # Ok, we couldn't reach it or it's real slow or it doesn't do portDuplex.
  # Assume no stack MIB, so try the 2900 MIB.  Believe it or not, this
  # is where 3524s keep the duplex values.
  #
  # First, get the administrative duplex settings.
  $logger->info("couldn't get portDuplex, trying c2900PortDuplexState from Cisco 2900 MIB...");
  my %c2900PortDuplexState;
  $status = SwitchUtils::GetSnmpTable($Session,
                                      'c2900PortDuplexState',
                                      $Constants::INTERFACE,
                                      \%c2900PortDuplexState);
  if ($status == $Constants::SUCCESS) {
    $logger->info("got the c2900PortDuplexState table from the 2900 MIB.");
    foreach my $ifNbr (keys %c2900PortDuplexState) {
      my $DuplexCode = $c2900PortDuplexState{$ifNbr};
      my $DuplexString = ReadableC2900PortDuplexStateStrings($DuplexCode);
      my $PortName = $$IfToIfNameRef{$ifNbr};
      $DuplexRef->{$PortName} = $DuplexString;
    }

    #
    # Now that we've set the administrative string for each port, replace
    # the ones that are set to 'auto' if we can, with a more descriptive
    # string like 'a-half' or 'a-full'.
    #
    my %c2900PortDuplexStatus;
    $status = SwitchUtils::GetSnmpTable($Session,
                                        'c2900PortDuplexStatus',
                                        $Constants::INTERFACE,
                                        \%c2900PortDuplexStatus);
    if ($status == $Constants::SUCCESS) {
      $logger->info("got the c2900PortDuplexStatus table from the 2900 MIB.");
      # We can't interpret the duplex status without knowing the linkbeat status, so...
      $logger->info("getting c2900PortLinkbeatStatus from Cisco 2900 MIB...");
      my %c2900PortLinkbeatStatus;
      $status = SwitchUtils::GetSnmpTable($Session,
                                          'c2900PortLinkbeatStatus',
                                          $Constants::INTERFACE,
                                          \%c2900PortLinkbeatStatus);
      if ($status == $Constants::SUCCESS) {
        foreach my $ifNbr (keys %c2900PortDuplexStatus) {
          if ($c2900PortDuplexState{$ifNbr} == 3) {   # if it's 'auto-negotiate'
            my $DuplexCode = $c2900PortDuplexStatus{$ifNbr};
            my $DuplexString = ReadableC2900PortDuplexStatusStrings($DuplexCode);
            # 3524s report "half" duplex when a port has no "linkbeat".
            # Dunno what "linkbeat" is, really - it's not the port's link
            # state, because I have pinged a machine attached to a 3524
            # port and watched the 3524 report "nolinkbeat".  Anyway, if
            # there is no linkbeat on a port, a 3524 will report "half",
            # so to clarify things, I report that as an "unknown" duplex.
            my $NOLINKBEAT = 3;
            if ($c2900PortLinkbeatStatus{$ifNbr} == $NOLINKBEAT) {
              $DuplexString = 'unknown';
            }
            my $PortName = $$IfToIfNameRef{$ifNbr};
            $DuplexRef->{$PortName} = $DuplexString;
          }
        }
      }
    }
    $logger->debug("returning");
    return $Constants::SUCCESS;
  }

  # We couldn't reach it or it's real slow or it doesn't do portDuplex
  # or c2900PortDuplexStatus.  Ok, no stack MIB or 2900 MIB.  Try the
  # ESSWITCH MIB.  It's used by at least 1900s.
  $logger->info("couldn't get c2900PortDuplexStatus, trying swPortDuplexStatus from ESSWITCH MIB...");
  my %swPortDuplexStatus;
  $status = SwitchUtils::GetSnmpTable($Session,
                                      'swPortDuplexStatus',
                                      $Constants::INTERFACE,
                                      \%swPortDuplexStatus);
  if ($status == $Constants::SUCCESS) {
    $logger->info("got swPortDuplexStatus table from the ESSWITCH MIB.");
    foreach my $ifNbr (keys %swPortDuplexStatus) {
      my $DuplexCode = $swPortDuplexStatus{$ifNbr};
      my $DuplexString = ReadableSwPortDuplexStatus($DuplexCode);
      if ($DuplexString) {
        my $PortName = $$IfToIfNameRef{$ifNbr};
        $DuplexRef->{$PortName} = $DuplexString;
      }
    }
  }

  $logger->debug("returning");
  return $Constants::SUCCESS;
}


sub GetMacsFromBridgeTables($$$$) {
  my $Switch         = shift;
  my $Session        = shift;
  my $IfToIfNameRef  = shift;
  my $PortsRef       = shift;
  my $logger = get_logger('log5');
  $logger->debug("called");

  GetMacsFromQBridgeMib::GetMacsFromQBridgeMib($Switch, $Session, $IfToIfNameRef, $PortsRef);
  GetMacsFromCiscoMibs::GetMacsFromCiscoMibs  ($Switch, $IfToIfNameRef, $PortsRef);
}


sub GetMacsFromArpCache ($$$$) {
  my $Switch        = shift;
  my $Session       = shift;
  my $IfToIfNameRef = shift;
  my $PortsRef      = shift;
  my $logger = get_logger('log5');
  $logger->debug("called");

  my $SwitchName = GetName $Switch;
  my %ipNetToMediaIfIndex;
  my $status = SwitchUtils::GetSnmpTable($Session,
                                         'ipNetToMediaIfIndex',
                                         $Constants::IP_ADDRESS,
                                         \%ipNetToMediaIfIndex);
  if ($status != $Constants::SUCCESS) {
    $logger->warn("Couldn't get ARP cache interfaces from $SwitchName, skipping\n");
    return;
  }

  my %ipNetToMediaPhysAddress;
  $status = SwitchUtils::GetSnmpTable($Session,
                                      'ipNetToMediaPhysAddress',
                                      $Constants::IP_ADDRESS,
                                      \%ipNetToMediaPhysAddress);
  if ($status != $Constants::SUCCESS) {
    $logger->warn("Couldn't get ARP physical addresses from $SwitchName, skipping\n");
    return;
  }

  #
  # Build a hash of the number of MACs we found on each interface.
  #
  my %ifIndexCounts;
  foreach my $ip (keys %ipNetToMediaIfIndex) {
    my $tmp = $ipNetToMediaIfIndex{$ip};
    $ifIndexCounts{$ipNetToMediaIfIndex{$ip}}++;
  }

  my $ArpCount = 0;
  foreach my $ip (sort keys %ipNetToMediaPhysAddress) {
    next if !exists $ipNetToMediaIfIndex{$ip};
    my $ifIndex = $ipNetToMediaIfIndex{$ip};
    next if !exists $$IfToIfNameRef{$ifIndex};
    my $PortName = $$IfToIfNameRef{$ifIndex};
    next if !exists $PortsRef->{$PortName};
    my $Port = $$PortsRef{$PortName};
    my $Mac = unpack 'H12', $ipNetToMediaPhysAddress{$ip};
    if (!exists $Switch->{IfMacs}{$Mac}) {                      # if it's not one of the switch's own MACs
      if ($ifIndexCounts{$ifIndex} <= $ThisSite::ArpMacLimit) { # if the interface doesn't have too many MACs
        $Port->AddMac($Mac);
#        $logger->debug("\$Mac = \"$Mac\"");
        $ArpCount++;
      } else {
        $Port->{ArpMacCount}++;
      }
    }
  }

  $logger->debug("returning success, got $ArpCount ARP entries");
  return $Constants::SUCCESS;
}


sub SetExplicitTrunkStatuses($) {
  my $Switch = shift;
  my $logger = get_logger('log6');
  $logger->debug("called");

  my $SwitchName = GetName $Switch;
  $logger->debug("checking switch $SwitchName");
  if (exists $ThisSite::LocalSwitchTrunkPorts{$SwitchName}) {
    my $numberPorts = $#{ $ThisSite::LocalSwitchTrunkPorts{$SwitchName} } + 1;
    $logger->debug("switch $SwitchName has $numberPorts explicit trunk ports");
    if ($numberPorts == 0) {
      $logger->warn("!!! In ThisSite.pm, in \$LocalSwitchTrunkPorts, the list of ports for switch $SwitchName is empty, skipping");
    } else {
      my $SwitchTrunkPorts = $ThisSite::LocalSwitchTrunkPorts{$SwitchName};
      foreach my $PortName (@$SwitchTrunkPorts) {
        $logger->debug("\$PortName = $PortName");
        my $Port = $Switch->{Ports}{$PortName};
        if (defined $Port) {
          $logger->debug("setting $SwitchName port $PortName as a trunk port");
          $Port->{IsTrunking} = 1;
        } else {
          $logger->warn("!!! In ThisSite.pm, in \$LocalSwitchTrunkPorts, port $PortName doesn't exist in switch $SwitchName, skipping !!!");
        }
      }
    }
  }
  $logger->debug("returning");
}


# Get the trunking status of all the ports - status will be NotTrunking,
# IslTrunking or 8021qTrunking.
#
# In a set of switches at a site, it is likely that uplink ports (the
# ports that connect core switches or that connect edge switches to
# core switches) will be trunking, and will therefore have a great
# many MAC addresses in their CAM tables.  It's annoying to actually
# see all those MAC addresses, because they aren't really bound to the
# trunk ports.  So when the SwitchMap code outputs the MAC addresses
# that are bound to ports, it treats trunk ports specially - it
# outputs "trunk port" instead of the MAC addresses.
#
# I think this idea is sound, but it assumes that SwitchMap can tell
# trunk ports from non-trunk ports.  This function makes that
# determination.
#
sub GetPortTrunkStatuses ($$$$) {
  my $Switch         = shift;
  my $Session        = shift;
  my $IfToIfNameRef  = shift;
  my $PortIfIndexRef = shift;
  my $logger = get_logger('log5');
  $logger->debug("called");

  my %jnxExVlanPortAccessMode;
  my $status = SwitchUtils::GetSnmpTable($Session,
                                         'jnxExVlanPortAccessMode',
                                         $Constants::PORT,
                                         \%jnxExVlanPortAccessMode);
  if ($status == $Constants::SUCCESS) {
#
# This part doesn't work yet - I haven't figured out how to get the
# trunk statuses out of the jnxExVlanPortAccessMode table.  So this
# code doesn't actually set the trunk status of any ports, it just
# emits debugging statements.
#
    my $ACCESS_PORT = 1;
    my $TRUNK_PORT = 2;
    foreach my $port (sort keys %jnxExVlanPortAccessMode) {
      my $portAccessMode = $jnxExVlanPortAccessMode{$port};
      my $textAccessMode = '';
      if ($portAccessMode == $ACCESS_PORT) {
        $textAccessMode = 'access';
      } elsif ($portAccessMode == $TRUNK_PORT) {
        $textAccessMode = 'trunk';
      } else {
        $logger->warn("!!! expected access mode = 1 or 2, got $portAccessMode!!!");
      }
#      $logger->debug("\$jnxExVlanPortAccessMode{$port} = $portAccessMode = $textAccessMode"); # dbg
      my ($unknown, $BifNbr) = split '/', $port;

      $logger->debug("   \$port = \"$port\", unknown part = $unknown, \$BifNbr = $BifNbr");

      if (exists $$IfToIfNameRef{$BifNbr}) {
        my $ifName = $$IfToIfNameRef{$BifNbr};
        my $ttt = ($portAccessMode == $TRUNK_PORT) ? 'trunk' : 'access';
        $logger->debug("   port $ifName is a $ttt port");
      }
    }
  } else {
    my $SwitchName = GetName $Switch;
    $logger->debug("Couldn't get jnxExVlanPortAccessMode from $SwitchName, trying Cisco MIBs\n");
    #
    # Get the trunk status of all the ports.  If the switch isn't
    # trunking (only has default VLANS) then this call won't do
    # anything.
    #
    GetCiscoPortTrunkStatuses::GetCiscoPortTrunkStatuses($Switch,
                                                         $Session,
                                                         $PortIfIndexRef,
                                                         $IfToIfNameRef);
  }

  SetExplicitTrunkStatuses($Switch);

  $logger->debug("returning");
}


#
# Set the "State" of the port.
#
sub SetState ($$$$) {
  my $Switch           = shift;
  my $IdleSinceFile    = shift;
  my $ifAdminStatusRef = shift;
  my $Port             = shift;
  my $logger = get_logger('log7');
  $logger->debug("called for port $Port->{Name}");

  my $State = 'Unknown';
  if (exists $Port->{IfNbr}) {
    my $IfNbr = $Port->{IfNbr};
    if (defined $$ifAdminStatusRef{$IfNbr}) {
      $State = 'Disabled' if $$ifAdminStatusRef{$IfNbr} == $Constants::DISABLED;
    }
  }

  if ($State ne 'Disabled') {
    if (defined $Port->{Type}) {
      if ($Port->{IdleSince} == -1) { # if no .idlesince value exists
        $logger->error("$Switch->{Name}: no idlesince data found for port $Port->{Name}, you need to run ScanSwitch.pl");
      } elsif ($Port->{IdleSince} == 0) { # 0 means the port was active last time we checked
        $State = 'Active';
      } else {
        $State = 'Inactive';
      }
    }
  }

  $Port->{State} = $State;
  $logger->debug("returning with State set to \"$State\"");
}


sub SetDaysInactive ($$) {
  my $Switch = shift;
  my $Port   = shift;
  my $logger = get_logger('log5');
  $logger->debug("called");

  my $DaysInactive = '';
  my $Unused = 0;
  if ($Port->{State} ne 'Active') {
    if ($Port->{IdleSince} == -1) {         # if no .idlesince value exists
      $DaysInactive = 'unknown';
    } else {
      my $SecondsDead = (time - $Port->{IdleSince});
      if ($SecondsDead > $Constants::SecondsPerDay) {
        $DaysInactive = int ($SecondsDead / $Constants::SecondsPerDay);
      }
      if ($SecondsDead > ($ThisSite::UnusedAfter * $Constants::SecondsPerDay)) {
        $Unused = 1;
        $Switch->{NbrUnusedPorts}++;
      }
    }
  }
  $Port->{Unused}       = $Unused;
  $Port->{DaysInactive} = $DaysInactive;
  $logger->debug("returning");
}


sub SetPortStateAndDaysInactive ($$$$) {
  my $Switch           = shift;
  my $IdleSinceFile    = shift;
  my $ifAdminStatusRef = shift;
  my $Port             = shift;

  SetState($Switch, $IdleSinceFile, $ifAdminStatusRef, $Port);
  SetDaysInactive($Switch, $Port);
}


sub SetStatesAndDaysInactive ($$$$) {
  my $Switch           = shift;
  my $IdleSinceFile    = shift;
  my $ifAdminStatusRef = shift;
  my $PortsRef         = shift;
  my $logger = get_logger('log5');
  $logger->debug("called");

  foreach my $PortName (keys %{$Switch->{Ports}}) {
    SetPortStateAndDaysInactive($Switch, $IdleSinceFile, $ifAdminStatusRef, $$PortsRef{$PortName});
  }
  $logger->debug("returning");
}


sub IsVirtualPort ($$) {
  my $PortName       = shift;
  my $PortType       = shift;
  my $logger = get_logger('log4');
  $logger->debug("called");

  my $RetVal = $Constants::FALSE;
  if ($PortName =~ /^EFXS /) {
    $RetVal = $Constants::TRUE;
  } elsif (defined $PortType) {
    my $PortType = $PortType;
    if (($PortType == 22) or    # proprietary serial
        ($PortType == 24) or    # softwareLoopback
        ($PortType == 49) or    # aal5
        ($PortType == 53) or    # propVirtual
        ($PortType == 81) or    # Digital Signal Level 0
        ($PortType == 108) or   # pppMultilinkBundle
        ($PortType == 100) or   # voice recEive and transMit
        ($PortType == 101) or   # voice Foreign Exchange Office
        ($PortType == 102) or   # voice Foreign Exchange Station
        ($PortType == 103) or   # voice encapsulation
        ($PortType == 104) or   # voice over IP encapsulation
        ($PortType == 131) or   # tunnel
        ($PortType == 134) or   # atmSubInterface
        ($PortType == 135) or   # l2vlan
        ($PortType == 161)) {   # Bridge-Aggregation

      $RetVal = $Constants::TRUE;
    }
  }
  $logger->debug("returning $RetVal");
  return $RetVal;
}


sub GetInterfaceTypes($$$$) {
  my $Switch            = shift; # passed in
  my $Session           = shift; # passed in
  my $IfToIfNameRef     = shift; # passed in
  my $interfaceTypesRef = shift; # passed in
  my $logger = get_logger('log5');
  $logger->debug("called");

  my %ifTypes;
  my $status = SwitchUtils::GetSnmpTable($Session,
                                         'ifType',
                                         $Constants::INTERFACE,
                                         \%ifTypes);
  if (!$status) {
    my $SwitchName = GetName $Switch;
    $logger->warn("Couldn't get the ifType table from $SwitchName, skipping");
  } else {
    foreach my $ifNbr (keys %ifTypes) {
      my $ifName = $$IfToIfNameRef{$ifNbr};
      my $ifType = $ifTypes{$ifNbr};
      my $ifTypeString = $Constants::ifTypeStrings{$ifType};
#      $logger->debug("setting \$interfaceTypes{$ifName} to $ifType");
      $interfaceTypesRef->{$ifName} = $ifType;
    }
  }
  $logger->debug("returning");
  return $Constants::SUCCESS;
}


sub PopulatePorts ($$) {
  my $Switch   = shift;     # passed in
  my $Session  = shift;     # passed in
  my $logger = get_logger('log4');
  $logger->debug("called");

  my $SwitchName = GetName $Switch;
  my $PortsRef = $Switch->{Ports};

  #
  # Get the tables that let us translate interface numbers to names
  # and back.
  #
  my %IfToIfName;
  my %IfNameToIf;
  my $status = SwitchUtils::GetNameTables($Session, \%IfToIfName, \%IfNameToIf);
  if (!$status) {
    $logger->warn("Couldn't get the ifName table from $SwitchName, skipping");
    return;
  }
# SwitchUtils::DbgPrintHash('IfToIfName', \%IfToIfName);  # dbg
# SwitchUtils::DbgPrintHash('IfNameToIf', \%IfNameToIf);  # dbg

  #
  # If the switch supports the Cisco Stack MIB, then we may have to
  # map the stack MIB's names (like "1/1" on 3550s) to the standard
  # MIB-II ifNames (like "Gi0/1" on 3550s).  To do this, we'll need
  # the portIfIndex table.
  #
  my %portIfIndex;
  if ($Switch->{HasStackMIB}) {
    $status = SwitchUtils::GetSnmpTable($Session,
                                        'portIfIndex',
                                        $Constants::PORT,
                                        \%portIfIndex);
    # Imran Malik reported that his ME3600 switches don't return the portIfIndex table, even
    # though they do support the STACK MIB.  So, as an experiment, just ignore the error if
    # the switch doesn't return a portIfIndex.  The rest of the code handles empty portIfIndex
    # tables, so the fix may be this simple.
    #    if ($status != $Constants::SUCCESS) { # if we couldn't reach it or it's real slow
    #      $logger->warn("Couldn't get the portIfIndex table from $Switch->{Name}, skipping");
    #      return;
    #    }
  }
  # SwitchUtils::DbgPrintHash('portIfIndex', \%portIfIndex);

  #
  # Read the idlesince file for the switch.
  #
  my %IdleSince;
  my $IdleSinceFile = File::Spec->catfile($Constants::IdleSinceDirectory, $SwitchName . '.idlesince');
  $status = SwitchUtils::ReadIdleSinceFile($IdleSinceFile, \%IdleSince);
  if ($status ne "") {
    $logger->warn($status);
    $logger->fatal("couldn't read $IdleSinceFile, you need to run ScanSwitch.pl");
    exit;
  }
  # SwitchUtils::DbgPrintHash('IdleSince', \%IdleSince);
  if (!keys %IdleSince) {
    $logger->warn("no idlesince file exists for $SwitchName, you need to run ScanSwitch.pl");
  }

  my %CdpCacheDeviceId;
  $status = SwitchUtils::GetSnmpTable($Session,
                                      'cdpCacheDeviceId',
                                      $Constants::TABLE_ROW,
                                      \%CdpCacheDeviceId);
  if ($status != $Constants::SUCCESS) {
    my $error = $Session->error();
    if ($error !~ /equested table is empty or does not exist/) {
      $logger->warn("SNMP error while trying to get the cdpCacheDeviceId table from $SwitchName: $error, skipping");
    }
  }
#    SwitchUtils::DbgPrintHash('cdpCacheDeviceId', \%CdpCacheDeviceId);

  my %CdpCachePlatform;
  $status = SwitchUtils::GetSnmpTable($Session,
                                      'cdpCachePlatform',
                                      $Constants::TABLE_ROW,
                                      \%CdpCachePlatform);
  if (($status != $Constants::SUCCESS) and
     ($Session->error() !~ /equested table is empty or does not exist/)) {
    $logger->warn("SNMP error while trying to get the cdpCachePlatform table from $SwitchName");
  }
  #  SwitchUtils::DbgPrintHash('cdpCachePlatform', \%CdpCachePlatform);

  my %cieIfDot1dBaseMappingPort;
  my ( %lldpRemSysName
    #, %lldpRemSysDesc
    #, %lldpRemChassisId
    #, %lldpRemPortId
     , %lldpRemPortDesc
     , %lldpRemManAddr
    );
  $status = SwitchUtils::GetSnmpTable($Session,
                                      'cieIfDot1dBaseMappingPort',
                                      $Constants::INTERFACE,
                                      \%cieIfDot1dBaseMappingPort);
  if ($status) {
    $status = SwitchUtils::GetSnmpTable($Session,
                                      'lldpRemSysName',
                                      $Constants::TABLE_ROW,
                                      \%lldpRemSysName);
#    SwitchUtils::DbgPrintHash('lldpRemSysName', \%lldpRemSysName);
    %lldpRemSysName= map { my $key = $_;
                               exists $lldpRemSysName{$cieIfDot1dBaseMappingPort{$key}}
                           ? ($key => $lldpRemSysName{$cieIfDot1dBaseMappingPort{$key}})
                           : ()
                         } keys %cieIfDot1dBaseMappingPort;

    $status = SwitchUtils::GetSnmpTable($Session,
                                      'lldpRemPortDesc',
                                      $Constants::TABLE_ROW,
                                      \%lldpRemPortDesc);
    %lldpRemPortDesc= map { my $key = $_;
                               exists $lldpRemPortDesc{$cieIfDot1dBaseMappingPort{$key}}
                           ? ($key => $lldpRemPortDesc{$cieIfDot1dBaseMappingPort{$key}})
                           : ()
                         } keys %cieIfDot1dBaseMappingPort;

    # any column in this table will do, since we only use the oid/index
    my $lldpRemManAddrTable= $Session->get_table($Constants::SnmpOids{'lldpRemManAddrIfSubtype'});
    %lldpRemManAddr= map { # see LLDP-MIB: we exact both the key and value out of the oid/index
        /\.(?<lldpRemLocalPortNum>\d+)\.\d+\.\d+\.\d+\.(?<lldpRemManAddr>\d+\.\d+\.\d+\.\d+)$/;
        ( $+{lldpRemLocalPortNum} => $+{lldpRemManAddr} ) } keys %{$lldpRemManAddrTable};
    # for now, we assume a single RemManAddr per local port; but beware LLDP allows many
#    SwitchUtils::DbgPrintHash('lldpRemManAddr', \%lldpRemManAddr);

    # hope it's safe to overload/rebuild %lldpRemManAddr on the fly...
    %lldpRemManAddr= map { my $key = $_;
                               exists $lldpRemManAddr{$cieIfDot1dBaseMappingPort{$key}}
                           ? ($key => $lldpRemManAddr{$cieIfDot1dBaseMappingPort{$key}})
                           : ()
                         } keys %cieIfDot1dBaseMappingPort;
#    SwitchUtils::DbgPrintHash('lldpRemManAddr', \%lldpRemManAddr);
  }

  #
  # Get the table that maps ports to VLANs.
  #
  my %portNameToVlan;
  GetPortNameToVlanTable($Switch, $Session, \%IfToIfName, \%portIfIndex, \%portNameToVlan);
#    SwitchUtils::DbgPrintHash('portNameToVlan', \%portNameToVlan); # dbg

  #
  # Get the table that maps ports to auxiliary VLANs.
  #
  my %portNameToAuxiliaryVlan;
  if (keys(%portNameToVlan) != 0) {   # if the switch has VLANs
    GetPortNameToAuxiliaryVlanTable($Switch, $Session, \%IfToIfName, \%portIfIndex, \%portNameToAuxiliaryVlan);
  }

  #
  # Get the table that maps each port name to a "name" field for the
  # port.
  #
  my %Labels;
  $status = GetPortToLabel($Switch, $Session, \%IfToIfName, \%portIfIndex, \%Labels);
  if (!$status) {
    $logger->warn("Couldn't get the port-to-label mapping table from $SwitchName, skipping");
    return;
  }

  #
  # Get the speeds.
  #
  my %AdminSpeeds;
  my %IfSpeeds;
  $status = GetPortSpeeds($Switch, $Session, \%IfToIfName, \%portIfIndex, \%AdminSpeeds, \%IfSpeeds);
  if (!$status) {
    $logger->warn("Couldn't get port speeds from $SwitchName, skipping\n");
    return;
  }
  # SwitchUtils::DbgPrintHash('AdminSpeeds', \%AdminSpeeds);
  # SwitchUtils::DbgPrintHash('IfSpeeds', \%IfSpeeds);

  #
  # Get the Power-over-Ethernet detection statuses.
  #
  my %PoEDetectionStatuses;
  $status = GetPoEDetectionStatuses($Switch, $Session, \%IfToIfName, \%portIfIndex, \%PoEDetectionStatuses);
  if (!$status) {
    $logger->warn("Couldn't get the Power-Over-Ethernet table from $SwitchName, skipping");
    return;
  }

  #
  # Get the table that maps each port name to a duplex value.
  #
  my %Duplex;
  $status = GetPortToDuplex($Switch,
                            $Session,
                            \%IfToIfName,
                            \%portIfIndex,
                            \%AdminSpeeds,
                            \%Duplex);
  if (!$status) {
    $logger->warn("Couldn't get the port-to-duplex mapping table from $SwitchName, skipping");
    return;
  }


  my %interfaceTypes;
  $status = GetInterfaceTypes($Switch,
                              $Session,
                              \%IfToIfName,
                              \%interfaceTypes);
  if (!$status) {
    $logger->warn("Couldn't get the interface types from $SwitchName, skipping");
    return;
  }


  #
  # Initialize the fields of this port.
  #
  foreach my $IfNbr (keys %IfToIfName) {
    my $PortName = $IfToIfName{$IfNbr};
    my $Port = new Port $PortName;
    $$PortsRef{$PortName} = $Port;
    $Port->{CdpCacheDeviceId}     = $CdpCacheDeviceId{$IfNbr}        if exists $CdpCacheDeviceId{$IfNbr};
    $Port->{CdpCachePlatform}     = SwitchUtils::trim($CdpCachePlatform{$IfNbr}) if exists $CdpCachePlatform{$IfNbr};
    $Port->{lldpRemSysName}       = $lldpRemSysName{$IfNbr}          if exists $lldpRemSysName{$IfNbr};
    $Port->{lldpRemPortDesc}      = $lldpRemPortDesc{$IfNbr}         if exists $lldpRemPortDesc{$IfNbr};
    $Port->{lldpRemManAddr}       = $lldpRemManAddr{$IfNbr}          if exists $lldpRemManAddr{$IfNbr};
    $Port->{Duplex}               = $Duplex{$PortName}               if exists $Duplex{$PortName};
    $Port->{IdleSince}            = $IdleSince{$PortName}            if exists $IdleSince{$PortName};
    $Port->{IfNbr}                = $IfNbr;
    $Port->{IsConnectedToIpPhone} = 1                                if $Port->{CdpCachePlatform} =~ /IP Phone/;
    $Port->{Label}                = $Labels{$PortName}               if exists $Labels{$PortName};
    $Port->{PoeStatus}            = $PoEDetectionStatuses{$PortName} if exists $PoEDetectionStatuses{$PortName};
    $Port->{Type}                 = $interfaceTypes{$PortName};
    $Port->{IsVirtual}            = IsVirtualPort($PortName, $Port->{Type});

#    $logger->debug("checking existence of \$portNomeToVlan{$PortName}"); # dbg
    if (exists $portNameToVlan{$PortName}) {
      my $VlanNbr = $portNameToVlan{$PortName};
#     $logger->debug("for port $PortName, setting the VlanNbr to $VlanNbr"); # dbg
      $Port->{VlanNbr} = $VlanNbr;
      if ($VlanNbr != 0) {
        $logger->debug("port $PortName, incrementing \$Switch\-\>\{Vlans\}\{$VlanNbr\}");
        $Switch->{Vlans}{$VlanNbr}++;
      }
#    } else {
#      $logger->debug("it didn't exist!"); # dbg
    }

    if (exists $portNameToAuxiliaryVlan{$PortName}) {
      my $AuxiliaryVlanNbr = $portNameToAuxiliaryVlan{$PortName};
      $Port->{AuxiliaryVlanNbr} = $AuxiliaryVlanNbr;
      if ($AuxiliaryVlanNbr != 0) {
        $logger->debug("port $PortName, incrementing \$Switch\-\>\{Vlans\}\{$AuxiliaryVlanNbr\}");
        $Switch->{Vlans}{$AuxiliaryVlanNbr}++;
      }
    } else {
      # let Port->{AuxiliaryVlanNbr} keep it's default value of 0
    }
  }

  GetPortTrunkStatuses($Switch, $Session, \%IfToIfName, \%portIfIndex);

  GetVlansOnPorts::GetVlansOnPorts($Switch, $Session);

  GetMacsFromBridgeTables($Switch, $Session, \%IfToIfName, $PortsRef);

  $status = GetMacsFromArpCache($Switch, $Session, \%IfToIfName, $PortsRef);

  #
  # Get the administrative status of each port, like 'Active' or 'Inactive'.
  #
  #   1.3.6.1.2.1 = iso.org.dod.internet.mgmt.mib-2
  #   2.2.1.7 = interfaces.ifTable.ifEntry.ifAdminStatus
  my %ifAdminStatus;
  $status = SwitchUtils::GetSnmpTable($Session,
                                      'ifAdminStatus',
                                      $Constants::INTERFACE,
                                      \%ifAdminStatus);
  if ($status != $Constants::SUCCESS) {
    $logger->warn("Couldn't get the ifAdminStatus table from $SwitchName, skipping");
    return;
  }

  SetStatesAndDaysInactive($Switch, $IdleSinceFile, \%ifAdminStatus, $PortsRef);

  #
  # Set the "speed" of the port.  This is the value we'll put in the
  # output HTML tables, in the "Speed" column.  If the port is active,
  # use the actual speed that the port is using.  If it's not active,
  # use the administrative speed.
  #
  foreach my $IfNbr (keys %IfToIfName) {
    my $PortName = $IfToIfName{$IfNbr};
    my $Port = $PortsRef->{$PortName};
    if ($Port->{State} eq 'Active') {
      $Port->{Speed} = $IfSpeeds{$PortName};
    } else {
      $Port->{Speed} = (exists $AdminSpeeds{$PortName}) ? $AdminSpeeds{$PortName} : 'n/a';
    }
  }

  $logger->debug("returning");
}

1;
