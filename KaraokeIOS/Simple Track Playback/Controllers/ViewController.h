
#import <UIKit/UIKit.h>
#import <Spotify/Spotify.h>

@interface ViewController : UIViewController<SPTAudioStreamingDelegate, SPTAudioStreamingPlaybackDelegate, NSXMLParserDelegate>

@property NSMutableDictionary *dict;
@property NSString* currentSong;
@property NSMutableArray *times;
@property NSMutableArray *lines;
@property double onStopPlaybackPosition;
@property NSString* currentSongID;
@property NSThread* lyricsThread;
@property NSMutableDictionary *timeLyrics;
@property NSTimer *timer;

-(void)handleNewSession:(SPTSession *)session;

@end
