# Author:  <wblake@CB95043>
# Created: May 17, 2022
# Version: 0.01
# Usage: perl [-g] [-r ] [-x] [-i] [-q] oldcn.pl cnfile.csv
# -g Debug/verbose -r read only , no update, -i in, -q quiet
#
#
use strict;
use diagnostics;
use integer;
use Getopt::Std;
use Data::Dumper;
use say;
use constant NEW_CALLNUM_PREFIX => "ER" ;
use constant OLD_CALLNUM_PREFIX=> "E";
use constant OLD_CALLNUM_SUFFIX=> "- BEGINNING TO READ";

our ($opt_g,$opt_r,$opt_x, $opt_i,$opt_q);
getopts('grx:iq');

my $local_filename=$0;
my $prefix;
my $author;
my $separator;
my $newcallnum;

$local_filename =~ s/.+\\([A-z]+.pl)/$1/;
       
if ( defined($opt_g) ) {
     say "[$local_filename" . ":" . __LINE__ . "]Debug Mode $opt_g." ;
}


my $CALLNUM_PATTERN1 = qr/^(ER) +([\w\-]+)\s*/;

# Read and print first line containing column header information.
$_=<>;
chomp;
my ($item_header, $bid_header,  $oldcn_header, $newcn_header) = split(/,/,$_,5);
say "$item_header, $bid_header, $oldcn_header, $newcn_header" ;


while (<>) {
  chomp;
  my ($item, $bid, $callnum)= split(/,/); 
 
  if (!defined($opt_q)) {
      
      say "[$local_filename" . ":" . __LINE__ . "]$_" ;
  }
			
  if ( $callnum =~ $CALLNUM_PATTERN1 ) {

    $prefix = $1;
    $author = $2 ;
    
    #Print if debug or not quiet
    if (!defined ($opt_q) || defined($opt_g)) {
    say "[$local_filename" . ":" . __LINE__ . "]Match ER <author>" ;
    # say "[$local_filename" . ":" . __LINE__ . "]Match 1 $1 2 $2 3 $3 4 $4" ;
    say "[$local_filename" . ":" . __LINE__ . "]Match Prefix $prefix Author $author";
    }
    $newcallnum = OLD_CALLNUM_PREFIX . " " . $author . " " . OLD_CALLNUM_SUFFIX;
    say "$item,$bid,$callnum,$newcallnum";
  }
  #Debug print what's not matching;
  elsif (defined($opt_g))
  {
        say "[$local_filename" . ":" . __LINE__ . "]$. Does Not Match $_" ;
  }  
}
