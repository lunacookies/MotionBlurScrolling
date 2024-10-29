@implementation MainViewController

- (instancetype)init {
	self = [super init];
	self.title = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleDisplayName"];
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];

	NSURL *url = [NSBundle.mainBundle URLForResource:@"Text" withExtension:@"txt"];
	NSString *string = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
	NSAttributedString *attributedString =
	        [[NSAttributedString alloc] initWithString:string
	                                        attributes:@{
		                                        NSFontAttributeName : [NSFont systemFontOfSize:NSFont.systemFontSize],
		                                        NSForegroundColorAttributeName : NSColor.labelColor,
	                                        }];

	NSTextField *textField = [NSTextField labelWithAttributedString:attributedString];
	textField.translatesAutoresizingMaskIntoConstraints = NO;

	NSView *documentView = [[NSView alloc] init];
	[documentView addSubview:textField];
	documentView.translatesAutoresizingMaskIntoConstraints = NO;

	NSScrollView *appKitScrollView = [[NSScrollView alloc] init];
	appKitScrollView.documentView = documentView;
	appKitScrollView.hasVerticalScroller = YES;

	[NSLayoutConstraint activateConstraints:@[
		[documentView.leadingAnchor constraintEqualToAnchor:appKitScrollView.contentView.leadingAnchor],
		[documentView.trailingAnchor constraintEqualToAnchor:appKitScrollView.contentView.trailingAnchor],

		[textField.topAnchor constraintEqualToAnchor:documentView.topAnchor constant:5],
		[textField.bottomAnchor constraintLessThanOrEqualToAnchor:documentView.bottomAnchor constant:-10],
		[textField.leadingAnchor constraintEqualToAnchor:documentView.leadingAnchor constant:10],
		[textField.trailingAnchor constraintEqualToAnchor:documentView.trailingAnchor constant:-10],
	]];

	MetalScrollView *metalScrollView = [MetalScrollView scrollViewWithAttributedString:attributedString];

	NSBox *separatorBox = [[NSBox alloc] init];
	separatorBox.boxType = NSBoxSeparator;

	[self.view addSubview:appKitScrollView];
	[self.view addSubview:separatorBox];
	[self.view addSubview:metalScrollView];
	appKitScrollView.translatesAutoresizingMaskIntoConstraints = NO;
	separatorBox.translatesAutoresizingMaskIntoConstraints = NO;
	metalScrollView.translatesAutoresizingMaskIntoConstraints = NO;

	[NSLayoutConstraint activateConstraints:@[
		[appKitScrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
		[appKitScrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
		[appKitScrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],

		[separatorBox.topAnchor constraintEqualToAnchor:self.view.topAnchor],
		[separatorBox.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
		[separatorBox.leadingAnchor constraintEqualToAnchor:appKitScrollView.trailingAnchor],
		[separatorBox.trailingAnchor constraintEqualToAnchor:metalScrollView.leadingAnchor],

		[metalScrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
		[metalScrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
		[metalScrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

		[appKitScrollView.widthAnchor constraintEqualToAnchor:metalScrollView.widthAnchor],
	]];
}

@end
