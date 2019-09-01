Neatbash -- bash prettyprinter 

  Fuzzy prettyprinter for BASH scripts: it takes into account only first and the last words in the line for formatting decisions

  Nikolai Bezroukov, 2019
  Licensed under Perl Artistic license
  neatbash can be called "fuzzy" bash pretty-printer. If does not perform full lexical analysis (which for bash is impossible
  as it does not have lexical level defined, but instead relies on the first word of the source to determine nesting
  For reasonable bash style the results are quite satisfactory. Of course, it will not work for compressed or obscured code.
  Produces some useful diagnostic messages.

  The key idea if fuzzy reformatting is use the first symbol, the first word as well the last symbol and the last word of the line
  for determining the nesting level.
  In most cases this is successful approach and in a few case when it is not it is easily corrected using pragma #%nest=Requred_level
 
  To be successful, this approach requires a certain (very reasonable) layout of the script.
  But there some notable exceptions. For example, for any script compressed to eliminate whitespace this approach is not successful
 
  --- INVOCATION
 
  neatbash [options] [file_to_process]
 
 --- OPTIONS
 
  -v -- display version
  -h -- this help
  -t number -- size of tab (emulated with spaces)
  -f -- write formatted test into the same file, creating backup
  -p -- work as a pipe
  -w -- provide additional warnings about non-balance of quotes and round patenthes
 
 
  Parameters
  1st -- name of the file
