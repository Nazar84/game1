# perl -Ilocal/lib/perl5 game.pl
use strict;
use warnings;

use Schema;
use Figura;
use Util;

use DDP;
use SDL;
use SDLx::App;
use SDL::Event;

my $app_w = 700; #размер экрана;
my $app_h = 700; #размер экрана;
my $app = SDLx::App->new( width => $app_w, height => $app_h, resizeable => 1);

my @grouped_squares;
my @groups_draw;
my @squares;
my $selection;
my $scale_x = $app_w / 350;
my $scale_y = $app_h / 350;

my $button = Figura->new( 0, 0, 50, 50, undef, 255, undef, 0, $scale_x, $scale_y );
my $cursor = Figura->new( 0, 0,  0,  0, 255, undef, undef, 0, $scale_x, $scale_y );

$app->add_show_handler ( sub{ show            ( @_, $button, @squares ) } );
$app->add_event_handler( sub{ event_pause_quit( @_,                   ) } );

$app->add_event_handler( sub{ new_square      ( @_, $button           ) } );
$app->add_event_handler( sub{ square_backlight( @_, @squares          ) } );
$app->add_event_handler( sub{ square_capture  ( @_, @squares          ) } );
$app->add_event_handler( sub{ square_moving   ( @_, @squares          ) } );
$app->add_event_handler( sub{ square_free     ( @_, @squares          ) } );

$app->add_event_handler( sub{ # create select field
	my $res = create_select_field( @_, \@squares, $selection );
	if( $res ) {
		$selection = $res;
	} });
$app->add_event_handler( sub{ select_field_moving( @_, $selection, \@squares ) } );
$app->add_event_handler( sub{ if(create_group( @_, $selection, \@squares ) )
	{
		$selection = undef;
	} });
$app->add_show_handler ( sub{ # arrange_group
	my( $grouped_squares, $groups_draw ) =
	arrange_group( @_, \@squares, $scale_x, $scale_y );
} );


my $schema;
sub db {
	return $schema   if $schema;

	my $DB =  {
		NAME => 'game_i',
		HOST => '127.0.0.1',
		DRVR => 'Pg',
		USER => 'gamer_i',
		PASS => 'V74F3iV4xQ1NAcdp',
		PORT => '5433',
	};
	$DB->{ DSN } =  sprintf "dbi:%s:dbname=%s;host=%s;port=%s",  @$DB{ qw/ DRVR NAME HOST PORT / };

	$schema //=  Schema->connect( $DB->{ DSN },  @$DB{ qw/ USER PASS / },  {
		AutoCommit => 1,
		RaiseError => 1,
		PrintError => 1,
		ShowErrorStatement => 1,
		# HandleError => sub{ DB::x; 1; },
		# unsafe => 1,
		quote_char => '"',  # Syntax error: SELECT User.id because of reserwed word
	});
	return $schema;
}


my @db_squares = db()->resultset( 'Figura' )-> all;

for my $i( @db_squares) {

	my $x            = $i->x / $scale_x;
	my $y            = $i->y / $scale_y;
	my $width        = $i->width;
	my $height       = $i->height;
	my $red          = $i->red;
	my $green        = $i->green;
	my $blue         = $i->blue;
	my $moving       = $i->moving;
	my $id           = $i->id;

	my $figura = Figura->new( $x, $y, $width, $height, $red, $green, $blue, $moving,
		$scale_x, $scale_y, $id );

	push @squares, $figura;
}



$app->run();



sub show {
    my ($delta, $app, @objects ) = @_;

    for my $object ( @objects ){
		$object->draw( $app );
	}

    $app->update;
}



sub event_pause_quit {
    my ($event, $app) = @_;

    if( $event->type == SDL_QUIT ) {
    	$app->stop;
    }

    elsif($event->type == SDL_ACTIVEEVENT) {
        if($event->active_state & SDL_APPINPUTFOCUS) {
            if($event->active_gain) {
                return 1;
            }
            else {
                $app->pause(\&event_pause_quit);
            }
        }
    }

    elsif($event->type == SDL_KEYDOWN) {
        if($event->key_sym == SDLK_SPACE) {
            return 1 if $app->paused;
             
            $app->pause(\&event_pause_quit);
        }
    }	
}



sub new_square {
	my ($event, $app, $button ) = @_;

	if( $event->type == SDL_MOUSEBUTTONDOWN
		&&  Util::mouse_target_square( $event, $button )
	){
		my $r = int rand( 300 );

		my $db_figura = db()->resultset( 'Figura' )->create({
			x            => $r,
			y            => 100,
			width        => 50,
			height       => 50,
			red          => 255,
			green        => 0,
			blue         => 0,
			moving       => 0,
		});
		my $id =  $db_figura->id;

		my $figura =  Figura->new(
			$r, 100, 50, 50,
			255, undef, undef, 0, $scale_x, $scale_y, $id,
		);
		push @squares, $figura;
	}
}



sub square_backlight {
	my ($event, $app, @squares ) = @_;

	$event->type == SDL_MOUSEMOTION
		or return;

	for my $square ( @squares ){

		if( Util::mouse_target_square( $event, $square ) ){
			$square->{ blue } = 200;
			$square->draw( $app );
		}

		else {
			$square->{ blue } = 0;
			$square->draw( $app );
		}
	}
}



sub square_capture {
	my( $event, $app, @squares ) =  @_;

	$event->type == SDL_MOUSEBUTTONDOWN 
		or return;

	for my $square ( @squares ){

		if( Util::mouse_target_square( $event, $square ) ) {
			$square->{ moving } = 1;
			$square->{ blue }   = 200;

			$square->{ take_point_x } = $event->motion_x - $square->{ x };
			$square->{ take_point_y } = $event->motion_y - $square->{ y };
		}
	}
}



sub square_moving {
	my ($event, $app, @squares ) = @_;

	$event->type == SDL_MOUSEMOTION
		or return;

	for my $square ( @squares ){

		if( $square->{ moving } ) {

			$square->draw_black( $app );
			
			$square->{ x } = $event->motion_x - $square->{ take_point_x };
			$square->{ y } = $event->motion_y - $square->{ take_point_y };

			my $id = $square->{ id };

			my $f = db()->resultset( 'Figura' )->search({ id => $id })->first;
			$f->update({
				x => $square->{ x },
				y => $square->{ y },
			});
		}
	}
}



sub square_free {
	my ($event, $app, @squares ) = @_;

	$event->type == SDL_MOUSEBUTTONUP
		or return;

	for my $square ( @squares ){
		$square->{ moving } = 0;
		$square->{ blue   } = 0;
	}
}



sub create_select_field {
	my( $event, $app, $squares, $selection ) = @_;

	!$selection  &&  $event->type == SDL_MOUSEBUTTONDOWN
		or return;

	for my $square ( @$squares ){
		if( Util::mouse_target_square( $event, $square ) ){	
			return;
		}
	}

	my %selection_i = (
		x            => $event->motion_x,
		y            => $event->motion_y,
		red          => 120,
		alpha        => 255,
		take_point_x => $event->motion_x,
		take_point_y => $event->motion_y,
	);

	return bless \%selection_i, "Figura";
}



sub select_field_moving {
	my( $event, $app, $square_selection ) =  @_;

	$event->type == SDL_MOUSEMOTION  && $square_selection 
		or return;

	$square_selection->draw_black( $app );

	my $mx = $event->motion_x;
	my $my = $event->motion_y;
	my $tx = $square_selection->{ take_point_x };
	my $ty = $square_selection->{ take_point_y };

	if( $mx > $tx ) {
		$square_selection->{ width } = $mx - $square_selection->{ x };
	}
	else {
		$square_selection->{ x } = $mx;
		$square_selection->{ width } = $tx - $mx;
	}

	if( $my > $ty ) {
		$square_selection->{ height } = $my - $square_selection->{ y };
	}
	else {
		$square_selection->{ y }      = $my;
		$square_selection->{ height } = $ty - $my;
	}

	$square_selection->draw( $app );

}	



sub create_group {
	my( $event, $app, $selection, $squares ) =  @_;

	$event->type == SDL_MOUSEBUTTONUP  &&  $selection
		or return;

	my @grouped;

	my $sx1 =  $selection->{ x };
	my $sx2 =  $selection->{ x } + $selection->{ width };
	my $sy1 =  $selection->{ y };
	my $sy2 =  $selection->{ y } + $selection->{ height };

	for my $square ( $squares->@* ) {
		if( ( $sx1 > $square->{ x } + $square->{ width }
			|| $sx2 < $square->{ x } )
			&& ( $sy1 > $square->{ y } + $square->{ height }
			|| $sy2 < $square->{ y } )
		){	
			$selection->draw_black( $app );
			return 1;
		}
	}

	for my $square ( @squares ){
		if( $square->{ x } > $sx1 && $square->{ x } + $square->{ width }  < $sx2 
		 && $square->{ y } > $sy1 && $square->{ y } + $square->{ height } < $sy2 
		){	
			push @grouped, $square;
		}
	}



	my $db_group = db->resultset( 'Group' )->create({
		x            => $selection->{ x },
		y            => $selection->{ y },
		width        => $selection->{ width },
		height       => $selection->{ height },
		red          => $selection->{ red },
		green        => 0,
		blue         => 0,
		moving       => 0,
		alpha        => $selection->{ alpha },
	});

	my $id = $db_group->id;
	
	for my $square ( @grouped ) {
		$square->{ group_id } = $id;

		my $f = db()->resultset( 'Figura' )->search({ id => $square->{ id } })->first;
		$f->update({
			group_id => $id,
		})
	}
	$selection->draw_black( $app );
	return 1;
}	



sub arrange_group {
	my( $delta, $app, $squares, $scale_x, $scale_y ) =  @_;

	my @groups = db()->resultset( 'Group' )->all;
		@groups or return;

	my @grouped_squares;
	my @groups_draw;

	for my $group( @groups ) {

		my $x            = $group->x / $scale_x;
		my $y            = $group->y / $scale_y;
		my $width        = $group->width;
		my $height       = $group->height;
		my $red          = $group->red;
		my $green        = $group->green;
		my $blue         = $group->blue;
		my $moving       = $group->moving;
		my $id           = $group->id;

		my $group_draw = Figura->new( $x, $y, $width, $height, $red, $green, $blue, $moving,
		$scale_x, $scale_y, $id );

		push @groups_draw, $group_draw;

		for my $square( $squares->@* ) {
			if( $square->{ group_id } == $id ) {
				push @grouped_squares , $square;
			}
		}
		my $ng = $#grouped_squares +1;

		$group_draw->{ width  } = 70 * $scale_x;
		$group_draw->{ height } = ( 10 + ( $ng * 60 ) ) * $scale_y;

		my $dy;
		for my $square_i ( @grouped_squares ){
			$square_i->{ x } = $group->x + 10 * $scale_x;
			$square_i->{ y } = $group->y + $dy + ( 10 * $scale_y );
			$dy +=  60 * $scale_y;

			$square_i->draw( $app );
		}
			
		$group_draw->Figura::draw( $app );
		
	}
	return \@grouped_squares, \@groups_draw;
}

# my( $x, $y, $z ) =  fn();
