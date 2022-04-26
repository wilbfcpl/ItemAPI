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
use Parallel::ForkManager;
use Data::Dumper;
use say;

# See the CPAN and web pages for XML::Compile::WSDL http://perl.overmeer.net/xml-compile/
use XML::Compile::WSDL11;      # use WSDL version 1.1
use XML::Compile::SOAP11;      # use SOAP version 1.1
use XML::Compile::Transport::SOAPHTTP;
use Getopt::Std;

use constant API_CHUNK_SIZE => 10;
#my $max_procs = API_CHUNK_SIZE;



my $t0;
my $elapsed;

#Command line input variable handling
our ($opt_d,$opt_r,$opt_x, $opt_i);
getopts('grx:i');

if (defined $opt_d) {
   use Log::Report mode=>'DEBUG';
}


my $local_filename=$0;
 $local_filename =~ s/.+\\([A-z]+.pl)/$1/;
                  

# Results and trace from XML::Compile::WSDL et al.
my %trace;
my %results;

my %ItemRec;
my %UpdateItemRequest;

%ItemRec = (
         #itemid=> $itemid,
         # bid=> $bid ,
        CallNumber=>''   
         );

%UpdateItemRequest = (
 ItemID => '',
 Item => \%ItemRec,
     Modifiers=> {
        DebugMode=>1,
        ReportMode=>0,}
             );


my $wsdlfile = 'ItemAPI.wsdl';

my $wsdl = XML::Compile::WSDL11->new($wsdlfile);
my $trans = XML::Compile::Transport::SOAPHTTP
    ->new(timeout => 500, address => $wsdl->endPoint);
$wsdl->compileCalls(transport => $trans);

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
  my $mods = $nr%API_CHUNK_SIZE;
  
  say " [$local_filename" . ":" . __LINE__ . "]Linecount " . $nr . " Burst Size " . API_CHUNK_SIZE . " Bursts " . $num_chunks . " Mod " . $mods;
  my (@items,@bids,@old_callnumbers,@new_callnumbers) ;
  my $pid;
  my (@result2,@trace2);
  
 

  # Read the input file and ignore the first line having column headings
  $_ = <>;
  chomp;
  
#my $pm =  new Parallel::ForkManager(API_CHUNK_SIZE);

## End subroutine for each of the forked processes.
## Save results for examination by parent process
#  $pm->run_on_finish( sub {
#			my ($pid, $exit_code, $ident, $exit_signal, $core_dump, $data_structure_reference) = @_;
#
#    # my $q = $data_structure_reference->{input};
#
#    say "Ident: $ident PID: $pid exit code: $exit_code" ;
#  # $results{$q} = $data_structure_reference->{result};
#  # $trace{$q} = $data_structure_reference->{trace};
#
#  # if ((defined $opt_d) &&  (defined  $trace{$q})) {
#  #  if ($trace{$q}->errors) {
#  #    $trace{$q}->printErrors;
#  #    } 
#  # } 
#});
  
  
  for my $current_block (1..$num_chunks)
  {
   say " [$local_filename" . ":" . __LINE__ . "]Burst $current_block";
   
   #time the operation length in seconds
   #$t0 = [gettimeofday];
   
   for my $current_line (0..API_CHUNK_SIZE-1)
   {
    chomp ;
       #say " [$local_filename" . ":" . __LINE__ . "]Current line " . ($current_block * API_CHUNK_SIZE + $current_line + 1);

    $_ = <>;
    ($items[$current_line], $bids[$current_line], $old_callnumbers[$current_line], $new_callnumbers[$current_line] ) = split(/,/);
   }
   my $pm =  new Parallel::ForkManager(API_CHUNK_SIZE);
   for my $current_line (0..API_CHUNK_SIZE-1)
   {

    $pid = $pm->start and next;

    $ItemRec{CallNumber} = $new_callnumbers[$current_line] ;
    $UpdateItemRequest{ItemID}=$items[$current_line] ;

    ($result2[$current_line],$trace2[$current_line]) = $call2->(%UpdateItemRequest);
    say " [$local_filename" . ":" . __LINE__ . "]Burst $current_block proc $current_line API returned";
    $pm->finish;
   #$pm->finish (0, { result=>$result2[$current_line], trace=>$trace2[$current_line],input=>$current_line});
   } 
   say " [$local_filename" . ":" . __LINE__ . "]Burst $current_block waiting...";
   $pm->wait_all_children;
   say " [$local_filename" . ":" . __LINE__ . "]Burst $current_block finished...";
   sleep 1;
  }

  
  for my $mod_line (0..$mods-1)
  {
   
   chomp;
   say " [$local_filename" . ":" . __LINE__ . "]Mod Line " . ( $num_chunks* API_CHUNK_SIZE + $mod_line + 1);
   $_=<>;
    ($items[$mod_line], $bids[$mod_line], $old_callnumbers[$mod_line], $new_callnumbers[$mod_line] ) = split(/,/);
  }
  my $pm =  new Parallel::ForkManager($mods);
  
  for my $mod_line (0..$mods-1)
  {
   $pid = $pm->start and next;
   say("[$local_filename" . ":" . __LINE__ . "]Parallel Fork Mod proc $mod_line");
   $ItemRec{CallNumber} = $new_callnumbers[$mod_line] ;
   $UpdateItemRequest{ItemID}=$items[$mod_line] ;
   ($result2[$mod_line],$trace2[$mod_line]) = $call2->(%UpdateItemRequest);
   say " [$local_filename" . ":" . __LINE__ . "]Mod proc $mod_line API returned";
   $pm->finish;
   #$pm->finish (0, { result=>$result2[$mod_lsay " [$local_filename" . ":" . __LINE__ . "]current_line waitingine], trace=>$trace2[$mod_line],input=>$mod_line});
   
  }
  say " [$local_filename" . ":" . __LINE__ . "]mod_line waiting...";
  $pm->wait_all_children;
  say " [$local_filename" . ":" . __LINE__ . "]mod_line finished";
  #$elapsed = tv_interval ($t0) ;
  #say ("[$local_filename" . ":" . __LINE__ . "]Parallel Fork Call lapsed time $elapsed.");

  #  print Dumper \%results;
 
   
   
   #
   #my $MyResponseStatusCode = ($result2->{UpdateItemResponse}->{ResponseStatuses}->{cho_ResponseStatus}[0]->{ResponseStatus}->{Code});
   #
   #if ( (defined $MyResponseStatusCode) && ($MyResponseStatusCode == 0) )
   # {
   # say "[$local_filename" . ":" . __LINE__ . "]ItemAPI Success: $MyResponseStatusCode" ;
   # }     
  
  

     
     
