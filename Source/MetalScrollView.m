typedef struct Arguments Arguments;
struct Arguments {
	MTLResourceID documentViewTexture;
	simd_float2 documentViewOrigin;
	simd_float2 documentViewSize;
	simd_float2 resolution;
};

typedef struct ClearArguments ClearArguments;
struct ClearArguments {
	simd_float4 clearColor;
};

typedef struct DivideArguments DivideArguments;
struct DivideArguments {
	float subframeCount;
};

@implementation MetalScrollView {
	NSAttributedString *_attributedString;

	id<MTLDevice> _device;
	id<MTLCommandQueue> _commandQueue;
	id<MTLRenderPipelineState> _pipelineState;
	id<MTLRenderPipelineState> _clearPipelineState;
	id<MTLRenderPipelineState> _accumulatePipelineState;
	id<MTLRenderPipelineState> _dividePipelineState;

	IOSurfaceRef _frontBuffer;
	id<MTLTexture> _frontBufferTexture;
	IOSurfaceRef _backBuffer;
	id<MTLTexture> _backBufferTexture;

	IOSurfaceRef _cachedDocumentView;
	id<MTLTexture> _cachedDocumentViewTexture;
	simd_float2 _documentViewSize;

	id<MTLTexture> _subframeTexture;
	id<MTLTexture> _accumulationTexture;

	CGFloat _scrollOffset;
	CGFloat _scrollOffsetLastDisplay;
}

+ (instancetype)scrollViewWithAttributedString:(NSAttributedString *)attributedString {
	MetalScrollView *scrollView = [[MetalScrollView alloc] init];
	scrollView.wantsLayer = YES;
	scrollView.layerContentsRedrawPolicy = NSViewLayerContentsRedrawDuringViewResize;

	scrollView->_attributedString = attributedString;

	scrollView->_device = MTLCreateSystemDefaultDevice();
	scrollView->_commandQueue = [scrollView->_device newCommandQueue];

	id<MTLLibrary> library = [scrollView->_device newDefaultLibrary];

	{
		MTLRenderPipelineDescriptor *descriptor = [[MTLRenderPipelineDescriptor alloc] init];
		descriptor.vertexFunction = [library newFunctionWithName:@"VertexMain"];
		descriptor.fragmentFunction = [library newFunctionWithName:@"FragmentMain"];
		descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
		descriptor.colorAttachments[0].blendingEnabled = YES;
		descriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
		descriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
		descriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorOne;
		descriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
		descriptor.colorAttachments[1].pixelFormat = MTLPixelFormatRGBA16Float;
		descriptor.colorAttachments[2].pixelFormat = MTLPixelFormatBGRA8Unorm;
		scrollView->_pipelineState = [scrollView->_device newRenderPipelineStateWithDescriptor:descriptor error:nil];
	}

	{
		MTLTileRenderPipelineDescriptor *descriptor = [[MTLTileRenderPipelineDescriptor alloc] init];
		descriptor.tileFunction = [library newFunctionWithName:@"Clear"];
		descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
		descriptor.colorAttachments[1].pixelFormat = MTLPixelFormatRGBA16Float;
		descriptor.colorAttachments[2].pixelFormat = MTLPixelFormatBGRA8Unorm;
		scrollView->_clearPipelineState =
		        [scrollView->_device newRenderPipelineStateWithTileDescriptor:descriptor
		                                                              options:MTLPipelineOptionNone
		                                                           reflection:nil
		                                                                error:nil];
	}

	{
		MTLTileRenderPipelineDescriptor *descriptor = [[MTLTileRenderPipelineDescriptor alloc] init];
		descriptor.tileFunction = [library newFunctionWithName:@"Accumulate"];
		descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
		descriptor.colorAttachments[1].pixelFormat = MTLPixelFormatRGBA16Float;
		descriptor.colorAttachments[2].pixelFormat = MTLPixelFormatBGRA8Unorm;
		scrollView->_accumulatePipelineState =
		        [scrollView->_device newRenderPipelineStateWithTileDescriptor:descriptor
		                                                              options:MTLPipelineOptionNone
		                                                           reflection:nil
		                                                                error:nil];
	}

	{
		MTLTileRenderPipelineDescriptor *descriptor = [[MTLTileRenderPipelineDescriptor alloc] init];
		descriptor.tileFunction = [library newFunctionWithName:@"Divide"];
		descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
		descriptor.colorAttachments[1].pixelFormat = MTLPixelFormatRGBA16Float;
		descriptor.colorAttachments[2].pixelFormat = MTLPixelFormatBGRA8Unorm;
		scrollView->_dividePipelineState =
		        [scrollView->_device newRenderPipelineStateWithTileDescriptor:descriptor
		                                                              options:MTLPipelineOptionNone
		                                                           reflection:nil
		                                                                error:nil];
	}
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

		descriptor.storageMode = MTLStorageModeMemoryless;
		_subframeTexture = [_device newTextureWithDescriptor:descriptor];
		_subframeTexture.label = @"Subframe Texture";

		descriptor.pixelFormat = MTLPixelFormatRGBA16Float;
		_accumulationTexture = [_device newTextureWithDescriptor:descriptor];
		_accumulationTexture.label = @"Accumulation Texture";
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
	simd_float4 backgroundColor = 0;
	backgroundColor.r = (float)backgroundColorNS.redComponent;
	backgroundColor.g = (float)backgroundColorNS.greenComponent;
	backgroundColor.b = (float)backgroundColorNS.blueComponent;
	backgroundColor.a = (float)backgroundColorNS.alphaComponent;
	backgroundColor.rgb *= backgroundColor.a;

	MTLRenderPassDescriptor *descriptor = [[MTLRenderPassDescriptor alloc] init];

	descriptor.colorAttachments[0].texture = _subframeTexture;
	descriptor.colorAttachments[0].loadAction = MTLLoadActionDontCare;
	descriptor.colorAttachments[0].storeAction = MTLStoreActionDontCare;

	descriptor.colorAttachments[1].texture = _accumulationTexture;
	descriptor.colorAttachments[1].loadAction = MTLLoadActionClear;
	descriptor.colorAttachments[1].storeAction = MTLStoreActionDontCare;
	descriptor.colorAttachments[1].clearColor = (MTLClearColor){0};

	descriptor.colorAttachments[2].texture = _backBufferTexture;
	descriptor.colorAttachments[2].loadAction = MTLLoadActionDontCare;
	descriptor.colorAttachments[2].storeAction = MTLStoreActionStore;

	id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:descriptor];

	[encoder useResource:_cachedDocumentViewTexture usage:MTLResourceUsageRead stages:MTLRenderStageFragment];
	NSInteger subframeCount = 10;

	for (NSInteger subframeIndex = 0; subframeIndex < subframeCount; subframeIndex++) {
		{
			[encoder setRenderPipelineState:_clearPipelineState];
			ClearArguments arguments = {0};
			arguments.clearColor = backgroundColor;
			[encoder setTileBytes:&arguments length:sizeof(arguments) atIndex:0];
			[encoder dispatchThreadsPerTile:(MTLSize){encoder.tileWidth, encoder.tileHeight, 1}];
		}

		float fractionThrough = (float)subframeIndex / (float)subframeCount;
		float subframeScrollOffset = simd_mix((float)_scrollOffsetLastDisplay, (float)_scrollOffset, fractionThrough);
		subframeScrollOffset *= scaleFactor;

		[encoder setRenderPipelineState:_pipelineState];

		Arguments arguments = {0};
		arguments.documentViewTexture = _cachedDocumentViewTexture.gpuResourceID;
		arguments.documentViewOrigin.y = subframeScrollOffset;
		arguments.documentViewSize.x = _cachedDocumentViewTexture.width;
		arguments.documentViewSize.y = _cachedDocumentViewTexture.height;
		arguments.resolution = sizePixelsFloat;

		[encoder setVertexBytes:&arguments length:sizeof(arguments) atIndex:0];
		[encoder setFragmentBytes:&arguments length:sizeof(arguments) atIndex:0];
		[encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];

		[encoder setRenderPipelineState:_accumulatePipelineState];
		[encoder dispatchThreadsPerTile:(MTLSize){encoder.tileWidth, encoder.tileHeight, 1}];
	}

	[encoder setRenderPipelineState:_dividePipelineState];
	DivideArguments arguments = {0};
	arguments.subframeCount = subframeCount;
	[encoder setTileBytes:&arguments length:sizeof(arguments) atIndex:0];
	[encoder dispatchThreadsPerTile:(MTLSize){encoder.tileWidth, encoder.tileHeight, 1}];

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

	_scrollOffsetLastDisplay = _scrollOffset;
}

- (void)scrollWheel:(NSEvent *)event {
	_scrollOffset -= event.scrollingDeltaY;
	_scrollOffset = simd_clamp(_scrollOffset, simd_min(0, self.bounds.size.height - _documentViewSize.y), 0);
	self.needsDisplay = YES;
}

@end
