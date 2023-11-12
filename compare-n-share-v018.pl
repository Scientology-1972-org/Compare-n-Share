#!/usr/bin/perl
# compare-n-share
# provide two files as input and get single command-line script as output
#
# use:
# ./compare-n-share-v002.pl list-of-friends-files.csv list-of-my-files.csv friendsTarget MyTarget

use strict;
use Getopt::Long;
Getopt::Long::Configure(qw{no_auto_abbrev no_ignore_case_always});
use List::Util qw(min max sum);
use List::MoreUtils qw(uniq);

my $usage = <<'USAGE';

############ Search for dates #############
usage: compare-n-share-v002.pl [options]
		--list-of-friends-files|-f=list-of-friends-files.csv
		--list-of-my-files|-m=list-of-my-files.csv
		--friendsTarget|--ft=friendsTarget
		--MyTarget|--mt=MyTarget
		--copy|-c="arguments for linux cp (copy command) in quotes"
		--replace|-r
		--version|-v
		--help|-h
#########################################

USAGE
my $inFILE1;
my $inFILE2;
my $friendsTarget;
my $MyTarget;
my $version;
my $preserve=" --preserve";
my $replace;

my $result = GetOptions(
	"list-of-friends-files|f=s" => \$inFILE1,
	"list-of-my-files|m=s" => \$inFILE2,
	"friendsTarget|ft=s" => \$friendsTarget,
	"replace|r=s" => \$replace,
	"MyTarget|mt=s" => \$MyTarget,
	"copy|c=s" => \$preserve,
	"version|v" => sub{$version='TRUE'},
	"help|h|?" => sub{print $usage; exit}			
);

if($version)
{
print "Version 18\n";
}


die $usage unless($inFILE1);
die $usage unless($inFILE2);
die $usage unless($friendsTarget);
die $usage unless($MyTarget);

$MyTarget=~s/\/$//;
$friendsTarget=~s/\/$//;


if(length($replace) > 0)
{
	$replace=~s/^\///;
	$replace=~s/\/$//;
	$replace.="/";
}
our $os = $^O =~ /Win/ ? "windows" : "nix";

our $delimeter = "/";
$delimeter = "\\" if $os eq "windows";
our $split_delim = $delimeter;
$split_delim = "\\\\" if $os eq "windows";
our $copyCommand = "cp -R ";
$copyCommand = "XCopy /E /I  " if $os eq "windows";
our $delCommand = "rm ";
$delCommand = "del /q " if $os eq "windows";
our $ext = "sh";
$ext = "cmd" if $os eq "windows";
our $mkdir = "  mkdir -p ";
$mkdir = "  mkdir " if $os eq "windows";

print "Indexing and sorting...";

#open $FILE1, $ARGV[0] or die "Cannot open $ARGV[0]";
#open $FILE2, $ARGV[1] or die "Cannot open $ARGV[1]";
open my $FILE1, $inFILE1 or die "Cannot open $inFILE1";
open my $FILE2, $inFILE2 or die "Cannot open $inFILE2";
# sub dumpHash defined at the end - is sorting the Hashes in temp and hidden files...
my $sortedFileName1 = dumpHash($FILE1, 1);
my $sortedFileName2 = dumpHash($FILE2, 2);

print "done\n";


print "Comparing...";
my $OUT1;
my $OUT2;
my $newHash1 = "$sortedFileName1.new";
my $newHash2 = "$sortedFileName2.new";
open $OUT1, ">".$newHash1 or die "Cannot open $newHash1";
open $OUT2, ">".$newHash2 or die "Cannot open $newHash2";
open $FILE1, $sortedFileName1 or die "Cannot open $sortedFileName1";
open $FILE2, $sortedFileName2 or die "Cannot open $sortedFileName2";

while(1)
{
  my $line1 = <$FILE1>;
  if (!$line1)
  {
    dumpTail($FILE2, $OUT2);
    last;
  }
  my $line2 = <$FILE2>;
  if (!$line2)
  {
    dumpTail($FILE1, $OUT1);
    last;
  }
compare:
  my $r = $line1 cmp $line2;
  next if $r == 0;
  if ($r == -1)
  {
    print $OUT1 $line1;
    $line1 = <$FILE1>;
    if (!$line1)
    {
      print $OUT2, $line2;
      dumpTail($FILE2, $OUT2);
      last;
    }
    goto compare;
  }
  else
  {
    print $OUT2 $line2;
    $line2 = <$FILE2>;
    if (!$line2)
    {
      print $OUT1 $line1;
      dumpTail($FILE1, $OUT1);
      last;
    }
    goto compare;
  }
}
close $OUT1;
close $OUT2;
close $FILE1;
close $FILE2;
print "done\n";

#remove temp files
system("$delCommand $sortedFileName1");
system("$delCommand $sortedFileName2");

print "Make commands left...";
makeCommands($newHash1, $inFILE1, $friendsTarget, "Friend");
print "done\n";
print "Make commands right...";
makeCommands($newHash2, $inFILE2, $MyTarget, "Me");
print "done\n";

#remove temp files
system("$delCommand $newHash1");
system("$delCommand $newHash2");

sub makeCommands
{
  my $newHash = shift;
  my $cvsFile = shift;
  my $folderRight = shift;
  my $targetPerson = shift;
  my %hash = ();
  my $FILE1;
  my $OUTL;
  open $FILE1, $newHash or die "Cannot read $newHash";
  while(my $line = <$FILE1>)
  {
    chomp $line;
    $hash{$line} = 1;
  }
  close $FILE1;  
  open $FILE1, $cvsFile or die "Cannot read $cvsFile";
  my $commandFile1 = "Copies-for-$targetPerson.$ext";
  my $ListOfFile1 = "Files-for-$targetPerson.txt";

  open $OUT1, ">".$commandFile1 or die "Cannot write file $commandFile1\n";
  open $OUTL, ">".$ListOfFile1 or die "Cannot write file $ListOfFile1\n";

# for Linux Bash and move to home folder
  print $OUT1 "#!/bin/bash\n\n" if $os ne "windows";
  print $OUT1 "cd ~\n" if $os ne "windows";
	
  #print $OUTL uc("LIST OF FILES FOR $targetPerson\n\n");
my $filenameIndex=0;
my $pathIndex=1;
my $hash=-1;
my $lineCounter=0;
  while(my $line = <$FILE1>)
  {
    $lineCounter++;
    chomp $line;
	if($lineCounter==1)
	{	#print @array;
		chomp($line); #print $line;
		my @array=split/\t/,$line;
		for(my $index = 0; $index <=scalar(@array); $index++)
		{
			if($array[$index] eq "hash")
			{
				$hash = $index;
			}
			if(uc($array[$index]) eq "PATH")
			{
				$pathIndex = $index;
			}
			if(uc($array[$index]) eq "FILENAME")
			{
				$filenameIndex = $index;
			}
		}
	print $OUTL join("\t",@array)."\tDestination\n";
	next;
	}
    my @mas = split /\t/, $line;
      if($hash==-1){
	$hash=$#mas-1;
	}
    	
    if (exists $hash{$mas[$hash]})
    {
      my @path = split $split_delim, $mas[$pathIndex];
      shift @path;
      my $nakedpath = join $delimeter, @path;

#	$mas[0] is the path, $mas[1] is the filename
# but the followning cp command will fail, as the target folder is expected to exist before the copy:
#      print $OUT1 qq{cp "$mas[0]$delimeter$mas[1]" "$folderRight$delimeter$nakedpath"\n};

#	This is the solution for Linux:
#	if [ ! -d "$2" ]; then
#	    mkdir -p "$2"
#	fi
#	cp -R "$1" "$2"
#print "--->$nakedpath\n";
$nakedpath=~s/$replace//;
print $OUTL join("\t",@mas)."\t$folderRight$delimeter$nakedpath\n";

$mas[$pathIndex]=~s/`//g;
$mas[$filenameIndex]=~s/`//g;
$nakedpath=~s/`//g;
$folderRight=~s/`//g;
$mas[$pathIndex]=~s/'//g;
$mas[$filenameIndex]=~s/'//g;
$nakedpath=~s/'//g;
$folderRight=~s/'//g;
#$mas[$filenameIndex]=~s/\W/\\W/g;
#print "\n===>@mas<===\n";
#print "$nakedpath<---\n";
      if ($os eq "windows")
      {
        print $OUT1 "$mkdir \"$folderRight$delimeter$nakedpath\"\n";
        print $OUT1 "$copyCommand \"$mas[$pathIndex]$delimeter$mas[$filenameIndex]\" \"$folderRight$delimeter$nakedpath\"\n\n";
  	    #print $OUTL "$folderRight$delimeter$nakedpath$delimeter$mas[$filenameIndex]\n";
      }
      else
      {
            
	    #print $OUT1 $copyCommand $preserve "$mas[$pathIndex]$delimeter$mas[$filenameIndex]" "$folderRight$delimeter$nakedpath"\n\n};
	    		print $OUT1 qq{if [ ! -d '$folderRight$delimeter$nakedpath' ]; then\n};
  	    		print $OUT1 qq{$mkdir '$folderRight$delimeter$nakedpath' \n};
	    		print $OUT1 qq{fi\n};
			print $OUT1 qq{$copyCommand $preserve '$mas[$pathIndex]$delimeter$mas[$filenameIndex]' '$folderRight$delimeter$nakedpath'\n\n};			
			print $OUT1 'if [ $?';
			print $OUT1 qq{ -eq 1 ]; then echo 'Failed to execute $copyCommand $preserve $mas[$pathIndex]$delimeter$mas[$filenameIndex]' ; fi\n\n};  
	#print $OUTL qq{$folderRight$delimeter$nakedpath$delimeter$mas[$filenameIndex]\n};
	  }
    }
  }
  close $OUT1;
  close $FILE1;
}



sub dumpTail
{
  my $FROM = shift;
  my $TO = shift;
  while(my $line = <$FROM>)
  {
    print $TO $line;
  }
}

sub dumpHash
# all hash-values of given file get sorted
{
 my $FILE = shift;
 my $index = shift;
 my $OUT; #print "\n==>$FILE<==\n";
 my $outIndexName = "hash$index";
 open $OUT, ">".$outIndexName or die "cannot create index file $outIndexName";
 my $hash=-1;
 my $lineCounter=0;
  while(my $line = <$FILE>)
  { #print $line;
    $lineCounter++;
    chomp $line;
	if($lineCounter==1)
	{	
		chomp($line); #print $line;
		my @array=split/\t/,$line;
		for(my $index = 0; $index <=scalar(@array); $index++)
		{
			if($array[$index] eq "hash")
			{
				$hash = $index;
			}
		}


	next;
	}
   my @mas = split /\t/, $line;
    if($hash==-1){
	$hash=$#mas-1;
	}
    
   #print $mas[$hash]."<--\n";
   print $OUT $mas[$hash]."\n";
 }
 close $OUT;
 my $sortedFileName = $outIndexName.".sorted"; 
 system("sort $outIndexName > $sortedFileName");
# system("$delCommand $outIndexName");
 return $sortedFileName;
}

