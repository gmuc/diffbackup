#!/usr/bin/perl
#--------------------------------------------------------------------------------------------------------------
# $Id$
# $URL$
# $Author$
# $Revision$
# $Date$
#--------------------------------------------------------------------------------------------------------------
use strict;
use Getopt::Long;
use Env;
use Config::General;
Getopt::Long::Configure("no_ignorecase");

sub doShCmd;

# --- define programm version

my $vDate = '$Date$';
$vDate =~ s/^[^0-9]*(.+?)\s.*\$$/$1/;

my $G_version = "2.2.0.beta8 ($vDate) ";

# --- end
our (
    $opt_v,           $G_verbose_mode, $opt_b,           $G_backup_only_mode,
    $opt_batch,       $opt_n,          $G_noaction_mode, $opt_r,
    $G_recovery_mode, $opt_d,          $G_diffonly_mode, $opt_reusefileset,
    $G_reusefileset_mode,
);

# --- alias definitionen
*G_verbose_mode      = *opt_v;
*G_recovery_mode     = *opt_r;
*G_backup_only_mode  = *opt_b;
*G_diffonly_mode     = *opt_d;
*G_noaction_mode     = *opt_n;
*G_reusefileset_mode = *opt_reusefileset;

my ($G_yyddmm,         $G_config_file, $G_base_backup_file, $G_reuseFileset,
    %G_config,         $G_start_time,  @G_data_old_cksum,   $G_test_excl_file,
    @G_currentFileset, @G_baseFileset,
);
main();
exit;

# ------ subroutines definitions --------------------------------------------------------------------
# ------ subroutines definitions --------------------------------------------------------------------
# ------ subroutines definitions --------------------------------------------------------------------
sub main {
    init();
    get_config();

    # todo: testen
    if ( $G_reusefileset_mode and !$G_reuseFileset ) {
        $G_reuseFileset = $G_config{reusefileset_default};
    }
    if ( $G_config{backupStatusFile} ne '' ) {
        my $file = $G_config{backupStatusFile};
        open FH, ">$file"
            or die "Error 026: Open error status file '$file': $!\n";
        close FH;
    }
    $G_start_time = time();

    # ------ get cksum information form baseset files
    if ( !defined $G_base_backup_file ) {
        my $file = $G_config{cksumFileBaseSet};
        open( FH, $file )
            or die "Error 022: file not open '$file' $!\n";
        @G_baseFileset = <FH>;
        close FH;
    }

    # ------ end
    $G_config{diffBackupFile} =~ s/yymmdd/$G_yyddmm/; # substitute date macro in diffBackup filename
    chdir $G_config{backUpBase}
        or die
        "Error 023: Can't change directory to backUpBase '$G_config{backUpBase}'\nCause: $!\n";

    # ??? want recover from backuparchives ???
    if ($G_recovery_mode) {
        recover();
        exit(0);
    }

    # ??? use backuponly ???
    # yes: skip make cksumfile + diff-file for backup)
    if ( !$G_backup_only_mode ) {
        determine_backup_fileset();
    }
    do_backup();
    make_current_cksum_file();

    # ??? it's not a basebackup ???
    if ( not defined $G_base_backup_file ) {
        find_new_and_changed_files();
    }
}

#---------------------------------------------------------------------------------------------------
# function: init
#
# docstatus: (ok)   Version: 1.11
#
# description:
#
# read parameteroptions; make default value if configfile not defined;  get current date
#
# interface
#
# input (O = optional)
# none
#
# output
# none
#---------------------------------------------------------------------------------------------------
sub init {
    if ( $#ARGV == -1 ) {
        usage();
    }

    my $use_help;

    # todo: test von der cmd-Line aus
    # todo: Schreiben eines Tests

    GetOptions(
        'c|config=s', \$G_config_file,
        'v|verbose',
        'd|diffonly',
        'version' => sub { print "\ndiff_backup.pl Version: $G_version\n\n"; exit },
        'batch',
        'ink',
        'reusefileset:s', \$G_reuseFileset,
        'n|noaction',
        'r|recover',
        't|testexcl:s', \$G_test_excl_file,      # for test exlude pattern
        'base:s',       \$G_base_backup_file,    # optional filename basebackup
        'b|backuponly',
        'h|help|?', sub { $use_help = 1 }
    );

    $G_config_file = "$ENV{HOME}/.diffBackUp.conf"
        if ( !$G_config_file and -e "$ENV{HOME}/.diffBackUp.cfg" );

    if ( !$G_config_file ) {
        if ( -e "/etc/diffBackUp.cfg" ) {
            $G_config_file = "/etc/diffBackUp.cfg";
        }
        else {
            print "configFile is required argument\n\n";
            usage();
        }
    }

    my @gentime = localtime(time);
    $gentime[5] -= 100;
    $gentime[4]++;
    $gentime[5] =~ s/^(.)$/0$1/;
    $gentime[4] =~ s/^(.)$/0$1/;
    $gentime[3] =~ s/^(.)$/0$1/;
    $G_yyddmm = "$gentime[5]$gentime[4]$gentime[3]";

    if ($use_help) {
        usage('not_exit');

        print "\nused config: $G_config_file\n";

        exit 1;
    }
}

#---------------------------------------------------------------------------------------------------
# function: get_config
#
# docstatus: (ok)   Version: 1.11
#
# description:
#
# read config::General like config file. check required parameters. Output parameters if verbose mode
#
# interface
#
# input (O = optional)
# none
#
# output
# none
#---------------------------------------------------------------------------------------------------
sub get_config {
    my $conf = new Config::General(
        -ConfigFile      => $G_config_file,
        -InterPolateVars => 1
    );
    %G_config   = $conf->getall;
    $DB::single = 1;
    my $badConfig;

    # ------ check required parameter
    my @requiredParam = qw(baseBackNr backupBaseDate searchDirs);

    # wird der Argument "base" benutzt???
    push @requiredParam, "baseBackupFile" if ( !defined $G_base_backup_file );
    foreach (@requiredParam) {
        if ( !$G_config{$_} ) {
            print "Configurationparameter '$_' missing!\n";
            $badConfig = 1;
        }
    }
    die "\n\nError 024: Incomplete configurationfile.'$G_config_file'!\n\n"
        if $badConfig;

    # ------ end
    # ??? work in verbose mode ???
    # yes: output read configuration
    if ($G_verbose_mode) {
        my ( $mi, $hh, $dd, $mm, $yyyy ) = (localtime)[ 1 .. 5 ];
        printf "Starttime %.2d.%.2d.%s %s:%.2d\n\n", $dd, $mm + 1, $yyyy + 1900, $hh, $mi;
        print "Configuration:\n\nparameter = value;\n";
        foreach ( sort keys %G_config ) {
            print "$_ =$G_config{$_};\n";
        }
        print "Environment:\n\nparameter =value;\n";
        foreach ( sort keys %ENV ) {
            print "\n$_=$ENV{$_};";
        }
        print "\n\n";
    }
    my $home = `cd ~; pwd`;
    chop $home;

    # ??? is backUpBase NOT defined ???
    # yes: set backUpBase default value
    if ( $G_config{backUpBase} eq '' ) {
        $G_config{backUpBase} = $home;
    }

    # ??? is diffBackDir NOT defined ???
    # yes: set diffBackDir default value
    if ( $G_config{diffBackDir} eq '' ) {
        $G_config{diffBackDir} = "$home/diffBackup";
        if ( !-e $G_config{diffBackDir} ) {
            if ( !mkdir $G_config{diffBackDir} ) {
                die "Error 027: can't make backup directory\n$!\n";
            }
        }
    }
    if ( $G_config{backupName} eq '' ) {
        $G_config{backupName} = "diffbackup";
    }
    if ( $G_config{cksumFileCurrStat} eq '' ) {
        $G_config{cksumFileCurrStat} = "$G_config{backupName}.curr_userdata.cksum";
    }
    if ( $G_config{diffFileSet} eq '' ) {
        $G_config{diffFileSet} = "$G_config{backupName}.diffFileSet.userdata.txt";
    }
    if ( $G_config{backupStatusFile} eq '' ) {
        $G_config{backupStatusFile} = "$G_config{backupName}.statusFile.txt";
    }
    if ( $G_config{cksumFileBaseSet} eq '' ) {
        $G_config{cksumFileBaseSet} =
            "$G_config{backupName}.$G_config{backupBaseDate}.userdata.base$G_config{baseBackNr}.cksum";
    }
    $G_config{diffBackDir} =~ s/\/\s*$//;    # delete whitespace on string end
    if ( !( -r $G_config{diffBackDir} and -x $G_config{diffBackDir} ) ) {
        die "Error 028: backup directory '$G_config{diffBackDir}' is not accessable or readable\n";
    }
    my @parameter_list = qw(
        cksumFileCurrStat diffFileSet diffBackupFile
        baseBackupFile cksumFileBaseSet exclPatt
        backupStatusFile
    );
    foreach my $param_name (@parameter_list) {
        if ( $G_config{$param_name} !~ /^\// ) {
            $G_config{$param_name} = $G_config{diffBackDir} . '/' . $G_config{$param_name};
        }
    }
}

#---------------------------------------------------------------------------------------------------
# function: prepare_base_backup_filename
#
# prepare
#
# input (O = optional)
# none
#
# output
# none
#---------------------------------------------------------------------------------------------------
sub prepare_base_backup_filename {

    # take backupfile from arguments ???
    if ( $G_base_backup_file ne '' ) {
        $G_config{cksumFileCurrStat} = $G_base_backup_file;
        $G_config{cksumFileCurrStat}
            =~ s/\.(tgz|tar|cksum)\s*$//;    # cut not recommended filename extention
        $G_config{cksumFileCurrStat} .= ".cksum";
    }

    # take name backupfile from configfile
    elsif ( $G_config{baseBackupFile} ne '' ) {
        $G_base_backup_file = $G_config{baseBackupFile};
        $G_config{cksumFileCurrStat} = $G_config{cksumFileBaseSet};
    }
    else {
        die
            "Error 001: Parameter 'baseBackupFile' is not defined in configuration file '$G_config_file'!\n";
    }
    $G_base_backup_file =~ s/yymmdd/$G_yyddmm/;
}

#---------------------------------------------------------------------------------------------------
# function: determine_backup_fileset
#
# description:
#
# Make a filelist from all directorys included in backup. Exclude all files match on exclude
# patterns. Determine for all files cksum. Compare this list with cksum from basebackup and
# generate a filelist with all new and changed files for tar backup.
#
# interface
#
# input (O = optional)
# none
#
# output
# none
#---------------------------------------------------------------------------------------------------
sub determine_backup_fileset {
    $DB::single = 1;
    my ($command);

    # $G_base_backup_file == undef -> if no using of startflag "base"
    # ??? create base backup ???
    # yes: define cksumFileCurrStat
    if ( defined $G_base_backup_file ) {
        prepare_base_backup_filename();
    }

    # cksum file to store cksum from all current files in the backup fileset
    my $file = $G_config{cksumFileCurrStat};

    # ??? exists cksum file ???
    # yes: make a backup from last version of cksum file & read the complete
    # cksum for later check of file changes
    if ( -e $file ) {
        open FH, $file or die "Erorr 002: Can't open file '$file'!\nError:\n$!\n";
        `cp $file $file.old`;
        @G_data_old_cksum = <FH>;
    }

    # --- determine current filelist
    my $curr_file_list;

    # todo: doku & test
    if ($G_reuseFileset) {
        $curr_file_list = $G_reuseFileset;
    }
    else {

        # make filelist by find
        $curr_file_list = "$G_config{diffBackDir}/curr_files.tmp.txt";
        $command        = "find $G_config{searchDirs} -type f 2>&1 1> $curr_file_list";
        doShCmd $command, $G_verbose_mode, $G_noaction_mode;
    }
    if ($G_verbose_mode) {
        print "\nList of all found files without filter  in: $curr_file_list\n";
    }

    # --- end
    # ??? is exlude pattern file defined in commandline arguments ???
    # yes: overwrite definition in configfile
    if ( defined $G_test_excl_file and $G_test_excl_file ne '' ) {
        $G_config{exclPatt} = $G_test_excl_file;
    }

    # make exclude pattern from exclude pattern file
    my ( $raw_pattern, $excl_pattern ) = get_patterns( $G_config{exclPatt} );

    # ??? is exclude pattern test mode and no pattern is defined in pattern file
    # yes: die because without pattern is no test possible
    if ( defined $G_test_excl_file
        and ( !defined $excl_pattern or $excl_pattern eq '' ) )
    {
        die
            "Error 003: There is no exclude pattern in pattern file '$G_config{exclPatt}' in test-exclude-pattern mode\n";
    }

    my $excluded_files = exclude_files_from_fileset(
        "$G_config{diffBackDir}/excluded_files.tmp.txt",
        $G_config{cksumFileCurrStat},
        $curr_file_list, $excl_pattern
    );

    # ??? is exclude pattern TEST mode used ???
    # yes: exit diffbackup why exclude pattern test job is finished
    if ( defined $G_test_excl_file ) {
        print "\nTest for excludepattern:\n\n"
            . "diffBackup base dir: '$G_config{backUpBase}'\n\n"
            . "file search dirs: '$G_config{searchDirs}'\n\n"
            . "all found files: '$curr_file_list'\n\n"
            . "exclude pattern: \n$raw_pattern\n"
            . "excluded files:\n"
            . eval { join "\n", @{$excluded_files} } . "\n\n";
        exit 0;
    }

    # cksumfile basefileset is empty is a baseback is run
    $G_config{cksumFileBaseSet} = " / dev / null "
        if ( defined $G_base_backup_file );

    # make list of files for backup tar file
    diffcksum();

    # ??? is exclude pattern TEST mode used ???
    # yes: exit programm
    if ($G_diffonly_mode) {
        print " Filedifferenz : $G_config{diffFileSet} \n ";
        exit 0;
    }
}

# todo: Doku & test
# todo: TEST > cksum abschaltbar bei Patternstests
#---------------------------------------------------------------------------------------------------
# function: exclude_files_from_fileset
#
# description:
#
# Exclude files from current fileset by useing an exclude pattern.
# Determine and log from all included files cksum data.
#
# interface
#
# input (O = optional)
# 1. $log_file_excl_pattern - name of logfile for excluded pattern
# 2. $cksum_file            - name of cksum-file
# 3. $current_files         - name of current fileset
# 4. $excl_pattern          - pattern for exclude files
#
# output
# 1. \@excluded_files - List of all excluded files
#---------------------------------------------------------------------------------------------------
sub exclude_files_from_fileset {
    my ( $log_file_excl_pattern, $cksum_file, $current_files, $excl_pattern ) = @_;

    # avoid a null exlcude pattern
    $excl_pattern = '' if ( !defined $excl_pattern );
    my ( $ret, $status, $command );
    my @excluded_files;

    # open log of excluded files
    my $file = $log_file_excl_pattern;
    open FH_EXCL, " > $file "
        or die " Error 004 : Can't open file '$file' !\nError : \n $!\n ";

    if ( !defined $G_test_excl_file ) {

        # open new file for cksum data current files
        $file = $cksum_file;
        open FH_CKSUM, " > $file "
            or die " Error 004 : Can't open file '$file' !\nError : \n $!\n ";
    }

    # open list of current files
    $file = $current_files;
    open FH, $file
        or die " Error 004 : Can't open file '$file' !\nError : \n $!\n ";
    my $workdir = `pwd`;
    chomp $workdir;

    # determine save file list
    while ( $file = <FH> ) {
        chop $file;

        # ??? exclude file from save fileset ???
        if ( $file =~ /$excl_pattern/ ) {
            print FH_EXCL "$file \n ";
            push @excluded_files, $file;
            next;
        }

        # ??? is exclude pattern TEST mode used ???
        # yes: proceed next file, why don't need generate a save fileset
        if ( defined $G_test_excl_file ) {
            next;
        }

        # ??? file for cksum not exists ???
        if ( !-e $file ) {
            warn " Error 031 : File not exists workdir '$workdir' file '$file' for cksum !\n ";
            next;
        }

        # ??? file for cksum isn't a plain file  ???
        if ( !-f $file ) {
            warn
                " Error 032 : File workdir '$workdir' file '$file' for cksum, isn't a plain file !\n ";
            next;
        }

        # prepare filename for `` execution
        $file =~ s/\$/\\\$/g;
        $file =~ s/ /\ /g;

        # ??? NO Test exclude pattern ???
        # yes: determine cksum data & log to cksum file
        if ( !defined $G_test_excl_file ) {

            # execute file cksum and write it in cksum file current fileset
            $command = " cksum \"$file\"";
            $ret     = `$command 2>&1`;
            $status  = $? >> 8;
            if ($status) {
                warn "Error 029: Execution of command\n$command\n$ret\nworkingdir:$workdir\n";
            }
            else {
                print FH_CKSUM $ret;
            }
        }
    }
    close FH_EXCL;
    close FH_CKSUM;
    return \@excluded_files;
}

#---------------------------------------------------------------------------------------------------
# function: diffcksum
#
# docstatus: (ok)   Version: 1.11
#
# description:
#
# generate differencefileset between basefileset and current fileset
#
# interface
#
# input
# none
#
# output
# none
#---------------------------------------------------------------------------------------------------
sub diffcksum {
    my $file = $G_config{cksumFileCurrStat};
    open( SET_CURRENT, $file ) or die "Error 007: file not open '$file' $!\n\n";
    $file = $G_config{diffFileSet};
    open( DIFF_FILE_SET, ">$file" )
        or die "Error 008: file not open '$file' $!\n\n";
    my %baseFileset;

    # push basefileset in a hash to use it execute diff fileset with high performance
    foreach (@G_baseFileset) {
        $baseFileset{$_} = 1;
    }
    my ( @a, $fileName, $line_f1, $baseFile );
    while (<SET_CURRENT>) {
        $line_f1  = $_;                        # line contain checksum & filename
        @a        = split / +/, $line_f1, 3;
        $fileName = $a[2];
        push @G_currentFileset, $fileName;     # collect currentfiles for later use

        # ??? don't exists file in base fileset ???
        # yes: write file in diff fileset
        if ( !exists( $baseFileset{$line_f1} ) ) {
            print DIFF_FILE_SET $fileName;
        }
    }
    close DIFF_FILE_SET;
}

#---------------------------------------------------------------------------------------------------
# function: make_rm_list
#
# docstatus: (ok)   Version: 1.11
#
# description:
#
# Generate a list of files from base fileset, which are removed in current filelist. Write
# removed filelist in a file.
#
# interface
#
# input (O = optional)
# none
#
# output
# none
#---------------------------------------------------------------------------------------------------
sub make_rm_list {
    my $file = $G_config{diffBackupFile};
    open( RM_LIST, ">${file}.rmlist.txt" )
        or die "Error 009: file not open '$file' $!\n\n";
    my ( @a, $file_is_removed, $baseFile );

    # look for all files from base files if file is removed or not
    foreach (@G_baseFileset) {
        @a               = split / +/, $_, 3;
        $baseFile        = $a[2];
        $file_is_removed = 1;

        # search file from base filelist in current filelist
        foreach my $currentFile (@G_currentFileset) {

            # file is still in current fileset
            if ( $baseFile eq $currentFile ) {
                $file_is_removed = 0;
            }
        }

        # file is removed in current fileset
        if ($file_is_removed) {
            print RM_LIST $baseFile;
        }
    }
}

#---------------------------------------------------------------------------------------------------
# function: do_backup
#
# docstatus: (ok)   Version: 1.11
#
# description:
#
# make tar backupfile and contentfile tar backuparchiv and print out alle backup relevant file and
# largest backuped files
#
# interface
#
# input (O = optional)
# none
#
# output
# none
#---------------------------------------------------------------------------------------------------
sub do_backup {
    my $backupFile = $G_config{diffBackupFile};

    # you want a basebackup ???
    if ( defined $G_base_backup_file ) {

        # get name of basebackup from commandargs
        $backupFile = $G_base_backup_file;

        # prevent remove an old basebackup
        if ( -e $backupFile ) {
            if ($opt_batch) {
                print "Basebackup with name '$backupFile' overwrite!\n";
            }
            else {
                print
                    "Already exists a base backup with the name '$backupFile'!\n\nFile overwrite überschreiben? (y/n)";
                chop( my $overwrite = <> );
                if ( $overwrite ne "y" ) {
                    die "Error 010: Abort backup, why backupfile '$backupFile' already exist!!!\n";
                }
            }
        }
    }

    # Backupfile absolute Path is not given???
    # yes: take current dir a destination dir for backupfile
    if ( not $backupFile =~ /^\// ) {
        $_ = `pwd`;
        s/\/\s*$//s;    # cut last / from path
        $backupFile = "$_/$backupFile";
    }
    my $err_tar_log     = "${backupFile}.err";
    my $content_tar_log = "${backupFile}.content.txt";
    print <<END;
    
diff_backup.pl $G_version

Configfile:        $G_config_file

Savefileset:       $G_config{diffFileSet}

Tar error log:     $err_tar_log

Tar content log:   $content_tar_log

Exludepatternfile: $G_config{exclPatt}

Differencefileset: $G_config{diffFileSet}

cksum Savefileset: $G_config{cksumFileCurrStat}

cksum Basefileset: $G_config{cksumFileBaseSet}
END

    # make backup tar file
    my $command =
        "tar cvzf $backupFile --ignore-failed-read -T $G_config{diffFileSet} 2>$err_tar_log";
    doShCmd $command, $G_verbose_mode, $G_noaction_mode;

    # ??? error log has no content ???
    if ( -z $err_tar_log ) {
        unlink $err_tar_log
            or die "Error 011: Fehler beim unlink der Datei $err_tar_log!\n$!\n";
    }

    # ??? exist a backupfile ???
    # yes: generate a content file and sort file after size
    if ( !-z $backupFile ) {
        if ( $G_config{backupStatusFile} ne '' ) {
            my $file = $G_config{backupStatusFile};
            open FH, ">$file"
                or die "Error 025: Open error status file '$file': $!\n";
            print FH $backupFile . "\n";
            close FH;
        }
        doShCmd "tar tvzf $backupFile >$content_tar_log", $G_verbose_mode, $G_noaction_mode;
        open FH, $content_tar_log
            or die "Error 012: Open error file '$content_tar_log': $!\n";
        my @lines = <FH>;
        open FH, ">$content_tar_log"
            or die "Error 013: Open error file '$content_tar_log': $!\n";
        foreach (@lines) {
            my @a = split /\s+/, $_, 4;
            printf FH "%10.10d %s", $a[2], $a[3];
        }
        close FH;
        doShCmd "sort -k1 -r $content_tar_log > $content_tar_log.sort", $G_verbose_mode,
            $G_noaction_mode;
        doShCmd "mv $content_tar_log.sort $content_tar_log", $G_verbose_mode, $G_noaction_mode;

        #make_rm_list();
    }
    my $head_lines = 20;

    my $files;

    # ??? it's a base backup ???
    if ( $backupFile eq $G_config{baseBackupFile} ) {

        $files = `ls -lh $backupFile`;
    }
    else {    # ??? commen backup ???
        $files = `ls -lh $backupFile $G_config{baseBackupFile}`;
    }

    if ( defined $files ) {
        print "\nBackupfile:\n";

        my @file_list = split /\n/, $files;

        foreach (@file_list) {
            my @b = split / +/;
            printf "%6.6s %s %s %s %s\n", $b[4], $b[5], $b[6], $b[7], $b[8];
        }

        print "\n\n";
    }

    my $largest = `head -$head_lines $content_tar_log`;

    print "\nFirst $head_lines largest entries in backup archiv:\n\n";
     
    foreach my $file (split /\n/,$largest){
      
      my @a = split / +/, $file;
      
      my $ret = `ls -lh $a[3]`; 
      my @b = split / +/, $ret;
      print "$b[4] $a[3]\n";
    }
    
    print "\n\n";
}

#---------------------------------------------------------------------------------------------------
# function: get_patterns
#
# docstatus: (ok)   Version: 1.11
#
# description:
#
# Read patternlist from patternfile. Lists from patternfiles are or joined.
#
# interface
#
# input (O = optional)
# 1. @patternfiles - list of patternfiles
#
# output
# 1. @pattern      - list of patterns read from patternfiles
#---------------------------------------------------------------------------------------------------
sub get_patterns {
    my (@patternfiles) = @_;
    my @pattern_list;
    my $raw_pattern;

    # proceed all patternfiles
    foreach my $file (@patternfiles) {

        # ??? is filename not empty ???
        if ( $file ne '' ) {
            open FH, $file
                or die "Error 014: Can't open file '$file'!\nError:\n$!\n";
        }
        else {
            push @pattern_list, '';
            next;
        }
        my @lines;
        my $pattern = '';

        # read complete pattern list
        # ignore empty lines and lines beginning with \s*#
        foreach (<FH>) {
            chop;
            next if (/^\s*$|^\s*#/);
            $raw_pattern .= "$_\n";
            push @lines, $_;
        }

        # generate a or joined pattern list
        if ( @lines >= 2 ) {
            $pattern = join( "|", @lines );
        }
        else {
            $pattern = $lines[0];
        }

        # --- validate pattern
        eval { "" =~ /$pattern/ };
        if ($@) {
            die "\nError 015: Error in pattern patternfile '$file'!\n\n'$@'\n";
        }

        # --- end
        push @pattern_list, $pattern;
        print "patternfile: '$file'\npattern: $pattern\n" if $G_verbose_mode;
    }
    return $raw_pattern, @pattern_list;
}

#---------------------------------------------------------------------------------------------------
# function: make_current_cksum_file
#
# docstatus: (ok)   Version: 1.11
#
# description:
#
# make a cksum list from last file set and overwrite above generated cksum File
#
# interface
#
# input
# none
#
# output
# none
#---------------------------------------------------------------------------------------------------
sub make_current_cksum_file {

    # make a backup from cksum file of last fileset
    `cp $G_config{cksumFileCurrStat} $G_config{cksumFileCurrStat}.orig`;

    # --- get cksum data form last fileset and write it in a cksum cache
    my $file = $G_config{cksumFileCurrStat};
    open FH, "$file" or die "Error 016: Error on open file '$file'!\n$!\n";
    my ( %cksum_cache, $cksum, $filelen, $filename );
    while (<FH>) {
        chomp;
        ( $cksum, $filelen, $filename ) = split / +/, $_, 4;
        $cksum_cache{$filename} = "$cksum $filelen";
    }

    # --- end
    open FH, ">$file" or die "Error 017: Error on init file '$file'!\n$!\n";
    close FH;
    $file = $G_config{diffFileSet};
    open FH, $file or die "Error 018: Error on open file '$file'!\n$!\n";
    my $errflag = 0;
    my ( $count_cksum, $count_cache ) = ( 0, 0 );

    #
    while (<FH>) {
        chomp;
        s/\$/\\\$/g;    # $ mask
        s/\s*$//s;      # delete \s characters
        $filename = $_;

        # ??? is current file a plain file ???
        if ( -f "$filename" ) {

            # ??? exists a cksum in cksum cache ???
            # yes: take cache entry
            if ( exists( $cksum_cache{$filename} ) ) {
                $count_cache++;
                `echo "$cksum_cache{$filename} $filename" >> $G_config{cksumFileCurrStat} 2>&1`;
            }

            # no: make a new cksum
            else {
                $count_cksum++;
                `cksum "$_" >> $G_config{cksumFileCurrStat} 2>&1`;
            }

            # ??? errors in last cksum???
            # yes: set flag 'some errors ocurred'
            if ( $? != 0 ) {
                $errflag = 1;
            }
        }
    }
    print "count_cksum:$count_cksum, count_cache:$count_cache\n"
        if $G_verbose_mode;
    warn "Error 030: Fehler bei cksum siehe $G_config{cksumFileCurrStat}.err"
        if $errflag;
}

#---------------------------------------------------------------------------------------------------
# function: find_new_and_changed_files
#
# docstatus: (ok)   Version: 1.11
#
# description:
#
# find new & changed file since last backup
#
# interface
#
# input
# none
#
# output
# none
#---------------------------------------------------------------------------------------------------
sub find_new_and_changed_files {
    my $file = $G_config{cksumFileCurrStat};
    open( FH, $file )
        or die "Error 019: Kann File $file nicht öffnen!\nUrsache:\n$!\n";
    my @data_new_cksum = <FH>;
    print "\n\nnew Files:\n\n";
    my @changed_files;

    # loop over cksum all current files to find out new & changed files
    foreach (@data_new_cksum) {
        my @new_file_cksum = split / +/, $_, 3;
        my $is_new = 1;
        my @old_file_cksum;

        # look in old entries to find out if exist file in last backup
        # if not find file is new
        foreach my $line_old (@G_data_old_cksum) {
            @old_file_cksum = split / +/, $line_old, 3;

            # ??? file already exists in old cksum filelist ???
            # yes: break search why file is old
            if ( $new_file_cksum[2] eq $old_file_cksum[2] ) {
                $is_new = 0;
                last;
            }
        }

        # ??? file is new ???
        if ($is_new) {
            print "$new_file_cksum[2]";
        }
        else {

            # ??? cksum of a existing file has changed ???
            # yes: write file in file changed list
            if (not(    $new_file_cksum[0] eq $old_file_cksum[0]
                    and $new_file_cksum[1] eq $old_file_cksum[1] )
                )
            {
                push @changed_files, $new_file_cksum[2];
            }
        }
    }

    # --- print out file changed list
    print "\nchanged Files:\n\n";
    foreach (@changed_files) {
        print "$_";
    }

    # --- end
}

#---------------------------------------------------------------------------------------------------
# function: recover
#
# docstatus: (ok)   Version: 1.11
#
# description:
#
# recover data from backup archive
#
# interface
#
# input
# none
#
# output
# none
#---------------------------------------------------------------------------------------------------
sub recover {

    # extract data from base backup
    doShCmd "tar xvzf $G_config{baseArchive} --ignore-failed-read 2>&1", $G_verbose_mode,
        $G_noaction_mode;

    # take by default diffbackup filename configured in config file
    my $diffBackupFile = $G_config{diffBackupFile};

    # ??? diffbackup file in config have a dynamic date string in filename
    # yes: take as recover diffbackup file the latest archive
    if ( $diffBackupFile =~ /yymmdd/ ) {
        my $diffBackUpPattern = $G_config{diffBackupFile};
        $diffBackUpPattern =~ s/yymmdd/[0-9][0-9][01][0-9][0-3][0-9]/;
        my @files = sort split /\s/, `ls $diffBackUpPattern`;
        $diffBackupFile = $files[$#files];
    }

    # extract data from diff backup
    doShCmd "tar xvzf $diffBackupFile --ignore-failed-read 2>&1", $G_verbose_mode, $G_noaction_mode;

    # ??? is flag for removing old files set in config ???
    if ( $G_config{rmOldFiles} eq 'y' ) {
        my $rmFiles = $diffBackupFile . '.rmlist.txt';

        # ??? exists rm Filelist to current diffbackup ???
        if ( -e $rmFiles ) {
            my $interactiv;

            # ??? is flag for interactiv removing old files set in config ???
            if ( $G_config{rmInteractiv} eq 'y' ) {
                $interactiv = '-i';
            }
            my $file = $rmFiles;
            open( FILE, $file )
                or die "Error 020: Kann File $file nicht öffnen!\nUrsache:\n$!\n";
            foreach (<FILE>) {
                `rm $interactiv $_`;
            }
        }
    }
}

#---------------------------------------------------------------------------------------------------
# function: doShCmd
#
# docstatus: (ok)   Version: 1.11
#
# description:
# execute system command and give back the command return value and command output
#
# interface
#
# input  (O = optional)
# 1.    $shCmd    - system command to execute
# 2.(O) $debug    - flag debug output
#                   0 = no, 1 = yes
# 3.(O) $noaction - flag supress command execution
#                   0 = no, 2 = yes
#
# output
# 1. $status - nummeric return status of executed command
# 2. $output - commant output of command to (default stdio)
#              STDIO & STDERR: doShCmd "tar xvzf BackupFile.tar 2>&1"
#              STDERR only: doShCmd "tar xvzf BackupFile.tar 2>&1 1>/dev/null"
#---------------------------------------------------------------------------------------------------
sub doShCmd {
    my ( $shCmd, $debug, $noaction ) = @_;
    my $ret         = "";
    my $verzeichnis = `pwd`;
    $verzeichnis =~ s/\s*$//;
    print "Directory:$verzeichnis\ndoShCmd:\n$shCmd\n\n" if $debug;
    if ( !$noaction ) {
        $ret = `$shCmd`;
        my $status = $? >> 8;    # get nummeric command status

        # ??? status != 0 -> command had a problem ???
        # yes: print command output & die programm
        if ($status) {
            $ret = "" if ( !$ret );
            die <<END;
Error 021: Error on exection shellcommand!!!

commando:
$shCmd

commandooutput:
$ret

commandostatus:
'$?'

Current directory: '$verzeichnis'

END
        }
        return ( $status, $ret );
    }
}

sub usage {
    my $exit_mode = shift || 'do_exit';

    print <<END;

useage:

diff_backup.pl

[-c, --config configFile]      -configurationfile
[-v, --verbose]                -enable verbose mode
[-n, --noaction]               -only show the actions without act the action
[-d, --diffonly]               -only filedifference to basefileset determine
[-b, --backuponly]             -make a backup with the last determined differencefile
[-t, --testexcl [patternfile]] -only test an exclude pattern
[    --base [backupfile]]      -make a basebackup
[    --reusefileset [fileset]] -take an explicit Fileset, disable generate one
[    --ink]                    -make a incremental backup
[    --batch ]                 -no programmfeedback
[-r  --recover]                -recover backup
[-h, --help]                   -show help information
[    --version]                -show programmversion

END

    if ( $exit_mode eq 'do_exit' ) {
        exit 1;
    }
}

END {
    if ($G_verbose_mode) {
        my $end_time = time();
        my $ss       = ( $end_time - $G_start_time ) % 60;
        my $mm       = ( $end_time - $G_start_time - $ss ) / 60;
        print "\ndiff_backup.pl total running time $mm:$ss min\n";
    }
}
__END__

grep "Error " didiff_backupl | perl -n -e'/(Error +[0-9?]+)/; print ":$1:\n";' | sort

=pod

=head1 Bezeichnung

 diff_backup.pl - Differenzbackup bzw. Basissicherung anlegen; Recovery durchführen

=head1 Syntax

 diff_backup.pl -c Datei [-v] [-n] [-b] [-version] [-h] [-base [Datei]] [-r]

=head1 Beschreibung

B<Basissicherung>

Dabei werden alle Dateien des vordefinierten Bereichs gesichert und für diese ein cksum-File erstellt.

B<Differenzsicherung>

Dabei wird geprüft, welche Dateien sich im aktuellen Dateisystem 
bezüglich der Basissicherung geändert haben bzw. welche hinzugekommen sind
oder gelöscht wurden. Gelöschte Dateien werden in einer Datei mit der Endung ".rmlist.txt"
hinterlegt.

B<Sicherung wiederherstellen>

Aus Basis- und Differenzsicherung sowie dem Löschprotokoll kann der Originaldatenbestand 
wieder hergestellt werden.

=head1 Optionen

    -c, --config Datei  Konfigurationsfile ("Datei") für den Ablauf des Skripts
                        ohne diese Argument wird die Defaultkonfiguration in 
                        $HOME/.diffBackUp.cfg oder /etc/diffBackUp.cfg

    -v, --verbose       Skriptverlauf und Konfiguration ausgeben

    -n, --noaction      nur anzeigen was passieren würde. Aktion nicht durchführen!

    -b, --backuponly    nur Backupfile mit dem im Konfigurationfile angegeben 
                        Differenzenfile

        --base [Datei]  Basissicherung durchführen und nach "Datei" schreiben
                        Im Dateinamen wird der String "yymmdd" durch das aktuelle
                        Datum ersetzt. Fehlt "Datei" wird die Sicherungsdatei aus
                        dem Konfigurationsfile ermittelt.

        --ink           Differenzsicherung zur Basissicherung, die im Konfigfile
                        steht, durchführen

        --batch         keine interaktiven Rückfragen

    -d, --diffonly      nur Filedifferenz zum Basefileset ermitteln
    
    -r, --recover       (ist noch experimentell) Datensicherung wieder einspielen
                        alle Backupoptionen werden ignoriert
                        
        --reusefileset [Datei]
                        Option 'reusefileset' ermöglicht ein Fileset (z.B. vom letzten diff_backup Lauf) 
                        als aktuelles Fileset zu verwenden. Damit muß das diff_backup.pl kein Fileset
                        generieren. So es muß nicht aufwendig neu erstellt werden, was z.B. für den Test
                        von Backup Patterns seht nützlich ist                 
                        
    -t, --testexcl [Datei]
                        Teste die exclude Patterns in die "Datei" sind mit dem
                        aktuellen Fileset von Diffbackup

    -h, --help          Hilfeinformationen ausgeben

        --version       Programmversion ausgeben

=head1 Anlegen einer Basissicherung

Eine Basissicherung ist eine Sicherung aller Files in eine tgz-Archiv, die in der Konfiguration
als sicherungsrelevant definiert wurden. 

Um eine Basissicherung anzulegen sind folgende Arbeitsschritte notwendig:

1) notwendige Parametrierung im Konfigurationsfile vornehmen (Config lokalisieren mit "diff_backup.pl -v")

In der Regel reicht die Änderung von "baseBackNr" und "backupBaseDate" aus.

Prinzipiell gilt für die verwendeten Parameter:

Pflichtparameter: baseBackNr backupName diffBackDir backUpBase backupBaseDate searchDirs
optionale Parameter: exclPatt 

2) diff_backup.pl mit folgenden Parametern starten

 diff_backup.pl [-c Datei] -base [Datei]

Wird der optionale Dateiname bei der Option "base" angegeben, erfolgt in diese Datei die
Sicherung der definierten Files. Ansonsten definiert der Parameter "baseBackupFile"
in der Konfigurationsdatei die Zieldatei der Sicherung.

Wenn base-Datei definiert ist, wird dieser Name auch für die Definition des Names des
aktuellen cksum-Protokoll verwendet. Dazu werden von dem Namen allen Endungen mit der
Bezeichnung ".tgz", ".tar" entfernt und die Endung ".cksum" angehangen.

Bei der Basissicherung werden folgende Files angelegt:
-cksum aller gesicherten Files; s. Parameter "cksumFileCurrStat"
-Liste aller gesicherten Files; s. Parameter "diffFileSet"
-Sicherungsarchiv; s. Parameter "backupFile" oder Argument der Option "base"

Existiert ein Sicherungsarchiv gleichen Namens schon, wird gefragt, ob sie überschrieben werden soll.
Im Batchmodus gibt es keine solche Rückfrage sondern nur die Ausschrift, daß das Sicherungsarchiv
überschrieben wurde.

=head1 Anlegen einer Differenzsicherung

Eine Differenzsicherung ist die Sicherung aller Files in eine tgz-Archiv, die in der Konfiguration
als sicherungsrelevant definiert wurden. Eine Differenzsicherung bezieht sich immer auf eine Basissicherung.
Es geht nur ein File in die Sicherung ein, wenn es:

-neu ist, d.h. in der Basissicherung noch nicht vorhanden ist
-geändert wurde, d.h. es ist zwar in der Basissicherung vorhanden, wurde aber inzwischen verändert

Mit der Differenzsicherung kann ein großer Datenbestand sehr platzsparend gesichert werden, wenn
sich nur eine geringer Anteil der Daten wirklich in den Sicherungsintervallen ändert.

Um eine Basissicherung anzulegen sind folgende Arbeitsschritte notwendig:

1) notwendige Parametrierung im Konfigurationsfile vornehmen

s.o. Basissicherung

2) diff_backup.pl mit folgenden Parametern starten

 diff_backup.pl -c Datei -ink

Welche Files wirklich gesichert wurden, ist in dem File protokolliert, das beim
Parameter "diffFileSet" hinterlegt wurde.

Wird zusätzlich die Option "-d" angegeben erfolgt nur die Erstellung des Files 
mit den Filedifferenzen (s. Parameter "diffFileSet"). Damit kann man prüfen,
welche Veränderungen im Datenbestand bezüglich der Basissicherung entstanden sind.
Damit kann u.U. eine zeitaufwendige Sicherung vermieden werden, wenn der Benutzer
entscheidet, daß die Veränderungen noch keiner Sicherung bedürfen.

Die Option "-b" ermöglich die Sicherung aller Dateien die als Filedifferenzen 
hinterlegt sind. Es wird das unter dem Parameter "diffFileSet" definierte File
verwendet.

=head1 Wiederherstellung eines Datenbestandes

Dieses Feature ist noch experimentell.

=head1 Das Konfigurationsfile

=head2 Allgemeine Syntax

 PARAMETER=DATEN;

 PARAMETER - Bezeichnung des Parameters. Vor dieser Bezeichnung können beliebig viele 
             Leerzeichen oder Tabs stehen.
 DATEN     - Daten die dem Parameter zugeordnete sind. Zwischen den Daten und
             Parameterbezeichnung steht ein "=". Vor und nach ihm können beliebig viele 
             Leerzeichen und/oder Tabs stehen. Die Daten enden mit einem ";" Sie
             können sich über mehrere Zeilen erstrecken.

 Leerzeilen und Kommentarzeilen mit einem vorangestellem "#" werden ignoriert.

=head2 Gültige Parameter

 * - Pflichtparameter

 baseBackNr        - *Nr des Basisbackup

 backupName        - Name des Backups der dessen Inhalt beschreibt
                     Default: diffbackup

 backupBaseDate    - *Datum der Basissicherung

 backupStatusFile  - File in dem bei erfolgreichem Backup hinterlegt wird, in welchem
                     File sich das Backup befinden. Das kann z.B. genutzt werden, um
                     das Backup auf eine DVD zu brennen.
                     Default: $backupName.statusFile.txt
 
 backUpBase        - Basisverzeichnis in das zu Beginn des Programms gewechselt wird,
                     von dem aus alle weiteren Operationen durchgeführt werden, z.B. 
                     Suchoperationen.
                     Default: $HOME

 baseBackupFile    - File in das das Basisbackup geschrieben wird. "yymmdd" im Namen
                     wird durch das aktuelle Datum ersetzt. Der Dateinamen kann durch 
                     Option "base" überschrieben werden.

 cksumFileBaseSet  - File in dem die cksum-Angaben der Files der Basissicherung stehen
                     Default: $backupName.$backupBaseDate.userdata.base${baseBackNr}.cksum

 cksumFileCurrStat - File in das die cksum-Angaben der gefundenen File geschrieben werden
                     Default: $backupName.curr_userdata.cksum

 diffBackupFile    - Backuparchiv in dem alles Files gespeichert werden die im File 
                     "diffFileSet" aufgelistet sind

 diffBackDir       - Basisverzeichnis für die Sicherungen
                     Default: $HOME/diffBackup

 diffFileSet       - File mit allen neuen und geänderteten Files bezüglich des Basisbackups.
                     Der Test erfolgt mit cksum.
                     Default: $backupName.diffFileSet.userdata.txt

 exclPatt          - File das excluding-Muster für die aktuellen cksum-Files enthält
                     d.h. alle Files die auf das Muster passen, gehen NICHT in die 
                     cksum-Ermittlung ein
                     Keine Muster auf Links verwenden, da diese nicht berücksichtigt werden.
      
 searchDirs        - *Verzeichnisse in denen rekrusiv für alle Dateien cksum ermittelt wird.
                     Bei Angabe mehrere Verzeichnisse sind diese mit Leerzeichen getrennt.
                     Alle relativen Verzeichnispfade verwenden als Rootverzeichnis den in 
                     "backUpBase" definierten Pfad. Liegt das zu durchsuchende Verzeichnis
                     also außerhalb von "backUpBase" muß ein absoluter Pfad angegeben werden,
                     um Fehler bei der Sicherung zu vermeiden.

=head2 Beispiel

 # Basisverzeichnis der searchDirs
 backUpBase=/home/username

 # Basisverzeichnis für die Sicherungen
 diffBackDir=/home/username/diffBackup

 # Verzeichnisse in denen rekrusiv für alle Datein cksum ermittelt wird
 searchDirs=.

 baseBackNr=09
 backupName=mycomputer
 backupBaseDate=20060710

 # Backuparchiv in dem alles Files gespeichert werden die im File "diffFileSet"
 # aufgelistet sind
 diffBackupFile=$backupName.yymmdd.ink$baseBackNr.tgz

 # Backuparchiv für die Basissicherung
 baseBackupFile=$backupName.$backupBaseDate.base$baseBackNr.tgz

 # File das excluding-Muster für die akutellen cksumfiles enthält
 # d.h. alle Files auf die die Muster passen, gehen nicht in die cksum-Ermittlung ein
 exclPatt=/home/mucha/wp/backup/gollum.br.exclude_userdata.pat

 # ------ redundante Parameter

 #backupStatusFile=backupStatusFile.txt

 # File in das die cksum-Angaben der gefundenen File geschrieben werden
 #cksumFileCurrStat=$backupName.curr_userdata.cksum

 # File in dem alle Files hinterlegt werden, deren cksum sich bezüglich der
 # Basissicherung geändert hat bzw. die in dieser noch nicht vorhanden sind
 #diffFileSet=$backupName.diffFileSet.userdata.txt

 # File in dem die cksum-Angaben der Files der Basissicherung stehen
 #cksumFileBaseSet= $backupName.$backupBaseDate.userdata.base09.cksum

=head1 BUGs

Recovery und anlegen von Löschlisten ist ein experimentelles Feature.

=head1 COPYRIGHT AND LICENSE

Copyright 2001-2007 by G. Mucha

This code is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
