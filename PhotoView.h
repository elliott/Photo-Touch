/*!
    @class	PhotoView
    @discussion  PhotoView is a class that implments multitouch interaction with photos, which are represented
				 as layers in PhotoView's layer tree. PhotoView is the root layer for all the photos, and thus,
				 it's sublayers array represents every photo we are displaying. Multitouch events hit test against
				 the sublayers so that the appropriate layer is dealt with during events. Since layers don't deal
				 with events, all event handling for every layer in handled in this class.
*/

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

@interface PhotoView : NSView {

	//We cache the layer because during some gestures to keep talking 
	//to the correct layer even if our mouse position is no longer on top
	//of the layer. It's reset and set during beginGesture and endGesture.
	CALayer *currentLayer;
	BOOL isGrid;
	BOOL isExploding;
	BOOL isFullscreen;
	
	float topZPosition;
}

-(void)loadPhotoFromPath:(NSString *)aPath;
-(IBAction)toggleFullScreen:(id)sender;
-(void)arrangeSublayers;

@end
