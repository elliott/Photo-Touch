//
//  AppController.h
//  Photo Touch
//
//  Created by Elliott Harris on 3/25/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PhotoView.h"


@interface AppController : NSObject {
	IBOutlet PhotoView *photoView;
	NSProgressIndicator *progress;
}

@end
