# perl -Ilocal/lib/perl5 game.pl
use strict;
use warnings;
#use lib 'local/lib/perl5';

use Figura;

use DDP;
use SDL;
use SDLx::App;
use SDL::Event;

my $app_w = 700; #размер экрана;
my $app_h = 700; #размер экрана;
my $app = SDLx::App->new( width => $app_w, height => $app_h, resizeable => 1);

$app->add_event_handler( \&mouse  );
$app->add_event_handler( \&event  );
$app->add_event_handler( \&ride   );
$app->add_show_handler ( \&show   );
$app->add_move_handler ( \&move   );
$app->add_event_handler( \&cursor );

my @squares;

my $selection;
$app->add_event_handler( sub{ 
	my $res =  group( @_, \@squares, $selection );
	if( $res ) {
		$selection =  $res;
	}
	print "$selection<<\n";
});
$app->add_event_handler( sub{ selection( @_, $selection, \@squares ) } );
$app->add_event_handler( sub{ 
	if(create_group( @_, $selection, \@squares ) ) {
		$selection = undef;
	}
});
$app->add_show_handler( sub{ arrange_group( @_, \@squares ) } );

use Schema;

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


my $scale_x = $app_w / 350;
my $scale_y = $app_h / 350;

my $car = Figura->new( 0, 0, 50, 50, undef, 255, undef, 0, $scale_x, $scale_y );

my $gun = Figura->new( 0, 0, 0, 0, 255, undef, undef, 0, $scale_x, $scale_y );

my @db_squares = db()->resultset( 'Figura' )-> all;
my @groups;
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
	print "my \$x$id;\n";
}

for my $square ( @squares, @groups ){
	$square->draw( $app );
}

$app->run();

sub event {
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
                $app->pause(\&event);
            }
        }
    }

    elsif($event->type == SDL_KEYDOWN) {
        if($event->key_sym == SDLK_SPACE) {
            return 1 if $app->paused;
             
            $app->pause(\&event);
        }
    }	
}



sub show {
    my ($delta, $app) = @_;

    #car
	$car->draw_black( $app );

	$car->{ x } +=  $car->{ dx } * $scale_x * 50;
	$car->{ y } +=  $car->{ dy } * $scale_y * 50;
	$car->{ dx } =  0;
	$car->{ dy } =  0;
	
	$car->draw( $app ); 

	# print "UPDATE\n";
    $app->update;
}



sub ride {
	my ($event, $app) = @_;
	$event->type == SDL_KEYDOWN
		or return;

	if( $event->key_sym == SDLK_LEFT ) {
		$car->{ dx } -= 1;
	}

	if( $event->key_sym == SDLK_RIGHT ) {
		$car->{ dx } += 1;
	}
}



sub move {
	my ($step, $app, $t) = @_;

	#car
	if( $car->{ x } >  $scale_x * 300) {
	    $car->{ x } =  $scale_x * 300;
	}

	if( $car->{ x } < 0) {
		$car->{ x } = 0;
	}
}



sub cursor {
	my ($event, $app) = @_;

	$event->type == SDL_MOUSEMOTION
		or return;

	$gun->draw_black( $app );
	
	$gun->{ x } = $event->motion_x;
	$gun->{ y } = $event->motion_y;

	$gun->draw( $app );



	for my $square ( @squares ){

		if( $square->{ moving } ) {

			$square->draw_black( $app );
			
			$square->{ x } = $event->motion_x - $square->{ take_point_x };
			$square->{ y } = $event->motion_y - $square->{ take_point_y };

			$square->draw( $app );

			my $id = $square->{ id };

			my $x = $square->{ x };
			my $y = $square->{ y };

			my $f = db()->resultset( 'Figura' )->search({ id => $id })->first;
			$f->update({
				x => $x,
				y => $y,
			})
		}
	}
}

sub mouse_target_square {
	my( $event, $square ) =  @_;

	return $event->motion_x > $square->{ x }
		&& $event->motion_x < $square->{ x } + ( 50 * $scale_x )
		&& $event->motion_y > $square->{ y }
		&& $event->motion_y < $square->{ y } + ( 50 * $scale_y )
}	

my $n;
sub mouse {
	my ($event, $app) = @_;

	if( $event->type == SDL_MOUSEBUTTONDOWN
		&&  mouse_target_square( $event, $car )
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

		for my $square ( @squares ){
			$square->draw( $app );
		}
	}



	for my $square ( @squares ){

		if( $event->type == SDL_MOUSEBUTTONDOWN 
			&& mouse_target_square( $event, $square )
		){
			$square->{ moving } = 1;
			$square->{ blue }   = 200;
			$square->draw( $app );

			$square->{ take_point_x } = $event->motion_x - $square->{ x };
			$square->{ take_point_y } = $event->motion_y - $square->{ y };
		}

		if( $event->type == SDL_MOUSEBUTTONUP ) {
			$square->{ moving } = 0;
			$square->{ blue   } = 0;
			$square->draw( $app );
		}
	}

	for my $square ( @squares ){

		if( mouse_target_square( $event, $square ) ){
			$square->{ green } = 150;
			$square->draw( $app );
		}

		else {
			$square->{ green } = 0;
			$square->draw( $app );
		}
	}
}



sub create_group {
	my( $event, $app, $selection, $squares ) =  @_;

	$event->type == SDL_MOUSEBUTTONUP  &&  $selection
		or return;

	my @grouped;

	for my $square ( $squares->@* ) {
		if( ( $selection->{ x } > $square->{ x } + $square->{ width }
			|| $selection->{ x } + $selection->{ width } < $square->{ x } )
			&& ( $selection->{ y } > $square->{ y } + $square->{ height }
			|| $selection->{ y } + $selection->{ height } < $square->{ y } )
		){	
			$selection->draw_black( $app );
			return 1;
		}
	}

#если попадаем на группу, то выход!

	my $sx1 =  $selection->{ x };
	my $sx2 =  $selection->{ x } + $selection->{ width };
	my $sy1 =  $selection->{ y };
	my $sy2 =  $selection->{ y } + $selection->{ height };

	for my $square ( @squares ){
		if( $square->{ x } > $sx1 && $square->{ x } + $square->{ width }  < $sx2 
		 && $square->{ y } > $sy1 && $square->{ y } + $square->{ height } < $sy2 
		){	
			push @grouped, $square
			or return;
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
	my( $delta, $app, @squares ) =  @_;

	my @groups = db()->resultset( 'Group' )->all;

	@groups or return;

	for my $group( @groups ) {
# DB::x;
		# my $id = $group->id;

		my @grouped = db()->resultset( 'Figura' )->search({ group_id => $group->id })->all;
		my $ng = $#grouped +1;
		$group->{ width }  = 70;
		$group->{ height } = 10 + ( $ng * 50 + $ng * 10 );
# print "$id\n";

		$group->Figura::draw( $app );
	}
	

	#1 упорядочить поле по числу квадратов

	# #2 упрядочить квадраты в поле
	# my $n = $ng * 60;
	# for my $square( @grouped ) {
	# 	$square->{ x } = $n + $arrange->{ x } + 10;
	# 	$square->{ y } = $arrange->{ y } + 10;
	# 	$n -= 1;
	# }

	#3 отривоска 
}



sub selection {
	my( $event, $app, $app_state_selection ) =  @_;

	$event->type == SDL_MOUSEMOTION  && $app_state_selection 
		or return;

	$app_state_selection->draw_black( $app );

	my $mx = $event->motion_x;
	my $my = $event->motion_y;
	my $tx = $app_state_selection->{ take_point_x };
	my $ty = $app_state_selection->{ take_point_y };

	if( $mx > $tx ) {
		$app_state_selection->{ width } = $mx - $app_state_selection->{ x };
	}
	else {
		$app_state_selection->{ x } = $mx;
		$app_state_selection->{ width } = $tx - $mx;
	}

	if( $my > $ty ) {
		$app_state_selection->{ height } = $my - $app_state_selection->{ y };
	}
	else {
		$app_state_selection->{ y }      = $my;
		$app_state_selection->{ height } = $ty - $my;
	}

	$app_state_selection->draw( $app );
	# p $app_state_selection;

	for my $square ( @squares ){
		$square->draw( $app );
	}
}	



sub group {
	my( $event, $app, $squares, $selection ) = @_;

	!$selection  &&  $event->type == SDL_MOUSEBUTTONDOWN
		or return;

	print "GROUP\n";

	for my $square ( @$squares ){
		if( mouse_target_square( $event, $square ) ){	
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


