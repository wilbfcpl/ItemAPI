# Author:  <wblake@CB95043>
# Created: March 7, 2022
# Version: 0.01
#
# Usage: perl [-d] [-r ] [-x] [-i] UpdateItem.pl item_file.csv
# -d Debug/verbose -r read only , no update, -i in

use strict;
use diagnostics;
use integer;
use Time::HiRes qw( gettimeofday tv_interval);;
use Data::Dumper;
use say;

# See the CPAN and web pages for XML::Compile::WSDL http://perl.overmeer.net/xml-compile/
use XML::Compile::WSDL11;      # use WSDL version 1.1
use XML::Compile::SOAP11;      # use SOAP version 1.1
use XML::Compile::Transport::SOAPHTTP;
use Getopt::Std;

use constant API_CHUNK_SIZE => 5;

#Command line input variable handling
our ($opt_d,$opt_r,$opt_x, $opt_i);
getopts('drx:i');

if (defined $opt_d) {
   use Log::Report mode=>'DEBUG';
}


my $local_filename=$0;
 $local_filename =~ s/.+\\([A-z]+.pl)/$1/;
                  

# Results and trace from XML::Compile::WSDL et al.
my $result ;
my $trace;
my %ItemRec;
my %UpdateItemRequest;

%ItemRec = (
         #itemid=> $itemid,
         # bid=> $bid ,
        CallNumber=>'',
        Modifiers=> {
        DebugMode=>1,
        ReportMode=>0,}
         );

%UpdateItemRequest = (
 ItemID => '',
 Item => \%ItemRec
             );


my $wsdlfile = 'ItemAPI.wsdl';

my $wsdl = XML::Compile::WSDL11->new($wsdlfile);

unless (defined $wsdl)
{
    die "[$local_filename" . ":" . __LINE__ . "]Failed XML::Compile call\n" ;
}
           
my $call1 = $wsdl->compileClient('GetItemList');
my $call2 = $wsdl->compileClient('UpdateItem');
my $call3 = $wsdl->compileClient('DeleteItem');
my $call4 = $wsdl->compileClient('GetItemNotes');
my $call5 = $wsdl->compileClient('UpdateItemNote');



unless ((defined $call1) && (defined $call2) && (defined $call3) && ( defined $call4)  && defined($call5))
  { die "[$local_filename" . ":" . __LINE__ . "] SOAP/WSDL Error $wsdl $call1, $call2 $call3 $call4 $call5 \n" ;}

 #[TODO] group API update calls into bursts of five
  say "Argv0 $ARGV[0]" ;
  my $nr ;
  
  
  open(FILEHANDLE, "< $ARGV[0]") or die "[$local_filename" . ":" . __LINE__ . "]Unable to Open $ARGV[0]";
       
   while (<FILEHANDLE>) {
    $nr += 1;
   }
   #Ignore first line with labels
   $nr -= 1; 
   seek FILEHANDLE, 0, 0;
 
 #[TODO] determine why backtick doesn't work
 
  #my $nr = qx/dir/ ;
  #if ($? != 0) {
  #  die "shell returned $?";
  #}
  #
  #$nr =~ s/.+ ([0-9]+).*/$1/;
  #
  
  #[$local_filename" . ":" . __LINE__ . "]DBI Call lapsed time $elapsed."
  my $num_chunks = $nr/API_CHUNK_SIZE;
  my $leftovers = $nr%API_CHUNK_SIZE;
  
  say " [$local_filename" . ":" . __LINE__ . "]Linecount " . $nr . " Chunk Size " . API_CHUNK_SIZE . " Blocks " . $num_chunks . " Mod " . $leftovers;
  
  # Read the input file and ignore the first line having column headings
  $_ = <>;
  chomp;
     
  for my $current_block (1..$num_chunks)
  {
   say " [$local_filename" . ":" . __LINE__ . "]Block $current_block";
   for my $current_line (1..API_CHUNK_SIZE)
   {
    chomp ;
    #say " [$local_filename" . ":" . __LINE__ . "]Line $current_line";
    $_ = <>;
    my ($item, $bid, $old_callnumber, $new_callnumber ) = split(/,/);
    say  "[$local_filename" . ":" . __LINE__ . "]Item $item, Bid $bid, OldCN $old_callnumber, NewCN $new_callnumber";
   }
   
  }
  for my $leftover_line (1..$leftovers)
  {
   chomp;
   say " [$local_filename" . ":" . __LINE__ . "]Leftover Line $leftover_line";
   $_=<>;
   my ($item, $bid, $old_callnumber, $new_callnumber ) = split(/,/);
   say  "[$local_filename" . ":" . __LINE__ . "]Item $item, Bid $bid, OldCN $old_callnumber, NewCN $new_callnumber";
   $ItemRec{CallNumber} = $new_callnumber ;
   $UpdateItemRequest{ItemID}=$item ;
   
   my ($result2,$trace2) = $call2->(%UpdateItemRequest);
   say Dumper($result2);
   
   my $MyResponseStatusCode = ($result2->{UpdateItemResponse}->{ResponseStatuses}->{cho_ResponseStatus}[0]->{ResponseStatus}->{Code});
 
   if ( (defined $MyResponseStatusCode) && ($MyResponseStatusCode == 0) )
    {
    say "[$local_filename" . ":" . __LINE__ . "]ItemAPI Success: $MyResponseStatusCode" ;
    }     
  }
  

     
     