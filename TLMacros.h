// TLDebugLog is a drop-in replacement for NSLog that logs iff the build variable TL_DEBUG is defined
#ifdef TL_DEBUG
#define TLDebugLog(format, args...) NSLog(format, ## args)
#else
#define TLDebugLog(format, args...)
#endif

#ifdef TL_DEVELOPMENT
#define TLDevLog(format, args...) NSLog(format, ## args)
#else
#define TLDevLog(format, args...)
#endif

#define BOUND(min, val, max) MAX(min, MIN(max, val))


// These are temporary; we'll converge back on one style soon enough
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define kBarStyle (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0") ?  UIBarStyleDefault : UIBarStyleBlackOpaque)
