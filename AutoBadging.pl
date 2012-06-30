#!/usr/bin/perl
#Arguments:
# 1- Dealer ID
# 2- Vehicle ID
# 3- Dealer Badges
# 4- Auto Features
# 5- Separator

#use strict;
#use warnings;
use Graphics::Magick;
use conf::Config;
use Switch;
use File::Copy;
use Time::HiRes;
use Constants;
use Data::Dumper;

require 'checkco2.pl';

my $dealer_id;
my $vehicle_id;
my @badges_list;
my $finance_idx;
my $border_idx;
my $badge_type;
my $badge_pos;
my $badge_shift_dir;
my $badge_shift_amt;
my $badge_photo_size;	#border only
my $composite_layout_num, $composite_layout_idx;	#composite only
my $original_image, $badge_image;
my $w,$h;
my $w_margin, $h_margin;
my $image_path, $vehicle_image_path;
my $undo_image;
my $server_index;

#####Utility hashes
%badge_types = ();
%badge_positions = ();
%badge_shift_dirs = ();
$badge_types{$conf::Badges{+ENVIRONMENT_BADGE}{code}} = ENVIRONMENT_BADGE;
$badge_types{$conf::Badges{+FINANCE_BADGE}{code}} = FINANCE_BADGE;
$badge_types{$conf::Badges{+BORDER_BADGE}{code}} = BORDER_BADGE;
$badge_types{$conf::Badges{+COMPOSITE_BADGE}{code}} = COMPOSITE_BADGE;
$badge_positions{$conf::Positions{+NORTH_EAST}} = NORTH_EAST;
$badge_positions{$conf::Positions{+SOUTH_EAST}} = SOUTH_EAST;
$badge_positions{$conf::Positions{+NORTH_WEST}} = NORTH_WEST;
$badge_positions{$conf::Positions{+SOUTH}} = SOUTH;
$badge_positions{$conf::Positions{+SOUTH_WEST}} = SOUTH_WEST;
$badge_positions{$conf::Positions{+CENTER}} = CENTER;
$badge_shift_dirs{$conf::ShiftDirs{+NORTH}} = NORTH;
$badge_shift_dirs{$conf::ShiftDirs{+EAST}} = EAST;
$badge_shift_dirs{$conf::ShiftDirs{+SOUTH}} = SOUTH;
$badge_shift_dirs{$conf::ShiftDirs{+WEST}} = WEST;

sub badge_dealer_vehicle{
	$dealer_id = shift;
	$vehicle_id = shift;
	my $badges_list_arg = shift;
	$finance_idx = shift;
	$border_idx = shift;
	$composite_idx = shift;
	$server_index = shift;
	@badges_list = @$badges_list_arg;
	#$badge_idx = shift;
	my $start = [ Time::HiRes::gettimeofday( ) ];
	
	if($dealer_id eq '5'){
		print join (',', @badges_list);
		print "/n";
	}
	
	my $env_badge_code = $conf::Badges{+ENVIRONMENT_BADGE}{code};
	my $finance_badge_code = $conf::Badges{+FINANCE_BADGE}{code};
	my $border_badge_code = $conf::Badges{+BORDER_BADGE}{code};
	my $composite_badge_code = $conf::Badges{+COMPOSITE_BADGE}{code};
	#Preparing image path & creating Undo Image
	$cp_flag = &prepare_dealer_image();
	if($cp_flag eq 1){
		print "badging  $vehicle_id  ............. \n";
		#print "Preparing Image Completed...\n";
		#Reading original_image
		&read_original_image();
		#print "Reading Image Completed...\n";
		#First applying border badges
		
		@badges_list = sort{
			my $tmp_a = $a;
			my $tmp_b = $b;
			if($a =~ /^$finance_badge_code\d+/){
				$tmp_a = 0;
			}elsif($a =~ /^$env_badge_code\d+/){
				$tmp_a = 1;
			}elsif($a =~ /^$border_badge_code\d+/){
				$tmp_a = 2;
			}elsif($a =~ /^$composite_badge_code\d+/){
				$tmp_a = 3;
			}
			
			if($b =~ /^$finance_badge_code\d+/){
				$tmp_b = 0;
			}elsif($b =~ /^$env_badge_code\d+/){
				$tmp_b = 1;
			}elsif($b =~ /^$border_badge_code\d+/){
				$tmp_b = 2;
			}elsif($b =~ /^$composite_badge_code\d+/){
				$tmp_b = 3;
			}
			return $tmp_a <=> $tmp_b;
		}(@badges_list);
		foreach $badge (@badges_list){
			&parse_badge($badge);
			#print "Parsing Border Badge $badge Completed... type : ".$badge_type."\n" ;
			&apply_badge($server_index);
			#print "Applying Border Badge $badge Completed...\n";
		}

		 &write_xl($server_index);
		 &scale(LARGE,$server_index);
		 &scale(NORMAL,$server_index);
		 &scale(SMALL,$server_index);
		my $elapsed = Time::HiRes::tv_interval( $start );
		if(scalar(@badges_list) == 0){
			unlink($conf::Paths{Dealers_Root_Pre}.$server_index.$conf::Paths{Dealers_Root_Post}.$dealer_id.'/'."thumbs/".$vehicle_id."_undo.jpg");
		}
		#print "\n\n Elapsed time: $elapsed seconds \n\n";
	}	
	return $cp_flag;
}

sub parse_badge{
	#####Parsing Badge Codes
	my $badge_code = $_[0];
	my $badge_type_code;
	my $badge_pos_code;
	my $badge_shift_dir_code;
	my $badge_shift_amt_code;
	my $composite_layout_code;
	if(length ($badge_code) eq 6){
		$badge_code =~ /(..)(.)(.)(..)/;
		$badge_type_code = $1;
		$badge_pos_code = $2;
		$badge_shift_dir_code = $3;
		$badge_shift_amt_code = $4;
	}elsif(length ($badge_code) eq 7){
		$badge_code =~ /(..)(.)(..)(..)/;
		$badge_type_code = $1;
		$badge_pos_code = $2;
		$composite_layout_code = $4;
		$composite_layout_num = int($composite_layout_code);
		$composite_layout_idx = $composite_layout_num - 1;
	}elsif(length ($badge_code) eq 9){
		$badge_code =~ /(..)(.)(.)(..)(..)(.)/;
		$badge_type_code = $1;
		$badge_pos_code = $2;
		$badge_shift_dir_code = $3;
		$badge_shift_amt_code = $4;
		$badge_photo_size_code = $5;
	}

	if($badge_shift_dir_code == 0) {
		$badge_shift_dir_code = '1';
		$badge_shift_amt_code= '00';
	}
	
	$badge_type = $badge_types{$badge_type_code};
	$badge_pos = $badge_positions{$badge_pos_code};
	$badge_shift_dir = $badge_shift_dirs{$badge_shift_dir_code};
	$badge_shift_amt = int($badge_shift_amt_code);
	$badge_photo_size = int($badge_photo_size_code);
	
	print " \n in parse..  code : $badge_code   typecode : $badge_type_code  type : $badge_type position-code: $badge_pos_code position: $badge_pos  shift-dir-code: $badge_shift_dir_code shift dir: $badge_shift_dir\n" ;
}

sub prepare_dealer_image{
	$vehicle_image_path = $conf::Paths{Dealers_Root_Pre}.$server_index.$conf::Paths{Dealers_Root_Post}.$dealer_id.'/xl/'.$vehicle_id;
	$image_path = $vehicle_image_path;
	my $copy_flag = 1;
	unless (-e $image_path.'_undo.jpg')
	{
		#undo file not found
		#print $image_path."_1.jpg\n";
		$copy_flag = copy($image_path."_1.jpg", $image_path."_undo.jpg");
	}
	$image_path = $image_path.'_undo.jpg';
	
	if ($copy_flag eq 1) {
		$undo_image = Graphics::Magick->new;
		$undo_image->Read($image_path);
	}
	#print "\n original images path $image_path \n";
	return $copy_flag ;
}

sub read_original_image{
	$original_image = &read_image($image_path);
	$h = $original_image ->Get ('height');
	$w = $original_image ->Get ('width');
	my $margin = $conf::Utils{Margin};
	$w_margin = $w * $margin;
	$h_margin = $h * $margin;
}

sub read_image{
	my $image_path = shift;
	$image = Graphics::Magick->new;
	$image->Read($image_path);
	return $image;
}

sub apply_badge{
	$badge_image = Graphics::Magick->new;
	switch ($badge_type){
		case ENVIRONMENT_BADGE {
			#print "\n=========In Env badging ========= \n";
			my $env_badge_path = $conf::Paths{Environment_Path};
			my $co2_check = &get_co2_path($dealer_id."-".$vehicle_id);
			 unless($co2_check eq ""){
				$env_badge_path = $co2_check;
			 }
			$badge_image->Read ($env_badge_path);
			my $env_w_ratio = $conf::Badges{+ENVIRONMENT_BADGE}{width};
			my $env_h_ratio = $conf::Badges{+ENVIRONMENT_BADGE}{height};
			$badge_image->Scale(width=>($w * $env_w_ratio), height=>($h * $env_h_ratio));
			&do_badging($original_image, $badge_image, 0, 0);
		}
		case FINANCE_BADGE {
			#print "\n=========In Finance badging ========= \n";
			my $finance_dir_path = $conf::Paths{Dealer_Badges_Root_Pre}.$_[0].$conf::Paths{Dealer_Badges_Root_Post}.$dealer_id.'/Finance/';
			$ls_command = "ls $finance_dir_path"."finphoto_$finance_idx"."_*";
			#print "cmd > $ls_command  \n";
			$badge_path = `$ls_command`;
			chomp($badge_path);
			#print "-------------$badge_path------------\n";
			my $finance_badge_path = $badge_path;
			if (-e $finance_badge_path)
			{
				$badge_image->Read ($finance_badge_path);
				my $fin_w_ratio = $conf::Badges{+FINANCE_BADGE}{width};
				my $fin_h_ratio = $conf::Badges{+FINANCE_BADGE}{height};
				$badge_image->Scale(width=>($w * $fin_w_ratio), height=>($h * $fin_h_ratio));
				&do_badging($original_image, $badge_image, 0, 0);
			}
		}
		case BORDER_BADGE{
			#print "\n=========In Border badging ========= \n";
			my $border_dir_path = $conf::Paths{Dealer_Badges_Root_Pre}.$_[0].$conf::Paths{Dealer_Badges_Root_Post}.$dealer_id.'/Border/';
			$ls_command = "ls $border_dir_path"."borderphoto_$border_idx"."_*";
			$badge_path = `$ls_command`;
			chomp($badge_path);
			#print "-------------$badge_path------------\n";
			my $border_badge_path = $badge_path;
                        if (-e $border_badge_path)
                        {
				$badge_image->Read ($border_badge_path);
				&do_badging($badge_image, $original_image, 1, $badge_photo_size);
				$original_image = $badge_image;
			}
		}
		case COMPOSITE_BADGE{
			#print "\n=========In composite badging ========= \n";
			my $composite_dir_path = $conf::Paths{Dealer_Badges_Root_Pre}.$_[0].$conf::Paths{Dealer_Badges_Root_Post}.$dealer_id.'/Composite/';
			$ls_command = "ls $composite_dir_path"."compphoto_$composite_idx"."_*";
			$badge_path = `$ls_command`;
			chomp($badge_path);
			#print "-------------$badge_path------------\n";
			my $composite_badge_path = $badge_path;
                        if (-e $composite_badge_path)
                        {
				$badge_image->Read($composite_badge_path);
				&composite_badging($badge_image, $original_image);
				$original_image = $badge_image;
			}
		}
	}
}

sub get_geometry{
	my $background_image = shift;
	my $position = shift;
	my $shift_direction = shift;
	my $shift_amout = shift;
	my $h_margin = shift;
	my $v_margin = shift;
	$h_margin = $h_margin * $background_image->Get('width');;
	$v_margin = $v_margin * $background_image->Get('height');
	my $h_shift = '+'.$h_margin;
	my $v_shift = '+'.$v_margin;
	my $negative = false;
	#temporary position variable for setting the negative flag.
	#note: the image is itself the badge
	$position_tmp = $position;
	if($position eq CENTER){
	    $position_tmp = NORTH_WEST;
	}elsif($position eq SOUTH){
	    $position_tmp = SOUTH_WEST;
	}

	if($position_tmp =~ /.*$shift_direction.*/){
	    $negative = true;
	}
	
	my $badge_h_shift = (($shift_amout * $background_image->Get('width'))/100);
	my $badge_v_shift = (($shift_amout * $background_image->Get('height'))/100);
	
	if($shift_direction eq NORTH or $shift_direction eq SOUTH){
	    if($negative eq true){
            $v_shift = "-".$badge_v_shift;
	    }else{
            $v_shift = "+".$badge_v_shift;
	    }
	}elsif($shift_direction eq EAST or $shift_direction eq WEST){
	    if($negative eq true ){
			$h_shift = "-".$badge_h_shift;
	    }else{
		    $h_shift = "+".$badge_h_shift;
	    }
	}elsif($shift_direction eq H_MARGIN){
		$h_shift = '+'.$h_margin;
	}elsif($shift_direction eq V_MARGIN){
		$v_shift = '+'.$v_margin;
	}elsif($shift_direction eq MARGIN){
		$h_shift = '+'.$h_margin;
		$v_shift = '+'.$v_margin;
	}
	
	
	my $geometry = $h_shift.$v_shift;
	return $geometry;
}

sub badge_small_composite{
	my $background_image = shift;
	my $small_image_path = shift;
	my $small_image_position = shift;
	my $small_image_shift_dir = shift;
	my $small_image_shift_amount = shift;
	my $composite_layout = shift;
	my %composite_layout = %{$composite_layout};
	my $background_width = $background_image->Get('width');
	my $background_height = $background_image->Get('height');
	
	my $small_width = $background_width * $composite_layout{small}{width};
	my $small_height = $background_height * $composite_layout{small}{height};
	if(-e $small_image_path){
		my $vehicle_image = &read_image($small_image_path);
		$vehicle_image->Scale(width => $small_width, height => $small_height);
		my $geometry = &get_geometry($background_image,$small_image_position, $small_image_shift_dir, $small_image_shift_amount, $composite_layout{small}{h_margin}, $composite_layout{small}{v_margin});
		&compose_image($background_image, $vehicle_image, $small_image_position, $geometry);
	}
}

sub composite_badging{
	my $background_image = shift;
	my $vehicle_image = shift;

	my @composite_layouts = $conf::Badges{+COMPOSITE_BADGE}{layouts};
	my %composite_layout = %{$composite_layouts[0][$composite_layout_idx]};
	
	my $background_width = $background_image->Get('width');
	my $background_height = $background_image->Get('height');
	
	my $large_width = $background_width * $composite_layout{large}{width};
	my $large_height = $background_height * $composite_layout{large}{height};
	#Scaling Vehicle Images
	$vehicle_image->Scale(width => $large_width, height => $large_height);
	
	
	my $geometry = &get_geometry($background_image,$composite_layout{large}{position}, $composite_layout{large}{shift_direction}, $composite_layout{large}{shift_amount}, $composite_layout{large}{h_margin}, $composite_layout{large}{v_margin});
	&compose_image($background_image, $vehicle_image, $composite_layout{large}{position}, $geometry);
	switch($composite_layout_num){
		case COMPOSITE_FIRST{
			&badge_small_composite($background_image, $vehicle_image_path.'_2.jpg', SOUTH_WEST, MARGIN, 0.12 *100, \%composite_layout);
			&badge_small_composite($background_image, $vehicle_image_path.'_3.jpg', SOUTH, V_MARGIN, 0.12*100, \%composite_layout);
			&badge_small_composite($background_image, $vehicle_image_path.'_4.jpg', SOUTH_EAST, WEST, 1.8 , \%composite_layout);
		}
		case COMPOSITE_SECOND{
			&badge_small_composite($background_image, $vehicle_image_path.'_2.jpg', NORTH_EAST, MARGIN,0.744* 100, \%composite_layout);
			&badge_small_composite($background_image, $vehicle_image_path.'_3.jpg', NORTH_EAST, SOUTH, 0.502 * 100, \%composite_layout);
			&badge_small_composite($background_image, $vehicle_image_path.'_4.jpg', NORTH_EAST, SOUTH, 0.257 * 100, \%composite_layout);
		}
		case COMPOSITE_THIRD{
			&badge_small_composite($background_image, $vehicle_image_path.'_2.jpg', SOUTH_WEST, MARGIN, 0.02 * 100, \%composite_layout);
			&badge_small_composite($background_image, $vehicle_image_path.'_3.jpg', SOUTH_WEST, EAST, (2 * 0.02 + 0.225) * 100, \%composite_layout);
			&badge_small_composite($background_image, $vehicle_image_path.'_4.jpg', SOUTH_WEST, EAST, (3 * 0.02 + 2 * 0.225)* 100, \%composite_layout);
			&badge_small_composite($background_image, $vehicle_image_path.'_5.jpg', SOUTH_WEST, EAST, (4 * 0.02 + 3 * 0.225) * 100, \%composite_layout);
		}
	}
}

sub compose_image{
	my $super_image = shift;
	my $sub_image = shift;
	my $position = shift;
	my $geometry = shift;
	
	$super_image->Composite(
	    image => $sub_image,
	    compose => 'over',
	    gravity => $position,
	    geometry => $geometry,
	);
}

sub do_badging{
	my $badging_image = shift;
	my $badged_image = shift;
	my $scale_badged = shift;
	my $scale_factor = shift;
	
	if($badge_type eq +BORDER_BADGE){
		$x_shift = "+$w_margin";
		$y_shift = "+$h_margin";
	}else{
		$x_shift = "+0";
		$y_shift = "+0";
	}
	
	$negative = false;
	#temporary position variable for setting the negative flag.
	#note: the image is itself the badge
	$badge_pos_tmp = $badge_pos;
	if($badge_pos eq CENTER){
	    $badge_pos_tmp = NORTH_WEST;
	}elsif($badge_pos eq SOUTH){
	    $badge_pos_tmp = SOUTH_WEST;
	}

	if($badge_pos_tmp =~ /.*$badge_shift_dir.*/){
	    $negative = true;
	}
	
	$north_constant = NORTH;
	$south_constant = SOUTH;
	
	my $badge_x_shift = (($badge_shift_amt*$w)/100);
	my $badge_y_shift = (($badge_shift_amt*$h)/100);
	
	if($badge_shift_dir =~ /^$north_constant|$south_constant$/){
	    if($negative eq true){
            $y_shift = "-".$badge_y_shift;
	    }else{
            $y_shift = "+".$badge_y_shift;
	    }
	}else{
	    if($negative eq true ){
			$x_shift = "-".$badge_x_shift;
	    }else{
		    $x_shift = "+".$badge_x_shift;
	    }
	}
	
	$geometry = $x_shift.$y_shift;
	if($scale_badged){
		my $background_width = $badging_image->Get('width');
		my $background_height = $badging_image->Get('height');
		$badged_image->Scale(width=>($background_width * ($scale_factor / 100)), height=>($background_height * ($scale_factor / 100)));
	}
	#print "\n----------------------- \n negativ : $negative \n badgePos : $badge_pos \n pos_tmp : $badge_pos_tmp \n shift Dir : $badge_shift_dir \n geom : $geometry \n ----------------------\n";
	$badging_image->Composite(
	    image => $badged_image,
	    compose => 'over',
	    gravity => $badge_pos,
	    geometry => $geometry,
	);
 }

sub scale{
	switch ($_[0]) {
		case SMALL {
			$width = int($conf::MaxDims{MaxSmall});
			$height = int($conf::MaxDims{MaxSmall}) * $conf::MaxDims{Ratio};
			$scale_path = "thumbs/";
		}
		case NORMAL {
			$width = int($conf::MaxDims{MaxNormal});
			$height = int($conf::MaxDims{MaxNormal}) * $conf::MaxDims{Ratio};
			$scale_path = "";
		}
		case LARGE {
			$width = int($conf::MaxDims{MaxLarge});
			$height = int($conf::MaxDims{MaxLarge}) * $conf::MaxDims{Ratio};
			$scale_path = "larg/";
		}
	}
	$original_image->Scale(width=>$width, height=>$height);
	$original_image->Write($conf::Paths{Dealers_Root_Pre}.$_[1].$conf::Paths{Dealers_Root_Post}.$dealer_id.'/'.$scale_path.$vehicle_id."_1.jpg");
	
	$undo_image->Scale(width=>$width, height=>$height);
	$undo_image->Write($conf::Paths{Dealers_Root_Pre}.$_[1].$conf::Paths{Dealers_Root_Post}.$dealer_id.'/'.$scale_path.$vehicle_id."_undo.jpg");
}

sub write_xl{
	$original_image->Write($conf::Paths{Dealers_Root_Pre}.$_[0].$conf::Paths{Dealers_Root_Post}.$dealer_id.'/xl/'.$vehicle_id."_1.jpg");
}


