Neatbash -- bash prettyprinter 

  Fuzzy prettyprinter for BASH scripts

  Copyright Nikolai Bezroukov, 2019-2020
  
  Licensed under Perl Artistic license
  
  NOTE: for html version of this document (and may be newer version ;-) see http://www.softpanorama.org/Utilities/Beautifiers/neatbash.shtml
  
 Pretty printer Neatbash can be called a "fuzzy" pretty-printer. If does not perform full lexical analysis (which for bash is impossible  as BASH does not have lexical level defined).  Instead it relies on analysis of a limited context of each line (prefix and suffix) to "guess" correct nesting level. It does not perform any reorginization of the text other then re-indentation. 
 
For reasonable bash style typically found in production scripts the results are quite satisfactory. Of course, it will not work for compressed or obscured code.
 
This is a relatively novel approach as typically prettyprinter attempt to implement full lexical analysis of the language with some elements of syntax analysis, see for example my NEATPL pretty printer (http://www.softpanorama.org/Articles/Oldies/neatpl.pdf ) or Perl tidy. 

The main advantage is that such approach allows to implement pretty capable pretty printer is less then 1K of Perl source lines. Such scripts are more maintainable and have less chances to "drop dead" and became abandonware after the initial author lost interests and no longer supports the script. 

Another huge advantage is the this is  very safe approach, which normally does not (and can not) introduces any errors in bash code with the exception of indented here lines which might be "re-indented" based on the current nesting.  As BASH has no defined lexical level and its parting can never be guaranteed to be  correct this is the only safe approach for such language. You can be sure that no errors are injected by the formatter into the script. 

But there is no free lunch, and such "limited context" approach means that sometimes (rarely) the nesting level can be determined incorrectly.  There also might be problem with multiline string literals including HERE literals that have non zero fixed indent that can't be changed (HERE stings with zero indent are safe) 

To correct this situation three pseudo=comments(pragmas)  were introduced using which you can control the formatting and correct formatting errors. All pesudocomments should start at the beginning of the line. No leading spaces allowed. 

Currently Neatbash allows three types of pseudo-comments:

Switching formatting off and on for the set of lines. This idea is similar to HERE documents allowing to skip portions of the script which are too difficult to format correctly. One example is a here statement with indented lines when re-indenting them to the current nesting level (which is the default action of the formatter)  is undesirable. 

  #%OFF -- (all capitals, should be on the only text in the line, starting from the first position) stops formatting, All lines after this directive are not processed and put into listing and formatted code buffer intact
  
  #%ON -- (all capitals, the  only text on the line starting from the first position with no leading blanks) resumes formatting

Correcting nesting level if it was determined incorrectly. The directive is "#%NEST" which has three forms (more can be added if necessary ;-): 

1. Set the current nesting level to specified integer 

 #%NEST=digit --

2. Increment

#%NEST--

3. Decrement

#%NEST--

For example, if neatbash did not recognize correctly the  point of closing of a particular control structure you can close it yourself with the directive

#%NEST-- 

or 

#%NEST=0 

NOTES: 

1. Again, all control statement should start at the first position of the line. No leading blanks are allowed. 

2. ATTENTION: No spaces between NEST and = or NEAT and ++/-- are allowed.

Also you can arbitrary increase and decrease indent with this directive

As neatbash maintains stack of control keywords it reorganize it also produces some useful diagnostic messages, which in many cases are more precise then  bash diagnostics. 

For most scripts NEATBASH is able to determine that correct nesting level and proper indentation. Of course, to be successful, this approach requires a certain (very reasonable) layout of the script. the main requirement is that multiline control statements should start and end on a separate line. They can not have preceding statements on the same line. For example 

a=$1; if (( $a > $b )) ; then 

max=$a; else max=$b; fi

but one liners (control statements which start and end on the same line) are acceptable 

a=$1; if (( $a > $b )) ; then max=$a; else max=$b; fi

While any of us saw pretty perverted formatting style in some scripts this typically is an anomaly in production quality scripts and most production quality scripts display very reasonable control statements layout, the one that is expected by this pretty printer.  

But again that's why I called this pretty printer "fuzzy"

For any script compressed to eliminate whitespace this approach is not successful

INVOCATION
 
       neatbash [options] [file_to_process]

OPTIONS

  -h -- this help
  
  -t number -- size of tab (emulated with spaces)
  
  -f -- write formatted test into the same file, creating backup
  
  -p -- work as a pipe
  
  -v -- provide additional warnings about non-balance of quotes and round parenthesis 

PARAMETERS

  1st -- name of the file to be formatted

