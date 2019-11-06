package Util;



sub mouse_target_square {
	my( $event, $square ) =  @_;

	return $event->motion_x > $square->{ x }
		&& $event->motion_x < $square->{ x } + $square->{ width  }
		&& $event->motion_y > $square->{ y }
		&& $event->motion_y < $square->{ y } + $square->{ height }
}	



1;
