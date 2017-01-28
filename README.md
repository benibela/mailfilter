Mailfilter
============

This is a minimal language to filter mails using maildrop and perl.
You write the filter rules in a plain text file, use the perl script in this repository to convert the filter rules to a maildrop script, and configure your mail server to use the maildrop script.



For example this will move all mails about Subject test to testfolder:

    Subject: test
    => testfolder

This will move all mails that are _either_ about Subject test or from someone@example.org to testfolder:

    Subject: test
    From: someone@example.org
    => testfolder

Regular expressions can be used to match the values:

    Subject: /test[0-9]+/
    From: /someone@example\.(org|com)/
    => testfolder

As well as to match the entire header line (in this form they are passed unchanged to maildrop):

    /Subject:\s*test[0-9]+$/
    /From:\s*someone@example.(org|com)/
    => testfolder

Blocks surrounded by {} are also passed unchanged to maildrop. For example this sets the default maildir (which is necessary otherwise the final maildrop script will not work):
 
    {
    MAILDIR="$HOME/mail"
    }
    
    
See tests/tests.pl for further examples.

Caveats
==============

This is highly experimental and mostly made to sort my own mails.

The folder used by => is always prefixed with $MAILDIR, which is currently not configurable, so you need to declare a variable MAILDIR.

From/To/Cc/Resent-To/Resent-Cc ignore the name part and only compare the addr.
