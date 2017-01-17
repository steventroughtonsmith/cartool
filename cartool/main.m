//
//  main.m
//  cartool
//
//  Created by Steven Troughton-Smith on 14/07/2013.
//  Copyright (c) 2013 High Caffeine Content. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum _kCoreThemeIdiom {
	kCoreThemeIdiomUniversal,
	kCoreThemeIdiomPhone,
	kCoreThemeIdiomPad,
	kCoreThemeIdiomTV,
	kCoreThemeIdiomCar,
	kCoreThemeIdiomWatch,
	kCoreThemeIdiomMarketing
} kCoreThemeIdiom;

typedef NS_ENUM(NSInteger, UIUserInterfaceSizeClass) {
	UIUserInterfaceSizeClassUnspecified = 0,
	UIUserInterfaceSizeClassCompact     = 1,
	UIUserInterfaceSizeClassRegular     = 2,
};

CGDataProviderRef CGPDFDocumentGetDataProvider(CGPDFDocumentRef);

typedef struct _renditionkeytoken {
    unsigned short k;
    unsigned short v;
} CUIRenditionKeyToken;

@interface CUICommonAssetStorage : NSObject

-(NSArray *)allAssetKeys;
-(NSArray *)allRenditionNames;
-(id)initWithPath:(NSString *)p;
-(NSString *)versionString;
- (NSString*)renditionNameForKeyList:(CUIRenditionKeyToken*) keyList;

@end

typedef unsigned long long CUITheme;
typedef long long CUIRenditionType;

@interface CUIRenditionKey : NSObject
- (CUIRenditionKeyToken*) keyList;
- (NSString*) nameOfAttributeName: (int) attributeName;
- (NSUInteger) themeScale;
- (kCoreThemeIdiom) themeIdiom;
- (UIUserInterfaceSizeClass) themeSizeClassHorizontal;
- (UIUserInterfaceSizeClass) themeSizeClassVertical;
@end

@interface CUIImage : NSObject
- (CGImageRef) image;
@end

@interface CUIThemeRendition : NSObject
+ (NSString*) displayNameForRenditionType:(CUIRenditionType)type;

- (CUIRenditionType) type;
- (NSString*) name;
- (CGPDFDocumentRef) pdfDocument;
- (CGImageRef) unslicedImage;
- (CGImageRef) uncroppedImage;
- (id) packedContents;
- (NSData*) data;
- (id) utiType;
@end

@interface CUIThemeFacet : NSObject

+(CUITheme) themeWithContentsOfURL:(NSURL *)u error:(NSError **)e;
+(CUITheme) themeWithBytes:(const void *) bytes length:(size_t) len error:(NSError**) e;
+(CUIThemeFacet *)facetWithRenditionKey:(CUIRenditionKey*) key fromTheme:(CUITheme)theme;

- (instancetype) initWithRenditionKey:(CUIRenditionKey*) key fromTheme:(CUITheme)theme;
- (CGSize) imageSize;
- (CUIImage*) image;
- (NSString*) displayName;
- (CUIRenditionType) renditionType;
- (CUIThemeRendition*) themeRendition;

@end


void CGImageWriteToFile(CGImageRef image, NSString *path)
{
	CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:path];
	CGImageDestinationRef destination = CGImageDestinationCreateWithURL(url, kUTTypePNG, 1, NULL);
	CGImageDestinationAddImage(destination, image, nil);
	
	if (!CGImageDestinationFinalize(destination)) {
		NSLog(@"Failed to write image to %@", path);
	}
	
	CFRelease(destination);
}

void createSubdirectories(NSString* path, NSString* outputDirectoryPath) {
    NSArray* pathComponents = [path pathComponents];
    if (pathComponents.count > 1)
    {
        // Create subdirectories for namespaced assets (those with names like "some/namespace/image-name")
        NSArray* subdirectoryComponents = [pathComponents subarrayWithRange:NSMakeRange(0, pathComponents.count - 1)];
        
        NSString* subdirectoryPath = [outputDirectoryPath copy];
        for (NSString* pathComponent in subdirectoryComponents)
        {
            subdirectoryPath = [subdirectoryPath stringByAppendingPathComponent:pathComponent];
        }
        
        [[NSFileManager defaultManager] createDirectoryAtPath:subdirectoryPath
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];
    }
}

NSString *idiomSuffixForCoreThemeIdiom(kCoreThemeIdiom idiom)
{
    switch (idiom) {
        case kCoreThemeIdiomUniversal:
            return @"";
            break;
        case kCoreThemeIdiomPhone:
            return @"~iphone";
            break;
        case kCoreThemeIdiomPad:
            return @"~ipad";
            break;
        case kCoreThemeIdiomTV:
            return @"~tv";
            break;
        case kCoreThemeIdiomCar:
            return @"~carplay";
            break;
        case kCoreThemeIdiomWatch:
            return @"~watch";
            break;
        case kCoreThemeIdiomMarketing:
            return @"~marketing";
            break;
        default:
            break;
    }
    
    return @"";
}

NSString *sizeClassSuffixForSizeClass(UIUserInterfaceSizeClass sizeClass)
{
    switch (sizeClass)
    {
        case UIUserInterfaceSizeClassCompact:
            return @"C";
            break;
        case UIUserInterfaceSizeClassRegular:
            return @"R";
            break;
        default:
            return @"A";
    }
}

NSString* fileExtension(CUIThemeRendition* rendition) {
    // try to use the UTI
    if (rendition.utiType) {
        NSArray* extensions = CFBridgingRelease(UTTypeCopyAllTagsWithClass((__bridge CFStringRef _Nonnull)(rendition.utiType), kUTTagClassFilenameExtension));
        if (extensions.count > 0) {
            return extensions.firstObject;
        }
    }
    
    if (rendition.type == 9) {
        return @"pdf";
    }
    
    if (rendition.type == 1000) {
        // use the existing extension
        NSString* extension = rendition.name.pathExtension;
        if (extension.length > 0) {
            return extension;
        }
        
        // unknown UTI, just use it directly
        return rendition.utiType;
    }
    
    // everything else should probably be a PNG
    return @"png";
}

NSString* typedFilename(NSString* renditionName, CUIRenditionKey* key, CUIThemeRendition* rendition) {
    NSString *idiomSuffix = idiomSuffixForCoreThemeIdiom(key.themeIdiom);
    NSString *sizeClassSuffix = @"";
    
    if (key.themeSizeClassHorizontal || key.themeSizeClassVertical)
    {
        sizeClassSuffix = [NSString stringWithFormat:@"-%@x%@", sizeClassSuffixForSizeClass(key.themeSizeClassHorizontal), sizeClassSuffixForSizeClass(key.themeSizeClassVertical)];
    }
    
    NSString *scale = key.themeScale > 1 ? [NSString stringWithFormat:@"@%lux", key.themeScale] : @"";
    
    NSString* extension = fileExtension(rendition);
    
    NSString *name = [NSString stringWithFormat:@"%@%@%@%@.%@", renditionName, idiomSuffix, sizeClassSuffix, scale, extension];
    return name;
}

void exportCarFileAtPath(NSString * carPath, NSString *outputDirectoryPath)
{
	NSError *error = nil;
	
	outputDirectoryPath = [outputDirectoryPath stringByExpandingTildeInPath];
    
    CUITheme theme = [CUIThemeFacet themeWithContentsOfURL:[NSURL fileURLWithPath:carPath] error:&error];
    
    if (error != nil) {
        NSLog(@"Error: %@", error);
        exit(1);
    }
	
	/* CUICommonAssetStorage won't link */
	CUICommonAssetStorage *storage = [[NSClassFromString(@"CUICommonAssetStorage") alloc] initWithPath:carPath];
    
    for (CUIRenditionKey *key in [storage allAssetKeys]) {
        CUIThemeFacet* aFacet = [[CUIThemeFacet alloc] initWithRenditionKey:key fromTheme:theme];
        
        CUIThemeRendition* rendition = [aFacet themeRendition];
        if (rendition.type > 1001) {
            // this is a packed asset, skip it
            continue;
        }
        NSString* renditionName = [storage renditionNameForKeyList:[key keyList]];
        NSString* filename = typedFilename(renditionName, key, rendition);
        printf("%s\n", filename.UTF8String);
        
        if( outputDirectoryPath ) {
            createSubdirectories( filename, outputDirectoryPath );
            NSURL* path = [NSURL fileURLWithPath:[outputDirectoryPath stringByAppendingPathComponent:filename]];
            if (rendition.pdfDocument) {
                CGPDFDocumentRef doc = rendition.pdfDocument;
                CGDataProviderRef provider = CGPDFDocumentGetDataProvider(doc);
                NSData *data = provider ? CFBridgingRelease(CGDataProviderCopyData(provider)) : nil;
                [data writeToURL:path atomically:YES];
            } else if (rendition.data) {
                [rendition.data writeToURL:path atomically:YES];
            } else if (rendition.uncroppedImage) {
                CGImageRef image = rendition.uncroppedImage;
                CGImageWriteToFile(image, [outputDirectoryPath stringByAppendingPathComponent:filename]);
            } else {
                printf("  Unknown file type!\n");
            }
        }
        
    }
    
}

int main(int argc, const char * argv[])
{
	@autoreleasepool {
		
		if (argc < 2)
		{
			printf("Usage: cartool <path to Assets.car> [outputDirectory]\n");
			return -1;
		}
		
		exportCarFileAtPath([NSString stringWithUTF8String:argv[1]], argc > 2 ? [NSString stringWithUTF8String:argv[2]] : nil);
	}
	return 0;
}
