//
//  MainVC.m
//  NV21Image
//
//  Created by GreeX on 2021/6/12.
//

#import "MainVC.h"
#import "NV21Convert.h"

#define kImgW 480

@interface MainVC ()

@property (nonatomic, strong) UIImageView *baseImgView;
@property (nonatomic, strong) UIImageView *converImgView;

@end

@implementation MainVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _baseImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 100, 200, 200)];
    [self.view addSubview:_baseImgView];
    
    UIImage *baseImg = [UIImage imageNamed:@"face.jpeg"];
    _baseImgView.image = baseImg;
    
    
    // UIImage -> CVPixelBufferRef(NV21) -> nv21 data
    UIImage *newSizeImg = [self newSizeImg:baseImg];
    NSData *nv21Data = [NV21Convert convertDataWithImage:newSizeImg];
    // nv21 data -> CVPixelBufferRef(NV21) -> UIImage
    UIImage *converImg = [NV21Convert convertImageWithData:nv21Data imageSize:CGSizeMake(kImgW, kImgW)];
    
    // 显示UIImage转换成NV21，再转换成UIImage的图片
    _converImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 320, 200, 200)];
    [self.view addSubview:_converImgView];
    _converImgView.image = converImg;
}

// 注意尺寸！
// 注意尺寸！
// 注意尺寸！
// 尺寸480
- (UIImage *)newSizeImg:(UIImage *)img {
    CGFloat scale = kImgW / UIScreen.mainScreen.scale;
    CGSize size = CGSizeMake(scale, scale);
    
    UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.mainScreen.scale);
    [img drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *resizeImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return  resizeImage;
}



@end
