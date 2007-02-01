/*
 *  ModifierMap.m
 *  HotKeyToolKit
 *
 *  Created by Shadow Team.
 *  Copyright (c) 2004 - 2007 Shadow Lab. All rights reserved.
 */

#import "HKKeyMap.h"
#include <Carbon/Carbon.h>

typedef struct __ModifierMap {
  UInt32 size;
  struct __ModifierEntry {
    UInt32 input;
    UInt32 output;
  } entries[];
} ModifierMap;

static const
ModifierMap _kHKUtilsNativeToCococaMap = {
size:8,
entries:{
{kCGEventFlagMaskCommand, NSCommandKeyMask},
{kCGEventFlagMaskShift, NSShiftKeyMask},
{kCGEventFlagMaskAlphaShift, NSAlphaShiftKeyMask},
{kCGEventFlagMaskAlternate, NSAlternateKeyMask},
{kCGEventFlagMaskControl, NSControlKeyMask},
  /* specials */
{kCGEventFlagMaskHelp, NSHelpKeyMask},
{kCGEventFlagMaskSecondaryFn, NSFunctionKeyMask},
{kCGEventFlagMaskNumericPad, NSNumericPadKeyMask},
}};
static const ModifierMap _kHKUtilsCocoaToNative = {
size:8,
entries:{
{NSAlphaShiftKeyMask, kCGEventFlagMaskAlphaShift},
{NSShiftKeyMask, kCGEventFlagMaskShift},
{NSControlKeyMask, kCGEventFlagMaskControl},
{NSAlternateKeyMask, kCGEventFlagMaskAlternate},
{NSCommandKeyMask, kCGEventFlagMaskCommand},
  /* specials */
{NSHelpKeyMask, kCGEventFlagMaskHelp},
{NSFunctionKeyMask, kCGEventFlagMaskSecondaryFn},
{NSNumericPadKeyMask, kCGEventFlagMaskNumericPad},
}};

static const
ModifierMap _kHKUtilsNativeToCarbonMap = {
size:5,
entries:{
{kCGEventFlagMaskCommand, cmdKey},
{kCGEventFlagMaskShift, shiftKey},
{kCGEventFlagMaskAlphaShift, alphaLock},
{kCGEventFlagMaskAlternate, optionKey},
{kCGEventFlagMaskControl, controlKey},
}
};
static const ModifierMap _kHKUtilsCarbonToNative = {
size:8,
entries:{
{cmdKey, kCGEventFlagMaskCommand},
{shiftKey, kCGEventFlagMaskShift},
{alphaLock, kCGEventFlagMaskAlphaShift},
{optionKey, kCGEventFlagMaskAlternate},
{controlKey, kCGEventFlagMaskControl},
  /* Additional mapping */
{rightShiftKey, kCGEventFlagMaskShift},
{rightOptionKey, kCGEventFlagMaskAlternate},
{rightControlKey, kCGEventFlagMaskControl},
}};

static const
ModifierMap _kHKUtilsCocoaToCarbon = {
size:5,
entries:{
{NSAlphaShiftKeyMask, alphaLock},
{NSShiftKeyMask, shiftKey},
{NSControlKeyMask, controlKey},
{NSAlternateKeyMask, optionKey},
{NSCommandKeyMask, cmdKey},
}};
static const
ModifierMap _kHKUtilsCarbonToCocoa = {
size:8,
entries:{
{cmdKey, NSCommandKeyMask},
{shiftKey, NSShiftKeyMask},
{alphaLock, NSAlphaShiftKeyMask},
{optionKey, NSAlternateKeyMask},
{controlKey, NSControlKeyMask},
  /* Additional mapping */
{rightShiftKey, NSShiftKeyMask},
{rightOptionKey, NSAlternateKeyMask},
{rightControlKey, NSControlKeyMask},
}};

static
UInt32 _HKUtilsConvertModifier(UInt32 modifier, const ModifierMap *map) {
  unsigned idx = 0;
  UInt32 result = 0;
  while (idx < map->size) {
    if (modifier & map->entries[idx].input)
      result |= map->entries[idx].output;
    idx++;
  }
  return result;
}

UInt32 HKUtilsConvertModifier(UInt32 modifier, HKModifierFormat input, HKModifierFormat output) {
  const ModifierMap *map = NULL;
  switch (input) {
    case kHKModifierFormatNative:
      switch (output) {
        case kHKModifierFormatNative:
          return modifier;
        case kHKModifierFormatCarbon:
          map = &_kHKUtilsNativeToCarbonMap;
          break;
        case kHKModifierFormatCocoa:
          map = &_kHKUtilsNativeToCococaMap;
          break;
      }
      break;
    case kHKModifierFormatCarbon:
      switch (output) {
        case kHKModifierFormatNative:
          map = &_kHKUtilsCarbonToNative;
          break;
        case kHKModifierFormatCarbon:
          return modifier;
        case kHKModifierFormatCocoa:
          map = &_kHKUtilsCarbonToCocoa;
          break;
      }
      break;
    case kHKModifierFormatCocoa:
      switch (output) {
        case kHKModifierFormatNative:
          map = &_kHKUtilsCocoaToNative;
          break;
        case kHKModifierFormatCarbon:
          map = &_kHKUtilsCocoaToCarbon;
          break;
        case kHKModifierFormatCocoa:
          return modifier;
      }
      break;
  }
  if (map)
    return _HKUtilsConvertModifier(modifier, map);
  
  return 0;
}

