package Figura;

sub new {
	my( $figura, $x, $y, $w, $h, $r, $g, $b, $m, $scale_x, $scale_y, $id ) = @_;

	my %figura = (
		x            => $x * $scale_x,
		y            => $y * $scale_y,
		width        => $w * $scale_x,,
		height       => $h * $scale_y,
		red          => $r // 0,
		green        => $g // 0,
		blue         => $b // 0,
		alpha        => 255,
		moving       => $m,
		take_point_x => 0,
		take_point_y => 0,
		id           => $id // 0, 
	);
	return bless \%figura;
}



sub draw_black {
	my( $figura, $screen ) = @_;

	$screen->draw_rect([
		$figura->{ x },
		$figura->{ y },
		$figura->{ width },
		$figura->{ height },
	],[ 0, 0, 0, 0 ]);
}



sub draw {
	my( $figura, $screen ) = @_;

	$screen->draw_rect([
		$figura->{ x },
		$figura->{ y },
		$figura->{ width },
		$figura->{ height },
	],[
		$figura->{ red },
		$figura->{ green },
		$figura->{ blue },
		$figura->{ alpha },
	]);
}

1;
