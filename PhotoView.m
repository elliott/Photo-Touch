//
//  PhotoView.m
//  Photo Touch
//
//  Created by Elliott Harris on 3/25/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PhotoView.h"

#define CGAutorelease(x) (__typeof(x))[NSMakeCollectable(x) autorelease]


CGImageRef CreateCGImageFromFile(NSString* path)
{
    NSURL*            url = [NSURL fileURLWithPath:path];
    CGImageRef        imageRef = NULL;
    CGImageSourceRef  sourceRef;

    sourceRef = CGImageSourceCreateWithURL((CFURLRef)url, NULL);
    if(sourceRef) {
        imageRef = CGImageSourceCreateImageAtIndex(sourceRef, 0, NULL);
        CGAutorelease(sourceRef);
    }

    return imageRef;
}

@interface NSEvent (MultiTouchEvents)
-(float)magnification;
@end

@interface PhotoView (PRIVATE)
-(int)layersPerRowForTotal:(int)totalLayers;
-(void)arrangeSublayers;
-(CGPathRef)newPathStartingAtPoint:(CGPoint)aPoint;
@end

@implementation PhotoView

-(void)awakeFromNib
{
	isGrid = NO;
	topZPosition = 0.02; //Hi Nick!
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

-(void)loadPhotoFromPath:(NSString *)aPath
{
	if(![[aPath pathExtension] isEqual:@"jpg"])
		return;
	
	//Create a new layer, load it's contents from disk, and add it as a sublayer.
	CALayer *newLayer = [CALayer layer];
	
	//Load the image from the given path.
	CGImageRef layerContents = CreateCGImageFromFile(aPath);
	
	/*	As we create new layers, we essentially want them to stack on top of each other, however we strive to have at least a slice
	 *	of the image visible at all times, so that zPosition can be adjusted properly with swipes to see the image.
	 *	To achieve this effect, we randomize the point that the image is placed at, as well as some random degree of initial rotation.
	 */
	
	//The first two floats have no effect since the position property is set immediately afterwards, trivializing these values.
	newLayer.bounds = CGRectMake(0.0, 0.0, CGImageGetWidth(layerContents) / 3.0, CGImageGetHeight(layerContents) / 3.0);
	
	CGPoint randomPoint = CGPointMake(arc4random() % ((NSInteger)(self.bounds.size.width + 25.0)), arc4random() % ((NSInteger)(self.bounds.size.height + 25.0)));
	
	newLayer.position = randomPoint;

	newLayer.transform = CATransform3DRotate(newLayer.transform, (((arc4random() % 2) ? 1 : -1) * (arc4random() % 90)) * M_PI / 180, 0.0, 0.0, 1.0);
			
	newLayer.contents = (id)layerContents;
	newLayer.contentsGravity = kCAGravityResizeAspect;
	newLayer.opacity = 1.0;
	newLayer.opaque = YES;
	
	CGAutorelease(layerContents);
	
	[newLayer setValue:[NSNumber numberWithBool:NO] forKey:@"isZoomed"];
	
	[[self layer] addSublayer:newLayer];
	[CATransaction commit];
}

-(void)keyDown:(NSEvent *)anEvent
{
	#define KEY_CODES_DEBUG 0
	
	#if KEY_CODES_DEBUG
	NSLog(@"keyDown: %@", anEvent);
	#endif
	
	NSUInteger eventFlags = [anEvent modifierFlags];
	
	#define F_KEY_CODE (3)
	if(eventFlags & NSCommandKeyMask && [anEvent keyCode] == F_KEY_CODE) {
		[self toggleFullScreen:self];
		return;
	}
	
	#define TAB_KEY_CODE (48)
	if([anEvent keyCode] == TAB_KEY_CODE && isGrid) {
		float delayedDuration = 1.0;
		//We add a special case for tab during grid mode that will run a simple flip animation on each picture.
		for(CALayer *layer in [[self layer] sublayers]) {
			[layer addAnimation:[self flipAnimationWithDuration:delayedDuration] forKey:@"flipAnimation"];
			//We don't need to make a toggle, since the animation will be removed when it finishes.
			delayedDuration += 0.050; //We delay each layer a little bit longer to get a tiered effect.
		}
		
		return;
	} 

	#define SPACE_BAR_KEY_CODE (49)
	if([anEvent keyCode] == SPACE_BAR_KEY_CODE)
		[self arrangeSublayers];
	else {
		if(isExploding) {
			for(CALayer *layer in [[self layer] sublayers])
				[layer removeAllAnimations];
			isExploding = NO;
		} else {
			for(CALayer *layer in [[self layer] sublayers])
				[layer addAnimation:[self explosionAnimation] forKey:@"explosionAnimation"];
			isExploding = YES;
		}
	}	
}

-(void)mouseDown:(NSEvent *)anEvent
{
	//We need to get the layer that's been selected.
	if(!currentLayer) {
		currentLayer = [[self layer] hitTest:NSPointToCGPoint([anEvent locationInWindow])];
		//currentLayer.zPosition = currentLayer.zPosition + 0.1;
	}
	
	//We don't want to modify the root layer.
	if(currentLayer == [self layer]) {
		currentLayer = nil;
		return;
	}
	
	CGRect currentBounds = currentLayer.bounds;
	//We need the zoom value for the currentLayer, so get it.
	BOOL isZoomed = [[currentLayer valueForKey:@"isZoomed"] boolValue];
	
	float scaleFactor = 0.0;
	
	if(isGrid)
		scaleFactor = 2.5;
	else
		scaleFactor = 1.25;
	
	if([anEvent clickCount] > 1) {
		//Double click, we use a flag to change between zoomed and not zoomed, which does the same thing as a single click, but persists it.
		if(isZoomed) {
			//Unzoom.
			[CATransaction begin];
			[CATransaction setValue:[NSNumber numberWithFloat:0.5] forKey:kCATransactionAnimationDuration];
			currentLayer.zPosition = [[currentLayer valueForKey:@"oldZPosition"] floatValue];	
			//currentLayer.bounds = CGRectMake(0.0, 0.0, currentBounds.size.width / 1.25, currentBounds.size.height / 1.25);
			[CATransaction commit];
			[currentLayer setValue:[NSNumber numberWithBool:NO] forKey:@"isZoomed"];
		} else {
			[CATransaction begin];
			[CATransaction setValue:[NSNumber numberWithFloat:0.5] forKey:kCATransactionAnimationDuration];
			currentLayer.bounds = CGRectMake(0.0, 0.0, currentBounds.size.width * scaleFactor, currentBounds.size.height * scaleFactor);
			[currentLayer setValue:[NSNumber numberWithFloat:currentLayer.zPosition] forKey:@"oldZPosition"];
			currentLayer.zPosition = 1000.0;
			[CATransaction commit];
			[currentLayer setValue:[NSNumber numberWithBool:YES] forKey:@"isZoomed"];
		}
		
		return;
	}
	
	if(isZoomed)
		return;
	
	[CATransaction begin];
	[CATransaction setValue:[NSNumber numberWithFloat:0.5] forKey:kCATransactionAnimationDuration];
	currentLayer.bounds = CGRectMake(0.0, 0.0, currentBounds.size.width * scaleFactor, currentBounds.size.height * scaleFactor);
	//currentLayer.zPosition = 1000.0;
	[CATransaction commit];
}

-(void)mouseDragged:(NSEvent *)anEvent
{
	//Since dragging is continous, we will set currentLayer similar to beginGesture, with it being unset in mouseUp at the end of the drag.
	if(!currentLayer) {
		currentLayer = [[self layer] hitTest:NSPointToCGPoint([anEvent locationInWindow])];
	}
	
	//We don't want to modify the root layer.
	if(currentLayer == [self layer]) {
		currentLayer = nil;
		return;
	}
	
	CGPoint currentOrigin = currentLayer.position;
		
	[CATransaction begin];
	[CATransaction setValue:[NSNumber numberWithFloat:0.001
	] forKey:kCATransactionAnimationDuration];
	currentLayer.position = CGPointMake(currentOrigin.x + [anEvent deltaX], currentOrigin.y + -[anEvent deltaY]);
	[CATransaction commit];
	currentLayer.opacity = 0.5;
	if(currentLayer.zPosition < topZPosition) {
		currentLayer.zPosition = (topZPosition += 0.1);
		//Write this new zPosition into the layer, so it will be loaded instead of the old zPosition, which is now wrong.
		[currentLayer setValue:[NSNumber numberWithFloat:currentLayer.zPosition] forKey:@"oldZPosition"];
	}
}

- (void)mouseUp:(NSEvent *)theEvent
{
	//We don't want to modify the root layer.
	if(currentLayer == [self layer]) {
		currentLayer = nil;
		return;
	}
	
	//We need the zoom value for the currentLayer, so get it.
	BOOL isZoomed = [[currentLayer valueForKey:@"isZoomed"] boolValue];
	
	if(isZoomed) {
		currentLayer.opacity = 1.0;
		return;
	}
	
	CGRect currentBounds = currentLayer.bounds;
	float scaleFactor = 0.0;
	
	if(isGrid)
		scaleFactor = 2.5;
	else
		scaleFactor = 1.25;
	
	//Reverse the effects of mouseDown
	[CATransaction begin];
	[CATransaction setValue:[NSNumber numberWithFloat:0.5] forKey:kCATransactionAnimationDuration];
	currentLayer.bounds = CGRectMake(0.0, 0.0, currentBounds.size.width / scaleFactor, currentBounds.size.height / scaleFactor);
	//This reverts a mouseDragged effect, but is harmless for mouseDown.
	currentLayer.opacity = 1.0;
	[CATransaction commit];
	currentLayer = nil;
}

-(void)beginGestureWithEvent:(NSEvent *)anEvent;
{
	CALayer *eventLayer = [[self layer] hitTest:NSPointToCGPoint([anEvent locationInWindow])];
	
	//We don't want to modify the root layer.
	if(eventLayer == [self layer]) {
		currentLayer = nil;
		return;
	}
	
	currentLayer = eventLayer;
}

-(void)endGestureWithEvent:(NSEvent *)anEvent;
{	
	currentLayer = nil;
}

- (void)magnifyWithEvent:(NSEvent *)anEvent
{	
	//We use the magnification constant from the event to scale the bounds of the image.
	CGRect currentBounds = currentLayer.bounds;
	
	[CATransaction begin];
	[CATransaction setValue:[NSNumber numberWithFloat:0.001] forKey:kCATransactionAnimationDuration];
	currentLayer.bounds = CGRectMake(0.0, 0.0, (currentBounds.size.width + (currentBounds.size.width * [anEvent magnification])) , 
				(currentBounds.size.height + (currentBounds.size.height * [anEvent magnification])));
	[CATransaction commit];
}

- (void)rotateWithEvent:(NSEvent *)anEvent
{	
	//We use the rotation constant from the event to rotate the image.
	CATransform3D currentRotation = currentLayer.transform;
	
	[CATransaction begin];
	[CATransaction setValue:[NSNumber numberWithFloat:0.001] forKey:kCATransactionAnimationDuration];
	currentLayer.transform = CATransform3DRotate(currentRotation, [anEvent rotation] * M_PI / 180, 0.0, 0.0, 1.0);
	[CATransaction commit];
}

- (void)swipeWithEvent:(NSEvent *)anEvent
{
	//beginGesture and endGesture don't appear to be called for swipe, but swipe is also not continuous, so we can just work with the layer we are called on.
	CALayer *eventLayer = [[self layer] hitTest:NSPointToCGPoint([anEvent locationInWindow])];
	
	//We don't want to modify the root layer.
	if(eventLayer == [self layer]) {
		currentLayer = nil;
		return;
	}
		
	float currentZPos = eventLayer.zPosition;
	float deltaZ = 0.0;
	float deltaY = [anEvent deltaY];
	
	if(deltaY == 1.0) {
		//Swipe Up
		deltaZ = 0.1;
	} else if(deltaY == -1.0) {
		//Swipe Down
		deltaZ = -0.1;
	} else {
		//Swipe Left or Right. Value ignored.
		//deltaZ = 0.0;
	}

	[CATransaction begin];
	[CATransaction setValue:[NSNumber numberWithFloat:0.001] forKey:kCATransactionAnimationDuration];
	eventLayer.zPosition = currentZPos + deltaZ;
	[CATransaction commit];
}

#pragma mark Arrange and Path methods

//This method arranges the photos (sublayers) into a nice grid pattern, based on how many we've got and the window dimensions, scaling appropriately.
//The end result should be something like the AppleTV screen, but with static content.
-(void)arrangeSublayers
{
	if(isGrid) {
		[CATransaction begin];
		[CATransaction setValue:[NSNumber numberWithFloat:1.0] forKey:kCATransactionAnimationDuration];
		//We handle the reverse case at the top since it requires less math, it fits into an if nicely.
		for(CALayer *layer in [[self layer] sublayers]) {
			//We need the contents of the layer to determine the size we should make the layer.
			CGImageRef layerContents = (CGImageRef)layer.contents;
			[layer setBounds:CGRectMake(0.0, 0.0, CGImageGetWidth(layerContents) / 3.0, CGImageGetHeight(layerContents) / 3.0)];
			
			//We make a random point, just like when we create a layer.
			[layer setPosition:CGPointMake(arc4random() % ((NSInteger)(self.bounds.size.width + 25.0)), arc4random() % ((NSInteger)(self.bounds.size.height + 25.0)))];
			
			//We also need a random rotation, just like when we create a layer.
			[layer setTransform:CATransform3DRotate(layer.transform, (((arc4random() % 2) ? 1 : -1) * (arc4random() % 90)) * M_PI / 180, 0.0, 0.0, 1.0)];
			
			[layer setValue:[NSNumber numberWithBool:NO] forKey:@"isZoomed"];
		}
		
		[CATransaction commit];
		
		isGrid = NO;
		
		return;
	}
				
	isGrid = YES;
	int sublayerCount = [[[self layer] sublayers] count];
	
	//We need the numbers of layers we can put in each row evenly, and also the remainder.	
	int layersInRow = [self layersPerRowForTotal:sublayerCount]; //This method uses a simple algorithm to figure out our row size.
	int layersInColumn = (sublayerCount / layersInRow) + (sublayerCount % layersInRow); //and then we use the result to determine the column size.
		
	//We are going to make 6 rows of images, so we need to determine the size of the layers and number of layers we can fit into each row.
	NSRect currentBounds = [self bounds];
	
	//We need to determine the size our layers will be, which can be determined using the number of sublayers and the current bounds.
	float layerHeight = -10 + (currentBounds.size.height) / (layersInRow); //We subtract 10 here to get some spacing on the grid.
	float layerWidth = (currentBounds.size.width) / (layersInColumn);
	
	//Now we need to iterate through the sublayers with a double for loop, positioning them into a grid.
	NSArray *sublayers = [[self layer] sublayers];
	float currentX = (layerWidth / 2.0); //This represents the X origin for the top left layer.
	float currentY = currentBounds.size.height - (layerHeight / 2.0); //The initial Y origin for the top left layer	
	
	for(CALayer *layer in sublayers) {
		[CATransaction begin];
		[CATransaction setValue:[NSNumber numberWithBool:YES] forKey:kCATransactionDisableActions];
		//[layer setBorderWidth:0.0];
		[CATransaction commit];
	
		//Reset currentX and set currentY as necessary.
		if(currentX >= currentBounds.size.width) {
			currentX = (layerWidth / 2.0); //Reset to initial X
			currentY -= (layerHeight + 10.0); //Change the row we are working on.
		}
	
		[CATransaction begin];
		[CATransaction setValue:[NSNumber numberWithFloat:1.0] forKey:kCATransactionAnimationDuration];
		[layer setBounds:CGRectMake(0.0, 0.0, layerWidth, layerHeight)];
		[layer setPosition:CGPointMake(currentX, currentY)];
		//Make sure we negate all the rotation current done by setting it to the identitiy.
		[layer setTransform:CATransform3DIdentity];
		[layer setValue:[NSNumber numberWithBool:NO] forKey:@"isZoomed"];
		[CATransaction commit];
	
		//Increment currentX
		currentX += layerWidth; //Next column.
	}
}

-(int)layersPerRowForTotal:(int)totalLayers
{
	int ret = 0;
	int total = totalLayers;
	
	while((total = total / 2) > 2) {
		ret += 3;
	}
	
	if(ret == 0)
		ret = 1;
	
	return ret;
}

-(CAAnimation *)flipAnimationWithDuration:(float)aDuration
{	
	//This animation flips a photo around 360 degrees. We'll need two animations - one perspective correction, and one rotation.y
	CABasicAnimation *perspectiveAnimation = [CABasicAnimation animationWithKeyPath:@"transform"];
	
	CATransform3D perspectiveTransform = CATransform3DIdentity;
	perspectiveTransform.m34 = 1 / 2000.0;
	
	perspectiveAnimation.fromValue = [NSValue valueWithCATransform3D:CATransform3DIdentity];
	perspectiveAnimation.toValue = [NSValue valueWithCATransform3D:perspectiveTransform];
	perspectiveAnimation.duration = aDuration;
	perspectiveAnimation.removedOnCompletion = YES;
	
	CABasicAnimation *rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.y"];
	rotationAnimation.fromValue = [NSNumber numberWithFloat:0.0];
	rotationAnimation.toValue = [NSNumber numberWithFloat:2*M_PI]; //We actually WANT to see the back of the image.
	rotationAnimation.duration = aDuration;
	rotationAnimation.removedOnCompletion = NO;
	
	CAAnimationGroup *flipGroup = [CAAnimationGroup animation];
	flipGroup.animations = [NSArray arrayWithObjects:perspectiveAnimation, rotationAnimation, nil];
	flipGroup.duration = aDuration;
	flipGroup.removedOnCompletion = !isExploding;
	if(isExploding) {
		flipGroup.repeatCount = 1e100;

	}

	return flipGroup;
}	

-(CAAnimation *)explosionAnimation
{
	CGPoint startingPoint;
	NSInteger x = arc4random() % ((NSInteger)(self.bounds.size.width) + 50);
	NSInteger y = arc4random() % ((NSInteger)(self.bounds.size.width) + 50);
	startingPoint = CGPointMake(x, y);
	
	return [self explodingAnimationForPoint:startingPoint];
}

-(CAAnimation *)explodingAnimationForPoint:(CGPoint)aPoint
{
	CGPathRef path = [self newPathStartingAtPoint:aPoint];
	CAKeyframeAnimation *explosionAnimation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
	
	explosionAnimation.path = path;
	explosionAnimation.duration = (arc4random() % 15 + 5); //5-15 seconds.
	explosionAnimation.autoreverses = YES;
	explosionAnimation.repeatCount = 1e100;
	
	CGPathRelease(path);
	return explosionAnimation;
}

-(CGPathRef)newPathStartingAtPoint:(CGPoint)aPoint
{
	//This method creates a random path starting a some point.
	NSUInteger count = 10;
	CGPoint point;
	CGPoint points[count];
	points[0] = aPoint;
	
	int i = 1;
	 //Now we randomize the rest of the points.
	for(i; i < count; i++) {
		NSInteger randomX = arc4random() % (NSInteger)(self.bounds.size.width + 50.0);
		NSInteger randomY = arc4random() % (NSInteger)(self.bounds.size.width + 50.0);
		point = CGPointMake(randomX, randomY);
		points[i] = point;		
	}
	
	CGMutablePathRef newPath = CGPathCreateMutable();
    CGPathAddLines (newPath, NULL, points, count);
	
	return newPath;
}

#pragma mark Full Screen Support
-(IBAction)toggleFullScreen:(id)sender
{
	if(isFullscreen) {
		[self exitFullScreenModeWithOptions:nil];
		[[self window] makeFirstResponder:self];
		isFullscreen = NO;
	} else {
		[self enterFullScreenMode:[NSScreen mainScreen] withOptions:nil];
		isFullscreen = YES;
	}
}
	
@end
