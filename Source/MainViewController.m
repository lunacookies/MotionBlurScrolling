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
	NSTextField *textField = [NSTextField wrappingLabelWithString:string];
	textField.translatesAutoresizingMaskIntoConstraints = NO;

	NSView *documentView = [[NSView alloc] init];
	[documentView addSubview:textField];
	documentView.translatesAutoresizingMaskIntoConstraints = NO;

	NSScrollView *scrollView = [[NSScrollView alloc] init];
	scrollView.documentView = documentView;
	scrollView.hasVerticalScroller = YES;

	[self.view addSubview:scrollView];
	scrollView.translatesAutoresizingMaskIntoConstraints = NO;

	[NSLayoutConstraint activateConstraints:@[
		[scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
		[scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
		[scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
		[scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

		[documentView.leadingAnchor constraintEqualToAnchor:scrollView.contentView.leadingAnchor],
		[documentView.trailingAnchor constraintEqualToAnchor:scrollView.contentView.trailingAnchor],

		[textField.topAnchor constraintEqualToAnchor:documentView.topAnchor],
		[textField.bottomAnchor constraintLessThanOrEqualToAnchor:documentView.bottomAnchor constant:-10],
		[textField.leadingAnchor constraintEqualToAnchor:documentView.leadingAnchor constant:10],
		[textField.trailingAnchor constraintEqualToAnchor:documentView.trailingAnchor constant:-10],
	]];
}

@end
