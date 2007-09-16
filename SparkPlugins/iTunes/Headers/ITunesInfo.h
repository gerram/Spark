/*
 *  ITunesInfo.h
 *  Spark Plugins
 *
 *  Created by Black Moon Team.
 *  Copyright (c) 2004 - 2007, Shadow Lab. All rights reserved.
 */

#import <Cocoa/Cocoa.h>
#import "ITunesAESuite.h"

typedef struct _ITunesVisual {
  BOOL shadow;
  NSPoint location;
  NSTimeInterval delay;
  /* Colors */ 
  float text[4];
  float border[4];
  float backtop[4];
  float backbot[4];
} ITunesVisual;

SK_PRIVATE
BOOL ITunesVisualIsEqualTo(const ITunesVisual *v1, const ITunesVisual *v2);

enum {
  kiTunesSettingDefault = 0,
  kiTunesSettingCustom = 1,
};

SK_PRIVATE
const NSPoint kiTunesUpperLeft;
SK_PRIVATE
const NSPoint kiTunesUpperRight;
SK_PRIVATE
const NSPoint kiTunesBottomLeft;
SK_PRIVATE
const NSPoint kiTunesBottomRight;

SK_PRIVATE
const ITunesVisual kiTunesDefaultSettings;

@class ITunesStarView, ITunesProgressView;
@interface ITunesInfo : NSWindowController {
  IBOutlet NSTextField *ibName;
  IBOutlet NSTextField *ibAlbum;
  IBOutlet NSTextField *ibArtist;
  
  IBOutlet NSTextField *ibTime;
  IBOutlet ITunesStarView *ibRate;
  IBOutlet ITunesProgressView *ibProgress;
  @private
    int ia_loc;
}

+ (ITunesInfo *)sharedWindow;

- (IBAction)display:(id)sender;

- (void)setTrack:(iTunesTrack *)track;

/* Settings */
- (void)getVisual:(ITunesVisual *)visual;
- (void)setVisual:(const ITunesVisual *)visual;

- (NSTimeInterval)delay;
- (void)setDelay:(NSTimeInterval)aDelay;
- (void)setPosition:(NSPoint)aPoint;
- (void)setHasShadow:(BOOL)hasShadow;

- (NSColor *)textColor;
- (void)setTextColor:(NSColor *)aColor;

- (NSColor *)borderColor;
- (void)setBorderColor:(NSColor *)aColor;

- (NSColor *)backgroundColor;
- (void)setBackgroundColor:(NSColor *)aColor;

- (NSColor *)backgroundTopColor;
- (void)setBackgroundTopColor:(NSColor *)aColor;

- (NSColor *)backgroundBottomColor;
- (void)setBackgroundBottomColor:(NSColor *)aColor;

/* Internal */
- (void)setDuration:(SInt32)aTime rate:(SInt32)rate;
@end

SK_INLINE
UInt64 ITunesVisualPackColor(float color[4]) {
  UInt64 pack = 0;
  pack |= (llround(color[0] * 0xffff) & 0xffff) << 0;
  pack |= (llround(color[1] * 0xffff) & 0xffff) << 16;
  pack |= (llround(color[2] * 0xffff) & 0xffff) << 32;
  pack |= (llround(color[3] * 0xffff) & 0xffff) << 48;
  return pack;
}

SK_INLINE
void ITunesVisualUnpackColor(UInt64 pack, float color[4]) {
  color[0] = (float)((pack >> 0) & 0xffff) / 0xffff;
  color[1] = (float)((pack >> 16) & 0xffff) / 0xffff;
  color[2] = (float)((pack >> 32) & 0xffff) / 0xffff;
  color[3] = (float)((pack >> 48) & 0xffff) / 0xffff;
}

typedef struct _ITunesPackedVisual {
  UInt8 shadow;
  UInt64 colors[4];
  CFSwappedFloat32 x, y;
  CFSwappedFloat64 delay;
} ITunesPackedVisual;

SK_INLINE
NSData *ITunesVisualPack(ITunesVisual *visual) {
  NSMutableData *data = [[NSMutableData alloc] initWithCapacity:sizeof(ITunesPackedVisual)];
  [data setLength:sizeof(ITunesPackedVisual)];
  ITunesPackedVisual *pack = [data mutableBytes];
  pack->shadow = visual->shadow ? 1 : 0;
  pack->delay = CFConvertFloat64HostToSwapped(visual->delay);
  pack->x = CFConvertFloat32HostToSwapped((float)visual->location.x);
  pack->y = CFConvertFloat32HostToSwapped((float)visual->location.y);
  pack->colors[0] = OSSwapHostToBigInt64(ITunesVisualPackColor(visual->text));
  pack->colors[1] = OSSwapHostToBigInt64(ITunesVisualPackColor(visual->border));
  pack->colors[2] = OSSwapHostToBigInt64(ITunesVisualPackColor(visual->backtop));
  pack->colors[3] = OSSwapHostToBigInt64(ITunesVisualPackColor(visual->backbot));
  return [data autorelease];
}

SK_INLINE
BOOL ITunesVisualUnpack(NSData *data, ITunesVisual *visual) {
  NSCParameterAssert(visual != NULL);
  if (!data || [data length] != sizeof(ITunesPackedVisual)) {
    return NO;
  }
  bzero(visual, sizeof(*visual));
  const ITunesPackedVisual *pack = [data bytes];
  visual->shadow = pack->shadow != 0;
  visual->delay = CFConvertFloat64SwappedToHost(pack->delay);
  visual->location.x = CFConvertFloat32SwappedToHost(pack->x);
  visual->location.y = CFConvertFloat32SwappedToHost(pack->y);
  ITunesVisualUnpackColor(OSSwapBigToHostInt64(pack->colors[0]), visual->text);
  ITunesVisualUnpackColor(OSSwapBigToHostInt64(pack->colors[1]), visual->border);
  ITunesVisualUnpackColor(OSSwapBigToHostInt64(pack->colors[2]), visual->backtop);
  ITunesVisualUnpackColor(OSSwapBigToHostInt64(pack->colors[3]), visual->backbot);
  return YES;
}
