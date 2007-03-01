/*
 *  SoundView.h
 *  Spark Plugins
 *
 *  Created by Black Moon Team.
 *  Copyright (c) 2004 - 2007, Shadow Lab. All rights reserved.
 */

#import "SKLevelView.h"

@interface SoundView : SKLevelView {

}

- (BOOL)isMuted;
- (void)setMuted:(BOOL)flag;

@end
