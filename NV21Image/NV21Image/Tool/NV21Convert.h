//
//  NV21Convert.h
//  smartdevice
//
//  Created by GreeX on 2021/4/21.
//  Copyright © 2021 Gree. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NV21Convert : NSObject

// UIImage -> nv21Buffer -> nv21 data
+ (NSData *)convertDataWithImage:(UIImage *)img;
// UIImage -> CVPixelBufferRef(RGBA) -> CVPixelBufferRef(NV21)
+ (CVPixelBufferRef)convertN21WithImage:(UIImage *)img;
// UIImage -> CVPixelBufferRef(RGBA)
+ (CVPixelBufferRef)imageToRGBPixelBuffer:(UIImage *)image;

// nv21 data -> buffer -> UIImage
+ (UIImage *)convertImageWithData:(NSData *)nv21Data imageSize:(CGSize)size;

@end

NS_ASSUME_NONNULL_END
