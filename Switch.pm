package Switch;

use strict;
use Log::Log4perl qw(get_logger);
use Portically;
#use Data::Dumper;
use PopulateEtherChannels;
use ModuleList;
use PopulatePorts;


sub new {
  my $type = shift;
  my $name = shift;
  my $logger = get_logger('log3');
  $logger->debug("called");

  my $this = {};
  my $ShortName = $name;
  $ShortName =~ s/$ThisSite::DnsDomain//;         # remove the trailing DNS domain
  $this->{ChassisModel}          = 'unknown';
  $this->{EtherChannels}         = {};            # hash of EtherChannel objects, keys are IfIndexes of parent ports
  $this->{FullName}              = $name;
  $this->{HasStackMIB}           = $Constants::FALSE;
  $this->{IfMacs}                = {};            # keys are MAC addresses of the ports, values are meaningless
  $this->{ModuleList}            = 0;
  $this->{Name}                  = $ShortName;
  $this->{NbrModules}            = 0;             # 3524s and 1912Cs don't have modules, all others at NCAR do
  $this->{NbrUnusedPorts}        = 0;
  $this->{PortCountByVlan}       = {};            # keys are Vlan numbers
  $this->{PortsByIfNbr}          = {};            # keys are ifIndexes
  $this->{Ports}                 = {};            # keys are port names
  $this->{ProductDescription}    = 'unknown';
  $this->{ProductName}           = 'unknown';
  $this->{SnmpCommunityString}   = '';
  $this->{SnmpSysContact}        = 'unknown';
  $this->{SnmpSysDescr}          = '';
  $this->{SnmpSysLocation}       = 'unknown';
  $this->{SnmpSysName}           = 'unknown';
  $this->{SnmpSysObjectId}       = '';
  $this->{UnusedPortCountByVlan} = {};            # keys are Vlan numbers
  $this->{Vlans}                 = {};            # keys are Vlan numbers, values are the number of ports in the Vlan
  $this->{SnmpSysUptime}         = '';

  $logger->debug("returning");
  return bless $this;
}


sub GetName {
  my $this = shift;
  return $this->{Name};
}


sub GetChassisModel {
  my $this = shift;
  return $this->{ChassisModel};
}


sub GetSysDescription {
  my $this = shift;
  return $this->{SnmpSysDescr};
}


sub GetContact {
  my $this = shift;
  return $this->{SnmpSysContact};
}


sub GetSysName {
  my $this = shift;
  return $this->{SnmpSysName};
}


sub GetLocation {
  my $this = shift;
  return $this->{SnmpSysLocation};
}


sub GetProductName {
  my $this = shift;
  return $this->{ProductName};
}


sub GetProductDescription {
  my $this = shift;
  return $this->{ProductDescription};
}


sub GetPrintableModules {
  my $this = shift;
  return $this->{ModuleList}->GetPrintableModuleList;
}


sub GetSysUptime {
  my $this = shift;
  return $this->{SnmpSysUptime};
}


sub GetChassisModelFromCiscoStackMib($$$) {
  my $this            = shift;
  my $Session         = shift;
  my $chassisModelRef = shift;
  my $logger = get_logger('log4');
  $logger->debug("called");

  my $cName = '';
  my $status = SwitchUtils::GetOneOidValue($Session,
                                           'chassisModel',
                                           \$cName);
  if ($status == $Constants::SUCCESS) {
    $this->{HasStackMIB} = $Constants::TRUE;
    if ($cName eq '') {
      $$chassisModelRef = $this->{ProductName};
    } else {
      $$chassisModelRef = 'Cisco ' . $cName;
    }
  } else {
    $this->{HasStackMIB} = $Constants::FALSE;
  }

  $logger->debug("returning");
}


sub GetChassisModelFromEntityMib($$) {
  my $Session         = shift;
  my $chassisModelRef = shift;
  my $logger = get_logger('log4');
  $logger->debug("called");

  # This SNMP GET assumes that the first entry in the Entity MIB will
  # be the chassis itself, which is probably a bad assumption, but it
  # works for 3524s.
  my $FirstEntPhysicalClass;
  my $status = SwitchUtils::GetOneOidValue($Session,
                                        'entPhysicalClass',
                                        \$FirstEntPhysicalClass);
  if ($status == $Constants::SUCCESS) { # if it has the Entity MIB
    if ($FirstEntPhysicalClass eq $Constants::CHASSIS) {
      $status = SwitchUtils::GetOneOidValue($Session,
                                            'entPhysicalModelName',
                                            $chassisModelRef);
    }
    $$chassisModelRef =~ s/^CISCO//;
    $$chassisModelRef =~ s/ +$//;   # trim trailing spaces
  }
  $logger->debug("returning");
}


sub GetChassisModelFromCiscoProductsMib($$) {
  my $sysObjectId     = shift;
  my $chassisModelRef = shift;
  my $logger = get_logger('log4');
  $logger->debug("called");

  my $cName = CiscoMibConstants::getCiscoChassisName($sysObjectId);
  if ($cName ne '') {
    $cName =~ s/^catalyst//;
    $cName =~ s/^cisco//;
    $cName =~ s/^ciscoPro//;
    $cName =~ s/^ciscosysID//;
    $cName =~ s/^wsc//;
    $cName =~ s/sysID$//;
    $$chassisModelRef = 'Cisco ' . $cName;
  }

  $logger->debug("returning");
}


sub GetChassisModelFromHpProductsMib($$) {
  my $sysObjectId     = shift;
  my $chassisModelRef = shift;
  my $logger = get_logger('log4');
  $logger->debug("called");

  my $cName = HpMibConstants::getHpDeviceName($sysObjectId);
  if ($cName ne '') {
    $$chassisModelRef = $cName;
  }

  $logger->debug("returning");
}


sub GetChassisModelFromJuniperSysDescr($$) {
  my $sysDescr        = shift;
  my $chassisModelRef = shift;
  my $logger = get_logger('log4');
  $logger->debug("called, sysDescr = \"$sysDescr\"");

  if ($sysDescr =~ /^Juniper Networks, Inc. (.+) internet router/) {
    $$chassisModelRef = 'Juniper ' . $1;
  }

  $logger->debug("returning");
}


sub GetChassisModelFromBrocadeSysDescr($$) {
  my $sysDescr        = shift;
  my $chassisModelRef = shift;
  my $logger = get_logger('log4');
  $logger->debug("called, sysDescr = \"$sysDescr\"");

  if ($sysDescr =~ /^Brocade Communications+ Systems, Inc\. (.+),/) {
    $$chassisModelRef = 'Brocade ' . $1;
  }

  $logger->debug("returning");
}


sub GetChassisModelFromFoundryMib($$) {
  my $sysObjectId     = shift;
  my $chassisModelRef = shift;
  my $logger = get_logger('log4');
  $logger->debug("called, sysObjectId = \"$sysObjectId\"");
  if (exists $Constants::FoundrySwitchObjectOids{$sysObjectId}) {
    $$chassisModelRef = $Constants::FoundrySwitchObjectOids{$sysObjectId};
  }
  $logger->debug("returning");
}


#
# Find out what type of switch it is.
#
sub GetChassisModelFromSwitch ($$) {
  my $this    = shift;
  my $Session = shift;
  my $logger = get_logger('log3');
  $logger->debug("called");

  my $chassisModel = 'unknown';
  GetChassisModelFromCiscoStackMib($this, $Session, \$chassisModel);
  if ($chassisModel eq 'unknown') {
    # The switch didn't respond, so either it's unreachable, or it's
    # slow, or it doesn't support the Cisco Stack MIB.  Assume that it
    # doesn't support the Cisco Stack MIB, and try the Entity MIB.
    $logger->info("couldn't get it from the Cisco Stack MIB, trying the Entity MIB...");
    GetChassisModelFromEntityMib($Session, \$chassisModel);
  }
  if ($chassisModel eq 'unknown') {
    # Assume that the switch it doesn't support either the Cisco Stack
    # MIB or the Entity MIB.  Some Cisco 3524s are like this, as are
    # non-Cisco switches like Foundry switches.  Try using the
    # sysOBjectID to look up the chassis model in the Cisco Products
    # MIB.
    $logger->info("couldn't get it from the Entity MIB, use the sysObjectID to look it up in the Cisco STACK and PRODUCTS lists...");
    GetChassisModelFromCiscoProductsMib($this->{SnmpSysObjectId}, \$chassisModel);
  }
  if ($chassisModel eq 'unknown') {
    # It must not be a Cisco device.  Try HP.
    $logger->info("couldn't get it from the Cisco Products MIB, trying HP...");
    GetChassisModelFromHpProductsMib($this->{SnmpSysObjectId}, \$chassisModel);
  }
  if ($chassisModel eq 'unknown') {
    # It must not be an HP device.  Assume it's a Juniper and try
    # parsing the model number out of the sysDecription.
    $logger->info("couldn't get it from the Cisco Products MIB, use the sysObjectID to parse it out of the Juniper sysDescr...");
    GetChassisModelFromJuniperSysDescr($this->{SnmpSysDescr}, \$chassisModel);
  }
  if ($chassisModel eq 'unknown') {
    # It must not be a Juniper device.  Assume it's a Brocade and try
    # parsing the model number out of the sysDecription.
   $logger->info("couldn't get a Juniper model, trying parsing a Brocade model string out of the sysDecription...");
    GetChassisModelFromBrocadeSysDescr($this->{SnmpSysDescr}, \$chassisModel);
  }
  if ($chassisModel eq 'unknown') {
   # Brocade bought Foundry in 2008.  Many "Foundry" switches have
   # sysDescr strings that start with "Brocade...", so they are
   # matched by GetChassisModelFromBrocadeSysDescr.  This next test
   # is meant to match really old (before Brocade bought Foundry)
   # Foundry switches.
   $logger->info("couldn't get a Brocade model, use the sysObjectID to look it up in the Foundry MIB...");
    GetChassisModelFromFoundryMib($this->{SnmpSysObjectId}, \$chassisModel);
  }

  $this->{ChassisModel} = $chassisModel;
  $logger->debug("returning success, type is \"$chassisModel\"");
  return $Constants::SUCCESS;
}


#
# Net::SNMP returns MAC tables as a hash with the values in binary format.
# This subroutine converts such a hash into another hash with the values
# in ASCII.
#
sub TranslateSnmpMacs {
  my $InTable = shift;
  my $OutTable = shift;
  foreach my $interface (keys %{$InTable}) {
    my $mac = unpack 'H12', $$InTable{$interface};
    next if $mac eq '';
    next if $mac eq '000000000000';
    $OutTable->{$mac}++;
  }
}


sub DbgPrintEtherchannel ($) {
  my $Switch = shift;
  my $logger = get_logger('log3');

  foreach my $ParentIfIndex (sort keys %{$Switch->{EtherChannels}}) {
    my $EtherChannel = $Switch->{EtherChannels}{$ParentIfIndex};
    my $outstring = "parent = $ParentIfIndex, children =";
    foreach my $ChildPort (@{$EtherChannel->{ChildPorts}}) {
      my $ChildName = $ChildPort->{Name};
      $outstring .= " $ChildName";
    }
    $logger->debug($outstring);
  }
}


#
# Given a switch object, do SNMP to the switch and fill in the data
# fields in the object.
#
sub PopulateSwitch ($) {
  my $this = shift;
  my $logger = get_logger('log3');
  $logger->debug("called");

  my $SwitchName = $this->{Name};
  my $Session;
  if (!SwitchUtils::OpenSnmpSession($SwitchName,                   # passed in
                                    \$Session,                     # returned
                                    \$this->{SnmpCommunityString}, # returned
                                    \$this->{SnmpSysObjectId})) {  # returned
    $logger->error("couldn't open SNMP session to $SwitchName, skipping this switch");
    return $Constants::FAILURE;
  }

  $this->{ProductName}        = MibConstants::getChassisName   ($this->{SnmpSysObjectId});
  $this->{ProductDescription} = MibConstants::getChassisComment($this->{SnmpSysObjectId});

  my $sysDescrOid    = '1.3.6.1.2.1.1.1.0';
  my $sysUptimeOid   = '1.3.6.1.2.1.1.3.0';
  my $sysContactOid  = '1.3.6.1.2.1.1.4.0';
  my $sysNameOid     = '1.3.6.1.2.1.1.5.0';
  my $sysLocationOid = '1.3.6.1.2.1.1.6.0';
  my $result = $Session->get_request(-varbindlist => [$sysDescrOid,
                                                      $sysUptimeOid,
                                                      $sysContactOid,
                                                      $sysNameOid,
                                                      $sysLocationOid]);
  if (!defined($result)) {
    $logger->warn("$SwitchName: Couldn't get the sysDescr, sysUptimeOid, sysContact, sysName and sysLocation");
    return $Constants::FAILURE;
  }
  $this->{SnmpSysDescr}    = $result->{$sysDescrOid};
  $this->{SnmpSysContact}  = $result->{$sysContactOid};
  $this->{SnmpSysName}     = $result->{$sysNameOid};
  $this->{SnmpSysLocation} = $result->{$sysLocationOid};
  $this->{SnmpSysUptime}   = $result->{$sysUptimeOid};

  $logger->debug('sysDescr = "'    . $this->{SnmpSysDescr}    . '"');
  $logger->debug('sysContact = "'  . $this->{SnmpSysContact}  . '"');
  $logger->debug('sysName = "'     . $this->{SnmpSysName}     . '"');
  $logger->debug('sysLocation = "' . $this->{SnmpSysLocation} . '"');
  $logger->debug('sysUptime = "'   . $this->{SnmpSysUptime}   . '"');

  my $status = GetChassisModelFromSwitch($this, $Session);
  if (!$status) {
    $logger->warn("Couldn't get the switch type from $SwitchName, skipping this switch");
    return $Constants::FAILURE;
  }

  #
  # When you ask a switch for the MAC addresses in a bridge table,
  # some switches will return the MAC addresses of the switch's own
  # interfaces along with the MAC addresses of the things that are
  # outside the switch.  No one is interested in the MAC addresses of
  # interfaces on the switch itself, so we have to explicitly ignore
  # them when we see them.  In order to ignore them, we have to know
  # which ones they are...
  #
  my %ifPhysAddress;
  $status = SwitchUtils::GetSnmpTable($Session,
                                      'ifPhysAddress',
                                      $Constants::INTERFACE,
                                      \%ifPhysAddress);
  if ($status == $Constants::SUCCESS) {
    TranslateSnmpMacs \%ifPhysAddress, $this->{IfMacs};
    # SwitchUtils::DbgPrintHash('IfMacs', $this->{IfMacs});
  } else {
    $logger->warn("$SwitchName: Couldn't get the ifPhysAddress table");
  }

  $this->{ModuleList} = new ModuleList;
  $this->{NbrModules} = $this->{ModuleList}->PopulateModuleList($Session);

  PopulatePorts::PopulatePorts($this, $Session);

  #
  # build $this->{PortsByIfNbr}
  #
  foreach my $PortName (keys %{$this->{Ports}}) {
    my $Port = $this->{Ports}{$PortName};
    my $IfNbr = $Port->{IfNbr};
    $logger->debug("setting \$this\{PortsByIfNbr\}\{$IfNbr\} for $PortName");
    $this->{PortsByIfNbr}{$IfNbr} = $Port;
    my $VlanNbr = $Port->{VlanNbr};
    if (defined $VlanNbr) {     # if the port is in a VLAN
      $this->{PortCountByVlan}{$VlanNbr}++;
      $this->{UnusedPortCountByVlan}{$VlanNbr}++ if $Port->{Unused};
    }
  }

  #
  # Get the etherchannel data, if the switch has etherchannels.
  #
  PopulateEtherChannels::PopulateEtherChannels($Session, $this);
#  DbgPrintEtherchannel($this);

  $Session->close;

  $logger->debug("returning success");
  return $Constants::SUCCESS;
}                               # PopulateSwitch

1;
