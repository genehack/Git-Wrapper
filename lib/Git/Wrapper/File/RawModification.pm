package Git::Wrapper::File::RawModification;
# ABSTRACT: Modification of a file in a commit

use 5.006;
use strict;
use warnings;

sub new {
  my ($class, $filename, $type, $perms_from, $perms_to, $blob_from, $blob_to) = @_;

  my $score;
  if ( defined $type && $type =~ s{^(.)([0-9]+)$}{$1} ) {
    $score = $2;
  }

  return bless {
    filename   => $filename,
    type       => $type,
    score      => $score,
    perms_from => $perms_from,
    perms_to   => $perms_to,
    blob_from  => $blob_from,
    blob_to    => $blob_to,
  } => $class;
}

sub filename   { shift->{filename} }
sub type       { shift->{type} }
sub score      { shift->{score} }

sub perms_from { shift->{perms_from} }
sub perms_to   { shift->{perms_to} }

sub blob_from  { shift->{blob_from} }
sub blob_to    { shift->{blob_to} }

1;

=head1 METHODS

=head2 new

Constructor

=head2 filename

=head2 type

=head2 score

=head2 perms_from

=head2 perms_to

=head2 blob_from

=head2 blob_to

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
