//
//  processFrame.h
//  mosaic
//
//  Created by Akhil Stanislavose on 27/07/15.
//  Copyright (c) 2015 Mobile Express. All rights reserved.
//

#ifndef mosaic_processFrame_h
#define mosaic_processFrame_h

std::vector<std::vector<cv::Point>> detect(cv::Mat src);
cv::Mat highlight(cv::Mat src);

#endif
