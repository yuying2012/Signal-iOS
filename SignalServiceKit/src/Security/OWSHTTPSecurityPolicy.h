//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import <AFNetworking/AFSecurityPolicy.h>

@interface OWSHTTPSecurityPolicy : AFSecurityPolicy

+ (instancetype)sharedPolicy;

@end

@interface MockSecurityPolicy : AFSecurityPolicy

+ (instancetype)sharedPolicy;

@end
