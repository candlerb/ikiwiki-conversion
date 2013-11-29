[[!template id=plugin name=conversion author="[[BrianCandler]]"]]
[[!tag type/special-purpose]]

*STATUS: EXPERIMENTAL*

This plugin enables the conversion of binary files from one format to
another when copying them into the website.  You provide a list of extension
mappings and a shell command which implements each conversion.

# Configuration

Configuration is by means of a "conversion" setting, which is a list of
conversion rules. In YAML, each list item must start with a dash-space bullet.
Due to a problem with YAML parsing in ikiwiki, each item must take the form
of a multiline string as shown below.

The following example has three rules:

~~~
conversion:
  - |
    from: [odt, odp]
    to: pdf
    command: [unoconv, -f, pdf, -o, $OUTPUTDIR, $INPUTFILE]
    copy_input: true   # we want both odp and pdf in the output
  - |
    from: ditaa
    to: png
    command: [ditaa, $INPUTFILE, $OUTPUTFILE, -s, 0.7]
  - |
    from: mdbeamer
    to: pdf
    command: [pandoc, -t, beamer, -V, "theme:Warsaw", -o, $OUTPUTFILE, $INPUTNAME]
    chdir: $INPUTDIR
~~~

For each conversion, the parameters are as follows:

from
:   The extension of the input file. May be a YAML or space-separated list.
to
:   The extension of the destination file to be generated
match
:   A regular expression - limits this rule to only processing files which
    match this expression
command
:   The command which copies input to output. This is safer if specified
    as a list rather than a single string (which may be subject to shell
    expansion)
chdir
:   The current working directory is changed to this value before
    executing the command. Useful if the command pulls out other files
    relative to the input file.
copy_input
:   If true, ikiwiki will also process the input file using its normal
    rules. For binary files this means copying as-is to the output site.

There can be multiple rules which map the same input extension to different
output extensions; if so they will all be processed (subject to the match
rules). If there are multiple rules which map the same input extension to
the same output extension, only the first matching one will be used.

# Substitutions

The following substitutions may be made. They are performed internally
before passing the command to be executed, not put in environment variables.

$INPUTFILE, $OUTPUTFILE
:    The full path to the input/output file
$INPUTDIR, $OUTPUTDIR
:    The full path to the directory containing the input/output file
$INPUTNAME, $OUTPUTNAME
:    The filename (without directory but with extension)
$INPUTEXT, $OUTPUTEXT
:    Just the extension

Hence:

~~~
$INPUTFILE = $INPUTDIR/$INPUTNAME
~~~

# Download

You can get the source code from [github](https://github.com/candlerb/ikiwiki-conversion)

# TODO

Future ideas:

* keep a cache of converted files, based on hash of input content and the
  conversion flags used
* a way of associating metadata with individual files, which can influence
  the conversion (e.g. set the -s option for ditaa). For most input files
  this would have to be stored somewhere externally.
* if you have a file which consumes other files, e.g. a beamer presentation
  which creates a PDF from Markdown plus images:

    ~~~
    my_document.mdbeamer
    my_document/image1.png
    my_document/image2.png
    ~~~

    then it would be good to have a way to suppress copying of the consumed
    png files to the output. Maybe a "discard" type of rule?
* ditaa is probably best handled by a preprocessor plugin, like graphviz
* beamer presentations would be best handled as a format plugin, so they
  can be edited in the browser and have inline markup (like graphviz). Care
  is required so that embedded images are found by pandoc: there could be
  some in the input directory, and some dynamically-generated ones. And
  they should have a HTML form for quick browsing as well as PDF.
