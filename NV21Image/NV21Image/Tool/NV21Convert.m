//
//  NV21Convert.m
//  smartdevice
//
//  Created by GreeX on 2021/4/21.
//  Copyright © 2021 Gree. All rights reserved.
//

#import "NV21Convert.h"
#import <AVFoundation/AVFoundation.h>
#import "libyuv.h"
#import "aw_all.h"
#import <CoreGraphics/CoreGraphics.h>

@implementation NV21Convert

//MARK: - UIImage -> nv21Buffer -> nv21 data
+ (NSData *)convertDataWithImage:(UIImage *)img
{
    CVPixelBufferRef nv21Buffer = [self convertN21WithImage: img];
    NSData *nv21Data = [self convertVideoSmapleBufferToYuvData: nv21Buffer];
    return  nv21Data;
}

//MARK: - UIImage -> CVPixelBufferRef(RGBA) -> CVPixelBufferRef(NV21)
+ (CVPixelBufferRef)convertN21WithImage:(UIImage *)img
{
    CVPixelBufferRef argbBuffer = [self imageToRGBPixelBuffer: img];
    
    CVPixelBufferLockBaseAddress(argbBuffer, 0);
    //图像宽度（像素）
    size_t pixelWidth = CVPixelBufferGetWidth(argbBuffer);
    //图像高度（像素）
    size_t pixelHeight = CVPixelBufferGetHeight(argbBuffer);
    // CVPixelBufferRef中 Rgb
    uint8_t *rgb_data = (uint8 *)CVPixelBufferGetBaseAddress(argbBuffer);//rgb_data
    
    // 创建一个空的32BGRA格式的CVPixelBufferRef
    NSDictionary *pixelAttributes = @{(id)kCVPixelBufferIOSurfacePropertiesKey : @{}};
    CVPixelBufferRef nv21Buffer1 = NULL;
    CVReturn result = CVPixelBufferCreate(kCFAllocatorDefault,
                                          pixelWidth,
                                          pixelHeight,
                                          kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                                          (__bridge CFDictionaryRef)pixelAttributes,
                                          &nv21Buffer1);
    if (result != kCVReturnSuccess) {
        NSLog(@"Unable to create cvpixelbuffer %d", result);
        return NULL;
    }
    CVPixelBufferUnlockBaseAddress(argbBuffer, 0);
    
    result = CVPixelBufferLockBaseAddress(nv21Buffer1, 0);
    if (result != kCVReturnSuccess) {
        CFRelease(nv21Buffer1);
        NSLog(@"Failed to lock base address: %d", result);
        return NULL;
    }
    
    // 得到新创建的CVPixelBufferRef中 nv21数据的首地址
//    uint8_t *nv21_data = (unsigned char *)CVPixelBufferGetBaseAddress(nv21Buffer1);//rgb_data
    //获取CVImageBufferRef中的y数据
    uint8_t *y_frame = (unsigned char *)CVPixelBufferGetBaseAddressOfPlane(nv21Buffer1, 0);
    //获取CMVImageBufferRef中的uv数据
    uint8_t *uv_frame =(unsigned char *) CVPixelBufferGetBaseAddressOfPlane(nv21Buffer1, 1);
    
    
    // 使用libyuv为rgb_data写入数据，将BGRA转换为NV21
    int ret = ARGBToNV21(rgb_data, pixelWidth * 4, y_frame, pixelWidth, uv_frame, pixelWidth, pixelWidth, pixelHeight);
//    int ret2 = NV21ToARGB(<#const uint8 *src_y#>, <#int src_stride_y#>, <#const uint8 *src_vu#>, <#int src_stride_vu#>, <#uint8 *dst_argb#>, <#int dst_stride_argb#>, <#int width#>, <#int height#>)
//    int ret3 = NV21ToARGB(y_frame, pixelWidth, uv_frame, pixelWidth, rgb_data, pixelWidth * 4, pixelWidth, pixelHeight);
    if (ret) {
        CFRelease(nv21Buffer1);
        return NULL;
    }
    CVPixelBufferUnlockBaseAddress(nv21Buffer1, 0);
    
    return nv21Buffer1;
}

//MARK: - UIImage -> CVPixelBufferRef(RGBA)
+ (CVPixelBufferRef)imageToRGBPixelBuffer:(UIImage *)image
{
    CGSize frameSize = CGSizeMake(CGImageGetWidth(image.CGImage),CGImageGetHeight(image.CGImage));
    NSDictionary *options =
    [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES],kCVPixelBufferCGImageCompatibilityKey,[NSNumber numberWithBool:YES],kCVPixelBufferCGBitmapContextCompatibilityKey,nil];
    CVPixelBufferRef pxbuffer = NULL;
    CVReturn status =
    CVPixelBufferCreate(kCFAllocatorDefault,
                        frameSize.width,
                        frameSize.height,
                        kCVPixelFormatType_32ARGB,
                        (__bridge CFDictionaryRef)options,
                        &pxbuffer);
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, frameSize.width, frameSize.height,8, CVPixelBufferGetBytesPerRow(pxbuffer),rgbColorSpace,(CGBitmapInfo)kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image.CGImage),CGImageGetHeight(image.CGImage)), image.CGImage);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    return pxbuffer;
}

//MARK: - CVPixelBufferRef -> NSData
+ (NSData *)convertVideoSmapleBufferToYuvData:(CVPixelBufferRef)pixelBuffer
{
    //表示开始操作数据
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);

    //图像宽度（像素）
    size_t pixelWidth = CVPixelBufferGetWidth(pixelBuffer);
    //图像高度（像素）
    size_t pixelHeight = CVPixelBufferGetHeight(pixelBuffer);
    //yuv中的y所占字节数
    size_t y_size = pixelWidth * pixelHeight;
    //yuv中的uv所占的字节数
    size_t uv_size = y_size / 2;

    uint8_t *yuv_frame = aw_alloc(uv_size + y_size);

    //获取CVImageBufferRef中的y数据
    uint8_t *y_frame = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    memcpy(yuv_frame, y_frame, y_size);

    //获取CMVImageBufferRef中的uv数据
    uint8_t *uv_frame = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
    memcpy(yuv_frame + y_size, uv_frame, uv_size);

    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

    //返回数据
    return [NSData dataWithBytesNoCopy:yuv_frame length:y_size + uv_size];
}

/* *************************************************************************************************** */
//MARK: - nv21 data -> buffer -> UIImage
+ (UIImage *)convertImageWithData:(NSData *)nv21Data imageSize:(CGSize)size
{
    @synchronized(self) {
        //data -> nv21 buffer
        unsigned char *byteBuffer = (unsigned char *)nv21Data.bytes;
        CVPixelBufferRef nv21Buffer = [self createCVPixelBufferRefFromNV12buffer:byteBuffer width:size.width height:size.height];
        //nv21 buffer -> ARGB buffer
        CVPixelBufferRef argbBuffer = [self convertVideoSmapleBufferToBGRAData:nv21Buffer];
        //ARGB buffer -> UIimage
        UIImage *image = [self imageFromRGBImageBuffer:argbBuffer];
        return image;
    }
}

//MARK: - NSData(NV21) -> CVPixelBufferRef(NV21)
+ (CVPixelBufferRef)createCVPixelBufferRefFromNV12buffer:(unsigned char *)buffer width:(int)w height:(int)h
{
    NSDictionary *pixelAttributes = @{(NSString*)kCVPixelBufferIOSurfacePropertiesKey:@{}};
    
    CVPixelBufferRef pixelBuffer = NULL;
    
    CVReturn result = CVPixelBufferCreate(kCFAllocatorDefault,
                                          w,
                                          h,
                                          kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,//kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                                          (__bridge CFDictionaryRef)(pixelAttributes),
                                          &pixelBuffer);//kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
    
    CVPixelBufferLockBaseAddress(pixelBuffer,0);
    unsigned char *yDestPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    
    // Here y_ch0 is Y-Plane of YUV(NV12) data.
    unsigned char *y_ch0 = buffer;
    memcpy(yDestPlane, y_ch0, w * h);
    unsigned char *uvDestPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
    
    // Here y_ch1 is UV-Plane of YUV(NV12) data.
    unsigned char *y_ch1 = buffer + w * h;
    memcpy(uvDestPlane, y_ch1, w * h/2);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    if (result != kCVReturnSuccess) {
        NSLog(@"Unable to create cvpixelbuffer %d", result);
    }
    return pixelBuffer;
}

//MARK: - NV21 To ARGB
+ (CVPixelBufferRef)convertVideoSmapleBufferToBGRAData:(CVPixelBufferRef)pixelBuffer
{
  //VideoToolbox解码后的图像数据并不能直接给CPU访问，需先用CVPixelBufferLockBaseAddress()锁定地址才能从主存访问，否则调用CVPixelBufferGetBaseAddressOfPlane等函数则返回NULL或无效值。值得注意的是，CVPixelBufferLockBaseAddress自身的调用并不消耗多少性能，一般情况，锁定之后，往CVPixelBuffer拷贝内存才是相对耗时的操作，比如计算内存偏移。
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    //图像宽度（像素）
    size_t pixelWidth = CVPixelBufferGetWidth(pixelBuffer);
    //图像高度（像素）
    size_t pixelHeight = CVPixelBufferGetHeight(pixelBuffer);
    //获取CVImageBufferRef中的y数据
    uint8_t *y_frame = (unsigned char *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    //获取CMVImageBufferRef中的uv数据
    uint8_t *uv_frame =(unsigned char *) CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
    
    
    // 创建一个空的32BGRA格式的CVPixelBufferRef
    NSDictionary *pixelAttributes = @{(id)kCVPixelBufferIOSurfacePropertiesKey : @{}};
    CVPixelBufferRef pixelBuffer1 = NULL;
    CVReturn result = CVPixelBufferCreate(kCFAllocatorDefault,
                                          pixelWidth,
                                          pixelHeight,
                                          kCVPixelFormatType_32ARGB,
                                          (__bridge CFDictionaryRef)pixelAttributes,
                                          &pixelBuffer1);
    if (result != kCVReturnSuccess) {
        NSLog(@"Unable to create cvpixelbuffer %d", result);
        return NULL;
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    result = CVPixelBufferLockBaseAddress(pixelBuffer1, 0);
    if (result != kCVReturnSuccess) {
        CFRelease(pixelBuffer1);
        NSLog(@"Failed to lock base address: %d", result);
        return NULL;
    }
    
    // 得到新创建的CVPixelBufferRef中 rgb数据的首地址
    uint8_t *rgb_data = (uint8*)CVPixelBufferGetBaseAddress(pixelBuffer1);
    
    // 使用libyuv为rgb_data写入数据，将NV21转换为BGRA
    int ret = NV21ToARGB(y_frame, pixelWidth, uv_frame, pixelWidth, rgb_data, pixelWidth * 4, pixelWidth, pixelHeight);
    if (ret) {
        NSLog(@"Error converting NV12 VideoFrame to BGRA: %d", result);
        CFRelease(pixelBuffer1);
        return NULL;
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer1, 0);
    
    return pixelBuffer1;
}

//MARK: - CVImageBufferRef (RGB)转为UIImage
+ (UIImage *)imageFromRGBImageBuffer:(CVImageBufferRef)imageBuffer
{
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(baseAddress,
                                                 width,
                                                 height,
                                                 8,
                                                 bytesPerRow,
                                                 colorSpace,
                                                 kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    UIImage *image = [UIImage imageWithCGImage:quartzImage];
    CGImageRelease(quartzImage);
    return (image);
}

@end
