#! perl

use strict;
use warnings;
use utf8;

use Test::More;

use Git::Wrapper;

use File::Path qw(mkpath);
use File::Spec;
use File::Temp qw(tempdir);
use IO::File;
use Sort::Versions;

my $dir = tempdir(CLEANUP => 1);
my $git = Git::Wrapper->new($dir);

my $version = $git->version;
if ( versioncmp( $git->version , '1.5.0') eq -1 ) {
  plan skip_all =>
    "Git prior to v1.5.0 doesn't support 'config' subcmd which we need for this test."
  }

diag( "Testing git version: " . $version );

$git->init;                    # 'git init' also added in v1.5.0 so we're safe

$git->config( 'user.name'  , 'Test User'        );
$git->config( 'user.email' , 'test@example.com' );

# make sure git isn't munging our content so we have consistent hashes
$git->config( 'core.autocrlf' , 'false' );
$git->config( 'core.safecrlf' , 'false' );

mkpath(File::Spec->catfile($dir, 'foo'));
IO::File->new(File::Spec->catfile($dir, qw(foo bar)), '>:raw')->print("hello bär\n");
$git->add('.');

my $author = 'Dagfinn Ilmari Mannsåker <ilmari@example.org>';

$git->commit({ message => 'first commit', author => $author });

my @log = $git->log();
#utf8::encode($author); # because the log output is octets
is($log[0]->author, $author);

use Devel::Peek;
Dump($log[0]->author);

done_testing();
