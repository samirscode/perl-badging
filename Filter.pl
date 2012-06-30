#!/usr/bin/perl
use conf::Config;
use Constants;
use Data::Dumper;
require 'AutoBadging.pl';

 #($fin_idx, $border_idx, $badges) = &filter_badges("015000;023000;041050502;041315654;",",102,416,27,15,22,505b,442b,500a,303,73,37,78,38,87,,",",",";");
 #print "Filtered Badges : ".join(";", @$badges)."\n ";
 #print " >>>> " .&isSame("015000;041050502;",\@$badges)."\n";
 #&badge_dealer_vehicle("146", "0086065", \@$badges, $fin_idx, $border_idx);
 
 sub isSame {
 $auto_badges_old = @_[0];
 @auto_badges_new_list =@{$_[1]}; 
 @auto_badges_old_list = split(/;/,$auto_badges_old);
 
  unless(scalar (@auto_badges_new_list) eq scalar (@auto_badges_old_list) ){
	return 0;
 }
 	foreach $badge_str_new (@auto_badges_new_list){
		$flag=false;
		foreach $badge_str_old (@auto_badges_old_list){
		 if($badge_str_new eq $badge_str_old){
				$flag= true;
			}
		}
		if($flag eq false ){
		 return 0;
		}
	}
return 1;
}

 
sub filter_badges {
	my $badges = shift;
	my $features = shift;
	my $feature_separator = shift;
	my $badges_separator = shift;
	my %feature_badge_code = (500 => '01',442 => '02' ,505 => '04', 508 => '05');
	my @features_list = split(/$feature_separator/, $features );
	my $border_code = $conf::Badges{+BORDER_BADGE}{code};
	my $finance_code = $conf::Badges{+FINANCE_BADGE}{code};
	my $composite_code = $conf::Badges{+COMPOSITE_BADGE}{code};
	my ($finance_idx, $border_idx, $composite_idx, @filtered_badges_list);
	
	foreach $feature (@features_list){
	  if ( $feature =~ /(^500[a-z]$)/ || $feature =~ /(^505[a-z]$)/ || $feature =~/(^442b$)/ || $feature =~/(^508[a-z]$)/){
			my $sub_code = substr $feature,0,3;
			my $badge_id = $feature_badge_code{$sub_code}."";
			if($badge_id eq $finance_code.""){
				my $photo_alph = substr $feature,3;
				$finance_idx  = ord(lc $photo_alph) - 96;
			}elsif($badge_id eq $border_code.""){
				my $photo_alph = substr $feature,3;
				$border_idx  = ord(lc $photo_alph) - 96;
			}elsif($badge_id eq $composite_code.""){
				my $photo_alph = substr $feature,3;
				$composite_idx  = ord(lc $photo_alph) - 96;
			}
			my $tmp_badges = $badges_separator.$badges;
			while ($tmp_badges =~ m/$badges_separator($badge_id\d+)$badges_separator/g) {
				if ($badge_id eq $border_code.""){
					if((substr $1,-1,1) == $border_idx){
						push(@filtered_badges_list,$1."");
					}
				}elsif ($badge_id eq $composite_code.""){
					if((substr $1,3,2) == $composite_idx){
						push(@filtered_badges_list,$1."");
					}
				}else{
					push(@filtered_badges_list,$1."");
				}
				$tmp_badges = substr($tmp_badges ,pos($tmp_badges)-1);
			}
		}
	}
	return ($finance_idx, $border_idx, $composite_idx, \@filtered_badges_list);
}
1; 
