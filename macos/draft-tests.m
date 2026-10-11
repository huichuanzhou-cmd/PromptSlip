#import <Foundation/Foundation.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#import "DraftStorage.h"

static void PDRequire(BOOL condition, NSString *message) {
    if (!condition) {
        fprintf(stderr, "FAIL: %s\n", message.UTF8String);
        exit(1);
    }
}

static NSData *PDDamagedBytes(void) {
    return [NSData dataWithBytes:(const uint8_t[]){0x66, 0x80, 0x6f} length:3];
}

static NSString *PDNewText(void) {
    return @"new text survives restart 🙂\n";
}

static void PDRunLegacyMigrationPhase(NSString *directory) {
    NSError *error = nil;
    NSString *newDirectory = [directory stringByAppendingPathComponent:@"PromptSlip"];
    NSString *oldDirectory = [directory stringByAppendingPathComponent:@"PasteDrop"];
    NSString *newPath = [newDirectory stringByAppendingPathComponent:@"draft.txt"];
    NSString *oldPath = [oldDirectory stringByAppendingPathComponent:@"draft.txt"];
    NSString *legacyText = @"legacy draft survives migration 🙂\n";
    PDRequire([NSFileManager.defaultManager createDirectoryAtPath:oldDirectory withIntermediateDirectories:YES attributes:nil error:&error], @"create legacy fixture directory");
    PDRequire([legacyText writeToFile:oldPath atomically:YES encoding:NSUTF8StringEncoding error:&error], @"write legacy draft fixture");

    NSString *loaded = nil;
    NSString *backup = nil;
    PDRequire(PDResolveDraft(newPath, @[oldPath], &loaded, &backup, &error), @"migrate valid legacy draft");
    PDRequire([loaded isEqualToString:legacyText], @"migration loads legacy text");
    PDRequire([[NSString stringWithContentsOfFile:newPath encoding:NSUTF8StringEncoding error:NULL] isEqualToString:legacyText], @"migration copies draft to new path");
    PDRequire([[NSString stringWithContentsOfFile:oldPath encoding:NSUTF8StringEncoding error:NULL] isEqualToString:legacyText], @"migration leaves legacy draft intact");

    NSString *newText = @"new PromptSlip draft wins\n";
    PDRequire(PDWriteDraft(newText, newPath, &error), @"write preferred new draft");
    loaded = nil;
    PDRequire(PDResolveDraft(newPath, @[oldPath], &loaded, &backup, &error), @"load preferred new draft");
    PDRequire([loaded isEqualToString:newText], @"existing new draft takes precedence over legacy");
    PDRequire([[NSString stringWithContentsOfFile:oldPath encoding:NSUTF8StringEncoding error:NULL] isEqualToString:legacyText], @"precedence check preserves legacy bytes");

    NSString *damagedDirectory = [directory stringByAppendingPathComponent:@"damaged-case"];
    NSString *damagedOldPath = [[damagedDirectory stringByAppendingPathComponent:@"PasteDrop"] stringByAppendingPathComponent:@"draft.txt"];
    NSString *damagedNewPath = [[damagedDirectory stringByAppendingPathComponent:@"PromptSlip"] stringByAppendingPathComponent:@"draft.txt"];
    NSData *damagedBytes = PDDamagedBytes();
    PDRequire([NSFileManager.defaultManager createDirectoryAtPath:damagedOldPath.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:&error], @"create damaged legacy fixture directory");
    PDRequire([damagedBytes writeToFile:damagedOldPath atomically:YES], @"write damaged legacy bytes");
    loaded = nil;
    backup = nil;
    error = nil;
    PDRequire(PDResolveDraft(damagedNewPath, @[damagedOldPath], &loaded, &backup, &error), @"migrate invalid UTF-8 legacy draft and recover");
    PDRequire(loaded.length == 0, @"damaged legacy draft opens a fresh editor");
    PDRequire(backup.length > 0 && ![NSFileManager.defaultManager fileExistsAtPath:damagedNewPath], @"invalid migrated copy is moved to a unique backup in new directory");
    PDRequire([[NSData dataWithContentsOfFile:backup] isEqualToData:damagedBytes], @"new corrupt backup retains the original legacy bytes");
    PDRequire([[NSData dataWithContentsOfFile:damagedOldPath] isEqualToData:damagedBytes], @"legacy corrupt source remains untouched");
    NSString *recoveredText = @"editing remains available after corrupt legacy migration\n";
    PDRequire(PDWriteDraft(recoveredText, damagedNewPath, &error), @"save a fresh draft after corrupt legacy migration");
    PDRequire([[NSString stringWithContentsOfFile:damagedNewPath encoding:NSUTF8StringEncoding error:NULL] isEqualToString:recoveredText], @"fresh draft is saved at the PromptSlip path");
    puts("PASS: legacy migration preserves source, prioritizes new draft, and recovers corrupt copies");
}

static void PDRunLoadAndSavePhase(NSString *directory) {
    NSError *error = nil;
    NSString *draftPath = [directory stringByAppendingPathComponent:@"draft.txt"];
    NSData *damagedBytes = PDDamagedBytes();
    PDRequire([damagedBytes writeToFile:draftPath atomically:YES], @"write damaged UTF-8 draft fixture");

    NSString *recovered = nil;
    NSString *backupPath = nil;
    PDRequire(PDLoadDraft(draftPath, &recovered, &backupPath, &error), @"load damaged draft and preserve it");
    PDRequire(recovered.length == 0, @"damaged draft starts a fresh editor");
    PDRequire(backupPath.length > 0 && ![NSFileManager.defaultManager fileExistsAtPath:draftPath], @"damaged draft moved aside");
    PDRequire([[NSData dataWithContentsOfFile:backupPath] isEqualToData:damagedBytes], @"backup retains original damaged bytes");
    PDRequire(PDWriteDraft(PDNewText(), draftPath, &error), @"close saves new text to fresh draft");
    puts("PASS: phase 1 saved new text and preserved the damaged draft");
}

static void PDRunRestartPhase(NSString *directory) {
    NSError *error = nil;
    NSString *draftPath = [directory stringByAppendingPathComponent:@"draft.txt"];
    NSArray<NSString *> *entries = [NSFileManager.defaultManager contentsOfDirectoryAtPath:directory error:&error];
    PDRequire(entries != nil, @"read shared test directory");
    NSMutableArray<NSString *> *backups = [NSMutableArray array];
    for (NSString *entry in entries) {
        if ([entry hasPrefix:@"draft.txt.corrupt-"]) [backups addObject:[directory stringByAppendingPathComponent:entry]];
    }
    PDRequire(backups.count == 1, @"restart finds exactly one preserved corrupt draft backup");
    PDRequire([[NSData dataWithContentsOfFile:backups.firstObject] isEqualToData:PDDamagedBytes()], @"restart confirms original damaged bytes remain intact");

    NSString *afterRestart = nil;
    NSString *secondBackup = nil;
    PDRequire(PDLoadDraft(draftPath, &afterRestart, &secondBackup, &error), @"new process loads saved draft");
    PDRequire([afterRestart isEqualToString:PDNewText()], @"new process restores the edited text");
    PDRequire(secondBackup == nil, @"valid draft does not create another backup");
    puts("PASS: phase 2 restored new text in a separate process and retained original bytes");
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 3) {
            fprintf(stderr, "Usage: draft-tests (load-save|restart|legacy) DIRECTORY\n");
            return 2;
        }
        NSString *phase = [NSString stringWithUTF8String:argv[1]];
        NSString *directory = [NSString stringWithUTF8String:argv[2]];
        if (!phase || !directory) return 2;
        if ([phase isEqualToString:@"load-save"]) PDRunLoadAndSavePhase(directory);
        else if ([phase isEqualToString:@"restart"]) PDRunRestartPhase(directory);
        else if ([phase isEqualToString:@"legacy"]) PDRunLegacyMigrationPhase(directory);
        else return 2;
    }
    return 0;
}
