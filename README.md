
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
    
If multiple filters must be all satisfied in an "and" relation, they can be prefixed by &&. For example, if the mail should be relayed if it is about foo bar, or only about foo from certain senders:

    Subject: foo bar
    Subject: foo
    && From: /foo@|bar@/
    => foobar

When the same header is checked in multiple, consecutive filters, only the first filter has to specify the header name:
  
    From: foo@example.org
    : foo@example.com
    : bar@example.org
    => exfolder

The mails can be automatically marked as read with the mark seen command (requires maildrop >= 2.8.4, although you could use an older  mailfilter from early 2017 with older maildrops ):

    From: foobar
    => foolder
    mark seen

This marking can also be done conditionally, e.g. to hide spam:

    From: foobar
    => foolder
    Subject: spam
    mark seen

Multiple filters are separated by line breaks like paragraphs in markdown.

    Subject: topic1
    => folder1
    
    Subject: topic2
    => folder2

    From: someguy
    => thatguy
    mark seen
    
    => catchall

See tests/tests.pl for further examples.

Caveats
==============

This is highly experimental and mostly made to sort my own mails.

The folder used by => is always prefixed with $MAILDIR, which is currently not configurable, so you need to declare a variable MAILDIR.

From/To/Cc/Resent-To/Resent-Cc ignore the name part and only compare the addr.

The two commands `=>` and `mark seen` should probably become more user configurable. 

If you use contains filters like `subject: ..`, the script should ensure that the resulting maildrop script is valid. 
However, if custom regular expressions are used, e.g. `subject: /.../`, it does not check whether the regular expression is valid. So one should always run  `echo | maildrop` to check if the mailfiltering still works after editing these expressions.

Dovecot uses mailfolders like `$MAILDIR/.a.b.c` for a folder c in b in a. Here we write such a folder as `a.b.c`
