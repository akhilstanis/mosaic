# Mosaic
Simply put, Mosiac is an attempt to create a mosiac out of smartphones. This repo hosts the source code of Mosiac mobile application for iOS.

![final](https://cloud.githubusercontent.com/assets/955760/12316994/b6b7cc5c-bab2-11e5-8258-92c7f3965686.jpg)

## How it works?
Mosiac consists of two parts, [mosaic server](https://github.com/akhilstanislavose/mosaic-server) and mosaic mobile application. To generate a mosiac using smartphones do the following.

* Open up Mosaic server homepage on all the smartphones that is going to be used to create the grid.
* Mosiac homepage is a simple page with just an ID shown to identify each smartphone.
* Arrange the smartphones to create a grid.
* Scan the grid using Mosaic mobile application using the mobile camera, which will identify the screen sizes and locations on the grid, and map it to the ID shown on the smartphone screens.
* Once the grid is scanned, users can upload an image to be shown on the grid.
* Mosaic client application will slice up the image uploaded and will push to each smartphone in the grid via the mosiac server.

## What it makes use of?
The challenging part was to scan the grid and identify the smartphone screens. I used the excellent [OpenCV](http://opencv.org/) library to detect rectangular smartphone screens. [Tesseract OCR](https://github.com/tesseract-ocr/tesseract) library is also used to parse the ID shown on smartphone screens.

## Todo
* Preprocess scanned IDs to avoid invalid OCR results.
* Preserve the aspect ratio of pushed image ie., Aspect fit instead of fill.
* Implement animation using sliding window technique.
* Implement Andorid client.

## Contributing
1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
