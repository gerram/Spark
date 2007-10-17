//
//  TAKeystroke.h
//  Spark Plugins
//
//  Created by Jean-Daniel Dupas on 17/10/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <HotKeyToolKit/HotKeyToolKit.h>

@interface TAKeystroke : NSObject {
  @private
  UniChar ta_char;
  HKKeycode ta_code;
  HKModifier ta_modifier;
  
  NSString *ta_desc;
}

- (id)initWithKeycode:(HKKeycode)keycode character:(UniChar)character modifier:(HKModifier)modifier;
- (id)initFromRawKey:(UInt64)rawKey;

- (void)sendKeystroke:(CGEventSourceRef)src;

- (NSString *)shortcut;

- (UInt64)rawKey;

@end