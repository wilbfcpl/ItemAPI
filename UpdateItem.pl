# Author:  <wblake@CB95043>
# Created: March 7, 2022
# Version: 0.01
#
# Usage: perl [-g] [-x] [-i] UpdateItem.pl item_file.csv
# -g Debug/verbose -q quiet
#
# Expects Input csv file with a header row
# itemid,bid,old call number, new call number
# 
# Example First Two Lines of an Input File:
#
# ITEM,BID,OLDCN,NEWCN,TITLE,AUTHOR,BRANCHCODE,LOCCODE
# 21982030026524,67393,E TRAN - BEGINNING TO READ,ER TRAN,Transformers : Training day : hunt for the Decepticons /,"Teitelbaum, Michael",CBA,EPRDR

use strict;
use diagnostics;
use integer;
use Time::HiRes qw( gettimeofday tv_interval);
use Parallel::ForkManager;
use Data::Dumper;
use say;

# See the CPAN and web pages for XML::Compile::WSDL http://perl.overmeer.net/xml-compile/
use XML::Compile::WSDL11;      # use WSDL version 1.1
use XML::Compile::SOAP11;      # use SOAP version 1.1
use XML::Compile::Transport::SOAPHTTP;
use Getopt::Std;

use constant API_CHUNK_SIZE => 16;

#Command line input variable handling
our ($opt_g,$opt_x,$opt_q);
getopts('gx:q');

my $local_filename=$0;
 $local_filename =~ s/.+\\([A-z]+.pl)/$1/;
       
use if defined $opt_g, "Log::Report", mode=>'DEBUG';
   
if ( defined($opt_g) ) {
     say "[$local_filename" . ":" . __LINE__ . "]Debug Mode $opt_g." ;
}

my $quiet_mode = 0;

if ( defined($opt_q)) {
     $quiet_mode =1 ;
     say "[$local_filename" . ":" . __LINE__ . "]Quiet Mode $quiet_mode." ;
}

#Time::HiRes qw( gettimeofday tv_interval) related variables
my $t0;
my $elapsed;

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
{  die "[$local_filename" . ":" . __LINE__ . "]Failed XML::Compile call\n" ;
}
           
my $call1 = $wsdl->compileClient('GetItemList');
my $call2 = $wsdl->compileClient('UpdateItem');
my $call3 = $wsdl->compileClient('DeleteItem');
my $call4 = $wsdl->compileClient('GetItemNotes');
my $call5 = $wsdl->compileClient('UpdateItemNote');

unless ((defined $call1) && (defined $call2) && (defined $call3) && ( defined $call4)  && defined($call5))
  { die "[$local_filename" . ":" . __LINE__ . "] SOAP/WSDL Error $wsdl $call1, $call2 $call3 $call4 $call5 \n" ;}

  say "[$local_filename" . ":" . __LINE__ . "] ARGV[0] $ARGV[0] " ;
 
# Use wc -l to get line count of input file $ARGV[0]
  my $nr = qx/wc -l $ARGV[0]/ ;
  if ($? != 0) {
    die "[$local_filename" . ":" . __LINE__ . "]shell returned $?";
  }
  
  $nr =~ s/^([0-9]+).*/$1/;
  chomp($nr);
  
  #[$local_filename" . ":" . __LINE__ . "]DBI Call lapsed time $elapsed."
  my $num_chunks = $nr/API_CHUNK_SIZE;
  my $mods = $nr%API_CHUNK_SIZE;
  
  say "[$local_filename" . ":" . __LINE__ . "]Linecount " . $nr . " Burst Size " . API_CHUNK_SIZE . " Bursts " . $num_chunks . " Mod " . $mods;
  my (@items,@bids,@old_callnumbers,@new_callnumbers) ;
  my $pid;
  my (@result2,@trace2);
  
  # Read the input file and ignore the first line having column headings
  $_ = <>;
  chomp;
  
  my $pm =  new Parallel::ForkManager(API_CHUNK_SIZE);

# End subroutine for each of the forked processes.
# Save result, trace for examination by parent process
# Debug mode only
if ( defined($opt_g) ) {
     say "[$local_filename" . ":" . __LINE__ . "]Debug Mode $opt_g run_on_finish" ;

  $pm->run_on_finish( sub {
   my ($pid, $exit_code, $ident, $exit_signal, $core_dump, $data_structure_reference) = @_;
   if (defined ($data_structure_reference))
   {
    my $entry=$data_structure_reference->{entry_line};
    say "[$local_filename" . ":" . __LINE__ . "]Mod Process input " . $entry;
    #say "[$local_filename" . ":" . __LINE__ . "]Dumper " . Dumper $data_structure_reference->{result} ;
    $results{$entry} =  ${$data_structure_reference->{result}};
    say "[$local_filename" . ":" . __LINE__ . "]Dumper " . Dumper $results{$entry};
    #say "[$local_filename" . ":" . __LINE__ . "]Mod Process result " . $results{$entry};
    # print Dumper $results{$entry};
    #  $trace{$entry} =    ${${$data_structure_reference}->{tracer}};
   }
   });
 }
  
  for (my $current_block=0; $current_block<$num_chunks;$current_block++ )
  {
    if ($quiet_mode==0) {
    say "[$local_filename" . ":" . __LINE__ . "]Burst $current_block";
    }
    #time the operation length in seconds
    #$t0 = [gettimeofday]; 
    for my $current_line (0..API_CHUNK_SIZE-1)
    {
     #say " [$local_filename" . ":" . __LINE__ . "]Current line " . ($current_block * API_CHUNK_SIZE + $current_line + 1);
     $_ = <>;
     next if ( (not defined $_ ) || ($_=~/^ *$/) || ($_ =~/^\s*$/));
     chomp ;
     ($items[$current_line], $bids[$current_line], $old_callnumbers[$current_line], $new_callnumbers[$current_line] ) = split(/,/);
    }
    for (my $current_line=0; $current_line<API_CHUNK_SIZE; $current_line++)
      {
        $pid = $pm->start and next;
    
        $ItemRec{CallNumber} = $new_callnumbers[$current_line] ;
        $UpdateItemRequest{ItemID}=$items[$current_line] ;
    
        ($result2[$current_line],$trace2[$current_line]) = $call2->(%UpdateItemRequest);
       
        if ( $quiet_mode == 0) {    
          say "[$local_filename" . ":" . __LINE__ . "]Burst $current_block proc $current_line API returned";
        }
        my $MyResponseStatusCode = ($result2[$current_line]->{UpdateItemResponse}->{ResponseStatuses}->{cho_ResponseStatus}[0]->{ResponseStatus}->{Code});
        #say "[$local_filename" . ":" . __LINE__ . "]MyResponseStatusCode " . $MyResponseStatusCode ;
       
        if ( defined($opt_g) ) {
           say "[$local_filename" . ":" . __LINE__ . "]Debug Mode $opt_g." ;
           $pm->finish (0,  {entry_line=>$current_line,result=>\$MyResponseStatusCode});
           #$pm->finish (0,  {entry_line=>$current_line});
           #$pm->finish (0,   {entry_line=>$current_line, result=>\$result2[$current_line]});
           #$pm->finish (0, { result=>\$result2[$current_line], tracer=>\$trace2[$current_line],entry_line=>$current_line});
        }
        else {
          $pm->finish;
         }
  
        if ( $quiet_mode==0) {   
         say "[$local_filename" . ":" . __LINE__ . "]Burst $current_block waiting...";
        }
       $pm->wait_all_children;
       if ( $quiet_mode==0) {
        say "[$local_filename" . ":" . __LINE__ . "]Burst $current_block finished...";
       }
     } # end for (my $current_line=0; $current_line<API_CHUNK_SIZE; $current_line++)
  } # end for (my $current_block=0; $current_block<$num_chunks;$current_block++ )
  
  # Remaining Items after dividing into API_CHUNK_SIZE bursts 
  for ( my $mod_line=0; $mod_line<$mods; $mod_line++)
  {
   if ($quiet_mode==0) {
    say "[$local_filename" . ":" . __LINE__ . "]Mod Line $mod_line";
    }
   $_=<>;
    next if ( (not defined $_ ) || ($_=~/^ *$/) || ($_ =~/^\s*$/));
    chomp;
    ($items[$mod_line], $bids[$mod_line], $old_callnumbers[$mod_line], $new_callnumbers[$mod_line] ) = split(/,/);
   }
  
  for ( my $mod_line=0; $mod_line<$mods; $mod_line++ )
  {
    $pid = $pm->start and next;
    if ($quiet_mode==0) {
    #say("[$local_filename" . ":" . __LINE__ . "]Parallel Fork Mod proc $mod_line");
    }
    $ItemRec{CallNumber} = $new_callnumbers[$mod_line] ;
    $UpdateItemRequest{ItemID}=$items[$mod_line] ;
  
    ($result2[$mod_line],$trace2[$mod_line]) = $call2->(%UpdateItemRequest);
    
    if ($quiet_mode==0) {
      say "[$local_filename" . ":" . __LINE__ . "]Forked modline $mod_line UpdateItem request returned";
     }

     my $MyResponseStatusCode = ($result2[$mod_line]->{UpdateItemResponse}->{ResponseStatuses}->{cho_ResponseStatus}[0]->{ResponseStatus}->{Code});
     #say "[$local_filename" . ":" . __LINE__ . "]MyResponseStatusCode " . $MyResponseStatusCode ;
     if ( defined($opt_g) ) {
       $pm->finish (0,   {entry_line=>$mod_line, result=>\$MyResponseStatusCode});
       #$pm->finish (0,  {entry_line=>$mod_line});
       #$pm->finish (0,   {entry_line=>$mod_line, result=>\$result2[$mod_line]});
       #$pm->finish (0,   {result=>\$result2[$mod_line], tracer=>\$trace2[$mod_line],entry_line=>$mod_line});
     }
     else {
      $pm->finish;
      } 
  if ($quiet_mode==0) {
   say "[$local_filename" . ":" . __LINE__ . "]mod_line waiting children...";
  }
  $pm->wait_all_children;
  
  if ( $quiet_mode==0 )   {
    say "[$local_filename" . ":" . __LINE__ . "]mod_line finished";
    }
   #$elapsed = tv_interval ($t0) ;
   #say ("[$local_filename" . ":" . __LINE__ . "]Parallel Fork Call lapsed time $elapsed.");
  } #end for ( my $mod_line=0; $mod_line<$mods; $mod_line++ )

  
     
     
