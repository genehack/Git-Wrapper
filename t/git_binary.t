#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

use File::Temp qw(tempdir);
use Git::Wrapper;

my $dir = tempdir(CLEANUP => 1);
my $git = Git::Wrapper->new($dir, 'git_binary' => 'echo' );

my @got = $git->RUN('marco');
is_deeply(\@got, ['marco'], "Wrapper runs what ever binary we tell it to");

done_testing();
