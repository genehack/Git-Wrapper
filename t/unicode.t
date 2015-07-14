use strict;
use warnings;
use Test::More;

use File::Temp qw(tempdir);
use Git::Wrapper;
use File::Spec;
use File::Path qw(mkpath);
use File::Basename qw(dirname);
use Sort::Versions;

my $dir = tempdir(CLEANUP => 1);
my $git = Git::Wrapper->new($dir);

if ( versioncmp( $git->version , '1.5.0') eq -1 ) {
  plan skip_all =>
    "Git prior to v1.5.0 doesn't support 'config' subcmd which we need for this test."
}
elsif (! Git::Wrapper::USE_ENCODE) {
  plan skip_all => 'unicode handling not supported on perl < 5.8.1';
}

my $version = $git->version;

$git->init; # 'git init' also added in v1.5.0 so we're safe

$git->config( 'user.name'  , 'Test User'        );
$git->config( 'user.email' , 'test@example.com' );

# make sure git isn't munging our content so we have consistent hashes
$git->config( 'core.autocrlf' , 'false' );
$git->config( 'core.safecrlf' , 'false' );

my %files = (
  'objects/4b/825dc642cb6eb9a060e54bf8d69288fbee4904' => unpack('u', <<'END_FILE'),
/>`$K*4I-53!@```*+`(!
END_FILE
  'objects/72/f435d3883ab383adc19088640b78a5d66cec2a' => unpack('u', <<'END_FILE'),
M>`%UC4$*PC`015WW%',!)8UI2*!(%X*(>(A).FV#35+&"%[(DW@QI;AU\Q>/
M]_@^QQ@*U$9N"A.!<D8VO==*>J?)611:4*/<8'IMI3&#(U)6J`H?9<H,1QR'
MD!*<YX@<X(HIW=^O&S&T844=/3$N,^TRCP>HU5X;K865L!5*B,JO_^7KGQ@G
4C'!)>8%V0N2Q6_=/^"NK#S.Q/#<`
END_FILE
  'refs/heads/master' => "72f435d3883ab383adc19088640b78a5d66cec2a\n",
);

for my $fn (keys %files) {
  my $full = File::Spec->catfile($dir, '.git', $fn);
  my $dir = dirname($full);
  mkpath($dir);
  open my $fh, '>', $full or die "can't write to $full: $!";
  binmode $fh;
  print { $fh } $files{$fn};
  close $fh;
}

my $author = "Dagfinn Ilmari Manns\x{00E5}ker <ilmari\@example.org>";

{
  my @log = $git->log;
  is $log[0]->author, $author, 'reading UTF-8 log works';
}

{
  my ($hash) = $git->hash_object({ stdin => 1, -STDIN => $author });

  is $hash, '568e1f3c53614a4dc80d6c08e1206fed6704622f',
    'UTF-8 sent by STDIN works';
}

{
  $git->commit({ allow_empty => 1, message => 'commit', author => $author });

  my @log = $git->log;
  is $log[0]->author, $author, 'UTF-8 sent by command args works';
}

done_testing;
