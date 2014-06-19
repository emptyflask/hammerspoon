#import "lua/lauxlib.h"

int window_gc(lua_State* L) {
    AXUIElementRef* winptr = lua_touserdata(L, 1);
    CFRelease(*winptr);
    return 0;
}

void window_push_window_as_userdata(lua_State* L, AXUIElementRef win) {
    AXUIElementRef* winptr = lua_newuserdata(L, sizeof(AXUIElementRef));
    *winptr = win;
    // [ud]
    
    if (luaL_newmetatable(L, "window"))
    // [ud, md]
    {
        lua_pushcfunction(L, window_gc); // [ud, md, gc]
        lua_setfield(L, -2, "__gc");     // [ud, md]
    }
    // [ud, md]
    
    lua_setmetatable(L, -2);
    // [ud]
}

static AXUIElementRef system_wide_element() {
    static AXUIElementRef element;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        element = AXUIElementCreateSystemWide();
    });
    return element;
}

int window_get_focused_window(lua_State* L) {
    CFTypeRef app;
    AXUIElementCopyAttributeValue(system_wide_element(), kAXFocusedApplicationAttribute, &app);
    
    if (app) {
        CFTypeRef win;
        AXError result = AXUIElementCopyAttributeValue(app, (CFStringRef)NSAccessibilityFocusedWindowAttribute, &win);
        
        CFRelease(app);
        
        if (result == kAXErrorSuccess) {
            window_push_window_as_userdata(L, win);
            return 1;
        }
    }
    
    return 0;
}

static id get_window_prop(AXUIElementRef win, NSString* propType, id defaultValue) {
    CFTypeRef _someProperty;
    if (AXUIElementCopyAttributeValue(win, (__bridge CFStringRef)propType, &_someProperty) == kAXErrorSuccess)
        return CFBridgingRelease(_someProperty);
    
    return defaultValue;
}

static BOOL set_window_prop(AXUIElementRef win, NSString* propType, id value) {
    if ([value isKindOfClass:[NSNumber class]]) {
        AXError result = AXUIElementSetAttributeValue(win, (__bridge CFStringRef)(propType), (__bridge CFTypeRef)(value));
        if (result == kAXErrorSuccess)
            return YES;
    }
    return NO;
}


int window_title(lua_State* L) {
    AXUIElementRef win = *((AXUIElementRef*)lua_touserdata(L, 1));
    NSString* title = get_window_prop(win, NSAccessibilityTitleAttribute, @"");
    lua_pushstring(L, [title UTF8String]);
    return 1;
}

int window_subrole(lua_State* L) {
    AXUIElementRef win = *((AXUIElementRef*)lua_touserdata(L, 1));
    NSString* str = get_window_prop(win, NSAccessibilitySubroleAttribute, @"");
    
    lua_pushstring(L, [str UTF8String]);
    return 1;
}

int window_role(lua_State* L) {
    AXUIElementRef win = *((AXUIElementRef*)lua_touserdata(L, 1));
    NSString* str = get_window_prop(win, NSAccessibilityRoleAttribute, @"");
    
    lua_pushstring(L, [str UTF8String]);
    return 1;
}

// args: [subrole]
int window_is_standard(lua_State* L) {
    const char* subrole = lua_tostring(L, 1);
    
    BOOL is_standard = [[NSString stringWithUTF8String:subrole] isEqualToString: (__bridge NSString*)kAXStandardWindowSubrole];
    lua_pushboolean(L, is_standard);
    return 1;
}

int window_topleft(lua_State* L) {
    AXUIElementRef win = *((AXUIElementRef*)lua_touserdata(L, 1));
    
    CFTypeRef positionStorage;
    AXError result = AXUIElementCopyAttributeValue(win, (CFStringRef)NSAccessibilityPositionAttribute, &positionStorage);

    CGPoint topLeft;
    if (result == kAXErrorSuccess) {
        if (!AXValueGetValue(positionStorage, kAXValueCGPointType, (void *)&topLeft)) {
            NSLog(@"could not decode topLeft");
            topLeft = CGPointZero;
        }
    }
    else {
        NSLog(@"could not get window topLeft");
        topLeft = CGPointZero;
    }

    if (positionStorage)
        CFRelease(positionStorage);
    
    lua_pushnumber(L, topLeft.x);
    lua_pushnumber(L, topLeft.y);
    return 2;
}

int window_size(lua_State* L) {
    AXUIElementRef win = *((AXUIElementRef*)lua_touserdata(L, 1));
    
    CFTypeRef sizeStorage;
    AXError result = AXUIElementCopyAttributeValue(win, (CFStringRef)NSAccessibilitySizeAttribute, &sizeStorage);

    CGSize size;
    if (result == kAXErrorSuccess) {
        if (!AXValueGetValue(sizeStorage, kAXValueCGSizeType, (void *)&size)) {
            NSLog(@"could not decode topLeft");
            size = CGSizeZero;
        }
    }
    else {
        NSLog(@"could not get window size");
        size = CGSizeZero;
    }

    if (sizeStorage)
        CFRelease(sizeStorage);
    
    lua_pushnumber(L, size.width);
    lua_pushnumber(L, size.height);
    return 2;
}

int window_settopleft(lua_State* L) {
    AXUIElementRef win = *((AXUIElementRef*)lua_touserdata(L, 1));
    CGPoint thePoint = CGPointMake(lua_tonumber(L, 2),
                                   lua_tonumber(L, 3));
    
    CFTypeRef positionStorage = (CFTypeRef)(AXValueCreate(kAXValueCGPointType, (const void *)&thePoint));
    AXUIElementSetAttributeValue(win, (CFStringRef)NSAccessibilityPositionAttribute, positionStorage);
    if (positionStorage)
        CFRelease(positionStorage);
    
    return 0;
}

int window_setsize(lua_State* L) {
    AXUIElementRef win = *((AXUIElementRef*)lua_touserdata(L, 1));
    CGSize theSize = CGSizeMake(lua_tonumber(L, 2),
                                lua_tonumber(L, 3));
    
    CFTypeRef sizeStorage = (CFTypeRef)(AXValueCreate(kAXValueCGSizeType, (const void *)&theSize));
    AXUIElementSetAttributeValue(win, (CFStringRef)NSAccessibilitySizeAttribute, sizeStorage);
    if (sizeStorage)
        CFRelease(sizeStorage);
    
    return 0;
}

static void set_window_minimized(AXUIElementRef win, NSNumber* minimized) {
    set_window_prop(win, NSAccessibilityMinimizedAttribute, minimized);
}

int window_minimize(lua_State* L) {
    AXUIElementRef win = *((AXUIElementRef*)lua_touserdata(L, 1));
    set_window_minimized(win, @YES);
    return 0;
}

int window_unminimize(lua_State* L) {
    AXUIElementRef win = *((AXUIElementRef*)lua_touserdata(L, 1));
    set_window_minimized(win, @NO);
    return 0;
}

int window_isminimized(lua_State* L) {
    AXUIElementRef win = *((AXUIElementRef*)lua_touserdata(L, 1));
    BOOL minimized = [get_window_prop(win, NSAccessibilityMinimizedAttribute, @(NO)) boolValue];
    lua_pushboolean(L, minimized);
    return 1;
}

int window_pid(lua_State* L) {
    AXUIElementRef win = *((AXUIElementRef*)lua_touserdata(L, 1));
    
    pid_t pid = 0;
    if (AXUIElementGetPid(win, &pid) == kAXErrorSuccess) {
        lua_pushnumber(L, pid);
        return 1;
    }
    else {
        return 0;
    }
}

int window_equals(lua_State* L) {
    AXUIElementRef winA = *((AXUIElementRef*)lua_touserdata(L, 1));
    AXUIElementRef winB = *((AXUIElementRef*)lua_touserdata(L, 2));
    lua_pushboolean(L, CFEqual(winA, winB));
    return 1;
}

int window_makemain(lua_State* L) {
    AXUIElementRef win = *((AXUIElementRef*)lua_touserdata(L, 1));
    BOOL success = (AXUIElementSetAttributeValue(win, (CFStringRef)NSAccessibilityMainAttribute, kCFBooleanTrue) == kAXErrorSuccess);
    lua_pushboolean(L, success);
    return 1;
}

// XXX: undocumented API.  We need this to match dictionary entries returned by CGWindowListCopyWindowInfo (which
// appears to be the *only* way to get a list of all windows on the system in "most-recently-used first" order) against
// AXUIElementRef's returned by AXUIElementCopyAttributeValues
AXError _AXUIElementGetWindow(AXUIElementRef, CGWindowID* out);

int window_visible_windows_sorted_by_recency(lua_State* L) {
    lua_newtable(L);
    
    int i = 0;
    
    // This gets windows sorted by most-recently-used criteria.  The
    // first one will be the active window.
    CFArrayRef visible_win_info = CGWindowListCopyWindowInfo(
                                                             kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements,
                                                             kCGNullWindowID);

    // But we only got some dictionaries containing info.  Need to get
    // the actual AXUIMyHeadHurts for each of them and create SDWindow-s.
    for (NSMutableDictionary* entry in (__bridge NSArray*)visible_win_info) {
        // Tricky...  for Google Chrome we get one hidden window for
        // each visible window, so we need to check alpha > 0.
        int alpha = [[entry objectForKey:(id)kCGWindowAlpha] intValue];
        int layer = [[entry objectForKey:(id)kCGWindowLayer] intValue];

        if (layer == 0 && alpha > 0) {
            CGWindowID win_id = [[entry objectForKey:(id)kCGWindowNumber] intValue];

            // some AXUIElementCreateByWindowNumber would be soooo nice.  but nope, we have to take the pain below.

            int pid = [[entry objectForKey:(id)kCGWindowOwnerPID] intValue];
            AXUIElementRef app = AXUIElementCreateApplication(pid);
            CFArrayRef appwindows;
            AXUIElementCopyAttributeValues(app, kAXWindowsAttribute, 0, 1000, &appwindows);
            if (appwindows) {
                // looks like appwindows can be NULL when this function is called during the
                // switch-workspaces animation
                for (id w in (__bridge NSArray*)appwindows) {
                    AXUIElementRef win = (__bridge AXUIElementRef)w;
                    CGWindowID tmp;
                    _AXUIElementGetWindow(win, &tmp); //XXX: undocumented API.  but the alternative is horrifying.
                    if (tmp == win_id) {
                        // finally got it, insert in the result array.
                        
                        CFRetain(win);
                        
                        lua_pushnumber(L, i++);
                        window_push_window_as_userdata(L, win);
                        lua_settable(L, -3);
                        break;
                    }
                }
                CFRelease(appwindows);
            }
            CFRelease(app);
        }
    }
    CFRelease(visible_win_info);
    
    return 1;
}