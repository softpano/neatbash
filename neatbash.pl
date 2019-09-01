#!/usr/bin/perl
#:: neatbash version 0.8 (Sep 1, 2019)
#:: Fuzzy prettyprinter for BASH scripts: it takes into account only first and the last words in the line for formatting desitions
#:: Nikolai Bezroukov, 2019
#:: Licensed under Perl Artistic license
#:: neatbash can be  called "fuzzy" bash pretty-printer. If does not perform full lexical analysis (which for bash is impossible
#:: as it does not have lexical level defined, but instead relies on the first word of the source to determine nesting
#:: For reasonable bash style the results are quite satisfactory. Of course, it will not work for compressed or obscured code.
#:: Produces some useful diagnostic messages.

#:: The key idea if fuzzy reformating is use the first symbol, the first word as well the last symbol and the last word of the line
#:: for  determining the nesting level.
#:: In most cases this is sucessful approach and in a few case when it is not it is easily corrected using pragma #%nest=Requred_level
#::
#:: To be sucessful, this approach requres a certain (very resonable) layout of the script.
#:: But there some notable exceptions. For example, for any script compressed to eliminate whitespece this approach  is not sucessful
#::
#:: --- INVOCATION
#::
#::   neatbash [options] [file_to_process]
#::
#::--- OPTIONS
#::
#::    -v -- display version
#::    -h -- this help
#::    -t number -- size of tab (emulated with spaces)
#::    -f  -- writen formattied test into the same files creating backup
#::    -w --  provide additonal warnings about non-balance of quotes and round patenthes
#::
#::
#::  Parameters
#::    1st -- name of  file
#::
#--- Development History
#
# Ver      Date        Who        Modification
# ====  ==========  ========  ==============================================================
# 0.1  2019/08/30  BEZROUN   Initial implementation
# 0.2  2019/08/30  BEZROUN   The ability to debug startign with particular line of input
# 0.3  2019/09/03  BEZROUN   Better diagnistics based on keyword stack added
# 0.4  2019/08/31  BEZROUN   Formatter listing reditected to STDERR. The ability to work as a pipe (via option -p)
# 0.5  2019/08/31  BEZROUN   Warning about unbalanced symbols on the line if msglevel>3 (which means warning are displayed)
# 0.6  2019/08/31  BEZROUN   Formatter test now stored in a buffer and is wrtten only if appropriate optes are activated and the final nesting level is zero
# 0.7  2019/08/31  BEZROUN   Single back indent is now treated via offset parameter
# 0.8  2019/08/31  BEZROUN   Comments and lines staring with a letter in the first position are treated as immutable, theyare never shifted
#START ===================================================================================
#=== Start
   use v5.10;
#  use Modern::Perl;
   use warnings;
   use strict 'subs';
   use feature 'state';
   use Getopt::Std;

   $debug=1; # 0-1 production mode (1 with additional diag messages); 2-9 debugging modes
   #$debug=1;  # better diagnistics, but the result is written to the disk
   #$debug=2; # starting from debug=2 the results are not written to disk
   #$debug=3; # starting from Debug=3 only the first chunk processed


   $VERSION='0.8';
   $SCRIPT_NAME=substr($0,0,rindex($0,'.'));
   $OS=$^O; # $^O is built-in Perl variable that contains OS name
   if($OS eq 'cygwin' ){
      $HOME="/cygdrive/f";
      $BACKUP_DRIVE="/cygdrive/h";
      $LOG_DIR="$BACKUP_DRIVE/Mylogs/$main::SCRIPT_NAME";
   }elsif($OS eq 'linux' ){
      $HOME=ENV{'HOME'};
      $LOG_DIR='/tmp/neatbash';
   }
   %close_delim=('if'=>'fi','for'=>'done', 'case'=>'esac','while'=>'done','until'=>'done');

   $breakpoint=-1; # INTERSTING, VERY NEAT IDEA: you can switch tracing from particular line of source that neatbash processes
   # $breakpoint=56;
   $tab=3;
   $write_formatted=0; # flag that dremines if we need to write the result into the file supplied.
   $write_pipe=0;

   prolog($SCRIPT_NAME,"$HOME/_Scripts");
    if( $debug>0 ){
      logme(-1,5,5);
   } else {
      logme(-1,3,5);
   }
   banner($LOG_DIR,$main::SCRIPT_NAME,30); # Opens SYSLOG and print STDERRs banner; parameter is log retention period
   if( $debug==0 ){
      print STDERR "$main::SCRIPT_NAME is working in production mode\n";
   } else {
      print STDERR "ATTENTION!!! $main::SCRIPT_NAME is working in debugging mode debug=$debug\n";
   }

   get_params();

   $new_nest=$cur_nest=0;

  $top=0; $lineno=0;
  $fline=0; # line number in formatted code
  while($line=<STDIN> ){
    $inbalance='';
    chomp($line);
    $intact_line=$line;
    $lineno++;
    if( $lineno == $breakpoint ){
       $DB::single = 1
    }
    #
    # check for comment lines
    #
    if( substr($line,0,1) eq '#' ){
      list_line(-1000);
      next;
    }
   # trim blanks
   if( $line=~/^\s*(\S.*\S)\s*$/  || $line=~/^\s*(\S)\s*$/ ){
      $line=$1;
   }
   # comments on the level of nesting 0 should start with the first position

   if(  length($line)==0 ){
      list_line(0);
      next;
   }
   if(  substr($line,0,1) eq '#' ){
      list_line(0);
      next;
   }
   if( substr($intact_line,0,1) eq '{' || substr($line,-1,1 ) eq '{' ){
       if( $cur_nest !=0  ){
         logme(__LINE__,'S',"Non zero nesting of exit from function");
      }
      list_line(-1);
      $cur_nest=0;
      next;
    }
    if( substr($intact_line,0,1) eq '}' && length($line)==1 ){
      if( $cur_nest !=0  ){
         logme(__LINE__,'S',"Non zero nesting of exit from function");
      }
      $cur_nest=0; # immeduate effect
      list_line(-1000);
      next;
    }

   if( $line=~/(\w+)/  ){
      $first_word=$1;
      if( $first_word eq 'if' || $first_word eq 'for'  || $first_word eq 'case'){
         $new_nest++;
         $top++;
         $stack[$top]=$first_word;
      } elsif( $first_word eq 'fi' || $first_word eq 'done'   || $first_word eq 'esac' ){
         $new_nest--;
         $cur_nest=$new_nest;
         if( $top>0 ){
            $last_open=$stack[$top];
            if( $close_delim{$last_open} ne $first_word ){
               logme(__LINE__,'S',"Extended closing delimiter should be $close_delim{$last_open} and not $first_word");
            }
            $top--;
         }else{
            logme(__LINE__,'S',"Attempt to close control structure on zero nesting level. Extra closing keyword $first_word ?");
         }
      }elsif($first_word eq 'else' || $first_word eq 'elif'|| $first_word eq 'then' || $first_word eq 'do' ){
         list_line(-1); # immeduate one time move left
         next;
      }

   }
   list_line(0);
   } # while
   close STDIN;
   if( $cur_nest !=0 ){
      logme(__LINE__,'W',"Final nesting is $cur_nest insted of zero. Writing formatted code is blocked");
      exit 16;
   }
     if( $write_formatted >0 || $write_pipe > 0  ){
      write_formatted_code();
   }
   exit;

#
# Subroutines
#
sub list_line
{
   my $offset=$_[0];

   check_delimiter_balance($line);
   $prefix=sprintf('%4u %3d %4s',$lineno, $cur_nest, $inbalance);

   if( ($cur_nest+$offset)<0 || $cur_nest<0 ){
      $spaces='';
   }elsif( substr($intact_line,0,1) =~ /[\w]/ ){
      $spaces='';
   } else {
      $spaces= ' ' x (($cur_nest+$offset+1)*$tab);
   }
   print STDERR "$prefix | $spaces$line\n";
   if(  $write_formatted > 0 ){
      $formattted[$fline++]="$spaces$line\n";
   }
   $cur_nest=$new_nest;
}
sub  write_formatted_code
{
   if( -f $fname ){
      $timestamp=`date +"%y%m%d_%H%M`;
      $fname_backup=$fname.'.'.$timestamp;
      `cp -p $fname $fname_backup`;
   }
   if( $write_formatted ){
      open (SYSFORM,">$fname");
      print SYSFORM join("\n",@formattted);
      close SYSFORM;
   }elsif( $write_pipe ){
      print join("\n",@formattted);
   }
}
sub check_delimiter_balance
{
my $i;
my $scan_text=$_[0];
   $sq_br=0;
   $round_br=0;
   $curve_br=0;
   $single_quote=0;
   $double_quote=0;
   return if( length($_[0])==1 || $line=~/.\s*#/); # no balance in one symbol line.
   for ($i=0; $i<length($scan_text); $i++ ){
     $s=substr($scan_text,$i,1);
     if( $s eq '{' ){ $curve_br++;} elsif( $s eq '}' ){ $curve_br--; }
     if( $s eq '(' ){ $round_br++;} elsif( $s eq ')' ){ $round_br--; }
     if( $s eq '[' ){ $sq_br++;} elsif( $s eq ']' ){ $sq_br--; }

     if(  $s eq "'"  ){ $single_quote++;}
     if(  $s eq '"'  ){ $double_quote++;}
   }
   if(  $single_quote%2==1  ){ $inbalance.="'";}
   elsif(  $double_quote%2==1  ){  $inbalance.='"'; }

   if( $single_quote%2==0 && $double_quote%2==0 ){

       if( $curve_br>0 ){
          $inbalance ='{';
          ( $single_quote==0 && $double_quote==0 ) && logme(__LINE__,'W',"Possible missing '}' on the following line:");
       } elsif(  $curve_br<0  ){
          $inbalance ='}';
           ( $single_quote==0 && $double_quote==0 ) && logme(__LINE__,'W',"Possible missing '{' on the following line:  ");
       }

      if(  $round_br>0  ){
        $inbalance ='(';
         ( $single_quote==0 && $double_quote==0 ) && logme(__LINE__,'W',"Possible missing ')' on the following line:");
      } elsif(  $round_br<0  ){
        $inbalance =')';
          ( $single_quote==0 && $double_quote==0 ) && logme(__LINE__,'W',"Possible missing '(' on the following line:");
      }
      if(  $sq_br>0  ){
        $inbalance ='[';
        ( $single_quote==0 && $double_quote==0 ) &&logme(__LINE__,'W',"Possible missing ']' on the following line:");
      } elsif(  $sq_br<0  ){
        $inbalance =']';
         ( $single_quote==0 && $double_quote==0 ) && logme(__LINE__,'W',"Possible missing '[' on the following line:");
      }
   }

}



sub get_params
{
#
# process parameters and options
#
   getopts("t:fvh",\%options);
   if(  exists $options{'v'} ){
      banner($LOG_DIR,$main::SCRIPT_NAME,30); # Opens SYSLOG and print STDERRs banner; parameter is log retention period
      print STDERR "Options -h, -v, -c file\n";
      exit;
   } elsif(  exists $options{'h'} ){
      helpme();
   } elsif(  exists $options{'p'}  ){
       $write_formatted=0;
       $write_pipe=1;
   } elsif(  exists $options{'f'}  ){
       $write_formatted=1;
   } elsif(  exists $options{'t'}  ){
      if( $options{'t'}>0  && $options{'t'}<10 ){
         $tab=$options{'t'};
      } else {
        die("Wrong value of option -t (tab size): $options('t')\n");
      }
   } elsif(  exists $options{'b'}  ){
      if( $options{'b'}>0  && $options{'t'}<1000 ){
         $breakpoint=$options{'b'};
      } else {
        die("Wrong value of option -b (line for debugger breakpoint): $options('b')\n");
      }
   }
   if( scalar(@ARGV)==0 ){
       open (STDIN, ">-");
       $write_formatted=0;
       return;
   }


   if( scalar(@ARGV)==1 ){
       $fname=$ARGV[0];
       unless ( -f $fname ){
          die ("Unable to open file $ARGV[0]");
       }
       open (STDIN, "<$fname");
   } else {
       $args=join(' ', @ARGV);
       die ("Too many arguments: $args")
   }

}
#
###================================================= NAMESPACE sp: My SP toolkit subroutines
#

sub prolog
{
my $SCRIPT_NAME=$_[0];
my $SCRIPT_DIR=$_[1];
#
# Set message  prefix
#
   $message_prefix='neatbash';


#
# Commit each running version to the repository
#
my $SCRIPT_TIMESTAMP;
my $script_delta=1;
  if(  -f "$SCRIPT_DIR/Archive/$main::SCRIPT_NAME.pl"  ){
     if( (-s "$SCRIPT_DIR/$main::SCRIPT_NAME.pl") == (-s "$SCRIPT_DIR/Archive/$main::SCRIPT_NAME.pl")   ){
        `diff $SCRIPT_DIR/$main::SCRIPT_NAME.pl $SCRIPT_DIR/Archive/$main::SCRIPT_NAME.pl`;
        if(  $? == 0  ){
           $script_delta=0;
        }
     }
     if( $script_delta > 0 ){
        chomp($SCRIPT_TIMESTAMP=`date -r $SCRIPT_DIR/Archive/$main::SCRIPT_NAME.pl +"%y%m%d_%H%M"`);
       `mv $SCRIPT_DIR/Archive/$main::SCRIPT_NAME.pl $SCRIPT_DIR/Archive/$main::SCRIPT_NAME.$SCRIPT_TIMESTAMP.pl`;
       `cp -p $SCRIPT_DIR/$main::SCRIPT_NAME.pl $SCRIPT_DIR/Archive/$main::SCRIPT_NAME.pl `;
     }
   } else {
      `cp -p $SCRIPT_DIR/$main::SCRIPT_NAME.pl $SCRIPT_DIR/Archive/$main::SCRIPT_NAME.pl `;
   }

} # prolog


# Read script and extract help from comments starting with #::
#
sub helpme
{
   open(SYSHELP,"<$0");
   while($line=<SYSHELP> ){
      if(  substr($line,0,3) eq "#::" ){
         print STDERR substr($line,3);
      }
   } # for
   close SYSHELP;
   exit;
}

#
# Teminate program (variant without mailing)
#
sub abend
{
my $message;
my $lineno=$_[0];
   if( scalar(@_)==1 ){
      $message="ABEND at $lineno. No message was provided for abend call. Exiting.";
   }else{
      $message="$lineno $_[1]. Exiting ";
   }
#  Syslog might not be availble
   out($message);
   die("Abend at $lineno. $message");
} # abend
#
# Inital banner
# dependw of two variable from main namespace: VERSION and debug
sub banner {
#
# Sanity check
#
   if( scalar(@_)<2 ){
      die("Incorrect call to banner; less then three argumnets passed".join("\n",@_));
   }
#
# Decode obligatory arguments
#
my $LOG_DIR=$_[0];
my $SCRIPT_NAME=$_[1];
my $LOG_RETENTION_PERIOD=$_[2];
#
# optional arguments
#
my $subtitle;
if( scalar(@_)>2 ){
   $subtitle=$_[3]; # this is an optional argumnet which is print STDERRed as subtitle after the title.
}

my $timestamp=`date "+%y/%m/%d %H:%M"`;
   chomp $timestamp;

my $SCRIPT_MOD_DATE=`date -r /cygdrive/f/_Scripts/$main::SCRIPT_NAME.pl +"%y%m%d_%H%M"`;
   chomp $SCRIPT_MOD_DATE;

my $title="\n\n".uc($main::SCRIPT_NAME).": Cleaner for html ChunksA. Version $main::VERSION ($SCRIPT_MOD_DATE) DEBUG=$main::debug Date $timestamp";
my $day=`date '+%d'`; chomp $day;

   if( 1 == $day && $LOG_RETENTION_PERIOD>0 ){
     #Note: in debugging script home dir is your home dir and the last thing you want is to clean it ;-)
      `find $LOG_DIR -name "*.log" -type f -mtime +$LOG_RETENTION_PERIOD -delete`; # monthly cleanup
   }
my $logstamp=`date +"%y%m%d_%H%M"`; chomp $logstamp;
   $LOG_FILE="$LOG_DIR/$main::SCRIPT_NAME.$logstamp.log";
   unless ( -d $LOG_DIR ){
      `mkdir -p $LOG_DIR`;
   }
   open(SYSLOG, ">$LOG_FILE") || abend(__LINE__,"Fatal error: unable to open $LOG_FILE");

   out($title); # output the banner

   unless ($subtitle ){
      $subtitle="Logs are at $LOG_FILE. Type -h for help.\n";
   }
   out("$subtitle");
   out ("================================================================================\n\n");

}


# ================================================================================ LOGGING ===========================================================

#
# Message generator: Record message in log and STDIN
# PARAMETERS:
#            lineno, severity, message
# ARG1 lineno, If it is negative skip this number of lines
# Arg2 Error code (the first letter is severity, the second letter can be used -- T is timestamp -- put timestamp inthe message)
# Arg3 Text of the message
# NOTE: $top_severity, $verbosity1, $verbosity1 are state variables that are initialized via special call to sp:: sp::logmes

sub logme
{
#our $top_severity; -- should be defined globally

my $lineno=$_[0];
my $message=$_[2];
   chomp($message); # we will add \n ourselves

state $verbosity1; # $verbosity console
state $verbosity2; # $verbosity for log
state $msg_cutlevel1; # variable 6-$verbosity1
state $msg_cutlevel2; # variable 5-$verbosity2
state @ermessage_db; # accumulates messages for each caterory (warning, errors and severe errors)
state @ercounter;
state $delim='=' x 80;
state $linelen=110; # max allowed line length


#
# special cases -- "negative lineno": -1 means set msglevel1 and msglevel2, 0 means print STDERR in log and console -- essentially out($message)
#

if( $lineno<=0 ){
   if( $lineno == -1 ){
        $verbosity1=$_[1];
        $verbosity2=$_[2];
        $msg_cutlevel1=length("DIWEST")-$verbosity1-1;
        $msg_cutlevel2=length("DIWEST")-$verbosity2-1;

    }elsif( 00==$lineno ){
         # this is eqivalenet of out: put obligatory message on console and into log)
         out($message);
    }
   return;
} #if
#
# Now let's process "normal message, which should have severty code.
#
my $error_code=substr($_[1],0,1);
my $error_suffix=(length($_[0])>1) ? substr($_[1],1,1):'';


my $severity=index("diwest",lc($error_code));
#
# Increase messages counter  for given severity (supressed messages are counted too)
#
      if( $severity> -1 ){ $ercounter[$severity]++;}
#
# Stop processing if the message is too trivial for current msglevel1 and msglevel2
#
      return if(  $severity<$msg_cutlevel1 && $severity<$msg_cutlevel2 ); # no need to process if this is lower then both msglevels
#
# From diagnostic message from error code, line number and message (optionally timestamp is suffic of error code is T)
#
$message="$message_prefix\-$lineno$error_code: $message";
   if( $severity eq 'I' ){
      out($message);
      return;
   }

#----------------- Error history -------------------------
      if(  $severity > 2 ){
         # Errors and above should be stored so that later then can be displayed in summary.
         $ermessage_db[$severity] .= "\n\n$message";
      }
#--------- Message print STDERRing and logging --------------
      if( $severity<5  ){
            if( $severity >= $msg_cutlevel2 ){
               # $msg_cutlevel2 defines writing to SYSLOG. 3 means Errors (Severe and terminal messages always whould be print STDERRed)
               if( $severity<4 ){
                  print SYSLOG "$message\n";
               } else {
                  # special treatment of serious messages
                  print SYSLOG "$delim\n$message\n$delim\n";
               }
            }
            if( $severity >= $msg_cutlevel1 ){
               # $msg_cutlevel1 defines writing to STDIN. 3 means Errors (Severe and terminal messages always whould be print STDERRed)
               if( $severity<3 ){
                   if( length($message) <$linelen ){
                      print STDERR "$message\n";
                   } else {
                      $split_point=rindex($message,' ',$linelen);
                      if( $split_point>0 ){
                         print STDERR substr($message,0, $split_point);
                         print STDERR "\n   ".substr($message, $split_point)."\n";
                      } else {
                         print STDERR substr($message,0,$linelen);
                         print STDERR "\n   ".substr($message,$linelen)."\n";
                      }
                   }
               } else {
                  print STDERR "$delim\n$message\n$delim\n";
               }
            }
            return;
      } # $severity<5
#
# code 'T' now means "issue summary and terminate, if message contains the word ABEND" (using state variables now defined within sp:: sp::logme) -- Nov 12, 2015
#

my $summary;
my $counter;
my $delta_chunks;
   #
   # We will put the most severe errors at the end and make 15 sec pause before  read them
   #

   for( $counter=1; $counter<=length('DIWEST'); $counter++ ){
      next unless( $ercounter[$counter] );
      $summary.=" ".substr('DIWEST',$counter,1).": ".$ercounter[$counter];
   } # for
   out("\n\n=== MESSAGES SUMMARY $summary\n");
   out($_[2]);
   if( $ercounter[2] + $ercounter[3] + $ercounter[4] ){
      # print STDERR errors & severe errors
      for(  $severity=1;  $severity<5; $severity++ ){
          # $ermessage_db[$severity]
          if( $ercounter[$severity]>0 ){
             out("$ermessage_db[$severity]\n\n");
          }
      }
   }
#
# Final messages
#
  out("\n*** PLEASE CHECK $ercounter[4] SERIOUS MESSAGES ABOVE");
  out($_[2]);
  if( index($message,'ABEND') ){
    exit; # messages with the word ABEND (in capital) terminate the program
  }
} # logme
#
# Output message to syslog and print STDERR
#
sub out
{
   if( scalar(@_)==0 ){
      print STDERR;
      print SYSLOG;
      return;
   }
   print STDERR "$_[0]\n";
   print SYSLOG "$_[0]\n";
}

sub step
{
   $DB::single = 1;
}
