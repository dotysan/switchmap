package SnmpCommunities;

use strict;
use Log::Log4perl qw(get_logger);
use Constants;
use PetesUtils;
use SwitchUtils;

sub ReadCommunityFromCacheFile ($) {
  my $DeviceName = shift;       # passed in
  my $logger = get_logger('log4');
  $logger->info("ReadCommunityFromCache: called");

  my $RetVal = '';              # false
  my $CommunityFileName = File::Spec->catfile($Constants::CommunityDirectory, $DeviceName);
  if (-r $CommunityFileName) {
    $logger->debug("found cached SNMP community file for $DeviceName");
    open COMMUNITY, "<$CommunityFileName" or
      die "couldn't open cached community file for $DeviceName: $!";
    $RetVal = <COMMUNITY>;
    close COMMUNITY;
  } else {
    $logger->info("no entry for $DeviceName yet");
  }
  $RetVal = '' if !defined $RetVal;
#  $logger->info("ReadCommunityFromCache: returning \"$RetVal\"");
  $logger->info("ReadCommunityFromCache: returning");
  return $RetVal;
}


sub WriteCommunityToCacheFile ($$) {
  my $DeviceName = shift;       # passed in
  my $Community  = shift;       # passed in
  my $logger = get_logger('log4');

  # If the user has configured the $StateFileDirectory to be the same
  # as the destination directory, it's a security hole.  We don't want
  # to write a bunch of SNMP community strings into the destination
  # directory, where they can be browsed by web users.  So just
  # quietly return if this is the case.
  return if $ThisSite::StateFileDirectory eq $ThisSite::DestinationDirectory;

  # Create the directory if it doesn't already exist
  if (!-d $Constants::CommunityDirectory) {
    mkdir $Constants::CommunityDirectory or do {
      $logger->fatal("Couldn't create $Constants::CommunityDirectory, $!");
      exit;
    };
    $logger->debug("created $Constants::CommunityDirectory");
  }

  my $CommunityFileName = File::Spec->catfile($Constants::CommunityDirectory, $DeviceName);
  $logger->debug("opening file CommunityFileName = \"$CommunityFileName\" for writing");
  open COMMUNITYFILE, ">$CommunityFileName" or
    die "couldn't open cached community string file $CommunityFileName: $!";
  print COMMUNITYFILE $Community;
  close COMMUNITYFILE;
  SwitchUtils::AllowOnlyOwnerToReadFile $CommunityFileName;
  $logger->debug("returning");
}


my @SnmpCommunities;

#
# Given a list of community strings, return the optimized list.
# Optimized means that if there's a cached community string for the
# device, it appears first in the list.
#
sub PutCachedCommunityFirst($) {
  my $DeviceName = shift;
  my $logger = get_logger('log4');
  $logger->debug("called");

  my $cachedCommunity = ReadCommunityFromCacheFile $DeviceName;

  my @ReorderedCommunities = @SnmpCommunities;
  if ($cachedCommunity) {
    for (my $i=0; $i<=$#ReorderedCommunities; $i++) {
      if ($ReorderedCommunities[$i] eq $cachedCommunity) {
        # move the entry to the front of the list 
        unshift @ReorderedCommunities, splice @ReorderedCommunities, $i, 1;
        last;
      }
    }
  }
  $logger->debug("returning");
  return @ReorderedCommunities;
}


#
# The SNMP community string(s) to be used to talk to switches are
# defined by the value of $ThisSite::Community.  See ThisSite.pm for
# an explanation of the possible values.  This function takes care of
# the details, and returns an array of possible community strings to
# be used when talking to the switches.
#
sub initialize () {
  my $logger = get_logger('log1');
  $logger->debug("called");

  if ($ThisSite::CmstrFile) {  # if there's a list of communities to try
    if (($ThisSite::GetSnmpCommunitiesFromHpOpenView) and
        ($ThisSite::OpenViewHost ne 'localhost')) {
      $logger->info("Getting SNMP communities via ssh from file $ThisSite::CmstrFile on $ThisSite::OpenViewHost...");
      open COMMSTRFILE, "/usr/bin/ssh $ThisSite::SshKeyOption $ThisSite::OpenViewHost cat $ThisSite::CmstrFile |" or do {
        $logger->fatal("Couldn't read file $ThisSite::CmstrFile from host $ThisSite::OpenViewHost via ssh, $!.\n" .
                       "The file name came from \$CmstrFile in ThisSite.pm, see comments in ThisSite.pm");
        exit;
      };
    } else {
      $logger->info("reading SNMP communities from file $ThisSite::CmstrFile on local host...");
      open COMMSTRFILE, "<$ThisSite::CmstrFile" or do {
        $logger->fatal("Couldn't open $ThisSite::CmstrFile for reading, $!.\n" .
                       "The file name came from \$CmstrFile in ThisSite.pm, see comments in ThisSite.pm");
        exit;
      };
    }
    if (eof COMMSTRFILE) {
      $logger->fatal("Couldn't read $ThisSite::CmstrFile,\n" .
                     "The file name came from \$CmstrFile in ThisSite.pm, see the comments in ThisSite.pm");
      exit;
    }
    my %Cstrs;                  # used to detect duplicates
    while (<COMMSTRFILE>) {
      next if /^#/;             # skip comment lines
      /^"([^"]+)"/;             # pull out the community string
      my $cstr = $1;
      if (defined $1) {
        next if exists $Cstrs{$cstr}; # skip duplicates
        $Cstrs{$cstr}++;
        push @SnmpCommunities, $cstr;
      }
    }
    close COMMSTRFILE;
  } else {                      # not using a file
    push @SnmpCommunities, $ThisSite::Community; # so it's just a simple single community string
  }

  if ($#SnmpCommunities == -1) {
    $logger->fatal("No SNMP community strings defined.  Something about the value of\n" .
                   "\$CmstrFile and/or \$Community in ThisSite.pm isn't right.");
    exit;
  }

  #  foreach my $Comm (@SnmpCommunities) {
  #    $logger->debug("returning, candidate SNMP community string: \"$Comm\"");
  #  }
  my $NbrStrings = $#SnmpCommunities+1;
  $logger->info("got $NbrStrings SNMP community strings");
  $logger->debug("returning");
}


sub GetCommunities ($) {
  my $logger = get_logger('log3');
  my $DeviceName = shift;
  $logger->debug("called, DeviceName = \"$DeviceName\"");
  return PutCachedCommunityFirst($DeviceName);
}


# To unit-test this module, uncomment the following lines and then
# run it with "perl SnmpCommunities.pm"

 # my $opt_d = 1;
 # my $opt_i = 0;
 # my $opt_w = 0;
 # PetesUtils::InitializeLogging(0, $opt_d, $opt_i, $opt_w, $Constants::MAX_DEBUGGING_MESSAGE_DEPTH);
 # initialize();
 # foreach my $SnmpCommunity (getCommunities()) {
 #   print "Community = $SnmpCommunity\n";
 # }

1;
