#!/usr/bin/perl -w
#
# Module: vyatta_update_resolv.pl
#
# **** License ****
# Version: VPL 1.0
#
# The contents of this file are subject to the Vyatta Public License
# Version 1.0 ("License"); you may not use this file except in
# compliance with the License. You may obtain a copy of the License at
# http://www.vyatta.com/vpl
#
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
# the License for the specific language governing rights and limitations
# under the License.
#
# This code was originally developed by Vyatta, Inc.
# Portions created by Vyatta are Copyright (C) 2007 Vyatta, Inc.
# All Rights Reserved.
#
# Author: Marat Nepomnyashy
# Date: December 2007
# Description: Script to update '/etc/resolv.conf' on commit of 'system domain-search domain' config.
#
# **** End License ****
#

use strict;
use lib "/opt/vyatta/share/perl5/";


use Getopt::Long;
my $change_dir = '';
my $modify_dir = '';
GetOptions("change_dir=s" => \$change_dir, "modify_dir=s" => \$modify_dir);


use VyattaConfig;
my $vc = new VyattaConfig();

if ($change_dir ne '') {
	$vc->{_changes_only_dir_base} = $change_dir;
}
if ($modify_dir ne '') {
	$vc->{_new_config_dir_base} = $modify_dir;
}


$vc->setLevel('system');

my @domains = $vc->returnValues('domain-search domain');
my $domain_name = $vc->returnValue('domain-name');

if (@domains > 0 && $domain_name && length($domain_name) > 0) {
	print STDERR "System configuration error.  Both \'domain-name\' and \'domain-search\' are specified, but only one of these mutually exclusive parameters is allowed.\n";
	print STDERR "System configuration commit aborted due to error(s).\n";
	exit(1);
}

my $doms = '';
foreach my $domain (@domains) {
	if (length($doms) > 0) {
		$doms .= ' ';
	}
	$doms .= $domain;
}

my $search = '';
if (length($doms) > 0) {
	$search = "search\t\t$doms\t\t#line generated by $0\n";
}

my $domain = '';
if ($domain_name && length($domain_name) > 0) {
	$domain = "domain\t\t$domain_name\t\t#line generated by $0\n";
}


# The following will re-write '/etc/resolv.conf' line by line,
# replacing the 'search' specifier with the latest values,
# or replacing the 'domain' specifier with the latest value.

my @resolv;
if (-e '/etc/resolv.conf') {
	open (RESOLV, '</etc/resolv.conf') or die("$0:  Error!  Unable to open '/etc/resolv.conf' for input: $!\n");
	@resolv = <RESOLV>;
	close (RESOLV);
}


my $foundSearch = 0;
my $foundDomain = 0;

open (RESOLV, '>/etc/resolv.conf') or die("$0:  Error!  Unable to open '/etc/resolv.conf' for output: $!\n");
foreach my $line (@resolv) {
	if ($line =~ /^search\s/) {
		$foundSearch = 1;
		if (length($search) > 0) {
			print RESOLV $search;
		}
	} elsif ($line =~ /^domain\s/) {
		$foundDomain = 1;
		if (length($domain) > 0) {
			print RESOLV $domain;
		}
	} else {
		print RESOLV $line;
	}
}
if ($foundSearch == 0 && length($search) > 0) {
	print RESOLV $search;
}
if ($foundDomain == 0 && length($domain) > 0) {
	print RESOLV $domain;
}

close (RESOLV);

