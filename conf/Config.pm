 %conf::Run = (
	Servers => '4,5,6',
	Processes => '5'
 );
 
 %conf::Paths = (
        Environment_Path => '/home/www/aos24/images/envBdgephoto.png',
        Dealers_Root_Pre  => '/home/servers/www',
        Dealers_Root_Post  => '.aos24.com/vehicles/photos/',
    Dealers_Root_No  => '/home/vehicles_no/photos/',
        Dealer_Badges_Root_Pre  => '/home/servers/www',
        Dealer_Badges_Root_Post  => '.aos24.com/dealersImages/',
        Preview_Tmp_Root => '/home/java/aos.work/tmp/PreviewImage/',
        Log_Path => '/root/bin/Badging/badging.log',
 );
 
 %conf::Positions = (
      NORTHWEST   => '1',
      NORTHEAST   => '2',
      SOUTHWEST   => '3',
      SOUTHEAST   => '4',
      CENTER      => '5',
      SOUTH       => '6',
  );

 %conf::ShiftDirs = (
      NORTH       => '1',
      EAST        => '2',
      SOUTH       => '3',
      WEST        => '4',
  );

 %conf::Utils = (
      Separator	  => ';',
      Margin 	  => '0.02',
  );

 %conf::Badges = (
    FINANCE => {
		width	  => '1',
		height	  => '1',
		code 	  => '01',
		desc 	  => 'Special Finance Badge',
	},

    GREEN   => {
        width     => '0.16',
        height    => '0.2',
        code      => '02',
        desc      => 'Green Environment Badge',
	},

    BORDER  => {
        width     => '0.5',
        height    => '0.5',
        code      => '04',
        desc      => 'Fotos-Rahmen',
	},
	
	COMPOSITE	=> {
        code    	=> '05',
        desc		=> 'Composite Photo Badge',
		layouts		=> [
			{
				small_cnt => '3',
				large	  => {width => '0.5695', height => '0.5703', position => 'NORTHEAST', shift_direction => 'MARGIN', shift_amount => '0', h_margin => '0.02', v_margin => '0.02'},
				small	  => {width => '0.2300', height => '0.2300', h_margin => '0.0201', v_margin => '0.159'}
			},
			{
				small_cnt => '3',
				large	  => {width => '0.7200', height => '0.7200', position => 'NORTHWEST', shift_direction => 'MARGIN', shift_amount => '0', h_margin => '0.02', v_margin => '0.02'},
				small	  => {width => '0.2300', height => '0.2300', h_margin => '0.02', v_margin => '0.02'}
			},
			{
				small_cnt => '4',
				large	  => {width => '0.5695', height => '0.5703', position => 'NORTHEAST', shift_direction => 'MARGIN', shift_amount => '0', h_margin => '0.02', v_margin => '0.02'},
				small	  => {width => '0.2300', height => '0.2300', h_margin => '0.02', v_margin => '0.158'}
			}
		]
	}

 );

 %conf::MaxDims = (
	Ratio     => '0.75',
	MaxSmall  => '90',
	MaxNormal => '400',
	MaxLarge  => '640',
	MaxXLarge => '1024',
 );

