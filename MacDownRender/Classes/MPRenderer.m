//
//  MPRenderer.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 26/6.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPRenderer.h"
#import <limits.h>
#import "html.h"
#import "document.h"
#import <HBHandlebars/HBHandlebars.h>
#import "hoedown_html_patch.h"
#import "NSJSONSerialization+File.h"
#import "NSObject+HTMLTabularize.h"
#import "NSString+Lookup.h"
#import "MPUtilities.h"
#import "MPAsset.h"
#import "MPPreferences.h"
#import "Bundle.h"

@implementation NSString (MacDownRender)

- (void)markdown:(void (^)(NSString *))done {
    MPRenderer *render = MPRenderer.shared;
    render.title = @"";
    render.content = self;
    render.renderDone = done;
    [render parseAndRenderNow];
}

- (void)markdownwith:(NSString *)title done:(void (^)(NSString *))done {
    MPRenderer *render = MPRenderer.shared;
    render.title = title;
    render.content = self;
    render.renderDone = done;
    [render parseAndRenderNow];
}

@end

static NSString * const kMPMathJaxCDN =
    @"https://cdn.mathjax.org/mathjax/latest/MathJax.js"
    @"?config=TeX-AMS-MML_HTMLorMML";
static NSString * const kMPPrismScriptDirectory = @"components";
static NSString * const kMPPrismThemeDirectory = @"themes";
static NSString * const kMPPrismPluginDirectory = @"plugins";
static size_t kMPRendererNestingLevel = SIZE_MAX;
static int kMPRendererTOCLevel = 6;  // h1 to h6.


NS_INLINE NSURL *MPExtensionURL(NSString *name, NSString *extension)
{
    NSBundle *bundle = Bundle.Extensions;
    NSURL *url = [bundle URLForResource:name withExtension:extension];
    return url;
}

NS_INLINE NSURL *MPPrismPluginURL(NSString *name, NSString *extension)
{
    NSBundle *bundle = Bundle.Prism;
    NSString *dirPath =
        [NSString stringWithFormat:@"%@/%@", kMPPrismPluginDirectory, name];

    NSString *filename = [NSString stringWithFormat:@"prism-%@.min", name];
    NSURL *url = [bundle URLForResource:filename withExtension:extension
                           subdirectory:dirPath];
    if (url)
        return url;

    filename = [NSString stringWithFormat:@"prism-%@", name];
    url = [bundle URLForResource:filename withExtension:extension
                    subdirectory:dirPath];
    return url;
}

NS_INLINE NSArray *MPPrismScriptURLsForLanguage(NSString *language)
{
    NSURL *baseUrl = nil;
    NSURL *extraUrl = nil;
    NSBundle *bundle = Bundle.Prism;

    language = [language lowercaseString];
    NSString *baseFileName =
        [NSString stringWithFormat:@"prism-%@", language];
    NSString *extraFileName =
        [NSString stringWithFormat:@"prism-%@-extras", language];

    for (NSString *ext in @[@"min.js", @"js"])
    {
        if (!baseUrl)
        {
            baseUrl = [bundle URLForResource:baseFileName withExtension:ext
                                subdirectory:kMPPrismScriptDirectory];
        }
        if (!extraUrl)
        {
            extraUrl = [bundle URLForResource:extraFileName withExtension:ext
                                 subdirectory:kMPPrismScriptDirectory];
        }
    }

    NSMutableArray *urls = [NSMutableArray array];
    if (baseUrl)
        [urls addObject:baseUrl];
    if (extraUrl)
        [urls addObject:extraUrl];
    return urls;
}

NS_INLINE NSString *MPHTMLFromMarkdown(
    NSString *text, int flags, BOOL smartypants, NSString *frontMatter,
    hoedown_renderer *htmlRenderer, hoedown_renderer *tocRenderer)
{
    NSData *inputData = [text dataUsingEncoding:NSUTF8StringEncoding];
    hoedown_document *document = hoedown_document_new(
        htmlRenderer, flags, kMPRendererNestingLevel);
    hoedown_buffer *ob = hoedown_buffer_new(64);
    hoedown_document_render(document, ob, inputData.bytes, inputData.length);
    if (smartypants)
    {
        hoedown_buffer *ib = ob;
        ob = hoedown_buffer_new(64);
        hoedown_html_smartypants(ob, ib->data, ib->size);
        hoedown_buffer_free(ib);
    }
    NSString *result = [NSString stringWithUTF8String:hoedown_buffer_cstr(ob)];
    hoedown_document_free(document);
    hoedown_buffer_free(ob);

    if (tocRenderer)
    {
        document = hoedown_document_new(
            tocRenderer, flags, kMPRendererNestingLevel);
        ob = hoedown_buffer_new(64);
        hoedown_document_render(
            document, ob, inputData.bytes, inputData.length);
        NSString *toc = [NSString stringWithUTF8String:hoedown_buffer_cstr(ob)];

        static NSRegularExpression *tocRegex = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSString *pattern = @"<p.*?>\\s*\\[TOC\\]\\s*</p>";
            NSRegularExpressionOptions ops = NSRegularExpressionCaseInsensitive;
            tocRegex = [[NSRegularExpression alloc] initWithPattern:pattern
                                                            options:ops
                                                              error:NULL];
        });
        NSRange replaceRange = NSMakeRange(0, result.length);
        result = [tocRegex stringByReplacingMatchesInString:result options:0
                                                      range:replaceRange
                                               withTemplate:toc];
        hoedown_document_free(document);
        hoedown_buffer_free(ob);
    }
    if (frontMatter)
        result = [NSString stringWithFormat:@"%@\n%@", frontMatter, result];
    
    return result;
}

NS_INLINE NSString *MPGetHTML(
    NSString *title, NSString *body, NSArray *styles, MPAssetOption styleopt,
    NSArray *scripts, MPAssetOption scriptopt)
{
    NSMutableArray *styleTags = [NSMutableArray array];
    NSMutableArray *scriptTags = [NSMutableArray array];
    for (MPStyleSheet *style in styles)
    {
        NSString *s = [style htmlForOption:styleopt];
        if (s)
            [styleTags addObject:s];
    }
    for (MPScript *script in scripts)
    {
        NSString *s = [script htmlForOption:scriptopt];
        if (s)
            [scriptTags addObject:s];
    }

    MPPreferences *preferences = [MPPreferences sharedInstance];

    static NSString *f = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        NSBundle *bundle = [NSBundle bundleForClass:MPRenderer.class];
        NSString *path = [bundle pathForResource:@"MacDownRender" ofType:@"bundle"];
        NSBundle *b = [NSBundle bundleWithPath:path];
        NSString *t = [b pathForResource:@"Templates" ofType:nil];
        NSBundle *tt = [NSBundle bundleWithPath:t];
        NSURL *url = [tt URLForResource:preferences.htmlTemplateName
                              withExtension:@".handlebars"];
        f = [NSString stringWithContentsOfURL:url
                                     encoding:NSUTF8StringEncoding error:NULL];
    });
    NSCAssert(f.length, @"Could not read template");

    NSString *titleTag = @"";
    if (title.length)
        titleTag = [NSString stringWithFormat:@"<title>%@</title>", title];

    NSDictionary *context = @{
        @"title": title,
        @"titleTag": titleTag,
        @"styleTags": styleTags,
        @"body": body,
        @"scriptTags": scriptTags,
    };
    NSString *html = [HBHandlebars renderTemplateString:f withContext:context
                                                  error:NULL];
    return html;
}

NS_INLINE BOOL MPAreNilableStringsEqual(NSString *s1, NSString *s2)
{
    // The == part takes care of cases where s1 and s2 are both nil.
    return ([s1 isEqualToString:s2] || s1 == s2);
}


@interface MPRenderer ()

@property (strong) NSMutableArray *currentLanguages;
@property (readonly) NSArray *baseStylesheets;
@property (readonly) NSArray *prismStylesheets;
@property (readonly) NSArray *prismScripts;
@property (readonly) NSArray *mathjaxScripts;
@property (readonly) NSArray *stylesheets;
@property (readonly) NSArray *scripts;
@property (copy) NSString *currentHtml;
@property (strong) NSTimer *parseDelayTimer;
@property int extensions;
@property BOOL smartypants;
@property BOOL TOC;
@property (copy) NSString *styleName;
@property BOOL frontMatter;
@property BOOL syntaxHighlighting;
@property MPCodeBlockAccessoryType codeBlockAccesory;
@property BOOL lineNumbers;
@property BOOL manualRender;
@property (copy) NSString *highlightingThemeName;

@end


NS_INLINE hoedown_buffer *language_addition(
    const hoedown_buffer *language, void *owner)
{
    MPRenderer *renderer = (__bridge MPRenderer *)owner;
    NSString *lang = [[NSString alloc] initWithBytes:language->data
                                              length:language->size
                                            encoding:NSUTF8StringEncoding];

    static NSDictionary *aliasMap = nil;
    static NSDictionary *languageMap = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        NSBundle *bundle = [Bundle Base];
        NSURL *url = [bundle URLForResource:@"syntax_highlighting" withExtension:@"json"];
        NSDictionary *info =
            [NSJSONSerialization JSONObjectWithFileAtURL:url options:0
                                                   error:NULL];

        aliasMap = info[@"aliases"];

        bundle = [Bundle Prism];
        url = [bundle URLForResource:@"components" withExtension:@"js"];
        NSString *code = [NSString stringWithContentsOfURL:url
                                                  encoding:NSUTF8StringEncoding
                                                     error:NULL];
        NSDictionary *comp = MPGetObjectFromJavaScript(code, @"components");
        languageMap = comp[@"languages"];
    });

    // Try to identify alias and point it to the "real" language name.
    hoedown_buffer *mapped = NULL;
    if ([aliasMap objectForKey:lang])
    {
        lang = [aliasMap objectForKey:lang];
        NSData *data = [lang dataUsingEncoding:NSUTF8StringEncoding];
        mapped = hoedown_buffer_new(64);
        hoedown_buffer_put(mapped, data.bytes, data.length);
    }

    // Walk dependencies to include all required scripts.
    NSMutableArray *languages = renderer.currentLanguages;
    while (lang)
    {
        NSUInteger index = [languages indexOfObject:lang];
        if (index != NSNotFound)
            [languages removeObjectAtIndex:index];
        [languages insertObject:lang atIndex:0];
        lang = languageMap[lang][@"require"];
    }
    
    return mapped;
}

NS_INLINE hoedown_renderer *MPCreateHTMLRenderer(MPRenderer *renderer)
{
    int flags = renderer.rendererFlags;
    hoedown_renderer *htmlRenderer = hoedown_html_renderer_new(
        flags, kMPRendererTOCLevel);
    htmlRenderer->blockcode = hoedown_patch_render_blockcode;
    htmlRenderer->listitem = hoedown_patch_render_listitem;
    
    hoedown_html_renderer_state_extra *extra =
        hoedown_malloc(sizeof(hoedown_html_renderer_state_extra));
    extra->language_addition = language_addition;
    extra->owner = (__bridge void *)renderer;

    ((hoedown_html_renderer_state *)htmlRenderer->opaque)->opaque = extra;
    return htmlRenderer;
}

NS_INLINE hoedown_renderer *MPCreateHTMLTOCRenderer()
{
    hoedown_renderer *tocRenderer =
        hoedown_html_toc_renderer_new(kMPRendererTOCLevel);
    tocRenderer->header = hoedown_patch_render_toc_header;
    return tocRenderer;
}

NS_INLINE void MPFreeHTMLRenderer(hoedown_renderer *htmlRenderer)
{
    hoedown_html_renderer_state_extra *extra =
        ((hoedown_html_renderer_state *)htmlRenderer->opaque)->opaque;
    if (extra)
        free(extra);
    hoedown_html_renderer_free(htmlRenderer);
}


@implementation MPRenderer

static MPRenderer* _shared = nil;
+ (MPRenderer *)shared {
    if (_shared == nil) {
        _shared = [[MPRenderer alloc]init];
    }
    return _shared;
}

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;

    self.currentHtml = @"";
    self.currentLanguages = [NSMutableArray array];
    self.preferences = [[MPPreferences alloc]init];
    self.rendererFlags = self.preferences.rendererFlags;
    return self;
}

#pragma mark - Accessor

- (NSArray *)baseStylesheets
{
    NSString *defaultStyleName = MPStylePathForName([self rendererStyleName:self]);
    if (!defaultStyleName) { return @[]; }
    NSURL *defaultStyle = [NSURL fileURLWithPath:defaultStyleName];
    NSMutableArray *stylesheets = [NSMutableArray array];
    [stylesheets addObject:[MPStyleSheet CSSWithURL:defaultStyle]];
    return stylesheets;
}

- (NSArray *)prismStylesheets
{
    NSString *name = [self rendererHighlightingThemeName:self];
    MPAsset *stylesheet = [MPStyleSheet CSSWithURL:MPHighlightingThemeURLForName(name)];

    NSMutableArray *stylesheets = [NSMutableArray arrayWithObject:stylesheet];

    if (self.rendererFlags & HOEDOWN_HTML_BLOCKCODE_LINE_NUMBERS)
    {
        NSURL *url = MPPrismPluginURL(@"line-numbers", @"css");
        [stylesheets addObject:[MPStyleSheet CSSWithURL:url]];
    }
    if ([self rendererCodeBlockAccesory:self]
        == MPCodeBlockAccessoryLanguageName)
    {
        NSURL *url = MPPrismPluginURL(@"show-language", @"css");
        [stylesheets addObject:[MPStyleSheet CSSWithURL:url]];
    }

    return stylesheets;
}

- (NSArray *)prismScripts
{
    NSBundle *bundle = Bundle.Prism;
    NSURL *url = [bundle URLForResource:@"prism-core.min" withExtension:@"js"
                           subdirectory:kMPPrismScriptDirectory];
    MPAsset *script = [MPScript javaScriptWithURL:url];
    NSMutableArray *scripts = [NSMutableArray arrayWithObject:script];
    for (NSString *language in self.currentLanguages) {
        for (NSURL *url in MPPrismScriptURLsForLanguage(language)) {
            [scripts addObject:[MPScript javaScriptWithURL:url]];
        }
    }

    if (self.rendererFlags & HOEDOWN_HTML_BLOCKCODE_LINE_NUMBERS) {
        NSURL *url = MPPrismPluginURL(@"line-numbers", @"js");
        [scripts addObject:[MPScript javaScriptWithURL:url]];
    }
    if ([self rendererCodeBlockAccesory:self] == MPCodeBlockAccessoryLanguageName) {
        NSURL *url = MPPrismPluginURL(@"show-language", @"js");
        [scripts addObject:[MPScript javaScriptWithURL:url]];
    }
    return scripts;
}

- (NSArray *)mathjaxScripts {
    NSMutableArray *scripts = [NSMutableArray array];
    NSURL *url = [NSURL URLWithString:kMPMathJaxCDN];
    NSBundle *bundle = Bundle.MathJax;
    MPEmbeddedScript *script =
        [MPEmbeddedScript assetWithURL:[bundle URLForResource:@"init"
                                                withExtension:@"js"]
                               andType:kMPMathJaxConfigType];
    [scripts addObject:script];
    [scripts addObject:[MPScript javaScriptWithURL:url]];
    return scripts;
}

- (NSArray *)chartAndSequenceScripts {
    NSMutableArray *scripts = [NSMutableArray array];
    NSBundle *bundle = Bundle.Chart;
    if ([self.currentLanguages containsObject:@"flow"] ) {
        NSURL *flowchart = [bundle URLForResource:@"flowchart.min"
                                    withExtension:@"js"];
        if (flowchart) {
            [scripts addObject: [MPScript javaScriptWithURL:flowchart]];
        }
        MPEmbeddedScript *script =
        [MPEmbeddedScript assetWithURL:[bundle URLForResource:@"flowchart.init"
                                                withExtension:@"js"]
                               andType:kMPJavaScriptType];
        [scripts addObject:script];
    }
    if ([self.currentLanguages containsObject:@"seq" ]) {
        
        NSURL *underscore = [bundle URLForResource:@"underscore-min"
                                     withExtension:@"js"];
        if (underscore) {
            [scripts addObject: [MPScript javaScriptWithURL:underscore]];
        }
        
        NSURL *seq = [bundle URLForResource:@"sequence-diagram-min"
                                    withExtension:@"js"];
        if (seq) {
            [scripts addObject: [MPScript javaScriptWithURL:seq]];
        }
       
        MPEmbeddedScript *script =
        [MPEmbeddedScript assetWithURL:[bundle URLForResource:@"sequence-diagram-init"
                                                withExtension:@"js"]
                               andType:kMPJavaScriptType];
        [scripts addObject:script];
    }
    if (scripts.count > 0) {
        NSURL *raphael = [bundle URLForResource:@"raphael.min" withExtension:@"js"];
        if (raphael) {
            [scripts insertObject:[MPScript javaScriptWithURL:raphael] atIndex:0];
        }
    }
    return scripts;
}

- (NSArray *)stylesheets
{
    

    NSMutableArray *stylesheets = [self.baseStylesheets mutableCopy];
    if ([self rendererHasSyntaxHighlighting:self])
        [stylesheets addObjectsFromArray:self.prismStylesheets];

    if ([self rendererCodeBlockAccesory:self] == MPCodeBlockAccessoryCustom)
    {
        NSURL *url = MPExtensionURL(@"show-information", @"css");
        [stylesheets addObject:[MPStyleSheet CSSWithURL:url]];
    }
    return stylesheets;
}

- (NSArray *)scripts
{
    
    NSMutableArray *scripts = [NSMutableArray array];
    if (self.rendererFlags & HOEDOWN_HTML_USE_TASK_LIST) {
        NSURL *url = MPExtensionURL(@"tasklist", @"js");
        [scripts addObject:[MPScript javaScriptWithURL:url]];
    }
    if ([self rendererHasSyntaxHighlighting:self]) { [scripts addObjectsFromArray:self.prismScripts]; }
    if ([self rendererHasMathJax:self]) { [scripts addObjectsFromArray:self.mathjaxScripts]; }
    [scripts addObjectsFromArray:self.chartAndSequenceScripts];
    return scripts;
}

#pragma mark - Public

- (void)parseAndRenderNow
{
    [self parseNowWithCommand:@selector(parse) completionHandler:^{
        [self render];
    }];
}

- (void)parseAndRenderLater
{
    [self parseLaterWithCommand:@selector(parse) completionHandler:^{
        [self render];
    }];
}

- (void)parseNowWithCommand:(SEL)action completionHandler:(void(^)())handler
{
    [self parseLater:0.0 withCommand:action completionHandler:handler];
}

- (void)parseLaterWithCommand:(SEL)action completionHandler:(void(^)())handler
{
    [self parseLater:0.5 withCommand:action completionHandler:handler];
}

- (void)parseIfPreferencesChanged
{
    
    if ([self rendererExtensions:self] != self.extensions
            || [self rendererHasSmartyPants:self] != self.smartypants
            || [self rendererRendersTOC:self] != self.TOC
            || [self rendererDetectsFrontMatter:self] != self.frontMatter)
        [self parse];
}

- (void)parse
{
    void(^nextAction)() = nil;
    if (self.parseDelayTimer.isValid)
    {
        nextAction = self.parseDelayTimer.userInfo[@"next"];
        [self.parseDelayTimer invalidate];
    }

    [self.currentLanguages removeAllObjects];

    
    int extensions = [self rendererExtensions:self];
    BOOL smartypants = [self rendererHasSmartyPants:self];
    BOOL hasFrontMatter = [self rendererDetectsFrontMatter:self];
    BOOL hasTOC = [self rendererRendersTOC:self];

    id frontMatter = nil;
    NSString *markdown = [self rendererMarkdown:self];
    if (hasFrontMatter)
    {
        NSUInteger offset = 0;
        frontMatter = [markdown frontMatter:&offset];
        markdown = [markdown substringFromIndex:offset];
    }
    hoedown_renderer *htmlRenderer = MPCreateHTMLRenderer(self);
    hoedown_renderer *tocRenderer = NULL;
    if (hasTOC)
        tocRenderer = MPCreateHTMLTOCRenderer();
    self.currentHtml = MPHTMLFromMarkdown(
        markdown, extensions, smartypants, [frontMatter HTMLTable],
        htmlRenderer, tocRenderer);
    if (tocRenderer)
        hoedown_html_renderer_free(tocRenderer);
    MPFreeHTMLRenderer(htmlRenderer);

    self.extensions = extensions;
    self.smartypants = smartypants;
    self.TOC = hasTOC;
    self.frontMatter = hasFrontMatter;

    if (nextAction)
        nextAction();
}

- (void)renderIfPreferencesChanged
{
    BOOL changed = NO;
    
    if ([self rendererHasSyntaxHighlighting:self] != self.syntaxHighlighting)
        changed = YES;
    else if (!MPAreNilableStringsEqual(
            [self rendererHighlightingThemeName:self], self.highlightingThemeName))
        changed = YES;
    else if (!MPAreNilableStringsEqual(
            [self rendererStyleName:self], self.styleName))
        changed = YES;
    else if ([self rendererCodeBlockAccesory:self] != self.codeBlockAccesory)
        changed = YES;

    if (changed)
        [self render];
}

- (void)render
{
    

    NSString *title = [self rendererHTMLTitle:self];
    NSString *html = MPGetHTML(
        title, self.currentHtml, self.stylesheets, MPAssetFullLink,
        self.scripts, MPAssetFullLink);
    [self renderer:self didProduceHTMLOutput:html];

    self.styleName = [self rendererStyleName:self];
    self.syntaxHighlighting = [self rendererHasSyntaxHighlighting:self];
    self.highlightingThemeName = [self rendererHighlightingThemeName:self];
    self.codeBlockAccesory = [self rendererCodeBlockAccesory:self];
}

- (NSString *)HTMLForExportWithStyles:(BOOL)withStyles
                         highlighting:(BOOL)withHighlighting
{
    MPAssetOption stylesOption = MPAssetNone;
    MPAssetOption scriptsOption = MPAssetNone;
    NSMutableArray *styles = [NSMutableArray array];
    NSMutableArray *scripts = [NSMutableArray array];

    if (withStyles)
    {
        stylesOption = MPAssetEmbedded;
        [styles addObjectsFromArray:self.baseStylesheets];
    }
    if (withHighlighting)
    {
        stylesOption = MPAssetEmbedded;
        scriptsOption = MPAssetEmbedded;
        [styles addObjectsFromArray:self.prismStylesheets];
        [scripts addObjectsFromArray:self.prismScripts];
    }
    if ([self rendererHasMathJax:self])
    {
        scriptsOption = MPAssetEmbedded;
        [scripts addObjectsFromArray:self.mathjaxScripts];
    }

    NSString *title = [self rendererHTMLTitle:self];
    if (!title)
        title = @"";
    NSString *html = MPGetHTML(
        title, self.currentHtml, styles, stylesOption, scripts, scriptsOption);
    return html;
}


#pragma mark - Private

- (void)parseLater:(NSTimeInterval)delay
       withCommand:(SEL)action completionHandler:(void(^)())handler
{
    self.parseDelayTimer =
        [NSTimer scheduledTimerWithTimeInterval:delay
                                         target:self
                                       selector:action
                                       userInfo:@{@"next": handler}
                                        repeats:NO];
}





#pragma mark - MPRendererDataSource
- (NSString *)rendererMarkdown:(MPRenderer *)renderer {
    return self.content;
}
- (NSString *)rendererHTMLTitle:(MPRenderer *)renderer {
    return self.title;
}


#pragma mark - MPRendererDelegate

- (int)rendererExtensions:(MPRenderer *)renderer
{
    return self.preferences.extensionFlags;
}

- (BOOL)rendererHasSmartyPants:(MPRenderer *)renderer
{
    return self.preferences.extensionSmartyPants;
}

- (BOOL)rendererRendersTOC:(MPRenderer *)renderer
{
    return self.preferences.htmlRendersTOC;
}

- (NSString *)rendererStyleName:(MPRenderer *)renderer
{
    return self.preferences.htmlStyleName;
}

- (BOOL)rendererDetectsFrontMatter:(MPRenderer *)renderer
{
    return self.preferences.htmlDetectFrontMatter;
}

- (BOOL)rendererHasSyntaxHighlighting:(MPRenderer *)renderer
{
    return YES;
}

- (MPCodeBlockAccessoryType)rendererCodeBlockAccesory:(MPRenderer *)renderer
{
    return self.preferences.htmlCodeBlockAccessory;
}

- (BOOL)rendererHasMathJax:(MPRenderer *)renderer
{
    return YES;
}

- (NSString *)rendererHighlightingThemeName:(MPRenderer *)renderer
{
    return self.preferences.htmlHighlightingThemeName;
}

- (void)renderer:(MPRenderer *)renderer didProduceHTMLOutput:(NSString *)html
{
    !_renderDone ?: _renderDone(html);
}


@end
