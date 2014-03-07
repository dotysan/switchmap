package WriteModulesFile;

use strict;
use Log::Log4perl qw(get_logger);
use ModuleList;


sub WriteSwitchModuleTableFragment ($$) {
  my $ModuleList = shift;
  my $SwitchName = shift;
  my $logger = get_logger('log3');
  $logger->debug("called, SwitchName = \"$SwitchName\"");

  my $NbrModulesWritten = 0;
  my $RemainderOfFragment = '';
  my $FirstTimeThroughLoop = 1;
  foreach my $ModNbr (sort {$a <=> $b} keys %{$ModuleList->{Model}}) {
    my $HtmlStyle= ModuleList::GetModuleHtmlStyle($ModuleList, $ModNbr);
    if ($FirstTimeThroughLoop) {
      $FirstTimeThroughLoop = 0; # first time through, don't output "<tr>"
    } else {
      $RemainderOfFragment .= "<tr>";
    }
    $RemainderOfFragment .= <<MBS2;
<td $HtmlStyle>$ModNbr</td>
<td $HtmlStyle>$ModuleList->{Model}{$ModNbr}</td>
<td $HtmlStyle>$ModuleList->{Description}{$ModNbr}</td>
<td $HtmlStyle>$ModuleList->{HwVersion}{$ModNbr}</td>
<td $HtmlStyle>$ModuleList->{FwVersion}{$ModNbr}</td>
<td $HtmlStyle>$ModuleList->{SwVersion}{$ModNbr}</td>
<td $HtmlStyle>$ModuleList->{SerialNumberString}{$ModNbr}</td>
</tr>
MBS2
    $NbrModulesWritten++;
  }
  my $SwitchCell = <<FULLMOD;
<tr><td colspan="8" height="4" bgcolor="black"></td></tr>
<tr><td rowspan="$NbrModulesWritten"><a href=\"switches/$SwitchName.html\">$SwitchName</a></td>
FULLMOD
  my $retval = $SwitchCell . $RemainderOfFragment;
  $logger->debug("returning");
  return $retval;
}


sub WriteModulesFile ($) {
  my $SwitchesRef = shift;
  my $logger = get_logger('log2');
  my $ModulesBySwitchFileName = File::Spec->catfile($ThisSite::DestinationDirectory, $Constants::ModulesBySwitchFile);
  $logger->debug("called, writing $ModulesBySwitchFileName");

  $logger->info("writing $ModulesBySwitchFileName");
  open MODSBYSWITCHFILE, ">$ModulesBySwitchFileName" or do {
    $logger->fatal("Couldn't open $ModulesBySwitchFileName for writing, $!");
    exit;
  };

  print MODSBYSWITCHFILE SwitchUtils::HtmlHeader("Modules");
  print MODSBYSWITCHFILE <<MBS;
<p>
<table class="Modules">
<tr class="tblHead">
<th>Switch</th>
<th>Slot</th>
<th>Model</th>
<th>Description</th>
<th>HW</th>
<th>FW</th>
<th>SW</th>
<th>Serial</th>
</tr>
MBS
  foreach my $Switch (@$SwitchesRef) {
    if ($Switch->{NbrModules} > 1) { # if it has modules (i.e. 6509s have modules, 3524s don't)
      my $SwitchName = GetName $Switch;
      print MODSBYSWITCHFILE WriteSwitchModuleTableFragment($Switch->{ModuleList}, $SwitchName);
    }
  }
  print MODSBYSWITCHFILE "</table>\n";
  print MODSBYSWITCHFILE SwitchUtils::HtmlTrailer;
  close MODSBYSWITCHFILE;
  SwitchUtils::AllowAllToReadFile $ModulesBySwitchFileName;
  $logger->debug("returning");
}

1;
