package MibConstants;

use strict;
use CiscoMibConstants;
use HpMibConstants;
use Log::Log4perl qw(get_logger);

sub initialize () {
  my $logger = get_logger('log1');
  my $logger7 = get_logger('log7');
  $logger->debug("called");

  CiscoMibConstants::initialize();
  HpMibConstants::initialize();

  $logger->debug("returning");
}


sub getChassisName ($) {
  my $sysObjectID = shift;
  my $name = CiscoMibConstants::getCiscoChassisName($sysObjectID);
  if ($name eq '') {
    $name = HpMibConstants::getHpDeviceName($sysObjectID);
  }
  return $name;
}


sub getChassisComment ($) {
  my $sysObjectID = shift;
  return CiscoMibConstants::getCiscoChassisComment($sysObjectID);
}


1;
