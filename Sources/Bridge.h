#import <Foundation/Foundation.h>

// Private SkyLight calls (read-only) for listing Spaces per display.
int CGSMainConnectionID(void);
CFArrayRef CGSCopyManagedDisplaySpaces(int cid);
