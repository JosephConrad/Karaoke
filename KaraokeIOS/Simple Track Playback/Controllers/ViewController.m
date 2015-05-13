
#import "Config.h"
#import "ViewController.h"

@interface ViewController () <SPTAudioStreamingDelegate>

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel2;
@property (weak, nonatomic) IBOutlet UILabel *albumLabel;
@property (weak, nonatomic) IBOutlet UILabel *artistLabel;
@property (weak, nonatomic) IBOutlet UILabel *playBackLabel;
@property (weak, nonatomic) IBOutlet UIImageView *coverView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spinner;


@property (strong, nonatomic) IBOutlet UIView *wallPaper;
@property (weak, nonatomic) IBOutlet UIButton *likeButton;
@property (weak, nonatomic) IBOutlet UIButton *dislikeButton;

@property (nonatomic, strong) SPTSession *session;
@property (nonatomic, strong) SPTAudioStreamingController *player;

@end

@implementation ViewController


-(void)viewDidLoad {
    [super viewDidLoad];
}

//-------------------------------------------------------------------------------------------
// Actions and buttons
//-------------------------------------------------------------------------------------------

- (IBAction)likeButtoon:(id)sender
{
    NSLog(@"Sending like message to server!");
}

- (IBAction)dislikeButton:(id)sender
{
    NSLog(@"Sending dislike message to server!");
}


-(IBAction)rewind:(id)sender
{
    [self.player skipPrevious:nil];
}

-(IBAction)playPause:(id)sender
{
    [self.player setIsPlaying:!self.player.isPlaying callback:nil]; 
    if (self.player.isPlaying) {
        [self stopTimer];
    } else {
        [self runTimer];
    }
}

-(IBAction)fastForward:(id)sender
{
    [self.player skipNext:nil];
}


//-------------------------------------------------------------------------------------------
// Parsing XML
//-------------------------------------------------------------------------------------------

- (void)parserDidStartDocument:(NSXMLParser *)parser
{
    NSLog(@"Parsing started");
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    NSString * errorString = [NSString stringWithFormat:@"Unable to parse XML (Error code %ld )", [parseError code]];
    NSLog(@"error parsing XML: %@", errorString);
    
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict
{
    if ([elementName isEqualToString:@"line"])
    {
        NSString* text = [attributeDict valueForKey:@"text"];
        int time = [[attributeDict valueForKey:@"time"] intValue];
        [self.times addObject: [NSNumber numberWithInteger:time]];
        [self.lines addObject: text];
        [self.timeLyrics setObject:text forKey:[NSNumber numberWithInt:time]];
        
        NSLog(@"Time: %i, Text: %@", time, text);
    }
}


//-------------------------------------------------------------------------------------------
// Logic - updateUI
//-------------------------------------------------------------------------------------------

-(void)updateUI
{
    if (self.player.currentTrackMetadata == nil) {
        self.titleLabel.text = @"Nothing Playing";
        self.titleLabel2.text = @"";
        self.albumLabel.text = @"";
        self.artistLabel.text = @"";
    } else {
        self.titleLabel.text = [self.player.currentTrackMetadata valueForKey:SPTAudioStreamingMetadataTrackName];
        self.currentSong = self.titleLabel.text;
        self.albumLabel.text = [self.player.currentTrackMetadata valueForKey:SPTAudioStreamingMetadataAlbumName];
        self.artistLabel.text = [self.player.currentTrackMetadata valueForKey:SPTAudioStreamingMetadataArtistName];
        self.titleLabel2.text = [self.player.currentTrackMetadata valueForKey:SPTAudioStreamingMetadataTrackURI];
        [self updateCoverArt];
        self.currentSongID = [[self.player.currentTrackMetadata valueForKey:SPTAudioStreamingMetadataTrackURI] componentsSeparatedByString:@":"][2];
        [self updateText];
    }

}


//-------------------------------------------------------------------------------------------
//Updating section with karaoke text
//-------------------------------------------------------------------------------------------
-(void)setText: (NSString*) string {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.titleLabel2.text = string;
    });
}

-(void)updateText {
    self.times = [NSMutableArray array];
    self.lines = [NSMutableArray array];
    [self.times addObject: [NSNumber numberWithInteger:0]];
    [self.lines addObject: @""];
    self.timeLyrics =  [NSMutableDictionary dictionary];
    [self.timeLyrics setObject:@"" forKey:[NSNumber numberWithInt:0]];
    
    
    // Parsing xml
    NSString *myURL = [NSString stringWithFormat:@"%@%@%@", @"http://students.mimuw.edu.pl/~kl291649/xml/", self.currentSongID, @".xml"];
    NSURL *url = [[NSURL alloc] initWithString:myURL];
    NSXMLParser *parser = [[NSXMLParser alloc] initWithContentsOfURL:url];
    
    [parser setDelegate:self];
    [parser setShouldResolveExternalEntities:NO];
    [parser setShouldProcessNamespaces:NO];
    [parser setShouldReportNamespacePrefixes:NO];
    BOOL xmlParseSuccess = [parser parse];
    if (xmlParseSuccess) {
        NSLog(@"Successed Parsing!");
    } else if (!xmlParseSuccess) {
        NSLog(@"Error Parsing!");
    }
    [self runTimer];
} 



- (int) findPrevious: (double) beginning {
    int i = 0;
    int returnVal = i;
    while (i < (int)[self.times count]-1){
        if (beginning >= [self.times[i] doubleValue]) {
            returnVal = i;
        }
        i++;
    }
    return returnVal;
}


//-------------------------------------------------------------------------------------------
// Timer
//-------------------------------------------------------------------------------------------

-(void) runTimer
{
    self.timer = [NSTimer scheduledTimerWithTimeInterval: 0.2
                                                  target: self
                                                selector:@selector(displayLyrics)
                                                userInfo: nil repeats:YES];
}


-(void)stopTimer
{
    [self.timer invalidate];
    self.timer = nil;
}


- (void)displayLyrics
{
    double playbackPosition = self.player.currentPlaybackPosition;
    int i = [self findPrevious:playbackPosition];
    if (i == 0) i = 1;
    NSString *line = [self.lines objectAtIndex:i];
    [self setText:line];
}


//-------------------------------------------------------------------------------------------
// Update cover
//-------------------------------------------------------------------------------------------

-(void)updateCoverArt
{
    if (self.player.currentTrackMetadata == nil) {
        self.coverView.image = nil;
        return;
    }
    
    [self.spinner startAnimating];
    
    [SPTAlbum albumWithURI:[NSURL URLWithString:[self.player.currentTrackMetadata valueForKey:SPTAudioStreamingMetadataAlbumURI]]
                   session:self.session
                  callback:^(NSError *error, SPTAlbum *album) {
                      
        NSURL *imageURL = album.largestCover.imageURL;
        if (imageURL == nil) {
            NSLog(@"Album %@ doesn't have any images!", album);
            self.coverView.image = nil;
            return;
        }
                      
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSError *error = nil;
            UIImage *image = nil;
            NSData *imageData = [NSData dataWithContentsOfURL:imageURL options:0 error:&error];
                          
            if (imageData != nil) {
                image = [UIImage imageWithData:imageData];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.spinner stopAnimating];
                    self.coverView.image = image;
                    if (image == nil) {
                    NSLog(@"Couldn't load cover image with error: %@", error);
                }
            });
        });
    }];
}


-(void)handleNewSession:(SPTSession *)session
{
    self.session = session;
    
    if (self.player == nil) {
        self.player = [[SPTAudioStreamingController alloc] initWithClientId:@kClientId];
        self.player.playbackDelegate = self;
    }

    [self.player loginWithSession:session callback:^(NSError *error) {

		if (error != nil) {
			NSLog(@"*** Enabling playback got error: %@", error);
			return;
		}
        
        [SPTRequest requestItemAtURI:[NSURL URLWithString:@"spotify:user:knrd.lisiecki"]
                         withSession:session
                            callback:^(NSError *error, id object) {
                                
               if (error != nil) {
                   NSLog(@"*** Album lookup got error %@", error);
                   return;
               }
                                
        }];
        
		[SPTRequest requestItemAtURI:[NSURL URLWithString:@"spotify:user:knrd.lisiecki:playlist:2jJ52IFoQnq7pTz0dUOzDJ"]
                         withSession:session
                            callback:^(NSError *error, id object) {

            if (error != nil) {
                NSLog(@"*** Album lookup got error %@", error);
                return;
            }

            [self.player playTrackProvider:(id <SPTTrackProvider>)object callback:nil];

        }];
	}];
}



//-------------------------------------------------------------------------------------------
//Track Player Delegates
//-------------------------------------------------------------------------------------------

- (void)audioStreaming:(SPTAudioStreamingController *)audioStreaming didReceiveMessage:(NSString *)message
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Message from Spotify"
                                                        message:message
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
    [alertView show];
}


- (void) audioStreaming:(SPTAudioStreamingController *)audioStreaming didChangeToTrack:(NSDictionary *)trackMetadata
{
    [self updateUI];
}

@end
