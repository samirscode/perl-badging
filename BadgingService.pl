#!/usr/bin/perl

#use DBI;
#use DBD::mysql;
use DBIx::Connector;
use Parallel::ForkManager;
use conf::Config;
use Constants;
use Data::Dumper;

require 'AutoBadging.pl';
require 'Filter.pl';

#Run Configurations
my $server_idxs = $conf::Run{Servers};
my $processes 	= $conf::Run{Processes};
my $logfile 	= $conf::Paths{Log_Path};

#Database Configurations
my $database = "shopdb";
my $host = "localhost";
my $port = "3306";
my $user = "webdb";
my $password = "maluma!";
my $data_source = "dbi:mysql:$database:$host:$port";
my $db_connection = DBIx::Connector->new($data_source, $user, $password, 
    {
        AutoCommit       => 0,
        PrintError       => 0,
        RaiseError       => 1,
        ChopBlanks       => 1,
    }
);
END { unlink "shopdb" }

open LOGFILE, ">>$logfile" or die "cannot open logfile $logfile for append: $!";

#&sweep_autoBadges();
my $start_date = localtime();
print LOGFILE "Badging Service Started At : ".$start_date, "\n";
my $srv_start = [ Time::HiRes::gettimeofday( ) ];
&service();
my $srv_elapsed = Time::HiRes::tv_interval( $srv_start );
my $end_date = localtime();
print LOGFILE "\nBadging Service Finished At : ".$end_date, "\n";
print LOGFILE "Total Service time: $srv_elapsed  seconds \n";
print LOGFILE "------------------------------------------------------------------------------------\n\n";
close LOGFILE;

sub service{
	&sweep_autoBadges();
	my $parallel_manager = new Parallel::ForkManager($processes);
	my($dealer , $dealer_badges);#quey result
	my $dealers_query_result = &get_server_dealers(\$dealer , \$dealer_badges);
	while($dealers_query_result->fetch()) {
		$parallel_manager->start and next;
		print LOGFILE  " Handling dealer   $dealer  \n";
		print "Dealer: $dealer \n";
		$counter= 0;
		####-|($dealer , $dealer_badges)
		my($auto_id , $dealer_autoBadges);#query result
		my $autoBadges_query_result = &get_dealer_autoBadges($dealer, \$auto_id , \$dealer_autoBadges);
		while($autoBadges_query_result->fetch()) {
			####-|($auto_id , $dealer_autoBadges)
			my($auto_features);
			my $auto_query_result = &get_autoBadges_auto($auto_id, \$auto_features);
			if($auto_query_result->fetch()) {#Auto Exists
				####-|($auto_features)
				#->$auto_features + $dealer_badges	
				my ($finance_idx, $border_idx, $composite_idx, $badges_list);
				($finance_idx, $border_idx, $composite_idx, $badges_list) = &filter_badges($dealer_badges , $auto_features, ",", ";");
				if(&isSame($dealer_autoBadges, \@$badges_list) == 0){
					$vid = $auto_id;
					$regx = $dealer."-";
					$vid =~ s/$regx//;
					#print " auto : $vid \n badge:  ".join(";",@$badges_list)." \n dealerBadges: $dealer_badges\n autoFeatures : $auto_features  \n =============================================";
					#print "attempting to badge $vid\n";
					$badging_status = &badge_dealer_vehicle($dealer, $vid, \@$badges_list, $finance_idx, $border_idx, $composite_idx);
					#print "$vid badging status: $badging_status\n";
					if($badging_status  eq 1 ){
						$counter = $counter + 1;
						#print "$vid Badges: \n";
						#print Dumper(\@$badges_list);
						&insert_autoBadges($dealer, $auto_id, join(";",@$badges_list).";");
					}
					#print "------------------------------------------------------------------------\n";
				}
			}else{#Auto Doesn't Exist
				&delete_autoBadges_record($dealer, $auto_id);
			}
		}
		print LOGFILE  " Dealer $dealer badged photos  =  $counter  photos\n";
		$parallel_manager->finish;
	}
	$parallel_manager->wait_all_children;
}

sub execute_update{
	my $update_query = shift;
	#print "executing query $update_query \n";
	my @query_params = @_;
	#my $update_handler = $db_connection->prepare($update_query);
	my $update_handler = $db_connection->dbh->prepare($update_query);
	$update_handler->execute(@query_params);
	#print "-------------- \n";
}

sub execute_select{
	my $select_query = shift;
	my @query_params = @_;
	#my $select_handler = $db_connection->prepare($select_query);
	my $select_handler = $db_connection->dbh->prepare($select_query);
	$select_handler->execute(@query_params);
	return $select_handler;
}

sub sweep_autoBadges{
	my $delete_query = "DELETE From autoBadges where dealerId in (SELECT id from common.dealer where server IN ($server_idxs)) AND id not in (SELECT id from autos where dealerId in (SELECT id from common.dealer where server IN ($server_idxs)));";
	&execute_update($delete_query);
	my $insert_query = "INSERT INTO autoBadges (id,dealerId) (SELECT id, dealerId from autos where id not in (select id from autoBadges) and dealerId in (SELECT id from common.dealer where server IN ($server_idxs)));";
	&execute_update($insert_query);
}

sub get_server_dealers{
	my $server_dealers_query = "SELECT id, badges FROM common.dealer WHERE server IN ($server_idxs) AND id IN (5);";
	my $dealers_query_handler = &execute_select($server_dealers_query);
	$dealers_query_handler->bind_columns(@_);
	return $dealers_query_handler;
}

sub get_dealer_autoBadges{
	my $dealer_id = shift;
	my $dealer_autoBadges_query = "SELECT id AS autoId, badges FROM autoBadges WHERE dealerId = ?;";
	my $autoBadges_query_handler = &execute_select($dealer_autoBadges_query, $dealer_id);
	$autoBadges_query_handler->bind_columns(@_);
	return $autoBadges_query_handler;
}

sub get_autoBadges_auto{
	my $auto_id = shift;
	my $autoBadges_auto_query = "SELECT features FROM autos WHERE id = ?;";
	my $auto_query_handler = &execute_select($autoBadges_auto_query, $auto_id);
	$auto_query_handler->bind_columns(@_);
	return $auto_query_handler;
}

sub delete_autoBadges_record{
	my $dealer_id = shift;
	my $auto_id = shift;
	my $delete_autoBadges_query = "DELETE FROM autoBadges WHERE dealerId = ? AND id = ?;";
	&execute_update($delete_autoBadges_query, $dealer_id, $auto_id);
}

sub insert_autoBadges{
	my $dealer_id = shift;
	my $auto_id = shift;
	my $badges = shift;
	my $insert_query = "REPLACE INTO autoBadges(id, dealerId, badges) VALUES (?, ?, ?);";
	&execute_update($insert_query, $auto_id, $dealer_id,, $badges);
}
#1- query: get dealers on the current server
#2- iterate over the dealers and for each:
#	2.1- query: get autoBadge entries for that dealer
#	2.2- iterate over autoBadge entries and for each:
#		2.2.1- query: get auto whose id = autoBadge.id
#		2.2.2- if auto doesn't exit then: {delete autoBadge record whose id = autoId; continue to the next autoBadge}
#		2.2.3- else then: {autoFeatures = get auto features, dealerBadges = get dealer badges, 
#							filteredBadges = filter(autoFeatures, dealerBadges) 
#							if badgesAreEqual(filteredBadges, autoBadge.badges) then:{APPLY BADGING()}
#							}
#	
$db_connection->disconnect();
