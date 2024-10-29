@implementation MetalScrollView {
	NSAttributedString *_attributedString;
	IOSurfaceRef _frontBuffer;
	IOSurfaceRef _backBuffer;
	CGFloat _scrollOffset;
}

+ (instancetype)scrollViewWithAttributedString:(NSAttributedString *)attributedString {
	MetalScrollView *scrollView = [[MetalScrollView alloc] init];
	scrollView.wantsLayer = YES;
	scrollView.layerContentsRedrawPolicy = NSViewLayerContentsRedrawDuringViewResize;
	scrollView->_attributedString = attributedString;
	return scrollView;
}

- (BOOL)wantsUpdateLayer {
	return YES;
}

- (void)updateLayer {
	NSSize sizeNS = self.layer.frame.size;
	NSSize sizePixelsNS = [self convertSizeToBacking:sizeNS];
	simd_long2 sizePixels = {(long)sizePixelsNS.width, (long)sizePixelsNS.height};

	simd_long2 currentSize = 0;
	if (_backBuffer != NULL) {
		currentSize.x = (long)IOSurfaceGetWidth(_backBuffer);
		currentSize.y = (long)IOSurfaceGetHeight(_backBuffer);
	}

	if (simd_any(currentSize != sizePixels)) {
		NSDictionary *properties = @{
			(__bridge NSString *)kIOSurfaceWidth : @(sizePixels.x),
			(__bridge NSString *)kIOSurfaceHeight : @(sizePixels.y),
			(__bridge NSString *)kIOSurfaceBytesPerElement : @4,
			(__bridge NSString *)kIOSurfacePixelFormat : @(kCVPixelFormatType_32BGRA),
		};

		if (_backBuffer != NULL) {
			CFRelease(_backBuffer);
		}
		_backBuffer = IOSurfaceCreate((__bridge CFDictionaryRef)properties);
	}

	IOSurfaceLock(_backBuffer, 0, NULL);

	uint32_t backgroundColor = 0;
	{
		NSColor *backgroundColorNS =
		        [NSColor.controlBackgroundColor colorUsingColorSpace:NSColorSpace.deviceRGBColorSpace];
		simd_double4 rgba = 0;
		rgba.r = backgroundColorNS.redComponent;
		rgba.g = backgroundColorNS.greenComponent;
		rgba.b = backgroundColorNS.blueComponent;
		rgba.a = backgroundColorNS.alphaComponent;
		rgba.rgb *= rgba.a;
		backgroundColor |= (uint32_t)round(rgba.b * 255) << 0;
		backgroundColor |= (uint32_t)round(rgba.g * 255) << 8;
		backgroundColor |= (uint32_t)round(rgba.r * 255) << 16;
		backgroundColor |= (uint32_t)round(rgba.a * 255) << 24;
	}
	uint8_t *pixels = IOSurfaceGetBaseAddress(_backBuffer);
	size_t bytesPerRow = IOSurfaceGetBytesPerRow(_backBuffer);
	for (size_t y = 0; y < (size_t)sizePixels.y; y++) {
		uint32_t *row = (uint32_t *)(pixels + y * bytesPerRow);
		for (size_t x = 0; x < (size_t)sizePixels.x; x++) {
			row[x] = backgroundColor;
		}
	}

	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(pixels, (size_t)sizePixels.x, (size_t)sizePixels.y, 8, bytesPerRow,
	        colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
	CGContextScaleCTM(context, self.window.backingScaleFactor, self.window.backingScaleFactor);

	CTFramesetterRef framesetter =
	        CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)_attributedString);

	CGSize frameSizeConstraints = {0};
	frameSizeConstraints.width = sizeNS.width - 10 - 10;
	frameSizeConstraints.height = CGFLOAT_MAX;

	CGSize frameSize =
	        CTFramesetterSuggestFrameSizeWithConstraints(framesetter, (CFRange){0}, NULL, frameSizeConstraints, NULL);

	_scrollOffset = simd_clamp(_scrollOffset, 0, simd_max(0, frameSize.height - sizeNS.height + 5 + 10));

	CGRect frameRect = {0};
	frameRect.origin.x = 10;
	frameRect.origin.y = sizeNS.height - frameSize.height - 5 + _scrollOffset;
	frameRect.size = frameSize;

	CGPathRef path = CGPathCreateWithRect(frameRect, NULL);
	CTFrameRef frame = CTFramesetterCreateFrame(framesetter, (CFRange){0}, path, NULL);
	CTFrameDraw(frame, context);

	CFRelease(path);
	CFRelease(frame);
	CFRelease(framesetter);
	CFRelease(context);
	CFRelease(colorSpace);

	IOSurfaceUnlock(_backBuffer, 0, NULL);

	IOSurfaceRef tmp = _frontBuffer;
	_frontBuffer = _backBuffer;
	_backBuffer = tmp;
	self.layer.contents = (__bridge id)_frontBuffer;
}

- (void)scrollWheel:(NSEvent *)event {
	_scrollOffset -= event.scrollingDeltaY;
	self.needsDisplay = YES;
}

@end
