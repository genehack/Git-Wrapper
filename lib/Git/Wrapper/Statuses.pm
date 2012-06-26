package Git::Wrapper::Statuses;
# ABSTRACT: 

use 5.006;
use strict;
use warnings;

use Git::Wrapper::Status;

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

=head1 METHODS

=head2 add

=head2 get

=head2 is_dirty

=head2 new

=head1 SEE ALSO

=head2 L<Git::Wrapper>

=head1 REPORTING BUGS & OTHER WAYS TO CONTRIBUTE

The code for this module is maintained on GitHub, at
L<https://github.com/genehack/Git-Wrapper>. If you have a patch, feel free to
fork the repository and submit a pull request. If you find a bug, please open
an issue on the project at GitHub. (We also watch the L<http://rt.cpan.org>
queue for Git::Wrapper, so feel free to use that bug reporting system if you
prefer)

=cut
