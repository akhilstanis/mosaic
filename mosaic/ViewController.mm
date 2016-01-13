//
//  ViewController.m
//  mosaic
//
//  Created by Akhil Stanislavose on 27/07/15.
//  Copyright (c) 2015 Mobile Express. All rights reserved.
//

#import "ViewController.h"

#import "processFrame.h"
#import <TesseractOCR/TesseractOCR.h>
#import <AFNetworking.h>
#import <LLSimpleCamera.h>

#define kImage @"ipad"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (strong, nonatomic) NSMutableArray *tiles;
@property (strong, nonatomic) LLSimpleCamera *camera;
@property (strong, nonatomic) UIButton *snapButton;
@end

@implementation ViewController

-(void)viewDidLoad {
//    [self push:[UIImage imageNamed:@"IMG_1"]];
}

- (IBAction)captureCanvasClicked:(id)sender {
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    self.camera = [[LLSimpleCamera alloc] init];
    [self.camera attachToViewController:self withFrame:CGRectMake(0, 0, screenRect.size.width, screenRect.size.height)];
    self.camera.fixOrientationAfterCapture = YES;
    [self.camera start];

    if (self.snapButton) {
        self.snapButton.hidden = NO;
        [[self view] bringSubviewToFront:self.snapButton];
    } else {
        self.snapButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.snapButton.frame = CGRectMake(self.view.frame.size.width/2 - 35, self.view.frame.size.height - 70, 70, 70);
        self.snapButton.clipsToBounds = YES;
        self.snapButton.layer.cornerRadius = self.snapButton.bounds.size.width / 2.0f;
        self.snapButton.layer.borderColor = [UIColor whiteColor].CGColor;
        self.snapButton.layer.borderWidth = 2.0f;
        self.snapButton.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.5];
        self.snapButton.layer.rasterizationScale = [UIScreen mainScreen].scale;
        self.snapButton.layer.shouldRasterize = YES;
        [self.snapButton addTarget:self action:@selector(snapButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:self.snapButton];
    }
}

- (void)snapButtonPressed:(UIButton *)button {
    [self.camera capture:^(LLSimpleCamera *camera, UIImage *image, NSDictionary *metadata, NSError *error) {
        if(!error) {
            self.snapButton.hidden = YES;

            // we should stop the camera, since we don't need it anymore. We will open a new vc.
            // this very important, otherwise you may experience memory crashes
            [camera stop];

            [[self.camera view] removeFromSuperview];
            [self.imageView setImage:image];

            [self push:image];
        }
        else {
            NSLog(@"An error has occured: %@", error);
        }
    } exactSeenImage:YES];
}


- (void)push:(UIImage *)image {
    // Do any additional setup after loading the view, typically from a nib.
//    [self.imageView setImage:[UIImage imageNamed:@"pattern"]];
    [self.imageView setContentMode:UIViewContentModeScaleAspectFit];
    [self.imageView setClipsToBounds:YES];

    UIImage *img = image;

    std::vector<std::vector<cv::Point>> rectangles = detect([self cvMatFromUIImage:image]);

    if (rectangles.size() == 0) {
        return;
    }

    cv::Mat highlighted = highlight([self cvMatFromUIImage:image]);

    NSLog(@"rows, columns => (%d,%d)", highlighted.rows, highlighted.cols);
    NSLog(@"rows, columns => (%f,%f)", img.size.height, img.size.width);

    std::vector<std::vector<cv::Point>> unNormalizedRects = rectangles;
    rectangles = [self normalizePoints:rectangles];

    cv::Mat normalized = [self rawHighlight:highlighted rectangles:rectangles];
//    cv::Mat normalized = [self rawHighlight:highlighted rectangles:unNormalizedRects];

    cv::Rect canvas = [self canvasRect:rectangles];
    cv::rectangle(normalized, canvas.tl(), canvas.br(), cv::Scalar(0, 0, 255), 5);

    [self.imageView setImage:[self UIImageFromCVMat:normalized]];

//    [self.imageView setImage:[self scale:[UIImage imageNamed:@"lisa"] ToSizeKeepAspect:CGSizeMake(canvas.width, canvas.height)]];


    // Begin mask

    cv::Mat resized = [self cvMatFromUIImage:[self scale:[UIImage imageNamed:@"lisa"] ToSizeKeepAspect:CGSizeMake(canvas.width, canvas.height)]];

    int deltaX = canvas.tl().x, deltaY = canvas.tl().y;

    cv::Mat cleanMat = [self cvMatFromUIImage:img];

    self.tiles = [NSMutableArray array];

    for (int i = 0; i < rectangles.size(); i++) {
        cv::Point topLeft = rectangles[i][0], bottomRight = rectangles[i][2];
        cv::Rect rect = cv::Rect(topLeft, bottomRight);

        cv::Mat imageROI;
        imageROI = normalized(rect);

        cv::Rect tile = cv::Rect(cv::Point(topLeft.x - deltaX, topLeft.y - deltaY), cv::Point(bottomRight.x - deltaX, bottomRight.y - deltaY));
        cv::Mat tileMat = resized(tile);

        tileMat.copyTo(imageROI);

        cv::Rect unNormalRect = cv::Rect(unNormalizedRects[i][0], unNormalizedRects[i][2]);
        cv::Mat ocrMat(cleanMat, unNormalRect);
        cv::Mat tmp;
        ocrMat.copyTo(tmp);
        cv::cvtColor(tmp, tmp, CV_BGR2GRAY);
        cv::threshold(tmp, tmp, 128, 255, 1);

//        cv::transpose(tmp, tmp);
//        cv::flip(tmp, tmp,1);
//        rotate(tmp, -90, tmp);
//        tmp = rotate(tmp, 90);
//        tmp = rotate(tmp, 270);
//        cv::threshold(tmp, tmp, 128, 255, 0);
        UIImage *beforeClean = [self UIImageFromCVMat:tmp];
        tmp = [self cleanForOCR2:tmp];
        UIImage *tmpImage = [self UIImageFromCVMat:tmp];
        self.imageView.image = tmpImage;
//        NSString *scannedId = [self scanNumber:[self UIImageFromCVMat:tmp]];
        NSString *scannedId = [self superLetterRecognizer:tmp];
//        NSString *scannedId = @"";//[self superNumberRecognizer:tmp];
//        return;

        NSLog(@"(%d, %d) - (%d, %d) - %@", imageROI.rows, imageROI.cols, tileMat.rows, tileMat.cols, scannedId);
//        if (i == 0) return;

        NSDictionary *tileDict = @{
                                   @"id": scannedId,
                                   @"topLeftX":[NSNumber numberWithInt:tile.tl().x],
                                   @"topLeftY":[NSNumber numberWithInt:tile.tl().y],
                                   @"width": [NSNumber numberWithInt:tile.width],
                                   @"height": [NSNumber numberWithInt:tile.height]
                               };
        [self.tiles addObject:tileDict];
    }

//    [self.imageView setImage:[self UIImageFromCVMat:normalized]];
    NSLog(@"Dict => %@", self.tiles);
//    return;

    [[[UIAlertView alloc] initWithTitle:@"Tiles" message:[self.tiles description] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];

    AFHTTPRequestOperationManager *manager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:[NSURL URLWithString:@"http://192.168.0.101:4000"]];
    NSData *imageData = UIImageJPEGRepresentation([self UIImageFromCVMat:resized], 0.5);

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self.tiles options:0 error:&error];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSDictionary *parameters = @{@"tiles": jsonString};

    AFHTTPRequestOperation *op = [manager POST:@"/push" parameters:parameters constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
        //do not put image inside parameters dictionary as I did, but append it!
        [formData appendPartWithFileData:imageData name:@"image" fileName:@"photo.jpg" mimeType:@"image/jpeg"];
    } success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"Success: %@ ***** %@", operation.responseString, responseObject);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@ ***** %@", operation.responseString, error);
    }];
    [op start];

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (cv::Mat)cvMatFromUIImage:(UIImage *)image
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;

    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels (color channels + alpha)

    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to  data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags

    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    
    return cvMat;
}

-(UIImage *)UIImageFromCVMat:(cv::Mat)cvMat
{
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
    CGColorSpaceRef colorSpace;

    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }

    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);

    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                                 //width
                                        cvMat.rows,                                 //height
                                        8,                                          //bits per component
                                        8 * cvMat.elemSize(),                       //bits per pixel
                                        cvMat.step[0],                            //bytesPerRow
                                        colorSpace,                                 //colorspace
                                        kCGImageAlphaNone|kCGBitmapByteOrderDefault,// bitmap info
                                        provider,                                   //CGDataProviderRef
                                        NULL,                                       //decode
                                        false,                                      //should interpolate
                                        kCGRenderingIntentDefault                   //intent
                                        );


    // Getting UIImage from CGImage
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
}

-(std::vector<std::vector<cv::Point>>)normalizePoints:(std::vector<std::vector<cv::Point>>)rectangles {

    for (int i = 0; i < rectangles.size(); i++) {
        rectangles[i][1].x = rectangles[i][0].x;
        rectangles[i][3].x = rectangles[i][2].x;
        rectangles[i][0].y = rectangles[i][3].y;
        rectangles[i][2].y = rectangles[i][1].y;
    }

    return rectangles;
}

-(cv::Mat)rawHighlight:(cv::Mat)src rectangles:(std::vector<std::vector<cv::Point>>) rectangles {
    for (int k = 0; k < rectangles.size(); k++) {
        cv::rectangle(src, rectangles[k][0], rectangles[k][2], cv::Scalar(255, 0, 0), 5);
    }
    return src;
}

-(cv::Rect)canvasRect:(std::vector<std::vector<cv::Point>>)rectangles {
    cv::Point topLeft = rectangles[0][0], bottomRight = rectangles[0][0];

    for (int i = 0; i < rectangles.size(); i++) {
        for (int k = 0; k < 4; k++) {
            if (rectangles[i][k].x < topLeft.x) topLeft.x = rectangles[i][k].x;
            if (rectangles[i][k].y < topLeft.y) topLeft.y = rectangles[i][k].y;
            if (rectangles[i][k].x > bottomRight.x) bottomRight.x = rectangles[i][k].x;
            if (rectangles[i][k].y > bottomRight.y) bottomRight.y = rectangles[i][k].y;
        }
    }

    return cv::Rect(topLeft, bottomRight);
}

- (UIImage*)scale:(UIImage *)image ToSizeKeepAspect:(CGSize)newSize {
    UIGraphicsBeginImageContext( newSize );
    [image drawInRect:CGRectMake(0,0,newSize.width,newSize.height)];
    UIImage* newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return newImage;
}

void rotate(cv::Mat& src, double angle, cv::Mat& dst)
{
    int len = std::max(src.cols, src.rows);
    cv::Point2f pt(len/2., len/2.);
    cv::Mat r = cv::getRotationMatrix2D(pt, angle, 1.0);

    cv::warpAffine(src, dst, r, cv::Size(len, len));
}

cv::Mat rotate(cv::Mat src, double angle)
{
    cv::Mat dst;
    cv::Point2f pt(src.cols/2., src.rows/2.);
    cv::Mat r = getRotationMatrix2D(pt, angle, 1.0);
    warpAffine(src, dst, r, cv::Size(src.cols, src.rows));
    return dst;
}

-(NSString *)superNumberRecognizer:(cv::Mat)input {
    G8Tesseract *tesseract = [[G8Tesseract alloc] initWithLanguage:@"eng"];
    tesseract.charWhitelist = @"ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    tesseract.image = [self UIImageFromCVMat:input];
    self.imageView.image = [self UIImageFromCVMat:input];

    std::vector<cv::Rect> textBlocks = detectLetters(input);
    for(int i = 0; i < textBlocks.size(); i++) {
        cv::Mat textBlockROI;
        try {
            textBlockROI = input(textBlocks[i]);
        } catch (std::exception& e) {
            continue;
        }

        cv::Mat textBlock;
        textBlockROI.copyTo(textBlock);
        cv::cvtColor(textBlock, textBlock, CV_BGR2GRAY);
        tesseract.image = [self UIImageFromCVMat:textBlock];
        if ([tesseract recognize]) {
            NSString *recognizedString = [tesseract recognizedText];
            NSString *cleanedString = [recognizedString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

            NSLog(@"cleanedString => %@", recognizedString);
            return cleanedString;
        };

    }

    return @"";
}

-(NSString *)superLetterRecognizer:(cv::Mat)input {
    G8Tesseract *tesseract = [[G8Tesseract alloc] initWithLanguage:@"eng"];
    tesseract.charWhitelist = @"ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890";
    tesseract.image = [self UIImageFromCVMat:input];
    self.imageView.image = [self UIImageFromCVMat:input];
    tesseract.pageSegmentationMode = G8PageSegmentationModeCircleWord;

    if ([tesseract recognize]) {
        NSString *recognizedString = [tesseract recognizedText];
        NSString *cleanedString = [recognizedString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        NSLog(@"cleanedString => %@", recognizedString);
        return cleanedString;
    };

    
    return @"";
}

std::vector<cv::Rect> detectLetters(cv::Mat img)
{
    std::vector<cv::Rect> boundRect;
    cv::Mat img_gray, img_sobel, img_threshold, element;
    cvtColor(img, img_gray, CV_BGR2GRAY);
    cv::Sobel(img_gray, img_sobel, CV_8U, 1, 0, 3, 1, 0, cv::BORDER_DEFAULT);
    cv::threshold(img_sobel, img_threshold, 0, 255, CV_THRESH_OTSU+CV_THRESH_BINARY);
    element = getStructuringElement(cv::MORPH_RECT, cv::Size(15, 10) );
    cv::morphologyEx(img_threshold, img_threshold, CV_MOP_CLOSE, element); //Does the trick
    std::vector< std::vector< cv::Point> > contours;
    cv::findContours(img_threshold, contours, 0, 1);
    std::vector<std::vector<cv::Point> > contours_poly( contours.size() );
    for( int i = 0; i < contours.size(); i++ )
        if (contours[i].size()>100)
        {
            cv::approxPolyDP( cv::Mat(contours[i]), contours_poly[i], 3, true );
            cv::Rect appRect( boundingRect( cv::Mat(contours_poly[i]) ));
            appRect.x -= 25;
            appRect.y -= 25;
            appRect.width += 50;
            appRect.height += 50;
            if (appRect.width>appRect.height)
                boundRect.push_back(appRect);
        }
    return boundRect;
}

-(cv::Mat)cleanForOCR:(cv::Mat)input {
    int centerX = input.cols / 2;
    int centerY = input.rows / 2;
    int radius;

    if (input.rows > input.cols) {
        int rightX = input.cols - 1;
        int leftX  = 0;

        while (input.at<uchar>(centerY,rightX) != 255) rightX--;
        while (input.at<uchar>(centerY,leftX)  != 255) leftX++;

        radius = MAX(rightX - centerX, centerX - leftX);
    } else {
        int topY = 0;
        int bottomY = input.rows - 1;

        while (input.at<uchar>(topY,centerX)     != 255) topY++;
        while (input.at<uchar>(bottomY,centerX)  != 255) bottomY--;

        radius = MAX(bottomY - centerY, centerY - topY);
    }

    cv::Mat mask(input.rows, input.cols, input.type(), cv::Scalar(255, 255, 255));
    cv::circle( mask, cv::Point(centerX, centerY), radius, cv::Scalar(255,255,255),0, 0, 0 );
    cv::floodFill(mask, cv::Point(0,0), cv::Scalar(255.0,255.0,255.0));

    cv::Mat result;
    input.copyTo(result, mask);

//    cv::Rect rect = cv::Rect(cv::Point(centerX-radius,centerY-radius), cv::Point(centerX+radius,centerY+radius));

//    cv::Mat imageROI;
//    imageROI = result(rect);

    return result;
//    return imageROI;
}

-(cv::Mat)cleanForOCR2:(cv::Mat)input {
    int rows = input.rows;
    int cols = input.cols;

    if(input.at<uchar>(2,2) == 0)
        cv::floodFill(input, cv::Point(2,2), cv::Scalar(255.0,255.0,255.0));

    if(input.at<uchar>(2,cols - 2) == 0)
        cv::floodFill(input, cv::Point(cols - 2,2), cv::Scalar(255.0,255.0,255.0));

    if(input.at<uchar>(rows - 2,cols - 2) == 0)
        cv::floodFill(input, cv::Point(cols - 2,rows - 2), cv::Scalar(255.0,255.0,255.0));

    if(input.at<uchar>(rows - 2,2) == 0)
        cv::floodFill(input, cv::Point(2,rows - 2), cv::Scalar(255.0,255.0,255.0));

    cv::Mat result;
    input.copyTo(result);
    return result;
}

@end
