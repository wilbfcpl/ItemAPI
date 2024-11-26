use strict;
use diagnostics;
use say;

 my $result = `wc -l $ARGV[0]` ;
 
  if ($? != 0) {
    die "shell returned $?";
  }
  
say "wc result: " . $result ;
  