use 5.006;
use strict;
use warnings;

package Git::Wrapper;
#ABSTRACT: wrap git(7) command-line interface

our $DEBUG=0;
use IPC::Open3 () ;
use Symbol;
use File::pushd;
use File::Temp;

sub new {
  my ($class, $arg, %opt) = @_;
  my $self = bless { dir => $arg, %opt } => $class;
  die "usage: $class->new(\$dir)" unless $self->dir;
  return $self;
}

sub dir { shift->{dir} }

my $GIT = 'git';

sub _opt {
  my $name = shift;
  $name =~ tr/_/-/;
  return length($name) == 1
    ? "-$name"
    : "--$name"
  ;
}

sub _cmd {
  my $self = shift;

  my $cmd = shift;

  my $opt = ref $_[0] eq 'HASH' ? shift : {};

  my @cmd = $GIT;

  for (grep { /^-/ } keys %$opt) {
    (my $name = $_) =~ s/^-//;
    my $val = delete $opt->{$_};
    next if $val eq '0';
    push @cmd, _opt($name) . ($val eq '1' ? "" : "=$val");
  }
  push @cmd, $cmd;
  for my $name (keys %$opt) {
    my $val = delete $opt->{$name};
    next if $val eq '0';
    ( $name, $val ) = $self->_message_tempfile( $val ) if $self->_win32_multiline_commit_msg( $cmd, $name, $val );
    push @cmd, _opt($name) . ($val eq '1' ? "" : "=$val");
  }
  push @cmd, @_;

  #print "running [@cmd]\n";
  my @out;
  my @err;

  {
    my $d = pushd $self->dir unless $cmd eq 'clone';
    my ($wtr, $rdr, $err);
    $err = Symbol::gensym;
    print STDERR join(' ',@cmd),"\n" if $DEBUG;
    my $pid = IPC::Open3::open3($wtr, $rdr, $err, @cmd);
    close $wtr;
    chomp(@out = <$rdr>);
    chomp(@err = <$err>);
    waitpid $pid, 0;
  };
  #print "status: $?\n";
  if ($?) {
    die Git::Wrapper::Exception->new(
      output => \@out,
      error  => \@err,
      status => $? >> 8,
    );
  }

  chomp(@out);
  return @out;
}

sub _win32_multiline_commit_msg {
  my ( $self, $cmd, $name, $val ) = @_;

  return 0 if $^O ne "MSWin32";
  return 0 if $cmd ne "commit";
  return 0 if $name ne "m" and $name ne "message";
  return 0 if $val !~ /\n/;

  return 1;
}

sub _message_tempfile {
  my ( $self, $message ) = @_;
  my $tmp = File::Temp->new( UNLINK => 0 );
  $tmp->print( $message );
  return ( "file", '"'.$tmp->filename.'"' );
}

sub AUTOLOAD {
  my $self = shift;
  (my $meth = our $AUTOLOAD) =~ s/.+:://;
  return if $meth eq 'DESTROY';
  $meth =~ tr/_/-/;

  return $self->_cmd($meth, @_);
}

sub version {
  my $self = shift;
  my ($version) = $self->_cmd('version');
  $version =~ s/^git version //;
  return $version;
}

sub log {
  my $self = shift;
  my $opt  = ref $_[0] eq 'HASH' ? shift : {};
  $opt->{no_color} = 1;
  $opt->{pretty}   = 'medium';
  my @out = $self->_cmd(log => $opt, @_);

  my @logs;
  while (my $line = shift @out) {
    die "unhandled: $line" unless $line =~ /^commit (\S+)/;
    my $current = Git::Wrapper::Log->new($1);
    $line = shift @out; # next line;
    while ($line =~ /^(\S+):\s+(.+)$/) {
      $current->attr->{lc $1} = $2;
      $line = shift @out; # next line;
    }
    die "no blank line separating head from message" if $line;
    my ( $initial_indent ) = $out[0] =~ /^(\s*)/ if @out;
    my $message = '';
    while (
      @out 
      and $out[0] !~ /^commit (\S+)/ 
      and length($line = shift @out)
    ) {
      $line =~ s/^$initial_indent//; # strip just the indenting added by git
      $message .= "$line\n";
    }
    $current->message($message);
    push @logs, $current;
  }

  return @logs;
}

my %STATUS_CONFLICTS = map { $_ => 1 } qw<DD AU UD UA DU AA UU>;

sub status {
  my $self = shift;
  my $opt  = ref $_[0] eq 'HASH' ? shift : {};
  $opt->{$_} = 1 for qw<porcelain>;
  my @out = $self->_cmd(status => $opt, @_);
  my $statuses = Git::Wrapper::Statuses->new;
  return $statuses if !@out;

  for (@out) {
    my ($x, $y, $from, $to) = $_ =~ /\A(.)(.) (.*?)(?: -> (.*))?\z/;

    if ($STATUS_CONFLICTS{"$x$y"}) {
      $statuses->add('conflict', "$x$y", $from, $to);
    }
    elsif ($x eq '?' && $y eq '?') {
      $statuses->add('unknown', '?', $from, $to);
    }
    else {
      $statuses->add('changed', $y, $from, $to)
        if $y ne ' ';
      $statuses->add('indexed', $x, $from, $to)
        if $x ne ' ';
    }
  }
  return $statuses;
}

package Git::Wrapper::Exception;

sub new { my $class = shift; bless { @_ } => $class }

use overload (
  q("") => 'error',
  fallback => 1,
);

sub output { join "", map { "$_\n" } @{ shift->{output} } }
sub error  { join "", map { "$_\n" } @{ shift->{error} } }
sub status { shift->{status} }

package Git::Wrapper::Log;

sub new {
  my ($class, $id, %arg) = @_;
  return bless {
    id => $id,
    attr => {},
    %arg,
  } => $class;
}

sub id { shift->{id} }

sub attr { shift->{attr} }

sub message { @_ > 1 ? ($_[0]->{message} = $_[1]) : $_[0]->{message} }

sub date { shift->attr->{date} }

sub author { shift->attr->{author} }

1;

package Git::Wrapper::Statuses;

sub new { return bless {} => shift }

sub add {
  my ($self, $type, $mode, $from, $to) = @_;
  my $status = Git::Wrapper::Status->new($mode, $from, $to);
  push @{ $self->{ $type } }, $status;
}

sub get {
  my ($self, $type) = @_;
  return @{ defined $self->{$type} ? $self->{$type} : [] };
}

sub is_dirty {
  my( $self ) = @_;

  return keys %$self ? 1 : 0;
}

1;

package Git::Wrapper::Status;

my %modes = (
  M   => 'modified',
  A   => 'added',
  D   => 'deleted',
  R   => 'renamed',
  C   => 'copied',
  U   => 'conflict',
  '?' => 'unknown',
  DD  => 'both deleted',
  AA  => 'both added',
  UU  => 'both modified',
  AU  => 'added by us',
  DU  => 'deleted by us',
  UA  => 'added by them',
  UD  => 'deleted by them',
);

sub new {
  my ($class, $mode, $from, $to) = @_;
  return bless {
    mode => $mode,
    from => $from,
    to   => $to,
  } => $class;
}

sub mode { $modes{ shift->{mode} } }

sub from { shift->{from} }

sub to   { defined( $_[0]->{to} ) ? $_[0]->{to} : '' }

__END__

=head1 SYNOPSIS

  my $git = Git::Wrapper->new('/var/foo');

  $git->commit(...)
  print $_->message for $git->log;

=head1 DESCRIPTION

Git::Wrapper provides an API for git(7) that uses Perl data structures for
argument passing, instead of CLI-style C<--options> as L<Git> does.

=head1 METHODS

Except as documented, every git subcommand is available as a method on a
Git::Wrapper object.  Replace any hyphens in the git command with underscores.

The first argument should be a hashref containing options and their values.
Boolean options are either true (included) or false (excluded).  The remaining
arguments are passed as ordinary command arguments.

  $git->commit({ all => 1, message => "stuff" });

  $git->checkout("mybranch");

Output is available as an array of lines, each chomped.

  @sha1s_and_titles = $git->rev_list({ all => 1, pretty => 'oneline' });

If a git command exits nonzero, a C<Git::Wrapper::Exception> object will be
thrown.  It has three useful methods:

=over

=item * error

error message

=item * output

normal output, as a single string

=item * status

the exit status

=back

The exception stringifies to the error message.

=head2 new

  my $git = Git::Wrapper->new($dir);

=head2 dir

  print $git->dir; # /var/foo

=head2 version

  my $version = $git->version; # 1.6.1.4.8.15.16.23.42

=head2 log

  my @logs = $git->log;

Instead of giving back an arrayref of lines, the C<log> method returns a list
of C<Git::Wrapper::Log> objects.  They have four methods:

=over

=item * id

=item * author

=item * date

=item * message

=back

=head2 status

  my $statuses = $git->status;

This returns an instance of Git::Wrapper:Statuses which has two public
methods. First, C<is_dirty>:

  my $dirty_flag = $statuses->is_dirty;

Which returns a true/false value depending on whether the repository has any
uncommitted changes.

Second, C<get>:

  my @status = $statuses->get($group)

Which returns an array of Git::Wrapper::Status objects, one per file changed.

There are four status groups, each of which may contain zero or more changes.

=over

=item * indexed : Changed & added to the index (aka, will be committed)

=item * changed : Changed but not in the index (aka, won't be committed)

=item * unknown : Untracked files

=item * conflict : Merge conflicts

=back

Note that a single file can occur in more than one group.  Eg, a modified file
that has been added to the index will appear in the 'indexed' list.  If it is
subsequently further modified it will additionally appear in the 'changed'
group.

A Git::Wrapper::Status object has three methods you can call:

  my $from = $status->from;

The file path of the changed file, relative to the repo root.  For renames,
this is the original path.

  my $to = $status->to;

Renames returns the new path/name for the path.  In all other cases returns
an empty string.

  my $mode = $status->mode;

Indicates what has changed about the file.

Within each group (except 'conflict') a file can be in one of a number of
modes, although some modes only occur in some groups (eg, 'added' never appears
in the 'unknown' group).

=over

=item * modified

=item * added

=item * deleted

=item * renamed

=item * copied

=item * conflict

=back

All files in the 'unknown' group will have a mode of 'unknown' (which is
redundant but at least consistent).

The 'conflict' group instead has the following modes.

=over

=item * 'both deleted' : deleted on both branches

=item * 'both added'   : added on both branches

=item * 'both modified' : modified on both branches

=item * 'added by us'  : added only on our branch

=item * 'deleted by us' : deleted only on our branch

=item * 'added by them' : added on the branch we are merging in

=item * 'deleted by them' : deleted on the branch we are merging in

=back

See git-status man page for more details.

=head3 Example

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

=head1 COMPATIBILITY

On Win32 Git::Wrapper is incompatible with msysGit installations earlier than
Git-1.7.1-preview20100612 due to a bug involving the return value of a git
command in cmd/git.cmd.  If you use the msysGit version distributed with
GitExtensions or an earlier version of msysGit, tests will fail during
installation of this module.  You can get the latest version of msysGit on the
Google Code project page: L<http://code.google.com/p/msysgit/downloads>

=head1 SEE ALSO

L<VCI::VCS::Git> is the git implementation for L<VCI>, a generic interface to
version-controle systems.

Git itself is at L<http://git.or.cz>.

=head1 BUGS

Please report any bugs or feature requests to
C<bug-git-wrapper@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.  I will be notified, and then you'll automatically be
notified of progress on your bug as I make changes.

=cut
