package Git::Wrapper::Log::Custom;
# ABSTRACT: Log output of the Git

sub new {
  my ($class, $id, %arg) = @_;
  return bless {
    output => q{},
    %arg,
  } => $class;
}

sub output { @_ > 1 ? ($_[0]->{output} = $_[1]) : $_[0]->{output} }

1;

=head1 DESCRIPTION

This module is the container for the full output when the C<--format> 
flag is passed as one of the arguments to L<Git::Wrapper>'s C<log> method. 

There is no attempt to parse the custom format specified as there is when
no custom C<--format> is specified.

=head1 METHODS

=head2 new

Class constructor

=head2 output 

Returns the entire output provided by C<git> when the C<--format> parameter
is specified.

No attempt is made to parse the output into individual entries. The caller
may post process the resulting output as they see fit.

=head1 SEE ALSO

=head2 L<Git::Wrapper>

=head2 L<Git::Wrapper::Log>

=head1 REPORTING BUGS & OTHER WAYS TO CONTRIBUTE

The code for this module is maintained on GitHub, at
L<https://github.com/genehack/Git-Wrapper>. If you have a patch, feel free to
fork the repository and submit a pull request. If you find a bug, please open
an issue on the project at GitHub. (We also watch the L<http://rt.cpan.org>
queue for Git::Wrapper, so feel free to use that bug reporting system if you
prefer)

=cut
