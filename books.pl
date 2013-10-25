#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use feature qw/say switch/;

use File::Basename qw/dirname/;
use File::Find;
use File::Path qw/make_path/;
use File::Temp qw/tempdir/;
use Getopt::Std;
use IPC::Open3;
use XML::Fast;
use Symbol qw/gensym/;

sub encode {return $_[1]}

our $VERSION = '1.0';
$Getopt::Std::STANDARD_HELP_VERSION = 1;

my @formats = qw/fb2 fb2.zip/;
# my @formats = qw/fb2/;
my ($file_re, $exclude_re);
my %opts = ();
my ($inputdir, $outputdir);
my $cnt = 0;

init();
main();

sub init {
	binmode STDOUT, ':utf8';
	unless(getopts('fmpx:1', \%opts)) {
		usage();
		exit 1;
	}
	if ($opts{f} and $opts{p}) {
		say "-f and -p options are incompatible";
		usage();
		exit 1;
	}
	($inputdir, $outputdir) = @ARGV[0,1];
	unless ($inputdir and $outputdir and -d $inputdir and -d $outputdir) {
		print STDERR "Something wrong with your input.\n";
		usage();
		exit 1;
	}
	my $re = '\\.(' . join('|', @formats) . ')$';
	$file_re = qr/$re/i;

	$exclude_re = qr/$opts{x}/ if $opts{x};
}

sub main {
	finddepth({ wanted => \&wanted, no_chdir => 1, }, $inputdir);
	say "Total files: $cnt";
}

sub wanted {
	rmdir $File::Find::name if -d $File::Find::name;
	return unless $_ =~ $file_re;
	return if $exclude_re and $File::Find::name =~ $exclude_re;
	my $format = $1;
	my $book = parse($format, $File::Find::name);
	unless ($book) {
		warn "Failed parsing \"$File::Find::name\"\n";
		return;
	}

	if ($opts{f}) {
		my $newname = $outputdir . '/' . $book->{newfilename};
		make_path(dirname $newname);
		my $ok = $opts{m} ? rename($File::Find::name, $newname) : link($File::Find::name, $newname);
		unless ($ok) {
			warn "Failed action on '$File::Find::name'";
			return;
		}
	} elsif ($opts{p}) {
		my $newname = $outputdir . '/' . $book->{newfilename};
		say (($opts{m} ? 'rename' : 'link') . " '$File::Find::name' '$newname'");
	}

	$cnt++;
}

sub parse {
	my ($format, $filename) = @_;
	my %parser = (
		'fb2'     => \&parse_fb2,
		'fb2.zip' => \&parse_fb2zip );
	return unless $parser{$format};
	return $parser{$format}->($filename);
}

sub parse_fb2 {
	my ($fname) = @_;
	my $info = { format => 'fb2' };
	my $book;
	{
		local $/ = undef;
		open my $IN, '<', $fname or die "Failed opening '$fname': $!";
		my $contents = <$IN>;
		close $IN or die "Failed closing '$fname': $!";
		$book = xml2hash $contents;
	}
	my $data = $book->{FictionBook}{description}{'title-info'};
	my $title = encode 'utf-8', $data->{'book-title'};
	$info->{title} = $title;
	$info->{author} = author_string($data->{author}, $title);
	$info->{series} = series($data->{sequence}, $title);
	$info->{newfilename} = book_filename($info);
	return $info;
}

sub parse_fb2zip {
	my ($fname) = @_;
	my $tmpdir = tempdir(CLEANUP => 1);
	# my $exit_ok = system qw/unzip -q -d/, $tmpdir, $fname;

	my $err;
	my $pid = open3(gensym, gensym, $err, qw/unzip -q -d/, $tmpdir, $fname);
	waitpid($pid, 0);
	my $exit_ok = $?;
	return unless $exit_ok == 0;

	my ($fb2file) = glob "$tmpdir/*.fb2";
	my $book = parse_fb2($fb2file);
	$book->{format} = 'fb2.zip';
	$book->{newfilename} = book_filename($book);
	# unlink $fb2file;
	return $book;
}

sub book_filename {
	my ($book) = @_;
	my $newname = $book->{author} . '/'
	  . ($book->{series} ? $book->{series}{name} . '/' : '')
	  . ($book->{series} && $book->{series}{num} ? $book->{series}{num} . '. ' : '' )
	  . $book->{title} . '.' . $book->{format};
	return $newname;
}

sub author_string {
	my ($author, $book) = @_;
	my $to_string = sub {encode 'utf-8', trim(join ' ', grep {$_} @{$_[0]}{qw/first-name last-name/})};
	$author = choose($author, $to_string, 'author', $book);
	return $to_string->($author);
}

sub series {
	my ($seq, $book) = @_;
	return unless $seq;
	$seq = choose($seq, sub {encode 'utf-8', $_[0]->{-name} . ' (book ' . $_[0]->{-number} . ')'}, 'series', $book);
	return { name => encode('utf-8', $seq->{'-name'}), num => $seq->{'-number'} };
}

sub choose {
	my ($val, $code, $title, $book) = @_;
	return $val unless ref($val) eq 'ARRAY';
	return $val->[0] if $opts{1};

	say "\nChoose main $title for book" . ($book ? " \"$book\"" : '');
	for my $i (1 .. @$val) {
		say "$i: " . $code->($val->[$i-1]);
	}
	{
		local $| = 1;
		print 'Your choice: ';
	}
	chomp(my $choice = <STDIN>);
	goto &choose unless $choice;
	goto &choose if $choice =~ /\D/;
	goto &choose unless $val->[$choice-1];
	return $val->[$choice-1];
}

sub trim {
	local $_ = "@_";
	s/\s+$//;
	s/^\s+//;
	return $_;
}

sub usage {
	my $usage = <<"USAGE";
Usage: $0 [options] <input directory> <output directory>

Available options:
  -f  force action (actually do stuff, incompatible with -p)
  -p  print actions that would be done if run with -f switch (incompatible with -f)
  -m  move files (default action is just copy)
  -x  perl regexp of files to exclude
  -1  use first element by default in all choices
USAGE

	print STDERR $usage;
}

sub HELP_MESSAGE() {usage()}
