//
//  MagicalRecord+Actions.m
//
//  Created by Saul Mora on 2/24/11.
//  Copyright 2011 Magical Panda Software. All rights reserved.
//

#import "MagicalRecord+Actions.h"
#import "NSManagedObjectContext+MagicalRecord.h"
#import "NSManagedObjectContext+MagicalThreading.h"

static NSOperationQueue *k_syncSaveQueue;

@implementation MagicalRecord (Actions)

#pragma mark - Asynchronous saving

+ (void) saveWithBlock:(void(^)(NSManagedObjectContext *localContext))block;
{
    [self saveWithBlock:block completion:nil];
}

+ (void) saveWithBlock:(void(^)(NSManagedObjectContext *localContext))block completion:(MRSaveCompletionHandler)completion;
{
    NSManagedObjectContext *savingContext  = [NSManagedObjectContext MR_rootSavingContext];
    NSManagedObjectContext *localContext = [NSManagedObjectContext MR_contextWithParent:savingContext];

    [localContext performBlock:^{
        [localContext MR_setWorkingName:NSStringFromSelector(_cmd)];

        if (block) {
            block(localContext);
        }

        [localContext MR_saveWithOptions:MRSaveParentContexts completion:completion];
    }];
}

+ (NSOperationQueue *) syncSaveQueue
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        k_syncSaveQueue = [NSOperationQueue new];
        k_syncSaveQueue.maxConcurrentOperationCount = 1;
        k_syncSaveQueue.qualityOfService = NSOperationQualityOfServiceUtility;
    });
    
    return k_syncSaveQueue;
}

+ (void) saveSyncWithBlock:(void(^)(NSManagedObjectContext *localContext))block completion:(MRSaveCompletionHandler)completion
{
    [[self syncSaveQueue] addOperationWithBlock:^{
        [self saveWithBlockAndWait:block];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(YES,nil);
            });
        }
    }];
}

+ (void) cancelAllSyncSaveTasks
{
    if (k_syncSaveQueue) {
        [k_syncSaveQueue cancelAllOperations];
    }
}

#pragma mark - Synchronous saving

+ (void) saveWithBlockAndWait:(void(^)(NSManagedObjectContext *localContext))block;
{
    NSManagedObjectContext *savingContext  = [NSManagedObjectContext MR_rootSavingContext];
    NSManagedObjectContext *localContext = [NSManagedObjectContext MR_contextWithParent:savingContext];

    [localContext performBlockAndWait:^{
        [localContext MR_setWorkingName:NSStringFromSelector(_cmd)];

        if (block) {
            block(localContext);
        }

        [localContext MR_saveWithOptions:MRSaveParentContexts|MRSaveSynchronously completion:nil];
    }];
}

@end

#pragma mark - Deprecated Methods — DO NOT USE
@implementation MagicalRecord (ActionsDeprecated)

+ (void) saveUsingCurrentThreadContextWithBlock:(void (^)(NSManagedObjectContext *localContext))block completion:(MRSaveCompletionHandler)completion;
{
    NSManagedObjectContext *localContext = [NSManagedObjectContext MR_contextForCurrentThread];

    [localContext performBlock:^{
        [localContext MR_setWorkingName:NSStringFromSelector(_cmd)];

        if (block) {
            block(localContext);
        }

        [localContext MR_saveWithOptions:MRSaveParentContexts completion:completion];
    }];
}

+ (void) saveUsingCurrentThreadContextWithBlockAndWait:(void (^)(NSManagedObjectContext *localContext))block;
{
    NSManagedObjectContext *localContext = [NSManagedObjectContext MR_contextForCurrentThread];

    [localContext performBlockAndWait:^{
        [localContext MR_setWorkingName:NSStringFromSelector(_cmd)];

        if (block) {
            block(localContext);
        }

        [localContext MR_saveWithOptions:MRSaveParentContexts|MRSaveSynchronously completion:nil];
    }];
}

+ (void) saveInBackgroundWithBlock:(void(^)(NSManagedObjectContext *localContext))block
{
    [[self class] saveWithBlock:block completion:nil];
}

+ (void) saveInBackgroundWithBlock:(void(^)(NSManagedObjectContext *localContext))block completion:(void(^)(void))completion
{
    NSManagedObjectContext *savingContext  = [NSManagedObjectContext MR_rootSavingContext];
    NSManagedObjectContext *localContext = [NSManagedObjectContext MR_contextWithParent:savingContext];

    [localContext performBlock:^{
        [localContext MR_setWorkingName:NSStringFromSelector(_cmd)];

        if (block)
        {
            block(localContext);
        }

        [localContext MR_saveToPersistentStoreAndWait];

        if (completion)
        {
            completion();
        }
    }];
}

+ (void) saveInBackgroundUsingCurrentContextWithBlock:(void (^)(NSManagedObjectContext *localContext))block completion:(void (^)(void))completion errorHandler:(void (^)(NSError *error))errorHandler;
{
    NSManagedObjectContext *localContext = [NSManagedObjectContext MR_contextForCurrentThread];

    [localContext performBlock:^{
        [localContext MR_setWorkingName:NSStringFromSelector(_cmd)];

        if (block) {
            block(localContext);
        }

        [localContext MR_saveToPersistentStoreWithCompletion:^(BOOL contextDidSave, NSError *error) {
            if (contextDidSave) {
                if (completion) {
                    completion();
                }
            }
            else {
                if (errorHandler) {
                    errorHandler(error);
                }
            }
        }];
    }];
}

@end
