# NAME

Git::Wrapper - Wrap git(7) command-line interface

# VERSION

version 0.032

# SYNOPSIS

    my $git = Git::Wrapper->new('/var/foo');

    $git->commit(...)
    print $_->message for $git->log;

    # specify which git binary to use
    my $git = Git::Wrapper->new({
      dir        => '/var/foo ,
      git_binary => '/path/to/git/bin/git' ,
    });

# DESCRIPTION

Git::Wrapper provides an API for git(7) that uses Perl data structures for
argument passing, instead of CLI-style `--options` as [Git](https://metacpan.org/pod/Git) does.

# METHOD INVOCATION

Except as documented, every git subcommand is available as a method on a
Git::Wrapper object. Replace any hyphens in the git command with underscores
(for example, 'git init-db' would become `$git-`init\_db>).

## Method Arguments

Methods accept a combination of hashrefs and scalars, which is used to build
the command used to invoke git. Arguments passed in hashrefs will be
automatically parsed into option pairs, but the ordering of these in the
resulting shell command is not guaranteed (with the exception of options with
a leading '-'; see below). Options that are passed as plain scalars will
retain their order. Some examples may help clarify. This code:

    $git->commit({ message => "stuff" , all => 1 });

may produce this shell command:

    git commit --all --message="stuff"

This code, however:

    $git->commit(qw/ --message "stuff" / , { all => 1 });

will always produce this shell command:

    git commit --message "stuff" --all

In most cases, this exact control over argument ordering is not needed and
simply passing all options as part of a hashref, and all other options as
additional list arguments, will be sufficient. In some cases, however, the
ordering of options to particular git sub-commands is significant, resulting
in the need for this level of control.

_N.b._ Options that are given with a leading '-' (with the exception of
special options noted below) are applied as arguments to the `git` command
itself; options without a leading '-' are applied as arguments to the
sub-command. For example:

    $git->command({ -foo => 1 , bar => 2 });

invokes the command line

    git --foo=1 command --bar=2

_N.b._ Because of the way arguments are parsed, should you need to pass an
explicit '0' value to an option (for example, to have the same effect as
`--abrrev=0` on the command line), you should pass it with a leading space, like so:

    $git->describe({ abbrev => ' 0' };

To pass content via STDIN, use the -STDIN option:

    $git->hash_object({ stdin => 1, -STDIN => 'content to hash' });

Output is available as an array of lines, each chomped.

    @sha1s_and_titles = $git->rev_list({ all => 1, pretty => 'oneline' });

### Passing stringify-able objects as arguments

Objects may be passed in the place of scalars, assuming those objects overload
stringification in such a way as to produce a useful value. However, relying
on this stringification is discouraged and likely to be officially deprecated
in a subsequent release. Instead, if you have an object that stringifies to a
meaningful value (_e.g._, a [Path::Class](https://metacpan.org/pod/Path::Class) object), you should stringify it
yourself before passing it to `Git::Wrapper` methods.

## Error handling

If a git command exits nonzero, a `Git::Wrapper::Exception` object will be
thrown (via `die()`). These objects have three useful methods:

- error

    error message

- output

    normal output, as a single string

- status

    the exit status

These exception objects stringify to the error message.

# METHODS

## new

    my $git = Git::Wrapper->new($dir);
    my $git = Git::Wrapper->new({ dir => $dir , git_binary => '/path/to/git' });

    # To force the git binary location
    my $git = Git::Wrapper->new($dir, 'git_binary' => '/usr/local/bin/git');

## git

    print $git->git; # /path/to/git/binary/being/used

## dir

    print $git->dir; # /var/foo

## version

    my $version = $git->version; # 1.6.1.4.8.15.16.23.42

## branch

    my @branches = $git->branch;

This command intentionally disables ANSI color highlighting in the output. If
you want ANSI color highlighting, you'll need to bypass via the RUN() method
(see below).

## log

    my @logs = $git->log;

Instead of giving back an arrayref of lines, the `log` method returns a list
of `Git::Wrapper::Log` objects. They have four methods:

- id
- author
- date
- message

## has\_git\_in\_path

This method returns a true or false value indicating if there is a 'git'
binary in the current $PATH.

## supports\_status\_porcelain

## supports\_log\_no\_abbrev\_commit

## supports\_log\_raw\_dates

## supports\_hash\_object\_filters

These methods return a true or false value (1 or 0) indicating whether the git
binary being used has support for these options. (The '--porcelain' option on
'git status', the '--no-abbrev-commit' and '--date=raw' options on 'git log',
and the '--no-filters' option on 'git hash-object' respectively.)

These are primarily for use in this distribution's test suite, but may also be
useful when writing code using Git::Wrapper that might be run with different
versions of the underlying git binary.

## status

When running with an underlying git binary that returns false for the
["supports\_status\_porcelain"](#supports_status_porcelain) method, this method will act like any other
wrapped command: it will return output as an array of chomped lines.

When running with an underlying git binary that returns true for the
["supports\_status\_porcelain"](#supports_status_porcelain) method, this method instead returns an
instance of Git::Wrapper::Statuses:

    my $statuses = $git->status;

Git::Wrapper:Statuses has two public methods. First, `is_dirty`:

    my $dirty_flag = $statuses->is_dirty;

which returns a true/false value depending on whether the repository has any
uncommitted changes.

Second, `get`:

    my @status = $statuses->get($group)

which returns an array of Git::Wrapper::Status objects, one per file changed.

There are four status groups, each of which may contain zero or more changes.

- indexed : Changed & added to the index (aka, will be committed)
- changed : Changed but not in the index (aka, won't be committed)
- unknown : Untracked files
- conflict : Merge conflicts

Note that a single file can occur in more than one group. Eg, a modified file
that has been added to the index will appear in the 'indexed' list. If it is
subsequently further modified it will additionally appear in the 'changed'
group.

A Git::Wrapper::Status object has three methods you can call:

    my $from = $status->from;

The file path of the changed file, relative to the repo root. For renames,
this is the original path.

    my $to = $status->to;

Renames returns the new path/name for the path. In all other cases returns
an empty string.

    my $mode = $status->mode;

Indicates what has changed about the file.

Within each group (except 'conflict') a file can be in one of a number of
modes, although some modes only occur in some groups (eg, 'added' never appears
in the 'unknown' group).

- modified
- added
- deleted
- renamed
- copied
- conflict

All files in the 'unknown' group will have a mode of 'unknown' (which is
redundant but at least consistent).

The 'conflict' group instead has the following modes.

- 'both deleted' : deleted on both branches
- 'both added'   : added on both branches
- 'both modified' : modified on both branches
- 'added by us'  : added only on our branch
- 'deleted by us' : deleted only on our branch
- 'added by them' : added on the branch we are merging in
- 'deleted by them' : deleted on the branch we are merging in

See git-status man page for more details.

### Example

    my $git = Git::Wrapper->new('/path/to/git/repo');
    my $statuses = $git->status;
    for my $type (qw<indexed changed unknown conflict>) {
        my @states = $statuses->get($type)
            or next;
        print "Files in state $type\n";
        for (@states) {
            print '  ', $_->mode, ' ', $_->from;
            print ' renamed to ', $_->to
                if $_->mode eq 'renamed';
            print "\n";
        }
    }

## RUN

This method bypasses the output rearranging performed by some of the wrapped
methods described above (i.e., `log`, `status`, etc.). This can be useful
in various situations, such as when you want to produce a particular log
output format that isn't compatible with the way `Git::Wrapper` constructs
`Git::Wrapper::Log`, or when you want raw `git status` output that isn't
parsed into a <Git::Wrapper::Status> object.

This method should be called with an initial string argument of the `git`
subcommand you want to run, followed by a hashref containing options and their
values, and then a list of any other arguments.

### Example

    my $git = Git::Wrapper->new( '/path/to/git/repo' );

    # the 'log' method returns Git::Wrapper::Log objects
    my @log_objects = $git->log();

    # while 'RUN('log')' returns an array of chomped lines
    my @log_lines = $git->RUN('log');

## ERR

After a command has been run, this method will return anything that was sent
to `STDERR`, in the form of an array of chomped lines. This information will
be cleared as soon as a new command is executed. This method should __\*NOT\*__
be used as a success/failure check, as `git` will sometimes produce output on
STDERR when a command is successful.

## OUT

After a command has been run, this method will return anything that was sent
to `STDOUT`, in the form of an array of chomped lines. It is identical to
what is returned from the method call that runs the command, and is provided
simply for symmetry with the `ERR` method. This method should __\*NOT\*__ be
used as a success/failure check, as `git` will frequently not have any output
with a successful command.

# COMPATIBILITY

## Windows

On Win32 Git::Wrapper is incompatible with msysGit installations earlier than
Git-1.7.1-preview20100612 due to a bug involving the return value of a git
command in cmd/git.cmd. If you use the msysGit version distributed with
GitExtensions or an earlier version of msysGit, tests will fail during
installation of this module. You can get the latest version of msysGit on the
Google Code project page: [http://code.google.com/p/msysgit/downloads](http://code.google.com/p/msysgit/downloads)

## Mac OS X

On Mac OS X Git::Wrapper is incompatible with git installations earlier than
Git-1.7.5. If you wish to use git 1.7.4 or below, tests will fail during the
installation of this module.

# ENVIRONMENT VARIABLES

Git::Wrapper normally uses the first 'git' binary in your path. The original
override provided to change this was by setting the GIT\_WRAPPER\_GIT environment
variable. Now that object creation accepts an override, you are encouraged to
instead pass the binary location (git\_binary) to new on object creation.

# SEE ALSO

[VCI::VCS::Git](https://metacpan.org/pod/VCI::VCS::Git) is the git implementation for [VCI](https://metacpan.org/pod/VCI), a generic interface to
version-control systems.

[Other Perl Git Wrappers](https://metacpan.org/module/Git::Repository#OTHER-PERL-GIT-WRAPPERS)
is a list of other Git interfaces in Perl. If [Git::Wrapper](https://metacpan.org/pod/Git::Wrapper) doesn't scratch
your itch, possibly one of the modules listed there will.

Git itself is at [http://git.or.cz](http://git.or.cz).

# REPORTING BUGS & OTHER WAYS TO CONTRIBUTE

The code for this module is maintained on GitHub, at
[https://github.com/genehack/Git-Wrapper](https://github.com/genehack/Git-Wrapper). If you have a patch, feel free to
fork the repository and submit a pull request. If you find a bug, please open
an issue on the project at GitHub. (We also watch the [http://rt.cpan.org](http://rt.cpan.org)
queue for Git::Wrapper, so feel free to use that bug reporting system if you
prefer)

# AUTHORS

- Hans Dieter Pearcey <hdp@cpan.org>
- Chris Prather <chris@prather.org>
- John SJ Anderson <genehack@genehack.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Hans Dieter Pearcey.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
