#import <Foundation/Foundation.h>
#import <errno.h>
#import <fcntl.h>
#import <unistd.h>

static BOOL PDLoadDraft(NSString *path, NSString **textOut, NSString **backupPathOut, NSError **errorOut) {
    if (textOut) *textOut = @"";
    if (backupPathOut) *backupPathOut = nil;
    if (![NSFileManager.defaultManager fileExistsAtPath:path]) return YES;

    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfFile:path options:0 error:&error];
    if (!data) {
        if (errorOut) *errorOut = error;
        return NO;
    }
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (text) {
        if (textOut) *textOut = text;
        return YES;
    }

    NSFileManager *manager = NSFileManager.defaultManager;
    for (NSUInteger attempt = 0; attempt < 64; attempt++) {
        NSString *backup = [path stringByAppendingFormat:@".corrupt-%@", NSUUID.UUID.UUIDString.lowercaseString];
        if ([manager fileExistsAtPath:backup]) continue;
        error = nil;
        if ([manager moveItemAtPath:path toPath:backup error:&error]) {
            if (backupPathOut) *backupPathOut = backup;
            return YES;
        }
        if ([manager fileExistsAtPath:backup]) continue;
        if (errorOut) *errorOut = [NSError errorWithDomain:error.domain code:error.code userInfo:@{
            NSLocalizedDescriptionKey: [NSString stringWithFormat:@"The invalid UTF-8 draft could not be moved to a unique backup and was left untouched: %@", error.localizedDescription ?: @"unknown file error"]
        }];
        return NO;
    }
    if (errorOut) *errorOut = [NSError errorWithDomain:@"PromptSlip" code:5 userInfo:@{
        NSLocalizedDescriptionKey: @"Could not find a unique backup name for the invalid UTF-8 draft; the original draft was left untouched."
    }];
    return NO;
}

static BOOL PDWriteDraft(NSString *text, NSString *path, NSError **errorOut) {
    NSString *directory = path.stringByDeletingLastPathComponent;
    NSError *error = nil;
    if (![NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error]) {
        if (errorOut) *errorOut = error;
        return NO;
    }
    BOOL saved = [(text ?: @"") writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (!saved && errorOut) *errorOut = error;
    return saved;
}

static BOOL PDResolveDraft(NSString *path, NSArray<NSString *> *legacyPaths, NSString **textOut,
                           NSString **backupPathOut, NSError **errorOut) {
    if ([NSFileManager.defaultManager fileExistsAtPath:path])
        return PDLoadDraft(path, textOut, backupPathOut, errorOut);

    for (NSString *legacyPath in legacyPaths) {
        if (![NSFileManager.defaultManager fileExistsAtPath:legacyPath]) continue;
        NSError *error = nil;
        NSData *data = [NSData dataWithContentsOfFile:legacyPath options:0 error:&error];
        if (!data) {
            if (errorOut) *errorOut = [NSError errorWithDomain:error.domain ?: @"PromptSlip" code:error.code userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:@"The legacy draft at %@ could not be read and was left untouched: %@", legacyPath, error.localizedDescription ?: @"unknown file error"]
            }];
            return NO;
        }
        NSString *directory = path.stringByDeletingLastPathComponent;
        if (![NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error]) {
            if (errorOut) *errorOut = [NSError errorWithDomain:error.domain code:error.code userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:@"The legacy draft at %@ was read but could not be copied to %@; the original was left untouched: %@", legacyPath, path, error.localizedDescription ?: @"unknown file error"]
            }];
            return NO;
        }

        NSString *temporary = [directory stringByAppendingPathComponent:[NSString stringWithFormat:@".draft-migrate-%@", NSUUID.UUID.UUIDString.lowercaseString]];
        int fd = open(temporary.fileSystemRepresentation, O_WRONLY | O_CREAT | O_EXCL, 0600);
        if (fd < 0) {
            int savedErrno = errno;
            if (errorOut) *errorOut = [NSError errorWithDomain:NSPOSIXErrorDomain code:savedErrno userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:@"The legacy draft at %@ could not be staged for migration; the original was left untouched: %@", legacyPath, [NSError errorWithDomain:NSPOSIXErrorDomain code:savedErrno userInfo:nil].localizedDescription]
            }];
            return NO;
        }
        const uint8_t *bytes = data.bytes;
        NSUInteger remaining = data.length;
        BOOL written = YES;
        while (remaining) {
            ssize_t count = write(fd, bytes, remaining);
            if (count < 0 && errno == EINTR) continue;
            if (count <= 0) { if (count == 0) errno = EIO; written = NO; break; }
            bytes += count;
            remaining -= (NSUInteger)count;
        }
        int writeErrno = errno;
        if (close(fd) != 0 && written) { written = NO; writeErrno = errno; }
        if (!written) {
            (void)unlink(temporary.fileSystemRepresentation);
            if (errorOut) *errorOut = [NSError errorWithDomain:NSPOSIXErrorDomain code:writeErrno userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:@"The legacy draft at %@ could not be copied; the original was left untouched: %@", legacyPath, [NSError errorWithDomain:NSPOSIXErrorDomain code:writeErrno userInfo:nil].localizedDescription]
            }];
            return NO;
        }
        if (link(temporary.fileSystemRepresentation, path.fileSystemRepresentation) != 0) {
            int savedErrno = errno;
            (void)unlink(temporary.fileSystemRepresentation);
            if (savedErrno == EEXIST) return PDLoadDraft(path, textOut, backupPathOut, errorOut);
            if (errorOut) *errorOut = [NSError errorWithDomain:NSPOSIXErrorDomain code:savedErrno userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:@"The legacy draft at %@ could not be copied to %@; the original was left untouched: %@", legacyPath, path, [NSError errorWithDomain:NSPOSIXErrorDomain code:savedErrno userInfo:nil].localizedDescription]
            }];
            return NO;
        }
        (void)unlink(temporary.fileSystemRepresentation);
        /* Let the normal loader preserve invalid UTF-8 in the new directory.
           The historical source remains untouched, and the editor can save again. */
        return PDLoadDraft(path, textOut, backupPathOut, errorOut);
    }
    if (textOut) *textOut = @"";
    if (backupPathOut) *backupPathOut = nil;
    return YES;
}
