//
//  AppController.m
//  Photo Touch
//
//  Created by Elliott Harris on 3/25/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "AppController.h"


@implementation AppController

-(void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[photoView setLayer:[CATiledLayer layer]];
	[photoView setWantsLayer:YES];
	
	//Set our background to black.
	CALayer *backgroundLayer = [photoView layer];
	backgroundLayer.backgroundColor = CGColorCreateGenericRGB(0.0, 0.0, 0.0, 1.0);
	
	//Set the photoView to full screen by default, cmd+f toggles it.
	[photoView toggleFullScreen:self];
	
	[NSThread detachNewThreadSelector:@selector(loadPhotoBoothPictures:) toTarget:self withObject:nil]; 
	[NSThread detachNewThreadSelector:@selector(loadiPhotoPictures:) toTarget:self withObject:nil];
}

-(void)loadiPhotoPictures:(id)threadParams
{
	NSString *iphotoPath = [NSHomeDirectory() stringByAppendingString:@"/Pictures/iPhoto Library/Originals/"];
	NSDirectoryEnumerator *iphotoEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:iphotoPath];
	
	//First from iPhoto, this will probably be WAY too many images, but hey why not.
	for(NSString *path in iphotoEnumerator) {
		[photoView loadPhotoFromPath:[iphotoPath stringByAppendingPathComponent:path]];
	}
}

-(void)loadPhotoBoothPictures:(id)threadParams
{
	NSString *photoBoothPath = [NSHomeDirectory() stringByAppendingString:@"/Pictures/Photo Booth/"];
	NSDirectoryEnumerator *photoBoothEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:[NSHomeDirectory() stringByAppendingString:@"/Pictures/Photo Booth/"]];
	
	for(NSString *path in photoBoothEnumerator) {
		[photoView loadPhotoFromPath:[photoBoothPath stringByAppendingPathComponent:path]];
	}
}


@end
