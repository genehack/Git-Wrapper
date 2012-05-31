package Git::Wrapper::Exception;
# ABSTRACT: Exception class for Git::Wrapper

use 5.006;
use strict;
use warnings;

sub new { my $class = shift; bless { @_ } => $class }

use overload (
  q("") => '_stringify',
  fallback => 1,
);

sub _stringify {
  my ($self) = @_;
  my $error = $self->error;
  return $error if $error =~ /\S/;
  return "git exited non-zero but had no output to stderr";
}

sub output { join "", map { "$_\n" } @{ shift->{output} } }
sub error  { join "", map { "$_\n" } @{ shift->{error} } }
sub status { shift->{status} }

1;

=head1 METHODS

=head2 error

=head2 new

=head2 output

=head2 status

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
