typedef struct Arguments Arguments;
struct Arguments {
	MTLResourceID documentViewTexture;
	simd_float2 documentViewOrigin;
	simd_float2 documentViewSize;
	simd_float2 resolution;
};

@implementation MetalScrollView {
	NSAttributedString *_attributedString;

	id<MTLDevice> _device;
	id<MTLCommandQueue> _commandQueue;
	id<MTLRenderPipelineState> _pipelineState;

	IOSurfaceRef _frontBuffer;
	id<MTLTexture> _frontBufferTexture;
	IOSurfaceRef _backBuffer;
	id<MTLTexture> _backBufferTexture;
	IOSurfaceRef _cachedDocumentView;
	id<MTLTexture> _cachedDocumentViewTexture;
	simd_float2 _documentViewSize;

	CGFloat _scrollOffset;
}

+ (instancetype)scrollViewWithAttributedString:(NSAttributedString *)attributedString {
	MetalScrollView *scrollView = [[MetalScrollView alloc] init];
	scrollView.wantsLayer = YES;
	scrollView.layerContentsRedrawPolicy = NSViewLayerContentsRedrawDuringViewResize;

	scrollView->_attributedString = attributedString;

	scrollView->_device = MTLCreateSystemDefaultDevice();
	scrollView->_commandQueue = [scrollView->_device newCommandQueue];
	id<MTLLibrary> library = [scrollView->_device newDefaultLibrary];
	MTLRenderPipelineDescriptor *descriptor = [[MTLRenderPipelineDescriptor alloc] init];
	descriptor.vertexFunction = [library newFunctionWithName:@"VertexMain"];
	descriptor.fragmentFunction = [library newFunctionWithName:@"FragmentMain"];
	descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
	descriptor.colorAttachments[0].blendingEnabled = YES;
	descriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
	descriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
	descriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorOne;
	descriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
	scrollView->_pipelineState = [scrollView->_device newRenderPipelineStateWithDescriptor:descriptor error:nil];

	return scrollView;
}

- (BOOL)wantsUpdateLayer {
	return YES;
}

- (void)updateLayer {
	float scaleFactor = (float)self.window.backingScaleFactor;
	NSSize sizeNS = self.bounds.size;
	simd_float2 sizePixelsFloat = (simd_float2){(float)sizeNS.width, (float)sizeNS.height} * scaleFactor;
	simd_long2 sizePixels = simd_long(sizePixelsFloat);

	simd_long2 currentSizePixels = 0;
	if (_backBuffer != NULL) {
		currentSizePixels.x = (long)IOSurfaceGetWidth(_backBuffer);
		currentSizePixels.y = (long)IOSurfaceGetHeight(_backBuffer);
	}

	if (simd_any(currentSizePixels != sizePixels)) {
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

		MTLTextureDescriptor *descriptor = [[MTLTextureDescriptor alloc] init];
		descriptor.width = (NSUInteger)sizePixels.x;
		descriptor.height = (NSUInteger)sizePixels.y;
		descriptor.storageMode = MTLStorageModeShared;
		descriptor.usage = MTLTextureUsageRenderTarget;
		descriptor.pixelFormat = MTLPixelFormatBGRA8Unorm;

		_backBufferTexture = [_device newTextureWithDescriptor:descriptor iosurface:_backBuffer plane:0];
		_backBufferTexture.label = @"Layer Backing Store";
	}

	long desiredDocumentViewWidth = (long)sizeNS.width;
	long desiredDocumentViewWidthPixels = (long)ceil(desiredDocumentViewWidth * scaleFactor);
	if (_cachedDocumentView == NULL || (long)IOSurfaceGetWidth(_cachedDocumentView) != desiredDocumentViewWidthPixels) {
		CTFramesetterRef framesetter =
		        CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)_attributedString);

		CGSize frameSizeConstraints = {0};
		frameSizeConstraints.width = desiredDocumentViewWidth - 10 - 10;
		frameSizeConstraints.height = CGFLOAT_MAX;

		CGSize frameSize = CTFramesetterSuggestFrameSizeWithConstraints(
		        framesetter, (CFRange){0}, NULL, frameSizeConstraints, NULL);

		_documentViewSize.x = desiredDocumentViewWidth;
		_documentViewSize.y = (float)ceil(frameSize.height) + 5 + 10;
		simd_long2 documentViewSizePixels = simd_long(scaleFactor * _documentViewSize);

		NSDictionary *properties = @{
			(__bridge NSString *)kIOSurfaceWidth : @(documentViewSizePixels.x),
			(__bridge NSString *)kIOSurfaceHeight : @(documentViewSizePixels.y),
			(__bridge NSString *)kIOSurfaceBytesPerElement : @4,
			(__bridge NSString *)kIOSurfacePixelFormat : @(kCVPixelFormatType_32BGRA),
		};

		if (_cachedDocumentView != NULL) {
			CFRelease(_cachedDocumentView);
		}
		_cachedDocumentView = IOSurfaceCreate((__bridge CFDictionaryRef)properties);

		MTLTextureDescriptor *descriptor = [[MTLTextureDescriptor alloc] init];
		descriptor.width = (NSUInteger)documentViewSizePixels.x;
		descriptor.height = (NSUInteger)documentViewSizePixels.y;
		descriptor.storageMode = MTLStorageModeShared;
		descriptor.pixelFormat = MTLPixelFormatBGRA8Unorm;

		_cachedDocumentViewTexture = [_device newTextureWithDescriptor:descriptor
		                                                     iosurface:_cachedDocumentView
		                                                         plane:0];
		_cachedDocumentViewTexture.label = @"Cached Document View";

		IOSurfaceLock(_cachedDocumentView, 0, NULL);

		CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
		CGContextRef context =
		        CGBitmapContextCreate(IOSurfaceGetBaseAddress(_cachedDocumentView), (size_t)documentViewSizePixels.x,
		                (size_t)documentViewSizePixels.y, 8, IOSurfaceGetBytesPerRow(_cachedDocumentView), colorSpace,
		                kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
		CGContextScaleCTM(context, scaleFactor, scaleFactor);

		CGRect frameRect = {0};
		frameRect.origin.x = 10;
		frameRect.origin.y = 10;
		frameRect.size = frameSize;

		CGPathRef path = CGPathCreateWithRect(frameRect, NULL);
		CTFrameRef frame = CTFramesetterCreateFrame(framesetter, (CFRange){0}, path, NULL);
		CTFrameDraw(frame, context);

		CFRelease(path);
		CFRelease(frame);
		CFRelease(framesetter);
		CFRelease(context);
		CFRelease(colorSpace);

		IOSurfaceUnlock(_cachedDocumentView, 0, NULL);
	}

	id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];

	NSColor *backgroundColorNS = [NSColor.controlBackgroundColor colorUsingColorSpace:NSColorSpace.deviceRGBColorSpace];
	simd_double4 rgba = 0;
	rgba.r = backgroundColorNS.redComponent;
	rgba.g = backgroundColorNS.greenComponent;
	rgba.b = backgroundColorNS.blueComponent;
	rgba.a = backgroundColorNS.alphaComponent;
	rgba.rgb *= rgba.a;
	MTLClearColor clearColor = {rgba.r, rgba.g, rgba.b, rgba.a};

	MTLRenderPassDescriptor *descriptor = [[MTLRenderPassDescriptor alloc] init];
	descriptor.colorAttachments[0].texture = _backBufferTexture;
	descriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
	descriptor.colorAttachments[0].clearColor = clearColor;

	id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:descriptor];

	[encoder setRenderPipelineState:_pipelineState];

	Arguments arguments = {0};
	arguments.documentViewTexture = _cachedDocumentViewTexture.gpuResourceID;
	arguments.documentViewOrigin.y = scaleFactor * (float)_scrollOffset;
	arguments.documentViewSize.x = _cachedDocumentViewTexture.width;
	arguments.documentViewSize.y = _cachedDocumentViewTexture.height;
	arguments.resolution = sizePixelsFloat;

	[encoder useResource:_cachedDocumentViewTexture usage:MTLResourceUsageRead stages:MTLRenderStageFragment];
	[encoder setVertexBytes:&arguments length:sizeof(arguments) atIndex:0];
	[encoder setFragmentBytes:&arguments length:sizeof(arguments) atIndex:0];
	[encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];

	[encoder endEncoding];

	[commandBuffer commit];
	[commandBuffer waitUntilCompleted];

	IOSurfaceRef tmp = _frontBuffer;
	id<MTLTexture> tmpTexture = _frontBufferTexture;
	_frontBuffer = _backBuffer;
	_frontBufferTexture = _backBufferTexture;
	_backBuffer = tmp;
	_backBufferTexture = tmpTexture;
	self.layer.contents = (__bridge id)_frontBuffer;
}

- (void)scrollWheel:(NSEvent *)event {
	_scrollOffset -= event.scrollingDeltaY;
	_scrollOffset = simd_clamp(_scrollOffset, simd_min(0, self.bounds.size.height - _documentViewSize.y), 0);
	self.needsDisplay = YES;
}

@end
