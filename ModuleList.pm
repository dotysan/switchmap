package ModuleList;

#
# A natural way to represent a list of modules might be as an array of
# "Module" objects.  Cisco switches store module data as a set of
# separate SNMP tables, one table for all the Names, one table for all
# the serial numbers, etc.  Each table is indexed by the module
# number.  I store module data the same way the switches do: as a set
# of arrays.  I could've done things the more intuitive way, as an
# array of module objects.  That would be easier to understand.  If I
# did it, I probably ought to represent ports the same way...  Sigh.
#

use strict;
use Log::Log4perl qw(get_logger);
#use Data::Dumper; #dbg
use feature qw(switch);


sub new {
  my $type = shift;
  my $name = shift;
  my $this = {};
  $this->{Description} = {};
  $this->{Model} = {};
  $this->{FwVersion} = {};
  $this->{HwVersion} = {};
  $this->{SwVersion} = {};
  $this->{SerialNumberString} = {};
  $this->{Role} = {};
  $this->{ModuleStatus} = {};
  return bless $this;
}


sub GetModuleDescription ($) {
  my $this   = shift;
  my $ModNbr = shift;
  return $this->{Description}{$ModNbr};
}


sub GetModuleModel ($) {
  my $this   = shift;
  my $ModNbr = shift;
  return $this->{Model}{$ModNbr};
}


sub GetPrintableModuleList ($) {
  my $this = shift;

  my $retval = "mod Description         Model                FW           HW  SW           Serial      Role      Status\n";
  foreach my $ModNbr (sort {$a <=> $b} keys %{$this->{Description}}) {
    my $type   = $this->{Description}       {$ModNbr} ? $this->{Description}       {$ModNbr} : 'n/a';
    my $model  = $this->{Model}             {$ModNbr} ? $this->{Model}             {$ModNbr} : 'n/a';
    my $fw     = $this->{FwVersion}         {$ModNbr} ? $this->{FwVersion}         {$ModNbr} : 'n/a';
    my $hw     = $this->{HwVersion}         {$ModNbr} ? $this->{HwVersion}         {$ModNbr} : 'n/a';
    my $sw     = $this->{SwVersion}         {$ModNbr} ? $this->{SwVersion}         {$ModNbr} : 'n/a';
    my $serial = $this->{SerialNumberString}{$ModNbr} ? $this->{SerialNumberString}{$ModNbr} : 'n/a';
    my $role   = $this->{Role}              {$ModNbr} ?
#                                                       $this->{Role}              {$ModNbr} : 'n/a';
                  CiscoMibConstants::getCiscoSwitchRole($this->{Role}              {$ModNbr}): 'n/a';
    my $status = $this->{ModuleStatus}      {$ModNbr} ?
#                                                       $this->{ModuleStatus}      {$ModNbr} : 'n/a';
                CiscoMibConstants::getCiscoModuleStatus($this->{ModuleStatus}      {$ModNbr}): 'n/a';
# TODO: regression test Role/ModuleStatus on any non-StackWise switch
    $retval .= sprintf("%3d %-19s %-20s %-12s %-3s %-12s %-11s %-9s %-10s\n",
      $ModNbr, $type, $model, $fw, $hw, $sw, $serial, $role, $status);
  }
  return $retval;
}


sub GetModuleHtmlStyle ($$) {
  my $this   = shift;
  my $ModNbr = shift;

  my $HtmlStyle= 'style="';
  given($this->{Description}{$ModNbr}) {
    when('StackWise master'   ) { $HtmlStyle.= 'color:#006000;font-weight:bold;'; } # bold green
    when('StackWise notMember') { $HtmlStyle.= 'color:#c0c0c0;'; } # grey
    # otherwise 'StackWise Member' normal text color (black)
  }
  given(CiscoMibConstants::getCiscoModuleStatus($this->{ModuleStatus}{$ModNbr})) {
    when('majorFault') { $HtmlStyle.= 'background-color:#ffd0d0;"'; } # red (absent stack member)
    when('minorFault') { $HtmlStyle.= 'background-color:#ffc000;"'; } # orange
    when('other'     ) { $HtmlStyle.= 'background-color:#ffff00;"'; } # yellow
    default            { $HtmlStyle.= '"'; } # otherwise ok(2) normal background color (white)
  }

  return $HtmlStyle;
}


sub WriteHtmlModuleTable ($$$) {
  my $this       = shift;
  my $SwitchName = shift;
  my $ModNbr     = shift;
  my $logger = get_logger('log3');
  $logger->debug("called, SwitchName = \"$SwitchName\", ModNbr = $ModNbr");

   my $HtmlStyle= GetModuleHtmlStyle($this, $ModNbr);

  $logger->debug("returning");
  return <<MODULE;
<hr size="5" noshade>
<p class="section-title">Module $ModNbr</p>
<center>
<table border class="Module" summary=\"Module ModNbr\">
<caption><strong>Module information</strong></caption>
<tr class="tblHead">
<th>Model</th><th>Description</th><th>Serial Number</th><th>HW</th><th>SW</th><th>FW</th>
</tr>
<tr><td colspan="6" height="2" bgcolor="black"></td></tr>
<tr>
<td $HtmlStyle>$this->{Model}{$ModNbr}</td>
<td $HtmlStyle>$this->{Description}{$ModNbr}</td>
<td $HtmlStyle>$this->{SerialNumberString}{$ModNbr}</td>
<td $HtmlStyle>$this->{HwVersion}{$ModNbr}</td>
<td $HtmlStyle>$this->{SwVersion}{$ModNbr}</td>
<td $HtmlStyle>$this->{FwVersion}{$ModNbr}</td>
</tr>
</table></center>
MODULE
}

#
# Try to get the module data from the Cisco Stack MIB.  Return either
# 0 if we couldn't get data from the Cisco Stack MIB, or a positive
# integer representing the number of modules that we got information
# about.
#
sub GetModuleDataFromStackMib ($$) {
  my $this    = shift;
  my $Session = shift;
  my $logger = get_logger('log5');
  $logger->debug("called");

  # Get the types of all the modules
  my %moduleTypes;
  my $status = SwitchUtils::GetSnmpTable($Session,
                                         'moduleType',
                                         $Constants::INTERFACE,
                                         \%moduleTypes);
  # We're intentionally ignoring the status here, it's handled by the next "if" statemont

  my $NumberModules = keys %moduleTypes;
  if ($NumberModules == 0) {    # if it has no modules
    $logger->debug("couldn't get module data from the Cisco Stack MIB, returning 0");
    return 0;
  }

  foreach my $MNbr (keys %moduleTypes) {
    my $ModuleComment = CiscoMibConstants::getCiscoModuleComment($moduleTypes{$MNbr});
    $this->{Description}{$MNbr} = ($ModuleComment eq '') ? 'unknown' : $ModuleComment;
  }

  # if Description unknown (i.e. C3750 stack), use cswSwitchInfoTable to
  # display the Role (master(1)/member(2)/notMember(3))
  # TODO: and SwPriority
  $status = SwitchUtils::GetSnmpTable($Session,
                                      'cswSwitchRole',
                                      $Constants::INTERFACE,
                                      $this->{Role});
  if ($status) {
    $logger->debug("Yay!");
    # But the CISCO-STACKWISE-MIB::cswSwitchInfoTable.cswSwitchRole doesn't
    # use the same index as the CISCO-STACK-MIB::moduleTable.moduleType so
    # we assume (dangerously or not?) that the first digit of the STACKWISE
    # entPhysicalIndex is the same as the STACK moduleIndex. This _should_
    # work because StackWise stacks never have more than 9 members/slots.
    foreach my $MNbr (keys %{$this->{Role}}) {
      # hope it's safe to adjust the indexes of the hash we're looping?
      $this->{Role}{substr($MNbr,0,1)} = delete $this->{Role}{$MNbr};
    }
    # Or...I guess we could look up the
    # CISCO-STACKWISE-MIB::cswSwitchInfoTable.cswSwitchNumCurrent
    # column and use that as the hash index instead of tweaking
    # the entPhysicalIndex. But that would require changing the
    # way SwitchUtils::GetSnmpTable() indexes the $ReturnedTable.

    foreach my $MNbr (keys %{$this->{Description}}) {
      $this->{Description}{$MNbr} = 'StackWise ' . CiscoMibConstants::getCiscoSwitchRole($this->{Role}{$MNbr})
        if $this->{Description}{$MNbr} eq 'unknown';
    }
  }

  $status = SwitchUtils::GetSnmpTable($Session,
                                      'moduleStatus',
                                      $Constants::INTERFACE,
                                      $this->{ModuleStatus});

  # Get the serial numbers of all the modules
  $status = SwitchUtils::GetSnmpTable($Session,
                                      'moduleSerialNumberString',
                                      $Constants::INTERFACE,
                                      $this->{SerialNumberString});
  if (!$status) {          # early Catalysts don't support moduleSerialNumberString
    $status = SwitchUtils::GetSnmpTable($Session,
                                        'moduleSerialNumber',
                                        $Constants::INTERFACE,
                                        $this->{SerialNumberString});
    if (!$status) {        # if we couldn't reach it or it's real slow
      $logger->warn($Session->hostname() . ": couldn't get module serial number , returning 0");
      return 0;
    }
  }

  # Some Cisco switches are fixed-configuration - they don't have
  # modules.  You would think that such switches wouldn't return any
  # values when asked for the 'module...' tables.  Unfortunately,
  # we've encountered 2960s that return 'module...' tables even though
  # they have no modules.  The sample 2960 said it had 3 modules, and
  # had somewhat good data in the first entry, but it had unprintable
  # characters in the remaining 2 entries.  So the following code
  # checks the returned tables for unprintable characters.  If they
  # are present, we assume all the module data is crap, and return 0
  # to indicate that the switch raelly doesn't have modules.
  my $ModuleTypesAreBogus = $Constants::FALSE;
  foreach my $ModNum (sort keys %{$this->{SerialNumberString}}) {
    if (${$this->{SerialNumberString}}{$ModNum} =~ s/[\x80-\xFF]//) {    # if it contains unprintable characters
      $ModuleTypesAreBogus = $Constants::TRUE;
      last;
    }
  }
  if ($ModuleTypesAreBogus) {
    $logger->debug("returning 0 module data (found bogus module data)");
    return 0;
  }

  # Get the firmware versions of all the modules
  $status = SwitchUtils::GetSnmpTable($Session,
                                      'moduleFwVersion',
                                      $Constants::INTERFACE,
                                      $this->{FwVersion});
  if (!$status) {          # if we couldn't reach it or it's real slow
    $logger->debug($Session->hostname() . ": couldn't get moduleFwVersion, returning 0");
    return 0;
  }

  # Get the models of all the modules
  $status = SwitchUtils::GetSnmpTable($Session,
                                      'moduleModel',
                                      $Constants::INTERFACE,
                                      $this->{Model});
  if (!$status) {          # if we couldn't reach it or it's real slow
    $logger->debug($Session->hostname() . ": couldn't get moduleModel, returning 0");
    return 0;
  }

  # Get the hardware versions of all the modules
  $status = SwitchUtils::GetSnmpTable($Session,
                                      'moduleHwVersion',
                                      $Constants::INTERFACE,
                                      $this->{HwVersion});
  if (!$status) {          # if we couldn't reach it or it's real slow
    $logger->debug($Session->hostname() . ": couldn't get moduleHwVersion, returning 0");
    return 0;
  }

  # Get the software versions of all the modules
  $status = SwitchUtils::GetSnmpTable($Session,
                                      'moduleSwVersion',
                                      $Constants::INTERFACE,
                                      $this->{SwVersion});
  if (!$status) {          # if we couldn't reach it or it's real slow
    $logger->debug($Session->hostname() . ": couldn't get moduleSwVersion, returning 0");
    return 0;
  }

  $logger->debug("returning success, got data for $NumberModules modules");
  return $NumberModules;
}


sub GetModuleDataFromEntityMib($$) {
  my $this    = shift;
  my $Session = shift;
  my $logger = get_logger('log5');
  $logger->debug("called");

  my %entPhysicalDescr;
  my $status = SwitchUtils::GetSnmpTable($Session,
                                         'entPhysicalDescr',
                                         $Constants::INTERFACE,
                                         \%entPhysicalDescr);
  if (!$status) {
    if ($Session->error() ne 'Requested table is empty or does not exist') {
      $logger->debug($Session->hostname() . ": couldn't get entPhysicalDescr, " . $Session->error() . ", returning 0");
      return 0;
    }
  }

  my %entPhysicalContainedIn;
  $status = SwitchUtils::GetSnmpTable($Session,
                                      'entPhysicalContainedIn',
                                      $Constants::INTERFACE,
                                      \%entPhysicalContainedIn);
  if (!$status) {          # if we couldn't reach it or it's real slow
    $logger->debug($Session->hostname() . ": couldn't get entPhysicalContainedIn, returning 0");
    return 0;
  }

  my %entPhysicalClass;
  $status = SwitchUtils::GetSnmpTable($Session,
                                      'entPhysicalClass',
                                      $Constants::INTERFACE,
                                      \%entPhysicalClass);
  if (!$status) { # if we couldn't reach it or it's real slow or it doesn't do the Entity MIB
    $logger->debug($Session->hostname() . ": couldn't get entPhysicalClass, returning 0");
    return 0;
  }

  my %entPhysicalName;
  $status = SwitchUtils::GetSnmpTable($Session,
                                      'entPhysicalName',
                                      $Constants::INTERFACE,
                                      \%entPhysicalName);
  if (!$status) {          # if we couldn't reach it or it's real slow
    $logger->debug($Session->hostname() . ": couldn't get entPhysicalName, returning 0");
    return 0;
  }

  my %entPhysicalHardwareRev;
  $status = SwitchUtils::GetSnmpTable($Session,
                                      'entPhysicalHardwareRev',
                                      $Constants::INTERFACE,
                                      \%entPhysicalHardwareRev);
  if (!$status) {          # if we couldn't reach it or it's real slow
    $logger->debug($Session->hostname() . ": couldn't get entPhysicalHardwareRev, returning 0");
    return 0;
  }

  my %entPhysicalFirmwareRev;
  $status = SwitchUtils::GetSnmpTable($Session,
                                      'entPhysicalFirmwareRev',
                                      $Constants::INTERFACE,
                                      \%entPhysicalFirmwareRev);
  if (!$status) {          # if we couldn't reach it or it's real slow
    $logger->debug($Session->hostname() . ": couldn't get entPhysicalFirmwareRev, returning 0");
    return 0;
  }

  my %entPhysicalSoftwareRev;
  $status = SwitchUtils::GetSnmpTable($Session,
                                      'entPhysicalSoftwareRev',
                                      $Constants::INTERFACE,
                                      \%entPhysicalSoftwareRev);
  if (!$status) {          # if we couldn't reach it or it's real slow
    $logger->debug($Session->hostname() . ": couldn't get entPhysicalSoftwareRev, returning 0");
    return 0;
  }

  my %entPhysicalSerialNum;
  $status = SwitchUtils::GetSnmpTable($Session,
                                      'entPhysicalSerialNum',
                                      $Constants::INTERFACE,
                                      \%entPhysicalSerialNum);
  if (!$status) {          # if we couldn't reach it or it's real slow
    $logger->debug($Session->hostname() . ": couldn't get entPhysicalSerialNum, returning 0");
    return 0;
  }

  my %cswSwitchRole;
  $status = SwitchUtils::GetSnmpTable($Session,
                                      'cswSwitchRole',
                                      $Constants::INTERFACE,
                                      \%cswSwitchRole);
  if (!$status) {          # if we couldn't reach it or it's real slow
    $logger->debug($Session->hostname() . ": couldn't get cswSwitchRole, returning 0");
    return 0;
  }
# StackWise-480 doesn't define a CISCO-STACK-MIB::moduleStatus. Non-
# members are removed from the CISCO-STACKWISE-MIB::cswSwitchInfoTable.
# So we can simply set all members to cswSwitchState=ready(4) which is
# _not_ equivalent to CISCO-STACK-MIB::moduleStatus=ok(2).
#  my %cswSwitchState;
#  $status = SwitchUtils::GetSnmpTable($Session,
#                                      'cswSwitchState',
#                                      $Constants::INTERFACE,
#                                      \%cswSwitchState);

  my %entPhysicalModelName;
  $status = SwitchUtils::GetSnmpTable($Session,
                                      'entPhysicalModelName',
                                      $Constants::INTERFACE,
                                      \%entPhysicalModelName);
  if (!$status) {          # if we couldn't reach it or it's real slow
    $logger->debug($Session->hostname() . ": couldn't get entPhysicalModelName, returning 0");
    return 0;
  }

  my %entPhysicalRows;

  my $NumberModules = 0;
  foreach my $entRowNbr (sort keys %entPhysicalClass) {
    my $Class = $entPhysicalClass{$entRowNbr};
    if ($Class != $Constants::ENTPORT &&
        $Class != $Constants::SENSOR &&
        $Class != $Constants::FAN &&
        $Class != $Constants::POWSUP &&
        $Class != $Constants::CONTAINER) {
        $logger->debug("entRowNbr:$entRowNbr $entPhysicalName{$entRowNbr}");
    }
    if ($Class == $Constants::MODULE) {
      my $Parent = $entPhysicalContainedIn{$entRowNbr};
      $logger->debug("Parent  == \"$Parent\" $entPhysicalName{$Parent}");
      if (($entPhysicalName{$Parent} =~ /^Physical Slot (\d+)$/) or
          ($entPhysicalName{$Parent} =~ /^Slot (\d+)$/)) {
        $NumberModules++;
        my $SlotNbr = $1;
        $this->{Model}{$SlotNbr}              = $entPhysicalModelName{$entRowNbr};
        $this->{Description}{$SlotNbr}        = $entPhysicalDescr{$entRowNbr};
        $this->{HwVersion}{$SlotNbr}          = ($entPhysicalHardwareRev{$entRowNbr} ne '') ?
          $entPhysicalHardwareRev{$entRowNbr} : 'unknown';
        $this->{FwVersion}{$SlotNbr}          = ($entPhysicalFirmwareRev{$entRowNbr} ne '') ?
          $entPhysicalFirmwareRev{$entRowNbr} : 'unknown';
        $this->{SwVersion}{$SlotNbr}          = ($entPhysicalSoftwareRev{$entRowNbr} ne '') ?
          $entPhysicalFirmwareRev{$entRowNbr} : 'unknown';
        $this->{SerialNumberString}{$SlotNbr} = ($entPhysicalSerialNum{$entRowNbr} ne '') ?
          $entPhysicalSerialNum{$entRowNbr} : 'unknown';
      }
      # C3850 (StackWise-480) switch stacks running IOS-XE don't appear
      # to support the enterprises.cisco.workgroup.ciscoStackMIB. So we
      # must instead glean the stack members directly from the standard
      # mib-2.entityMIB.entityMIBObjects.entityPhysical.entPhysicalTable.
      elsif ($entPhysicalName{$Parent} =~ /^Switch (\d+)$/) {
        $NumberModules++;
        my $SlotNbr = $1;
        $logger->debug("entRowNbr: $entRowNbr SlotNbr: $SlotNbr");
        $this->{Model}{$SlotNbr}              = $entPhysicalModelName{$Parent};
        $this->{Description}{$SlotNbr}        = $entPhysicalDescr{$Parent};
        $this->{HwVersion}{$SlotNbr}          = ($entPhysicalHardwareRev{$Parent} ne '') ?
          $entPhysicalHardwareRev{$Parent} : 'unknown';
        $this->{FwVersion}{$SlotNbr}          = ($entPhysicalFirmwareRev{$Parent} ne '') ?
          $entPhysicalFirmwareRev{$Parent} : 'unknown';
        $this->{SwVersion}{$SlotNbr}          = ($entPhysicalSoftwareRev{$Parent} ne '') ?
          $entPhysicalSoftwareRev{$Parent} : 'unknown';
        $this->{SerialNumberString}{$SlotNbr} = ($entPhysicalSerialNum{$Parent} ne '') ?
          $entPhysicalSerialNum{$Parent} : 'unknown';
        $this->{Role}{$SlotNbr}               = $cswSwitchRole{$Parent};
        $this->{ModuleStatus}{$SlotNbr}       = 2; # fake CISCO-STACK-MIB::moduleStatus=ok(2)
      }
    }
  }

  $logger->debug("returning success, got data for $NumberModules modules");
  return $NumberModules;
}


sub PopulateModuleList ($$) {
  my $this    = shift;
  my $Session = shift;
  my $logger = get_logger('log4');
  $logger->debug("called");

  #
  # NCAR's 6509 named l3-gw-1 contains bogus hardware version numbers
  # in the Entity MIB and correct ones in the Ciscoc Stack MIB.
  # That's why we try the Cisco Stack MIB first here, and use the
  # Entity MIB only if there's no Cisco Stack MIB.
  #
  my $NbrModules;
  $NbrModules = GetModuleDataFromStackMib($this, $Session);

  # If we got no module data from the Cisco Stack MIB, it could be because:
  #   1. the device doesn't support the Stack MIB, or
  #   2. the device has a Cisco Stack MIB that contains no module data
  #      (4500s have been known to behave this way) or
  #   3. the devices doesn't have modules
  # In any of these cases, try the Entity MIB.
  if ($NbrModules == 0) {
    $NbrModules = GetModuleDataFromEntityMib($this, $Session);
  }

# $logger->debug($this->GetPrintableModuleList);
  $logger->debug("returning, got information about $NbrModules modules");
  return $NbrModules;
}
1;
