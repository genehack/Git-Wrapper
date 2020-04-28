use strict;
use warnings;
use Test::More;

use File::Temp qw(tempdir);
use Git::Wrapper;

my $dir = tempdir(CLEANUP => 1);
my $git = Git::Wrapper->new($dir);

$git->init;

$git->config( 'user.name'  , 'Test User'        );
$git->config( 'user.email' , 'test@example.com' );

## test ->ERR, ->OUT

# this is an author test because I don't think github would appreciate
# everybody pulling this remote every time this module gets installed. Plus I
# don't think people want to wait for it happen. So, author test. Hopefully
# that's sufficient, it's a fairly simple bit of code.

{
  my @out = $git->remote( 'add' , 'test' , 'https://genehack@github.com/genehack/Git-Wrapper.git' );

  my $err = $git->ERR;
  is( ref $err , 'ARRAY' , 'get arrayref' );
  is_deeply( $err , [] , 'nothing on err' );

  is_deeply( \@out , [] , 'nothing on out' );
}

{
  my @out = $git->remote({ 'verbose' => 1 } , 'update' );

  my $err = $git->ERR;
  is( ref $err , 'ARRAY' , 'get arrayref' );
  print STDERR $err[0];
  like( $err->[0] , qr/POST git-upload-pack/ , 'expected content' );

  my $alt_out = $git->OUT;
  is_deeply( \@out , $alt_out , 'outputs are the same' );
}

done_testing();
