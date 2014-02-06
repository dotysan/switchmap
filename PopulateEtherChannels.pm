package PopulateEtherChannels;

use strict;
use Log::Log4perl qw(get_logger);
#use Data::Dumper;
use EtherChannel;


# Populate the hash pointed to by EtherChannelsRef.
sub FillEtherChannels($$) {
  my $ifStackStatusRef = shift;
  my $Switch           = shift;
  my $logger = get_logger('log5');
  $logger->debug("called");

  my $EtherChannelsRef = $Switch->{EtherChannels};
  my $PortsByIfNbrRef  = $Switch->{PortsByIfNbr};

  foreach my $ParentChildTuple (keys %{$ifStackStatusRef}) {
    $logger->debug("ParentChildTuple = $ParentChildTuple");
    my ($ParentIfIndex, $ChildIfIndex) = split /\//, $ParentChildTuple;

    # Dunno why, but a 3524 with no VLANs configured will
    # end up with zeros in some ifIndexes.  So skip 'em.
    next if ($ParentIfIndex == 0) or ($ChildIfIndex == 0);
    $logger->debug("ParentIfIndex = \"$ParentIfIndex\", ChildIfIndex = \"$ChildIfIndex\"");
    next if !exists $$PortsByIfNbrRef{$ChildIfIndex};
    my $ChildPort = $$PortsByIfNbrRef{$ChildIfIndex};
    my $ChildPortName = $ChildPort->{Name};

    my $EtherChannel;
    if (exists $$EtherChannelsRef{$ParentIfIndex}) {
      $logger->debug("adding child to parent $ParentIfIndex, child = $ChildPortName");
      $EtherChannel = $$EtherChannelsRef{$ParentIfIndex};
      $EtherChannel->AddChildPort($ChildPort);
    } else {
      $logger->debug("creating new EtherChannel, parent = $ParentIfIndex, child = $ChildPortName");
      $EtherChannel = new EtherChannel $ChildPort;
      $$EtherChannelsRef{$ParentIfIndex} = $EtherChannel;
    }
  }
  $logger->debug("returning");
}


# For every etherchannel that we've discovered, mark the child ports
# as part of an etherchannel.  While you're at it, delete any
# etherchannel that has only one child.  There shouldn't be parents
# with one child, but some 3845 switches return ifStackStatus tables
# that represent them.  In addition to entries where the parent or
# child is 0, which is caught above, these switches have entries
# that define a parent and a child, but there's only one such entry
# for the parent.  This loop deletes EtherChannels that have only
# one child.  It also marks the Port objects as etherchanneled for
# children of valid etherchannels.
sub CleanupEtherChannels($) {
  my $Switch = shift;
  my $logger = get_logger('log5');
  $logger->debug("called");

  my $EtherChannelsRef = $Switch->{EtherChannels};

  foreach my $ParentIfIndex (keys %$EtherChannelsRef) {
    $logger->debug("ParentIfIndex = $ParentIfIndex");
    my $EtherChannel = $$EtherChannelsRef{$ParentIfIndex};
    my $NumberChildren = @{$EtherChannel->{ChildPorts}};
    $logger->debug("NumberChildren = $NumberChildren");
    if ($NumberChildren == 1) {
      delete $$EtherChannelsRef{$ParentIfIndex};
    } else {
      foreach my $ChildPort (@{$EtherChannel->{ChildPorts}}) {
        $ChildPort->{EtherChannel} = $EtherChannel;
      }
    }
  }
  $logger->debug("returning");
}


#
# The SNMP ifStackStatus table represents EtherChannels as a list of
# tuples, where each tuple is a parent ifIndex and a child ifIndex.
# For example, if port 9/17 and 10/17 are etherchanneled, and port
# 9/17 is ifIndex 66 and port 10/17 is ifIndex 114, you'll find two
# entries in the ifStackStatus table with values like 447.66 =
# 'active' and 447.114 = 'active'.  This means that 447 is the parent
# virtual etherchanneled port and ports 66 and 114 are its children.
#
#              447
#              / \
#             /   \
#            66   114
#
# We represent this as a hash of EtherChannel objects.
#
sub PopulateEtherChannels ($$) {
  my $Session = shift; # passed in, SNMP session
  my $Switch  = shift; # passed in, this function fills the EtherChannels field
  my $logger = get_logger('log4');
  $logger->debug("called");

  my %ifStackStatus;
  my $status = SwitchUtils::GetSnmpTable($Session,
                                         'ifStackStatus',
                                         $Constants::PORT, # this gets us the last 2 octets
                                         \%ifStackStatus);
  if ($status == $Constants::SUCCESS) {
    #  SwitchUtils::DbgPrintHash('ifStackStatus', \%ifStackStatus);
    FillEtherChannels(\%ifStackStatus, $Switch);
    CleanupEtherChannels($Switch);
  }

  $logger->debug("returning");
}
1;
