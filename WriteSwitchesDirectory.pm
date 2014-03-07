package WriteSwitchesDirectory;

use strict;
use Log::Log4perl qw(get_logger);
use Portically;
#use Data::Dumper;


sub HeaderBlurb () {
  return <<HEADERBLURB;
<p>
Most of the following information came from the switch
itself.  Some information in the <strong>MAC&nbsp;address</strong>,
<strong>NIC&nbsp;Manufacturer</strong>,
<strong>IP&nbsp;address</strong> or <strong>DNS&nbsp;Name</strong>
columns may be incorrect due to unavoidable problems with switch
bridge table incompleteness, timing of SNMP requests, or obsolete MAC
data.  A comment at the bottom of this page indicates when this page
was created.  Green rows are active ports.  White rows are ports that
have been inactive for less than $ThisSite::UnusedAfter days.  Grey
rows are ports that have been inactive for more than
$ThisSite::UnusedAfter days.  Red indicates problems that should be
fixed, like an empty <strong>Port&nbsp;Label</strong> field on an
active port.
</p>

HEADERBLURB
}


sub ModuleDetailTable ($) {
  my $Switch = shift;
  my $logger = get_logger('log5');
  $logger->debug("called");

  my $RetVal = "<table border class=\"Switch\" summary=\"Switch information\">\n";
  $RetVal .= "<caption><strong>Switch information</strong></caption>\n";

  my $SwitchChassisModel = $Switch->GetChassisModel;
  if ($SwitchChassisModel ne 'unknown') {
    $RetVal .= "<tr><td class=\"tblHead\"><strong>Model</strong></td><td>$SwitchChassisModel</td></tr>\n";
  }

  my $ProductName = $Switch->GetProductName;
  if (($ProductName ne '') and ($ProductName ne $SwitchChassisModel)) {
    $RetVal .= "<tr><td class=\"tblHead\"><strong>Cisco Product name</strong></td><td>$ProductName</td></tr>\n";
  }

  my $ProductDescription = $Switch->GetProductDescription;
  if ($ProductDescription) {
    $RetVal .= "<tr><td class=\"tblHead\"><strong>Cisco Product comment</strong></td><td>$ProductDescription</td></tr>\n";
  }

  my $SysDescription = $Switch->GetSysDescription;
  $SysDescription =~ s/\n/<br>\n/g;
  if ($SysDescription) {
    $RetVal .= "<tr><td class=\"tblHead\"><strong>sysDescr</strong></td><td>$SysDescription</td></tr>\n";
  }

  my $SysName = $Switch->GetSysName;
  $SysName =~ s/\n/<br>\n/g;
  if ($SysName) {
    $RetVal .= "<tr><td class=\"tblHead\"><strong>sysName</strong></td><td>$SysName</td></tr>\n";
  }

  my $SwitchLocation = $Switch->GetLocation;
  if ($SwitchLocation) {
    $RetVal .= "<tr><td class=\"tblHead\"><strong>Location</strong></td><td>$SwitchLocation</td></tr>\n";
  }

  my $SwitchContact  = $Switch->GetContact;
  if ($SwitchContact) {
    $RetVal .= "<tr><td class=\"tblHead\"><strong>Contact</strong></td><td>$SwitchContact</td></tr>\n";
  }

  my $SysUptime  = $Switch->GetSysUptime;
  if ($SysUptime) {
    $RetVal .= "<tr><td class=\"tblHead\"><strong>sysUptime</strong></td><td>$SysUptime</td></tr>\n";
  }

  $RetVal .= "</table>\n\n";
  $logger->debug("returning");
  return $RetVal;
}


sub GetSectionName ($$) {
  my $Switch             = shift;
  my $PortName           = shift;

  my $SectionName = '';
  my $Port = $Switch->{Ports}{$PortName};
  if (SwitchUtils::IsAncillaryPort $Port) {
    $SectionName = 'Ancillary Ports';
  } elsif ($Port->{IsVirtual}) {
    $SectionName = 'Virtual Ports';
  } else {
    if ($Switch->{NbrModules} > 1) { # if it has modules (i.e. 6509s have modules, 3524s don't)
      $PortName =~ /[^\d]*(\d+)\//; # this matches "3/4", "Ga9/6", "Fa2/0/15", etc.
      if (defined $1) {
        # When you remove a module from a running 6500, its ports won't
        # disappear from the switch until the switch is rebooted.  So we
        # have to check if the module actually exists here to avoid
        # showing modules that don't really exist.  The "model" hash
        # uses module numbers as keys.
        my $ModuleList= $Switch->{ModuleList};
        if (exists $ModuleList->{Model}{$1} && $ModuleList->{Description}{$1} ne 'StackWise notMember') {
          $SectionName = "Module $1";
        } else {
          $SectionName = 'Removed Ports';
        }
      }
    }
    if ($SectionName eq '') {
      $SectionName = 'Ports';
    }
  }
  return $SectionName;
}


my %Sections;   # hash of arrays of rows

#
# Loop through the ports, creating an HTML row for each port.  Put
# each row into a section on the page.  Sections have names like
# 'Module 1', 'Virtual Ports', etc.
#
sub BuildSections ($$$) {
  my $Switch         = shift;
  my $MacIpAddrRef   = shift;
  my $MacHostNameRef = shift;
  my $logger = get_logger('log4');
  $logger->debug("called");

  %Sections = ();

  foreach my $PortName (Portically::PortSort keys %{$Switch->{Ports}}) {
    $logger->debug("PortName = \"$PortName\"");
    my $Port = $Switch->{Ports}{$PortName};
    my $HtmlRow = SwitchUtils::MakeHtmlRow($Switch,
                                           $Port,
                                           $MacIpAddrRef,
                                           $MacHostNameRef,
                                           SwitchUtils::GetDirectoryDepth($Constants::SwitchesDirectory));
    my $SectionName = GetSectionName($Switch, $PortName);
    if (!exists $Sections{$SectionName}) {
      my @Rows = ();
      $Sections{$SectionName} = [ @Rows ];
    }
    $logger->debug("for $PortName, storing a row in $SectionName");
    push @{$Sections{$SectionName}}, $HtmlRow;
  }
  $logger->debug("returning");
}


sub printModuleSections($) {
  my $Switch = shift;
  my $logger = get_logger('log4');
  $logger->debug("called");

  my $SwitchName = GetName $Switch;
  foreach my $SectionName (Portically::PortSort keys %Sections) {
    if ($SectionName =~ /Module (\d+)/) {
      my $ModNbr = $1;
      print HTMLFILE ModuleList::WriteHtmlModuleTable $Switch->{ModuleList}, $SwitchName, $ModNbr;
      print HTMLFILE SwitchUtils::HtmlPortTableHeader();
      foreach my $i ( 0 .. $#{ $Sections{$SectionName} } ) {
        print HTMLFILE $Sections{$SectionName}[$i];
      }
      print HTMLFILE "</table>\n\n";
    }
  }
  $logger->debug("returning");
}


sub printSection($) {
  my $SectionName = shift;
  my $logger = get_logger('log4');
  $logger->debug("called for section $SectionName");

  return if !exists $Sections{$SectionName};
  print HTMLFILE <<SECTIONHEADER;
<hr size="5" noshade>
<p class="section-title">$SectionName</p>
SECTIONHEADER

  print HTMLFILE SwitchUtils::HtmlPortTableHeader();
  foreach my $i ( 0 .. $#{ $Sections{$SectionName} } ) {
    print HTMLFILE $Sections{$SectionName}[$i];
  }
  print HTMLFILE "</table>\n\n";
  $logger->debug("returning");
}


sub WriteSwitchHtmlData ($$$) {
  my $Switch         = shift;
  my $MacIpAddrRef   = shift;
  my $MacHostNameRef = shift;
  my $logger = get_logger('log3');
  $logger->debug("called");

  BuildSections($Switch, $MacIpAddrRef, $MacHostNameRef);
  print HTMLFILE ModuleDetailTable($Switch);
  printModuleSections($Switch);
  printSection('Ports');
  printSection('Virtual Ports');
  printSection('Removed Ports');
  printSection('Ancillary Ports') if $ThisSite::ShowAncillaryPorts;

  $logger->debug("returning");
}


sub GetSwitchesIndex ($) {
  my $SwitchesRef = shift;
  my $logger = get_logger('log3');
  $logger->debug("called");

  my $NbrRows = ($#{$SwitchesRef} / $ThisSite::SwitchIndexColumns) + 1;
  my @OutList = ();
  my $RowNbr = 0;
  foreach my $Switch (@$SwitchesRef) {
    my $SwitchName = GetName $Switch;
    if ($SwitchName =~ /^---(.+)/) { # if it's a group name, not a switch
      $OutList[$RowNbr] .= "<th>$1</th>\n";
    } else {
      my $HtmlName = '';
      if ($ThisSite::UseSysNames) {
        my $SName = $Switch->GetSysName();
        $HtmlName = "$SName<br><span class='small'>($SwitchName)<br></span>\n";
      } else {
        $HtmlName = $SwitchName;
      }
      $OutList[$RowNbr] .= "<td><a href=\"$SwitchName.html\">$HtmlName</a></td>\n";
    }
    $RowNbr = 0 if ++$RowNbr >= $NbrRows;
  }
  my $RetVal = '';
  foreach (@OutList) {
    $RetVal .= "<tr>$_</tr>\n";
  }

  $logger->debug("returning");
  return $RetVal;
}


sub GetSwitchesIndexByGroup ($) {
  my $SwitchesRef = shift;
  my $logger = get_logger('log3');
  $logger->debug("called");

  #
  # Build a hash of groups, where each group is a ;-delimited list of switches within the group.
  #
  my %Group;
  foreach my $Switch (@$SwitchesRef) {
    my $SwitchName = GetName $Switch;
    if ($SwitchName =~ /^---(.+)/) { # if it's a group name, not a switch
      $logger->warn("Encountered a string starting with \"---\" in \@LocalSwitches, which is incompatible with \$UseGroups=1, skipping the string");
      next;
    }
    $SwitchName =~ s/$ThisSite::DnsDomain//;
    my $group = ThisSite::WhichGroup($SwitchName);
    if (!defined $group) {
      $group = 'undefined';
    }
    if (defined($Group{$group})) {
      $Group{$group} .= ';' . $SwitchName;
    } else {
      $Group{$group} = $SwitchName;
    }
  }
  
  my $row = 0;
  my $column = 0;
  my $RowsPerColumn = int(($#ThisSite::LocalSwitches + keys %Group) / $ThisSite::SwitchIndexColumns);
  my @output;                 # each $output[N] contains an output row

  foreach my $group (sort keys %Group) {
    $logger->debug("loop: group = \"$group\"");
    my @GroupSwitches = split(/;/, $Group{$group});
    $output[$row][$column] = "<th>$group</th>";
    $row++;
    foreach my $Switch (@GroupSwitches) {
      $logger->debug("loop: Switch = \"$Switch\"");
      my $SwitchName = $Switch;
      if ($ThisSite::UseSysNames) {
        my $SName = $Switch->GetSysName();
        $output[$row][$column] = "<td><a href=\"$SwitchName.html\">$SName<br><span class='small'>($SwitchName)<br></span></a></td>";
      } else {
        $output[$row][$column] = "<td><a href=\"$SwitchName.html\">$SwitchName</a></td>";
      }
      $row++;
    }
    if ($row >= $RowsPerColumn) {
      $column++;
      $row = 0;
    }
  }

  #
  # Final output
  #
  my $RetVal = '';
  my $done = 0;
  $row = 0;
  while (!$done) {
    $done=1;
    $RetVal .= "    <tr>";
    for (my $column = 0; $column < $ThisSite::SwitchIndexColumns; $column++) {
      if (defined($output[$row][$column])) {
        $RetVal .= "$output[$row][$column]";
        $done=0;
      } else {
        $RetVal .= "<td>--</td>\t";
      }
    }
    $row++;
    $RetVal .= "</tr>\n";
  }

  $logger->debug("returning");
  return $RetVal;
}


sub WriteSwitchesIndexFile ($) {
  my $SwitchesRef = shift;
  my $logger = get_logger('log2');
  my $IndexFileName = File::Spec->catfile($Constants::SwitchesDirectory, 'index.html');
  $logger->debug("called, writing $IndexFileName");

  $logger->info("writing $IndexFileName");
  open PORTSBYSWITCHFILE, ">$IndexFileName" or do {
    $logger->fatal("Couldn't open $IndexFileName for writing, $!");
    exit;
  };
  print PORTSBYSWITCHFILE SwitchUtils::HtmlHeader("Switches");
  print PORTSBYSWITCHFILE "<table class=\"SwitchList\">\n";

  if ($ThisSite::UseGroups) {
    print PORTSBYSWITCHFILE GetSwitchesIndexByGroup($SwitchesRef);
  } else {
    print PORTSBYSWITCHFILE GetSwitchesIndex($SwitchesRef);
  }

  print PORTSBYSWITCHFILE "</table>\n";
  print PORTSBYSWITCHFILE SwitchUtils::HtmlTrailer;
  close PORTSBYSWITCHFILE;
  SwitchUtils::AllowAllToReadFile $IndexFileName;
  $logger->debug("returning");
}


sub WriteSwitchesFiles ($) {
  my $SwitchesRef = shift;
  my $logger = get_logger('log2');
  $logger->debug("called");

  SwitchUtils::SetupDirectory $Constants::SwitchesDirectory; # create or empty out the directory

  my $MacIpAddrRef = MacIpTables::getMacIpAddr();
  my $MacHostNameRef = MacIpTables::getMacHostName();
  foreach my $Switch (@$SwitchesRef) {
    my $SwitchName = GetName $Switch;
    next if $SwitchName =~ /^---(.+)/;   # if it's a group name, not a switch
    my $HtmlFileName = File::Spec->catfile($Constants::SwitchesDirectory, $SwitchName . '.html');
    $logger->info("writing $HtmlFileName");
    open HTMLFILE, ">$HtmlFileName" or do {
      $logger->fatal("Couldn't open $HtmlFileName for writing, $!");
      exit;
    };

    my $TitleLine = "$SwitchName ports list";
    print HTMLFILE SwitchUtils::HtmlHeader($TitleLine);
    print HTMLFILE HeaderBlurb();
    WriteSwitchHtmlData($Switch, $MacIpAddrRef, $MacHostNameRef);
    #  UpdateVlanPortCount($SwitchNameitchName);
    print HTMLFILE SwitchUtils::HtmlTrailer;
    close HTMLFILE;
    SwitchUtils::AllowAllToReadFile $HtmlFileName;
  }

  WriteSwitchesIndexFile($SwitchesRef);
  $logger->debug("returning");
}

1;
