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

@interface CUICommonAssetStorage : NSObject

-(NSArray *)allAssetKeys;
-(NSArray *)allRenditionNames;

-(id)initWithPath:(NSString *)p;

-(NSString *)versionString;

@end

@interface CUINamedImage : NSObject

@property(readonly) CGSize size;
@property(readonly) CGFloat scale;
@property(readonly) kCoreThemeIdiom idiom;
@property(readonly) UIUserInterfaceSizeClass sizeClassHorizontal;
@property(readonly) UIUserInterfaceSizeClass sizeClassVertical;

-(CGImageRef)image;

@end

@interface CUIRenditionKey : NSObject
@end

@interface CUIThemeFacet : NSObject

+(CUIThemeFacet *)themeWithContentsOfURL:(NSURL *)u error:(NSError **)e;

@end

@interface CUICatalog : NSObject

@property(readonly) bool isVectorBased;

-(id)initWithName:(NSString *)n fromBundle:(NSBundle *)b;
-(id)allKeys;
-(id)allImageNames;
-(CUINamedImage *)imageWithName:(NSString *)n scaleFactor:(CGFloat)s;
-(CUINamedImage *)imageWithName:(NSString *)n scaleFactor:(CGFloat)s deviceIdiom:(int)idiom;
-(NSArray *)imagesWithName:(NSString *)n;

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

NSMutableArray *getImagesArray(CUICatalog *catalog, NSString *key)
{
    NSMutableArray *images = [[NSMutableArray alloc] initWithCapacity:5];

    for (NSNumber *scaleFactor in @[@1, @2, @3])
    {
        CUINamedImage *image = [catalog imageWithName:key scaleFactor:scaleFactor.doubleValue];

        if (image && image.scale == scaleFactor.floatValue) [images addObject:image];
    }

    return images;
}

void exportCarFileAtPath(NSString * carPath, NSString *outputDirectoryPath)
{
	NSError *error = nil;
	
	outputDirectoryPath = [outputDirectoryPath stringByExpandingTildeInPath];
	
	CUIThemeFacet *facet = [CUIThemeFacet themeWithContentsOfURL:[NSURL fileURLWithPath:carPath] error:&error];
	
	CUICatalog *catalog = [[CUICatalog alloc] init];
	
	/* Override CUICatalog to point to a file rather than a bundle */
	[catalog setValue:facet forKey:@"_storageRef"];
	
	/* CUICommonAssetStorage won't link */
	CUICommonAssetStorage *storage = [[NSClassFromString(@"CUICommonAssetStorage") alloc] initWithPath:carPath];
	
	for (NSString *key in [storage allRenditionNames])
	{
		printf("%s\n", [key UTF8String]);
        
        NSArray* pathComponents = [key pathComponents];
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
                                                            error:&error];
        }
        
		NSMutableArray *images = getImagesArray(catalog, key);
		for( CUINamedImage *image in images )
		{
			if( CGSizeEqualToSize(image.size, CGSizeZero) )
				printf("\tnil image?\n");
			else
			{
				CGImageRef cgImage = [image image];
				NSString *idiomSuffix = idiomSuffixForCoreThemeIdiom(image.idiom);
				
				NSString *sizeClassSuffix = @"";
				
				if (image.sizeClassHorizontal || image.sizeClassVertical)
				{
					sizeClassSuffix = [NSString stringWithFormat:@"-%@x%@", sizeClassSuffixForSizeClass(image.sizeClassHorizontal), sizeClassSuffixForSizeClass(image.sizeClassVertical)];
				}
				
				NSString *scale = image.scale > 1.0 ? [NSString stringWithFormat:@"@%dx", (int)floor(image.scale)] : @"";
				NSString *name = [NSString stringWithFormat:@"%@%@%@%@.png", key, idiomSuffix, sizeClassSuffix, scale];
				printf("\t%s\n", [name UTF8String]);
				if( outputDirectoryPath )
					CGImageWriteToFile(cgImage, [outputDirectoryPath stringByAppendingPathComponent:name]);
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
