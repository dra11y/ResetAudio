//
//  WakeAudio.h
//  WakeAudio
//
//  Created by Tom Grushka on 10/28/23.
//

#import <Foundation/Foundation.h>

//! Project version number for WakeAudio.
FOUNDATION_EXPORT double WakeAudioVersionNumber;

//! Project version string for WakeAudio.
FOUNDATION_EXPORT const unsigned char WakeAudioVersionString[];

BOOL isAudioAsleep(void);

void wakeAudioInterfaces(void);
