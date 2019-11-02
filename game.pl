# perl -Ilocal/lib/perl5 game.pl
use strict;
use warnings;
#use lib 'local/lib/perl5';

use Figura;

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

use Schema;

my $schema;
sub db {
	return $schema   if $schema;

	my $DB =  {
		NAME => 'nazar',
		HOST => '127.0.0.1',
		DRVR => 'Pg',
		USER => 'gamer',
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
my @squares;

for my $i( @db_squares ) {

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

for my $square ( @squares ){
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



sub mouse {
	my ($event, $app) = @_;

	if( $event->type == SDL_MOUSEBUTTONDOWN 
		&& $event->motion_x > $car->{ x }
		&& $event->motion_x < $car->{ x } + ( 50 * $scale_x )
		&& $event->motion_y > $car->{ y }
		&& $event->motion_y < $car->{ y } + ( 50 * $scale_y )
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
			&& $event->motion_x > $square->{ x }
			&& $event->motion_x < $square->{ x } + ( 50 * $scale_x )
			&& $event->motion_y > $square->{ y }
			&& $event->motion_y < $square->{ y } + ( 50 * $scale_y )
		){
			$square->{ moving } = 1;
			$square->{ blue }   = 200;
			$square->draw( $app );

			$square->{ take_point_x } = $event->motion_x - $square->{ x };
			$square->{ take_point_y } = $event->motion_y - $square->{ y };
		}

		if( $event->type == SDL_MOUSEBUTTONUP ) {
			$square->{ moving } = 0;
			$square->{ blue }   = 0;
			$square->draw( $app );
		}
	}



	for my $square ( @squares ){

		if( $event->motion_x > $square->{ x }
			&& $event->motion_x < $square->{ x } + ( 50 * $scale_x )
			&& $event->motion_y > $square->{ y }
			&& $event->motion_y < $square->{ y } + ( 50 * $scale_y )
		){
			$square->{ green }   = 150;
			$square->draw( $app );
		}

		else {
			$square->{ green } = 0;
			$square->draw( $app );
		}
	}
}



























































# my $points; #очки;
# my $o_i;	#колличество уничтоженых преград;
# my $scale_x = $app_w / 350;
# my $scale_y = $app_h / 350;

# my $car = Figura->new( 150, 300, 50, 50, undef, 255, undef, $scale_x, $scale_y );

# my $gun = Figura->new( 0, 0, 1, 1, undef, undef, undef, $scale_x, $scale_y );

# my @obstruction;
# for ( 1..10 ) {
# 	my $rand = int rand(7);
# 	my $obstruction = Figura->new(
# 		50 * $rand, -50 * $rand, 50, 50,
# 		255, undef, undef, $scale_x, $scale_y
# 	);
# 	push @obstruction, $obstruction;
# }

# $app->run();



# sub event {
#     my ($event, $app) = @_;

#     if( $event->type == SDL_QUIT ) {
#     	$app->stop;
#     }

#     elsif($event->type == SDL_ACTIVEEVENT) {
#         if($event->active_state & SDL_APPINPUTFOCUS) {
#             if($event->active_gain) {
#                 return 1;
#             }
#             else {
#                 $app->pause(\&event);
#             }
#         }
#     }

#     elsif($event->type == SDL_KEYDOWN) {
#         if($event->key_sym == SDLK_SPACE) {
#             return 1 if $app->paused;
             
#             $app->pause(\&event);
#         }
#     }
# }



# sub show {
#     my ($delta, $app) = @_;

#     #obstruction
# 	for my $i ( @obstruction ){
# 		$i->draw_black( $app );
			
# 		$i->{ y } +=  $scale_y;
		
# 		$i->draw( $app ); 
	
# 		if( $i->{ y } > $scale_y * 350) {
# 			$i->{ y } = -50 * (int rand(5)) * $scale_y;
# 			$i->{ x } = (int rand(6) + 1) * 50 * $scale_x;
# 			$i->{ red } = 255;
# 		}

# 		if(int $i->{ x } == int $car->{ x }
# 			&& $i->{ y } >= $car->{ y } - $scale_y * 49
# 			&& $i->{ red } > 200
# 		){
# 				$app->stop;
# 				print "BUMSSS...\npoints:$points\nobstruction:$o_i\n";				
# 		}
# 	}

#     #car
# 	$car->draw_black( $app );

# 	$car->{ x } +=  $car->{ dx } * $scale_x * 50;
# 	$car->{ y } +=  $car->{ dy } * $scale_y * 50;
# 	$car->{ dx } =  0;
# 	$car->{ dy } =  0;
	
# 	$car->draw( $app ); 

#     $app->update;
#     $o_i += 1;
# }



# sub ride {
# 	my ($event, $app) = @_;

# 	$event->type == SDL_KEYDOWN
# 		or return;

# 	if( $event->key_sym == SDLK_LEFT ) {
# 		$car->{ dx } -= 1;
# 	}

# 	if( $event->key_sym == SDLK_RIGHT ) {
# 		$car->{ dx } += 1;
# 	}
# }



# sub move {
# 	my ($step, $app, $t) = @_;

# 	#car
# 	if( $car->{ x } >  $scale_x * 300) {
# 	    $car->{ x } =  $scale_x * 300;
# 	}

# 	if( $car->{ x } < 0) {
# 		$car->{ x } = 0;
# 	}

# 	#gun
# 	for my $i ( @obstruction ){
# 		if( $gun->{ x } > $i->{ x }
# 			&& $gun->{ x } < $i->{ x } + 50 * $scale_x
# 			&& $gun->{ y } > $i->{ y }
# 			&& $gun->{ y } < $i->{ y } + 50 * $scale_y
# 			&& $i->{ red } == 255
# 		){
# 			$i->{ red } = 0;
			
# 		}
# 	}

# 	if( $points > 5000 ) {
# 		$app->stop;
# 		print "You are Winner\n";
# 	}

# 	$points += 1;
# }



# sub cursor {
# 	my ($event, $app) = @_;

# 	$event->type == SDL_MOUSEMOTION
# 	or return;

# 	$gun->draw_black( $app );
	
# 	$gun->{ x } = $event->motion_x;
# 	$gun->{ y } = $event->motion_y;

# 	$gun->draw( $app );
# }
