//
//  MPRenderer.h
//  MacDown
//
//  Created by Tzu-ping Chung  on 26/6.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MPPreferences.h"
//@protocol MPRendererDataSource;
//@protocol MPRendererDelegate;


typedef NS_ENUM(NSUInteger, MPCodeBlockAccessoryType)
{
    MPCodeBlockAccessoryNone = 0,
    MPCodeBlockAccessoryLanguageName,
    MPCodeBlockAccessoryCustom,
};

@interface NSString (MacDownRender)
-(void) markdown:(void (^)(NSString*))done;
-(void) markdownwith:(NSString*)title done:(void (^)(NSString*))done;
@end
@interface MPRenderer : NSObject

@property (nonatomic) int rendererFlags;
@property (strong, nonatomic) MPPreferences* preferences;
@property (copy, nonatomic) NSString* content;
@property (copy, nonatomic) NSString* title;
@property (nonatomic, copy) void (^renderDone)(NSString*);
//@property (weak) id<MPRendererDataSource> dataSource;
//@property (weak) id<MPRendererDelegate> delegate;
+ (MPRenderer*) shared;
- (void)parseAndRenderNow;
- (void)parseAndRenderLater;
- (void)parseNowWithCommand:(SEL)action completionHandler:(void(^)())handler;
- (void)parseLaterWithCommand:(SEL)action completionHandler:(void(^)())handler;
- (void)parseIfPreferencesChanged;
- (void)parse;
- (void)renderIfPreferencesChanged;
- (void)render;

- (NSString *)currentHtml;
- (NSString *)HTMLForExportWithStyles:(BOOL)withStyles
                         highlighting:(BOOL)withHighlighting;

@end


//@protocol MPRendererDataSource <NSObject>
//
//- (NSString *)rendererMarkdown:(MPRenderer *)renderer;
//- (NSString *)rendererHTMLTitle:(MPRenderer *)renderer;
//
//@end

//@protocol MPRendererDelegate <NSObject>
//
//- (int)rendererExtensions:(MPRenderer *)renderer;
//- (BOOL)rendererHasSmartyPants:(MPRenderer *)renderer;
//- (BOOL)rendererRendersTOC:(MPRenderer *)renderer;
//- (NSString *)rendererStyleName:(MPRenderer *)renderer;
//- (BOOL)rendererDetectsFrontMatter:(MPRenderer *)renderer;
//- (BOOL)rendererHasSyntaxHighlighting:(MPRenderer *)renderer;
//- (MPCodeBlockAccessoryType)rendererCodeBlockAccesory:(MPRenderer *)renderer;
//- (BOOL)rendererHasMathJax:(MPRenderer *)renderer;
//- (NSString *)rendererHighlightingThemeName:(MPRenderer *)renderer;
//- (void)renderer:(MPRenderer *)renderer didProduceHTMLOutput:(NSString *)html;
//
//@end
