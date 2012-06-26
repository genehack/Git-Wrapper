package Git::Wrapper::Status;
# ABSTRACT: A specific status information in the Git

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

1;

=head1 METHODS

=head2 new

=head2 mode

=head2 from

=head2 to

=head1 SEE ALSO

=head2 L<Git::Wrapper>

=head2 L<Git::Wrapper::Statuses>

=head1 REPORTING BUGS & OTHER WAYS TO CONTRIBUTE

The code for this module is maintained on GitHub, at
L<https://github.com/genehack/Git-Wrapper>. If you have a patch, feel free to
fork the repository and submit a pull request. If you find a bug, please open
an issue on the project at GitHub. (We also watch the L<http://rt.cpan.org>
queue for Git::Wrapper, so feel free to use that bug reporting system if you
prefer)

=cut
